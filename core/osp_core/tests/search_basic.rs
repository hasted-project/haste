//! Comprehensive tests for search functionality.

use osp_core::{Core, ItemKind, NewItem};
use tempfile::tempdir;

#[test]
fn test_search_text_items() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    // Insert test items
    let items = [
        "The quick brown fox jumps over the lazy dog",
        "Rust programming language is fast and safe",
        "SQLite is a lightweight database",
        "Full-text search with FTS5",
        "Clipboard manager for macOS",
    ];

    for (i, content) in items.iter().enumerate() {
        let item = NewItem {
            kind: ItemKind::Text,
            content_ref: content.to_string(),
            source_app: Some("test".to_string()),
            created_at: 1000 + i as i64,
            tags: vec![],
        };
        core.add_item(item).unwrap();
    }

    // Search for "rust"
    let results = core.search("rust", 10).unwrap();
    assert_eq!(results.len(), 1);
    assert!(results[0].content_ref.contains("Rust"));

    // Search for "quick"
    let results = core.search("quick", 10).unwrap();
    assert_eq!(results.len(), 1);
    assert!(results[0].content_ref.contains("quick"));

    // Search for "database" or "search"
    let results = core.search("database", 10).unwrap();
    assert_eq!(results.len(), 1);

    let results = core.search("search", 10).unwrap();
    assert_eq!(results.len(), 1);
}

#[test]
fn test_search_short_query() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    // Insert items with short content
    core.add_item(NewItem {
        kind: ItemKind::Text,
        content_ref: "ab test".to_string(),
        source_app: None,
        created_at: 1000,
        tags: vec![],
    })
    .unwrap();

    core.add_item(NewItem {
        kind: ItemKind::Text,
        content_ref: "xyz test".to_string(),
        source_app: None,
        created_at: 1001,
        tags: vec![],
    })
    .unwrap();

    // Short query (< 3 chars) should use LIKE
    let results = core.search("ab", 10).unwrap();
    assert_eq!(results.len(), 1);
    assert!(results[0].content_ref.contains("ab"));
}

#[test]
fn test_search_limit() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    // Insert 20 items with "test" in content
    for i in 0..20 {
        core.add_item(NewItem {
            kind: ItemKind::Text,
            content_ref: format!("test item {}", i),
            source_app: None,
            created_at: 1000 + i,
            tags: vec![],
        })
        .unwrap();
    }

    // Search with limit of 5
    let results = core.search("test", 5).unwrap();
    assert_eq!(results.len(), 5);

    // Search with limit of 10
    let results = core.search("test", 10).unwrap();
    assert_eq!(results.len(), 10);

    // Search with limit of 100 (should return all 20)
    let results = core.search("test", 100).unwrap();
    assert_eq!(results.len(), 20);
}

#[test]
fn test_search_order_by_recency() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    // Insert items with different timestamps
    let id1 = core
        .add_item(NewItem {
            kind: ItemKind::Text,
            content_ref: "searchable content old".to_string(),
            source_app: None,
            created_at: 1000,
            tags: vec![],
        })
        .unwrap();

    let id2 = core
        .add_item(NewItem {
            kind: ItemKind::Text,
            content_ref: "searchable content new".to_string(),
            source_app: None,
            created_at: 2000,
            tags: vec![],
        })
        .unwrap();

    // Search should return newer items first (for LIKE queries)
    let results = core.search("se", 10).unwrap();
    assert_eq!(results.len(), 2);
    assert_eq!(results[0].id, id2); // Newer item first
    assert_eq!(results[1].id, id1);
}

#[test]
fn test_pin_unpin() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    let id = core
        .add_item(NewItem {
            kind: ItemKind::Text,
            content_ref: "test".to_string(),
            source_app: None,
            created_at: 1000,
            tags: vec![],
        })
        .unwrap();

    // Initially not pinned
    let item = core.get(id).unwrap();
    assert!(!item.pinned);

    // Pin it
    core.pin(id, true).unwrap();
    let item = core.get(id).unwrap();
    assert!(item.pinned);

    // Unpin it
    core.pin(id, false).unwrap();
    let item = core.get(id).unwrap();
    assert!(!item.pinned);
}

#[test]
fn test_delete_behavior() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    let id = core
        .add_item(NewItem {
            kind: ItemKind::Text,
            content_ref: "delete me".to_string(),
            source_app: None,
            created_at: 1000,
            tags: vec![],
        })
        .unwrap();

    // Item exists
    assert!(core.get(id).is_ok());

    // Delete it
    core.delete(id).unwrap();

    // Item no longer exists
    assert!(core.get(id).is_err());

    // Search shouldn't find it
    let results = core.search("delete", 10).unwrap();
    assert_eq!(results.len(), 0);

    // Deleting again should fail
    assert!(core.delete(id).is_err());
}

