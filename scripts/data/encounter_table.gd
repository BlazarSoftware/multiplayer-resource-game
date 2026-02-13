class_name EncounterTable
extends Resource

@export var table_id: String = ""
@export var display_name: String = ""
@export var entries: Array[Dictionary] = [] # {species_id: String, weight: int, min_level: int, max_level: int}
@export var season_bonus: Dictionary = {} # {season: species_id} - increased chance in that season
