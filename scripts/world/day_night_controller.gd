extends Node
## Client-side day/night cycle controller.
## Drives the sky shader, sun light, and ambient lighting based on SeasonManager time.
## Exits immediately on dedicated server (no visuals needed).

# Season preset sky colors {sky_day, horizon_day, sky_sunset, horizon_sunset, sky_night, horizon_night}
const SEASON_SKY := {
	"spring": {
		"sky_day": Color(0.006, 0.357, 0.512),
		"horizon_day": Color(0.824, 0.837, 0.750),
		"sky_sunset": Color(0.094, 0.237, 0.302),
		"horizon_sunset": Color(0.958, 0.324, 0.186),
		"sky_night": Color(0.106, 0.089, 0.107),
		"horizon_night": Color(0.125, 0.153, 0.140),
		"cloud_density": 0.7,
	},
	"summer": {
		"sky_day": Color(0.05, 0.35, 0.65),
		"horizon_day": Color(0.90, 0.85, 0.70),
		"sky_sunset": Color(0.15, 0.20, 0.35),
		"horizon_sunset": Color(0.95, 0.40, 0.15),
		"sky_night": Color(0.08, 0.06, 0.12),
		"horizon_night": Color(0.10, 0.12, 0.10),
		"cloud_density": 0.4,
	},
	"autumn": {
		"sky_day": Color(0.15, 0.28, 0.50),
		"horizon_day": Color(0.85, 0.75, 0.55),
		"sky_sunset": Color(0.20, 0.15, 0.25),
		"horizon_sunset": Color(0.90, 0.35, 0.20),
		"sky_night": Color(0.09, 0.07, 0.10),
		"horizon_night": Color(0.12, 0.10, 0.12),
		"cloud_density": 1.2,
	},
	"winter": {
		"sky_day": Color(0.277, 0.286, 0.651),
		"horizon_day": Color(0.744, 0.842, 0.915),
		"sky_sunset": Color(0.165, 0.218, 0.318),
		"horizon_sunset": Color(0.852, 0.424, 0.396),
		"sky_night": Color(0.066, 0.079, 0.208),
		"horizon_night": Color(0.111, 0.143, 0.219),
		"cloud_density": 1.5,
	},
}

# Weather light energy targets
const WEATHER_LIGHT := {
	"sunny": 1.0,
	"rainy": 0.5,
	"stormy": 0.3,
	"windy": 0.85,
}

# Weather cloud density offsets (added to season base)
const WEATHER_CLOUD_OFFSET := {
	"sunny": 0.0,
	"rainy": 1.8,
	"stormy": 2.8,
	"windy": 0.3,
}

# Weather wind speed multipliers
const WEATHER_WIND := {
	"sunny": Vector2(0.05, 0.05),
	"rainy": Vector2(0.08, 0.08),
	"stormy": Vector2(0.15, 0.12),
	"windy": Vector2(0.12, 0.10),
}

var _dir_light: DirectionalLight3D
var _sky_material: ShaderMaterial
var _world_env: WorldEnvironment
var _season_mgr: Node
var _target_light_energy: float = 1.0
var _current_season: String = "spring"
var _current_weather: String = "sunny"
var _tween: Tween

func _ready() -> void:
	# Server headless guard — no visuals needed
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	# Also skip on server peer (even if not headless, server doesn't render game world)
	if multiplayer.is_server():
		set_process(false)
		return

	# Find existing DirectionalLight3D
	_dir_light = get_node_or_null("../Environment/DirectionalLight3D")
	if not _dir_light:
		push_warning("[DayNightController] No DirectionalLight3D found at Environment/DirectionalLight3D")
		set_process(false)
		return

	# Load the spring sky material as base
	var base_mat := load("res://assets/sky/material/basic/warm_material_01.tres") as ShaderMaterial
	if not base_mat:
		push_warning("[DayNightController] Could not load sky material")
		set_process(false)
		return

	# Duplicate so we don't modify the shared resource
	_sky_material = base_mat.duplicate() as ShaderMaterial
	_sky_material.set_shader_parameter("use_directional_light", true)
	_sky_material.set_shader_parameter("day_night_mix", 1.0)

	# Create Sky + WorldEnvironment
	var sky := Sky.new()
	sky.sky_material = _sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0

	_world_env = WorldEnvironment.new()
	_world_env.name = "SkyEnvironment"
	_world_env.environment = env
	add_child(_world_env)

	# Find SeasonManager
	_season_mgr = get_node_or_null("../SeasonManager")
	if _season_mgr:
		if _season_mgr.has_signal("season_changed"):
			_season_mgr.season_changed.connect(_on_season_changed)
		if _season_mgr.has_signal("weather_changed"):
			_season_mgr.weather_changed.connect(_on_weather_changed)
		# Initialize to current state
		if _season_mgr.has_method("get_current_season"):
			_current_season = _season_mgr.get_current_season()
			_apply_season_colors_immediate(_current_season)
		if _season_mgr.has_method("get_weather_name"):
			_current_weather = _season_mgr.get_weather_name()
			_apply_weather_immediate(_current_weather)

