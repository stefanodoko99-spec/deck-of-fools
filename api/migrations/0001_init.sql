-- Recovered on 2026-11-21 from the live deck-of-fools D1 database (sqlite_master).
-- Applied to production on 2026-10-21 as 0001_init.sql.

CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE,                    -- lower-case; null for guests and Apple/Google-only players
  email_verified INTEGER NOT NULL DEFAULT 0,
  password_hash TEXT,                   -- pbkdf2$<iterations>$<salt>$<hash>, base64
  apple_sub TEXT UNIQUE,
  google_sub TEXT UNIQUE,
  guest INTEGER NOT NULL DEFAULT 1,     -- 1 until an email, Apple or Google sign-in is linked
  created_at INTEGER NOT NULL
);

CREATE TABLE daily (
  date TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  started_at INTEGER NOT NULL,
  run_id INTEGER,
  PRIMARY KEY (date, user_id)
);

CREATE TABLE limits (
  key TEXT PRIMARY KEY,
  count INTEGER NOT NULL,
  window_start INTEGER NOT NULL
);

CREATE TABLE outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  to_addr TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE runs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seed TEXT NOT NULL,
  deck TEXT NOT NULL,
  stake INTEGER NOT NULL,
  challenge TEXT NOT NULL DEFAULT '',
  daily_date TEXT,                      -- set when this was a ranked daily attempt
  won INTEGER NOT NULL,
  town INTEGER NOT NULL,
  best_hand REAL NOT NULL,
  jesters TEXT NOT NULL,                -- JSON array of the Jester ids held at the end
  actions TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE saves (
  user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  data TEXT NOT NULL,
  device TEXT NOT NULL DEFAULT '',
  updated_at INTEGER NOT NULL
);

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,          -- SHA-256 of the bearer token; the token itself is never stored
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);

CREATE TABLE tokens (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE INDEX runs_best_hand ON runs(best_hand DESC);

CREATE INDEX runs_town ON runs(stake, town DESC);

CREATE INDEX runs_user ON runs(user_id);

CREATE INDEX sessions_user ON sessions(user_id);
