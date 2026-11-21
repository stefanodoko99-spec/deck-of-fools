#!/bin/sh
# Export the Godot project as an Xcode project for iPhone and iPad (build/ios).
# With export_project_only, Godot writes DeckOfFools.xcodeproj next to the .ipa path.
# Then: open build/ios/DeckOfFools.xcodeproj, pick your team, and Run on a device.
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Developer/godot-4.7.2/Godot.app/Contents/MacOS/Godot}"
rm -rf build/ios && mkdir -p build/ios
"$GODOT" --headless --path game --export-release "iOS" ../build/ios/DeckOfFools.ipa 2>&1 | grep -E "ERROR|SCRIPT ERROR|error" || true
ls build/ios
