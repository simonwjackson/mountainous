//! The gate: which messages become signals, and which signals reach the model.
//!
//! A message becomes a signal when an agent sender (`notify send`) matches a
//! rule. The signal waits for the rule's hold time. A clear of the same
//! notification during the hold means the source saw it recover, so the
//! signal is dropped. After the hold, a signal runs only when its key has not
//! run within the cool-down and the source and the whole service are under
//! their limits for the last 24 hours. Everything here is plain code with no
//! clock of its own, so the tests drive time.

use std::collections::{BTreeMap, VecDeque};

use regex::Regex;
use serde::{Deserialize, Serialize};

use crate::signal::{NtfyMessage, Signal};

const DAY: u64 = 24 * 60 * 60;
const SEEN_LIMIT: usize = 512;

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct RuleConfig {
    /// The signal's source name, such as `beszel`.
    pub source: String,
    /// Regex for the sender's `--name`.
    pub sender: String,
    /// Regexes for titles that mean "something is wrong".
    pub fire: Vec<String>,
    /// Regexes for titles that never fire, checked after `fire`.
    #[serde(default)]
    pub ignore: Vec<String>,
    pub hold_seconds: u64,
    pub cooldown_seconds: u64,
    pub daily_limit: usize,
    pub token_budget: u64,
    /// What the model looks at for this source.
    pub playbook: String,
}

struct Rule {
    config: RuleConfig,
    sender: Regex,
    fire: Vec<Regex>,
    ignore: Vec<Regex>,
}

impl Rule {
    fn new(config: RuleConfig) -> Result<Self, String> {
        let compile = |pattern: &str| {
            Regex::new(pattern)
                .map_err(|error| format!("rule {}: bad regex {pattern:?}: {error}", config.source))
        };
        let sender = compile(&config.sender)?;
        let fire = config
            .fire
            .iter()
            .map(|p| compile(p))
            .collect::<Result<_, _>>()?;
        let ignore = config
            .ignore
            .iter()
            .map(|p| compile(p))
            .collect::<Result<_, _>>()?;
        Ok(Rule {
            sender,
            fire,
            ignore,
            config,
        })
    }

    fn matches(&self, sender: &str, title: &str) -> bool {
        self.sender.is_match(sender)
            && self.fire.iter().any(|r| r.is_match(title))
            && !self.ignore.iter().any(|r| r.is_match(title))
    }
}

/// Everything the gate must remember across restarts.
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct State {
    /// ntfy time of the newest message handled; the stream resumes here.
    pub since: u64,
    seen: VecDeque<String>,
    pending: BTreeMap<String, Pending>,
    last_run: BTreeMap<String, u64>,
    runs: Vec<RunMark>,
}

#[derive(Debug, Serialize, Deserialize)]
struct Pending {
    signal: Signal,
    due: u64,
}

#[derive(Debug, Serialize, Deserialize)]
struct RunMark {
    source: String,
    at: u64,
}

#[derive(Debug, PartialEq)]
pub enum Observed {
    /// A stream event that is not a message, such as a keepalive.
    NotMessage,
    /// Not an alert this service handles.
    Ignored,
    /// Already handled before a reconnect or restart.
    Duplicate,
    /// A new signal, waiting until `due`.
    Held { key: String, due: u64 },
    /// The source cleared a held signal: it recovered within the hold.
    Resolved { key: String },
}

#[derive(Debug, PartialEq)]
pub enum Verdict {
    Respond(Signal),
    Skip(Signal, String),
}

pub struct Gate {
    rules: Vec<Rule>,
    daily_limit: usize,
    pub state: State,
}

impl Gate {
    pub fn new(rules: Vec<RuleConfig>, daily_limit: usize, state: State) -> Result<Self, String> {
        let rules = rules
            .into_iter()
            .map(Rule::new)
            .collect::<Result<Vec<_>, _>>()?;
        Ok(Gate {
            rules,
            daily_limit,
            state,
        })
    }

