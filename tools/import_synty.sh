#!/bin/bash
# Import curated Synty POLYGON packs from iCloud into assets/synty/
set -euo pipefail

SRC="/Users/sam/Library/Mobile Documents/com~apple~CloudDocs/game assets/synty_godot"
DST="$(cd "$(dirname "$0")/.." && pwd)/assets/synty"

echo "=== Synty POLYGON Import ==="
echo "Source: $SRC"
echo "Destination: $DST"
echo ""

imported=0
skipped=0

copy_pack() {
  local pack="$1"
  local folder="$2"
  local pack_src="$SRC/$pack"

  if [ ! -d "$pack_src" ]; then
    echo "SKIP: $pack (not found)"
    skipped=$((skipped + 1))
    return
  fi

  local dest="$DST/$folder"
  mkdir -p "$dest"

  if [ -d "$pack_src/models" ]; then
    echo "  Copying $pack/models -> $folder/models/"
    cp -R "$pack_src/models" "$dest/"
  fi
  if [ -d "$pack_src/textures" ]; then
    echo "  Copying $pack/textures -> $folder/textures/"
    cp -R "$pack_src/textures" "$dest/"
  fi
  if [ -d "$pack_src/materials" ]; then
    echo "  Copying $pack/materials -> $folder/materials/"
    cp -R "$pack_src/materials" "$dest/"
  fi

  echo "  OK: $pack -> $folder/"
  imported=$((imported + 1))
}

copy_pack "POLYGON_Farm" "farm"
copy_pack "POLYGON_Pirate_Pack" "pirate"
copy_pack "POLYGON_Nature" "nature"
copy_pack "POLYGON_NatureBiomes_TropicalJungle" "tropical"
copy_pack "POLYGON_Knights" "knights"
copy_pack "POLYGON_Western_Frontier" "western"
copy_pack "POLYGON_City" "city"
copy_pack "POLYGON_Mini" "mini"
copy_pack "POLYGON_Construction" "construction"
copy_pack "POLYGON_Explorer_Kit" "explorer"
copy_pack "POLYGON_Fantasy_Characters" "characters"
copy_pack "POLYGON_Mini_FantasyCharacters" "characters_mini"
copy_pack "POLYGON_Dungeon_Pack" "dungeon"
copy_pack "POLYGON_Snow_Kit" "snow"
copy_pack "POLYGON_Office" "office"
copy_pack "POLYGON_Starter" "starter"
copy_pack "POLYGON_Town" "town"
copy_pack "POLYGON_Dungeons_Map" "dungeons_map"
copy_pack "SIMPLE_Fantasy" "simple_fantasy"
copy_pack "SIMPLE_Fantasy_Interiors" "simple_fantasy_interiors"

echo ""
echo "=== Done: $imported imported, $skipped skipped ==="
