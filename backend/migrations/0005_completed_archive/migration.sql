-- D1 is an archive for completed anime only.
-- Ongoing / unaired rows must remain live-provider driven.
DELETE FROM episodes
WHERE anime_external_id IN (
  SELECT external_id
  FROM anime
  WHERE status IS NULL
     OR LOWER(TRIM(status)) NOT IN ('finished airing', 'finished', 'completed', 'complete')
);

DELETE FROM anime
WHERE status IS NULL
   OR LOWER(TRIM(status)) NOT IN ('finished airing', 'finished', 'completed', 'complete');

CREATE INDEX IF NOT EXISTS idx_anime_completed
  ON anime(external_id)
  WHERE LOWER(TRIM(status)) IN ('finished airing', 'finished', 'completed', 'complete');
