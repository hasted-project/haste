//! Interactive playground to test the Core API.
//!
//! Run with: cargo run -p osp_core --example playground

use osp_core::{Core, ItemKind, NewItem};
use std::path::Path;

fn main() -> anyhow::Result<()> {
    println!("🎮 Haste Core API Playground\n");

    // Create a test database
    let db_path = Path::new("/tmp/haste_playground.db");
    let blobs_dir = Path::new("/tmp/haste_blobs");

    // Clean up previous runs
    let _ = std::fs::remove_file(db_path);
    let _ = std::fs::remove_dir_all(blobs_dir);

    println!("📂 Opening database at {:?}\n", db_path);
    let core = Core::open(db_path, blobs_dir)?;

    // Add some test items
    println!("➕ Adding test items...");
    let items = [
        ("Hello, world!", ItemKind::Text, vec!["greeting"]),
        ("Rust is amazing!", ItemKind::Text, vec!["programming"]),
        ("SQLite FTS5 is fast", ItemKind::Text, vec!["database"]),
        ("{\\rtf1 Rich text}", ItemKind::Rtf, vec![]),
        ("/path/to/image.png", ItemKind::Image, vec!["photo"]),
        ("/path/to/document.pdf", ItemKind::File, vec!["document"]),
    ];

    let mut ids = Vec::new();
    for (content, kind, tags) in items {
        let item = NewItem {
            kind,
            content_ref: content.to_string(),
            source_app: Some("playground".to_string()),
            created_at: chrono::Utc::now().timestamp_millis(),
            tags: tags.iter().map(|s| s.to_string()).collect(),
        };

        let id = core.add_item(item)?;
        ids.push(id);
        println!("  ✓ Added {} (ID: {})", content, id);
    }

    // Pin an item
    println!("\n📌 Pinning item {}...", ids[0]);
    core.pin(ids[0], true)?;

    // Search
    println!("\n🔍 Searching for 'rust'...");
    let results = core.search("rust", 10)?;
    println!("  Found {} result(s):", results.len());
    for item in &results {
        println!("    - [{}] {} (pinned: {})", item.id, item.content_ref, item.pinned);
    }

    // Search for 'fast'
    println!("\n🔍 Searching for 'fast'...");
    let results = core.search("fast", 10)?;
    println!("  Found {} result(s):", results.len());
    for item in &results {
        println!("    - [{}] {}", item.id, item.content_ref);
    }

    // Get a specific item
    println!("\n📖 Getting item {}...", ids[0]);
    let item = core.get(ids[0])?;
    println!("  Content: {}", item.content_ref);
    println!("  Kind: {:?}", item.kind);
    println!("  Pinned: {}", item.pinned);
    println!("  Tags: {:?}", item.tags);

    // Test deduplication
    println!("\n🔄 Testing deduplication...");
    let duplicate = NewItem {
        kind: ItemKind::Text,
        content_ref: "  Hello,   world!  ".to_string(), // Same as first item
        source_app: None,
        created_at: chrono::Utc::now().timestamp_millis(),
        tags: vec![],
    };

    match core.dedupe_insert(duplicate)? {
        Some(id) => println!("  ✗ Inserted (should have detected duplicate!): {}", id),
        None => println!("  ✓ Duplicate detected, insert skipped"),
    }

    // Delete an item
    println!("\n🗑️  Deleting item {}...", ids[2]);
    core.delete(ids[2])?;
    println!("  ✓ Deleted");

    // Search again to verify deletion
    println!("\n🔍 Searching for 'fast' after deletion...");
    let results = core.search("fast", 10)?;
    println!("  Found {} result(s) (should be 0)", results.len());

    println!("\n✨ Playground complete!");
    println!("   Database: {:?}", db_path);
    println!("   You can inspect it with: sqlite3 {}", db_path.display());

    Ok(())
}

