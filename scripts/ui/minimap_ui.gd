extends Control

# 2D top-down minimap drawn via _draw(). Client-only.
# North (-Z in game world) = up on screen.
const UITokens = preload("res://scripts/ui/ui_tokens.gd")

const DEFAULT_ZOOM: float = 3.0 # pixels per world unit
const MIN_ZOOM: float = 1.0 # ~120 unit view
const MAX_ZOOM: float = 8.0 # ~20 unit view
const ICON_RADIUS: float = 8.0
const PLAYER_SIZE: float = 10.0
const LEGEND_ICON_SIZE: float = 7.0

var zoom_level: float = DEFAULT_ZOOM
var _locations_cache: Array = [] # Array of LocationDef

# Category display order and labels for legend
const CATEGORY_LABELS: Dictionary = {
	"zone": "Zone",
	"wild_zone": "Wild",
	"crafting": "Craft",
	"shop": "Shop",
	"trainer": "Trainer",
	"social_npc": "NPC",
	"landmark": "Landmark",
}

func _ready() -> void:
	DataRegistry.ensure_loaded()
	_locations_cache = DataRegistry.locations.values()
	PlayerData.discovered_locations_changed.connect(_on_locations_changed)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _on_locations_changed() -> void:
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_level = minf(zoom_level * 1.2, MAX_ZOOM)
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_level = maxf(zoom_level / 1.2, MIN_ZOOM)
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)
			accept_event()

func _handle_click(click_pos: Vector2) -> void:
	var player_pos = _get_player_position()
	var map_center = size / 2.0
	DataRegistry.ensure_loaded()
	# Find closest discovered location to click
	var best_dist: float = 20.0 # max click distance in pixels
	var best_id: String = ""
	for loc in _locations_cache:
		if loc.location_id not in PlayerData.discovered_locations:
			continue
		var screen_pos = _world_to_map(loc.world_position, player_pos, map_center)
		var d = click_pos.distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best_id = loc.location_id
	PlayerData.set_compass_target(best_id)
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	var player_pos = _get_player_position()
	var map_center = size / 2.0

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(UITokens.PAPER_TAN.r, UITokens.PAPER_TAN.g, UITokens.PAPER_TAN.b, 0.92))

	# Grid lines (every 10 world units)
	_draw_grid(player_pos, map_center)

	# Draw ALL location icons (discovered = filled, undiscovered = outline)
	for loc in _locations_cache:
		var sp = _world_to_map(loc.world_position, player_pos, map_center)
		if sp.x < -20 or sp.x > size.x + 20 or sp.y < -20 or sp.y > size.y + 20:
			continue

		var is_discovered: bool = loc.location_id in PlayerData.discovered_locations

		# Highlight selected target (discovered only)
		if is_discovered and loc.location_id == PlayerData.compass_target_id:
			draw_arc(sp, ICON_RADIUS + 4, 0, TAU, 24, Color(UITokens.STAMP_GOLD.r, UITokens.STAMP_GOLD.g, UITokens.STAMP_GOLD.b, 0.85), 2.0)

		_draw_location_icon(sp, loc.category, loc.icon_color, is_discovered)

		# Label
		var font = ThemeDB.fallback_font
		var font_size = 12
		var label_text: String
		var label_color: Color
		if is_discovered:
			label_text = loc.display_name
			label_color = Color(UITokens.INK_DARK.r, UITokens.INK_DARK.g, UITokens.INK_DARK.b, 0.9)
		else:
			label_text = "???"
			label_color = Color(UITokens.INK_MEDIUM.r, UITokens.INK_MEDIUM.g, UITokens.INK_MEDIUM.b, 0.65)
		var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, sp + Vector2(-text_size.x / 2.0, ICON_RADIUS + 12), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)

	# Player marker (triangle pointing in facing direction)
	var camera_yaw = _get_camera_yaw()
	# Camera yaw 0 = facing +Z = south in our map (+Y screen), so map_angle = PI (pointing down)
	# Camera yaw PI = facing -Z = north = up on screen, so map_angle = 0
	var map_angle = PI - camera_yaw # Convert: yaw=0 → south (PI), yaw=PI → north (0)
	var tri_points = PackedVector2Array()
	for i in 3:
		var a = map_angle + i * TAU / 3.0 - PI / 2.0
		tri_points.append(map_center + Vector2(cos(a), sin(a)) * PLAYER_SIZE)
	draw_colored_polygon(tri_points, UITokens.STAMP_BLUE)
	draw_circle(map_center, 3.0, UITokens.PAPER_CREAM)

	# Compass rose in top-right corner
	var rose_pos = Vector2(size.x - 30, 30)
	var rose_font_size = 14
	draw_string(ThemeDB.fallback_font, rose_pos + Vector2(-4, -15), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, rose_font_size, UITokens.STAMP_RED)
	draw_string(ThemeDB.fallback_font, rose_pos + Vector2(-4, 22), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, rose_font_size, UITokens.INK_MEDIUM)
	draw_string(ThemeDB.fallback_font, rose_pos + Vector2(12, 4), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, rose_font_size, UITokens.INK_MEDIUM)
	draw_string(ThemeDB.fallback_font, rose_pos + Vector2(-20, 4), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, rose_font_size, UITokens.INK_MEDIUM)

	# Legend (bottom-left)
	_draw_legend()

