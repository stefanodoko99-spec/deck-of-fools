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
"$GODOT" --headless --path game --export-release "Web" ../build/web/index.html
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
# Keep the engine cached across game updates (it only changes with Godot itself).
node tools/patch_service_worker.mjs build/web "$ENGINE_HASH"
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
