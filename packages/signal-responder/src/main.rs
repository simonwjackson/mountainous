//! signal-responder: alerts on the notify topic become read-only triage runs.
//!
//! Usage: signal-responder --config <file>
//!
//! It follows ntfy's JSON stream for the topic. The gate (gate.rs) turns
//! matching alerts into signals, holds them, and limits them. A signal that
//! passes becomes a one-time schedule on the assistant's background lane.
//! When that run finishes, its final answer goes back to the topic through
//! the `notify` CLI. The ntfy token is `$CREDENTIALS_DIRECTORY/ntfy-token`;
//! the `notify` CLI reads its own from NOTIFY_TOKEN_FILE.

mod gate;
mod respond;
mod rpc;
mod signal;

use std::fs;
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc::{self, RecvTimeoutError, Sender};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde::Deserialize;

use gate::{Gate, Observed, RuleConfig, State, Verdict};
use respond::Responder;
use signal::NtfyMessage;

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct Config {
    ntfy_url: String,
    topic: String,
    rpc_url: String,
    owner: String,
    lane: String,
    notify: String,
    notify_name: String,
    state_dir: PathBuf,
    daily_limit: usize,
    rules: Vec<RuleConfig>,
}

enum Failure {
    Usage,
    Stop(String),
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(Failure::Usage) => {
            eprintln!("usage: signal-responder --config <file>");
            ExitCode::from(2)
        }
        Err(Failure::Stop(message)) => {
            eprintln!("signal-responder: {message}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), Failure> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let [flag, path] = args.as_slice() else {
        return Err(Failure::Usage);
    };
    if flag != "--config" {
        return Err(Failure::Usage);
    }
    let config = read_config(Path::new(path)).map_err(Failure::Stop)?;
    let token = read_token().map_err(Failure::Stop)?;
    let state_file = config.state_dir.join("state.json");
    let state = load_state(&state_file).map_err(Failure::Stop)?;
    let mut gate = Gate::new(config.rules, config.daily_limit, state).map_err(Failure::Stop)?;
    if gate.state.since == 0 {
        // First start: alerts from before this service existed are history.
        gate.state.since = now();
    }
    let responder = Responder {
        rpc_url: config.rpc_url,
        owner: config.owner,
        lane: config.lane,
        notify: config.notify,
        notify_name: config.notify_name,
    };

    let since = Arc::new(AtomicU64::new(gate.state.since));
    let (sender, messages) = mpsc::channel();
    let stream_url = format!(
        "{}/{}/json",
        config.ntfy_url.trim_end_matches('/'),
        config.topic
    );
    let stream_since = Arc::clone(&since);
    thread::spawn(move || follow(&stream_url, &token, &stream_since, &sender));
    eprintln!(
        "following {} since {}",
        config.topic,
        respond::iso(gate.state.since)
    );

    loop {
        let wait = gate
            .next_due()
            .map_or(60, |due| due.saturating_sub(now()).clamp(1, 60));
        let mut changed = false;
        match messages.recv_timeout(Duration::from_secs(wait)) {
            Ok(message) => {
                changed = report(gate.observe(&message), &message);
                since.store(gate.state.since, Ordering::Relaxed);
            }
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => {
                return Err(Failure::Stop("the stream reader stopped".into()))
            }
        }
        let now = now();
        for verdict in gate.take_due(now) {
            changed = true;
            match verdict {
                Verdict::Skip(signal, why) => eprintln!("skip {}: {why}", signal.key),
                Verdict::Respond(signal) => {
                    let Some(rule) = gate.rule(&signal.source).cloned() else {
                        continue;
                    };
                    let responder = responder.clone();
                    eprintln!("triage {}", signal.key);
                    thread::spawn(move || responder.respond(&rule, &signal, now));
                }
            }
        }
        if changed {
            save_state(&state_file, &gate.state).map_err(Failure::Stop)?;
        }
    }
}

/// Logs what the gate did; true when the state changed.
fn report(observed: Observed, message: &NtfyMessage) -> bool {
    match observed {
        Observed::Ignored => true,
        Observed::NotMessage | Observed::Duplicate => false,
        Observed::Held { key, due } => {
            eprintln!("hold {key} until {} ({})", respond::iso(due), message.seq());
            true
        }
        Observed::Resolved { key } => {
            eprintln!("resolved during the hold: {key}");
            true
        }
    }
}

/// Reads the stream for ever, reconnecting from the newest handled time.
fn follow(url: &str, token: &str, since: &AtomicU64, sender: &Sender<NtfyMessage>) {
    // ntfy sends a keepalive every 45 s, so a silent minute means a dead link.
    let agent = ureq::AgentBuilder::new()
        .timeout_connect(Duration::from_secs(10))
        .timeout_read(Duration::from_secs(120))
        .build();
    let mut backoff = 1;
    loop {
        let from = since.load(Ordering::Relaxed);
        let response = (agent.get(url))
            .query("since", &from.to_string())
            .set("Authorization", &format!("Bearer {token}"))
            .call();
        match response {
            Ok(response) => {
                backoff = 1;
                for line in BufReader::new(response.into_reader()).lines() {
                    let line = match line {
                        Ok(line) => line,
                        Err(error) => {
                            eprintln!("stream: {error}");
                            break;
                        }
                    };
                    match serde_json::from_str::<NtfyMessage>(&line) {
                        Ok(message) => {
                            if sender.send(message).is_err() {
                                return;
                            }
                        }
                        Err(error) => eprintln!("stream: unreadable line: {error}"),
                    }
                }
                eprintln!("stream ended; reconnecting");
            }
            Err(error) => eprintln!("stream: {error}"),
        }
        thread::sleep(Duration::from_secs(backoff));
        backoff = (backoff * 2).min(60);
    }
}

fn read_config(path: &Path) -> Result<Config, String> {
    let text = fs::read_to_string(path).map_err(|error| format!("{}: {error}", path.display()))?;
    serde_json::from_str(&text).map_err(|error| format!("{}: {error}", path.display()))
}

fn read_token() -> Result<String, String> {
    let directory = std::env::var("CREDENTIALS_DIRECTORY")
        .map_err(|_| "CREDENTIALS_DIRECTORY is not set".to_string())?;
    let path = Path::new(&directory).join("ntfy-token");
    let token =
        fs::read_to_string(&path).map_err(|error| format!("{}: {error}", path.display()))?;
    Ok(token.trim().to_string())
}

fn load_state(path: &Path) -> Result<State, String> {
    match fs::read_to_string(path) {
        Ok(text) => {
            serde_json::from_str(&text).map_err(|error| format!("{}: {error}", path.display()))
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(State::default()),
        Err(error) => Err(format!("{}: {error}", path.display())),
    }
}

/// Replaces the state file in one rename, so a crash never leaves half a file.
fn save_state(path: &Path, state: &State) -> Result<(), String> {
    let temporary = path.with_extension("json.tmp");
    let text = serde_json::to_string(state).map_err(|error| error.to_string())?;
    fs::write(&temporary, text).map_err(|error| format!("{}: {error}", temporary.display()))?;
    fs::rename(&temporary, path).map_err(|error| format!("{}: {error}", path.display()))
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, |d| d.as_secs())
}
