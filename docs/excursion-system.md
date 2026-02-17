# Excursion System

## Overview

The Excursion system provides party-gated, procedurally generated, ephemeral exploration zones. Players in a party enter together, explore a unique terrain with rare creatures and resources, and all loot is shared equally among members present at the time of pickup.

**Key properties:**
- Per-party isolated instances (no cross-party interaction)
- Procedurally generated 80x80 terrain from a seed + season
- 15-minute timer per instance
- Shared loot (items + battle drops) to all members present
- Late-joining party members can enter an active instance
- Excursion-exclusive rare items and high-level encounters

## Architecture

```
ExcursionManager (Node, child of GameWorld)
  |- Manages instance lifecycle, entry/exit, loot routing
  |- References FriendManager for party validation
  |- Hooks into BattleManager + WorldItemManager for shared loot

ExcursionGenerator (class_name, static functions)
  |- generate_server(seed, season, offset) -> collision-only Node3D
  |- generate_client(seed, season, offset) -> full visual Node3D
  |- get_item_spawn_points(seed, season, offset) -> Array
  |- get_encounter_zones(seed, season, offset) -> Array
  |- get_harvestable_spawn_points(seed, season, offset) -> Array
  |- get_dig_spot_points(seed, season, offset) -> Array
```

## Files

| File | Purpose |
|------|---------|
| `scripts/world/excursion_manager.gd` | Instance lifecycle, entry/exit, shared loot, timeout |
| `scripts/world/excursion_generator.gd` | `class_name ExcursionGenerator` - procedural generation (static) |
| `scripts/ui/excursion_hud.gd` | Excursion overlay HUD (timer, members, leave button) |
| `scenes/ui/excursion_hud.tscn` | HUD scene |
| `resources/encounters/excursion_common.tres` | Common encounter table (Lv 10-20) |
| `resources/encounters/excursion_rare.tres` | Rare grove encounter table (Lv 18-35) |
| `resources/ingredients/golden_seed.tres` | Excursion-exclusive rare seed |
| `resources/ingredients/mystic_herb.tres` | Excursion-exclusive ingredient |
| `resources/ingredients/starfruit_essence.tres` | Excursion-exclusive ingredient |
| `resources/ingredients/truffle_shaving.tres` | Excursion-exclusive ingredient |
| `resources/ingredients/ancient_grain_seed.tres` | Excursion-exclusive seed |
| `resources/ingredients/wild_honey.tres` | Excursion-exclusive ingredient |
| `resources/foods/rainbow_creature.tres` | XP boost creature food |
| `resources/foods/excursion_berry.tres` | Healing creature food |
| `test/unit/excursion/test_excursion_generator.gd` | Generator determinism tests |
| `test/unit/excursion/test_excursion_manager.gd` | Manager state/logic tests |
| `test/unit/excursion/test_excursion_loot.gd` | Shared loot tests |

## Modified Files

| File | Changes |
|------|---------|
| `scenes/main/game_world.tscn` | Added ExcursionManager node |
| `scripts/world/game_world.gd` | Excursion entrance portal, HUD setup, disconnect handling |
| `scripts/battle/battle_manager.gd` | Shared loot distribution for excursion battles |
| `scripts/world/world_item_manager.gd` | Excursion pickup delegation |
| `scripts/world/friend_manager.gd` | `party_member_removed` and `party_member_added` signals |

## Entry Flow

1. Party leader walks into the Excursion Portal at `Vector3(-15, 0, 0)`
2. Server validates: party exists, leader, all members online/not-busy/not-in-battle/not-in-restaurant/not-in-excursion, `MAX_EXCURSION_INSTANCES` not exceeded
3. Server generates seed (`randi()`), snapshots current season
4. Creates instance data with UUID, allowed_player_ids from party members
5. Calls `ExcursionGenerator.generate_server()` for collision/encounter Area3Ds
6. Teleports all party members, saves overworld positions
7. RPCs `_enter_excursion_client()` to each member (sends seed + season + offset)
8. Client reconstructs visuals from seed (deterministic)
9. Spawns excursion world items via WorldItemManager

## Exit Flow

Triggers: voluntary (button/portal), disconnect, timeout, party disband/kick.

1. Restore overworld position from `overworld_positions[peer_id]`
2. Clear `player_excursion_map`, update location tracking
3. RPC `_exit_excursion_client()` (client queue_frees geometry)
4. Remove from instance members
5. If members empty -> cleanup instance (free nodes, despawn items, erase data)

## Late-Join Flow

1. Party leader invites friend mid-excursion (existing FriendManager flow)
2. `party_member_added` signal fires -> ExcursionManager adds to `allowed_player_ids`
3. New member calls `request_excursion_late_join.rpc_id(1)`
4. Server validates: player_id in allowed list, instance exists, not timed out
5. Teleport, send enter RPC with same seed/season/offset
6. Late joiners receive loot only from moment of entry

