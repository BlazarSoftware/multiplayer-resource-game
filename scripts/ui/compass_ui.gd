extends CanvasLayer

# Always-visible compass strip below the top HUD bar.
# Client-only — no server interaction.

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

const STRIP_HEIGHT: float = 36.0
const STRIP_Y: float = 40.0 # Below the 36px HUD top bar + 4px gap

var strip_width: float = 600.0
var pixels_per_radian: float = 600.0 / PI

# Cardinal directions: yaw value when camera faces that direction
# North = -Z (toward wild zones), camera_yaw = PI
# East = +X, camera_yaw = PI/2
# South = +Z (toward restaurants), camera_yaw = 0
# West = -X, camera_yaw = -PI/2
const CARDINALS: Array = [
	{"label": "N", "yaw": PI, "color": UITokens.STAMP_RED},
	{"label": "NE", "yaw": 3.0 * PI / 4.0, "color": UITokens.INK_MEDIUM},
	{"label": "E", "yaw": PI / 2.0, "color": UITokens.INK_DARK},
	{"label": "SE", "yaw": PI / 4.0, "color": UITokens.INK_MEDIUM},
	{"label": "S", "yaw": 0.0, "color": UITokens.INK_DARK},
	{"label": "SW", "yaw": -PI / 4.0, "color": UITokens.INK_MEDIUM},
	{"label": "W", "yaw": -PI / 2.0, "color": UITokens.INK_DARK},
	{"label": "NW", "yaw": -3.0 * PI / 4.0, "color": UITokens.INK_MEDIUM},
]

var strip: Control
var target_label: Label
var _indoor: bool = false
var _locations_cache: Array = [] # Array of LocationDef

func _ready() -> void:
	layer = 5
	UITheme.init()
	DataRegistry.ensure_loaded()
	_locations_cache = DataRegistry.locations.values()
	_build_ui()
	PlayerData.compass_target_changed.connect(_on_target_changed)
	PlayerData.location_changed.connect(_on_location_changed)

