#!/bin/sh
# Load every script the way the running game does and fail on any script error.
# (Exports tokenize scripts without compiling them, so they don't catch these.)
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Developer/godot-4.7.2/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --headless --path game --quit-after 120 2>&1 || true)
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "$out" | grep -A1 "SCRIPT ERROR"
	exit 1
fi
echo "scripts OK"