    pub fn rule(&self, source: &str) -> Option<&RuleConfig> {
        self.rules
            .iter()
            .map(|r| &r.config)
            .find(|c| c.source == source)
    }

    pub fn observe(&mut self, message: &NtfyMessage) -> Observed {
        let clear = matches!(message.event.as_str(), "message_clear" | "message_delete");
        if message.event != "message" && !clear {
            return Observed::NotMessage;
        }
        if self.state.seen.contains(&message.id) {
            return Observed::Duplicate;
        }
        self.state.seen.push_back(message.id.clone());
        while self.state.seen.len() > SEEN_LIMIT {
            self.state.seen.pop_front();
        }
        self.state.since = self.state.since.max(message.time);
        if clear {
            return match self.state.pending.remove(message.seq()) {
                Some(pending) => Observed::Resolved {
                    key: pending.signal.key,
                },
                None => Observed::Ignored,
            };
        }
        let Some((signal, hold)) = self.classify(message) else {
            return Observed::Ignored;
        };
        let key = signal.key.clone();
        let due = signal.at + hold;
        self.state
            .pending
            .insert(signal.seq.clone(), Pending { signal, due });
        Observed::Held { key, due }
    }

    fn classify(&self, message: &NtfyMessage) -> Option<(Signal, u64)> {
        let sender = message.sender().filter(|s| s.agent)?;
        let title = message.title.clone().unwrap_or_default();
        let rule = self
            .rules
            .iter()
            .find(|r| r.matches(&sender.name, &title))?;
        let signal = Signal {
            source: rule.config.source.clone(),
            key: format!("{}:{}", rule.config.source, title),
            sender: sender.name,
            title,
            body: message.message.clone().unwrap_or_default(),
            seq: message.seq().to_string(),
            at: message.time,
        };
        Some((signal, rule.config.hold_seconds))
    }

    pub fn next_due(&self) -> Option<u64> {
        self.state.pending.values().map(|p| p.due).min()
    }

    pub fn take_due(&mut self, now: u64) -> Vec<Verdict> {
        let mut due: Vec<(u64, String)> = (self.state.pending.iter())
            .filter(|(_, p)| p.due <= now)
            .map(|(seq, p)| (p.due, seq.clone()))
            .collect();
        due.sort();
        self.state.runs.retain(|mark| mark.at + DAY > now);
        let mut verdicts = Vec::new();
        for (_, seq) in due {
            let Some(pending) = self.state.pending.remove(&seq) else {
                continue;
            };
            verdicts.push(self.admit(pending.signal, now));
        }
        verdicts
    }

