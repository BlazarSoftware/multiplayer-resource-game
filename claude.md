# Claude Notes

## Project Runtime Defaults
- Multiplayer default port: `7777` (UDP).
- **Smart IP defaults**: In editor, ConnectUI defaults to `127.0.0.1` (localhost). In exported builds, defaults to `207.32.216.76` (public server). Editor mode ignores saved prefs for IP to prevent stale overrides.
- **Dedicated server detection** (3 triggers, checked in `NetworkManager._ready()`):
  1. `DisplayServer.get_name() == "headless"` — Docker/headless export
  2. `OS.has_feature("dedicated_server")` — Godot dedicated server export
  3. `"--server" in OS.get_cmdline_user_args()` — CLI flag (used by MCP `run_multiplayer_session`)
- When dedicated mode is detected: auto-calls `host_game("Server")` + `GameManager.start_game()`, skips ConnectUI entirely, skips game world UI setup (HUD, BattleUI, etc.).

## Docker Server Workflow
- Use `./scripts/start-docker-server.sh` to rebuild and start the dedicated server.
- The script runs `docker compose up --build -d` from the project root and prints service status.
- Docker mapping is `7777:7777/udp`.
- Docker logs work in real-time via `docker logs -f multiplayer-resource-game-game-server-1` (uses `stdbuf -oL` for line-buffered output).
- Godot's internal log file is also available: `docker exec <container> cat "/root/.local/share/godot/app_userdata/Creature Crafting Demo/logs/godot.log"`

## Multiplayer Join/Spawn Stabilization
- Join flow uses a client-ready handshake before server-side spawn.
- Spawn waits for client world path readiness (`/root/Main/GameWorld/Players/MultiplayerSpawner`).
- Server tracks temporary join state and times out peers that never become ready.

## Player/Camera Notes
- Player movement uses server authority with replicated input.
- Camera defaults to over-the-shoulder and captures mouse during world control.
- Mouse is explicitly made visible during battle UI and recaptured after battle ends.
- **Player visuals** (color, nameplate): set on the player node server-side **before** `add_child()` in `_spawn_player()`, synced via StateSync spawn-only mode (replication_mode=0). `_apply_visuals()` runs on all peers to apply color to mesh material and set nameplate text.
- **Mesh rotation**: `mesh_rotation_y` computed server-side in `_physics_process`, synced via StateSync always-mode. All clients apply it in `_process()` to `mesh.rotation.y`.
- **StateSync properties** (5 total): `position`, `velocity` (always), `player_color`, `player_name_display` (spawn-only), `mesh_rotation_y` (always).

## Battle System
- **3 battle modes**: Wild, Trainer (7 NPCs), PvP (V key challenge within 5 units of another player)
- **18 creatures** (9 original + 9 new), 4 evolution chains, MAX_PARTY_SIZE = 3
- **Starter creature**: All new players spawn with Rice Ball (Grain, Lv 5, 45 HP) with moves: grain_bash, quick_bite, bread_wall, taste_test
- **42 moves** including weather setters, hazards, protection, charging, multi-hit, recoil, drain
- **18 abilities** with trigger-based dispatch (on_enter/on_attack/on_defend/on_status/end_of_turn/on_weather)
- **12 held items** (6 type boosters, 6 utility) — all craftable from ingredients
- **XP/Leveling**: XP from battles, level-up stat recalc, learnset moves, evolution. Full XP to participants, 50% to bench.
- **AI**: 3 tiers (easy=random, medium=type-aware, hard=damage-calc + prediction)
- **PvP**: Both-submit simultaneous turns, 30s timeout, disconnect = forfeit. Loser forfeits 25% of each ingredient stack to winner.
- **Defeat penalty**: 50% money loss, teleport to spawn point, all creatures healed

