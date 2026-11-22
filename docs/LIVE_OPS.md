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
new API also clears letter claims when a player deletes their account, which fails until
the tables exist.

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

Writing the SQL:

- Text goes in single quotes. An apostrophe inside is written twice: `'What''s new'`.
- Times are unix seconds, UTC. `unixepoch()` is now, `unixepoch('2026-12-24 18:00')` is a
  set moment in UTC (Albania is UTC+1 in winter, so 18:00 UTC is 19:00 in Tirana), and
  `unixepoch() + 7 * 86400` is a week from now.
- The database refuses rows the game can't show (an unknown kind, colour or action, a title
  over 80 characters, words over 600, more than 5,000 coins). The error names the rule.

## The Playbill: news, banners and What's new

Each row of `news` is a card on the Playbill: a title, two lines of its words and at most
one button. Tapping the card shows all of its words.

| Column | What to put |
| --- | --- |
| `kind` | `'news'` (the Playbill only), `'banner'` (also on the home screen, up to three) or `'whats_new'` (shown once after an update) |
| `title` | Up to 80 characters; the card shows two lines, so about 40 read best |
| `body` | Up to 600 characters; the card shows the first two lines (about 70 characters) |
| `colour` | `''` for the kind's own (news blue, What's new purple, banner pink), one of `'gold'`, `'orange'`, `'red'`, `'pink'`, `'purple'`, `'blue'`, `'teal'`, `'green'`, or `'#rrggbb'` |
| `action` | The button: `''` (none), `'shop'`, `'collection'` (the Jester collection), `'daily'` (today's daily run) or an `https://` link (a web page) |
| `version` | What's new only: the game version it describes, `''` for every build (see below) |
| `starts_at` | When it goes up: `unixepoch()`, or a later time to schedule it |
| `ends_at` | When it comes down, or `NULL` to stay up |
| `created_at` | `unixepoch()` |

The game shows the 20 newest cards that have started and not ended.

### Post a news card

```sql
INSERT INTO news (kind, title, body, colour, action, starts_at, ends_at, created_at)
VALUES ('news', 'Il Capitano joins the troupe',
  'A new Jester struts through the Market. Find him and see what he does to a full house.',
  'teal', 'collection', unixepoch(), NULL, unixepoch());
```

### Put up an event banner

A banner is also one of the (at most three) cards on the home screen, until it ends. Give
it an end; the card says "Until 21 Dec", never a countdown.

```sql
INSERT INTO news (kind, title, body, colour, action, starts_at, ends_at, created_at)
VALUES ('banner', 'Carnival weekend in Venezia',
  'Every show this weekend plays to a carnival crowd. Bring your loudest Jesters.',
  'pink', 'daily', unixepoch('2026-12-19 08:00'), unixepoch('2026-12-21 23:00'), unixepoch());
```

### Write What's new for an update

Players who had played before see the newest What's new note once, the first time they
open the game after it goes up (never during the guided first run). New players never see
it: the whole game is new to them. Post it when the update ships:

```sql
INSERT INTO news (kind, title, body, colour, action, version, starts_at, ends_at, created_at)
VALUES ('whats_new', 'New: the Weekly Festival',
  'Every Monday a new challenge on a seed everyone shares, with its own board. Play it as often as you like.',
  'purple', 'daily', '1.2', unixepoch(), NULL, unixepoch());
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

### See what's up

```sh
npx wrangler d1 execute deck-of-fools --remote --command "SELECT id, kind, title, action, datetime(starts_at, 'unixepoch') AS starts, datetime(ends_at, 'unixepoch') AS ends FROM news ORDER BY starts_at DESC LIMIT 20"
```

## The inbox: letters

Each row of `letters` is a letter: a title, a few lines, and optionally coins. The player
claims the coins with one tap (a letter without coins is claimed as read). A claim is paid
once per account by the server and once per profile by the game, so a letter never pays
twice, even after a cloud-save conflict or on a new guest account.

| Column | What to put |
| --- | --- |
| `user_id` | `NULL` for everyone, or one player's id (see below) |
| `title` | Up to 80 characters; one line shows |
| `body` | Up to 600 characters; two lines show |
| `coins` | 0 (a message) to 5,000 |
| `created_at` | When it arrives: `unixepoch()`, or a later time to schedule it |
| `expires_at` | When it leaves the inbox, or `NULL` to stay; the inbox only mentions it in the last three days |

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

Find their id first. Names aren't unique, so prefer the email they signed up with:

```sh
npx wrangler d1 execute deck-of-fools --remote --command "SELECT id, name, email, datetime(created_at, 'unixepoch') AS joined FROM users WHERE email = 'player@example.com'"
```

Then send it to that id (the database refuses an id that isn't a player's):

```sql
INSERT INTO letters (user_id, title, body, coins, created_at, expires_at)
VALUES ('0f8c2d1e-0000-4000-8000-000000000000', 'Thanks for the bug report',
  'You found the Patron that skipped its rule. It is fixed now, thanks to you.',
  300, unixepoch(), NULL);
```

### Send a message without coins

```sql
INSERT INTO letters (user_id, title, body, coins, created_at, expires_at)
VALUES (NULL, 'The Weekly Festival is coming',
  'Every Monday a new challenge on a seed everyone shares. No coins needed, just your best hands.',
  0, unixepoch(), unixepoch() + 30 * 86400);
```

### Withdraw a letter, and see who claimed it

Expire a letter rather than delete it: claims already made stay on record.

```sql
-- Stop it now; letters already claimed stay claimed.
UPDATE letters SET expires_at = unixepoch() WHERE id = 12;
```

```sh
npx wrangler d1 execute deck-of-fools --remote --command "SELECT l.id, l.title, l.coins, COUNT(c.user_id) AS claims, l.coins * COUNT(c.user_id) AS coins_paid FROM letters l LEFT JOIN letter_claims c ON c.letter_id = l.id GROUP BY l.id ORDER BY l.id DESC LIMIT 20"
```

## How fast it reaches players

- **News, banners, What's new:** the API keeps a copy for up to a minute, and the game asks
  at most every 10 minutes and keeps its last copy for when it's offline. A new card shows
  within about 11 minutes; an ended one disappears on the server's clock, whatever the
  phone's clock says.
- **Letters:** the game asks when the inbox opens (if its copy is over a minute old) and at
  most every 10 minutes for the badge on the home screen.

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
`api/.wrangler/` (ignored by git).
