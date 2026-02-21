# Audio System

## Architecture
- **AudioManager** autoload singleton (`scripts/autoload/audio_manager.gd`, ~500 lines)
- 6-bus layout in `default_bus_layout.tres`: Master, Music, SFX, UI, Ambience, Voice (all children of Master)
- Server guard: every public method exits early on dedicated server via `_is_server()` check. No audio nodes created server-side.
- Client-only: no networking impact. Audio is entirely local.

## Music System
- Two `AudioStreamPlayer` nodes for crossfade (1.5s duration)
- `play_music(context)` picks random track from context folder, crossfades
- Tracks `_music_context` and `_music_previous_context` for restore after battle
- `restore_previous_music()` resumes pre-battle context
- `play_music_next_track()` auto-called when current track finishes (loops playlist)
- `now_playing_changed` signal emitted on track change → HUD "Now Playing" label

### Music Contexts

| Context | Folder | Tracks | Trigger |
|---------|--------|--------|---------|
| menu | music/menu/ | 3 | ConnectUI `_ready()` |
| overworld | music/overworld/ | 6 | game_world.gd `_setup_ui()` |
| battle | music/battle/ | 5 | battle_arena_ui.gd (wild/trainer) |
| boss | music/boss/ | 3 | battle_arena_ui.gd (PvP) |
| restaurant | music/restaurant/ | 3 | restaurant_manager.gd enter |
| excursion | music/excursion/ | 6 | excursion_manager.gd enter |
| victory | music/victory/ | 3 | battle_arena_ui.gd win |
| defeat | music/defeat/ | 3 | battle_arena_ui.gd lose |

## SFX System
- Pool of 12 `AudioStreamPlayer` nodes on SFX bus
- 1 dedicated `AudioStreamPlayer` on UI bus
- 8 `AudioStreamPlayer3D` nodes for positional audio
- `play_sfx(id)` — fire and forget, picks idle player from pool
- `play_sfx_varied(id)` — random pitch (0.9-1.1) for footsteps etc
- `play_ui_sfx(id)` — dedicated UI player, no pitch variance
- `play_sfx_3d(id, position)` — positional audio

### SFX Registry (48 across 7 categories)

| Category | IDs | Files |
|----------|-----|-------|
| UI (8) | ui_click, ui_confirm, ui_cancel, ui_open, ui_close, ui_tab, ui_error, ui_hover | sfx/ui/ |
| Combat (15) | hit_physical, hit_special, hit_crit, super_effective, not_effective, miss, faint, switch, flee, heal, buff, debuff, status_apply, xp_gain, level_up | sfx/combat/ |
| Footsteps (4) | footstep_grass, footstep_stone, footstep_dirt, footstep_wood | sfx/footsteps/ |
| Tools (4) | tool_hoe, tool_axe, tool_water, tool_harvest | sfx/tools/ |
| Items (6) | item_pickup, item_craft, item_coin, item_equip, item_eat, item_door | sfx/items/ |
| Fishing (4) | fish_cast, fish_reel, fish_splash, fish_catch | sfx/fishing/ |
| Social (6) | dialogue_blip, gift, quest_accept, quest_complete, quest_progress, friend_request | sfx/social/ |

## Ambience System
- 3 layers: base (0), weather (1), zone (2) — each an `AudioStreamPlayer` on Ambience bus
- `play_ambience(layer, id)` — crossfades within layer
- `stop_ambience(layer)` / `stop_all_ambience()`

### Ambience Registry

| ID | Path | Trigger |
|----|------|---------|
| overworld | ambience/overworld/world_loop.ogg | game_world.gd, excursion exit, restaurant exit |
| restaurant | ambience/restaurant/indoor.ogg | restaurant_manager.gd enter |
| excursion | ambience/excursion/wilderness.ogg | excursion_manager.gd enter |
| rain | ambience/weather/rain.ogg | season_manager.gd weather change |
| storm | ambience/weather/storm.ogg | season_manager.gd weather change |
| wind | ambience/weather/wind.ogg | season_manager.gd weather change |

