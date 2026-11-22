#!/bin/sh
# Run the headless test suite (game/tests/test_*.gd, including the play bot) and fail on any error.
#   ./test.sh                  everything: unit tests and 48 complete bot runs (a few minutes)
#   ./test.sh --fast           unit tests and a short bot smoke run (8 runs)
#   ./test.sh --only=hand      only the suites or tests whose name contains "hand"
#   ./test.sh --bot-runs=200 --verbose   more runs for steadier balance numbers, every run listed
# The bot's numbers also go to build/bot_stats.json; the full output to build/test-output.txt.
# A fresh checkout is imported first (game/.godot missing); after adding a class_name script,
# import again by hand: $GODOT --headless --path game --import
set -eu
cd "$(dirname "$0")"
GODOT="${GODOT:-$HOME/Developer/godot-4.7.2/Godot.app/Contents/MacOS/Godot}"
mkdir -p build
if [ ! -d game/.godot ]; then
	"$GODOT" --headless --path game --import > build/test-import.txt 2>&1 || true
fi
args=""
for arg in "$@"; do
	if [ "$arg" = "--fast" ]; then
		args="$args --bot-runs=8"
	else
		args="$args $arg"
	fi
done
# Headless runs keep the Online autoload inert; --api also points it at a closed local port,
# so a test can never reach the real server. --log-file keeps Godot's log out of user://.
# --quit-after only matters if the runner scene fails to load (it would idle otherwise).
rm -f build/test-exit
# shellcheck disable=SC2086
{ code=0
	"$GODOT" --headless --path game --log-file "$PWD/build/test-godot.log" --quit-after 100000 \
		res://tests/run_tests.tscn -- --api=http://127.0.0.1:9 --stats-out="$PWD/build/bot_stats.json" $args || code=$?
	echo "$code" > build/test-exit; } 2>&1 | tee build/test-output.txt
code=$(cat build/test-exit 2>/dev/null || echo 1)
if grep -q "SCRIPT ERROR" build/test-output.txt; then
	echo "test.sh: script errors in the output (see above)"
	exit 1
fi
if [ "$code" != "0" ] || ! grep -q "^TESTS PASSED" build/test-output.txt; then
	echo "test.sh: tests failed (exit code $code)"
	exit 1
fi
echo "tests OK"
