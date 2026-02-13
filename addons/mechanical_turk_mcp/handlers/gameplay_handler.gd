@tool
extends Node
## Handles gameplay tools: play_sequence, save/restore game state, simulate playthrough.

signal play_sequence_ready(result: Dictionary)
signal save_state_ready(result: Dictionary)
signal restore_state_ready(result: Dictionary)
signal simulate_ready(result: Dictionary)

var _snapshots: Dictionary = {}  # name -> snapshot data


func handle_play_sequence(params) -> Dictionary:
	_play_sequence_deferred(params)
	return {"_deferred": play_sequence_ready}


func _play_sequence_deferred(params) -> void:
	if not params is Dictionary:
		play_sequence_ready.emit({"error": "Invalid params"})
		return

	var steps: Array = params.get("steps", [])
	var capture_screenshot: bool = params.get("capture_screenshot", false)

	if steps.is_empty():
		play_sequence_ready.emit({"error": "No steps provided"})
		return

	var tree := get_tree()
	if tree == null:
		play_sequence_ready.emit({"error": "No scene tree available"})
		return

	var events_log: Array = []
	var start_time := Time.get_ticks_msec()

	# Record initial position
	var player := _find_player()
	var initial_pos := {}
	if player:
		initial_pos = {"x": player.position.x, "y": player.position.y}

	# Execute each step
	for step in steps:
		if not step is Dictionary:
			continue

		var step_type: String = step.get("type", "wait")
		var action: String = step.get("action", "")
		var duration_ms: int = int(step.get("duration_ms", 0))

		match step_type:
			"hold":
				if action.is_empty():
					continue
				Input.action_press(action)
				events_log.append({"action": action, "event": "pressed", "time_ms": Time.get_ticks_msec() - start_time})
				if duration_ms > 0:
					await _wait_ms(duration_ms)
				Input.action_release(action)
				events_log.append({"action": action, "event": "released", "time_ms": Time.get_ticks_msec() - start_time})

			"press":
				if action.is_empty():
					continue
				Input.action_press(action)
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release(action)
				events_log.append({"action": action, "event": "press_release", "time_ms": Time.get_ticks_msec() - start_time})

			"release":
				if action.is_empty():
					continue
				Input.action_release(action)
				events_log.append({"action": action, "event": "released", "time_ms": Time.get_ticks_msec() - start_time})

			"wait":
				if duration_ms > 0:
					await _wait_ms(duration_ms)

	# Release any held actions
	for action_name in ["move_left", "move_right", "move_up", "move_down", "jump", "shoot"]:
		Input.action_release(action_name)

	# Collect final state
	var result := {
		"status": "ok",
		"duration_ms": Time.get_ticks_msec() - start_time,
		"steps_executed": steps.size(),
		"events": events_log,
		"initial_position": initial_pos,
	}

	# Get final game state
	var rule_engine = tree.root.get_node_or_null("RuleEngine")
	if rule_engine:
		result["score"] = rule_engine.get("score")
		result["health"] = rule_engine.get("health")
		result["game_active"] = rule_engine.get("game_active")
		result["game_won"] = rule_engine.get("game_won")
		result["game_lost"] = rule_engine.get("game_lost")

	player = _find_player()
	if player:
		result["final_position"] = {"x": player.position.x, "y": player.position.y}
		if player is CharacterBody2D:
			result["final_velocity"] = {"x": (player as CharacterBody2D).velocity.x, "y": (player as CharacterBody2D).velocity.y}
			result["on_floor"] = (player as CharacterBody2D).is_on_floor()

	# Optional screenshot
	if capture_screenshot:
		await get_tree().process_frame
		var viewport := tree.root
		var texture := viewport.get_texture()
		if texture:
			var image := texture.get_image()
			if image:
				var png_buffer := image.save_png_to_buffer()
				result["screenshot_base64"] = Marshalls.raw_to_base64(png_buffer)

	play_sequence_ready.emit(result)


func handle_save_state(params) -> Dictionary:
	_save_state_deferred(params)
	return {"_deferred": save_state_ready}


