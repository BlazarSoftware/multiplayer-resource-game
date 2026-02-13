extends Node

signal game_started()
signal game_ended()
signal game_world_ready()

var game_world: Node = null
var GAME_WORLD_SCENE: PackedScene = null

func start_game() -> void:
	if is_game_world_ready():
		return
	# Remove connect UI
	var main = get_tree().current_scene
	if main == null:
		return
	for child in main.get_children():
		if child.name == "ConnectUI":
			child.queue_free()
	# Instance game world
	if GAME_WORLD_SCENE == null:
		GAME_WORLD_SCENE = load("res://scenes/main/game_world.tscn")
	game_world = GAME_WORLD_SCENE.instantiate()
	main.add_child(game_world)
	game_started.emit()
	_emit_game_world_ready.call_deferred()

func end_game() -> void:
	if game_world:
		game_world.queue_free()
		game_world = null
	game_ended.emit()

func is_playing() -> bool:
	return is_game_world_ready()

func is_game_world_ready() -> bool:
	return game_world != null and is_instance_valid(game_world)

func _emit_game_world_ready() -> void:
	if is_game_world_ready():
		game_world_ready.emit()
