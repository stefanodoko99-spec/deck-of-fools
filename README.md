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
| `test.sh` | Runs the headless tests in `game/tests/` and the play bot (see below). |
| `art.sh` | Adds a Jester illustration to `game/art/jesters/` (see [docs/ART.md](docs/ART.md)). |

This repository was rebuilt from the live build on 2026-11-21 because the original project folder was lost. See [RECOVERY.md](RECOVERY.md) for what came back and what didn't.

## Build and deploy the game

Needs Godot 4.7.2 with its export templates installed.

```sh
GODOT=/path/to/Godot ./build.sh
cd site && npx wrangler deploy
```

`index.wasm` is about 38 MiB, over the 25 MiB limit for a Workers static asset, so `build.sh` ships it as `index.wasm.gz` and `site/worker.js` serves it with `Content-Encoding: gzip`.

## Run the tests

```sh
./test.sh            # about a minute: unit tests, 48 complete bot runs, 8 challenges, 24 wandering runs
./test.sh --fast     # a few seconds of bot play instead
./test.sh --only=profile --verbose
```

Every `game/tests/test_*.gd` is a suite (`game/tests/suite.gd` explains the rules); they run headless in `res://tests/run_tests.tscn`, with the Online autoload inert and pointed at a closed local port. `game/tests/bot.gd` plays whole runs through `RunState.apply()` only; its numbers (towns reached, shows won, ducats per show and per run) are printed and written to `build/bot_stats.json`. A test marked `known_bug()` pins a bug that isn't fixed yet: it shows as XFAIL and doesn't fail the run, and once the bug is fixed it shows as XPASS and fails until the marker is removed. `game/tests/` is left out of the release exports.

## Build the iPhone app

```sh
./ios.sh
open build/ios/DeckOfFools.xcodeproj
```

`ios.sh` exports the Xcode project (needs Godot's iOS template). In Xcode, choose your team under Signing & Capabilities, connect your iPhone and press Run. To run it in the iOS Simulator on an Apple-silicon Mac, run `tools/ios_sim.sh` after `ios.sh`: it builds and launches the game in the booted Simulator, and Xcode's Run works there afterwards. See [docs/APP_STORE.md](docs/APP_STORE.md) for the App Store steps.

## Deploy the API

Apply any new migrations first, then deploy: the news and letters routes answer with an error until `0002_news_letters.sql` is in.

```sh
cd api && npx wrangler d1 migrations apply deck-of-fools --remote
```

```sh
cd api && npx wrangler deploy
```

New tables go in a new file in `api/migrations/`. See [docs/LIVE_OPS.md](docs/LIVE_OPS.md) for posting news and letters.

Decks are listed twice: in `game/content/deck_cards.gd` and in the `DECKS` list in `api/src/index.js` (from `src/daily.js`). A deck missing from the API list is rejected when a run is handed in, so add new decks to both.