func _build_ui() -> void:
	_compute_strip_width()

	# Background strip
	strip = Control.new()
	strip.clip_contents = true
	strip.custom_minimum_size = Vector2(strip_width, STRIP_HEIGHT)
	var vw: float = get_viewport().get_visible_rect().size.x
	strip.position = Vector2((vw - strip_width) / 2.0, STRIP_Y)
	strip.size = Vector2(strip_width, STRIP_HEIGHT)
	add_child(strip)

	# Dark background for strip
	var bg = ColorRect.new()
	bg.color = Color(UITokens.PAPER_TAN.r, UITokens.PAPER_TAN.g, UITokens.PAPER_TAN.b, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.add_child(bg)

	# Center tick mark
	var tick = ColorRect.new()
	tick.color = Color(UITokens.STAMP_GOLD.r, UITokens.STAMP_GOLD.g, UITokens.STAMP_GOLD.b, 0.95)
	tick.position = Vector2(strip_width / 2.0 - 1, 0)
	tick.size = Vector2(2, STRIP_HEIGHT)
	strip.add_child(tick)

	# Target distance label (below strip)
	target_label = Label.new()
	target_label.text = ""
	UITheme.style_small(target_label)
	target_label.add_theme_color_override("font_color", UITokens.STAMP_BLUE)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var strip_center_x: float = vw / 2.0
	target_label.position = Vector2(strip_center_x - 100, STRIP_Y + STRIP_HEIGHT + 2)
	target_label.size = Vector2(200, 20)
	add_child(target_label)

	get_viewport().size_changed.connect(_on_viewport_resized)

func _compute_strip_width() -> void:
	var vw: float = get_viewport().get_visible_rect().size.x
	strip_width = clampf(vw * 0.5, 300.0, 700.0)
	pixels_per_radian = strip_width / PI

func _on_viewport_resized() -> void:
	_compute_strip_width()
	var vw: float = get_viewport().get_visible_rect().size.x
	if strip:
		strip.position = Vector2((vw - strip_width) / 2.0, STRIP_Y)
		strip.custom_minimum_size = Vector2(strip_width, STRIP_HEIGHT)
		strip.size = Vector2(strip_width, STRIP_HEIGHT)
		var tick = strip.get_child(1)
		if tick:
			tick.position = Vector2(strip_width / 2.0 - 1, 0)
	if target_label:
		target_label.position = Vector2(vw / 2.0 - 100, STRIP_Y + STRIP_HEIGHT + 2)

func _process(_delta: float) -> void:
	if _indoor:
		return
	# Get camera yaw from local player
	var camera_yaw: float = _get_camera_yaw()
	_draw_compass(camera_yaw)

func _draw_compass(camera_yaw: float) -> void:
	# Remove old cardinal labels (keep bg at index 0, tick at index 1)
	while strip.get_child_count() > 2:
		var child = strip.get_child(2)
		strip.remove_child(child)
		child.queue_free()

	var center_x = strip_width / 2.0

	# Draw cardinal markers
	for card in CARDINALS:
		var rel = _normalize_angle(card.yaw - camera_yaw)
		var px = center_x + rel * pixels_per_radian
		if px < -30 or px > strip_width + 30:
			continue
		var lbl = Label.new()
		lbl.text = card.label
		lbl.add_theme_font_size_override("font_size", UITheme.scaled(UITokens.FONT_BODY) if card.label.length() == 1 else UITheme.scaled(UITokens.FONT_TINY))
		lbl.add_theme_color_override("font_color", card.color)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(px - 12, 2 if card.label.length() == 1 else 5)
		lbl.size = Vector2(24, 20)
		strip.add_child(lbl)

	# Draw undiscovered location markers (dimmed, at top of strip)
	var player_pos = _get_player_position()
	for loc in _locations_cache:
		if loc.location_id in PlayerData.discovered_locations:
			continue
		var dx = loc.world_position.x - player_pos.x
		var dz = loc.world_position.z - player_pos.z
		var loc_yaw = atan2(dx, dz)
		var rel = _normalize_angle(loc_yaw - camera_yaw)
		var px = center_x + rel * pixels_per_radian
		if px < -4 or px > strip_width + 4:
			continue
		var marker = ColorRect.new()
		marker.color = Color(loc.icon_color.r, loc.icon_color.g, loc.icon_color.b, 0.4)
		marker.position = Vector2(px - 3, 2)
		marker.size = Vector2(6, 4)
		strip.add_child(marker)

	# Draw target marker
	if PlayerData.compass_target_id != "":
		DataRegistry.ensure_loaded()
		var loc = DataRegistry.get_location(PlayerData.compass_target_id)
		if loc:
			var dx = loc.world_position.x - player_pos.x
			var dz = loc.world_position.z - player_pos.z
			var target_yaw = atan2(dx, dz)
			var rel_angle = _normalize_angle(target_yaw - camera_yaw)
			# Clamp to strip edges
			var clamped_px = clampf(center_x + rel_angle * pixels_per_radian, 4, strip_width - 4)

			var marker = ColorRect.new()
			marker.color = loc.icon_color
			marker.position = Vector2(clamped_px - 4, STRIP_HEIGHT - 8)
			marker.size = Vector2(8, 6)
			strip.add_child(marker)

			# Distance text
			var dist = Vector2(dx, dz).length()
			target_label.text = "%s — %dm" % [loc.display_name, int(dist)]
		else:
			target_label.text = ""
	else:
		target_label.text = ""

func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

func _get_camera_yaw() -> float:
	var local_player = _get_local_player()
	if local_player and "camera_yaw" in local_player:
		return local_player.camera_yaw
	return 0.0

func _get_player_position() -> Vector3:
	var local_player = _get_local_player()
	if local_player:
		return local_player.position
	return Vector3.ZERO

func _get_local_player() -> Node:
	var players_node = get_node_or_null("/root/Main/GameWorld/Players")
	if players_node == null:
		return null
	var local_id = str(multiplayer.get_unique_id())
	return players_node.get_node_or_null(local_id)

func _on_location_changed(zone: String, _owner_name: String) -> void:
	_indoor = (zone == "restaurant")
	strip.visible = not _indoor
	target_label.visible = not _indoor


func _on_target_changed(_target_id: String) -> void:
	pass # Compass updates in _process anyway
