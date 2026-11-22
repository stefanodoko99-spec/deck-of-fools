#!/bin/sh
# Export the Godot project for the web and prepare it for the deck-of-fools Worker.
#   GODOT=/path/to/Godot ./build.sh          build into build/web
#   ./build.sh && (cd site && npx wrangler deploy)
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Developer/godot-4.7.2/Godot.app/Contents/MacOS/Godot}"
./check.sh
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path game --import
# WEB_PRESET="Web Test Store" ./build.sh builds with the test store and test ads
# (custom feature store_test), for a preview version only, never for production.
"$GODOT" --headless --path game --export-release "${WEB_PRESET:-Web}" ../build/web/index.html
# Compress the engine and the game data once here, so the worker can send them as they
# are (site/worker.js): Brotli (~6.9 MB engine) for browsers that take it, gzip (~10 MB)
# as the fallback. Workers static assets cap each file at 25 MiB, so the raw ~38 MiB
# engine is never uploaded.
ENGINE_HASH=$(shasum -a 256 build/web/index.wasm | cut -c1-16)
./tools/brotli.sh build/web/index.wasm build/web/index.wasm.br
gzip -9 -c build/web/index.wasm > build/web/index.wasm.gz
rm build/web/index.wasm
./tools/brotli.sh build/web/index.pck build/web/index.pck.br
gzip -9 -c build/web/index.pck > build/web/index.pck.gz
# Stored under another name so requests for index.pck reach the worker, which picks
# the compressed copy (a file at the requested path would be served directly).
mv build/web/index.pck build/web/index.pck.raw
# The music stays out of the game data on the web (export filter audio/music/*): the
# game fetches these files after the menu appears (Feel._fetch_track).
mkdir -p build/web/music
cp game/audio/music/*.ogg build/web/music/
MUSIC_HASH=$(cat build/web/music/*.ogg | shasum -a 256 | cut -c1-16)
# Keep the engine cached across game updates (it only changes with Godot itself), and
# the music in a cache of its own.
node tools/patch_service_worker.mjs build/web "$ENGINE_HASH" "$MUSIC_HASH"
# A service worker that fails to parse silently stops caching for every player.
node --check build/web/index.service.worker.js
# The privacy and support pages the App Store asks for. They go live once a real
# contact address replaces the CONTACT_EMAIL placeholder.
if grep -q CONTACT_EMAIL site/public/*.html; then
	echo "note: privacy.html and support.html still say CONTACT_EMAIL, so they were not published"
else
	cp site/public/*.html build/web/
fi
# iOS launch screens for the installed web app.
mkdir -p build/web/splash
cp site/public/splash/*.png build/web/splash/
ls -la build/web
