# NPC Schedules & Placement

Every NPC in the game, their world position, schedule behavior, and animation config.

## How Schedules Work

- A game day lasts **600 real seconds** (10 minutes). Time is expressed as a **fraction** from `0.0` (dawn) to `1.0` (end of day).
- Both server and client independently compute NPC positions from the synced `SeasonManager` clock every 30 physics frames.
- Server teleports NPCs instantly (for Area3D collision accuracy). Clients smoothly lerp NPCs to their target at 2 units/sec.
- Schedules can be gated by **season** (`spring`, `summer`, `autumn`, `winter`), though no NPC currently uses season-specific schedules.
- Only **social NPCs** have schedules. Trainers, shops, and the bank NPC are **static** (fixed position, no movement).

---

## Social NPCs (15) — With Schedules

Each social NPC has two schedule slots: a **morning position** (first half of day, 0.0-0.5) and an **afternoon position** (second half, 0.5-1.0). They walk between these positions at the midday transition.

### Hubert Crumb — Baker
| ID | `npc_hubert` |
|---|---|
| Scene start | (-3, 1, 8) |
| Morning (0.0-0.5) | (-3, 1, 8) — near bakery |
| Afternoon (0.5-1.0) | (2, 1, 12) — toward restaurant doors |
| Idle animation | `Idle` |
| Actions | `Interact`, `Farm_Harvest` |
| Color | NPC-defined `visual_color` |

### Old Sage Murphy — Herbalist
| ID | `npc_murphy` |
|---|---|
| Scene start | (5, 7, 35) |
| Morning (0.0-0.5) | (5, 7, 35) — hilltop garden |
| Afternoon (0.5-1.0) | (0, 6, 32) — nearby meadow |
| Idle animation | `Idle` |
| Actions | `Farm_ScatteringSeeds`, `Farm_PlantSeed` |

### Captain Sal Haddock — Fisherman Captain
| ID | `npc_captain_sal` |
|---|---|
| Scene start | (-8, 0, -3) |
| Morning (0.0-0.5) | (-8, 0, -3) — fishing dock |
| Afternoon (0.5-1.0) | (-10, 0, -5) — further down the dock |
| Idle animation | `Fish_Cast_Idle` |
| Actions | `Fish_Cast`, `Fish_Reel` |

### Pepper Santos — Spice Artisan
| ID | `npc_pepper` |
|---|---|
| Scene start | (7, 1, 6) |
| Morning (0.0-0.5) | (7, 1, 6) — spice stall area |
| Afternoon (0.5-1.0) | (3, 1, 12) — toward town center |
| Idle animation | `Idle` |
| Actions | `Mining`, `TreeChopping` |

### Professor Quill — Scholar
| ID | `npc_quill` |
|---|---|
| Scene start | (18, 2, 8) |
| Morning (0.0-0.5) | (18, 2, 8) — elevated study area |
| Afternoon (0.5-1.0) | (5, 1, 10) — walks into town |
| Idle animation | `Sitting_Idle` |
| Actions | `Sitting_Talking` |

### Mayor Rosemary Hartwell — Mayor
| ID | `npc_mayor` |
|---|---|
| Scene start | (5, 1, 10) |
| Morning (0.0-0.5) | (5, 1, 10) — town hall area |
| Afternoon (0.5-1.0) | (0, 1, 8) — town center stroll |
| Idle animation | `Idle` |
| Actions | `Yes`, `Interact` |

### Innkeeper Mabel Tidecrest — Innkeeper
| ID | `npc_innkeeper` |
|---|---|
| Scene start | (-10, 0, -5) |
| Morning (0.0-0.5) | (-10, 0, -5) — inn entrance |
| Afternoon (0.5-1.0) | (-8, 0, -3) — steps outside |
| Idle animation | `Idle` |
| Actions | `Counter_Give`, `Counter_Show` |

### Clay Brennan — Potter
| ID | `npc_potter` |
|---|---|
| Scene start | (-5, 1, 8) |
| Morning (0.0-0.5) | (-5, 1, 8) — pottery workshop |
| Afternoon (0.5-1.0) | (-3, 1, 12) — moves toward center |
| Idle animation | `Idle` |
| Actions | `Interact`, `Mining` |

### Scarlet Winters — Tailor
| ID | `npc_tailor` |
|---|---|
| Scene start | (15, 2, 5) |
| Morning (0.0-0.5) | (15, 2, 5) — tailor shop |
| Afternoon (0.5-1.0) | (12, 2, 8) — walks closer to town |
| Idle animation | `Idle` |
| Actions | `Interact`, `Farm_ScatteringSeeds` |

### Iris Greenthumb — Gardener
| ID | `npc_gardener` |
|---|---|
| Scene start | (20, 2, 10) |
| Morning (0.0-0.5) | (20, 2, 10) — garden plots |
| Afternoon (0.5-1.0) | (18, 2, 12) — adjacent garden path |
| Idle animation | `Idle` |
| Actions | `Farm_PlantSeed`, `Farm_Watering` |

### Dr. Honey Sweetwater — Doctor
| ID | `npc_doctor` |
|---|---|
| Scene start | (22, 2, 3) |
| Morning (0.0-0.5) | (22, 2, 3) — clinic |
| Afternoon (0.5-1.0) | (20, 2, 6) — steps out for a walk |
| Idle animation | `Idle` |
| Actions | `Interact`, `Yes` |

