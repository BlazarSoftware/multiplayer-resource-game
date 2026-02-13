class_name DataRegistry
extends Node

# Registries
static var ingredients: Dictionary = {} # id -> IngredientDef
static var species: Dictionary = {} # id -> CreatureSpecies
static var moves: Dictionary = {} # id -> MoveDef
static var encounter_tables: Dictionary = {} # id -> EncounterTable
static var recipes: Dictionary = {} # id -> RecipeDef
static var abilities: Dictionary = {} # id -> AbilityDef
static var held_items: Dictionary = {} # id -> HeldItemDef
static var trainers: Dictionary = {} # id -> TrainerDef

static var _loaded: bool = false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_all("res://resources/ingredients/", ingredients, "ingredient_id")
	_load_all("res://resources/creatures/", species, "species_id")
	_load_all("res://resources/moves/", moves, "move_id")
	_load_all("res://resources/encounters/", encounter_tables, "table_id")
	_load_all("res://resources/recipes/", recipes, "recipe_id")
	_load_all("res://resources/abilities/", abilities, "ability_id")
	_load_all("res://resources/held_items/", held_items, "item_id")
	_load_all("res://resources/trainers/", trainers, "trainer_id")
	print("DataRegistry loaded: ", ingredients.size(), " ingredients, ", species.size(), " species, ", moves.size(), " moves, ", encounter_tables.size(), " encounter tables, ", recipes.size(), " recipes, ", abilities.size(), " abilities, ", held_items.size(), " held items, ", trainers.size(), " trainers")

static func _load_all(path: String, registry: Dictionary, id_field: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		print("DataRegistry: Could not open ", path)
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		# In exported builds, .tres may become .res or .tres.remap
		var load_path := ""
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			load_path = path + file_name
		elif file_name.ends_with(".remap"):
			# .tres.remap -> load the original .tres path (Godot resolves it)
			load_path = path + file_name.replace(".remap", "")
		if load_path != "":
			var res = load(load_path)
			if res and id_field in res:
				registry[res.get(id_field)] = res
			elif res:
				print("DataRegistry: loaded ", load_path, " but missing field '", id_field, "'")
		file_name = dir.get_next()

static func get_ingredient(id: String):
	ensure_loaded()
	return ingredients.get(id)

static func get_species(id: String):
	ensure_loaded()
	return species.get(id)

static func get_move(id: String):
	ensure_loaded()
	return moves.get(id)

static func get_encounter_table(id: String):
	ensure_loaded()
	return encounter_tables.get(id)

static func get_recipe(id: String):
	ensure_loaded()
	return recipes.get(id)

static func get_ability(id: String):
	ensure_loaded()
	return abilities.get(id)

static func get_held_item(id: String):
	ensure_loaded()
	return held_items.get(id)

static func get_trainer(id: String):
	ensure_loaded()
	return trainers.get(id)
