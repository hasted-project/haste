//! Core library for Haste clipboard manager.
//!
//! Copyright (C) 2025 Haste Project Contributors
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with this program. If not, see <https://www.gnu.org/licenses/>.
//!
//! Provides SQLite-backed storage with FTS5 full-text search for clipboard items.
//!
//! # Example
//!
//! ```no_run
//! use osp_core::{Core, NewItem, ItemKind};
//! use std::path::Path;
//!
//! let core = Core::open(
//!     Path::new("clipboard.db"),
//!     Path::new("blobs")
//! ).unwrap();
//!
//! let item = NewItem {
//!     kind: ItemKind::Text,
//!     content_ref: "Hello, world!".to_string(),
//!     source_app: Some("terminal".to_string()),
//!     created_at: 1234567890000,
//!     tags: vec![],
//! };
//!
//! let id = core.add_item(item).unwrap();
//! let results = core.search("hello", 10).unwrap();
//! ```

use anyhow::Result;
use std::path::{Path, PathBuf};
use std::sync::Arc;

mod db;
mod models;
mod search;

pub mod ffi;

pub use models::{Item, ItemKind, NewItem};

use db::Database;

/// Main handle to the clipboard storage system.
///
/// Thread-safe and can be cloned cheaply (uses `Arc` internally).
#[derive(Clone)]
pub struct Core {
    db: Arc<Database>,
    #[allow(dead_code)]
    blobs_dir: PathBuf,
}

impl Core {
    /// Open or create a clipboard database at the specified path.
    ///
    /// # Arguments
    ///
    /// * `db_path` - Path to the SQLite database file
    /// * `blobs_dir` - Directory to store blob data (images, files)
    ///
    /// # Example
    ///
    /// ```no_run
    /// use osp_core::Core;
    /// use std::path::Path;
    ///
    /// let core = Core::open(Path::new("clipboard.db"), Path::new("blobs")).unwrap();
    /// ```
    pub fn open(db_path: &Path, blobs_dir: &Path) -> Result<Self> {
        let db = Database::open(db_path)?;

        // Ensure blobs directory exists
        std::fs::create_dir_all(blobs_dir)?;

        Ok(Self {
            db: Arc::new(db),
            blobs_dir: blobs_dir.to_path_buf(),
        })
    }

    /// Add a new item to the clipboard.
    ///
    /// Returns the ID of the newly created item.
    ///
    /// # Example
    ///
    /// ```no_run
    /// use osp_core::{Core, NewItem, ItemKind};
    /// # use std::path::Path;
    /// # let core = Core::open(Path::new("clipboard.db"), Path::new("blobs")).unwrap();
    ///
    /// let item = NewItem {
    ///     kind: ItemKind::Text,
    ///     content_ref: "Hello!".to_string(),
    ///     source_app: None,
    ///     created_at: 1234567890000,
    ///     tags: vec![],
    /// };
    ///
    /// let id = core.add_item(item).unwrap();
    /// ```
    pub fn add_item(&self, item: NewItem) -> Result<i64> {
        self.db.insert_item(&item)
    }

    /// Get an item by ID.
    ///
    /// # Example
    ///
    /// ```no_run
    /// # use osp_core::Core;
    /// # use std::path::Path;
    /// # let core = Core::open(Path::new("clipboard.db"), Path::new("blobs")).unwrap();
    /// let item = core.get(1).unwrap();
    /// println!("Content: {}", item.content_ref);
    /// ```
    pub fn get(&self, id: i64) -> Result<Item> {
        self.db.get_item(id)
    }

    /// Delete an item by ID.
    ///
    /// # Example
    ///
    /// ```no_run
    /// # use osp_core::Core;
    /// # use std::path::Path;
    /// # let core = Core::open(Path::new("clipboard.db"), Path::new("blobs")).unwrap();
    /// core.delete(1).unwrap();
    /// ```
    pub fn delete(&self, id: i64) -> Result<()> {
        self.db.delete_item(id)
    }

    /// Set the pinned status of an item.
    ///
    /// Pinned items can be given special treatment in the UI.
    ///
    /// # Example
    ///
    /// ```no_run
    /// # use osp_core::Core;
    /// # use std::path::Path;
    /// # let core = Core::open(Path::new("clipboard.db"), Path::new("blobs")).unwrap();
    /// core.pin(1, true).unwrap();
    /// ```
    pub fn pin(&self, id: i64, pinned: bool) -> Result<()> {
        self.db.set_pinned(id, pinned)
    }

