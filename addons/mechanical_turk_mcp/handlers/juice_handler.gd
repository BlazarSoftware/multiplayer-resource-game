@tool
extends Node
## Handles juice / game-feel effects: punch scale, screen shake, hit stop, hit flash, UI pop.

signal juice_ready(result: Dictionary)


func handle_punch_scale(params) -> Dictionary:
	_punch_scale_deferred(params)
	return {"_deferred": juice_ready}


func _punch_scale_deferred(params) -> void:
	await get_tree().process_frame

	if not params is Dictionary:
		juice_ready.emit({"error": "Invalid params"})
		return

	var node_path: String = params.get("node_path", "")
	var strength: float = float(params.get("strength", 1.3))
	var duration: float = float(params.get("duration", 0.3))
	var easing_name: String = params.get("easing", "elastic")

	if node_path.is_empty():
		juice_ready.emit({"error": "node_path is required"})
		return

	var tree := get_tree()
	if tree == null:
		juice_ready.emit({"error": "No scene tree available"})
		return

	var node := tree.root.get_node_or_null(node_path.trim_prefix("/root"))
	if node_path == "/root":
		node = tree.root
	if node == null:
		juice_ready.emit({"error": "Node not found: %s" % node_path})
		return

	# Get original scale
	var original_scale: Variant
	if node is Node2D:
		original_scale = (node as Node2D).scale
	elif node is Control:
		original_scale = (node as Control).scale
	else:
		juice_ready.emit({"error": "Node must be Node2D or Control, got: %s" % node.get_class()})
		return

	var target_scale: Variant
	if original_scale is Vector2:
		target_scale = original_scale * strength

	# Determine easing
	var ease_type: int = Tween.EASE_OUT
	var trans_type: int
	match easing_name:
		"elastic":
			trans_type = Tween.TRANS_ELASTIC
		"back":
			trans_type = Tween.TRANS_BACK
		"bounce":
			trans_type = Tween.TRANS_BOUNCE
		_:
			trans_type = Tween.TRANS_ELASTIC

	# Create tween: scale up quickly, then ease back
	var tween := tree.create_tween()
	tween.tween_property(node, "scale", target_scale, duration * 0.3)
	tween.tween_property(node, "scale", original_scale, duration * 0.7).set_ease(ease_type).set_trans(trans_type)

	juice_ready.emit({
		"status": "ok",
		"node": node_path,
		"effect": "punch_scale",
		"strength": strength,
		"duration": duration,
	})


func handle_screen_shake(params) -> Dictionary:
	_screen_shake_deferred(params)
	return {"_deferred": juice_ready}


func _screen_shake_deferred(params) -> void:
	await get_tree().process_frame

	if not params is Dictionary:
		juice_ready.emit({"error": "Invalid params"})
		return

	var camera_path: String = params.get("camera_path", "")
	var intensity: float = float(params.get("intensity", 10.0))
	var duration: float = float(params.get("duration", 0.3))
	var frequency: float = float(params.get("frequency", 15.0))

	var tree := get_tree()
	if tree == null:
		juice_ready.emit({"error": "No scene tree available"})
		return

	# Find camera
	var camera: Camera2D = null
	if not camera_path.is_empty():
		var node := tree.root.get_node_or_null(camera_path.trim_prefix("/root"))
		if node is Camera2D:
			camera = node as Camera2D
	else:
		# Auto-detect: find first Camera2D marked as current, or first Camera2D
		camera = _find_camera_2d(tree.root)

	if camera == null:
		juice_ready.emit({"error": "No Camera2D found. Provide cameraPath or add a Camera2D to the scene."})
		return

	# Use FastNoiseLite for smooth noise-based shake
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = frequency * 0.01

	var original_offset := camera.offset
	var elapsed: float = 0.0

	# Shake loop using process frames
	while elapsed < duration:
		var delta := get_process_delta_time()
		elapsed += delta
		var decay: float = 1.0 - (elapsed / duration)
		var noise_x: float = noise.get_noise_2d(elapsed * frequency * 100.0, 0.0) * intensity * decay
		var noise_y: float = noise.get_noise_2d(0.0, elapsed * frequency * 100.0) * intensity * decay
		camera.offset = original_offset + Vector2(noise_x, noise_y)
		await get_tree().process_frame

	# Restore original offset
	camera.offset = original_offset

	juice_ready.emit({
		"status": "ok",
		"effect": "screen_shake",
		"intensity": intensity,
		"duration": duration,
	})


