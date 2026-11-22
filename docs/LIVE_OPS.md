# Live ops: news, banners and letters

How to post news on the Playbill, put a banner on the home screen, write the What's new
note after an update, and send letters to the inbox, with or without coins. There is no
admin screen: everything is a row in the API's D1 database (`deck-of-fools`), added with
`wrangler d1 execute`. The tables come from `api/migrations/0002_news_letters.sql`.

> **Production commands.** Every command below with `--remote` changes what every player
> sees, at once. They are written out for the owner to run by hand; nothing in this
> repository runs them. To try one first, run it with `--local` instead of `--remote`
> (see [Trying it locally](#trying-it-locally)).

## Once, before the first post

Create the tables in production, then deploy the API that reads them. In this order: the
new API's news and letters calls fail until the tables exist. (Deleting an account works
either way: a player's claims and personal letters go with their account.)

```sh
cd ~/Developer/deck-of-fools/api
npx wrangler d1 migrations apply deck-of-fools --remote
npx wrangler deploy
```

The migration also posts the first What's new note (the Shop, card backs, the Encore and
faster loading), which returning players see once.

`npx wrangler` downloads Wrangler when it isn't installed. On the studio Mac the installed
one is `/Users/laura/Stefano/beed-energy/node_modules/.bin/wrangler`; it can stand in for
`npx wrangler` in every command here.

## How to run a command

Run every command from the `api` folder. Short ones fit in `--command "..."`; for anything
with real words in it, save the SQL in a file (for example `news.sql` next to
`wrangler.jsonc`) and run it with `--file`, so the shell doesn't trip over `!`, `$` or
quotes:

```sh
cd ~/Developer/deck-of-fools/api
npx wrangler d1 execute deck-of-fools --remote --file news.sql
```

> **Never paste a player's words into a command or into SQL**: not an email address, a
> name or anything from a support message. An address can legally hold quotes, `;`, `$(`
> and backticks, so pasted into a command it can run SQL on the live database or commands
> on this Mac. To find a player, use [the lookup below](#send-a-letter-to-one-player),
> which takes the address from the clipboard and refuses anything that isn't a plain one.

Writing the SQL:

- Text goes in single quotes. An apostrophe inside is written twice: `'What''s new'`.
- Times are unix seconds, UTC. `unixepoch()` is now, `unixepoch('2026-12-24 18:00')` is a
  set moment in UTC (Albania is UTC+1 in winter, so 18:00 UTC is 19:00 in Tirana), and
  `unixepoch() + 7 * 86400` is a week from now. Write dates exactly as `'YYYY-MM-DD HH:MM'`,
  two digits each: `unixepoch()` can't read `'2026-12-1 9:00'` or `'21 Dec 2026'`.
- An end time of `0` means never: `ends_at` for a card that stays up, `expires_at` for a
  letter that stays.
- The database refuses rows the game can't show, and the error names the rule:
  - `NOT NULL constraint failed: news.ends_at` (or `starts_at`, `created_at`,
    `expires_at`): `unixepoch()` couldn't read that date. Fix how it's written.
  - `CHECK constraint failed: ends_at_0_or_after_starts_at` (or
    `expires_at_0_or_after_created_at`): the end isn't after the start, or a time was
    written as text instead of with `unixepoch()`.
  - `starts_at_is_a_time`, `created_at_is_a_time`: a time written as text, or in
    milliseconds.
  - `title_1_to_80_characters`: a title that is blank or over 80 characters.
  - `action_shop_collection_daily_or_https_link`: a button the game doesn't know (links
    are `https://`, lower case, 12 to 300 characters, no spaces or quotes).
  - The others name themselves: an unknown kind or colour, words over 600 characters,
    coins that aren't a whole number from 0 to 5,000.

## The Playbill: news, banners and What's new

Each row of `news` is a card on the Playbill: a title, two lines of its words and at most
one button. Tapping the card shows all of its words (long ones scroll inside the card).

| Column | What to put |
| --- | --- |
| `kind` | `'news'` (the Playbill only), `'banner'` (also on the home screen, up to three) or `'whats_new'` (shown once after an update) |
| `title` | Up to 80 characters; the card shows two lines, so about 40 read best |
| `body` | Up to 600 characters; the card shows the first two lines (about 70 characters) |
| `colour` | `''` for the kind's own (news blue, What's new purple, banner pink), one of `'gold'`, `'orange'`, `'red'`, `'pink'`, `'purple'`, `'blue'`, `'teal'`, `'green'`, or `'#rrggbb'` |
| `action` | The button: `''` (none), `'shop'`, `'collection'` (the Jester collection), `'daily'` (today's daily run) or an `https://` link (a web page) |
| `version` | What's new only: the game version it describes, `''` for every build (see below) |
| `starts_at` | When it goes up: `unixepoch()`, or a later time to schedule it |
| `ends_at` | When it comes down, or `0` to stay up |
| `created_at` | `unixepoch()` |

The game shows the 20 newest cards that have started and not ended.

### Post a news card

```sql
INSERT INTO news (kind, title, body, colour, action, starts_at, ends_at, created_at)
VALUES ('news', 'Il Capitano joins the troupe',
  'A new Jester struts through the Market. Find him and see what he does to a full house.',
  'teal', 'collection', unixepoch(), 0, unixepoch());
```

### Put up an event banner

A banner is also one of the (at most three) cards on the home screen, until it ends. Give
it an end. On the Playbill its card says "Until 21 Dec" ("Until Sat 21 Dec" when opened):
the last day it is up, in each player's own time zone, never a countdown or "ends today".

```sql
INSERT INTO news (kind, title, body, colour, action, starts_at, ends_at, created_at)
VALUES ('banner', 'Carnival weekend in Venezia',
  'Every show this weekend plays to a carnival crowd. Bring your loudest Jesters.',
  'pink', 'daily', unixepoch('2026-12-19 08:00'), unixepoch('2026-12-21 23:00'), unixepoch());
```

### Write What's new for an update

Players who had played before see the newest What's new note they haven't been shown,
once: the home screen opens it (never during the guided first run, never right after a
lost show), and opening the Playbill counts it as seen too. A note posted for later shows
once when it starts, and a note about a version (see below) shows once a player's build
reaches that version. New players never see the notes that were up when they started:
the whole game is new to them. Post a note when the update ships:

```sql
INSERT INTO news (kind, title, body, colour, action, version, starts_at, ends_at, created_at)
VALUES ('whats_new', 'New: the Weekly Festival',
  'Every Monday a new challenge on a seed everyone shares, with its own board. Play it as often as you like.',
  'purple', 'daily', '1.2', unixepoch(), 0, unixepoch());
```

`version` matters when the web game and the iPhone app update on different days: a build
that knows its version (`application/config/version` in `project.godot`) doesn't show a
note about a newer version until it has updated. A build without a version, like the web
game today, shows every note. Use `''` for a note that is for everyone.

### Schedule, end or remove a card

```sql
-- Put it up later (or move its start):
UPDATE news SET starts_at = unixepoch('2026-12-20 09:00') WHERE id = 7;
-- Take it down now (it stays in the table):
UPDATE news SET ends_at = unixepoch() WHERE id = 7;
-- Remove it for good:
DELETE FROM news WHERE id = 7;
```

A card that hasn't started yet can't be ended "now" (the end would come before its start,
so the database refuses it): delete it instead, nobody has seen it.

### See what's up

```sh
npx wrangler d1 execute deck-of-fools --remote --command "SELECT id, kind, title, action, datetime(starts_at, 'unixepoch') AS starts, CASE ends_at WHEN 0 THEN 'never' ELSE datetime(ends_at, 'unixepoch') END AS ends FROM news ORDER BY starts_at DESC LIMIT 20"
```

## The inbox: letters

Each row of `letters` is a letter: a title, a few lines, and optionally coins. The inbox
lists each with two lines of its words; tapping one shows all of it. The player claims the
coins with one tap (a letter without coins is claimed as read). A claim is paid once per
account by the server and once per profile by the game, so a letter never pays twice,
even after a cloud-save conflict or on a new guest account.

| Column | What to put |
| --- | --- |
| `user_id` | `NULL` for everyone, or one player's id (see below) |
| `title` | Up to 80 characters; one line shows in the list |
| `body` | Up to 600 characters; two lines show in the list, all of it when the letter is opened |
| `coins` | 0 (a message) to 5,000 |
| `created_at` | When it arrives: `unixepoch()`, or a later time to schedule it |
| `expires_at` | When it leaves the inbox, or `0` to stay; the inbox mentions the last day ("until 21 Dec") only in the last three days |

Letters pay coins only, never diamonds: diamonds are what players buy, and giving them
away by letter would blur that (see `docs/MONETIZATION.md`). Keep amounts in proportion: a
won quick run pays 40 coins and a won tour 100 or more, so 100 to 300 is a generous
apology. A letter for everyone also reaches players who join later, until it expires, so
give gifts an end.

### Send a letter to everyone

```sql
INSERT INTO letters (user_id, title, body, coins, created_at, expires_at)
VALUES (NULL, 'Sorry about Tuesday''s outage',
  'The leaderboards were down for an hour. Here is something for your patience.',
  200, unixepoch(), unixepoch() + 14 * 86400);
```

### Send a letter to one player

Find their id first, from the address they signed up with. Copy just the address (from
their message, say), then paste this whole block into Terminal. It reads the address from
the clipboard, so the address never becomes part of a command; it refuses anything but
letters, digits, `. _ % + -` and one `@`, and looks the address up by its hex code, so
nothing in it can reach the SQL as text:

```sh
cd ~/Developer/deck-of-fools/api
EMAIL=$(pbpaste | tr 'A-Z' 'a-z')
case "$EMAIL" in
  '' | @* | *@ | *@*@* | *[^abcdefghijklmnopqrstuvwxyz0123456789._%+@-]*)
    echo "Refused. Copy just the address: letters, digits, . _ % + - and one @." ;;
  *@*)
    printf "SELECT id, name, email, datetime(created_at, 'unixepoch') AS joined FROM users WHERE hex(email) = upper('%s');\n" \
      "$(printf '%s' "$EMAIL" | od -v -An -tx1 | tr -d ' \n')" > lookup.sql
    npx wrangler d1 execute deck-of-fools --remote --file lookup.sql ;;
  *)
    echo "Refused. That isn't an email address." ;;
esac
```

If it refuses an address, don't type the address into a command yourself: ask the player
for the address they signed up with, as plain text. (New accounts can only use plain
addresses; a few older ones, or ones that came from Apple or Google, may not be.)

Then send the letter to the id the lookup printed (the database refuses an id that isn't a
player's):

```sql
INSERT INTO letters (user_id, title, body, coins, created_at, expires_at)
VALUES ('0f8c2d1e-0000-4000-8000-000000000000', 'Thanks for the bug report',
  'You found the Patron that skipped its rule. It is fixed now, thanks to you.',
  300, unixepoch(), 0);
```

### Send a message without coins

```sql
INSERT INTO letters (user_id, title, body, coins, created_at, expires_at)
VALUES (NULL, 'The Weekly Festival is coming',
  'Every Monday a new challenge on a seed everyone shares. No coins needed, just your best hands.',
  0, unixepoch(), unixepoch() + 30 * 86400);
```

### Check the letters after posting

Run this after every post: it shows when each letter arrives and leaves (UTC), so a date
that came out wrong shows at once, and how often each was claimed.

```sh
npx wrangler d1 execute deck-of-fools --remote --command "SELECT l.id, l.title, l.coins, datetime(l.created_at, 'unixepoch') AS arrives, CASE l.expires_at WHEN 0 THEN 'never' ELSE datetime(l.expires_at, 'unixepoch') END AS leaves, COUNT(c.user_id) AS claims, l.coins * COUNT(c.user_id) AS coins_paid FROM letters l LEFT JOIN letter_claims c ON c.letter_id = l.id GROUP BY l.id ORDER BY l.id DESC LIMIT 20"
```

### Withdraw a letter

Expire a letter rather than delete it: claims already made stay on record.

```sql
-- Stop it now; letters already claimed stay claimed.
UPDATE letters SET expires_at = unixepoch() WHERE id = 12;
```

A letter that hasn't arrived yet can't expire "now" (the database refuses an end before
its arrival): delete it instead. Nobody can have claimed it.

```sql
DELETE FROM letters WHERE id = 12;
```

## How fast it reaches players

- **News, banners, What's new:** the API keeps a copy for up to a minute. The game asks at
  most every 10 minutes (a minute after a failed try), whenever the home screen looks at
  its banners and dots or the Playbill opens, and keeps its last copy for when it's
  offline. A new card shows within about 11 minutes; an ended one disappears on the
  server's clock, whatever the phone's clock says.
- **Letters:** the home screen's inbox badge asks at most every 10 minutes (a minute after
  a failed try), and the inbox asks when it opens if its copy is over a minute old.

## Test builds

Test-money builds (debug runs from the editor, the dev gallery and the Web/Test Store
preview builds) pay into their own test wallet. On the production API they only show
letters, with the Claim button off and a line saying letters are claimed in the released
game: a claim there would use up the real account's letter for good. Pointed at another
API (`-- --api=http://localhost:8787`, see below) they claim, into the test wallet, with a
claim record of their own, so the real game still pays those letters to the real wallet.

## The rules

These come from `docs/ROADMAP.md` and `docs/MONETIZATION.md`, and the game is built around
them:

- Nothing pushy: no "only today" offers, no countdowns in titles, nothing that punishes a
  missed day, nothing sent because someone lost.
- Coins by letter only, never diamonds; nothing posted here changes how a run plays.
- Plain words and real dates.

## Trying it locally

The same commands work on a local copy of the database, which nobody else sees:

```sh
cd ~/Developer/deck-of-fools/api
npx wrangler d1 migrations apply deck-of-fools --local
npx wrangler d1 execute deck-of-fools --local --file news.sql
npx wrangler dev --local
```

Then run the game against it from a desktop debug run, with
`-- --api=http://localhost:8787` after the Godot arguments. The local data lives in
`api/.wrangler/` (ignored by git). Wrangler applies a migration once, so a local copy that
got `0002_news_letters.sql` before its time and title rules were tightened (22 November
2026) keeps the older tables: delete `api/.wrangler/state` and apply the migrations again.
