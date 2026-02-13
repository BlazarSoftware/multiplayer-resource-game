@tool
extends Node
## Evaluates level quality: reachability, difficulty, design issues, suggestions.

signal eval_ready(result: Dictionary)


func handle_evaluate(params) -> Dictionary:
	_evaluate_deferred(params)
	return {"_deferred": eval_ready}


func _evaluate_deferred(params) -> void:
	await get_tree().process_frame

	var tree := get_tree()
	if tree == null:
		eval_ready.emit({"error": "No scene tree available"})
		return

	var root := tree.root

	# Detect game type
	var game_type: String = "platformer"
	if params is Dictionary and params.get("game_type", "auto") != "auto":
		game_type = params.get("game_type")
	else:
		var rule_engine = root.get_node_or_null("RuleEngine")
		if rule_engine and rule_engine.has_method("get_game_type"):
			game_type = rule_engine.get_game_type()

	# Get physics params
	var jump_force: float = 600.0
	var gravity_val: float = 980.0
	var player_speed: float = 300.0

	var rule_engine = root.get_node_or_null("RuleEngine")
	if rule_engine:
		var pc: Dictionary = rule_engine.get_player_config() if rule_engine.has_method("get_player_config") else {}
		var wc: Dictionary = rule_engine.get_world_config() if rule_engine.has_method("get_world_config") else {}
		jump_force = pc.get("jump_force", 600.0)
		gravity_val = wc.get("gravity", 980.0)
		player_speed = pc.get("speed", 300.0)

	if params is Dictionary:
		if params.has("jump_force"):
			jump_force = float(params.get("jump_force"))
		if params.has("gravity"):
			gravity_val = float(params.get("gravity"))
		if params.has("player_speed"):
			player_speed = float(params.get("player_speed"))

	# Collect all game objects
	var platforms: Array = []
	var collectibles: Array = []
	var enemies: Array = []
	var portals: Array = []
	var all_objects: Array = []

	var game_root := _find_game_root(root)
	if game_root == null:
		eval_ready.emit({"error": "Could not find game root node"})
		return

	_collect_level_objects(game_root, platforms, collectibles, enemies, portals, all_objects)

	# Perform analysis
	var result := {
		"game_type": game_type,
		"object_counts": {
			"platforms": platforms.size(),
			"collectibles": collectibles.size(),
			"enemies": enemies.size(),
			"portals": portals.size(),
			"total": all_objects.size(),
		},
	}

	if game_type == "platformer":
		result["reachability"] = _analyze_reachability_platformer(platforms, collectibles, portals, jump_force, gravity_val, player_speed)
		result["difficulty"] = _analyze_difficulty(platforms, collectibles, enemies, portals, game_type)
	elif game_type == "topdown":
		result["reachability"] = _analyze_reachability_topdown(all_objects, collectibles, portals, player_speed)
		result["difficulty"] = _analyze_difficulty(platforms, collectibles, enemies, portals, game_type)
	else:
		result["difficulty"] = _analyze_difficulty(platforms, collectibles, enemies, portals, game_type)

	result["design_issues"] = _find_design_issues(platforms, collectibles, enemies, portals, all_objects, game_type)
	result["suggestions"] = _generate_suggestions(result)

	eval_ready.emit(result)


func _find_game_root(root: Node) -> Node:
	# Try common game root paths
	for path in ["GameLoader/Game"]:
		var node := root.get_node_or_null(path)
		if node:
			return node
	# Fallback: look for a BaseGame-derived node
	return _find_node_by_class(root, "BaseGame")


func _find_node_by_class(node: Node, target_class: String) -> Node:
	if node.get_class() == target_class or (node.get_script() and str(node.get_script().get_path()).contains("game")):
		return node
	for child in node.get_children():
		var found := _find_node_by_class(child, target_class)
		if found:
			return found
	return null


func _collect_level_objects(node: Node, platforms: Array, collectibles: Array, enemies: Array, portals: Array, all_objects: Array) -> void:
	for child in node.get_children():
		var obj := _classify_node(child)
		if obj.is_empty():
			_collect_level_objects(child, platforms, collectibles, enemies, portals, all_objects)
			continue

		all_objects.append(obj)
		match obj.get("type", ""):
			"platform", "wall":
				platforms.append(obj)
			"collectible":
				collectibles.append(obj)
			"enemy":
				enemies.append(obj)
			"portal":
				portals.append(obj)

		# Don't recurse into classified objects (their children are internals)


