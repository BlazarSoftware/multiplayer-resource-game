extends GutTest

# Tests for compass bearing and angle normalization math.
# These test the pure math functions used by compass_ui.gd.

# Compass coordinate system:
# North = -Z (toward wild zones), camera_yaw = PI
# East = +X, camera_yaw = PI/2
# South = +Z (toward restaurants), camera_yaw = 0
# West = -X, camera_yaw = -PI/2

func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

func _target_bearing(player_pos: Vector3, target_pos: Vector3) -> float:
	var dx = target_pos.x - player_pos.x
	var dz = target_pos.z - player_pos.z
	return atan2(dx, dz)

func test_cardinal_north_facing() -> void:
	# When camera faces north (yaw=PI), N cardinal should be at center (rel=0)
	var camera_yaw = PI
	var north_yaw = PI
	var rel = _normalize_angle(north_yaw - camera_yaw)
	assert_almost_eq(rel, 0.0, 0.01, "N should be at center when facing north")

func test_cardinal_south_facing() -> void:
	# When camera faces south (yaw=0), S cardinal should be at center (rel=0)
	var camera_yaw = 0.0
	var south_yaw = 0.0
	var rel = _normalize_angle(south_yaw - camera_yaw)
	assert_almost_eq(rel, 0.0, 0.01, "S should be at center when facing south")

func test_cardinal_east_when_facing_north() -> void:
	# When facing north (yaw=PI), E (yaw=PI/2) should be to the right (negative rel)
	var camera_yaw = PI
	var east_yaw = PI / 2.0
	var rel = _normalize_angle(east_yaw - camera_yaw)
	assert_almost_eq(rel, -PI / 2.0, 0.01, "E should be PI/2 to the right when facing north")

func test_target_bearing_north() -> void:
	# Target at (0, 0, -10), player at origin. Target is north (-Z direction).
	# atan2(0, -10) = PI (pointing -Z)
	var bearing = _target_bearing(Vector3.ZERO, Vector3(0, 0, -10))
	assert_almost_eq(bearing, PI, 0.01, "Target due north should have bearing PI")

func test_target_bearing_east() -> void:
	# Target at (10, 0, 0), player at origin. Target is east (+X direction).
	# atan2(10, 0) = PI/2
	var bearing = _target_bearing(Vector3.ZERO, Vector3(10, 0, 0))
	assert_almost_eq(bearing, PI / 2.0, 0.01, "Target due east should have bearing PI/2")

func test_target_bearing_south() -> void:
	# Target at (0, 0, 10), player at origin. Target is south (+Z direction).
	# atan2(0, 10) = 0
	var bearing = _target_bearing(Vector3.ZERO, Vector3(0, 0, 10))
	assert_almost_eq(bearing, 0.0, 0.01, "Target due south should have bearing 0")

func test_target_bearing_west() -> void:
	# Target at (-10, 0, 0), player at origin. Target is west (-X direction).
	# atan2(-10, 0) = -PI/2
	var bearing = _target_bearing(Vector3.ZERO, Vector3(-10, 0, 0))
	assert_almost_eq(bearing, -PI / 2.0, 0.01, "Target due west should have bearing -PI/2")

func test_target_directly_behind() -> void:
	# Facing north (yaw=PI), target due south (bearing=0)
	# Relative angle should be PI (or -PI, both are "behind")
	var camera_yaw = PI
	var target_bearing = 0.0 # south
	var rel = _normalize_angle(target_bearing - camera_yaw)
	assert_almost_eq(absf(rel), PI, 0.01, "Target directly behind should have |rel| = PI")

func test_target_distance_calculation() -> void:
	var player_pos = Vector3(0, 0, 0)
	var target_pos = Vector3(30, 0, -40) # 50 units away (3-4-5 triangle scaled by 10)
	var dx = target_pos.x - player_pos.x
	var dz = target_pos.z - player_pos.z
	var dist = Vector2(dx, dz).length()
	assert_almost_eq(dist, 50.0, 0.01, "Distance should be 50 units")

func test_angle_normalization_positive_wrap() -> void:
	var angle = 3.5 * PI # should wrap to 1.5*PI = -0.5*PI
	var normalized = _normalize_angle(angle)
	assert_true(normalized >= -PI and normalized <= PI, "Should be in [-PI, PI] range")
	assert_almost_eq(normalized, -PI / 2.0, 0.01)