func _save_state_deferred(params) -> void:
	await get_tree().process_frame

	var snapshot_name: String = "auto"
	if params is Dictionary:
		snapshot_name = params.get("name", "auto")

	var tree := get_tree()
	if tree == null:
		save_state_ready.emit({"error": "No scene tree available"})
		return

	var snapshot := {}

	# Save RuleEngine state
	var rule_engine = tree.root.get_node_or_null("RuleEngine")
	if rule_engine:
		snapshot["rule_engine"] = {
			"score": rule_engine.get("score"),
			"health": rule_engine.get("health"),
			"game_active": rule_engine.get("game_active"),
			"game_won": rule_engine.get("game_won"),
			"game_lost": rule_engine.get("game_lost"),
		}

	# Save all node positions and metadata
	var game_root := _find_game_root()
	if game_root:
		snapshot["nodes"] = _snapshot_nodes(game_root)

	snapshot["timestamp"] = Time.get_ticks_msec()
	_snapshots[snapshot_name] = snapshot

	save_state_ready.emit({
		"status": "ok",
		"name": snapshot_name,
		"nodes_saved": (snapshot.get("nodes", []) as Array).size(),
		"available_snapshots": _snapshots.keys(),
	})


func handle_restore_state(params) -> Dictionary:
	_restore_state_deferred(params)
	return {"_deferred": restore_state_ready}


func _restore_state_deferred(params) -> void:
	await get_tree().process_frame

	var snapshot_name: String = "auto"
	if params is Dictionary:
		snapshot_name = params.get("name", "auto")

	if not _snapshots.has(snapshot_name):
		restore_state_ready.emit({"error": "Snapshot '%s' not found. Available: %s" % [snapshot_name, str(_snapshots.keys())]})
		return

	var snapshot: Dictionary = _snapshots[snapshot_name]
	var tree := get_tree()

	# Restore RuleEngine state
	var rule_engine = tree.root.get_node_or_null("RuleEngine")
	if rule_engine and snapshot.has("rule_engine"):
		var re_state: Dictionary = snapshot["rule_engine"]
		rule_engine.set("score", re_state.get("score", 0))
		rule_engine.set("health", re_state.get("health", 3))
		rule_engine.set("game_active", re_state.get("game_active", true))
		rule_engine.set("game_won", re_state.get("game_won", false))
		rule_engine.set("game_lost", re_state.get("game_lost", false))
		if rule_engine.has_signal("score_changed"):
			rule_engine.score_changed.emit(rule_engine.score)
		if rule_engine.has_signal("health_changed"):
			rule_engine.health_changed.emit(rule_engine.health)

	# Restore node positions
	var nodes_restored := 0
	if snapshot.has("nodes"):
		for node_data in snapshot["nodes"]:
			var node := tree.root.get_node_or_null(str(node_data.get("path", "")).trim_prefix("/root"))
			if node == null:
				continue
			if node_data.has("position") and node is Node2D:
				var pos: Dictionary = node_data["position"]
				(node as Node2D).position = Vector2(pos.get("x", 0), pos.get("y", 0))
			if node_data.has("velocity") and node is CharacterBody2D:
				var vel: Dictionary = node_data["velocity"]
				(node as CharacterBody2D).velocity = Vector2(vel.get("x", 0), vel.get("y", 0))
			nodes_restored += 1

	restore_state_ready.emit({
		"status": "ok",
		"name": snapshot_name,
		"nodes_restored": nodes_restored,
	})


func handle_simulate_playthrough(params) -> Dictionary:
	_simulate_deferred(params)
	return {"_deferred": simulate_ready}