func _classify_node(node: Node) -> Dictionary:
	if not node is Node2D:
		return {}

	var pos: Vector2 = (node as Node2D).position
	var obj_size := _estimate_size(node)

	if node.has_meta("enemy"):
		return {"type": "enemy", "x": pos.x, "y": pos.y, "width": obj_size.x, "height": obj_size.y, "node": node}
	if node is StaticBody2D:
		return {"type": "platform", "x": pos.x, "y": pos.y, "width": obj_size.x, "height": obj_size.y, "node": node}
	if node is Area2D:
		var area := node as Area2D
		if area.collision_layer == 2:
			return {"type": "collectible", "x": pos.x, "y": pos.y, "width": obj_size.x, "height": obj_size.y, "node": node}
		# Check for portal patterns
		if node.name.to_lower().contains("portal") or (obj_size.x >= 30 and obj_size.y >= 40):
			# Likely a portal if it's a larger area
			var child_colors := _get_child_colors(node)
			for c in child_colors:
				if c.b > 0.6 or c.g > 0.7:
					return {"type": "portal", "x": pos.x, "y": pos.y, "width": obj_size.x, "height": obj_size.y, "node": node}
		return {"type": "area", "x": pos.x, "y": pos.y, "width": obj_size.x, "height": obj_size.y, "node": node}

	return {}


func _estimate_size(node: Node) -> Vector2:
	for child in node.get_children():
		if child is ColorRect:
			return (child as ColorRect).size
		if child is CollisionShape2D:
			var shape := (child as CollisionShape2D).shape
			if shape is RectangleShape2D:
				return (shape as RectangleShape2D).size
			if shape is CircleShape2D:
				var r := (shape as CircleShape2D).radius
				return Vector2(r * 2, r * 2)
	return Vector2(32, 32)


func _get_child_colors(node: Node) -> Array:
	var colors: Array = []
	for child in node.get_children():
		if child is ColorRect:
			colors.append((child as ColorRect).color)
	return colors


func _analyze_reachability_platformer(platforms: Array, collectibles: Array, portals: Array, jump_force: float, gravity_val: float, player_speed: float) -> Dictionary:
	# Calculate max jump height and horizontal distance
	var max_jump_height: float = (jump_force * jump_force) / (2.0 * gravity_val)
	var jump_time: float = jump_force / gravity_val
	var max_horizontal_gap: float = player_speed * 2.0 * jump_time

	var result := {
		"max_jump_height_px": max_jump_height,
		"max_horizontal_gap_px": max_horizontal_gap,
		"reachable_platforms": 0,
		"unreachable_platforms": 0,
		"unreachable_details": [],
		"reachable_collectibles": 0,
		"unreachable_collectibles": 0,
		"portal_reachable": false,
	}

	# Sort platforms by x position
	var sorted_platforms := platforms.duplicate()
	sorted_platforms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("x", 0) < b.get("x", 0))

	# Start position (player spawn)
	var start_pos := Vector2(100, 500)

	# Check each platform against reachability from nearby platforms
	for i in range(sorted_platforms.size()):
		var plat: Dictionary = sorted_platforms[i]
		var plat_top: float = plat.get("y", 0)
		var plat_x: float = plat.get("x", 0)

		# Check if reachable from start or any preceding platform
		var reachable := false

		# From start position
		if plat_top >= start_pos.y - max_jump_height and abs(plat_x - start_pos.x) < max_horizontal_gap:
			reachable = true

		# From floor (y=600)
		if plat_top >= 600 - max_jump_height and plat_top <= 600:
			reachable = true

		# From any previous platform
		if not reachable:
			for j in range(i):
				var other: Dictionary = sorted_platforms[j]
				var dy: float = other.get("y", 0) - plat_top  # positive = plat is higher
				var dx: float = abs(plat_x - other.get("x", 0) - other.get("width", 0))
				if dx < 0:
					dx = 0  # Overlapping horizontally

				if dy >= 0:
					# Going up — need jump
					if dy <= max_jump_height and dx <= max_horizontal_gap:
						reachable = true
						break
				else:
					# Going down — always reachable if horizontal distance is ok
					if dx <= max_horizontal_gap * 1.5:
						reachable = true
						break

		if reachable:
			result["reachable_platforms"] += 1
		else:
			result["unreachable_platforms"] += 1
			(result["unreachable_details"] as Array).append({
				"position": {"x": plat_x, "y": plat_top},
				"reason": "No nearby platform within jump range (max height: %.0f, max gap: %.0f)" % [max_jump_height, max_horizontal_gap]
			})

	# Check collectibles
	for coll in collectibles:
		var cx: float = coll.get("x", 0)
		var cy: float = coll.get("y", 0)
		var reachable := false

		# On or near a platform?
		for plat in platforms:
			var px: float = plat.get("x", 0)
			var py: float = plat.get("y", 0)
			var pw: float = plat.get("width", 0)
			# Collectible is above the platform and within horizontal bounds
			if cx >= px - 20 and cx <= px + pw + 20 and cy >= py - max_jump_height - 20 and cy <= py + 20:
				reachable = true
				break

		# Reachable from floor
		if cy >= 600 - max_jump_height - 20 and cy <= 600:
			reachable = true

		if reachable:
			result["reachable_collectibles"] += 1
		else:
			result["unreachable_collectibles"] += 1

	# Check portal
	for portal in portals:
		var px: float = portal.get("x", 0)
		var py: float = portal.get("y", 0)
		# Portal reachable if near a reachable platform or floor
		for plat in platforms:
			var plat_x: float = plat.get("x", 0)
			var plat_y: float = plat.get("y", 0)
			var plat_w: float = plat.get("width", 0)
			if px >= plat_x - 50 and px <= plat_x + plat_w + 50 and abs(py - plat_y) < max_jump_height:
				result["portal_reachable"] = true
				break
		if py >= 600 - max_jump_height and py <= 620:
			result["portal_reachable"] = true

	return result


