//! Database connection management and migrations.

use anyhow::{Context, Result};
use parking_lot::Mutex;
use rusqlite::{params, Connection, OptionalExtension};
use std::path::Path;

use crate::models::{Item, ItemKind, NewItem};

/// Database connection wrapper with migrations support.
pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    /// Open or create a database at the specified path and apply migrations.
    pub fn open(db_path: &Path) -> Result<Self> {
        let conn = Connection::open(db_path)
            .with_context(|| format!("Failed to open database at {:?}", db_path))?;

        // Set SQLite pragmas for performance
        conn.execute_batch(
            "PRAGMA journal_mode=WAL;
             PRAGMA synchronous=NORMAL;
             PRAGMA mmap_size=268435456;
             PRAGMA cache_size=-20000;
             PRAGMA foreign_keys=ON;
             PRAGMA temp_store=MEMORY;",
        )
        .context("Failed to set SQLite pragmas")?;

        let db = Self {
            conn: Mutex::new(conn),
        };

        db.apply_migrations()?;
        Ok(db)
    }

    /// Apply all pending migrations.
    fn apply_migrations(&self) -> Result<()> {
        let conn = self.conn.lock();
        let current_version: i32 = conn
            .query_row("PRAGMA user_version", [], |row| row.get(0))
            .context("Failed to get user_version")?;

        let migrations = [include_str!("../migrations/0001_init.sql")];

        for (idx, sql) in migrations.iter().enumerate() {
            let version = idx as i32 + 1;
            if current_version < version {
                conn.execute_batch(sql)
                    .with_context(|| format!("Failed to apply migration {}", version))?;
                conn.execute_batch(&format!("PRAGMA user_version = {};", version))
                    .with_context(|| format!("Failed to update user_version to {}", version))?;
            }
        }

        Ok(())
    }

    /// Insert a new item and return its ID.
    /// Also inserts into FTS if applicable.
    pub fn insert_item(&self, item: &NewItem) -> Result<i64> {
        let conn = self.conn.lock();
        let tx = conn
            .unchecked_transaction()
            .context("Failed to begin transaction")?;

        let tags_json = serde_json::to_string(&item.tags).context("Failed to serialize tags")?;

        tx.execute(
            "INSERT INTO items (kind, content_ref, source_app, created_at, pinned, tags)
             VALUES (?1, ?2, ?3, ?4, 0, ?5)",
            params![
                item.kind.as_str(),
                &item.content_ref,
                &item.source_app,
                item.created_at,
                tags_json,
            ],
        )
        .context("Failed to insert item")?;

        let item_id = tx.last_insert_rowid();

        // Insert into FTS for text/rtf items
        if matches!(item.kind, ItemKind::Text | ItemKind::Rtf) {
            tx.execute(
                "INSERT INTO items_fts (item_id, text) VALUES (?1, ?2)",
                params![item_id, &item.content_ref],
            )
            .context("Failed to insert into FTS")?;
        }

        tx.commit().context("Failed to commit transaction")?;
        Ok(item_id)
    }


    /// Get an item by ID.
    pub fn get_item(&self, id: i64) -> Result<Item> {
        let conn = self.conn.lock();
        let mut stmt = conn
            .prepare("SELECT id, kind, content_ref, source_app, created_at, pinned, tags FROM items WHERE id = ?1")
            .context("Failed to prepare statement")?;

            let item = stmt
            .query_row(params![id], |row| {
                let kind_str: String = row.get(1)?;
                let tags_json: String = row.get(6)?;
                let tags: Vec<String> = serde_json::from_str(&tags_json).unwrap_or_default();

                Ok(Item {
                    id: row.get(0)?,
                    kind: kind_str.parse().unwrap(),
                    content_ref: row.get(2)?,
                    source_app: row.get(3)?,
                    created_at: row.get(4)?,
                    pinned: row.get::<_, i32>(5)? != 0,
                    tags,
                })
            })
            .context("Item not found")?;

        Ok(item)
    }

    /// Delete an item by ID.
    pub fn delete_item(&self, id: i64) -> Result<()> {
        let conn = self.conn.lock();
        let tx = conn
            .unchecked_transaction()
            .context("Failed to begin transaction")?;

        // Delete from FTS first
        tx.execute(
            "DELETE FROM items_fts WHERE item_id = ?1",
            params![id],
        )
        .context("Failed to delete from FTS")?;

        let rows = tx
            .execute("DELETE FROM items WHERE id = ?1", params![id])
            .context("Failed to delete item")?;

        if rows == 0 {
            anyhow::bail!("Item not found");
        }

        tx.commit().context("Failed to commit transaction")?;
        Ok(())
    }

    /// Set the pinned status of an item.
    pub fn set_pinned(&self, id: i64, pinned: bool) -> Result<()> {
        let conn = self.conn.lock();
        let rows = conn
            .execute(
                "UPDATE items SET pinned = ?1 WHERE id = ?2",
                params![if pinned { 1 } else { 0 }, id],
            )
            .context("Failed to update pinned status")?;

        if rows == 0 {
            anyhow::bail!("Item not found");
        }

        Ok(())
    }

    /// Search items using FTS5 or LIKE for short queries.
    pub fn search(&self, query: &str, limit: u32) -> Result<Vec<Item>> {
        let conn = self.conn.lock();

        if query.len() < 3 {
            // Use LIKE for short queries
            let pattern = format!("%{}%", query);
            let mut stmt = conn.prepare(
                "SELECT id, kind, content_ref, source_app, created_at, pinned, tags
                 FROM items
                 WHERE content_ref LIKE ?1
                 ORDER BY created_at DESC
                 LIMIT ?2",
            )?;

            let items = stmt
                .query_map(params![pattern, limit], Self::row_to_item)?
                .collect::<Result<Vec<_>, _>>()
                .context("Failed to fetch search results")?;

            return Ok(items);
        }

        // Use FTS5 for longer queries
        let mut stmt = conn.prepare(
            "SELECT i.id, i.kind, i.content_ref, i.source_app, i.created_at, i.pinned, i.tags
             FROM items i
             INNER JOIN items_fts fts ON fts.item_id = i.id
             WHERE items_fts MATCH ?1
             ORDER BY fts.rank, i.created_at DESC
             LIMIT ?2",
        )?;

        let items = stmt
            .query_map(params![query, limit], Self::row_to_item)?
            .collect::<Result<Vec<_>, _>>()
            .context("Failed to fetch FTS search results")?;

        Ok(items)
    }

    /// Helper to convert a row to an Item.
    fn row_to_item(row: &rusqlite::Row) -> rusqlite::Result<Item> {
        let kind_str: String = row.get(1)?;
        let tags_json: String = row.get(6)?;
        let tags: Vec<String> = serde_json::from_str(&tags_json).unwrap_or_default();

        Ok(Item {
            id: row.get(0)?,
            kind: kind_str.parse().unwrap(),
            content_ref: row.get(2)?,
            source_app: row.get(3)?,
            created_at: row.get(4)?,
            pinned: row.get::<_, i32>(5)? != 0,
            tags,
        })
    }

    /// Check for duplicate by computing hash and checking existing items.
    /// This is a simple implementation; returns true if duplicate exists.
    pub fn has_duplicate(&self, new_item: &NewItem) -> Result<bool> {
        let conn = self.conn.lock();

        // For text items, check normalized content
        if matches!(new_item.kind, ItemKind::Text | ItemKind::Rtf) {
            let normalized = new_item.normalized_text();
            let mut stmt = conn.prepare(
                "SELECT id FROM items WHERE kind = ?1 AND content_ref = ?2 LIMIT 1",
            )?;

            let exists = stmt
                .query_row(params![new_item.kind.as_str(), normalized], |_| Ok(()))
                .optional()?
                .is_some();

            return Ok(exists);
        }

        // For image/file items, check exact content_ref
        let mut stmt = conn.prepare(
            "SELECT id FROM items WHERE kind = ?1 AND content_ref = ?2 LIMIT 1",
        )?;

        let exists = stmt
            .query_row(
                params![new_item.kind.as_str(), &new_item.content_ref],
                |_| Ok(()),
            )
            .optional()?
            .is_some();

        Ok(exists)
    }
    
    /// Update the timestamp of an existing duplicate item to "bump" it to the top.
    /// Returns the ID of the updated item if found, None otherwise.
    pub fn update_duplicate_timestamp(&self, new_item: &NewItem) -> Result<Option<i64>> {
        let conn = self.conn.lock();
        
        // Find the duplicate item
        let id: Option<i64> = if matches!(new_item.kind, ItemKind::Text | ItemKind::Rtf) {
            let normalized = new_item.normalized_text();
            conn.query_row(
                "SELECT id FROM items WHERE kind = ?1 AND content_ref = ?2 LIMIT 1",
                params![new_item.kind.as_str(), normalized],
                |row| row.get(0)
            ).optional()?
        } else {
            conn.query_row(
                "SELECT id FROM items WHERE kind = ?1 AND content_ref = ?2 LIMIT 1",
                params![new_item.kind.as_str(), &new_item.content_ref],
                |row| row.get(0)
            ).optional()?
        };
        
        if let Some(item_id) = id {
            // Update the timestamp
            conn.execute(
                "UPDATE items SET created_at = ?1 WHERE id = ?2",
                params![new_item.created_at, item_id],
            )?;
            Ok(Some(item_id))
        } else {
            Ok(None)
        }
    }
}

