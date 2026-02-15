extends Area3D

func _ready() -> void:
	add_to_group("storage_station")
	collision_layer = 0
	collision_mask = 3 # Detect players on layer 2