    /// Search for items matching the query.
    ///
    /// Uses FTS5 full-text search for queries >= 3 characters,
    /// falls back to LIKE for shorter queries.
    ///
    /// # Arguments
    ///
    /// * `query` - Search query string
    /// * `limit` - Maximum number of results to return
    ///
    /// # Example
    ///
    /// ```no_run
    /// # use osp_core::Core;
    /// # use std::path::Path;
    /// # let core = Core::open(Path::new("clipboard.db"), Path::new("blobs")).unwrap();
    /// let results = core.search("rust", 10).unwrap();
    /// for item in results {
    ///     println!("{}: {}", item.id, item.content_ref);
    /// }
    /// ```
    pub fn search(&self, query: &str, limit: u32) -> Result<Vec<Item>> {
        self.db.search(query, limit)
    }

    /// Insert an item only if no duplicate exists.
    ///
    /// Returns `Some(id)` if the item was inserted, `None` if a duplicate exists.
    ///
    /// Deduplication is based on:
    /// - For text/rtf: normalized content (whitespace-collapsed)
    /// - For image/file: exact content_ref path
    ///
    /// # Example
    ///
    /// ```no_run
    /// use osp_core::{Core, NewItem, ItemKind};
    /// # use std::path::Path;
    /// # let core = Core::open(Path::new("clipboard.db"), Path::new("blobs")).unwrap();
    ///
    /// let item = NewItem {
    ///     kind: ItemKind::Text,
    ///     content_ref: "Hello!".to_string(),
    ///     source_app: None,
    ///     created_at: 1234567890000,
    ///     tags: vec![],
    /// };
    ///
    /// match core.dedupe_insert(item) {
    ///     Ok(Some(id)) => println!("Inserted/Updated with ID {}", id),
    ///     Ok(None) => println!("Error occurred"),
    ///     Err(e) => eprintln!("Error: {}", e),
    /// }
    /// ```
    pub fn dedupe_insert(&self, item: NewItem) -> Result<Option<i64>> {
        if self.db.has_duplicate(&item)? {
            // Update timestamp of existing duplicate to "bump" it to the top
            self.db.update_duplicate_timestamp(&item)
        } else {
            Ok(Some(self.db.insert_item(&item)?))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_core_basic_operations() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.db");
        let blobs_dir = dir.path().join("blobs");

        let core = Core::open(&db_path, &blobs_dir).unwrap();

        // Add item
        let item = NewItem {
            kind: ItemKind::Text,
            content_ref: "test content".to_string(),
            source_app: Some("test".to_string()),
            created_at: 1000,
            tags: vec!["tag1".to_string()],
        };

        let id = core.add_item(item).unwrap();
        assert!(id > 0);

        // Get item
        let retrieved = core.get(id).unwrap();
        assert_eq!(retrieved.content_ref, "test content");
        assert_eq!(retrieved.tags, vec!["tag1".to_string()]);
        assert!(!retrieved.pinned);

        // Pin item
        core.pin(id, true).unwrap();
        let retrieved = core.get(id).unwrap();
        assert!(retrieved.pinned);

        // Delete item
        core.delete(id).unwrap();
        assert!(core.get(id).is_err());
    }

    #[test]
    fn test_dedupe() {
        let dir = tempdir().unwrap();
        let db_path = dir.path().join("test.db");
        let blobs_dir = dir.path().join("blobs");

        let core = Core::open(&db_path, &blobs_dir).unwrap();

        let item1 = NewItem {
            kind: ItemKind::Text,
            content_ref: "hello world".to_string(),
            source_app: None,
            created_at: 1000,
            tags: vec![],
        };

        let item2 = NewItem {
            kind: ItemKind::Text,
            content_ref: "  hello   world  ".to_string(),
            source_app: None,
            created_at: 2000,
            tags: vec!["different".to_string()],
        };

        let id1 = core.dedupe_insert(item1).unwrap();
        assert!(id1.is_some(), "First insert should return an ID");

        let id2 = core.dedupe_insert(item2).unwrap();
        // After our timestamp update feature, duplicates return the ID after updating timestamp
        assert!(id2.is_some(), "Duplicate should update timestamp and return ID");
        assert_eq!(id1, id2, "Should return the same ID for duplicate");
    }
}

