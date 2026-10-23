//! A small client for the assistant core's Effect RPC over HTTP (NDJSON).
//!
//! A request is one line: `{"_tag":"Request","id":"1","tag":<rpc>,
//! "payload":<payload>,"headers":[]}`. The answer holds an `Exit` line whose
//! `exit` is `Success` with a `value`, or `Failure` with a `cause`.

use std::time::Duration;

use serde::Deserialize;
use serde_json::{json, Value};

pub struct Assistant {
    url: String,
    agent: ureq::Agent,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScheduleRun {
    pub schedule_id: String,
    pub attempt: u32,
    pub session_id: String,
    pub outcome: String,
    #[serde(default)]
    pub model: Option<String>,
    #[serde(default)]
    pub total_tokens: f64,
    #[serde(default)]
    pub cost_usd: f64,
    #[serde(default)]
    pub error: Option<String>,
}

impl Assistant {
    pub fn new(url: &str) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout(Duration::from_secs(60))
            .build();
        Assistant {
            url: url.to_string(),
            agent,
        }
    }

    pub fn call(&self, tag: &str, payload: Value) -> Result<Value, String> {
        let request =
            json!({"_tag": "Request", "id": "1", "tag": tag, "payload": payload, "headers": []});
        let response = (self.agent.post(&self.url))
            .set("content-type", "application/ndjson")
            .send_string(&format!("{request}\n"))
            .map_err(|error| format!("{tag}: {error}"))?;
        let text = response
            .into_string()
            .map_err(|error| format!("{tag}: {error}"))?;
        exit_value(&text).map_err(|error| format!("{tag}: {error}"))
    }

    pub fn create_schedule(&self, input: Value) -> Result<String, String> {
        let schedule = self.call("CreateSchedule", input)?;
        (schedule["id"].as_str())
            .map(str::to_string)
            .ok_or_else(|| "CreateSchedule: the answer has no id".to_string())
    }

    /// The newest finished run of a schedule, if one has finished.
    pub fn finished_run(&self, schedule_id: &str) -> Result<Option<ScheduleRun>, String> {
        let value = self.call("ListScheduleRuns", json!({ "scheduleId": schedule_id }))?;
        let runs: Vec<ScheduleRun> =
            serde_json::from_value(value).map_err(|error| format!("ListScheduleRuns: {error}"))?;
        Ok(runs
            .into_iter()
            .filter(|run| run.schedule_id == schedule_id && run.outcome != "running")
            .max_by_key(|run| run.attempt))
    }

    pub fn final_answer(&self, session_id: &str) -> Result<String, String> {
        let entries = self.call("GetTranscript", json!({ "sessionId": session_id }))?;
        Ok(final_answer(&entries))
    }
}

fn exit_value(text: &str) -> Result<Value, String> {
    for line in text.lines().filter(|line| !line.trim().is_empty()) {
        let message: Value =
            serde_json::from_str(line).map_err(|error| format!("bad answer line: {error}"))?;
        if message["_tag"] != "Exit" {
            continue;
        }
        let exit = &message["exit"];
        return match exit["_tag"].as_str() {
            Some("Success") => Ok(exit["value"].clone()),
            _ => Err(describe_cause(&exit["cause"])),
        };
    }
    Err("the answer has no Exit".into())
}

fn describe_cause(cause: &Value) -> String {
    let parts: Vec<String> = (cause.as_array().into_iter().flatten())
        .map(|part| {
            (part["error"]["message"].as_str())
                .or(part["defect"].as_str())
                .map(str::to_string)
                .unwrap_or_else(|| part.to_string())
        })
        .collect();
    if parts.is_empty() {
        cause.to_string()
    } else {
        parts.join("; ")
    }
}

/// The text of the last assistant message in a transcript.
pub fn final_answer(entries: &Value) -> String {
    let last = (entries.as_array().into_iter().flatten())
        .filter(|entry| {
            entry["type"] == "message" && entry["data"]["message"]["role"] == "assistant"
        })
        .map(|entry| {
            (entry["data"]["message"]["content"]
                .as_array()
                .into_iter()
                .flatten())
            .filter(|part| part["type"] == "text")
            .filter_map(|part| part["text"].as_str())
            .collect::<Vec<_>>()
            .join("\n")
        })
        .rfind(|text| !text.trim().is_empty());
    last.map(|text| text.trim().to_string())
        .unwrap_or_else(|| "The run finished without a final answer.".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reads_a_success() {
        let line =
            r#"{"_tag":"Exit","requestId":"1","exit":{"_tag":"Success","value":{"id":"s1"}}}"#;
        assert_eq!(exit_value(line).unwrap()["id"], "s1");
    }

    #[test]
    fn reads_a_failure_and_a_defect() {
        let fail = r#"{"_tag":"Exit","requestId":"1","exit":{"_tag":"Failure","cause":[{"_tag":"Fail","error":{"_tag":"FoundationRpcError","message":"Session x was not found"}}]}}"#;
        assert_eq!(exit_value(fail).unwrap_err(), "Session x was not found");
        let die = r#"{"_tag":"Exit","requestId":"1","exit":{"_tag":"Failure","cause":[{"_tag":"Die","defect":"Expected null"}]}}"#;
        assert_eq!(exit_value(die).unwrap_err(), "Expected null");
        assert_eq!(exit_value("\n").unwrap_err(), "the answer has no Exit");
    }

    #[test]
    fn the_final_answer_is_the_last_assistant_text() {
        let entries = json!([
            {"type": "message", "data": {"message": {"role": "user", "content": [{"type": "text", "text": "go"}]}}},
            {"type": "message", "data": {"message": {"role": "assistant", "content": [{"type": "text", "text": "first"}]}}},
            {"type": "message", "data": {"message": {"role": "assistant", "content": [
                {"type": "thinking", "thinking": "hmm"}, {"type": "text", "text": " tate is down.\n"}, {"type": "text", "text": "Fix: power it on."}]}}},
            {"type": "message", "data": {"message": {"role": "assistant", "content": [{"type": "toolCall"}]}}},
            {"type": "custom", "data": {}}
        ]);
        assert_eq!(final_answer(&entries), "tate is down.\n\nFix: power it on.");
        assert_eq!(
            final_answer(&json!([])),
            "The run finished without a final answer."
        );
    }
}
