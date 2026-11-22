-- The Playbill (news, What's new, banners) and the inbox of letters (wave 1).
-- How to add rows in production: docs/LIVE_OPS.md. Times are unix seconds (UTC).
-- Apply this before deploying the API code that reads these tables: account deletion
-- also clears letter_claims and personal letters.

-- One row per card on the Playbill. 'whats_new' is shown once after an update,
-- 'banner' also appears on the home screen (up to three), 'news' only on the Playbill.
CREATE TABLE news (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL CHECK (kind IN ('news', 'whats_new', 'banner')),
  title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 80),
  body TEXT NOT NULL DEFAULT '' CHECK (length(body) <= 600),
  -- '' (the kind's own colour), a palette name, or '#rrggbb'. (D1 refuses long GLOB
  -- patterns, so the hex digits are checked with a short one.)
  colour TEXT NOT NULL DEFAULT '' CHECK (colour IN ('', 'gold', 'orange', 'red', 'pink', 'purple', 'blue', 'teal', 'green')
    OR (length(colour) = 7 AND substr(colour, 1, 1) = '#' AND lower(substr(colour, 2)) NOT GLOB '*[^0-9a-f]*')),
  -- What the card's one button does: '' (no button), 'shop', 'collection', 'daily' or an https:// link.
  action TEXT NOT NULL DEFAULT '' CHECK (action IN ('', 'shop', 'collection', 'daily')
    OR (action LIKE 'https://%' AND length(action) <= 300)),
  -- For 'whats_new': the game version it describes ('1.2'); builds that know they are older don't show it.
  version TEXT NOT NULL DEFAULT '' CHECK (length(version) <= 20),
  starts_at INTEGER NOT NULL,           -- shown from this moment
  ends_at INTEGER,                      -- hidden from this moment; NULL = stays up
  created_at INTEGER NOT NULL
);

CREATE INDEX news_starts ON news(starts_at DESC);

-- A letter in the inbox: a message, with coins to claim when coins > 0.
CREATE TABLE letters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,   -- NULL = a letter for everyone
  title TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 80),
  body TEXT NOT NULL DEFAULT '' CHECK (length(body) <= 600),
  coins INTEGER NOT NULL DEFAULT 0 CHECK (coins BETWEEN 0 AND 5000),   -- coins only: diamonds are never given away by letter
  created_at INTEGER NOT NULL,          -- delivered from this moment (a future time schedules it)
  expires_at INTEGER                    -- gone from this moment; NULL = never
);

CREATE INDEX letters_user ON letters(user_id);

-- Who claimed which letter. The primary key makes a claim happen once per account however
-- often it is sent; claim_key is the client's key for the call that claimed it, so a repeat
-- of that same call (its answer was lost) gets the same answer again.
CREATE TABLE letter_claims (
  letter_id INTEGER NOT NULL REFERENCES letters(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  claimed_at INTEGER NOT NULL,
  claim_key TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (letter_id, user_id)
);

CREATE INDEX letter_claims_user ON letter_claims(user_id);

-- What's new in the first update with the Shop.
INSERT INTO news (kind, title, body, colour, action, version, starts_at, ends_at, created_at) VALUES (
  'whats_new',
  'New: the Shop, card backs and the Encore',
  'Win shows to earn coins, then spend them in the new Shop on card backs. They only change the look of your cards. Lost a show? Take an Encore for one more hand and one more discard, once a run. And the game now loads faster.',
  'purple',
  'shop',
  '',
  unixepoch(),
  NULL,
  unixepoch()
);
