#!/bin/sh
# Export the development gallery (tests/preview.gd) to build/preview.
# Serve it with: python3 -m http.server 8791 --directory build/preview
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Developer/godot-4.7.2/Godot.app/Contents/MacOS/Godot}"
./check.sh
mkdir -p build/preview
"$GODOT" --headless --path game --export-release "Web Preview" ../build/preview/index.html 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error|ERROR: Failed" || true
# The start screen's illustrations (game/web/shell.html).
mkdir -p build/preview/keyart
cp game/art/jesters/z_arlecchino.webp game/art/jesters/z_zanni.webp build/preview/keyart/