### Battle UI
- **Enemy panel**: name, level, types, HP bar, status effect, stat stage labels (e.g. "Stats: DEF+2 SPA+1")
- **Player panel**: name, level, types, HP bar, XP bar, ability name, held item name
- **Move buttons**: 3-line format — Name / Type|Category|Power / Accuracy|PP (e.g. "Grain Bash / Grain | Phys | Pwr:65 / Acc:100% | 15/15 PP")
- **Weather bar**: shown when weather is active, displays weather name + remaining turns
- **Flee/Switch**: Flee available in wild only, Switch always available (opens creature picker overlay)
- **Turn log**: scrolling RichTextLabel showing move results, damage, status effects, faints
- **Summary screen**: shown after battle ends — hides all battle panels, shows Victory!/Defeat, XP per creature (with level-up highlights), item drops, trainer money + bonus ingredients. Continue button dismisses and returns to world.
- **PvP-specific**: no Flee button, "Waiting for opponent..." label after submitting move, both perspectives actor-swapped

### Battle Manager Server-Side
- Battle state keyed by `battle_id` (auto-increment), `player_battle_map[peer_id] → battle_id`
- Wild/Trainer: server picks AI action, resolves turn, sends `_send_turn_result` RPC
- PvP: both sides submit via `request_battle_action` RPC, server resolves when both received
- Rewards sent via separate RPCs: `_grant_battle_rewards` (drops), `_send_xp_results` (XP/level-ups), `_grant_trainer_rewards_client` (money+ingredients), `_battle_defeat_penalty` (money loss)
- Client accumulates reward data in `summary_*` vars, summary screen displays after 0.5s delay

## Crafting & Farming
- **25 recipes**: 13 creature recipes + 12 held item recipes
- **16 ingredients**: farm crops (season-locked) + battle drops
- Crafting UI splits into "Creature Recipes" and "Held Item Recipes" sections
- New plantable crops: lemon (summer), pickle_brine (autumn)
- **Planting flow** (server-authoritative): Client sends `request_farm_action(plot_idx, "plant", seed_id)` RPC to server. Server removes seed from `player_data_store` inventory, attempts plant, rolls back on failure. No client-side inventory deduction.
- **Watering flow** (server-authoritative): Client sends `request_farm_action(plot_idx, "water", "")` RPC. Server calls `server_use_watering_can()` to decrement, then syncs remaining charges to client via `_sync_watering_can` RPC. Refill via `_request_refill` RPC at water sources.

## Wild Encounter Zones
- 6 zones total: Herb Garden, Flame Kitchen, Frost Pantry, Harvest Field, Sour Springs, Fusion Kitchen
- Represented by glowing colored grass patches with floating in-world labels
- HUD provides persistent legend + contextual hint when inside encounter grass

## NPC Trainers
- 7 trainers placed along world paths under `Zones/Trainers` in game_world.tscn
- Area3D proximity detection triggers battle; re-trigger after leaving and re-entering
- Color-coded by difficulty: green=easy, yellow=medium, red=hard
- Trainers: Sous Chef Pepper, Farmer Green, Pastry Chef Dulce, Brinemaster Vlad, Chef Umami, Head Chef Roux, Grand Chef Michelin

## Networking Rules (IMPORTANT)

This is a server-authoritative multiplayer game. **Every gameplay change — new feature, new action, new resource, any UI that affects game state — must be evaluated for networking impact.** If the user does not specify whether a change should be networked, always ask before implementing.

### Questions to resolve before writing code
- Should this run on **server only**, **client only**, or **both**?
- Does the server need to **validate/authorize** this action? (Almost always yes for anything that changes player data, inventory, party, or world state.)
- Do other clients need to **see the result**? If so, how is it synced — RPC, MultiplayerSynchronizer property, or MultiplayerSpawner?
- Is there a **race condition** if the client optimistically updates before the server confirms?

