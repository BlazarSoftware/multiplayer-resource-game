class_name RecipeDef
extends Resource

@export var recipe_id: String = ""
@export var display_name: String = ""
@export var result_species_id: String = "" # For creature recipes
@export var result_item_id: String = "" # For held item recipes
@export var ingredients: Dictionary = {} # {ingredient_id: amount_needed}
@export var description: String = ""
