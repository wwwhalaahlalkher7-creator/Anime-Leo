-- V1.22.0 automatic background catalog synchronization.
CREATE TABLE IF NOT EXISTS catalog_sync_state (
  stream TEXT PRIMARY KEY,
  page INTEGER NOT NULL DEFAULT 1,
  last_run_at TEXT,
  last_success_at TEXT,
  total_upserted INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);

INSERT OR IGNORE INTO catalog_sync_state (stream, page, total_upserted)
VALUES
  ('popularity', 1, 0),
  ('latest', 1, 0);
