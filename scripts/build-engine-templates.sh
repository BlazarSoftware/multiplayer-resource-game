#!/usr/bin/env bash
set -euo pipefail

# build-engine-templates.sh — Build Mechanical Turk engine for Linux x86_64
#
# Compiles the engine from source inside Docker and extracts the editor binary
# + export template to engine-builds/linux/. Results are cached — subsequent
# runs are instant unless you pass --force.
#
# Usage:
#   ./scripts/build-engine-templates.sh          # build (cached)
#   ./scripts/build-engine-templates.sh --force   # rebuild from scratch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENGINE_SRC="$(cd "$PROJECT_ROOT/../mechanical-turk" && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/engine-builds/linux"

FORCE=false
for arg in "$@"; do
	case "$arg" in
		--force) FORCE=true ;;
		*) echo "Unknown flag: $arg"; exit 1 ;;
	esac
done

# Check if already built
if [ "$FORCE" = false ] && [ -f "$OUTPUT_DIR/godot-editor" ] && [ -f "$OUTPUT_DIR/godot-template" ]; then
	echo "Engine binaries already exist in $OUTPUT_DIR"
	echo "  godot-editor:   $(ls -lh "$OUTPUT_DIR/godot-editor" | awk '{print $5}')"
	echo "  godot-template: $(ls -lh "$OUTPUT_DIR/godot-template" | awk '{print $5}')"
	echo "Use --force to rebuild."
	exit 0
fi

# Verify engine source exists
if [ ! -f "$ENGINE_SRC/SConstruct" ]; then
	echo "ERROR: Engine source not found at $ENGINE_SRC"
	echo "Expected the mechanical-turk repo at: $ENGINE_SRC"
	exit 1
fi

echo "==> Building Mechanical Turk engine for Linux x86_64..."
echo "    Engine source: $ENGINE_SRC"
echo "    Output:        $OUTPUT_DIR"
echo ""
echo "    This will take a while on the first run (compiling C++ engine)."
echo "    Docker layer caching will speed up subsequent builds."
echo ""

# Build using Docker with named build context for engine source
# Target the builder stage (Ubuntu-based) so we can extract binaries
IMAGE_NAME="mt-engine-linux-builder"

docker build \
	--platform linux/amd64 \
	-f "$PROJECT_ROOT/Dockerfile.engine" \
	-t "$IMAGE_NAME" \
	--target builder \
	--build-context "engine-src=$ENGINE_SRC" \
	"$PROJECT_ROOT"

# Extract binaries from the builder image
echo "==> Extracting binaries..."
mkdir -p "$OUTPUT_DIR"

CONTAINER_ID=$(docker create "$IMAGE_NAME" true)
docker cp "$CONTAINER_ID:/engine/bin/godot.linuxbsd.editor.x86_64" "$OUTPUT_DIR/godot-editor"
docker cp "$CONTAINER_ID:/engine/bin/godot.linuxbsd.template_release.x86_64" "$OUTPUT_DIR/godot-template"
docker rm "$CONTAINER_ID" > /dev/null

chmod +x "$OUTPUT_DIR/godot-editor" "$OUTPUT_DIR/godot-template"

echo ""
echo "==> Engine build complete!"
echo "    godot-editor:   $(ls -lh "$OUTPUT_DIR/godot-editor" | awk '{print $5}')"
echo "    godot-template: $(ls -lh "$OUTPUT_DIR/godot-template" | awk '{print $5}')"
