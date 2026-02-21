#!/bin/bash
# Unzip curated Godot community asset packs into assets/community/
set -euo pipefail

SRC="/Users/sam/Library/Mobile Documents/com~apple~CloudDocs/game assets/godot_assets/3d_models"
DST="$(cd "$(dirname "$0")/.." && pwd)/assets/community"

echo "=== Community Asset Import ==="
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

  echo "  OK: $zip -> $folder/"
  imported=$((imported + 1))
}

extract_pack "Low Poly Ultimate Pack.zip" "ultimate"
extract_pack "Low Poly Animated Animals.zip" "animals"
extract_pack "Toon Furniture.zip" "furniture"
extract_pack "Low Poly Tools Bundle.zip" "tools_models"
extract_pack "Low Poly Vegetation Pack.zip" "vegetation"
extract_pack "Fish - PolyPack.zip" "fish"
extract_pack "RPG Monster Wave Polyart.zip" "monsters"
extract_pack "3D Props - Adorable Items.zip" "props"
extract_pack "Meshtint Free Boximon Cyclopes Mega Toon Series.zip" "boximon_cyclopes"
extract_pack "Meshtint Free Boximon Fiery Mega Toon Series.zip" "boximon_fiery"
extract_pack "Meshtint Free Chick Mega Toon Series.zip" "boximon_chick"
extract_pack "Meshtint Free Chicken Mega Toon Series.zip" "boximon_chicken"
extract_pack "Tiny RPG Town Environment.zip" "tiny_rpg_town"
extract_pack "Tiny RPG - Forest.zip" "tiny_rpg_forest"

echo ""
echo "=== Done: $imported imported, $skipped skipped ==="
