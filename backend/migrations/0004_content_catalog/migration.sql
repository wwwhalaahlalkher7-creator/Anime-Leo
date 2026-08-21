-- V1.24.0 content catalog for Arabic-capable manga and animated-show sections.
CREATE TABLE IF NOT EXISTS content_catalog (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL,
  external_id TEXT NOT NULL,
  title TEXT NOT NULL,
  title_ar TEXT,
  synopsis TEXT,
  image_url TEXT,
  score REAL,
  year INTEGER,
  type TEXT,
  source TEXT NOT NULL,
  source_url TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(kind, external_id)
);

CREATE INDEX IF NOT EXISTS idx_content_kind_score ON content_catalog(kind, score DESC, year DESC);
CREATE INDEX IF NOT EXISTS idx_content_kind_title ON content_catalog(kind, title);

INSERT OR IGNORE INTO catalog_sync_state (stream, page, total_upserted) VALUES ('manga', 1, 0), ('animation', 1, 0);
