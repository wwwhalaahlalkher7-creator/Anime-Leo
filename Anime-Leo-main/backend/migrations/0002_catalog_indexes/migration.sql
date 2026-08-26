-- V1.9 catalog and operational indexes.
CREATE INDEX IF NOT EXISTS idx_anime_title_ar ON anime(title_ar);
CREATE INDEX IF NOT EXISTS idx_anime_score_year ON anime(score DESC, year DESC);
CREATE INDEX IF NOT EXISTS idx_episodes_anime_number ON episodes(anime_external_id, episode_number);
CREATE INDEX IF NOT EXISTS idx_episodes_external_anime ON episodes(external_id, anime_external_id);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window_key ON rate_limits(window_started, key);
CREATE INDEX IF NOT EXISTS idx_analytics_created_event ON analytics_events(created_at, event);