## Draw a category-specific icon at the given center position.
## filled=true for discovered (solid), false for undiscovered (outline at 40% alpha).
func _draw_location_icon(center: Vector2, category: String, color: Color, filled: bool) -> void:
	var r: float = ICON_RADIUS
	var points: PackedVector2Array
	match category:
		"zone":
			# Diamond (rotated square)
			points = PackedVector2Array([
				center + Vector2(0, -r),
				center + Vector2(r, 0),
				center + Vector2(0, r),
				center + Vector2(-r, 0),
			])
		"wild_zone":
			# Triangle (point up)
			points = PackedVector2Array([
				center + Vector2(0, -r),
				center + Vector2(r, r * 0.7),
				center + Vector2(-r, r * 0.7),
			])
		"crafting":
			# Hexagon
			points = PackedVector2Array()
			for i in 6:
				var angle = i * TAU / 6.0 - PI / 2.0
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
		"shop":
			# Circle with inner dot
			if filled:
				draw_circle(center, r, color)
				draw_circle(center, r * 0.35, UITokens.PAPER_CREAM)
			else:
				var dim_color = Color(color.r, color.g, color.b, 0.4)
				draw_arc(center, r, 0, TAU, 24, dim_color, 1.5)
				draw_circle(center, r * 0.35, Color(dim_color.r, dim_color.g, dim_color.b, 0.3))
			return
		"trainer":
			# 4-pointed star
			points = PackedVector2Array()
			for i in 8:
				var angle = i * TAU / 8.0 - PI / 2.0
				var dist = r if i % 2 == 0 else r * 0.4
				points.append(center + Vector2(cos(angle), sin(angle)) * dist)
		"social_npc":
			# Rounded square (approximated with slightly inset corners)
			var s: float = r * 0.75
			var c: float = r * 0.3 # corner rounding offset
			points = PackedVector2Array([
				center + Vector2(-s + c, -s),
				center + Vector2(s - c, -s),
				center + Vector2(s, -s + c),
				center + Vector2(s, s - c),
				center + Vector2(s - c, s),
				center + Vector2(-s + c, s),
				center + Vector2(-s, s - c),
				center + Vector2(-s, -s + c),
			])
		_: # "landmark" and any unknown
			# Flag shape
			points = PackedVector2Array([
				center + Vector2(-r * 0.3, r),       # base left (pole bottom)
				center + Vector2(-r * 0.3, -r),      # pole top
				center + Vector2(r, -r * 0.5),       # flag tip right
				center + Vector2(-r * 0.3, 0),       # flag bottom return
			])
			if filled:
				# Draw pole line then flag polygon
				draw_line(center + Vector2(-r * 0.3, r), center + Vector2(-r * 0.3, -r), color, 1.5)
				var flag_pts = PackedVector2Array([
					center + Vector2(-r * 0.3, -r),
					center + Vector2(r, -r * 0.5),
					center + Vector2(-r * 0.3, 0),
				])
				draw_colored_polygon(flag_pts, color)
			else:
				var dim_color = Color(color.r, color.g, color.b, 0.4)
				draw_line(center + Vector2(-r * 0.3, r), center + Vector2(-r * 0.3, -r), dim_color, 1.5)
				var flag_pts = PackedVector2Array([
					center + Vector2(-r * 0.3, -r),
					center + Vector2(r, -r * 0.5),
					center + Vector2(-r * 0.3, 0),
					center + Vector2(-r * 0.3, -r),
				])
				draw_polyline(flag_pts, dim_color, 1.5)
			return

	# Generic polygon rendering for non-special shapes
	if filled:
		draw_colored_polygon(points, color)
	else:
		var dim_color = Color(color.r, color.g, color.b, 0.4)
		var outline = points.duplicate()
		outline.append(points[0]) # close the loop
		draw_polyline(outline, dim_color, 1.5)

