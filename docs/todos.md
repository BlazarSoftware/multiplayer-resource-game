# Demo Build Todos

## Completed (Phases 0-4)

- [x] Import Synty POLYGON assets (16 packs)
- [x] Import Animpic low-poly assets (9 packs)
- [x] Import Godot community assets (14 packs)
- [x] Create world_toon.gdshader and water.gdshader
- [x] Refactor game_world.gd with town district layout, paths, signs, decorations
- [x] Update game_world.tscn with 15 NPC nodes and 4 new encounter zones
- [x] Remap 5 NPCs (baker→hubert, herbalist→murphy, fisherman→captain_sal, blacksmith→pepper, librarian→quill)
- [x] Create 10 new NPCs (mayor, innkeeper, potter, tailor, gardener, doctor, general_store, clementine, river, alex)
- [x] Fix all old NPC ID references across quests, locations, dialogues
- [x] Create 32 new quests (Acts 1-4 main story chain + 8 side quests)
- [x] Create 60 new ingredients (104 total)
- [x] Create 40 new creatures (61 total)
- [x] Create 60 new moves (117 total)
- [x] Create 80 new recipes (153 total)
- [x] Create 40 new foods (63 total)
- [x] Create 15 new held items (33 total)
- [x] Create 4 new encounter tables (fermented_hollow, blackened_crest, battered_bay, salted_shipwreck)
- [x] Create 25 new locations (54 total)
- [x] Expand all 6 original + 2 excursion encounter tables with new creatures
- [x] Clear local save data for fresh start

## Remaining Work

### Save/DB Cleanup
- [ ] Clear MongoDB player + world data on next `docker compose up` — run: `docker exec mongodb mongosh creature_crafting --eval "db.players.drop(); db.world.drop()"`

### Update demo-plan.md
- [ ] Update status section with current content counts (61 creatures, 153 recipes, 104 ingredients, 15 NPCs, 38 quests, 10 encounter zones)
- [ ] Update NPC roster to reflect new names (Hubert Crumb, Old Sage Murphy, etc.)

### Phase 5: New Gameplay Systems

#### Train Arrival Intro Sequence
- [ ] Create `scenes/intro/train_arrival.tscn` — camera pan along coastline, Cordelia's letter overlay
- [ ] Create `scenes/ui/letter_ui.tscn` — parchment-style letter display
- [ ] Create `scripts/intro/intro_controller.gd` — manages intro sequence, transitions to spawn
- [ ] Add skip button for returning players
- [ ] First-time player flag in save data to trigger intro

#### Restaurant Service Loop
- [ ] Create `scripts/world/restaurant_service.gd` — customer arrival during lunch/dinner
- [ ] Create `scenes/ui/restaurant_service_ui.tscn` — order display, timer, reputation counter
- [ ] Server-authoritative order generation
- [ ] Cooking validation via existing crafting system
- [ ] Reputation tracking in player_data_store
- [ ] Customer satisfaction feedback

#### Spice Challenge Mini-Game
- [ ] Create `scripts/minigames/spice_challenge.gd` — rhythm/timing game
- [ ] Create `scenes/ui/spice_challenge_ui.tscn` — button press matching patterns
- [ ] Trigger from Pepper's quest (ms_34_spice)
- [ ] Server-validated results

#### New Shop Definitions
- [ ] Create shop .tres for Bloom and Grow (Iris) — seeds, fertilizer
- [ ] Create shop .tres for The Book Nook (Quill) — recipe scrolls, lore
- [ ] Create shop .tres for Threads and Needles (Scarlet) — cosmetics
- [ ] Create shop .tres for Dr. Honey's Clinic — Munchie care items

### Phase 6: Polish & Demo Flow

#### Demo Progression Controller
- [ ] Create `scripts/world/demo_controller.gd` — tracks 4-act progression
- [ ] Hook into quest completion signals for act transitions
- [ ] End-of-demo trigger on ms_45_celebration completion

#### Day/Night Visual System
- [ ] Finish day_night_controller.gd (currently modified on branch)
- [ ] Time-of-day lighting changes
- [ ] Morning mist, golden hour, night lanterns

#### Environmental Polish
- [ ] Environmental audio placeholders per district
- [ ] Seasonal decoration references in NPC dialogue
- [ ] Weather visual effects (rain particles, fog shader)

#### NPC Visual Upgrade
- [ ] Select character GLBs from Synty POLYGON_Fantasy_Characters per NPC
- [ ] Add model_scene_path to NPCDef or lookup table in social_npc.gd
- [ ] Replace colored primitives with actual character models

#### Content Verification
- [ ] Full quest chain playthrough (Acts 1-4) as new player
- [ ] Verify all 15 NPCs render and have correct dialogue
- [ ] Verify all 10 encounter zones trigger battles with correct creatures
- [ ] Verify DataRegistry loads all new .tres files without errors
- [ ] Performance check with all imported assets
- [ ] Multiplayer test — join with 2 clients, verify town + NPCs for both

### Known Technical Debt
- [ ] New creature types (protein, dairy, liquid, mineral, earthy, toxic, aromatic, tropical, bitter) have no type effectiveness in TYPE_CHART — all neutral (1.0x). Either expand the chart or map these types to the 6 core types (spicy, sweet, sour, herbal, umami, grain)
- [ ] New ingredient .tres files created by agent used `shadow_truffle` and `ancient_letter` instead of plan's `void_truffle` and `phoenix_feather` — verify recipe ingredient references match
- [ ] Location .tres files for old NPCs kept old location_ids (npc_brioche, npc_herbalist, etc.) to avoid breaking existing save discovery tracking — but saves are now cleared so these could be renamed
- [ ] The `blaze_wyvern` creature exists but also appears in existing encounter tables — verify no duplicate/conflict issues
