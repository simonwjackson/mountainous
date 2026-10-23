//! What arrives on the notify topic, and the signal made from it.

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use serde::{Deserialize, Serialize};

/// One line of ntfy's JSON stream. Only the fields this service reads.
#[derive(Debug, Clone, Deserialize)]
pub struct NtfyMessage {
    pub id: String,
    pub time: u64,
    pub event: String,
    #[serde(default)]
    pub sequence_id: Option<String>,
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub message: Option<String>,
    #[serde(default)]
    pub tags: Vec<String>,
}

impl NtfyMessage {
    /// The notification's identity across updates and clears.
    pub fn seq(&self) -> &str {
        self.sequence_id.as_deref().unwrap_or(&self.id)
    }

    /// The sender metadata that the notify CLI puts in an `ns1_` tag
    /// (packages/notify-sync/types.go). `None` when there is no such tag.
    pub fn sender(&self) -> Option<Sender> {
        self.tags.iter().find_map(|tag| {
            let encoded = tag.strip_prefix("ns1_")?;
            let bytes = URL_SAFE_NO_PAD.decode(encoded).ok()?;
            serde_json::from_slice(&bytes).ok()
        })
    }
}

/// `{"h": name, "a": app, "g": agent}` from notify-sync.
#[derive(Debug, Clone, Deserialize)]
pub struct Sender {
    /// `notify send --name` for an agent sender, else the desktop's host.
    #[serde(rename = "h", default)]
    pub name: String,
    /// True only for `notify send`. Desktop popups mirrored to ntfy are false.
    #[serde(rename = "g", default)]
    pub agent: bool,
}

/// A firing alert, in the form every source shares.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Signal {
    /// The rule that matched, such as `beszel` or `storage`.
    pub source: String,
    /// The sender's `--name`.
    pub sender: String,
    /// `source` plus the title: one triage per key per cool-down.
    pub key: String,
    pub title: String,
    /// Untrusted text from the sender.
    pub body: String,
    pub seq: String,
    /// ntfy's time for the message, in Unix seconds.
    pub at: u64,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn message(tags: Vec<String>) -> NtfyMessage {
        NtfyMessage {
            id: "abc".into(),
            time: 1,
            event: "message".into(),
            sequence_id: None,
            title: None,
            message: None,
            tags,
        }
    }

    #[test]
    fn reads_the_notify_sender_tag() {
        let tag = format!(
            "ns1_{}",
            URL_SAFE_NO_PAD.encode(br#"{"h":"beszel","a":"agent","r":false,"l":true,"g":true}"#)
        );
        let sender = message(vec!["x".into(), tag]).sender().unwrap();
        assert_eq!(sender.name, "beszel");
        assert!(sender.agent);
    }

    #[test]
    fn no_tag_means_no_sender() {
        assert!(message(vec![]).sender().is_none());
        assert!(message(vec!["ns1_!!".into()]).sender().is_none());
    }

    #[test]
    fn seq_prefers_sequence_id() {
        let mut m = message(vec![]);
        assert_eq!(m.seq(), "abc");
        m.sequence_id = Some("agent-beszel-1".into());
        assert_eq!(m.seq(), "agent-beszel-1");
    }
}
