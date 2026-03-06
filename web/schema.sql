-- SavePenguin D1 (SQLite) schema
-- Equivalent to the original MySQL schema in web/subdomains/api/server.php

CREATE TABLE IF NOT EXISTS users (
  user_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid      TEXT UNIQUE NOT NULL,
  created   TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS level_packs (
  level_pack_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  level_pack_path TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS levels (
  level_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  level_path  TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS plays (
  play_id       INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id       INTEGER NOT NULL,
  level_pack_id INTEGER NOT NULL,
  level_id      INTEGER NOT NULL,
  created       TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS scores (
  score_id      INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id       INTEGER NOT NULL,
  level_pack_id INTEGER NOT NULL,
  level_id      INTEGER NOT NULL,
  score         INTEGER NOT NULL DEFAULT 0,
  created       TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS scores_summary (
  score_summary_id INTEGER PRIMARY KEY AUTOINCREMENT,
  level_pack_id    INTEGER NOT NULL,
  level_id         INTEGER NOT NULL,
  total_users      INTEGER DEFAULT 0,
  unique_plays     INTEGER DEFAULT 0,
  total_plays      INTEGER DEFAULT 0,
  unique_wins      INTEGER DEFAULT 0,
  total_wins       INTEGER DEFAULT 0,
  score_mean       INTEGER DEFAULT 0,
  score_median     INTEGER DEFAULT 0,
  score_std_dev    INTEGER DEFAULT 0,
  updating         INTEGER DEFAULT 1,
  created          TEXT DEFAULT (datetime('now')),
  UNIQUE(level_pack_id, level_id, created)
);
