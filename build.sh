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
# Workers static assets cap each file at 25 MiB; the wasm is ~38 MiB, gzip brings it to ~10 MiB.
gzip -9 -c build/web/index.wasm > build/web/index.wasm.gz
rm build/web/index.wasm
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
