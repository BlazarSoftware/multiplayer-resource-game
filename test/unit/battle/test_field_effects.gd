extends GutTest

# Tests for FieldEffects pure static methods

# --- get_weather_modifier ---

func test_spicy_weather_boosts_spicy():
	assert_eq(FieldEffects.get_weather_modifier("spicy", "spicy"), 1.5)

func test_spicy_weather_weakens_sweet():
	assert_eq(FieldEffects.get_weather_modifier("spicy", "sweet"), 0.5)

func test_spicy_weather_neutral_sour():
	assert_eq(FieldEffects.get_weather_modifier("spicy", "sour"), 1.0)

func test_sweet_weather_boosts_sweet():
	assert_eq(FieldEffects.get_weather_modifier("sweet", "sweet"), 1.5)

func test_sweet_weather_weakens_sour():
	assert_eq(FieldEffects.get_weather_modifier("sweet", "sour"), 0.5)

func test_sour_weather_boosts_sour():
	assert_eq(FieldEffects.get_weather_modifier("sour", "sour"), 1.5)

func test_sour_weather_weakens_herbal():
	assert_eq(FieldEffects.get_weather_modifier("sour", "herbal"), 0.5)

func test_herbal_weather_boosts_herbal():
	assert_eq(FieldEffects.get_weather_modifier("herbal", "herbal"), 1.5)

func test_herbal_weather_weakens_spicy():
	assert_eq(FieldEffects.get_weather_modifier("herbal", "spicy"), 0.5)

func test_umami_weather_boosts_umami():
	assert_eq(FieldEffects.get_weather_modifier("umami", "umami"), 1.5)

func test_umami_weather_weakens_grain():
	assert_eq(FieldEffects.get_weather_modifier("umami", "grain"), 0.5)

func test_grain_weather_boosts_grain():
	assert_eq(FieldEffects.get_weather_modifier("grain", "grain"), 1.5)

func test_grain_weather_weakens_umami():
	assert_eq(FieldEffects.get_weather_modifier("grain", "umami"), 0.5)

func test_empty_weather_returns_one():
	assert_eq(FieldEffects.get_weather_modifier("", "spicy"), 1.0)

func test_empty_move_type_returns_one():
	assert_eq(FieldEffects.get_weather_modifier("spicy", ""), 1.0)

func test_unknown_weather_returns_one():
	assert_eq(FieldEffects.get_weather_modifier("cosmic", "spicy"), 1.0)

# --- get_weather_name ---

func test_weather_name_spicy():
	assert_eq(FieldEffects.get_weather_name("spicy"), "Sizzle Sun")

func test_weather_name_sweet():
	assert_eq(FieldEffects.get_weather_name("sweet"), "Sugar Hail")

func test_weather_name_sour():
	assert_eq(FieldEffects.get_weather_name("sour"), "Acid Rain")

func test_weather_name_herbal():
	assert_eq(FieldEffects.get_weather_name("herbal"), "Herb Breeze")

func test_weather_name_umami():
	assert_eq(FieldEffects.get_weather_name("umami"), "Umami Fog")

func test_weather_name_grain():
	assert_eq(FieldEffects.get_weather_name("grain"), "Grain Dust")

func test_weather_name_unknown():
	assert_eq(FieldEffects.get_weather_name("cosmic"), "")

func test_weather_name_empty():
	assert_eq(FieldEffects.get_weather_name(""), "")

# --- apply_hazards_on_switch ---

func test_caltrops_damage():
	var c = {"hp": 80, "max_hp": 80}
	var results = FieldEffects.apply_hazards_on_switch(c, ["caltrops"])
	assert_eq(results.size(), 1)
	assert_eq(results[0].type, "hazard_damage")
	assert_eq(results[0].damage, 10) # 80 * 0.125
	assert_eq(c["hp"], 70)

func test_caltrops_min_one_damage():
	var c = {"hp": 4, "max_hp": 4}
	var results = FieldEffects.apply_hazards_on_switch(c, ["caltrops"])
	assert_eq(results[0].damage, 1)

func test_slippery_oil_lowers_speed():
	var c = {"hp": 80, "max_hp": 80, "speed_stage": 0}
	var results = FieldEffects.apply_hazards_on_switch(c, ["slippery_oil"])
	assert_eq(results.size(), 1)
	assert_eq(results[0].type, "hazard_stat")
	assert_eq(c["speed_stage"], -1)

func test_both_hazards_together():
	var c = {"hp": 80, "max_hp": 80, "speed_stage": 0}
	var results = FieldEffects.apply_hazards_on_switch(c, ["caltrops", "slippery_oil"])
	assert_eq(results.size(), 2)
	assert_eq(c["hp"], 70)
	assert_eq(c["speed_stage"], -1)

func test_empty_hazards():
	var c = {"hp": 80, "max_hp": 80}
	var results = FieldEffects.apply_hazards_on_switch(c, [])
	assert_eq(results.size(), 0)
	assert_eq(c["hp"], 80)

func test_unknown_hazard_skipped():
	var c = {"hp": 80, "max_hp": 80}
	var results = FieldEffects.apply_hazards_on_switch(c, ["unknown_trap"])
	assert_eq(results.size(), 0)

func test_slippery_oil_clamps_at_minus_six():
	var c = {"hp": 80, "max_hp": 80, "speed_stage": -6}
	FieldEffects.apply_hazards_on_switch(c, ["slippery_oil"])
	assert_eq(c["speed_stage"], -6)