#[test]
fn test_dedupe_behavior() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    // Insert first item
    let item1 = NewItem {
        kind: ItemKind::Text,
        content_ref: "hello world".to_string(),
        source_app: None,
        created_at: 1000,
        tags: vec![],
    };

    let id1 = core.dedupe_insert(item1).unwrap();
    assert!(id1.is_some(), "First insert should return an ID");

    // Try to insert duplicate (with different whitespace)
    let item2 = NewItem {
        kind: ItemKind::Text,
        content_ref: "  hello   world  ".to_string(),
        source_app: Some("different".to_string()),
        created_at: 2000,
        tags: vec!["tag".to_string()],
    };

    let id2 = core.dedupe_insert(item2).unwrap();
    // After our timestamp update feature, duplicates return the ID after updating timestamp
    assert!(id2.is_some(), "Duplicate should update timestamp and return ID");
    assert_eq!(id1, id2, "Should return the same ID for duplicate");

    // Different content should insert
    let item3 = NewItem {
        kind: ItemKind::Text,
        content_ref: "different content".to_string(),
        source_app: None,
        created_at: 3000,
        tags: vec![],
    };

    let id3 = core.dedupe_insert(item3).unwrap();
    assert!(id3.is_some());
}

#[test]
fn test_rtf_items() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    // Insert RTF item (in reality would be RTF markup, but we'll use plain text for testing)
    let id = core
        .add_item(NewItem {
            kind: ItemKind::Rtf,
            content_ref: "Rich text format content with styling".to_string(),
            source_app: None,
            created_at: 1000,
            tags: vec![],
        })
        .unwrap();

    // Should be searchable via FTS
    let results = core.search("rich", 10).unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, id);
    assert_eq!(results[0].kind, ItemKind::Rtf);
}

#[test]
fn test_mixed_item_types() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    // Insert various types
    core.add_item(NewItem {
        kind: ItemKind::Text,
        content_ref: "text content".to_string(),
        source_app: None,
        created_at: 1000,
        tags: vec![],
    })
    .unwrap();

    core.add_item(NewItem {
        kind: ItemKind::Rtf,
        content_ref: "rtf content".to_string(),
        source_app: None,
        created_at: 1001,
        tags: vec![],
    })
    .unwrap();

    core.add_item(NewItem {
        kind: ItemKind::Image,
        content_ref: "/path/to/image.png".to_string(),
        source_app: None,
        created_at: 1002,
        tags: vec![],
    })
    .unwrap();

    core.add_item(NewItem {
        kind: ItemKind::File,
        content_ref: "/path/to/file.pdf".to_string(),
        source_app: None,
        created_at: 1003,
        tags: vec![],
    })
    .unwrap();

    // Search should only find text/rtf items
    let results = core.search("content", 10).unwrap();
    assert_eq!(results.len(), 2);
    assert!(matches!(results[0].kind, ItemKind::Text | ItemKind::Rtf));
    assert!(matches!(results[1].kind, ItemKind::Text | ItemKind::Rtf));
}

#[test]
fn test_tags() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    let core = Core::open(&db_path, &blobs_dir).unwrap();

    let id = core
        .add_item(NewItem {
            kind: ItemKind::Text,
            content_ref: "tagged content".to_string(),
            source_app: None,
            created_at: 1000,
            tags: vec!["work".to_string(), "important".to_string()],
        })
        .unwrap();

    let item = core.get(id).unwrap();
    assert_eq!(item.tags.len(), 2);
    assert!(item.tags.contains(&"work".to_string()));
    assert!(item.tags.contains(&"important".to_string()));
}

#[test]
fn test_migration_idempotent() {
    let dir = tempdir().unwrap();
    let db_path = dir.path().join("test.db");
    let blobs_dir = dir.path().join("blobs");

    // Open database first time
    let core1 = Core::open(&db_path, &blobs_dir).unwrap();
    let id = core1
        .add_item(NewItem {
            kind: ItemKind::Text,
            content_ref: "test".to_string(),
            source_app: None,
            created_at: 1000,
            tags: vec![],
        })
        .unwrap();

    drop(core1);

    // Reopen database - should not re-apply migrations
    let core2 = Core::open(&db_path, &blobs_dir).unwrap();
    let item = core2.get(id).unwrap();
    assert_eq!(item.content_ref, "test");
}