func _process(_delta: float) -> void:
	if not _season_mgr or not _dir_light or not _sky_material:
		return

	# Get day progress (0-1)
	var progress: float = _season_mgr.get_day_progress()

	# Map progress to sun angle:
	# 0.0 = sunrise (east), 0.25 = noon (top), 0.5 = sunset (west), 0.75 = midnight (bottom)
	var sun_angle: float = (progress - 0.25) * TAU
	_dir_light.rotation.x = sun_angle
	# Keep Y rotation for sun direction (slightly angled, not straight overhead)
	_dir_light.rotation.y = deg_to_rad(-30)

	# Compute day_factor from sun height (how much "daytime" there is)
	# sin of sun_angle: 1.0 at noon, -1.0 at midnight
	var sun_height: float = -sin(sun_angle) # Negative because Godot's -Z is forward
	var day_factor: float = clampf(sun_height * 2.0 + 0.5, 0.0, 1.0)

	# Lerp light properties
	var night_energy := 0.05
	_dir_light.light_energy = lerpf(night_energy, _target_light_energy, day_factor)
	_dir_light.light_color = Color(1.0, 0.97, 0.92).lerp(Color(0.4, 0.45, 0.7), 1.0 - day_factor)

	# Shadow softness at night
	_dir_light.shadow_enabled = day_factor > 0.05

	# Ambient light
	if _world_env and _world_env.environment:
		_world_env.environment.ambient_light_energy = lerpf(0.05, 0.3, day_factor)

	# Day/night mix for sky shader (-1 = night, 0 = sunset, 1 = day)
	var mix: float = clampf(sun_height * 2.0, -1.0, 1.0)
	_sky_material.set_shader_parameter("day_night_mix", mix)

func _on_season_changed(new_season: String) -> void:
	_current_season = new_season
	_tween_season_colors(new_season)

func _on_weather_changed(new_weather: String) -> void:
	_current_weather = new_weather
	_tween_weather(new_weather)

func _apply_season_colors_immediate(season: String) -> void:
	if not _sky_material:
		return
	var preset: Dictionary = SEASON_SKY.get(season, SEASON_SKY["spring"])
	for param in ["sky_day", "horizon_day", "sky_sunset", "horizon_sunset", "sky_night", "horizon_night"]:
		if preset.has(param):
			_sky_material.set_shader_parameter(param, preset[param])
	_sky_material.set_shader_parameter("cloud_density", float(preset.get("cloud_density", 0.7)))

func _tween_season_colors(season: String) -> void:
	if not _sky_material:
		return
	var preset: Dictionary = SEASON_SKY.get(season, SEASON_SKY["spring"])
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for param in ["sky_day", "horizon_day", "sky_sunset", "horizon_sunset", "sky_night", "horizon_night"]:
		if preset.has(param):
			var current: Color = _sky_material.get_shader_parameter(param)
			_tween.tween_method(
				func(val: Color): _sky_material.set_shader_parameter(param, val),
				current, preset[param] as Color, 3.0
			)
	var current_density: float = _sky_material.get_shader_parameter("cloud_density")
	var target_density: float = float(preset.get("cloud_density", 0.7)) + float(WEATHER_CLOUD_OFFSET.get(_current_weather, 0.0))
	_tween.tween_method(
		func(val: float): _sky_material.set_shader_parameter("cloud_density", val),
		current_density, target_density, 3.0
	)

func _apply_weather_immediate(weather: String) -> void:
	_target_light_energy = float(WEATHER_LIGHT.get(weather, 1.0))
	if _sky_material:
		var season_preset: Dictionary = SEASON_SKY.get(_current_season, SEASON_SKY["spring"])
		var base_density: float = float(season_preset.get("cloud_density", 0.7))
		var offset: float = float(WEATHER_CLOUD_OFFSET.get(weather, 0.0))
		_sky_material.set_shader_parameter("cloud_density", base_density + offset)
		var wind: Vector2 = WEATHER_WIND.get(weather, Vector2(0.05, 0.05))
		_sky_material.set_shader_parameter("wind_speed", wind)

func _tween_weather(weather: String) -> void:
	_target_light_energy = float(WEATHER_LIGHT.get(weather, 1.0))
	if not _sky_material:
		return
	var season_preset: Dictionary = SEASON_SKY.get(_current_season, SEASON_SKY["spring"])
	var base_density: float = float(season_preset.get("cloud_density", 0.7))
	var offset: float = float(WEATHER_CLOUD_OFFSET.get(weather, 0.0))
	var target_density: float = base_density + offset
	var target_wind: Vector2 = WEATHER_WIND.get(weather, Vector2(0.05, 0.05))
	var current_density: float = _sky_material.get_shader_parameter("cloud_density")
	var current_wind: Vector2 = _sky_material.get_shader_parameter("wind_speed")
	var tw := create_tween().set_parallel(true)
	tw.tween_method(
		func(val: float): _sky_material.set_shader_parameter("cloud_density", val),
		current_density, target_density, 2.0
	)
	tw.tween_method(
		func(val: Vector2): _sky_material.set_shader_parameter("wind_speed", val),
		current_wind, target_wind, 2.0
	)
