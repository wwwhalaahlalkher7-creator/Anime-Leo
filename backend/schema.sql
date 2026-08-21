PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS anime (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  external_id TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  title_ar TEXT,
  synopsis TEXT,
  image_url TEXT,
  genres_json TEXT NOT NULL DEFAULT '[]',
  status TEXT,
  episodes INTEGER,
  score REAL,
  year INTEGER,
  type TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- D1 stores completed anime as an archive. Ongoing titles are served live.
CREATE INDEX IF NOT EXISTS idx_anime_title ON anime(title);
CREATE INDEX IF NOT EXISTS idx_anime_score ON anime(score DESC);
CREATE INDEX IF NOT EXISTS idx_anime_year ON anime(year DESC);

CREATE TABLE IF NOT EXISTS episodes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  external_id TEXT NOT NULL UNIQUE,
  anime_external_id TEXT NOT NULL,
  episode_number INTEGER NOT NULL,
  title TEXT,
  thumbnail TEXT,
  duration TEXT,
  aired TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (anime_external_id) REFERENCES anime(external_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_episodes_anime ON episodes(anime_external_id, episode_number);

CREATE TABLE IF NOT EXISTS providers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO providers (name, type, status) VALUES ('jikan', 'metadata', 'active');

CREATE TABLE IF NOT EXISTS analytics_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event TEXT NOT NULL,
  app_version TEXT,
  platform TEXT,
  anonymous_id TEXT,
  parameters_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_analytics_event_created ON analytics_events(event, created_at);


CREATE TABLE IF NOT EXISTS rate_limits (
  key TEXT PRIMARY KEY,
  window_started TEXT NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_window ON rate_limits(window_started);


CREATE TABLE IF NOT EXISTS catalog_sync_state (
  stream TEXT PRIMARY KEY,
  page INTEGER NOT NULL DEFAULT 1,
  last_run_at TEXT,
  last_success_at TEXT,
  total_upserted INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
);

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