### Hazel Mapleton — Shopkeeper
| ID | `npc_general_store` |
|---|---|
| Scene start | (8, 1, 5) |
| Morning (0.0-0.5) | (8, 1, 5) — general store |
| Afternoon (0.5-1.0) | (10, 1, 8) — nearby stall |
| Idle animation | `Idle` |
| Actions | `Counter_Give`, `Counter_Show` |

### Clementine Smith — Apprentice Chef
| ID | `npc_clementine` |
|---|---|
| Scene start | (2, 1, 4) |
| Morning (0.0-0.5) | (3, 1, 7) — near restaurant |
| Afternoon (0.5-1.0) | (-5, 0, -2) — explores the docks |
| Idle animation | `Idle` |
| Actions | `Interact`, `Farm_Harvest` |

### River Song — Fisher-Artist
| ID | `npc_river` |
|---|---|
| Scene start | (-12, 0, -8) |
| Morning (0.0-0.5) | (-12, 0, -8) — waterfront easel |
| Afternoon (0.5-1.0) | (-14, 0, -5) — further along shore |
| Idle animation | `Fish_Cast_Idle` |
| Actions | `Fish_Cast`, `Dance` |

### Alex Hartwell — Aspiring Explorer
| ID | `npc_alex` |
|---|---|
| Scene start | (0, 1, 6) |
| Morning (0.0-0.5) | (-2, 1, 5) — near spawn |
| Afternoon (0.5-1.0) | (7, 1, 12) — wanders toward outskirts |
| Idle animation | `Idle` |
| Actions | `Yes`, `Dance` |

---

## Trainer NPCs (7) — Static Positions

Trainers stand in fixed positions along the battle route heading south from spawn. They do not move. Two are gatekeepers that block passage until defeated.

| Trainer | ID | Position | Difficulty | Gatekeeper? |
|---|---|---|---|---|
| Sous Chef Pepper | `sous_chef_pepper` | (-12, 0, -10) | Easy | No |
| Farmer Green | `farmer_green` | (12, 0, -10) | Easy | No |
| **Chef Umami** | `chef_umami` | (0, 0, -20) | Medium | **Yes** |
| Pastry Chef Dulce | `pastry_chef_dulce` | (-18, 0, -28) | Medium | No |
| Brinemaster Vlad | `brinemaster_vlad` | (18, 0, -28) | Medium | No |
| **Head Chef Roux** | `head_chef_roux` | (0, 0, -40) | Hard | **Yes** |
| Grand Chef Michelin | `grand_chef_michelin` | (-25, 0, -55) | Hard | No |

**Trainer animation config** (by difficulty):
| Difficulty | Color | Idle | Actions |
|---|---|---|---|
| Easy | Green (0.3, 0.7, 0.3) | `Idle` | `Sword_Idle`, `Yes` |
| Medium | Yellow (0.7, 0.7, 0.2) | `Sword_Idle` | `Sword_Attack`, `Sword_Block` |
| Hard | Red (0.8, 0.2, 0.2) | `Sword_Block` | `Spell_Simple_Shoot`, `Sword_Attack` |

---

## Shop NPCs (3) — Static Positions

Shops are placed around the world at fixed positions. They do not move.

| Shop | ID | Position |
|---|---|---|
| General Store | `general_store` | (8, 0, 5) |
| Battle Supplies | `battle_supplies` | (-8, 0, -15) |
| Rare Goods | `rare_goods` | (-20, 0, -45) |

**Shop animation config:** Idle = `Idle`, Actions = `Counter_Give`, `Counter_Show`, `Yes`. Color = Teal (0.2, 0.7, 0.7).

---

## Bank NPC (1) — Static Position

| NPC | Position |
|---|---|
| Bank | (0, 0.6, -55) |

**Bank animation config:** Idle = `Idle`, Actions = `Counter_Give`, `Interact`. Color = Gold (0.85, 0.7, 0.2).

---

## World Map Overview

Rough spatial layout (looking down, north = +Z):

```
                    Murphy (5,35) hilltop
                         |
        Gardener (20,10)  Quill (18,8)  Tailor (15,5)
                    Doctor (22,3)
                         |
  Potter (-5,8)  Hubert (-3,8)  Mayor (5,10)  Hazel (8,5)
                 Pepper (7,6)  Alex (0,6)
                 Clementine (2,4)
                         |
    ===== SPAWN (0,0,3) =====
    General Store (8,5)        Workbench (-7,0)
                         |
  Innkeeper (-10,-5)   Sal (-8,-3)   River (-12,-8)
                         |
  Sous Chef Pepper (-12,-10)    Farmer Green (12,-10)
                         |
    Battle Supplies (-8,-15)
                         |
                 * CHEF UMAMI (0,-20) [GATE] *
                         |
  Pastry Dulce (-18,-28)    Brinemaster Vlad (18,-28)
                         |
                 * HEAD CHEF ROUX (0,-40) *
                         |
  Rare Goods (-20,-45)
                         |
  Grand Chef Michelin (-25,-55)    Bank (0,-55)
```

---

## Technical Details

- **Schedule data** is stored in each NPC's `.tres` resource file (`resources/npcs/npc_*.tres`) as a `schedule` array on the `NpcDef` resource.
- **Resolution function**: `NpcAnimator.resolve_schedule_position(npc_def, time_fraction, season)` — returns `Vector3.ZERO` if no matching entry.
- **Tick rate**: Every 30 physics frames (~0.5s at 60fps).
- **Client movement speed**: 2.0 units/sec, snaps when within 0.1 units of target.
- **Reaction animations**: Triggered when a player enters an NPC's Area3D range (3m radius for social/shop/bank, 4m for gatekeeper trainers).
