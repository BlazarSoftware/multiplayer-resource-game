# Claude Notes

## Project Runtime Defaults
- Multiplayer default port: `7777` (UDP).
- Local client connects to `127.0.0.1` on port `7777`.
- Dedicated server can be run in Docker or Mechanical Turk headless mode.

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

## Battle System
- **3 battle modes**: Wild, Trainer (7 NPCs), PvP (V key challenge)
- **18 creatures** (9 original + 9 new), 4 evolution chains, MAX_PARTY_SIZE = 3
- **42 moves** including weather setters, hazards, protection, charging, multi-hit, recoil, drain
- **18 abilities** with trigger-based dispatch (on_enter/on_attack/on_defend/on_status/end_of_turn/on_weather)
- **12 held items** (6 type boosters, 6 utility) — all craftable from ingredients
- **XP/Leveling**: XP from battles, level-up stat recalc, learnset moves, evolution
- **AI**: 3 tiers (easy=random, medium=type-aware, hard=damage-calc + prediction)
- **PvP**: Both-submit simultaneous turns, 30s timeout, disconnect = forfeit

## Crafting & Farming
- **25 recipes**: 13 creature recipes + 12 held item recipes
- **16 ingredients**: farm crops (season-locked) + battle drops
- Crafting UI splits into "Creature Recipes" and "Held Item Recipes" sections
- New plantable crops: lemon (summer), pickle_brine (autumn)

## Wild Encounter Zones
- 6 zones total: Herb Garden, Flame Kitchen, Frost Pantry, Harvest Field, Sour Springs, Fusion Kitchen
- Represented by glowing colored grass patches with floating in-world labels
- HUD provides persistent legend + contextual hint when inside encounter grass

## NPC Trainers
- 7 trainers placed along world paths under `Zones/Trainers` in game_world.tscn
- Area3D proximity detection triggers battle; re-trigger after leaving and re-entering
- Color-coded by difficulty: green=easy, yellow=medium, red=hard
- Trainers: Sous Chef Pepper, Farmer Green, Pastry Chef Dulce, Brinemaster Vlad, Chef Umami, Head Chef Roux, Grand Chef Michelin

## GDScript Conventions
- Use `class_name` for static utility classes (BattleCalculator, StatusEffects, FieldEffects, AbilityEffects, HeldItemEffects, BattleAI)
- Do NOT preload scripts that already have `class_name` — causes "constant has same name as global class" warning
- Prefix unused parameters/variables with `_` to suppress warnings
- Use `4.0` instead of `4` in division to avoid integer division warnings

## Export Build Gotchas
- **DataRegistry .tres/.remap handling**: Godot exports convert `.tres` files to `.tres.remap` (binary format with remap indirection). Any code using `DirAccess` to scan for resources must check `.tres`, `.res`, AND `.remap` extensions — otherwise the exported build loads zero resources while the editor build works fine.
- **Battle stacking prevention**: All encounter/battle entry points (TallGrass, EncounterManager, TrainerNPC) must check `BattleManager.player_battle_map` before starting a new battle. The `active_encounters` dict in EncounterManager only tracks wild encounters, NOT trainer/PvP battles. Client-side `start_battle_client()` also guards against duplicate `_start_battle_client` RPCs.
- **stdbuf for Docker logs**: Godot headless buffers stdout, making `docker logs` empty. The Dockerfile uses `stdbuf -oL` in the CMD to force line-buffered output.

## Kubernetes Deployment
- **Namespace**: `godot-multiplayer` (shared with other multiplayer game servers)
- **Image**: `ghcr.io/crankymagician/mt-creature-crafting-server:latest`
- **Endpoint**: `10.225.0.153:30777` (UDP) — NodePort 30777 → container 7777
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

## MCP Limitations
- MCP bridge only communicates with the editor process, NOT the running game
- `execute_gdscript`, `send_input_event`, `send_action`, and screenshots all target the editor only
- To test the running game: temporarily add auto-connect to connect_ui.gd, run project, check `get_debug_output`, then revert
- `batch_scene_operations` creates wrong node types — write .tscn files directly instead

## File Structure Overview
- `scripts/autoload/` — NetworkManager, GameManager, PlayerData, SaveManager
- `scripts/data/` — 10 Resource class definitions
- `scripts/battle/` — BattleManager, BattleCalculator, StatusEffects, FieldEffects, AbilityEffects, HeldItemEffects, BattleAI
- `scripts/world/` — FarmPlot, FarmManager, SeasonManager, TallGrass, EncounterManager, GameWorld, TrainerNPC
- `scripts/crafting/` — CraftingSystem
- `scripts/player/` — PlayerController, PlayerInteraction
- `scripts/ui/` — ConnectUI, HUD, BattleUI, CraftingUI, InventoryUI, PartyUI, PvPChallengeUI, TrainerDialogueUI
- `resources/` — ingredients/ (16), creatures/ (18), moves/ (42), encounters/ (6), recipes/ (25), abilities/ (18), held_items/ (12), trainers/ (7)