func _analyze_reachability_topdown(all_objects: Array, collectibles: Array, portals: Array, _player_speed: float) -> Dictionary:
	# Topdown: everything is potentially reachable unless blocked by walls
	# Simplified check — report objects that might be inside walls
	var result := {
		"reachable_collectibles": collectibles.size(),
		"unreachable_collectibles": 0,
		"portal_reachable": portals.size() > 0,
	}

	# Check for objects overlapping with walls
	var walls: Array = []
	for obj in all_objects:
		if obj.get("type") in ["platform", "wall"]:
			walls.append(obj)

	for coll in collectibles:
		for wall in walls:
			if _rects_overlap(coll, wall):
				result["unreachable_collectibles"] += 1
				result["reachable_collectibles"] -= 1
				break

	return result


func _analyze_difficulty(platforms: Array, collectibles: Array, enemies: Array, portals: Array, game_type: String) -> Dictionary:
	# Divide level into 3 zones
	var all_x: Array = []
	for obj in platforms + collectibles + enemies + portals:
		all_x.append(float(obj.get("x", 0)))

	if all_x.is_empty():
		return {"curve": "empty", "zones": []}

	all_x.sort()
	var min_x: float = all_x[0]
	var max_x: float = all_x[all_x.size() - 1]
	var range_x: float = max_x - min_x
	if range_x < 100:
		range_x = 100

	var zone_size: float = range_x / 3.0
	var zones: Array = [
		{"name": "tutorial", "x_start": min_x, "x_end": min_x + zone_size, "enemies": 0, "collectibles": 0, "platforms": 0},
		{"name": "challenge", "x_start": min_x + zone_size, "x_end": min_x + zone_size * 2, "enemies": 0, "collectibles": 0, "platforms": 0},
		{"name": "climax", "x_start": min_x + zone_size * 2, "x_end": max_x + 100, "enemies": 0, "collectibles": 0, "platforms": 0},
	]

	for enemy in enemies:
		var ex: float = enemy.get("x", 0)
		for zone in zones:
			if ex >= zone["x_start"] and ex < zone["x_end"]:
				zone["enemies"] += 1
				break

	for coll in collectibles:
		var cx: float = coll.get("x", 0)
		for zone in zones:
			if cx >= zone["x_start"] and cx < zone["x_end"]:
				zone["collectibles"] += 1
				break

	for plat in platforms:
		var px: float = plat.get("x", 0)
		for zone in zones:
			if px >= zone["x_start"] and px < zone["x_end"]:
				zone["platforms"] += 1
				break

	# Determine difficulty curve shape
	var enemy_counts: Array = []
	for zone in zones:
		enemy_counts.append(zone["enemies"])

	var curve := "unknown"
	if enemy_counts.size() >= 3:
		if enemy_counts[0] <= enemy_counts[1] and enemy_counts[1] <= enemy_counts[2]:
			curve = "ascending"  # Good — gets harder
		elif enemy_counts[0] >= enemy_counts[1] and enemy_counts[1] >= enemy_counts[2]:
			curve = "descending"  # Bad — gets easier
		elif enemy_counts[0] == enemy_counts[1] and enemy_counts[1] == enemy_counts[2]:
			curve = "flat"  # Okay but boring
		else:
			curve = "mixed"

	return {
		"curve": curve,
		"zones": zones,
		"total_enemies": enemies.size(),
		"total_collectibles": collectibles.size(),
		"total_platforms": platforms.size(),
	}