## Volume & Settings
- `set_bus_volume(bus_name, linear)` / `get_bus_volume(bus_name)` — per-bus 0.0-1.0
- `toggle_mute()` / `set_muted(bool)` — mutes Master bus
- `is_muted` property (read-only)
- Settings persisted to `user://settings.cfg` under `[audio]` section
- Keys: `master_volume`, `music_volume`, `sfx_volume`, `ui_volume`, `ambience_volume`, `voice_volume`, `muted`
- Backward compat: old single `master_volume` key still read for Master bus
- Bus defaults: Master=1.0, others=0.8, Ambience=0.6

## UI Integration
- **Settings tab** (`settings_tab.gd`): 6 per-bus HSlider controls (0.0-1.0, step 0.05) + mute checkbox
- **ConnectUI** (`connect_ui.gd`): Mute toggle button (top-right), starts menu music
- **HUD** (`hud.gd`): track name label in TopBar, fade-in on track change

## SFX Hook Locations

| System | File | Hooks |
|--------|------|-------|
| Battle | battle_arena_ui.gd | Hit/crit/miss/faint/heal/buff/status SFX, action menu clicks, flee |
| Battle XP | battle_arena_ui.gd | xp_gain, level_up |
| Pause menu | pause_menu.gd | ui_open, ui_close, ui_tab |
| Crafting | crafting_system.gd | item_craft, ui_error |
| Shop | shop_ui.gd | item_coin on buy/sell |
| Social/NPC | social_manager.gd | dialogue_blip, gift |
| Quests | quest_manager.gd | quest_accept, quest_progress, quest_complete |
| Friends | friend_manager.gd | friend_request (requests + party invites) |
| Farming | farm_manager.gd | tool_hoe/water/harvest per action |
| Fishing | fishing_manager.gd | fish_cast/splash/reel/catch |
| Player | player_controller.gd | Footsteps (timer-based, varied pitch), tool SFX on action start |
| HUD | hud.gd | item_pickup, quest_progress (discovery toast) |

## Export Handling
- `_scan_audio_folder()` handles `.ogg`, `.mp3`, `.wav`, `.remap`, and `.import` extensions
- Godot exports convert audio files to `.ogg.import` or `.ogg.remap` — both are handled
- Folder scan results cached in `_folder_cache` dict

## Adding New Audio
1. **New SFX**: Add `.ogg` file to `assets/audio/sfx/<category>/`, add entry to `SFX_REGISTRY` in audio_manager.gd, call `AudioManager.play_sfx("new_id")` where needed
2. **New music track**: Drop `.ogg` into the context folder (e.g. `assets/audio/music/overworld/`). Auto-discovered by folder scan.
3. **New music context**: Add entry to `MUSIC_CONTEXTS`, call `play_music("new_context")` at trigger point
4. **New ambience**: Add `.ogg` to `assets/audio/ambience/`, add to `AMBIENCE_REGISTRY`, call `play_ambience(layer, "new_id")`

## Asset Summary
- 85 audio files, ~75MB total
- 32 music tracks (OGG Vorbis, converted from Phat Phrog Studio WAV packs)
- 47 SFX (OGG Vorbis, converted from Feel SFX library WAV files, trimmed to 0.5-3s)
- 6 ambience loops (3 weather from Feel library + community animal pack, 3 base from community assets)
- Source packs: LoFi Music Bundle vols 1-3, RPG Music Bundle vol 1, RPG Piano Music Bundle vol 1, Sandbox Survival Piano Collection, Victory Fanfares, Defeat Outros, Feel (More Mountains), Low Poly Animated Animals (community)

## Key Files

| File | Role |
|------|------|
| `scripts/autoload/audio_manager.gd` | Core singleton (~500 lines) |
| `default_bus_layout.tres` | 6-bus layout |
| `project.godot` | AudioManager autoload registration |
| `assets/audio/` | All audio assets (music/, sfx/, ambience/) |
