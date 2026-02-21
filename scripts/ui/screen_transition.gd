extends RefCounted

# Shared screen transition utility for CanvasLayer UIs.
# Usage: await ScreenTransition.open(self)  /  await ScreenTransition.close(self)
#
# CanvasLayer `visible=false` does NOT propagate to children.
# These helpers explicitly iterate Control children.

class_name ScreenTransition

const FADE_SCALE_OPEN_DURATION := 0.2
const FADE_SCALE_CLOSE_DURATION := 0.15
const SLIDE_UP_OPEN_DURATION := 0.25
const SLIDE_UP_CLOSE_DURATION := 0.15
const TAB_FADE_OUT := 0.1
const TAB_FADE_IN := 0.15

static func open(canvas: CanvasLayer, style: String = "fade_scale") -> void:
	match style:
		"fade_scale":
			await _open_fade_scale(canvas)
		"slide_up":
			await _open_slide_up(canvas)
		_:
			await _open_fade_scale(canvas)

static func close(canvas: CanvasLayer, style: String = "fade_scale") -> void:
	match style:
		"fade_scale":
			await _close_fade_scale(canvas)
		"slide_up":
			await _close_slide_up(canvas)
		_:
			await _close_fade_scale(canvas)

# === fade_scale ===

static func _open_fade_scale(canvas: CanvasLayer) -> void:
	var children := _get_control_children(canvas)
	if children.is_empty():
		return
	for c in children:
		c.modulate.a = 0.0
		c.scale = Vector2(0.95, 0.95)
		c.pivot_offset = c.size / 2.0
	var tween := canvas.create_tween().set_parallel(true)
	for c in children:
		tween.tween_property(c, "modulate:a", 1.0, FADE_SCALE_OPEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(c, "scale", Vector2.ONE, FADE_SCALE_OPEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

static func _close_fade_scale(canvas: CanvasLayer) -> void:
	var children := _get_control_children(canvas)
	if children.is_empty():
		return
	var tween := canvas.create_tween().set_parallel(true)
	for c in children:
		c.pivot_offset = c.size / 2.0
		tween.tween_property(c, "modulate:a", 0.0, FADE_SCALE_CLOSE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(c, "scale", Vector2(0.95, 0.95), FADE_SCALE_CLOSE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	# Reset so next open starts clean
	for c in children:
		c.modulate.a = 1.0
		c.scale = Vector2.ONE

# === slide_up ===

static func _open_slide_up(canvas: CanvasLayer) -> void:
	var children := _get_control_children(canvas)
	if children.is_empty():
		return
	var offsets: Array[float] = []
	for c in children:
		offsets.append(c.position.y)
		c.modulate.a = 0.0
		c.position.y += 40.0
	var tween := canvas.create_tween().set_parallel(true)
	for i in range(children.size()):
		var c: Control = children[i]
		tween.tween_property(c, "modulate:a", 1.0, SLIDE_UP_OPEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(c, "position:y", offsets[i], SLIDE_UP_OPEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished

static func _close_slide_up(canvas: CanvasLayer) -> void:
	var children := _get_control_children(canvas)
	if children.is_empty():
		return
	var original_y: Array[float] = []
	for c in children:
		original_y.append(c.position.y)
	var tween := canvas.create_tween().set_parallel(true)
	for c in children:
		tween.tween_property(c, "modulate:a", 0.0, SLIDE_UP_CLOSE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(c, "position:y", c.position.y + 40.0, SLIDE_UP_CLOSE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	# Reset positions so next open starts clean
	for i in range(children.size()):
		children[i].modulate.a = 1.0
		children[i].position.y = original_y[i]

# === Tab crossfade ===

static func crossfade_tab(canvas: Node, old_tab: Control, new_tab: Control) -> void:
	if old_tab == new_tab:
		return
	if old_tab != null:
		var out_tween := canvas.create_tween()
		out_tween.tween_property(old_tab, "modulate:a", 0.0, TAB_FADE_OUT)
		await out_tween.finished
		old_tab.visible = false
		old_tab.modulate.a = 1.0
	if new_tab != null:
		new_tab.modulate.a = 0.0
		new_tab.visible = true
		var in_tween := canvas.create_tween()
		in_tween.tween_property(new_tab, "modulate:a", 1.0, TAB_FADE_IN)
		await in_tween.finished

# === Helpers ===

static func _get_control_children(canvas: CanvasLayer) -> Array[Control]:
	var result: Array[Control] = []
	for child in canvas.get_children():
		if child is Control and child.visible:
			result.append(child)
	return result