func _simulate_deferred(params) -> void:
	var max_duration: float = 30.0
	var strategy: String = "rush_right"
	if params is Dictionary:
		max_duration = clampf(float(params.get("max_duration", 30)), 1.0, 120.0)
		strategy = params.get("strategy", "rush_right")

	var tree := get_tree()
	if tree == null:
		simulate_ready.emit({"error": "No scene tree available"})
		return

	var player := _find_player()
	if player == null:
		simulate_ready.emit({"error": "No player found"})
		return

	var start_time := Time.get_ticks_msec()
	var start_pos := Vector2(player.position.x, player.position.y)
	var furthest_x: float = start_pos.x
	var path_points: Array = [{"x": start_pos.x, "y": start_pos.y, "time_ms": 0}]
	var stuck_locations: Array = []
	var last_x: float = start_pos.x
	var stuck_timer: float = 0.0
	var outcome: String = "timeout"
	var death_info := {}

	# Simulate step interval (check every 200ms)
	var step_interval_ms: int = 200
	var elapsed: float = 0.0

	while elapsed < max_duration:
		if not tree or tree.root == null:
			break

		var rule_engine = tree.root.get_node_or_null("RuleEngine")
		if rule_engine:
			if rule_engine.get("game_won"):
				outcome = "won"
				break
			if rule_engine.get("game_lost"):
				outcome = "died"
				death_info = {"position": {"x": player.position.x, "y": player.position.y}}
				break
			if not rule_engine.get("game_active"):
				outcome = "game_over"
				break

		player = _find_player()
		if player == null or not is_instance_valid(player):
			outcome = "died"
			break

		# Track furthest point
		if player.position.x > furthest_x:
			furthest_x = player.position.x

		# Check if stuck
		if abs(player.position.x - last_x) < 5:
			stuck_timer += step_interval_ms / 1000.0
			if stuck_timer > 2.0:
				stuck_locations.append({"x": player.position.x, "y": player.position.y, "time_s": elapsed})
				stuck_timer = 0.0
				# Try jumping when stuck
				Input.action_press("jump")
				await get_tree().process_frame
				await get_tree().process_frame
				Input.action_release("jump")
		else:
			stuck_timer = 0.0
			last_x = player.position.x

		# Apply strategy
		match strategy:
			"rush_right":
				Input.action_press("move_right")
				# Jump when on floor or near an obstacle
				if player is CharacterBody2D and (player as CharacterBody2D).is_on_floor():
					if (player as CharacterBody2D).is_on_wall() or randf() < 0.3:
						Input.action_press("jump")
						await get_tree().process_frame
						await get_tree().process_frame
						Input.action_release("jump")

			"explore":
				# Alternate directions, collect items
				if fmod(elapsed, 4.0) < 2.0:
					Input.action_press("move_right")
					Input.action_release("move_left")
				else:
					Input.action_press("move_left")
					Input.action_release("move_right")
				if player is CharacterBody2D and (player as CharacterBody2D).is_on_floor():
					if randf() < 0.4:
						Input.action_press("jump")
						await get_tree().process_frame
						await get_tree().process_frame
						Input.action_release("jump")

			"careful":
				Input.action_press("move_right")
				if player is CharacterBody2D and (player as CharacterBody2D).is_on_floor():
					if (player as CharacterBody2D).is_on_wall():
						Input.action_press("jump")
						await get_tree().process_frame
						await get_tree().process_frame
						Input.action_release("jump")

		# Record path point every second
		if int(elapsed * 1000) % 1000 < step_interval_ms:
			path_points.append({
				"x": player.position.x,
				"y": player.position.y,
				"time_ms": Time.get_ticks_msec() - start_time,
			})

		await _wait_ms(step_interval_ms)
		elapsed += step_interval_ms / 1000.0

		# Check for stuck too long
		if stuck_locations.size() >= 5:
			outcome = "stuck"
			break

	# Release all inputs
	for action_name in ["move_left", "move_right", "move_up", "move_down", "jump", "shoot"]:
		Input.action_release(action_name)

	var final_pos := {}
	player = _find_player()
	if player and is_instance_valid(player):
		final_pos = {"x": player.position.x, "y": player.position.y}

	simulate_ready.emit({
		"status": "ok",
		"outcome": outcome,
		"strategy": strategy,
		"duration_s": elapsed,
		"start_position": {"x": start_pos.x, "y": start_pos.y},
		"final_position": final_pos,
		"furthest_x": furthest_x,
		"distance_traveled": furthest_x - start_pos.x,
		"path_points": path_points,
		"stuck_locations": stuck_locations,
		"death_info": death_info,
	})


# --- Utility functions ---

func _find_player() -> Node2D:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null

	var game_root := _find_game_root()
	if game_root == null:
		return null

	# Check if game has a "player" property
	if "player" in game_root:
		var p = game_root.get("player")
		if p is Node2D and is_instance_valid(p):
			return p

	# Search for player node
	return _find_node_recursive(game_root, func(n: Node) -> bool:
		if n.name.to_lower() == "player":
			return true
		if n is CharacterBody2D and not n.has_meta("enemy"):
			return true
		return false
	)


func _find_game_root() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	for path in ["GameLoader/Game"]:
		var node := tree.root.get_node_or_null(path)
		if node:
			return node
	return tree.current_scene


func _find_node_recursive(root: Node, predicate: Callable) -> Node2D:
	for child in root.get_children():
		if predicate.call(child) and child is Node2D:
			return child as Node2D
		var found := _find_node_recursive(child, predicate)
		if found:
			return found
	return null


func _snapshot_nodes(root: Node) -> Array:
	var nodes: Array = []
	_snapshot_recursive(root, nodes)
	return nodes


func _snapshot_recursive(node: Node, nodes: Array) -> void:
	if node is Node2D:
		var data := {
			"path": str(node.get_path()),
			"name": node.name,
			"position": {"x": (node as Node2D).position.x, "y": (node as Node2D).position.y},
		}
		if node is CharacterBody2D:
			data["velocity"] = {"x": (node as CharacterBody2D).velocity.x, "y": (node as CharacterBody2D).velocity.y}
		nodes.append(data)

	for child in node.get_children():
		_snapshot_recursive(child, nodes)


func _wait_ms(ms: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(ms / 1000.0).timeout
