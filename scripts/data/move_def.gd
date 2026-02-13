class_name MoveDef
extends Resource

@export var move_id: String = ""
@export var display_name: String = ""
@export var type: String = "" # spicy, sweet, sour, herbal, umami, grain, or "" for typeless
@export var category: String = "physical" # physical, special, status
@export var power: int = 0
@export var accuracy: int = 100
@export var pp: int = 10
@export var priority: int = 0
@export var status_effect: String = "" # burned, frozen, poisoned, drowsy, wilted, soured
@export var status_chance: int = 0
@export var stat_changes: Dictionary = {} # e.g. {"attack": -1, "speed": 1}
@export var heal_percent: float = 0.0 # heals this % of max HP (for Taste Test)
@export var drain_percent: float = 0.0 # heals this % of damage dealt (for Harvest)
@export var description: String = ""

# Advanced move mechanics
@export var is_contact: bool = false
@export var recoil_percent: float = 0.0 # attacker takes this % of damage dealt
@export var multi_hit_min: int = 0 # 0 = single hit
@export var multi_hit_max: int = 0
@export var is_protection: bool = false # priority protect move
@export var is_charging: bool = false # two-turn move
@export var charge_message: String = "" # message shown during charge turn
@export var weather_set: String = "" # sets this weather type
@export var hazard_type: String = "" # sets entry hazard on opponent's side
@export var clears_hazards: bool = false # removes hazards from own side
@export var target_stat_changes: Dictionary = {} # stat changes applied to target
