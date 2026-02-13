extends Node

signal season_changed(new_season: String)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SEASON_NAMES = ["spring", "summer", "autumn", "winter"]
const SEASON_DURATION = 300.0 # 5 real minutes per season

var current_season: Season = Season.SPRING
var season_timer: float = 0.0
var day_count: int = 1

# Season ground tint colors
const SEASON_COLORS = {
	"spring": Color(0.35, 0.6, 0.3, 1),
	"summer": Color(0.3, 0.7, 0.25, 1),
	"autumn": Color(0.6, 0.45, 0.2, 1),
	"winter": Color(0.8, 0.85, 0.9, 1)
}

func _ready() -> void:
	if not multiplayer.is_server():
		return

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	season_timer += delta
	if season_timer >= SEASON_DURATION:
		season_timer -= SEASON_DURATION
		_advance_season()

func _advance_season() -> void:
	current_season = (current_season + 1) % 4 as Season
	day_count += 1
	var season_name = get_season_name()
	print("Season changed to: ", season_name, " (Day ", day_count, ")")
	_broadcast_season.rpc(current_season, day_count)
	season_changed.emit(season_name)

@rpc("authority", "call_local", "reliable")
func _broadcast_season(season: int, day: int) -> void:
	current_season = season as Season
	day_count = day
	season_changed.emit(get_season_name())

func get_season_name() -> String:
	return SEASON_NAMES[current_season]

func get_season_color() -> Color:
	return SEASON_COLORS[get_season_name()]

func is_crop_in_season(crop_season: String) -> bool:
	if crop_season == "":
		return true # grows in any season
	var current = get_season_name()
	# Some crops grow in multiple seasons (separated by /)
	var seasons = crop_season.split("/")
	return current in seasons

@rpc("any_peer", "reliable")
func request_season_sync() -> void:
	var sender = multiplayer.get_remote_sender_id()
	_broadcast_season.rpc_id(sender, current_season, day_count)

func get_save_data() -> Dictionary:
	return {
		"current_season": current_season,
		"season_timer": season_timer,
		"day_count": day_count
	}

func load_save_data(data: Dictionary) -> void:
	current_season = data.get("current_season", 0) as Season
	season_timer = data.get("season_timer", 0.0)
	day_count = data.get("day_count", 1)
	season_changed.emit(get_season_name())
