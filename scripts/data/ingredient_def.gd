class_name IngredientDef
extends Resource

@export var ingredient_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var category: String = "" # "farm_crop" or "battle_drop"
@export var icon_color: Color = Color.WHITE
@export var sell_price: int = 0
@export var season: String = "" # spring, summer, autumn, winter, or "" for all
@export var grow_time: float = 60.0 # seconds to grow (for crops)
@export var harvest_min: int = 1
@export var harvest_max: int = 2
