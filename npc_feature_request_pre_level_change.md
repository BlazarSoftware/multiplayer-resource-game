# Replace NPC Capsules with Animated UAL Mannequin Models

## Context
All 16 NPCs (5 social, 7 trainers, 3 shop, 1 bank) are currently colored capsule placeholders. The player character was just upgraded to use the UAL mannequin with 260 animations. NPCs need the same treatment — replace capsules with the mannequin model and give each NPC role-appropriate idle/contextual animations to bring the world to life. Per demo-plan.md, the game targets a cozy, Stardew-like atmosphere where NPCs feel alive.

## Architecture: Shared NPC Animator Script

Create a single reusable `npc_animator.gd` script that all NPC types call from `_create_visual()`. This replaces the capsule mesh code in each NPC script with a mannequin instance + simplified AnimationTree.

### Why a shared script, not a shared scene
- NPC scripts (trainer, social, shop, bank) all extend `Area3D` and are placed directly in `game_world.tscn` — they aren't instanced from a scene file
- A shared animator script keeps the existing architecture intact — each NPC type still owns its `_create_visual()` but delegates character model + animation setup to `NpcAnimator`

## Step 1: Create `scripts/world/npc_animator.gd`

New utility class (`class_name NpcAnimator`) with a static-ish factory method:

```gdscript
static func create_character(parent: Node3D, config: Dictionary) -> Dictionary:
    # config keys: idle_animation, action_animations, color_tint, face_direction
    # Returns: {model: Node3D, anim_tree: AnimationTree}
```

**What it does:**
1. Instances `mannequin_f.glb` as `CharacterModel` child of the NPC Area3D
2. Creates an AnimationTree (standalone AnimationMixer pattern — same as player)
3. Loads the shared `player_animation_library.tres` (260 anims)
4. Builds a **simple blend tree**: `IdleAnim → ActionBlend → output`
   - `IdleAnim`: the NPC's primary idle animation (looping)
   - `ActionAnim`: a one-shot action animation (swappable)
   - `ActionBlend` (Blend2): blends between idle (0) and action (1)
5. Applies a color tint to the mannequin material using `visual_color` from the NPC def (override albedo on surface material)
6. Sets initial facing direction from `config.face_direction` (Y rotation)
7. Returns the model and anim_tree references so the NPC script can drive actions

**NPC idle behavior** (driven by a simple timer in `_process` on clients only):
- Each NPC periodically plays a short contextual action animation (e.g., baker kneads, fisherman casts) then returns to idle
- Random interval (8-15 seconds) between actions to feel organic
- Action animations are one-shot (blend_amount lerps to 1.0, plays, lerps back to 0.0)

## Step 2: Define Per-NPC Animation Mappings

Each NPC gets a primary idle + 1-3 contextual action animations:

### Social NPCs
| NPC | Idle | Actions | Color |
|-----|------|---------|-------|
| Baker Brioche | `Idle` | `Interact`, `Farm_Harvest` (kneading) | (0.6, 0.4, 0.2) |
| Sage Herbalist | `Idle` | `Farm_ScatteringSeeds`, `Farm_PlantSeed` | (0.2, 0.55, 0.2) |
| Old Salt | `Fish_Cast_Idle` | `Fish_Cast`, `Fish_Reel` | (0.3, 0.45, 0.7) |
| Ember Smith | `Idle` | `Mining`, `TreeChopping` | (0.8, 0.35, 0.15) |
| Professor Umami | `Sitting_Idle` | `Sitting_Talking`, `Sitting_Nodding` | (0.5, 0.3, 0.6) |

### Trainers
| NPC | Idle | Actions |
|-----|------|---------|
| Easy trainers | `Idle` | `Sword_Idle`, `Yes` (encouraging) |
| Medium trainers | `Sword_Idle` | `Sword_Attack`, `Block_Idle` |
| Hard trainers / gatekeepers | `Block_Idle` | `Spell_Simple_Shoot`, `Sword_Attack` |