func _find_design_issues(platforms: Array, collectibles: Array, enemies: Array, portals: Array, all_objects: Array, game_type: String) -> Array:
	var issues: Array = []

	# 1. No portal
	if portals.is_empty():
		issues.append({"severity": "critical", "issue": "No portal/exit found. Player cannot win."})

	# 2. Very few platforms
	if game_type == "platformer" and platforms.size() < 3:
		issues.append({"severity": "high", "issue": "Only %d platforms. Platformer needs at least 5-10." % platforms.size()})

	# 3. No collectibles
	if collectibles.is_empty():
		issues.append({"severity": "medium", "issue": "No collectibles found. Consider adding items for score."})

	# 4. Overlapping objects
	var overlap_count := 0
	for i in range(all_objects.size()):
		for j in range(i + 1, all_objects.size()):
			if _rects_overlap(all_objects[i], all_objects[j]):
				overlap_count += 1
	if overlap_count > 3:
		issues.append({"severity": "medium", "issue": "%d object pairs overlap. Some may be unintentional." % overlap_count})

	# 5. All objects at same Y (flat level)
	if game_type == "platformer" and platforms.size() >= 3:
		var y_values: Array = []
		for p in platforms:
			y_values.append(float(p.get("y", 0)))
		y_values.sort()
		var y_range: float = y_values[y_values.size() - 1] - y_values[0]
		if y_range < 50:
			issues.append({"severity": "high", "issue": "All platforms at roughly the same height (range: %.0fpx). Level is flat — add vertical variety." % y_range})

	# 6. Empty horizontal stretches
	if platforms.size() >= 2:
		var sorted_by_x := platforms.duplicate()
		sorted_by_x.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("x", 0) < b.get("x", 0))
		for i in range(sorted_by_x.size() - 1):
			var gap: float = sorted_by_x[i + 1].get("x", 0) - (sorted_by_x[i].get("x", 0) + sorted_by_x[i].get("width", 0))
			if gap > 500:
				issues.append({"severity": "medium", "issue": "Large empty gap of %.0fpx between x=%.0f and x=%.0f." % [gap, sorted_by_x[i].get("x", 0), sorted_by_x[i + 1].get("x", 0)]})

	# 7. Enemies at spawn
	for enemy in enemies:
		if enemy.get("x", 0) < 200 and abs(enemy.get("y", 0) - 500) < 100:
			issues.append({"severity": "high", "issue": "Enemy at (%.0f, %.0f) is near player spawn. Move to later in level." % [enemy.get("x", 0), enemy.get("y", 0)]})

	# 8. Portal at spawn
	for portal in portals:
		if portal.get("x", 0) < 250:
			issues.append({"severity": "high", "issue": "Portal at x=%.0f is too close to spawn. Move to end of level." % portal.get("x", 0)})

	return issues


func _generate_suggestions(analysis: Dictionary) -> Array:
	var suggestions: Array = []
	var issues: Array = analysis.get("design_issues", [])

	for issue in issues:
		match issue.get("severity", ""):
			"critical":
				if str(issue.get("issue", "")).contains("portal"):
					suggestions.append("Add a portal at the far end of the level: spawn_node_live with type Area2D at x=world_width-200, y=floor_y-60")
			"high":
				if str(issue.get("issue", "")).contains("flat"):
					suggestions.append("Add platforms at varying heights: y=400, y=300, y=200 with ascending staircase pattern")
				if str(issue.get("issue", "")).contains("near player spawn"):
					suggestions.append("Move enemies to x>500 — give player safe space to learn controls")

	var reachability: Dictionary = analysis.get("reachability", {})
	if reachability.get("unreachable_platforms", 0) > 0:
		suggestions.append("Add stepping-stone platforms to bridge unreachable areas (max jump height: %.0fpx)" % reachability.get("max_jump_height_px", 180))

	if reachability.get("unreachable_collectibles", 0) > 0:
		suggestions.append("Move unreachable collectibles to positions above platforms or along the floor")

	var difficulty: Dictionary = analysis.get("difficulty", {})
	if difficulty.get("curve", "") == "descending":
		suggestions.append("Rearrange enemies: fewer in zone 1, more in zone 3 for ascending difficulty")
	elif difficulty.get("curve", "") == "flat":
		suggestions.append("Vary enemy density: 0-1 enemies in zone 1, 2-3 in zone 2, 3-5 in zone 3")

	return suggestions


func _rects_overlap(a: Dictionary, b: Dictionary) -> bool:
	var ax: float = a.get("x", 0)
	var ay: float = a.get("y", 0)
	var aw: float = a.get("width", 0)
	var ah: float = a.get("height", 0)
	var bx: float = b.get("x", 0)
	var by: float = b.get("y", 0)
	var bw: float = b.get("width", 0)
	var bh: float = b.get("height", 0)

	return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