### Authority model
| System | Authority | Sync mechanism |
|--------|-----------|---------------|
| Player movement | Server (`_physics_process`) | StateSync (position, velocity) |
| Player rotation | Server (`_physics_process`) | StateSync (`mesh_rotation_y`) |
| Player visuals (color, name) | Server (set before spawn) | StateSync (spawn-only) |
| Camera / input | Client (InputSync) | InputSync → server reads |
| Inventory changes | Server (`server_add/remove_inventory`) | RPC to client (`_sync_inventory_remove`, `_grant_harvest`) |
| Watering can | Server (`server_use/refill_watering_can`) | RPC to client (`_sync_watering_can`, `_receive_refill`) |
| Farm actions (plant/water/harvest/till) | Server (`request_farm_action` RPC) | Server validates, then RPC result to client |
| Battle state | Server (BattleManager) | RPCs to involved clients |
| Crafting | Server (CraftingSystem validates) | RPC results to client |
| Save/load | Server only (SaveManager) | Data sent to client via `_receive_player_data` |

### Never do this
- **Never deduct resources client-side before server confirms.** Always let the server deduct first, then sync to client via RPC. The old planting flow had this bug — client removed seed, then told server, creating desync on disconnect.
- **Never assume a gameplay feature is local-only** unless explicitly told so. Even "cosmetic" things like player color need syncing in multiplayer.
- **Never modify `PlayerData` (the autoload) on the server.** `PlayerData` is the client's local mirror. The server uses `NetworkManager.player_data_store[peer_id]`. Sync changes from server store to client PlayerData via RPC.

## GDScript Conventions
- Use `class_name` for static utility classes (BattleCalculator, StatusEffects, FieldEffects, AbilityEffects, HeldItemEffects, BattleAI)
- Do NOT preload scripts that already have `class_name` — causes "constant has same name as global class" warning
- Prefix unused parameters/variables with `_` to suppress warnings
- Use `4.0` instead of `4` in division to avoid integer division warnings

## Export Build Gotchas
- **DataRegistry .tres/.remap handling**: Godot exports convert `.tres` files to `.tres.remap` (binary format with remap indirection). Any code using `DirAccess` to scan for resources must check `.tres`, `.res`, AND `.remap` extensions — otherwise the exported build loads zero resources while the editor build works fine.
- **Battle stacking prevention**: All encounter/battle entry points (TallGrass, EncounterManager, TrainerNPC) must check `BattleManager.player_battle_map` before starting a new battle. The `active_encounters` dict in EncounterManager only tracks wild encounters, NOT trainer/PvP battles. Client-side `start_battle_client()` also guards against duplicate `_start_battle_client` RPCs.
- **stdbuf for Docker logs**: Godot headless buffers stdout, making `docker logs` empty. The Dockerfile uses `stdbuf -oL` in the CMD to force line-buffered output.
- **CanvasLayer child visibility persistence**: If you hide all children of a CanvasLayer (e.g. for a summary overlay), you MUST restore their visibility when the next screen/battle starts. Setting the CanvasLayer's own `visible` property does not propagate to children. The `_on_battle_started()` handler restores all child visibility and cleans up leftover dynamically-created panels.

