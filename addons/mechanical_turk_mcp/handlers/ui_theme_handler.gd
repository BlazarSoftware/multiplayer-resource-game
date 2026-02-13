@tool
extends Node
## Handles UI theme, layout, navigation, transition, and focus operations.

signal ui_ready(result: Dictionary)

# Anchor preset mapping to Godot 4 LayoutPreset values
const ANCHOR_PRESETS := {
	"top_left": Control.PRESET_TOP_LEFT,
	"top_right": Control.PRESET_TOP_RIGHT,
	"bottom_left": Control.PRESET_BOTTOM_LEFT,
	"bottom_right": Control.PRESET_BOTTOM_RIGHT,
	"center_left": Control.PRESET_CENTER_LEFT,
	"center_top": Control.PRESET_CENTER_TOP,
	"center_right": Control.PRESET_CENTER_RIGHT,
	"center_bottom": Control.PRESET_CENTER_BOTTOM,
	"center": Control.PRESET_CENTER,
	"left_wide": Control.PRESET_LEFT_WIDE,
	"top_wide": Control.PRESET_TOP_WIDE,
	"right_wide": Control.PRESET_RIGHT_WIDE,
	"bottom_wide": Control.PRESET_BOTTOM_WIDE,
	"full_rect": Control.PRESET_FULL_RECT,
	"hcenter_wide": Control.PRESET_HCENTER_WIDE,
	"vcenter_wide": Control.PRESET_VCENTER_WIDE,
}


func _safe_get_node(node_path: String) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if node_path == "/root":
		return tree.root
	return tree.root.get_node_or_null(node_path.trim_prefix("/root"))