### Shop NPCs
| NPC | Idle | Actions |
|-----|------|---------|
| All shops | `Idle` | `Counter_Give`, `Counter_Show`, `Yes` |

### Bank NPC
| NPC | Idle | Actions |
|-----|------|---------|
| Bank | `Idle` | `Counter_Give`, `Interact` |

## Step 3: Update NPC Scripts

Modify `_create_visual()` in each of the 4 NPC scripts:

### `scripts/world/social_npc.gd`
- Replace capsule mesh creation (lines 31-41) with `NpcAnimator.create_character()` call
- Pass `npc_def.visual_color` and animation config looked up from a `SOCIAL_NPC_ANIMS` dict keyed by `npc_id`
- Keep collision shape, Label3D, and quest indicator creation unchanged
- Add `_process` client-side animation tick (call `NpcAnimator.update()`)

### `scripts/world/trainer_npc.gd`
- Replace capsule mesh creation (lines 33-51) with `NpcAnimator.create_character()` call
- Color tint based on difficulty (green/yellow/red) — same colors as now
- Keep gate mesh for gatekeepers, collision, Label3D unchanged
- Add client-side animation tick

### `scripts/world/shop_npc.gd`
- Replace capsule mesh creation (lines 27-36) with `NpcAnimator.create_character()` call
- Teal color tint
- Keep collision, Label3D unchanged
- Add client-side animation tick

### `scripts/world/bank_npc.gd`
- Replace capsule mesh creation (lines 20-30) with `NpcAnimator.create_character()` call
- Gold color tint
- Keep collision, Label3D unchanged
- Add client-side animation tick

## Step 4: Interaction Response Animations

When a player interacts (enters Area3D proximity), trigger a reaction animation on the NPC:
- Social NPCs: play `Yes` (wave/nod) when player enters range
- Trainers: play combat stance flourish
- Shops: play `Counter_Show`

This is client-side only (triggered in the `_show_*_prompt` RPC handlers). No networking needed.

## Step 5: NPC Face-Toward-Player

Add a subtle rotation so NPCs turn to face the nearest player:
- In `_process` (client only), smoothly lerp Y rotation toward the local player's position
- Only when a player is within interaction range (nearby_peers not empty on server, but client can check distance)
- Rotation speed: ~2.0 rad/sec for smooth, not snappy, turning
- Only rotate the CharacterModel node, not the Area3D (keeps collision stable)

## Files to Create
- `scripts/world/npc_animator.gd` — shared NPC character model + animation utility

## Files to Modify
- `scripts/world/social_npc.gd` — replace capsule with animated model
- `scripts/world/trainer_npc.gd` — replace capsule with animated model
- `scripts/world/shop_npc.gd` — replace capsule with animated model
- `scripts/world/bank_npc.gd` — replace capsule with animated model

## Files Referenced (read-only)
- `scripts/player/player_controller.gd` — AnimationTree pattern to reuse (lines 384-507)
- `assets/models/mannequin_f.glb` — character model
- `assets/animations/player_animation_library.tres` — 260 animations
- `scripts/data/npc_def.gd` — visual_color field
- `resources/npcs/*.tres` — per-NPC color values

## Multiplayer Considerations
- **No networking changes needed.** NPC animations are purely visual, client-side only. NPCs are deterministic (same position, same idle cycle seed). The server doesn't need to know about NPC animations.
- Server skips animation setup (check `multiplayer.is_server()` before building AnimationTree)
- Existing Area3D collision, RPCs, and prompt logic are completely untouched

## Verification
1. Run the game in editor — all 16 NPCs should show mannequin models instead of capsules
2. Each NPC should be tinted with their role color
3. NPCs should play idle animations continuously
4. NPCs should periodically play contextual action animations (every 8-15s)
5. Walking near an NPC should trigger a reaction animation
6. NPCs should slowly turn to face the player when in range
7. Label3D nameplates and quest indicators should still appear above the model
8. Trainer gates should still work for gatekeepers
9. All interaction RPCs (talk, gift, shop, bank, challenge) should still function
10. Test in multiplayer: host + join, both clients see animated NPCs
