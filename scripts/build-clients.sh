#!/usr/bin/env bash
set -euo pipefail

# build-clients.sh — Export macOS and Windows client builds (debug + release).
#
# Usage:
#   ./scripts/build-clients.sh                # full build: both platforms, both variants
#   ./scripts/build-clients.sh --skip-macos   # Windows only
#   ./scripts/build-clients.sh --skip-windows # macOS only
#   ./scripts/build-clients.sh --debug-only   # debug variants only
#   ./scripts/build-clients.sh --release-only # release variants only
#   ./scripts/build-clients.sh --clean        # wipe builds/ before starting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

GODOT_BIN="/Applications/Mechanical Turk.app/Contents/MacOS/Mechanical Turk"
BUILDS_DIR="builds"

SKIP_MACOS=false
SKIP_WINDOWS=false
DEBUG_ONLY=false
RELEASE_ONLY=false
CLEAN=false

for arg in "$@"; do
	case "$arg" in
		--skip-macos)   SKIP_MACOS=true ;;
		--skip-windows) SKIP_WINDOWS=true ;;
		--debug-only)   DEBUG_ONLY=true ;;
		--release-only) RELEASE_ONLY=true ;;
		--clean)        CLEAN=true ;;
		*) echo "Unknown flag: $arg"; exit 1 ;;
	esac
done

if [ "$DEBUG_ONLY" = true ] && [ "$RELEASE_ONLY" = true ]; then
	echo "ERROR: --debug-only and --release-only are mutually exclusive."
	exit 1
fi

# --- Validate Godot binary ---
if [ ! -x "$GODOT_BIN" ]; then
	echo "ERROR: Godot binary not found at: $GODOT_BIN"
	exit 1
fi

# --- Clean ---
if [ "$CLEAN" = true ]; then
	echo "==> Cleaning builds/ directory..."
	rm -rf "$BUILDS_DIR"
fi

# --- Setup directories ---
mkdir -p "$BUILDS_DIR/macos" "$BUILDS_DIR/windows" "$BUILDS_DIR/logs"

MACOS_BUNDLE_ID="com.spatialmods.creaturecrafting"

EXPORT_COUNT=0
FAIL_COUNT=0

# Helper: fix macOS .app Info.plist after export.
# Godot's built-in codesign can fail to resolve plist template variables,
# leaving CFBundleExecutable as "godot_macos" and CFBundleIdentifier as "$identifier".
# This detects the actual binary name and patches the plist accordingly.
fix_macos_app() {
	local app_path="$1"
	local plist="$app_path/Contents/Info.plist"

	if [ ! -f "$plist" ]; then
		echo "    WARNING: Info.plist not found at $plist"
		return 1
	fi

	# Detect actual binary name (the only file in Contents/MacOS/)
	local binary_name
	binary_name="$(ls "$app_path/Contents/MacOS/")"
	local current_exec
	current_exec="$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist" 2>/dev/null || echo "")"

	if [ "$current_exec" != "$binary_name" ]; then
		echo "    Fixing Info.plist: CFBundleExecutable '$current_exec' -> '$binary_name'"
		/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable '$binary_name'" "$plist"
	fi

	local current_id
	current_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist" 2>/dev/null || echo "")"
	if [ "$current_id" = "\$identifier" ] || [ -z "$current_id" ]; then
		echo "    Fixing Info.plist: CFBundleIdentifier -> $MACOS_BUNDLE_ID"
		/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $MACOS_BUNDLE_ID" "$plist"
	fi
}

# Helper: run a Godot export and log output
run_export() {
	local mode="$1"    # --export-debug or --export-release
	local preset="$2"  # "macOS Client" or "Windows Client"
	local output="$3"  # output path
	local logfile="$4" # log path

	echo "    Exporting $preset ($mode) -> $output"
	> "$logfile"

	# Run Godot in background (it won't exit on its own after export)
	"$GODOT_BIN" --headless --path . "$mode" "$preset" "$output" > "$logfile" 2>&1 &
	local godot_pid=$!

	# Poll log for export completion or timeout after 5 minutes
	local elapsed=0
	while kill -0 $godot_pid 2>/dev/null; do
		if grep -q '\[ DONE \].*export' "$logfile" 2>/dev/null; then
			echo "    Export finished, stopping Godot process..."
			kill -9 $godot_pid 2>/dev/null || true
			wait $godot_pid 2>/dev/null || true
			break
		fi
		if [ $elapsed -ge 300 ]; then
			echo "    TIMEOUT: Export killed after 5 minutes"
			kill -9 $godot_pid 2>/dev/null || true
			wait $godot_pid 2>/dev/null || true
			cat "$logfile"
			FAIL_COUNT=$((FAIL_COUNT + 1))
			return 1
		fi
		sleep 2
		elapsed=$((elapsed + 2))
	done

	cat "$logfile"

	# Verify output file was actually created
	if [ ! -e "$output" ]; then
		echo "    ERROR: Export output not found at $output. See $logfile"
		FAIL_COUNT=$((FAIL_COUNT + 1))
		return 1
	fi

	EXPORT_COUNT=$((EXPORT_COUNT + 1))
}

