extends Area3D

@export var station_type: String = "workbench" # "kitchen", "workbench", "cauldron"

func _ready() -> void:
	add_to_group("crafting_" + station_type)
	# Also add to generic crafting_table group for backwards compatibility
	add_to_group("crafting_table")
	collision_layer = 0
	collision_mask = 3 # Detect players on layer 2