func handle_apply_theme(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	var theme_path: String = params.get("theme_path", "")
	var recursive: bool = params.get("recursive", false)

	if node_path.is_empty() or theme_path.is_empty():
		return {"error": "node_path and theme_path are required"}

	var node := _safe_get_node(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}
	if not node is Control:
		return {"error": "Node must be a Control, got: %s" % node.get_class()}

	if not ResourceLoader.exists(theme_path):
		return {"error": "Theme resource not found: %s" % theme_path}

	var theme: Theme = load(theme_path) as Theme
	if theme == null:
		return {"error": "Failed to load theme: %s" % theme_path}

	(node as Control).theme = theme

	var applied_count: int = 1
	if recursive:
		applied_count += _apply_theme_recursive(node, theme)

	return {"status": "ok", "node": node_path, "theme": theme_path, "applied_count": applied_count}


func _apply_theme_recursive(parent: Node, theme: Theme) -> int:
	var count: int = 0
	for child in parent.get_children():
		if child is Control:
			(child as Control).theme = theme
			count += 1
		count += _apply_theme_recursive(child, theme)
	return count


func handle_configure_layout(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return {"error": "node_path is required"}

	var node := _safe_get_node(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}
	if not node is Control:
		return {"error": "Node must be a Control, got: %s" % node.get_class()}

	var control := node as Control

	# Apply anchor preset
	var preset_name: String = params.get("anchor_preset", "")
	if not preset_name.is_empty():
		if ANCHOR_PRESETS.has(preset_name):
			control.set_anchors_preset(ANCHOR_PRESETS[preset_name])
		else:
			return {"error": "Unknown anchor preset: %s" % preset_name}

	# Apply offsets
	var offsets = params.get("offsets", null)
	if offsets is Dictionary:
		if offsets.has("left"):
			control.offset_left = float(offsets["left"])
		if offsets.has("top"):
			control.offset_top = float(offsets["top"])
		if offsets.has("right"):
			control.offset_right = float(offsets["right"])
		if offsets.has("bottom"):
			control.offset_bottom = float(offsets["bottom"])

	# Size flags
	if params.has("size_flags_horizontal"):
		control.size_flags_horizontal = int(params["size_flags_horizontal"])
	if params.has("size_flags_vertical"):
		control.size_flags_vertical = int(params["size_flags_vertical"])

	# Minimum size
	var min_size = params.get("min_size", null)
	if min_size is Dictionary:
		control.custom_minimum_size = Vector2(
			float(min_size.get("x", 0)),
			float(min_size.get("y", 0))
		)

	return {"status": "ok", "node": node_path, "anchor_preset": preset_name}


func handle_configure_navigation(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return {"error": "node_path is required"}

	var node := _safe_get_node(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}
	if not node is Control:
		return {"error": "Node must be a Control, got: %s" % node.get_class()}

	var control := node as Control

	# Focus neighbors
	if params.has("focus_neighbor_top") and params["focus_neighbor_top"] is String:
		control.focus_neighbor_top = NodePath(params["focus_neighbor_top"])
	if params.has("focus_neighbor_bottom") and params["focus_neighbor_bottom"] is String:
		control.focus_neighbor_bottom = NodePath(params["focus_neighbor_bottom"])
	if params.has("focus_neighbor_left") and params["focus_neighbor_left"] is String:
		control.focus_neighbor_left = NodePath(params["focus_neighbor_left"])
	if params.has("focus_neighbor_right") and params["focus_neighbor_right"] is String:
		control.focus_neighbor_right = NodePath(params["focus_neighbor_right"])

	# Focus next/previous
	if params.has("focus_next") and params["focus_next"] is String:
		control.focus_next = NodePath(params["focus_next"])
	if params.has("focus_previous") and params["focus_previous"] is String:
		control.focus_previous = NodePath(params["focus_previous"])

	# Focus mode
	var focus_mode_str: String = params.get("focus_mode", "")
	if not focus_mode_str.is_empty():
		match focus_mode_str:
			"none":
				control.focus_mode = Control.FOCUS_NONE
			"click":
				control.focus_mode = Control.FOCUS_CLICK
			"all":
				control.focus_mode = Control.FOCUS_ALL

	return {"status": "ok", "node": node_path}


func handle_add_transition(params) -> Dictionary:
	_add_transition_deferred(params)
	return {"_deferred": ui_ready}


func _add_transition_deferred(params) -> void:
	await get_tree().process_frame

	if not params is Dictionary:
		ui_ready.emit({"error": "Invalid params"})
		return

	var node_path: String = params.get("node_path", "")
	var transition_type: String = params.get("transition_type", "")
	var duration: float = float(params.get("duration", 0.3))
	var direction: String = params.get("direction", "left")
	var easing_name: String = params.get("easing", "quad")

	if node_path.is_empty() or transition_type.is_empty():
		ui_ready.emit({"error": "node_path and transition_type are required"})
		return

	var node := _safe_get_node(node_path)
	if node == null:
		ui_ready.emit({"error": "Node not found: %s" % node_path})
		return
	if not node is Control:
		ui_ready.emit({"error": "Node must be a Control, got: %s" % node.get_class()})
		return

	var control := node as Control
	var tree := get_tree()
	if tree == null:
		ui_ready.emit({"error": "No scene tree available"})
		return

	# Map easing name to Tween constant
	var trans_type: int = Tween.TRANS_QUAD
	match easing_name:
		"linear": trans_type = Tween.TRANS_LINEAR
		"quad": trans_type = Tween.TRANS_QUAD
		"cubic": trans_type = Tween.TRANS_CUBIC
		"back": trans_type = Tween.TRANS_BACK
		"elastic": trans_type = Tween.TRANS_ELASTIC
		"bounce": trans_type = Tween.TRANS_BOUNCE

	var tween := tree.create_tween()

	match transition_type:
		"fade_in":
			control.modulate.a = 0.0
			tween.tween_property(control, "modulate:a", 1.0, duration).set_trans(trans_type).set_ease(Tween.EASE_OUT)
		"fade_out":
			tween.tween_property(control, "modulate:a", 0.0, duration).set_trans(trans_type).set_ease(Tween.EASE_IN)
		"slide_in":
			var original_pos := control.position
			var start_offset := _get_slide_offset(control, direction)
			control.position = original_pos + start_offset
			tween.tween_property(control, "position", original_pos, duration).set_trans(trans_type).set_ease(Tween.EASE_OUT)
		"slide_out":
			var target_offset := _get_slide_offset(control, direction)
			tween.tween_property(control, "position", control.position + target_offset, duration).set_trans(trans_type).set_ease(Tween.EASE_IN)
		"scale_in":
			control.scale = Vector2.ZERO
			control.pivot_offset = control.size * 0.5
			tween.tween_property(control, "scale", Vector2.ONE, duration).set_trans(trans_type).set_ease(Tween.EASE_OUT)
		"scale_out":
			control.pivot_offset = control.size * 0.5
			tween.tween_property(control, "scale", Vector2.ZERO, duration).set_trans(trans_type).set_ease(Tween.EASE_IN)
		"popup":
			control.scale = Vector2(0.5, 0.5)
			control.modulate.a = 0.0
			control.pivot_offset = control.size * 0.5
			tween.set_parallel(true)
			tween.tween_property(control, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(control, "modulate:a", 1.0, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_:
			ui_ready.emit({"error": "Unknown transition type: %s" % transition_type})
			return

	ui_ready.emit({
		"status": "ok",
		"node": node_path,
		"transition": transition_type,
		"duration": duration,
	})


func _get_slide_offset(control: Control, direction: String) -> Vector2:
	var viewport_size := control.get_viewport_rect().size
	match direction:
		"left":
			return Vector2(-viewport_size.x, 0)
		"right":
			return Vector2(viewport_size.x, 0)
		"top":
			return Vector2(0, -viewport_size.y)
		"bottom":
			return Vector2(0, viewport_size.y)
		_:
			return Vector2(-viewport_size.x, 0)


func handle_grab_focus(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return {"error": "node_path is required"}

	var node := _safe_get_node(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}
	if not node is Control:
		return {"error": "Node must be a Control, got: %s" % node.get_class()}

	(node as Control).grab_focus()

	return {"status": "ok", "node": node_path}
