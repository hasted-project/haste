-- Initial schema for clipboard items and full-text search

CREATE TABLE items(
  id INTEGER PRIMARY KEY,
  kind TEXT NOT NULL CHECK(kind IN ('text','rtf','image','file')),
  content_ref TEXT NOT NULL,
  source_app TEXT,
  created_at INTEGER NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0,
  tags TEXT NOT NULL DEFAULT '[]'
);

CREATE INDEX idx_items_created_at ON items(created_at DESC);
CREATE INDEX idx_items_kind ON items(kind);

-- FTS for text content (and rtf extracted text)
CREATE VIRTUAL TABLE items_fts USING fts5(
  item_id UNINDEXED,
  text,
  tokenize='unicode61 remove_diacritics 2'
);

