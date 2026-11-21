# Deck of Fools

A poker-hand roguelike about a travelling commedia dell'arte troupe. Travel through 8 towns, beat each show's target with poker hands, and spend ducats on Jesters that bend the rules.

- Game: https://deck-of-fools.stefanodoko-radari.workers.dev
- API: https://deck-of-fools-api.stefanodoko-radari.workers.dev

## Layout

| Folder | What it is |
|---|---|
| `game/` | The Godot 4.7 project (GL Compatibility renderer, 640×360 canvas). |
| `site/` | The `deck-of-fools` Cloudflare Worker that serves the web export. |
| `api/` | The `deck-of-fools-api` Worker: accounts, saves, runs, daily run, leaderboards (D1 database `deck-of-fools`). |
| `build.sh` | Exports the game for the web into `build/web/` and gzips the wasm. |
| `art.sh` | Adds a Jester illustration to `game/art/jesters/` (see [docs/ART.md](docs/ART.md)). |

This repository was rebuilt from the live build on 2026-11-21 because the original project folder was lost. See [RECOVERY.md](RECOVERY.md) for what came back and what didn't.

## Build and deploy the game

Needs Godot 4.7.2 with its export templates installed.

```sh
GODOT=/path/to/Godot ./build.sh
cd site && npx wrangler deploy
```

`index.wasm` is about 38 MiB, over the 25 MiB limit for a Workers static asset, so `build.sh` ships it as `index.wasm.gz` and `site/worker.js` serves it with `Content-Encoding: gzip`.

## Build the iPhone app

```sh
./ios.sh
open build/ios/DeckOfFools.xcodeproj
```

`ios.sh` exports the Xcode project (needs Godot's iOS template). In Xcode, choose your team under Signing & Capabilities, connect your iPhone and press Run. See [docs/APP_STORE.md](docs/APP_STORE.md) for the App Store steps.

## Deploy the API

```sh
cd api && npx wrangler deploy
```

New tables go in a new file in `api/migrations/`, applied with `npx wrangler d1 migrations apply deck-of-fools --remote`.

Decks are listed twice: in `game/content/deck_cards.gd` and in the `DECKS` list in `api/src/index.js` (from `src/daily.js`). A deck missing from the API list is rejected when a run is handed in, so add new decks to both.
