//! Data models for clipboard items.

use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::str::FromStr;

/// Type of clipboard item.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ItemKind {
    Text,
    Rtf,
    Image,
    File,
}

impl ItemKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            ItemKind::Text => "text",
            ItemKind::Rtf => "rtf",
            ItemKind::Image => "image",
            ItemKind::File => "file",
        }
    }
}

impl FromStr for ItemKind {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "text" => Ok(ItemKind::Text),
            "rtf" => Ok(ItemKind::Rtf),
            "image" => Ok(ItemKind::Image),
            "file" => Ok(ItemKind::File),
            _ => Err(format!("Invalid item kind: {}", s)),
        }
    }
}

/// A stored clipboard item.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Item {
    pub id: i64,
    pub kind: ItemKind,
    pub content_ref: String,
    pub source_app: Option<String>,
    pub created_at: i64,
    pub pinned: bool,
    pub tags: Vec<String>,
}

/// A new item to be inserted.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewItem {
    pub kind: ItemKind,
    pub content_ref: String,
    pub source_app: Option<String>,
    pub created_at: i64,
    pub tags: Vec<String>,
}

impl NewItem {
    /// Normalize text content for deduplication.
    /// Trims whitespace and collapses multiple spaces/newlines.
    pub fn normalized_text(&self) -> String {
        self.content_ref
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
    }

    /// Compute a stable hash for deduplication.
    /// For text/rtf items, hash the normalized content.
    /// For image/file items, hash the content_ref path.
    pub fn dedupe_hash(&self) -> u64 {
        let mut hasher = DefaultHasher::new();
        self.kind.as_str().hash(&mut hasher);

        match self.kind {
            ItemKind::Text | ItemKind::Rtf => {
                self.normalized_text().hash(&mut hasher);
            }
            ItemKind::Image | ItemKind::File => {
                self.content_ref.hash(&mut hasher);
            }
        }

        hasher.finish()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalize_text() {
        let item = NewItem {
            kind: ItemKind::Text,
            content_ref: "  hello   world  \n\n  test  ".to_string(),
            source_app: None,
            created_at: 0,
            tags: vec![],
        };
        assert_eq!(item.normalized_text(), "hello world test");
    }

    #[test]
    fn test_dedupe_hash_consistency() {
        let item1 = NewItem {
            kind: ItemKind::Text,
            content_ref: "hello world".to_string(),
            source_app: None,
            created_at: 0,
            tags: vec![],
        };
        let item2 = NewItem {
            kind: ItemKind::Text,
            content_ref: "  hello   world  ".to_string(),
            source_app: None,
            created_at: 100,
            tags: vec!["tag".to_string()],
        };
        assert_eq!(item1.dedupe_hash(), item2.dedupe_hash());
    }
}

