# Animation System

## Architecture

- **Character model**: Quaternius UAL mannequin (`assets/models/mannequin_f.glb`), 65 Unreal-style bones (`pelvis`, `spine_01`, `spine_02`, `Head`, `clavicle_l`, etc.)
- **Animation source**: Quaternius Universal Animation Library — `assets/animations/ual/UAL1.glb` (127 anims) + `UAL2.glb` (135 anims) = 260 animations total
- **AnimationTree as standalone AnimationMixer** (NOT paired with a separate AnimationPlayer). Library loaded via `anim_tree.add_animation_library()`, root_node set to `../CharacterModel`.
- **Why standalone**: In Godot 4.x, AnimationTree with a separate AnimationPlayer via `anim_player` path silently fails to drive Skeleton3D bone poses through blend trees.
- **Animation library**: `assets/animations/player_animation_library.tres` — built via `tools/build_animation_library.gd`. Track paths: `Armature/Skeleton3D:bone_name` (no remapping needed).
- **GLB structure**: `CharacterModel > Armature > Skeleton3D > Mannequin_F` (65 Unreal bones).

## Blend Tree

Two-level state machine:
- **Stance**: stand / crouch
- **Standing locomotion**: Idle / Jog / Run
- **Crouch locomotion**: CrouchIdle / CrouchWalk
- Jump / Fall / Land layered on top

## Locomotion Mapping

| State | Animation |
|-------|-----------|
| Idle | `Idle` |
| Jog | `Jog_Fwd` |
| Sprint | `Sprint` |
| CrouchIdle | `Crouch_Idle` |
| CrouchWalk | `Crouch_Fwd` |
| JumpUp | `Jump_Start` |
| Falling | `Jump` |
| Landing | `Jump_Land` |

## Tool Action Mapping (`_get_tool_animation_name()`)

| Tool/Action | Animation |
|------------|-----------|
| `hoe` | `Farm_PlantSeed` |
| `axe` | `TreeChopping` |
| `water` | `Farm_Watering` |
| `harvest` | `Farm_Harvest` |
| `craft` | `Interact` |
| `fish` | `Fish_Cast` |
| `fish_idle` | `Fish_Cast_Idle` |
| `fish_hook` | `Fish_Reel` |

Plus 20+ additional mappings (combat, emotes, farming, climbing, etc.) — see `_get_tool_animation_name()` in `player_controller.gd`.

## Network Sync

Server sets `movement_state`, `anim_move_speed`, `anim_action` on the player node. StateSync replicates to all clients. Each client's AnimationTree reads these to drive animations locally.

## Loop Modes

Set in `build_animation_library.gd` LOOP_ANIMATIONS dict (explicit list, UAL has no suffix convention). Safety net also sets loop at runtime in `_build_animation_tree()`.

## Key Gotchas

- **Transition request type**: AnimationNodeTransition `transition_request` expects `String`, NOT `StringName` — using StringName causes "Type mismatch" error.
- **UAL track format**: `Armature/Skeleton3D:bone_name` — matches mannequin structure, NO remapping needed.

## Key Files

- `scripts/player/player_controller.gd` (`_build_animation_tree()`, `_update_animation_tree()`)
- `scenes/player/player.tscn`
- `tools/build_animation_library.gd`

## Re-build Command

```bash
'/Applications/Mechanical Turk.app/Contents/MacOS/Mechanical Turk' --path . --script tools/build_animation_library.gd
```
