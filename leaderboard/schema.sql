CREATE TABLE IF NOT EXISTS scores (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  score INTEGER NOT NULL,
  table_id TEXT NOT NULL,
  version TEXT NOT NULL DEFAULT '',
  ip_hash TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS scores_by_score ON scores (score DESC);
CREATE INDEX IF NOT EXISTS scores_by_table ON scores (table_id, score DESC);
CREATE INDEX IF NOT EXISTS scores_by_ip ON scores (ip_hash, created_at);
