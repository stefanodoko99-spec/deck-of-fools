#!/bin/sh
# Export the Godot project as an Xcode project for iPhone and iPad (build/ios).
# With export_project_only, Godot writes DeckOfFools.xcodeproj next to the .ipa path.
# Then: open build/ios/DeckOfFools.xcodeproj, pick your team, and Run on a device.
# For the iOS Simulator on Apple Silicon run tools/ios_sim.sh next: it makes the export
# Simulator-ready (arm64 slice, settings) and launches it; Xcode's Run works after that too.
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Developer/godot-4.7.2/Godot.app/Contents/MacOS/Godot}"
./check.sh
rm -rf build/ios && mkdir -p build/ios
# IOS_PRESET="iOS Test Store" ./ios.sh exports with the test store and test ads
# (custom feature store_test) for trying the shop in the Simulator. Never submit that build.
"$GODOT" --headless --path game --export-release "${IOS_PRESET:-iOS}" ../build/ios/DeckOfFools.ipa 2>&1 | grep -E "ERROR|SCRIPT ERROR|error" || true
ls build/ios
