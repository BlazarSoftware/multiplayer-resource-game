extends GutTest

# Tests for StatusEffects pure static methods

# --- get_stat_modifier ---

func test_burned_halves_attack():
	var c = {"status": "burned"}
	assert_eq(StatusEffects.get_stat_modifier(c, "attack"), 0.5)

func test_burned_no_effect_on_defense():
	var c = {"status": "burned"}
	assert_eq(StatusEffects.get_stat_modifier(c, "defense"), 1.0)

func test_wilted_halves_sp_attack():
	var c = {"status": "wilted"}
	assert_eq(StatusEffects.get_stat_modifier(c, "sp_attack"), 0.5)

func test_wilted_reduces_speed():
	var c = {"status": "wilted"}
	assert_eq(StatusEffects.get_stat_modifier(c, "speed"), 0.75)

func test_soured_halves_defense():
	var c = {"status": "soured"}
	assert_eq(StatusEffects.get_stat_modifier(c, "defense"), 0.5)

func test_soured_no_effect_on_attack():
	var c = {"status": "soured"}
	assert_eq(StatusEffects.get_stat_modifier(c, "attack"), 1.0)

func test_brined_halves_speed():
	var c = {"status": "brined"}
	assert_eq(StatusEffects.get_stat_modifier(c, "speed"), 0.5)

func test_no_status_returns_one():
	var c = {"status": ""}
	assert_eq(StatusEffects.get_stat_modifier(c, "attack"), 1.0)

func test_missing_status_key_returns_one():
	var c = {}
	assert_eq(StatusEffects.get_stat_modifier(c, "attack"), 1.0)

# --- get_status_display_name ---

func test_display_burned():
	assert_eq(StatusEffects.get_status_display_name("burned"), "Seared")

func test_display_frozen():
	assert_eq(StatusEffects.get_status_display_name("frozen"), "Brain Freeze")

func test_display_poisoned():
	assert_eq(StatusEffects.get_status_display_name("poisoned"), "Food Poisoning")

func test_display_drowsy():
	assert_eq(StatusEffects.get_status_display_name("drowsy"), "Food Coma")

func test_display_wilted():
	assert_eq(StatusEffects.get_status_display_name("wilted"), "Wilted")

func test_display_soured():
	assert_eq(StatusEffects.get_status_display_name("soured"), "Soured")

func test_display_brined():
	assert_eq(StatusEffects.get_status_display_name("brined"), "Brined")

func test_display_unknown():
	assert_eq(StatusEffects.get_status_display_name("cosmic"), "")

func test_display_empty():
	assert_eq(StatusEffects.get_status_display_name(""), "")

# --- apply_end_of_turn ---

func test_burn_deals_damage():
	var c = {"status": "burned", "status_turns": 0, "hp": 80, "max_hp": 80}
	var result = StatusEffects.apply_end_of_turn(c)
	assert_eq(result.damage, 10) # 80/8
	assert_eq(c["hp"], 70)
	assert_false(result.cured)

func test_burn_cures_after_five_turns():
	var c = {"status": "burned", "status_turns": 4, "hp": 80, "max_hp": 80}
	var result = StatusEffects.apply_end_of_turn(c)
	assert_true(result.cured)
	assert_eq(c["status"], "")
	assert_eq(c["status_turns"], 0)

func test_poison_escalating_damage():
	var c = {"status": "poisoned", "status_turns": 0, "hp": 80, "max_hp": 80}
	# Turn 1: fraction=1, dmg = 80*1/8 = 10
	var r1 = StatusEffects.apply_end_of_turn(c)
	assert_eq(r1.damage, 10)
	assert_eq(c["hp"], 70)
	# Turn 2: fraction=2, dmg = 80*2/8 = 20
	var r2 = StatusEffects.apply_end_of_turn(c)
	assert_eq(r2.damage, 20)
	assert_eq(c["hp"], 50)

func test_poison_damage_caps_at_four():
	var c = {"status": "poisoned", "status_turns": 3, "hp": 80, "max_hp": 80}
	# Turn 4: fraction = min(4,4) = 4
	var result = StatusEffects.apply_end_of_turn(c)
	assert_eq(result.damage, 40) # 80*4/8

func test_frozen_cures_after_five_turns():
	var c = {"status": "frozen", "status_turns": 4, "hp": 80, "max_hp": 80}
	var result = StatusEffects.apply_end_of_turn(c)
	assert_true(result.cured)
	assert_eq(c["status"], "")

func test_drowsy_cures_after_four_turns():
	var c = {"status": "drowsy", "status_turns": 3, "hp": 80, "max_hp": 80}
	var result = StatusEffects.apply_end_of_turn(c)
	assert_true(result.cured)
	assert_eq(c["status"], "")

func test_wilted_cures_after_three_turns():
	var c = {"status": "wilted", "status_turns": 2, "hp": 80, "max_hp": 80}
	var result = StatusEffects.apply_end_of_turn(c)
	assert_true(result.cured)
	assert_eq(c["status"], "")

func test_soured_cures_after_three_turns():
	var c = {"status": "soured", "status_turns": 2, "hp": 80, "max_hp": 80}
	var result = StatusEffects.apply_end_of_turn(c)
	assert_true(result.cured)

func test_brined_cures_after_four_turns():
	var c = {"status": "brined", "status_turns": 3, "hp": 80, "max_hp": 80}
	var result = StatusEffects.apply_end_of_turn(c)
	assert_true(result.cured)

func test_no_status_no_op():
	var c = {"status": "", "status_turns": 0, "hp": 80, "max_hp": 80}
	var result = StatusEffects.apply_end_of_turn(c)
	assert_eq(result.damage, 0)
	assert_false(result.cured)
	assert_eq(c["hp"], 80)

func test_burn_hp_cannot_go_below_zero():
	var c = {"status": "burned", "status_turns": 0, "hp": 3, "max_hp": 80}
	StatusEffects.apply_end_of_turn(c)
	assert_eq(c["hp"], 0)

# --- try_apply_status ---

func test_try_apply_on_empty_creature():
	seed(42)
	var c = {"status": ""}
	var result = StatusEffects.try_apply_status(c, "burned", 100)
	assert_true(result)
	assert_eq(c["status"], "burned")
	assert_eq(c["status_turns"], 0)

func test_try_apply_fails_with_existing_status():
	var c = {"status": "frozen"}
	var result = StatusEffects.try_apply_status(c, "burned", 100)
	assert_false(result)
	assert_eq(c["status"], "frozen")

func test_try_apply_empty_status_string():
	var c = {"status": ""}
	var result = StatusEffects.try_apply_status(c, "", 100)
	assert_false(result)
