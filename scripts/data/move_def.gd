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
