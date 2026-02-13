class_name RecipeDef
extends Resource

@export var recipe_id: String = ""
@export var display_name: String = ""
@export var result_species_id: String = ""
@export var ingredients: Dictionary = {} # {ingredient_id: amount_needed}
@export var description: String = ""