# ============================================================
# macOS
# ============================================================
if [ "$SKIP_MACOS" = false ]; then
	echo ""
	echo "==> macOS builds"

	# --- Debug ---
	if [ "$RELEASE_ONLY" = false ]; then
		run_export --export-debug "macOS Client" "$BUILDS_DIR/macos/CreatureCrafting-debug.app" "$BUILDS_DIR/logs/macos-debug.log"

		fix_macos_app "$BUILDS_DIR/macos/CreatureCrafting-debug.app"
		echo "    Codesigning CreatureCrafting-debug.app..."
		codesign --force --deep -s - "$BUILDS_DIR/macos/CreatureCrafting-debug.app"
		xattr -cr "$BUILDS_DIR/macos/CreatureCrafting-debug.app"

		# Generate .command launcher
		cat > "$BUILDS_DIR/macos/CreatureCrafting-debug.command" <<'LAUNCHER'
#!/bin/bash
cd "$(dirname "$0")"
open CreatureCrafting-debug.app
LAUNCHER
		chmod +x "$BUILDS_DIR/macos/CreatureCrafting-debug.command"
		echo "    Created CreatureCrafting-debug.command"
	fi

	# --- Release ---
	if [ "$DEBUG_ONLY" = false ]; then
		run_export --export-release "macOS Client" "$BUILDS_DIR/macos/CreatureCrafting-release.app" "$BUILDS_DIR/logs/macos-release.log"

		fix_macos_app "$BUILDS_DIR/macos/CreatureCrafting-release.app"
		echo "    Codesigning CreatureCrafting-release.app..."
		codesign --force --deep -s - "$BUILDS_DIR/macos/CreatureCrafting-release.app"
		xattr -cr "$BUILDS_DIR/macos/CreatureCrafting-release.app"

		# Create DMG
		echo "    Creating CreatureCrafting-release.dmg..."
		rm -f "$BUILDS_DIR/macos/CreatureCrafting-release.dmg"
		hdiutil create -volname "CreatureCrafting" \
			-srcfolder "$BUILDS_DIR/macos/CreatureCrafting-release.app" \
			-ov -format UDZO \
			"$BUILDS_DIR/macos/CreatureCrafting-release.dmg"
		echo "    DMG created."
	fi
fi

# ============================================================
# Windows
# ============================================================
if [ "$SKIP_WINDOWS" = false ]; then
	echo ""
	echo "==> Windows builds"

	# --- Debug ---
	if [ "$RELEASE_ONLY" = false ]; then
		run_export --export-debug "Windows Client" "$BUILDS_DIR/windows/CreatureCrafting-debug.exe" "$BUILDS_DIR/logs/windows-debug.log"
	fi

	# --- Release ---
	if [ "$DEBUG_ONLY" = false ]; then
		run_export --export-release "Windows Client" "$BUILDS_DIR/windows/CreatureCrafting-release.exe" "$BUILDS_DIR/logs/windows-release.log"
	fi
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=========================================="
echo "  Build Summary"
echo "=========================================="
echo "  Exports completed: $EXPORT_COUNT"
if [ "$FAIL_COUNT" -gt 0 ]; then
	echo "  Exports failed:    $FAIL_COUNT"
fi
echo ""

if [ "$SKIP_MACOS" = false ]; then
	echo "  macOS:"
	ls -lh "$BUILDS_DIR/macos/" 2>/dev/null | tail -n +2 || echo "    (no files)"
	echo ""
fi

if [ "$SKIP_WINDOWS" = false ]; then
	echo "  Windows:"
	ls -lh "$BUILDS_DIR/windows/" 2>/dev/null | tail -n +2 || echo "    (no files)"
	echo ""
fi

echo "  Logs: $BUILDS_DIR/logs/"
ls "$BUILDS_DIR/logs/" 2>/dev/null || echo "    (no logs)"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
	echo "WARNING: $FAIL_COUNT export(s) failed. Check logs for details."
	exit 1
fi

echo "All exports successful!"