func _draw_legend() -> void:
	var font = ThemeDB.fallback_font
	var font_size = 12
	var line_height: float = 18.0
	var legend_x: float = 12.0
	var legend_y: float = size.y - (CATEGORY_LABELS.size() * line_height) - 8.0
	var icon_size: float = LEGEND_ICON_SIZE
	var label_color = Color(UITokens.INK_DARK.r, UITokens.INK_DARK.g, UITokens.INK_DARK.b, 0.75)
	var bg_padding: float = 4.0

	# Semi-transparent background for legend
	var bg_rect = Rect2(
		legend_x - bg_padding,
		legend_y - bg_padding - 2,
		110 + bg_padding * 2,
		CATEGORY_LABELS.size() * line_height + bg_padding * 2 + 2
	)
	draw_rect(bg_rect, Color(UITokens.PARCHMENT_DARK.r, UITokens.PARCHMENT_DARK.g, UITokens.PARCHMENT_DARK.b, 0.82))

	var idx: int = 0
	for cat_id in CATEGORY_LABELS:
		var label: String = CATEGORY_LABELS[cat_id]
		var cy: float = legend_y + idx * line_height + line_height * 0.5
		var icon_center = Vector2(legend_x + icon_size, cy)

		# Draw a small filled icon for the legend
		_draw_legend_icon(icon_center, cat_id, icon_size)

		# Label text
		draw_string(font, Vector2(legend_x + icon_size * 2 + 6, cy + 3), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
		idx += 1

func _draw_legend_icon(center: Vector2, category: String, r: float) -> void:
	var color = Color(UITokens.STAMP_BROWN.r, UITokens.STAMP_BROWN.g, UITokens.STAMP_BROWN.b, 0.85)
	var points: PackedVector2Array
	match category:
		"zone":
			points = PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r, 0),
				center + Vector2(0, r), center + Vector2(-r, 0),
			])
			draw_colored_polygon(points, color)
		"wild_zone":
			points = PackedVector2Array([
				center + Vector2(0, -r),
				center + Vector2(r, r * 0.7),
				center + Vector2(-r, r * 0.7),
			])
			draw_colored_polygon(points, color)
		"crafting":
			points = PackedVector2Array()
			for i in 6:
				var angle = i * TAU / 6.0 - PI / 2.0
				points.append(center + Vector2(cos(angle), sin(angle)) * r)
			draw_colored_polygon(points, color)
		"shop":
			draw_circle(center, r, color)
			draw_circle(center, r * 0.35, UITokens.PAPER_CREAM)
		"trainer":
			points = PackedVector2Array()
			for i in 8:
				var angle = i * TAU / 8.0 - PI / 2.0
				var dist = r if i % 2 == 0 else r * 0.4
				points.append(center + Vector2(cos(angle), sin(angle)) * dist)
			draw_colored_polygon(points, color)
		"social_npc":
			var s: float = r * 0.75
			var c: float = r * 0.3
			points = PackedVector2Array([
				center + Vector2(-s + c, -s), center + Vector2(s - c, -s),
				center + Vector2(s, -s + c), center + Vector2(s, s - c),
				center + Vector2(s - c, s), center + Vector2(-s + c, s),
				center + Vector2(-s, s - c), center + Vector2(-s, -s + c),
			])
			draw_colored_polygon(points, color)
		_: # landmark / flag
			draw_line(center + Vector2(-r * 0.3, r), center + Vector2(-r * 0.3, -r), color, 1.0)
			var flag_pts = PackedVector2Array([
				center + Vector2(-r * 0.3, -r),
				center + Vector2(r, -r * 0.5),
				center + Vector2(-r * 0.3, 0),
			])
			draw_colored_polygon(flag_pts, color)

func _draw_grid(player_pos: Vector3, map_center: Vector2) -> void:
	var grid_spacing: float = 10.0
	var grid_color = Color(UITokens.PARCHMENT_DARK.r, UITokens.PARCHMENT_DARK.g, UITokens.PARCHMENT_DARK.b, 0.5)
	# Calculate grid range visible
	var half_view = size / (2.0 * zoom_level)
	var min_x = snappedf(player_pos.x - half_view.x, grid_spacing) - grid_spacing
	var max_x = player_pos.x + half_view.x + grid_spacing
	var min_z = snappedf(player_pos.z - half_view.y, grid_spacing) - grid_spacing
	var max_z = player_pos.z + half_view.y + grid_spacing

	var x = min_x
	while x <= max_x:
		var sp = _world_to_map(Vector3(x, 0, player_pos.z), player_pos, map_center)
		draw_line(Vector2(sp.x, 0), Vector2(sp.x, size.y), grid_color, 1.0)
		x += grid_spacing

	var z = min_z
	while z <= max_z:
		var sp = _world_to_map(Vector3(player_pos.x, 0, z), player_pos, map_center)
		draw_line(Vector2(0, sp.y), Vector2(size.x, sp.y), grid_color, 1.0)
		z += grid_spacing

func _world_to_map(world_pos: Vector3, player_pos: Vector3, map_center: Vector2) -> Vector2:
	var dx = world_pos.x - player_pos.x
	var dz = -(world_pos.z - player_pos.z) # negate so -Z (north) is up
	return map_center + Vector2(dx, dz) * zoom_level

func _get_player_position() -> Vector3:
	var local_player = _get_local_player()
	if local_player:
		return local_player.position
	return Vector3.ZERO

func _get_camera_yaw() -> float:
	var local_player = _get_local_player()
	if local_player and "camera_yaw" in local_player:
		return local_player.camera_yaw
	return 0.0

func _get_local_player() -> Node:
	var players_node = get_node_or_null("/root/Main/GameWorld/Players")
	if players_node == null:
		return null
	var local_id = str(multiplayer.get_unique_id())
	return players_node.get_node_or_null(local_id)