func test_angle_normalization_negative_wrap() -> void:
	var angle = -3.0 * PI # should wrap to -PI or PI (both equivalent)
	var normalized = _normalize_angle(angle)
	assert_true(normalized >= -PI and normalized <= PI, "Should be in [-PI, PI] range")
	# -3PI normalizes to -PI (equivalent to PI, both represent 180 degrees)
	assert_almost_eq(absf(normalized), PI, 0.01)

func test_angle_normalization_identity() -> void:
	# Angles already in range should not change
	assert_almost_eq(_normalize_angle(0.0), 0.0, 0.001)
	assert_almost_eq(_normalize_angle(PI / 2.0), PI / 2.0, 0.001)
	assert_almost_eq(_normalize_angle(-PI / 2.0), -PI / 2.0, 0.001)

func test_relative_angle_right_of_center() -> void:
	# Facing north (yaw=PI), target to NE (bearing=3PI/4)
	# NE is to the right when facing north
	var camera_yaw = PI
	var target_bearing = 3.0 * PI / 4.0
	var rel = _normalize_angle(target_bearing - camera_yaw)
	assert_true(rel < 0, "NE target should be to the right (negative) when facing north")
	assert_almost_eq(rel, -PI / 4.0, 0.01)

func test_relative_angle_left_of_center() -> void:
	# Facing north (yaw=PI), target to NW (bearing=-3PI/4)
	var camera_yaw = PI
	var target_bearing = -3.0 * PI / 4.0
	var rel = _normalize_angle(target_bearing - camera_yaw)
	assert_true(rel > 0 or rel < 0, "Should compute valid relative angle")
	# -3PI/4 - PI = -7PI/4 -> normalized to PI/4 (to the left)
	assert_almost_eq(rel, PI / 4.0, 0.01)

# --- Undiscovered location marker tests ---

const STRIP_WIDTH: float = 400.0
const PIXELS_PER_RADIAN: float = STRIP_WIDTH / (PI * 1.0)

func _marker_px(player_pos: Vector3, loc_pos: Vector3, camera_yaw: float) -> float:
	## Returns the pixel x-position of a location marker on the compass strip.
	var dx = loc_pos.x - player_pos.x
	var dz = loc_pos.z - player_pos.z
	var loc_yaw = atan2(dx, dz)
	var rel = _normalize_angle(loc_yaw - camera_yaw)
	return STRIP_WIDTH / 2.0 + rel * PIXELS_PER_RADIAN

func _marker_visible(player_pos: Vector3, loc_pos: Vector3, camera_yaw: float) -> bool:
	## Returns whether a marker would be within the visible strip bounds.
	var px = _marker_px(player_pos, loc_pos, camera_yaw)
	return px >= -4 and px <= STRIP_WIDTH + 4

func test_undiscovered_marker_visible_when_facing_location() -> void:
	# Location due north, camera facing north -> should be visible at center
	var player_pos = Vector3.ZERO
	var loc_pos = Vector3(0, 0, -50)
	var camera_yaw = PI # facing north
	assert_true(_marker_visible(player_pos, loc_pos, camera_yaw))
	var px = _marker_px(player_pos, loc_pos, camera_yaw)
	assert_almost_eq(px, STRIP_WIDTH / 2.0, 1.0, "Should be at center of strip")

func test_undiscovered_marker_hidden_when_behind() -> void:
	# Location due south, camera facing north -> behind camera, not visible
	var player_pos = Vector3.ZERO
	var loc_pos = Vector3(0, 0, 50)
	var camera_yaw = PI # facing north
	assert_false(_marker_visible(player_pos, loc_pos, camera_yaw))

func test_undiscovered_marker_offset_position() -> void:
	# Location to the east, camera facing north -> should be right of center
	var player_pos = Vector3.ZERO
	var loc_pos = Vector3(50, 0, 0) # east
	var camera_yaw = PI # facing north
	assert_true(_marker_visible(player_pos, loc_pos, camera_yaw))
	var px = _marker_px(player_pos, loc_pos, camera_yaw)
	assert_true(px < STRIP_WIDTH / 2.0, "East location should be right of center (lower px) when facing north")

func test_undiscovered_filtering_logic() -> void:
	# Simulate the discovered/undiscovered filtering
	var all_ids = ["loc_a", "loc_b", "loc_c", "loc_d"]
	var discovered = ["loc_a", "loc_c"]
	var undiscovered: Array = []
	for id in all_ids:
		if id not in discovered:
			undiscovered.append(id)
	assert_eq(undiscovered.size(), 2)
	assert_true("loc_b" in undiscovered)
	assert_true("loc_d" in undiscovered)
	assert_false("loc_a" in undiscovered)