    fn admit(&mut self, signal: Signal, now: u64) -> Verdict {
        let Some(rule) = self.rule(&signal.source) else {
            return Verdict::Skip(signal, "its rule no longer exists".into());
        };
        let (cooldown, source_limit) = (rule.cooldown_seconds, rule.daily_limit);
        if let Some(last) = self.state.last_run.get(&signal.key) {
            if now < last + cooldown {
                let minutes = (now - last) / 60;
                return Verdict::Skip(
                    signal,
                    format!("the same alert was triaged {minutes} min ago"),
                );
            }
        }
        let from_source = self
            .state
            .runs
            .iter()
            .filter(|m| m.source == signal.source)
            .count();
        if from_source >= source_limit {
            let why = format!("{from_source} {} triages in 24 h", signal.source);
            return Verdict::Skip(signal, why);
        }
        if self.state.runs.len() >= self.daily_limit {
            return Verdict::Skip(signal, format!("{} triages in 24 h", self.state.runs.len()));
        }
        self.state.runs.push(RunMark {
            source: signal.source.clone(),
            at: now,
        });
        self.state.last_run.insert(signal.key.clone(), now);
        self.state.last_run.retain(|_, at| *at + DAY * 7 > now);
        Verdict::Respond(signal)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use base64::engine::general_purpose::URL_SAFE_NO_PAD;
    use base64::Engine;

    fn rules() -> Vec<RuleConfig> {
        let rule = |source: &str, sender: &str, fire: &[&str], ignore: &[&str]| RuleConfig {
            source: source.into(),
            sender: sender.into(),
            fire: fire.iter().map(|s| s.to_string()).collect(),
            ignore: ignore.iter().map(|s| s.to_string()).collect(),
            hold_seconds: 600,
            cooldown_seconds: 6 * 3600,
            daily_limit: 2,
            token_budget: 1000,
            playbook: "look".into(),
        };
        vec![
            rule(
                "beszel",
                "^beszel$",
                &["^Connection to \\S+ is down", "above threshold$"],
                &["battery above threshold$"],
            ),
            rule("storage", "^[a-z0-9-]+$", &["^\\S+: storage problem$"], &[]),
        ]
    }

    fn gate(limit: usize) -> Gate {
        Gate::new(rules(), limit, State::default()).unwrap()
    }

    fn tag(name: &str, agent: bool) -> String {
        let meta = format!(r#"{{"h":"{name}","a":"agent","g":{agent}}}"#);
        format!("ns1_{}", URL_SAFE_NO_PAD.encode(meta))
    }

    fn sent(id: &str, time: u64, sender: &str, title: &str) -> NtfyMessage {
        NtfyMessage {
            id: id.into(),
            time,
            event: "message".into(),
            sequence_id: Some(format!("seq-{id}")),
            title: Some(title.into()),
            message: Some("body".into()),
            tags: vec![tag(sender, true)],
        }
    }

    fn cleared(id: &str, time: u64, of: &str) -> NtfyMessage {
        NtfyMessage {
            id: id.into(),
            time,
            event: "message_clear".into(),
            sequence_id: Some(format!("seq-{of}")),
            title: None,
            message: None,
            tags: vec![],
        }
    }

    fn sources(verdicts: &[Verdict]) -> Vec<String> {
        verdicts
            .iter()
            .map(|v| match v {
                Verdict::Respond(s) => format!("run {}", s.key),
                Verdict::Skip(s, why) => format!("skip {}: {why}", s.key),
            })
            .collect()
    }

    #[test]
    fn a_held_alert_runs_after_the_hold() {
        let mut g = gate(5);
        let observed = g.observe(&sent("a", 100, "beszel", "Connection to tate is down 🔴"));
        assert_eq!(
            observed,
            Observed::Held {
                key: "beszel:Connection to tate is down 🔴".into(),
                due: 700
            }
        );
        assert_eq!(g.next_due(), Some(700));
        assert!(g.take_due(699).is_empty());
        assert_eq!(
            sources(&g.take_due(700)),
            ["run beszel:Connection to tate is down 🔴"]
        );
        assert_eq!(g.next_due(), None);
    }

    #[test]
    fn a_clear_within_the_hold_drops_the_signal() {
        let mut g = gate(5);
        g.observe(&sent("a", 100, "beszel", "Connection to tate is down 🔴"));
        let observed = g.observe(&cleared("b", 200, "a"));
        assert_eq!(
            observed,
            Observed::Resolved {
                key: "beszel:Connection to tate is down 🔴".into()
            }
        );
        assert!(g.take_due(10_000).is_empty());
    }

    #[test]
    fn good_news_desktop_popups_and_unknown_senders_are_ignored() {
        let mut g = gate(5);
        assert_eq!(
            g.observe(&sent("a", 1, "beszel", "Connection to tate is up ✅")),
            Observed::Ignored
        );
        assert_eq!(
            g.observe(&sent("b", 1, "beszel", "galaxy battery above threshold")),
            Observed::Ignored
        );
        assert_eq!(
            g.observe(&sent(
                "c",
                1,
                "first-responder",
                "Connection to tate is down"
            )),
            Observed::Ignored
        );
        let mut popup = sent("d", 1, "beszel", "Connection to tate is down");
        popup.tags = vec![tag("beszel", false)];
        assert_eq!(g.observe(&popup), Observed::Ignored);
        popup.id = "d2".into();
        popup.tags = vec![];
        assert_eq!(g.observe(&popup), Observed::Ignored);
        let mut keepalive = sent("e", 1, "beszel", "Connection to tate is down");
        keepalive.event = "keepalive".into();
        assert_eq!(g.observe(&keepalive), Observed::NotMessage);
    }

    #[test]
    fn a_second_source_uses_its_own_rule() {
        let mut g = gate(5);
        let observed = g.observe(&sent("a", 0, "unzen", "unzen: storage problem"));
        assert_eq!(
            observed,
            Observed::Held {
                key: "storage:unzen: storage problem".into(),
                due: 600
            }
        );
        assert_eq!(
            g.observe(&sent("b", 0, "unzen", "unzen: storage recovered")),
            Observed::Ignored
        );
    }

    #[test]
    fn a_replayed_message_is_a_duplicate() {
        let mut g = gate(5);
        g.observe(&sent("a", 5, "beszel", "Connection to tate is down"));
        assert_eq!(
            g.observe(&sent("a", 5, "beszel", "Connection to tate is down")),
            Observed::Duplicate
        );
        assert_eq!(g.state.since, 5);
    }

    #[test]
    fn the_same_key_waits_for_its_cool_down() {
        let mut g = gate(5);
        g.observe(&sent("a", 0, "beszel", "Connection to tate is down"));
        assert_eq!(
            sources(&g.take_due(600)),
            ["run beszel:Connection to tate is down"]
        );
        g.observe(&sent("b", 3600, "beszel", "Connection to tate is down"));
        assert_eq!(
            sources(&g.take_due(4200)),
            ["skip beszel:Connection to tate is down: the same alert was triaged 60 min ago"]
        );
        g.observe(&sent("c", 6 * 3600, "beszel", "Connection to tate is down"));
        assert_eq!(
            sources(&g.take_due(6 * 3600 + 600)),
            ["run beszel:Connection to tate is down"]
        );
    }

    #[test]
    fn limits_hold_per_source_and_in_total() {
        let mut g = gate(3);
        for (id, host) in ["a", "b", "c"].iter().zip(["tate", "unzen", "ibuki"]) {
            g.observe(&sent(
                id,
                0,
                "beszel",
                &format!("Connection to {host} is down"),
            ));
        }
        g.observe(&sent("d", 0, "unzen", "unzen: storage problem"));
        g.observe(&sent("e", 1, "fuji", "fuji: storage problem"));
        let verdicts = sources(&g.take_due(601));
        assert_eq!(
            verdicts
                .iter()
                .filter(|v| v.starts_with("run beszel"))
                .count(),
            2
        );
        assert!(verdicts.contains(
            &"skip beszel:Connection to ibuki is down: 2 beszel triages in 24 h".to_string()
        ));
        assert!(verdicts.contains(&"run storage:unzen: storage problem".to_string()));
        assert!(
            verdicts.contains(&"skip storage:fuji: storage problem: 3 triages in 24 h".to_string())
        );
        // A day later the limits are free again.
        g.observe(&sent("f", 90_000, "beszel", "Connection to myoko is down"));
        assert_eq!(
            sources(&g.take_due(90_600)),
            ["run beszel:Connection to myoko is down"]
        );
    }

    #[test]
    fn state_survives_a_restart() {
        let mut g = gate(5);
        g.observe(&sent("a", 0, "beszel", "Connection to tate is down"));
        let saved = serde_json::to_string(&g.state).unwrap();
        let mut again = Gate::new(rules(), 5, serde_json::from_str(&saved).unwrap()).unwrap();
        assert_eq!(
            again.observe(&sent("a", 0, "beszel", "Connection to tate is down")),
            Observed::Duplicate
        );
        assert_eq!(
            sources(&again.take_due(600)),
            ["run beszel:Connection to tate is down"]
        );
    }

    #[test]
    fn a_bad_regex_names_its_rule() {
        let mut bad = rules();
        bad[1].fire = vec!["(".into()];
        let error = Gate::new(bad, 1, State::default()).err().unwrap();
        assert!(
            error.starts_with("rule storage: bad regex \"(\""),
            "{error}"
        );
    }
}