## Kubernetes Deployment
- **Namespace**: `godot-multiplayer` (shared with other multiplayer game servers)
- **Image**: `ghcr.io/crankymagician/mt-creature-crafting-server:latest`
- **Public endpoint**: `207.32.216.76:7777` (UDP) — NodePort 7777 → container 7777.
- **Internal/VPN endpoint**: `10.225.0.153:7777`.
- **Node SSH access**: `ssh jayhawk@10.225.0.153` (password: `fir3W0rks!`). User has sudo. k3s config at `/etc/rancher/k3s/config.yaml`. NodePort range: `7000-32767`.
- **Persistent storage**: 1Gi PVC (`creature-crafting-data`) mounted at `/app/data` for player/world saves
- **Deploy strategy**: `Recreate` (RWO PVC can't be shared during rolling update)
- **MCP config**: `.claude/mcp.json` provides both Godot and Kubernetes MCP servers
- **K8s MCP**: Uses `blazar-kubernetes-mcp/run-mcp.sh` with `K8S_NAMESPACE=godot-multiplayer`
- **RBAC**: Service account `mcp-admin` in `godot-multiplayer` namespace (configured in `blazar-kubernetes-mcp/k8s/rbac-setup.yaml`)

### K8s Deploy Workflow
```bash
./scripts/deploy-k8s.sh --setup      # first-time: namespace + ghcr-secret + RBAC
./scripts/deploy-k8s.sh              # full build + push + deploy
./scripts/deploy-k8s.sh --skip-build # redeploy without rebuilding image
```

## MCP Testing Workflow

### Editor-only bridge (single process)
- MCP bridge by default communicates with the editor process on port 9080, NOT the running game
- `batch_scene_operations` creates wrong node types — write .tscn files directly instead
- **To test server-side logic via MCP**: add temporary test code to `connect_ui.gd` `_ready()`, call `NetworkManager.host_game()`, run tests synchronously (no `await`), then check `get_debug_output`. Revert the test code afterward.
- **IMPORTANT**: Do NOT call `GameManager.start_game()` before your test code finishes — it frees ConnectUI via `queue_free`, killing any running coroutine. Run all assertions before `start_game()`.

### Runtime bridge — MCP multiplayer session (preferred)
- **Use `run_multiplayer_session` MCP tool** for multi-instance testing. It launches 1 server + N clients, each with a unique runtime bridge port, all managed by MCP.
- Pass `serverArgs: ["--server"]` so the server instance auto-starts without ConnectUI.
- Pass `numClients: 2` (or more) for client instances.
- Target instances with `target: "runtime:server"`, `target: "runtime:client_1"`, `target: "runtime:client_2"`, etc.
- **Lifecycle**: `stop_all_instances` to stop everything, `list_instances` to see running PIDs/ports.
- **Client join via GDScript**: Use `execute_gdscript` with `target: "runtime:client_N"` to emit the join button's pressed signal rather than mouse click coordinates (viewport coords vary).
- **Screenshot caching**: MCP screenshot tool may cache results — use `get_scene_tree` or `execute_gdscript` for reliable state verification.

### Runtime bridge — manual setup (alternative)
- The runtime bridge plugin enables `execute_gdscript`, `capture_screenshot`, `send_input_event`, and `send_action` on **running game processes**
- Each instance uses a different bridge port via `-- --bridge-port=NNNN` CLI arg
- **Headless server**: `'/Applications/Mechanical Turk.app/Contents/MacOS/Mechanical Turk' --path <project> --headless -- --bridge-port=9082`
- **Client 1**: launched via `run_project` MCP tool (uses default bridge port 9081)
- **Client 2**: launched manually with `-- --bridge-port=9083`

### Runtime bridge caveats
- **GDScript injection caveats**: runtime errors in injected scripts trigger the Godot debugger break, freezing the entire process. All subsequent MCP calls will timeout. Requires killing and restarting the process. GDScript has no try/catch.
- **Screenshot size**: use small resolutions (400x300) to avoid WebSocket `ERR_OUT_OF_MEMORY` on large images
- **PvP testing**: players must be within 5 units for challenge flow. Move them on server via `nm._get_player_node(peer_id).position = Vector3(...)`. PvP has 30s turn timeout — act quickly or increase temporarily.

### Port conflicts
- If `host_game()` returns error 20 (ERR_CANT_CREATE), check `lsof -i :7777` — a Docker container or previous server may be holding the port. Stop it with `docker compose down` first.
- Check bridge ports: `lsof -i :9081 -i :9082 -i :9083`

## File Structure Overview
- `scripts/autoload/` — NetworkManager, GameManager, PlayerData, SaveManager
- `scripts/data/` — 10 Resource class definitions
- `scripts/battle/` — BattleManager, BattleCalculator, StatusEffects, FieldEffects, AbilityEffects, HeldItemEffects, BattleAI
- `scripts/world/` — FarmPlot, FarmManager, SeasonManager, TallGrass, EncounterManager, GameWorld, TrainerNPC
- `scripts/crafting/` — CraftingSystem
- `scripts/player/` — PlayerController, PlayerInteraction
- `scripts/ui/` — ConnectUI, HUD, BattleUI, CraftingUI, InventoryUI, PartyUI, PvPChallengeUI, TrainerDialogueUI
- `resources/` — ingredients/ (16), creatures/ (18), moves/ (42), encounters/ (6), recipes/ (25), abilities/ (18), held_items/ (12), trainers/ (7)
