class_name RecipeDef
extends Resource

@export var recipe_id: String = ""
@export var display_name: String = ""
@export var result_species_id: String = "" # For creature recipes
@export var result_item_id: String = "" # For held item recipes
@export var result_food_id: String = "" # For food recipes
@export var result_tool_id: String = "" # For tool recipes
@export var ingredients: Dictionary = {} # {ingredient_id: amount_needed}
@export var description: String = ""
@export var station: String = "" # "kitchen", "workbench", "cauldron"
@export var requires_tool_ingredient: String = "" # tool item consumed by upgrade recipes
@export var unlockable: bool = false # if true, must be in player's known_recipes
