extends Node3D

var plots: Array[Node] = []
var rain_timer: float = 0.0
var rain_interval_min: float = 120.0
var rain_interval_max: float = 240.0
var next_rain_time: float = 0.0
var is_raining: bool = false
var rain_duration: float = 15.0
var rain_elapsed: float = 0.0

const FARM_PLOT_SCENE = preload("res://scenes/world/farm_plot.tscn")
const GRID_SIZE = 6
const PLOT_SPACING = 2.0

func _ready() -> void:
	if multiplayer.is_server():
		next_rain_time = randf_range(rain_interval_min, rain_interval_max)
	# Generate farm plot grid
	_generate_plots()
	# Collect all farm plots
	for child in get_children():
		if child.has_method("try_clear"):
			plots.append(child)

func _generate_plots() -> void:
	var offset = -(GRID_SIZE - 1) * PLOT_SPACING / 2.0
	for row in range(GRID_SIZE):
		for col in range(GRID_SIZE):
			var plot = FARM_PLOT_SCENE.instantiate()
			plot.name = "Plot_%d_%d" % [row, col]
			plot.position = Vector3(
				offset + col * PLOT_SPACING,
				0,
				offset + row * PLOT_SPACING
			)
			add_child(plot)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	# Rain system
	rain_timer += delta
	if is_raining:
		rain_elapsed += delta
		if rain_elapsed >= rain_duration:
			is_raining = false
			_broadcast_rain.rpc(false)
	elif rain_timer >= next_rain_time:
		is_raining = true
		rain_elapsed = 0.0
		rain_timer = 0.0
		next_rain_time = randf_range(rain_interval_min, rain_interval_max)
		# Water all plots
		for plot in plots:
			plot.rain_water()
		_broadcast_rain.rpc(true)
		print("Rain started!")

@rpc("authority", "call_local", "reliable")
func _broadcast_rain(raining: bool) -> void:
	is_raining = raining

@rpc("any_peer", "reliable")
func request_farm_action(plot_index: int, action: String, extra: String) -> void:
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	if plot_index < 0 or plot_index >= plots.size():
		return
	var plot = plots[plot_index]
	var success = false
	var result = {}
	match action:
		"clear":
			success = plot.try_clear(sender)
		"till":
			success = plot.try_till(sender)
		"plant":
			if extra != "":
				# Verify player has seeds
				_request_plant_validation.rpc_id(sender, plot_index, extra)
				return
		"water":
			success = plot.try_water(sender)
		"harvest":
			result = plot.try_harvest(sender)
			if result.size() > 0:
				success = true
				_grant_harvest.rpc_id(sender, result)
				# Server-side inventory tracking
				for item_id in result:
					NetworkManager.server_add_inventory(sender, item_id, result[item_id])
	_farm_action_result.rpc_id(sender, plot_index, action, success)

@rpc("authority", "reliable")
func _farm_action_result(_plot_index: int, _action: String, _success: bool) -> void:
	# Client receives result - could show feedback
	pass

@rpc("authority", "reliable")
func _grant_harvest(items: Dictionary) -> void:
	for item_id in items:
		PlayerData.add_to_inventory(item_id, items[item_id])

@rpc("authority", "reliable")
func _request_plant_validation(plot_index: int, seed_id: String) -> void:
	# Client validates they have the seed and responds
	if PlayerData.has_item(seed_id, 1):
		PlayerData.remove_from_inventory(seed_id, 1)
		_confirm_plant.rpc_id(1, plot_index, seed_id, multiplayer.get_unique_id())

@rpc("any_peer", "reliable")
func _confirm_plant(plot_index: int, seed_id: String, peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if plot_index >= 0 and plot_index < plots.size():
		var success = plots[plot_index].try_plant(peer_id, seed_id)
		if success:
			NetworkManager.server_remove_inventory(peer_id, seed_id, 1)
		else:
			# Refund seed
			_refund_seed.rpc_id(peer_id, seed_id)
			NetworkManager.server_add_inventory(peer_id, seed_id, 1)

@rpc("authority", "reliable")
func _refund_seed(seed_id: String) -> void:
	PlayerData.add_to_inventory(seed_id, 1)

func get_save_data() -> Array:
	var data = []
	for plot in plots:
		data.append(plot.get_save_data())
	return data

func load_save_data(data: Array) -> void:
	for i in range(min(data.size(), plots.size())):
		plots[i].load_save_data(data[i])

func get_nearest_plot(world_pos: Vector3, max_distance: float = 3.0) -> int:
	var closest_dist = max_distance
	var closest_idx = -1
	for i in range(plots.size()):
		var dist = plots[i].global_position.distance_to(world_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i
	return closest_idx
