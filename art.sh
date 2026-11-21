#!/bin/sh
# Add or replace a Jester's illustrated art.
# Usage: ./art.sh <jester_id> <image> [margin]
#   ./art.sh z_arlecchino ~/Downloads/arlecchino.png
# Writes game/art/jesters/<jester_id>.webp, imports it with mipmaps and lossy
# storage (small download, smooth when shrunk onto a card) and checks the scripts.
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Developer/godot-4.7.2/Godot.app/Contents/MacOS/Godot}"
id="$1"; src="$2"; margin="${3:-0}"
out="game/art/jesters/$id.webp"
grep -q "\"$id\"" game/ui/jester_designs.gd || { echo "unknown Jester id: $id"; exit 1; }
mkdir -p game/art/jesters
"$GODOT" --headless --script tools/jester_art.gd -- "$src" "$out" "$margin" 2>&1 | grep -E "webp|ERROR" || true
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
sed -i '' -e 's/^compress\/mode=0/compress\/mode=1/' -e 's/^mipmaps\/generate=false/mipmaps\/generate=true/' "$out.import"
"$GODOT" --headless --path game --import >/dev/null 2>&1 || true
./check.sh
echo "Added $out. See it with ./preview.sh, then ?screen=big (add the id there) or ?screen=jesters."
