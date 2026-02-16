extends GutTest

# Tests for SeasonManager logic.
# SeasonManager extends Node and uses multiplayer, so we instantiate it
# as a standalone node (without multiplayer) and test pure logic.

var sm: Node

func before_each():
	# Load the script and create instance
	var script = load("res://scripts/world/season_manager.gd")
	sm = Node.new()
	sm.set_script(script)
	# Don't add to tree (avoids _ready multiplayer check)
	# Set initial state directly
	sm.current_year = 1
	sm.current_season = 0 # SPRING
	sm.day_in_season = 1
	sm.day_timer = 0.0
	sm.total_day_count = 1
	sm.current_weather = 0 # SUNNY

func after_each():
	if sm:
		sm.free()

# --- get_season_name ---

func test_season_name_spring():
	sm.current_season = 0
	assert_eq(sm.get_season_name(), "spring")

func test_season_name_summer():
	sm.current_season = 1
	assert_eq(sm.get_season_name(), "summer")

func test_season_name_autumn():
	sm.current_season = 2
	assert_eq(sm.get_season_name(), "autumn")

func test_season_name_winter():
	sm.current_season = 3
	assert_eq(sm.get_season_name(), "winter")

# --- get_weather_name ---

func test_weather_name_sunny():
	sm.current_weather = 0
	assert_eq(sm.get_weather_name(), "sunny")

func test_weather_name_rainy():
	sm.current_weather = 1
	assert_eq(sm.get_weather_name(), "rainy")

func test_weather_name_stormy():
	sm.current_weather = 2
	assert_eq(sm.get_weather_name(), "stormy")

func test_weather_name_windy():
	sm.current_weather = 3
	assert_eq(sm.get_weather_name(), "windy")

# --- is_crop_in_season ---

func test_crop_single_season_matching():
	sm.current_season = 0 # spring
	assert_true(sm.is_crop_in_season("spring"))

func test_crop_single_season_not_matching():
	sm.current_season = 0 # spring
	assert_false(sm.is_crop_in_season("summer"))

func test_crop_multi_season_matching():
	sm.current_season = 1 # summer
	assert_true(sm.is_crop_in_season("spring/summer"))

func test_crop_multi_season_not_matching():
	sm.current_season = 3 # winter
	assert_false(sm.is_crop_in_season("spring/summer"))

func test_crop_empty_always_true():
	sm.current_season = 3
	assert_true(sm.is_crop_in_season(""))

func test_crop_all_seasons():
	sm.current_season = 2 # autumn
	assert_true(sm.is_crop_in_season("spring/summer/autumn/winter"))

# --- is_raining ---

func test_is_raining_when_rainy():
	sm.current_weather = 1 # RAINY
	assert_true(sm.is_raining())

func test_is_raining_when_stormy():
	sm.current_weather = 2 # STORMY
	assert_true(sm.is_raining())

func test_not_raining_when_sunny():
	sm.current_weather = 0 # SUNNY
	assert_false(sm.is_raining())

func test_not_raining_when_windy():
	sm.current_weather = 3 # WINDY
	assert_false(sm.is_raining())

# --- _roll_weather distribution ---

func test_roll_weather_distribution():
	seed(42)
	var counts = [0, 0, 0, 0]
	for i in range(1000):
		seed(i * 7 + 1)
		var w = sm._roll_weather()
		counts[w] += 1
	# Sunny ~50%, rainy ~25%, stormy ~10%, windy ~15%
	assert_gt(counts[0], 350) # sunny
	assert_lt(counts[0], 650)
	assert_gt(counts[1], 130) # rainy
	assert_lt(counts[1], 400)

# --- save/load round-trip ---

func test_save_load_roundtrip():
	sm.current_year = 3
	sm.current_season = 2 # AUTUMN
	sm.day_in_season = 10
	sm.day_timer = 123.5
	sm.total_day_count = 80
	sm.current_weather = 1 # RAINY

	var data = sm.get_save_data()
	assert_eq(data["current_year"], 3)
	assert_eq(data["current_season"], 2)
	assert_eq(data["day_in_season"], 10)

	# Reset and load
	sm.current_year = 1
	sm.current_season = 0
	sm.load_save_data(data)
	assert_eq(sm.current_year, 3)
	assert_eq(sm.current_season, 2)
	assert_eq(sm.day_in_season, 10)
	assert_almost_eq(sm.day_timer, 123.5, 0.01)
	assert_eq(sm.total_day_count, 80)
	assert_eq(sm.current_weather, 1)

func test_load_backward_compat():
	# Old save format without new fields
	var old_data = {
		"current_season": 1,
		"season_timer": 42.0,
		"day_count": 15,
	}
	sm.load_save_data(old_data)
	assert_eq(sm.current_season, 1)
	assert_almost_eq(sm.day_timer, 42.0, 0.01) # falls back to season_timer
	assert_eq(sm.total_day_count, 15) # falls back to day_count
	assert_eq(sm.current_year, 1) # default