func _find_camera_2d(root: Node) -> Camera2D:
	if root is Camera2D and (root as Camera2D).is_current():
		return root as Camera2D
	for child in root.get_children():
		var result := _find_camera_2d(child)
		if result != null:
			return result
	# Fallback: return first Camera2D found
	if root is Camera2D:
		return root as Camera2D
	for child in root.get_children():
		if child is Camera2D:
			return child as Camera2D
		var deep := _find_camera_2d(child)
		if deep != null:
			return deep
	return null


func handle_hit_stop(params) -> Dictionary:
	_hit_stop_deferred(params)
	return {"_deferred": juice_ready}


func _hit_stop_deferred(params) -> void:
	await get_tree().process_frame

	if not params is Dictionary:
		juice_ready.emit({"error": "Invalid params"})
		return

	var duration: float = float(params.get("duration", 0.05))
	var time_scale: float = float(params.get("time_scale", 0.0))

	var tree := get_tree()
	if tree == null:
		juice_ready.emit({"error": "No scene tree available"})
		return

	var original_time_scale: float = Engine.time_scale
	Engine.time_scale = time_scale

	# Use a process-independent timer (SceneTreeTimer ignores time_scale when process_always=true)
	await tree.create_timer(duration, true, false, true).timeout

	Engine.time_scale = original_time_scale

	juice_ready.emit({
		"status": "ok",
		"effect": "hit_stop",
		"duration": duration,
		"time_scale_during": time_scale,
		"restored_time_scale": original_time_scale,
	})


func handle_hit_flash(params) -> Dictionary:
	_hit_flash_deferred(params)
	return {"_deferred": juice_ready}


func _hit_flash_deferred(params) -> void:
	await get_tree().process_frame

	if not params is Dictionary:
		juice_ready.emit({"error": "Invalid params"})
		return

	var node_path: String = params.get("node_path", "")
	var color_hex: String = params.get("color", "#ffffff")
	var duration: float = float(params.get("duration", 0.1))

	if node_path.is_empty():
		juice_ready.emit({"error": "node_path is required"})
		return

	var tree := get_tree()
	if tree == null:
		juice_ready.emit({"error": "No scene tree available"})
		return

	var node := tree.root.get_node_or_null(node_path.trim_prefix("/root"))
	if node_path == "/root":
		node = tree.root
	if node == null:
		juice_ready.emit({"error": "Node not found: %s" % node_path})
		return

	if not node is CanvasItem:
		juice_ready.emit({"error": "Node must be a CanvasItem (Sprite2D, etc.), got: %s" % node.get_class()})
		return

	var canvas_item := node as CanvasItem

	# Save original material
	var original_material: Material = canvas_item.material

	# Create flash shader
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_mix : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = mix(tex, vec4(flash_color.rgb, tex.a), flash_mix);
}
"""
	var flash_mat := ShaderMaterial.new()
	flash_mat.shader = shader
	flash_mat.set_shader_parameter("flash_color", Color(color_hex))
	flash_mat.set_shader_parameter("flash_mix", 1.0)

	# Apply flash
	canvas_item.material = flash_mat

	# Wait then restore
	await tree.create_timer(duration, false).timeout
	canvas_item.material = original_material

	juice_ready.emit({
		"status": "ok",
		"node": node_path,
		"effect": "hit_flash",
		"color": color_hex,
		"duration": duration,
	})


func handle_ui_pop(params) -> Dictionary:
	_ui_pop_deferred(params)
	return {"_deferred": juice_ready}


func _ui_pop_deferred(params) -> void:
	await get_tree().process_frame

	if not params is Dictionary:
		juice_ready.emit({"error": "Invalid params"})
		return

	var node_path: String = params.get("node_path", "")
	var strength: float = float(params.get("strength", 1.2))
	var duration: float = float(params.get("duration", 0.2))

	if node_path.is_empty():
		juice_ready.emit({"error": "node_path is required"})
		return

	var tree := get_tree()
	if tree == null:
		juice_ready.emit({"error": "No scene tree available"})
		return

	var node := tree.root.get_node_or_null(node_path.trim_prefix("/root"))
	if node_path == "/root":
		node = tree.root
	if node == null:
		juice_ready.emit({"error": "Node not found: %s" % node_path})
		return

	if not node is Control:
		juice_ready.emit({"error": "Node must be a Control, got: %s" % node.get_class()})
		return

	var control := node as Control
	var original_scale := control.scale
	var pop_scale := original_scale * strength

	# Set pivot to center for natural pop
	control.pivot_offset = control.size * 0.5

	var tween := tree.create_tween()
	tween.tween_property(control, "scale", pop_scale, duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", original_scale, duration * 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	juice_ready.emit({
		"status": "ok",
		"node": node_path,
		"effect": "ui_pop",
		"strength": strength,
		"duration": duration,
	})
