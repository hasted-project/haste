//! Full-text search implementation using SQLite FTS5.
//!
//! This module provides helper functions for search functionality,
//! though the main search logic is currently in db.rs for simplicity.

use anyhow::{Context, Result};
use rusqlite::{params, Connection};

use crate::models::Item;

#[allow(dead_code)]
fn search_with_like(conn: &Connection, query: &str, limit: u32) -> Result<Vec<Item>> {
    let pattern = format!("%{}%", query);
    let mut stmt = conn.prepare(
        "SELECT id, kind, content_ref, source_app, created_at, pinned, tags
         FROM items
         WHERE content_ref LIKE ?1
         ORDER BY created_at DESC
         LIMIT ?2",
    )?;

    let items = stmt
        .query_map(params![pattern, limit], row_to_item)?
        .collect::<Result<Vec<_>, _>>()
        .context("Failed to fetch LIKE search results")?;

    Ok(items)
}

#[allow(dead_code)]
fn search_with_fts(conn: &Connection, query: &str, limit: u32) -> Result<Vec<Item>> {
    let mut stmt = conn.prepare(
        "SELECT i.id, i.kind, i.content_ref, i.source_app, i.created_at, i.pinned, i.tags
         FROM items i
         INNER JOIN items_fts fts ON fts.item_id = i.id
         WHERE items_fts MATCH ?1
         ORDER BY fts.rank, i.created_at DESC
         LIMIT ?2",
    )?;

    let items = stmt
        .query_map(params![query, limit], row_to_item)?
        .collect::<Result<Vec<_>, _>>()
        .context("Failed to fetch FTS search results")?;

    Ok(items)
}

/// Helper to convert a row to an Item.
#[allow(dead_code)]
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

