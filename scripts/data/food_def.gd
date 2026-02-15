class_name FoodDef
extends Resource

@export var food_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_color: Color = Color.WHITE
@export var sell_price: int = 0
@export var buff_type: String = "" # speed_boost, xp_multiplier, encounter_rate, creature_heal, none
@export var buff_value: float = 0.0
@export var buff_duration_sec: float = 0.0 # 0 = instant effect
