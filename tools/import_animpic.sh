#!/bin/bash
# Unzip curated Animpic low-poly packs into assets/animpic/
set -euo pipefail

SRC="/Users/sam/Downloads/game_assets/animpic_lowpoly"
DST="$(cd "$(dirname "$0")/.." && pwd)/assets/animpic"

echo "=== Animpic Low-Poly Import ==="
echo "Source: $SRC"
echo "Destination: $DST"
echo ""

imported=0
skipped=0

extract_pack() {
  local zip="$1"
  local folder="$2"
  local zip_path="$SRC/$zip"

  if [ ! -f "$zip_path" ]; then
    echo "SKIP: $zip (not found)"
    skipped=$((skipped + 1))
    return
  fi

  local dest="$DST/$folder"
  mkdir -p "$dest"

  echo "  Extracting $zip -> $folder/"
  unzip -qo "$zip_path" -d "$dest/"

  # Remove Unity-specific files
  find "$dest" -name "*.meta" -delete 2>/dev/null || true
  find "$dest" -name "*.mat" -delete 2>/dev/null || true
  find "$dest" -name "*.prefab" -delete 2>/dev/null || true
  find "$dest" -name "*.unity" -delete 2>/dev/null || true
  find "$dest" -name "*.asset" -delete 2>/dev/null || true
  find "$dest" -name "*.cs" -delete 2>/dev/null || true

  echo "  OK: $zip -> $folder/"
  imported=$((imported + 1))
}

extract_pack "poly_farm.zip" "farm"
extract_pack "poly_fantasyvillage.zip" "village"
extract_pack "poly_forestvillage.zip" "forest_village"
extract_pack "poly_houses.zip" "houses"
extract_pack "poly_houseappliances.zip" "appliances"
extract_pack "poly_megasurvivalfood_V2.zip" "food"
extract_pack "poly_megasurvivaltools.zip" "tools_models"
extract_pack "poly_megasurvivalforest_V4.zip" "forest"
extract_pack "poly_medievalcamp.zip" "medieval"

echo ""
echo "=== Done: $imported imported, $skipped skipped ==="