## Shared Loot System

### Battle Drops
When a player in an excursion wins a battle, drops are distributed to ALL current members:
- Each member gets identical item drops via `server_add_inventory()`
- Excursion bonus drops added (15% chance ingredient, 5% chance seed)
- XP is NOT shared (only battling player's creatures get XP)

### World Item Pickups
When a player picks up an excursion world item, all current members receive a copy:
- Item removed globally on first pickup (no duplication)
- Each member gets the item via `server_add_inventory()`
- `loot_log` tracks all grants per peer for audit

### Harvestable Objects (Trees, Rocks, Bushes)
Excursion instances spawn ~8-12 harvestable objects based on biome:
- **Trees** (DENSE_FOREST): axe, 3 HP, drops wood + herb_basil + mystic_herb
- **Rocks** (ROCKY_OUTCROP): axe, 4 HP, drops stone + spicy_essence + sweet_crystal
- **Bushes** (GRASSLAND/FLOWER_FIELD): hands, 1 HP, drops berry + wild_honey

When harvested, drops are shared to ALL excursion members (not just the harvester). Drop tables are richer than overworld. Harvestables respawn after their timer (120s/150s/90s).

### Dig Spots
3-5 dig spots per excursion, placed in low-height valleys:
- Require shovel equipped
- Excursion-specific rare loot table (golden_seed, ancient_grain_seed, starfruit_essence, etc.)
- Per-player per-spot daily cooldown (unique spot_ids prevent overworld conflicts)
- Drops shared to ALL excursion members

Both harvestable and dig spot nodes are created deterministically from the seed on both server and client (same as terrain).

## Procedural Generation

Uses 5 seeded FastNoiseLite instances:
- `biome_noise` (seed+0): biome type per cell
- `height_noise` (seed+1): terrain elevation (rolling hills, 0-6 units)
- `detail_noise` (seed+2): micro-height variation, prop density
- `resource_noise` (seed+3): resource/prop placement
- `rare_noise` (seed+4): rare grove zone placement

**Terrain:** 80x80 arena, 81x81 vertex heightmap. `SurfaceTool` mesh with per-vertex season-tinted colors. `ConcavePolygonShape3D` collision. Spawn area flattened.

**Biomes:** GRASSLAND, DENSE_FOREST, ROCKY_OUTCROP, WATER_EDGE, FLOWER_FIELD. Height-constrained (water < 1.0, rocky > 4.5). Season shifts thresholds.

**Determinism:** Same seed = identical output on server and all clients. Server sends 1 int (seed) + 1 string (season).

## Encounter Tables

| Table | Species | Level Range |
|-------|---------|-------------|
| excursion_common | Herb Guardian, Onigiri Knight, Tofu Block, Pumpkin Guard, Sourdough Sentinel, Taffy Serpent, Blaze Wyvern, Citrus Fiend | 10-20 |
| excursion_rare | Blaze Wyvern, Sorbet Phoenix, Truffle King, Citrus Fiend, Herb Guardian, Sushi Samurai | 18-35 |

## Excursion Items

| Item | Category | Sell Price | Notes |
|------|----------|-----------|-------|
| Golden Seed | Ingredient | 50 | Any-season premium crop |
| Mystic Herb | Ingredient | 40 | Rare creature recipe ingredient |
| Starfruit Essence | Ingredient | 45 | Rare crafting ingredient |
| Truffle Shaving | Ingredient | 55 | High-value cooking ingredient |
| Ancient Grain Seed | Ingredient | 45 | Rare heirloom crop seed |
| Wild Honey | Ingredient | 25 | Common excursion ingredient |
| Rainbow Creature Food | Food | 80 | XP x2.0 buff, 5 minutes |
| Excursion Berry | Food | 35 | Creature heal 50 HP |

## Networking

| Component | Authority | Sync |
|-----------|-----------|------|
| Instance creation/destruction | Server | RPCs to party members |
| Terrain seed + season | Server | `_enter_excursion_client` RPC |
| Visual geometry | Client (from seed) | None |
| Collision shapes | Server | Server-only Area3Ds |
| Encounters | Server (EncounterManager) | Existing battle RPCs |
| Shared loot | Server (ExcursionManager) | RPCs per member |
| World items | Server (WorldItemManager) | Existing spawn/despawn RPCs |
| Harvestables | Server (created + synced) | `_sync_state` RPC, client nodes from seed |
| Dig spots | Server (created + synced) | Client nodes from seed |
| Timer/status | Server | `_excursion_status_update` RPC |

### RPCs

**Client -> Server:**
- `request_enter_excursion()` - leader only
- `request_exit_excursion()` - any member
- `request_excursion_late_join()` - party member joining existing instance

**Server -> Client:**
- `_enter_excursion_client(instance_id, seed, season, offset_x, offset_y, offset_z)`
- `_exit_excursion_client()`
- `_excursion_action_result(action, success, message)`
- `_excursion_status_update(time_remaining_sec, member_count)`
- `_excursion_time_warning(seconds_remaining)` - at 2min and 30s
- `_grant_excursion_battle_rewards(drops)`
- `_show_excursion_grass(visible, is_rare)`
- `_notify_excursion_harvest(object_type, drops)` - shared harvest loot
- `_notify_excursion_dig(items)` - shared dig spot loot

## Exploit Prevention

| Exploit | Prevention |
|---------|------------|
| Re-entry farming | Instance destroyed on exit, no re-entry |
| Seed manipulation | Seed generated server-side |
| Loot duplication via reconnect | Late-joiner only gets loot from moment of entry |
| Double pickup | World item removed globally on first pickup |
| Party swap mid-loot | `allowed_player_ids` grows but loot only to current `members` |
| Passive XP farming | XP only to battling player |
| Disconnect position save | Disconnect restores overworld position |
| Orphaned instances | Timeout check every 10s, max 15 min, empty = immediate cleanup |

## MCP Testing

### Entry Flow
```
# Create party
execute_gdscript: var fm = get_node("/root/Main/GameWorld/FriendManager"); fm._process_create_party(peer_id)

# Enter excursion (call server method directly)
execute_gdscript: var em = get_node("/root/Main/GameWorld/ExcursionManager"); em._validate_and_enter(peer_id)
```

### Verify Instance
```
execute_gdscript: var em = get_node("/root/Main/GameWorld/ExcursionManager"); return {"instances": em.excursion_instances.size(), "mapped": em.player_excursion_map}
```

### Exit
```
execute_gdscript: var em = get_node("/root/Main/GameWorld/ExcursionManager"); em._exit_member(peer_id)
```

### Pickup Sharing
```
# Spawn item in excursion, then pick up — verify all members receive
execute_gdscript: var wim = get_node("/root/Main/GameWorld/WorldItemManager"); var uid = wim.spawn_world_item("mystic_herb", 1, Vector3(5040, 1, 5075), 0.0, "excursion_<id>"); wim.try_pickup(peer_id, uid)
```

### Verify Harvestables/Dig Spots
```
# Check harvestable count in excursion instance
execute_gdscript: var em = get_node("/root/Main/GameWorld/ExcursionManager"); var node = em._instance_nodes.values()[0]; var count = 0; for c in node.get_children(): { if c.is_in_group("harvestable_object"): count += 1 }; return {"harvestable_count": count}

# Check dig spot count
execute_gdscript: var em = get_node("/root/Main/GameWorld/ExcursionManager"); var node = em._instance_nodes.values()[0]; var count = 0; for c in node.get_children(): { if c.is_in_group("dig_spot"): count += 1 }; return {"dig_spot_count": count}
```

### Multi-Party Isolation Test
```
# Start server with run_multiplayer_session, connect 4 clients

# Create Party A (peer 2 + peer 3)
execute_gdscript target=runtime:server: var fm = get_node("/root/Main/GameWorld/FriendManager"); fm._process_create_party(2); fm._process_party_invite(2, 3)
execute_gdscript target=runtime:server: var fm = get_node("/root/Main/GameWorld/FriendManager"); fm._process_accept_party_invite(3, fm.player_party_map[fm._get_player_id(2)])

# Create Party B (peer 4 + peer 5)
execute_gdscript target=runtime:server: var fm = get_node("/root/Main/GameWorld/FriendManager"); fm._process_create_party(4); fm._process_party_invite(4, 5)
execute_gdscript target=runtime:server: var fm = get_node("/root/Main/GameWorld/FriendManager"); fm._process_accept_party_invite(5, fm.player_party_map[fm._get_player_id(4)])

# Enter excursion with both parties
execute_gdscript target=runtime:server: var em = get_node("/root/Main/GameWorld/ExcursionManager"); em._validate_and_enter(2)
execute_gdscript target=runtime:server: var em = get_node("/root/Main/GameWorld/ExcursionManager"); em._validate_and_enter(4)

# Verify isolation: 2 separate instances, different seeds/offsets
execute_gdscript target=runtime:server: var em = get_node("/root/Main/GameWorld/ExcursionManager"); return {"instance_count": em.excursion_instances.size(), "peer2_inst": em.player_excursion_map.get(2, ""), "peer4_inst": em.player_excursion_map.get(4, "")}
# Assert: instance_count == 2, peer2_inst != peer4_inst

# Verify loot isolation: harvest in Party A does NOT grant to Party B members
# (harvestable_object routes through excursion_mgr._on_excursion_harvest which only grants to inst["members"])
```
