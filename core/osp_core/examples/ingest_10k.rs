//! Performance smoke test: ingest 10k items and benchmark search queries.

use osp_core::{Core, ItemKind, NewItem};
use std::path::Path;
use std::time::{Duration, Instant};

fn main() {
    println!("🚀 Haste Core Performance Smoke Test");
    println!("=====================================\n");

    // Use a temporary database in /tmp
    let db_path = Path::new("/tmp/haste_perf_test.db");
    let blobs_dir = Path::new("/tmp/haste_perf_blobs");

    // Clean up if exists
    let _ = std::fs::remove_file(db_path);
    let _ = std::fs::remove_dir_all(blobs_dir);

    println!("Opening database...");
    let core = Core::open(db_path, blobs_dir).expect("Failed to open database");

    // Generate 10k mixed items
    println!("Ingesting 10,000 items...");
    let start = Instant::now();

    let sample_texts = [
        "The quick brown fox jumps over the lazy dog",
        "Rust is a systems programming language",
        "SQLite is fast and reliable",
        "Clipboard manager for macOS and Linux",
        "Full-text search with FTS5",
        "Performance optimization techniques",
        "Memory safety without garbage collection",
        "Concurrent programming with channels",
        "Zero-cost abstractions in Rust",
        "Database indexing strategies",
    ];

    for i in 0..10_000 {
        let kind = match i % 4 {
            0 => ItemKind::Text,
            1 => ItemKind::Rtf,
            2 => ItemKind::Image,
            _ => ItemKind::File,
        };

        let content_ref = if matches!(kind, ItemKind::Text | ItemKind::Rtf) {
            let base = sample_texts[i % sample_texts.len()];
            format!("{} - item {}", base, i)
        } else {
            format!("/path/to/resource_{}.dat", i)
        };

        let item = NewItem {
            kind,
            content_ref,
            source_app: Some("perf_test".to_string()),
            created_at: 1_000_000 + i as i64,
            tags: if i % 5 == 0 {
                vec!["important".to_string()]
            } else {
                vec![]
            },
        };

        core.add_item(item).expect("Failed to add item");

        if (i + 1) % 1000 == 0 {
            print!(".");
            std::io::Write::flush(&mut std::io::stdout()).unwrap();
        }
    }

    let ingest_duration = start.elapsed();
    println!("\n✓ Ingested 10,000 items in {:.2}s", ingest_duration.as_secs_f64());
    println!(
        "  Throughput: {:.0} items/sec\n",
        10_000.0 / ingest_duration.as_secs_f64()
    );

    // Run sample queries and measure performance
    let queries = vec![
        ("rust", "Single word"),
        ("quick brown", "Two words"),
        ("programming language", "Common phrase"),
        ("database", "General term"),
        ("optimization", "Long word"),
    ];

    println!("Running search queries (3 runs each)...");
    println!("{:<25} {:>12} {:>12} {:>12}", "Query", "Median", "Min", "Max");
    println!("{}", "-".repeat(65));

    let mut all_medians = Vec::new();

    for (query, description) in queries {
        let mut times = Vec::new();

        for _ in 0..3 {
            let start = Instant::now();
            let results = core.search(query, 100).expect("Search failed");
            let duration = start.elapsed();
            times.push(duration);

            // Sanity check
            if results.is_empty() {
                eprintln!("Warning: No results for query '{}'", query);
            }
        }

        times.sort();
        let median = times[times.len() / 2];
        let min = times[0];
        let max = times[times.len() - 1];

        all_medians.push(median);

        println!(
            "{:<25} {:>10.2}ms {:>10.2}ms {:>10.2}ms",
            description,
            median.as_secs_f64() * 1000.0,
            min.as_secs_f64() * 1000.0,
            max.as_secs_f64() * 1000.0
        );
    }

    // Calculate overall median
    all_medians.sort();
    let overall_median = all_medians[all_medians.len() / 2];

    println!("\n📊 Results Summary:");
    println!("  Overall median latency: {:.2}ms", overall_median.as_secs_f64() * 1000.0);

    // Performance guidance
    if overall_median < Duration::from_millis(50) {
        println!("  ✓ Excellent performance! Well within target.");
    } else if overall_median < Duration::from_millis(100) {
        println!("  ✓ Good performance, within acceptable range.");
    } else {
        println!("  ⚠ Performance is slower than expected (target: <50ms median).");
    }

    println!("\n✨ Test complete!");
    println!("   Database: {:?}", db_path);
    println!("   Size: {} bytes", std::fs::metadata(db_path).unwrap().len());

    // Cleanup
    println!("\nCleaning up test files...");
    let _ = std::fs::remove_file(db_path);
    let _ = std::fs::remove_dir_all(blobs_dir);
}

