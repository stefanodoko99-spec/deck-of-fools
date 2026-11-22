-- The Playbill (news, What's new, banners) and the inbox of letters (wave 1).
-- How to add rows in production: docs/LIVE_OPS.md.
-- Times are unix seconds (UTC), written with unixepoch(); for ends_at and expires_at, 0 means
-- never. unixepoch() gives NULL for a date it can't read, so NOT NULL refuses a mistyped date
-- instead of storing "never"; a date written as text, or an end that isn't after the start,
-- is refused by the named CHECK rules (the error names the rule).
-- The rules match what the API (src/index.js) and the game pass on, so the database refuses
-- a row the game would quietly change or drop: a blank title, or a link it wouldn't open.
-- Apply this before deploying the API code that reads these tables: until then GET /v1/news
-- and GET /v1/letters fail. (Account deletion works either way: ON DELETE CASCADE.)

-- One row per card on the Playbill. 'whats_new' is shown once after an update,
-- 'banner' also appears on the home screen (up to three), 'news' only on the Playbill.
CREATE TABLE news (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL CHECK (kind IN ('news', 'whats_new', 'banner')),
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '' CHECK (length(body) <= 600),
  -- '' (the kind's own colour), a palette name, or '#rrggbb'. (D1 refuses long GLOB
  -- patterns, so the hex digits are checked with a short one.)
  colour TEXT NOT NULL DEFAULT '' CHECK (colour IN ('', 'gold', 'orange', 'red', 'pink', 'purple', 'blue', 'teal', 'green')
    OR (length(colour) = 7 AND substr(colour, 1, 1) = '#' AND lower(substr(colour, 2)) NOT GLOB '*[^0-9a-f]*')),
  -- What the card's one button does: '' (no button), 'shop', 'collection', 'daily' or a link.
  action TEXT NOT NULL DEFAULT '',
  -- For 'whats_new': the game version it describes ('1.2'); builds that know they are older don't show it.
  version TEXT NOT NULL DEFAULT '' CHECK (length(version) <= 20),
  starts_at INTEGER NOT NULL,           -- shown from this moment
  ends_at INTEGER NOT NULL DEFAULT 0,   -- hidden from this moment; 0 = stays up
  created_at INTEGER NOT NULL,
  -- The game trims spaces, tabs and line breaks off a title and drops a card left blank.
  CONSTRAINT title_1_to_80_characters CHECK (length(title) <= 80
    AND length(trim(title, ' ' || char(9, 10, 11, 12, 13))) >= 1),
  -- A link is https://, 12 to 300 characters, without spaces, tabs, line breaks, quotes or
  -- < > (GLOB is case-sensitive, like the API's and the game's checks).
  CONSTRAINT action_shop_collection_daily_or_https_link CHECK (action IN ('', 'shop', 'collection', 'daily')
    OR (action GLOB 'https://*' AND length(action) BETWEEN 12 AND 300
      AND action NOT GLOB ('*[' || char(9, 10, 11, 12, 13, 32, 34, 39, 60, 62) || ']*'))),
  CONSTRAINT starts_at_is_a_time CHECK (typeof(starts_at) = 'integer' AND starts_at BETWEEN 1600000000 AND 4102444800),
  CONSTRAINT ends_at_0_or_after_starts_at CHECK (typeof(ends_at) = 'integer'
    AND (ends_at = 0 OR (ends_at > starts_at AND ends_at <= 4102444800))),
  CONSTRAINT created_at_is_a_time CHECK (typeof(created_at) = 'integer' AND created_at BETWEEN 1600000000 AND 4102444800)
);

CREATE INDEX news_starts ON news(starts_at DESC);

-- A letter in the inbox: a message, with coins to claim when coins > 0.
CREATE TABLE letters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,   -- NULL = a letter for everyone
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '' CHECK (length(body) <= 600),
  -- Coins only: diamonds are never given away by letter.
  coins INTEGER NOT NULL DEFAULT 0 CHECK (typeof(coins) = 'integer' AND coins BETWEEN 0 AND 5000),
  created_at INTEGER NOT NULL,          -- delivered from this moment (a later time schedules it)
  expires_at INTEGER NOT NULL DEFAULT 0,   -- gone from this moment; 0 = never
  CONSTRAINT title_1_to_80_characters CHECK (length(title) <= 80
    AND length(trim(title, ' ' || char(9, 10, 11, 12, 13))) >= 1),
  CONSTRAINT created_at_is_a_time CHECK (typeof(created_at) = 'integer' AND created_at BETWEEN 1600000000 AND 4102444800),
  CONSTRAINT expires_at_0_or_after_created_at CHECK (typeof(expires_at) = 'integer'
    AND (expires_at = 0 OR (expires_at > created_at AND expires_at <= 4102444800)))
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
  0,
  unixepoch()
);
