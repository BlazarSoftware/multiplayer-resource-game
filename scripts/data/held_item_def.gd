class_name HeldItemDef
extends Resource

@export var item_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var effect_type: String = "" # type_boost, damage_reduction, end_of_turn, on_status, on_hp_threshold
@export var effect_params: Dictionary = {} # e.g. {"type": "spicy", "multiplier": 1.2}
@export var icon_color: Color = Color.MEDIUM_PURPLE
@export var icon_texture: Texture2D
@export var consumable: bool = false
