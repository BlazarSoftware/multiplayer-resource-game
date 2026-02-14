# Agents Guide

## Quick Start (MCP Editor Session — preferred for local dev)
1. Use MCP `run_multiplayer_session` with `serverArgs: ["--server"]`, `numClients: 2`
2. Server auto-starts on port 7777 (no ConnectUI), clients show ConnectUI defaulting to `127.0.0.1`
3. Join clients via MCP `execute_gdscript` (emit join button pressed signal) or click "Join Game" manually

## Quick Start (Public Server)
1. Launch client with Mechanical Turk and open this project.
2. Click "Join Game" — exported builds default to `207.32.216.76` (public K8s server).

## Quick Start (Docker Local Dev)
1. Start server: `./scripts/start-docker-server.sh`
2. Launch client, click "Join Game" — editor defaults to `127.0.0.1`.

## Quick Start (Kubernetes Deploy)
1. First-time setup: `./scripts/deploy-k8s.sh --setup`
2. Build, push, and deploy: `./scripts/deploy-k8s.sh`
3. Join using `207.32.216.76:7777` (public) or `10.225.0.153:7777` (VPN).

## Networking Contract
- Server/client default UDP port is `7777`.
- **Smart IP defaults**: Editor ConnectUI defaults to `127.0.0.1` (localhost). Exported builds default to `207.32.216.76` (public server). Editor mode ignores saved prefs for IP to prevent stale overrides.
- **Dedicated server detection** (3 triggers in `NetworkManager._ready()`):
  1. `DisplayServer.get_name() == "headless"` — Docker/headless export
  2. `OS.has_feature("dedicated_server")` — Godot dedicated server export
  3. `"--server" in OS.get_cmdline_user_args()` — CLI flag (used by MCP `run_multiplayer_session`)
- When dedicated: auto-calls `host_game()` + `start_game()`, skips ConnectUI, skips game world UI (HUD, BattleUI, etc.)
- Any tooling, scripts, docs, and deployment defaults should assume port `7777`.

## Multiplayer-Aware Development (CRITICAL)

This is a server-authoritative persistent MMO. **Any gameplay change — new feature, new action, new resource, any UI that affects game state — must be evaluated for networking impact.** If the user does not specify whether a change should be networked (synced to other clients), always ask before implementing.

### Questions to resolve before writing code
- Should this run on **server only**, **client only**, or **both**?
- Does the server need to **validate/authorize** this action? (Almost always yes for anything that changes player data, inventory, party, or world state.)
- Do other clients need to **see the result**? If so, how is it synced — RPC, StateSync property, or MultiplayerSpawner?
- Is there a **race condition** if the client optimistically updates before the server confirms?
- Does this state need to **persist** across sessions (saved to disk)?

Never assume a gameplay feature is local-only unless explicitly told so.

### Authority Model
| System | Authority | Sync mechanism |
|--------|-----------|---------------|
| Player movement | Server (`_physics_process`) | StateSync (position, velocity) |
| Player rotation | Server (`_physics_process`) | StateSync (`mesh_rotation_y`, on-change) |
| Player visuals (color, name) | Server (set before spawn) | StateSync (spawn-only) |
| Camera / input | Client (InputSync) | InputSync → server reads |
| Inventory | Server (`server_add/remove_inventory`) | RPC to client |
| Watering can | Server (`server_use/refill_watering_can`) | RPC to client |
| Farm actions | Server (`request_farm_action` RPC) | Server validates, RPCs result |
| Battle state | Server (BattleManager) | RPCs to involved clients |
| Crafting | Server (CraftingSystem) | RPC results to client |
| Save/load | Server only (SaveManager) | `_receive_player_data` RPC on join |

### Data Flow Rules
- **Server-side data**: `NetworkManager.player_data_store[peer_id]` — the authoritative copy of each player's inventory, party, position, watering can, color, etc.
- **Client-side mirror**: `PlayerData` autoload — local copy for UI display. Updated only via server RPCs, never written to by server code.
- **Never deduct resources client-side before server confirms.** Server deducts from `player_data_store` first, then syncs to client via RPC.
- **Never modify `PlayerData` on the server process.** It's the client's local mirror only.

### Adding New Synced State (checklist)
1. Add the field to `NetworkManager._create_default_player_data()` (server default)
2. Add server helper functions to `NetworkManager` (e.g., `server_use_X`, `server_add_X`)
3. Add field to `PlayerData.load_from_server()`, `to_dict()`, and `reset()` (client mirror)
4. Add validation in the server-side RPC handler (don't trust the client)
5. Add sync RPC from server to client after successful action
6. If visually synced to all players: add to `player_controller.gd` + StateSync config in `player.tscn`
7. If only the owning player needs it: use targeted `rpc_id(sender, ...)`

## Multiplayer Expectations
- Server is authoritative for world state and movement simulation.
- Client must complete world-load readiness before spawn replication begins.
- If join fails, inspect logs for readiness/replication errors first.

## UI/UX Expectations
- Battle encounters must show mouse cursor for UI interaction.
- Exiting battle should recapture mouse for movement/camera control.
- Wild encounter areas should be clearly visible in-world and explained via HUD hinting.

## Kubernetes Deployment
- Namespace: `godot-multiplayer` (shared with sheep-tag and other game servers).
- Image: `ghcr.io/crankymagician/mt-creature-crafting-server:latest`.
- NodePort `7777` → container `7777/UDP`. Public IP: `207.32.216.76`. Internal/VPN: `10.225.0.153`.
- **Node SSH access**: `ssh jayhawk@10.225.0.153` (password: `fir3W0rks!`). User has sudo. k3s config at `/etc/rancher/k3s/config.yaml`.
- Player/world saves persist on a 1Gi PVC (`creature-crafting-data`) at `/app/data`.
- Deploy strategy is `Recreate` (RWO PVC constraint).
- Manifests live in `k8s/deployment.yaml` and `k8s/service.yaml`.
- Deploy script: `scripts/deploy-k8s.sh` (`--setup` for first-time, `--skip-build` to redeploy only).

## MCP Testing Workflow

### Preferred: `run_multiplayer_session`
- Use MCP `run_multiplayer_session` with `serverArgs: ["--server"]`, `numClients: 2`
- Target instances: `"runtime:server"`, `"runtime:client_1"`, `"runtime:client_2"`
- Join clients: `execute_gdscript` with `target: "runtime:client_N"` to emit join button pressed signal
- Verify state: `get_scene_tree`, `execute_gdscript`, `get_debug_output` (per instance)
- Cleanup: `stop_all_instances`
- **Screenshot caching**: MCP screenshot tool may cache — use `get_scene_tree` or `execute_gdscript` for reliable verification

### Alternative: Editor bridge test pattern
- MCP bridge by default talks to the editor process on port 9080, not the running game.
- **To test server-side logic**: add temp test code to `connect_ui.gd` `_ready()`, call `NetworkManager.host_game()`, run assertions synchronously, then check `get_debug_output`. Revert test code after.
- **Do NOT** call `GameManager.start_game()` before tests finish — it frees ConnectUI and kills any running coroutine.

### Port conflicts
- If `host_game()` fails with error 20, run `lsof -i :7777` and stop whatever is holding the port (usually Docker: `docker compose down`).

## Operational Notes
- If local container/server appears stale, rebuild:
  - `docker compose up --build -d`
- If needed, force rebuild without cache:
  - `docker compose build --no-cache`
  - `docker compose up -d`
- If K8s pod appears stale, redeploy:
  - `./scripts/deploy-k8s.sh`
  - Or restart without rebuild: `./scripts/deploy-k8s.sh --skip-build`
