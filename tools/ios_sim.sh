#!/bin/sh
# Run the iOS export (make it with ./ios.sh first) in the iOS Simulator on Apple Silicon.
# Godot's template has only an x86_64 Simulator libgodot.a, so this makes an arm64
# Simulator slice from the device slice (tools/patch_sim_lib.py), adds Simulator-only
# settings to the Xcode project (ad hoc signing with no Apple account, arm64 only, two
# Metal symbols the Simulator SDK lacks), then builds, installs and launches the game.
# Afterwards Xcode's Run on a Simulator destination works too. Safe to re-run.
# Env: SIM_UDID (default: the booted Simulator; a given one is booted if needed), CONFIGURATION
# (default Release, like the scheme's Run), IOS_DIR (build/ios), DERIVED_DIR (build/ios-derived).
set -eu
cd "$(dirname "$0")/.."
IOS_DIR="${IOS_DIR:-build/ios}"
DERIVED_DIR="${DERIVED_DIR:-build/ios-derived}"
CONFIGURATION="${CONFIGURATION:-Release}"
LOG="$(dirname "$DERIVED_DIR")/ios-sim-build.log"

# Add Simulator-only build settings to the app target's configurations (the ones
# that set PRODUCT_BUNDLE_IDENTIFIER), skipping any already there; device builds
# keep Godot's settings. _MTLIOErrorDomain and _MTLTensorDomain are weak imports
# in Godot's metal-cpp that the Simulator SDK does not export: -U lets dyld leave
# them null.
patch_project() {
	pbx="$1/project.pbxproj"
	awk '
	BEGIN {
		n = split("CODE_SIGN_IDENTITY CODE_SIGN_STYLE DEVELOPMENT_TEAM PROVISIONING_PROFILE_SPECIFIER EXCLUDED_ARCHS OTHER_LDFLAGS", key, " ")
		val["CODE_SIGN_IDENTITY"] = "\"-\""
		val["CODE_SIGN_STYLE"] = "Manual"
		val["DEVELOPMENT_TEAM"] = "\"\""
		val["PROVISIONING_PROFILE_SPECIFIER"] = "\"\""
		val["EXCLUDED_ARCHS"] = "x86_64"
		val["OTHER_LDFLAGS"] = "\"$(inherited) -Wl,-U,_MTLIOErrorDomain -Wl,-U,_MTLTensorDomain\""
	}
	/buildSettings = \{[ \t]*$/ { inside = 1; app = 0; split("", have) }
	inside && /PRODUCT_BUNDLE_IDENTIFIER = / { app = 1 }
	inside {
		for (i = 1; i <= n; i++)
			if (index($0, "\"" key[i] "[sdk=iphonesimulator*]\"")) have[key[i]] = 1
	}
	inside && /^[ \t]*\};[ \t]*$/ {
		if (app)
			for (i = 1; i <= n; i++)
				if (!(key[i] in have))
					printf "\t\t\t\t\"%s[sdk=iphonesimulator*]\" = %s;\n", key[i], val[key[i]]
		inside = 0
	}
	{ print }
	' "$pbx" > "$pbx.tmp"
	if cmp -s "$pbx" "$pbx.tmp"; then
		rm -f "$pbx.tmp"
		echo "$pbx: Simulator settings already present"
	else
		mv "$pbx.tmp" "$pbx"
		echo "$pbx: added Simulator settings"
	fi
}

project=
for p in "$IOS_DIR"/*.xcodeproj; do
	if [ -d "$p" ]; then project=$p; break; fi
done
if [ -z "$project" ]; then
	echo "No Xcode project in $IOS_DIR: run ./ios.sh first." >&2
	exit 1
fi
name=$(basename "$project" .xcodeproj)
udid="${SIM_UDID:-$(xcrun simctl list devices booted | sed -n 's/.*(\([0-9A-F-]\{36\}\)) (Booted).*/\1/p' | head -n 1)}"
if [ -z "$udid" ]; then
	echo "No Simulator is booted: boot one or set SIM_UDID." >&2
	exit 1
fi

python3 -I tools/patch_sim_lib.py "$IOS_DIR"/*.xcframework
patch_project "$project"

echo "Building $name ($CONFIGURATION) for the Simulator, log in $LOG"
if ! xcodebuild -project "$project" -scheme "$name" -configuration "$CONFIGURATION" \
	-destination "platform=iOS Simulator,id=$udid" -derivedDataPath "$DERIVED_DIR" \
	build > "$LOG" 2>&1; then
	grep -E 'error:|Undefined symbols|^ +"_' "$LOG" | head -n 30 >&2 || true
	echo "Build failed, see $LOG" >&2
	exit 1
fi

app="$DERIVED_DIR/Build/Products/$CONFIGURATION-iphonesimulator/$name.app"
bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
xcrun simctl bootstatus "$udid" -b > /dev/null
xcrun simctl install "$udid" "$app"
xcrun simctl terminate "$udid" "$bundle" 2> /dev/null || true
xcrun simctl launch "$udid" "$bundle"
echo "Launched $bundle on Simulator $udid"
