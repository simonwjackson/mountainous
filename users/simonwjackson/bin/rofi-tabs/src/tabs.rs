use serde::ser::{Serialize, SerializeSeq, Serializer};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct BrowserTab {
    pub active: bool,
    pub title: String,
    pub url: String,
    pub id: i32,
}

#[derive(Debug)]
pub struct TabStore {
    pub tabs: Vec<BrowserTab>,
}

impl TabStore {
    pub fn new() -> Self {
        TabStore {
            tabs: Vec::<BrowserTab>::new(),
        }
    }

    pub fn get_by_name(&self, name: &str) -> Result<BrowserTab, TabError> {
        let mut matching = self
            .tabs
            .iter()
            .filter(|t| name.contains(&t.title))
            .cloned()
            .collect::<Vec<BrowserTab>>();

        if matching.len() > 1 {
            warn!("Found multiple tabs with same name: `{}`", name);
        }

        match matching.pop() {
            None => Err(TabError::Missing),
            Some(tab) => Ok(tab),
        }
    }

    // TODO: Use AsRef<str> or something
    pub fn update_from_string(&mut self, string: String) -> Result<(), TabError> {
        self.tabs = parse_json(string)?;
        Ok(())
    }

    pub fn to_string(&self) -> String {
        serde_json::to_string(self)
            .expect("JSON serialisation should not throw an error")
    }

    pub fn clear(&mut self) {
        self.tabs.clear();
    }
}

impl Serialize for TabStore {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        let mut seq = serializer.serialize_seq(Some(self.tabs.len()))?;
        for e in self.tabs.iter() {
            seq.serialize_element(e)?;
        }
        seq.end()
    }
}

pub fn parse_json(json: String) -> Result<Vec<BrowserTab>, TabError> {
    let js: serde_json::Value = serde_json::from_str(&json)?;

    let mut tabs: Vec<BrowserTab> = Vec::new();
    for val in js.as_array().ok_or(TabError::InvalidJSON)?.iter() {
        tabs.push(serde_json::from_value(val.clone())?);
    }
    Ok(tabs)
}

#[derive(Debug)]
pub enum TabError {
    Missing,
    InvalidJSON,
}

impl std::error::Error for TabError {}

impl std::fmt::Display for TabError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl From<serde_json::Error> for TabError {
    fn from(_e: serde_json::Error) -> TabError {
        TabError::InvalidJSON
    }
}
