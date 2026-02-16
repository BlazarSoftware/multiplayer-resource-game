extends GutTest

# Tests for HeldItemEffects static methods.
# Requires RegistrySeeder for held item lookups.

func before_each():
	RegistrySeeder.seed_all()

func after_each():
	RegistrySeeder.clear_all()

# --- on_damage_calc ---

func test_type_boost_matching_type():
	var move = MockMove.physical(50, "spicy")
	var result = HeldItemEffects.on_damage_calc("spice_charm", move, 100)
	assert_eq(result.damage, 120) # 100 * 1.2

func test_type_boost_non_matching():
	var move = MockMove.physical(50, "sweet")
	var result = HeldItemEffects.on_damage_calc("spice_charm", move, 100)
	assert_eq(result.damage, 100)

func test_choice_fork_boosts_physical():
	var move = MockMove.physical(50, "spicy")
	var result = HeldItemEffects.on_damage_calc("choice_fork", move, 100)
	assert_eq(result.damage, 150)

func test_choice_fork_no_boost_special():
	var move = MockMove.special(50, "spicy")
	var result = HeldItemEffects.on_damage_calc("choice_fork", move, 100)
	assert_eq(result.damage, 100)

func test_choice_spoon_boosts_special():
	var move = MockMove.special(50, "sweet")
	var result = HeldItemEffects.on_damage_calc("choice_spoon", move, 100)
	assert_eq(result.damage, 150)

func test_life_orb_boosts_and_flags_recoil():
	var move = MockMove.physical(50, "spicy")
	var result = HeldItemEffects.on_damage_calc("life_orb", move, 100)
	assert_eq(result.damage, 130) # 1.3x
	assert_true(result.get("life_orb_recoil", false))

func test_empty_item_id_passthrough():
	var move = MockMove.physical(50, "spicy")
	var result = HeldItemEffects.on_damage_calc("", move, 100)
	assert_eq(result.damage, 100)

func test_zero_damage_passthrough():
	var move = MockMove.physical(50, "spicy")
	var result = HeldItemEffects.on_damage_calc("spice_charm", move, 0)
	assert_eq(result.damage, 0)

# --- on_damage_received ---

func test_iron_plate_reduces_physical():
	var move = MockMove.physical(50, "spicy")
	var result = HeldItemEffects.on_damage_received("iron_plate", move, 100)
	assert_eq(result.damage, 80)

func test_iron_plate_no_effect_special():
	var move = MockMove.special(50, "spicy")
	var result = HeldItemEffects.on_damage_received("iron_plate", move, 100)
	assert_eq(result.damage, 100)

func test_spell_guard_reduces_special():
	var move = MockMove.special(50, "sweet")
	var result = HeldItemEffects.on_damage_received("spell_guard", move, 100)
	assert_eq(result.damage, 80)

# --- end_of_turn ---

func test_leftovers_heals():
	var c = BattleFactory.creature({"held_item_id": "leftovers", "hp": 60, "max_hp": 80})
	var heal = HeldItemEffects.end_of_turn(c)
	assert_eq(heal, 5) # 80 * 0.0625
	assert_eq(c["hp"], 65)

func test_leftovers_capped_at_max():
	var c = BattleFactory.creature({"held_item_id": "leftovers", "hp": 79, "max_hp": 80})
	HeldItemEffects.end_of_turn(c)
	assert_eq(c["hp"], 80)

func test_no_item_no_heal():
	var c = BattleFactory.creature({"held_item_id": ""})
	assert_eq(HeldItemEffects.end_of_turn(c), 0)

# --- on_status_applied ---

func test_ginger_root_cures_and_consumed():
	var c = BattleFactory.creature({"held_item_id": "ginger_root", "status": "burned", "status_turns": 2})
	var result = HeldItemEffects.on_status_applied(c)
	assert_true(result.get("cured", false))
	assert_eq(c["status"], "")
	assert_eq(c["status_turns"], 0)
	assert_eq(c["held_item_id"], "") # consumed

func test_non_cure_item_no_effect():
	var c = BattleFactory.creature({"held_item_id": "spice_charm", "status": "burned"})
	var result = HeldItemEffects.on_status_applied(c)
	assert_eq(result.size(), 0)
	assert_eq(c["status"], "burned")

# --- on_hp_threshold ---

func test_espresso_shot_boosts_speed():
	var c = BattleFactory.creature({"held_item_id": "espresso_shot", "hp": 15, "max_hp": 80, "speed": 20})
	# 15/80 = 0.1875 < 0.25 threshold
	var result = HeldItemEffects.on_hp_threshold(c)
	assert_eq(result.get("stat_boost"), "speed")
	assert_eq(c["speed"], 30) # 20 * 1.5
	assert_eq(c["held_item_id"], "") # consumed

func test_espresso_shot_above_threshold():
	var c = BattleFactory.creature({"held_item_id": "espresso_shot", "hp": 60, "max_hp": 80, "speed": 20})
	var result = HeldItemEffects.on_hp_threshold(c)
	assert_eq(result.size(), 0)
	assert_eq(c["speed"], 20) # unchanged

func test_golden_truffle_heals():
	var c = BattleFactory.creature({"held_item_id": "golden_truffle", "hp": 15, "max_hp": 80})
	var result = HeldItemEffects.on_hp_threshold(c)
	assert_eq(result.get("heal"), 20) # 80 * 0.25
	assert_eq(c["hp"], 35) # 15 + 20
	assert_eq(c["held_item_id"], "") # consumed

func test_no_double_trigger():
	var c = BattleFactory.creature({"held_item_id": "espresso_shot", "hp": 15, "max_hp": 80, "speed": 20})
	HeldItemEffects.on_hp_threshold(c) # first trigger
	# Re-equip the item (simulating test scenario)
	c["held_item_id"] = "espresso_shot"
	var result2 = HeldItemEffects.on_hp_threshold(c)
	# _item_threshold_triggered is still true
	assert_eq(result2.size(), 0)
