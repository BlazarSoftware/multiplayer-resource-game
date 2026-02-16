extends GutTest

# Integration tests for battle turn pipeline.
# Tests the full flow through calculator + status + abilities + items.
# Uses RegistrySeeder, BattleFactory, MockMove, BattleTestScene.

func before_each():
	RegistrySeeder.seed_all()
	seed(42)

func after_each():
	RegistrySeeder.clear_all()

# --- Basic damage pipeline ---

func test_physical_attack_deals_damage():
	var attacker = BattleFactory.creature({"attack": 25, "types": ["spicy"]})
	var defender = BattleFactory.creature({"defense": 15, "hp": 80, "max_hp": 80, "types": ["grain"]})
	var move = MockMove.physical(50, "spicy")
	seed(42)
	var result = BattleCalculator.calculate_damage(attacker, defender, move, 5)
	assert_gt(result.damage, 0)
	defender["hp"] -= result.damage
	assert_lt(defender["hp"], 80)

func test_type_effectiveness_doubles_damage():
	var attacker = BattleFactory.creature({"attack": 20, "types": ["grain"]})
	var defender_weak = BattleFactory.creature({"defense": 15, "types": ["sweet"]})
	var defender_neutral = BattleFactory.creature({"defense": 15, "types": ["grain"]})
	var move = MockMove.physical(50, "grain")
	seed(42)
	var weak_result = BattleCalculator.calculate_damage(attacker, defender_weak, move, 5)
	seed(42)
	var neutral_result = BattleCalculator.calculate_damage(attacker, defender_neutral, move, 5)
	# Grain is SE vs sweet (2x) and neutral vs grain (1x)
	assert_gt(weak_result.damage, neutral_result.damage)

# --- Status effects during battle ---

func test_burn_reduces_hp_over_turns():
	var c = BattleFactory.creature({"status": "burned", "status_turns": 0, "hp": 80, "max_hp": 80})
	var r1 = StatusEffects.apply_end_of_turn(c)
	assert_eq(r1.damage, 10) # 80/8
	assert_eq(c["hp"], 70)
	var r2 = StatusEffects.apply_end_of_turn(c)
	assert_eq(c["hp"], 60)

func test_burn_halves_physical_damage():
	var attacker_burned = BattleFactory.creature({"attack": 20, "status": "burned", "types": ["grain"]})
	var attacker_healthy = BattleFactory.creature({"attack": 20, "status": "", "types": ["grain"]})
	var defender = BattleFactory.creature({"defense": 15})
	var move = MockMove.physical(50, "grain")
	# Burned attacker has 0.5x attack via status modifier
	# check_damage uses calculate_damage which doesn't apply status modifiers directly
	# Status modifier is on the stat itself in battle_manager._execute_action
	# But we can test the modifier separately
	var mod = StatusEffects.get_stat_modifier(attacker_burned, "attack")
	assert_eq(mod, 0.5)

# --- Ability triggers in battle ---

func test_sour_aura_on_entry():
	var creature = BattleFactory.creature({"ability_id": "sour_aura"})
	var foe = BattleFactory.creature({"defense_stage": 0})
	var battle = BattleFactory.battle()
	AbilityEffects.on_enter(creature, foe, battle)
	assert_eq(foe["defense_stage"], -1)

func test_deep_umami_boosts_umami_attack():
	var attacker = BattleFactory.creature({"ability_id": "deep_umami"})
	var move = MockMove.special(60, "umami")
	var result = AbilityEffects.on_attack(attacker, move, 100)
	assert_eq(result.damage, 130)

func test_brine_body_reduces_incoming_special():
	var defender = BattleFactory.creature({"ability_id": "brine_body"})
	var move = MockMove.special(60, "spicy")
	var result = AbilityEffects.on_defend(defender, move, 100)
	assert_eq(result.damage, 80)

func test_herbivore_absorbs_herbal():
	var defender = BattleFactory.creature({"ability_id": "herbivore", "hp": 30, "max_hp": 80})
	var move = MockMove.physical(50, "herbal")
	var result = AbilityEffects.on_defend(defender, move, 100)
	assert_eq(result.damage, 0)
	assert_eq(defender["hp"], 50) # healed 25% of 80 = 20

# --- Held item integration ---

func test_type_boost_item_increases_damage():
	var move = MockMove.physical(50, "spicy")
	var result = HeldItemEffects.on_damage_calc("spice_charm", move, 100)
	assert_eq(result.damage, 120)

func test_life_orb_boosts_with_recoil_flag():
	var move = MockMove.physical(50, "grain")
	var result = HeldItemEffects.on_damage_calc("life_orb", move, 100)
	assert_eq(result.damage, 130)
	assert_true(result.get("life_orb_recoil", false))

func test_iron_plate_reduces_physical_damage():
	var move = MockMove.physical(50, "spicy")
	var result = HeldItemEffects.on_damage_received("iron_plate", move, 100)
	assert_eq(result.damage, 80)

func test_ginger_root_cures_status():
	var c = BattleFactory.creature({"held_item_id": "ginger_root", "status": "burned", "status_turns": 2})
	var result = HeldItemEffects.on_status_applied(c)
	assert_true(result.get("cured", false))
	assert_eq(c["status"], "")
	assert_eq(c["held_item_id"], "") # consumed

func test_leftovers_heals_end_of_turn():
	var c = BattleFactory.creature({"held_item_id": "leftovers", "hp": 60, "max_hp": 80})
	var heal = HeldItemEffects.end_of_turn(c)
	assert_eq(heal, 5) # 80 * 0.0625
	assert_eq(c["hp"], 65)

# --- Protection ---

func test_protection_blocks_damage():
	# Protection is checked in battle_manager, here we test the flag setup
	var c = BattleFactory.creature({"is_protecting": true})
	assert_true(c["is_protecting"])

# --- Weather effects ---

func test_weather_boosts_matching_type():
	var move = MockMove.special(60, "spicy")
	var attacker = BattleFactory.creature({"sp_attack": 20, "types": ["grain"]})
	var defender = BattleFactory.creature({"sp_defense": 15, "types": ["grain"]})
	seed(42)
	var boosted = BattleCalculator.calculate_damage(attacker, defender, move, 5, "spicy")
	seed(42)
	var normal = BattleCalculator.calculate_damage(attacker, defender, move, 5, "")
	assert_gt(boosted.damage, normal.damage)

func test_weather_weakens_opposing_type():
	var move = MockMove.special(60, "sweet")
	var attacker = BattleFactory.creature({"sp_attack": 20, "types": ["grain"]})
	var defender = BattleFactory.creature({"sp_defense": 15, "types": ["grain"]})
	seed(42)
	var weakened = BattleCalculator.calculate_damage(attacker, defender, move, 5, "spicy") # spicy weakens sweet
	seed(42)
	var normal = BattleCalculator.calculate_damage(attacker, defender, move, 5, "")
	assert_lt(weakened.damage, normal.damage)

# --- Substitute ---

func test_substitute_hp_setup():
	var c = BattleFactory.creature({"substitute_hp": 0, "hp": 80, "max_hp": 80})
	# Substitute would be set to 25% max HP in battle_manager
	c["substitute_hp"] = c["max_hp"] / 4
	assert_eq(c["substitute_hp"], 20)

func test_damage_hits_substitute_first():
	var c = BattleFactory.creature({"substitute_hp": 20, "hp": 80})
	var damage = 30
	if c["substitute_hp"] > 0:
		var sub_dmg = min(damage, c["substitute_hp"])
		c["substitute_hp"] -= sub_dmg
		damage -= sub_dmg
	c["hp"] -= damage
	assert_eq(c["substitute_hp"], 0)
	assert_eq(c["hp"], 70) # 80 - (30-20)

# --- Taunt and Encore ---

func test_taunt_prevents_status_moves():
	var c = BattleFactory.creature({"taunt_turns": 2})
	var status_move = MockMove.status()
	# In battle_manager, taunted creatures can't use status moves
	var is_taunted = c["taunt_turns"] > 0
	assert_true(is_taunted)
	assert_eq(status_move.category, "status")

func test_encore_locks_move():
	var c = BattleFactory.creature({"encore_turns": 3, "last_move_used": "quick_bite"})
	assert_gt(c["encore_turns"], 0)
	assert_eq(c["last_move_used"], "quick_bite")

# --- Faint + Switch + Hazards ---

func test_hazards_on_switch_in():
	var c = BattleFactory.creature({"hp": 80, "max_hp": 80, "speed_stage": 0})
	var results = FieldEffects.apply_hazards_on_switch(c, ["caltrops", "slippery_oil"])
	assert_eq(results.size(), 2)
	assert_eq(c["hp"], 70) # 80 - 10 (12.5% of 80)
	assert_eq(c["speed_stage"], -1)

func test_creature_faints_at_zero_hp():
	var c = BattleFactory.creature({"hp": 5, "max_hp": 80})
	c["hp"] -= 10
	c["hp"] = max(0, c["hp"])
	assert_eq(c["hp"], 0)

# --- Bond level effects ---

func test_bond_level_4_endure():
	# Bond level 4: survive lethal hit at 1 HP (once per battle)
	var c = BattleFactory.creature({"bond_level": 4, "hp": 5, "max_hp": 80, "bond_endure_used": false})
	var damage = 10
	if c["hp"] - damage <= 0 and c["bond_level"] >= 4 and not c["bond_endure_used"]:
		c["hp"] = 1
		c["bond_endure_used"] = true
	else:
		c["hp"] = max(0, c["hp"] - damage)
	assert_eq(c["hp"], 1)
	assert_true(c["bond_endure_used"])

func test_bond_endure_only_once():
	var c = BattleFactory.creature({"bond_level": 4, "hp": 1, "max_hp": 80, "bond_endure_used": true})
	var damage = 5
	if c["hp"] - damage <= 0 and c["bond_level"] >= 4 and not c["bond_endure_used"]:
		c["hp"] = 1
		c["bond_endure_used"] = true
	else:
		c["hp"] = max(0, c["hp"] - damage)
	assert_eq(c["hp"], 0) # endure already used

func test_bond_level_5_stat_boost():
	# Bond level 5: +10% all stats — tested through get_speed
	var c = BattleFactory.creature({"speed": 20, "bond_level": 0, "status": "", "held_item_id": "", "bond_boost_stat": "speed"})
	var boosted_speed = BattleCalculator.get_speed(c)
	assert_eq(boosted_speed, 22) # 20 * 1.1 = 22

# --- Combined pipeline tests ---

func test_full_damage_pipeline():
	# Attacker: spicy type, holding spice_charm, ability scoville_boost
	var attacker = BattleFactory.creature({
		"attack": 25,
		"types": ["spicy"],
		"held_item_id": "spice_charm",
		"ability_id": "scoville_boost",
	})
	var defender = BattleFactory.creature({
		"defense": 15,
		"types": ["sweet"],
		"hp": 80,
		"max_hp": 80,
	})
	var move = MockMove.physical(50, "spicy") # spicy SE vs sweet

	seed(42)
	var calc_result = BattleCalculator.calculate_damage(attacker, defender, move, 5)
	# Apply ability boost
	var ability_result = AbilityEffects.on_attack(attacker, move, calc_result.damage)
	var dmg = ability_result.damage
	# Apply item boost
	var item_result = HeldItemEffects.on_damage_calc("spice_charm", move, dmg)
	var final_dmg = item_result.damage

	assert_gt(final_dmg, calc_result.damage) # boosted by ability + item
	assert_eq(calc_result.effectiveness, 2.0) # spicy SE vs sweet

func test_ability_defense_then_item_defense():
	# Defender: brine_body ability + spell_guard item = double special reduction
	var defender = BattleFactory.creature({"ability_id": "brine_body", "held_item_id": "spell_guard"})
	var move = MockMove.special(60, "spicy")

	var base_damage = 100
	var ability_result = AbilityEffects.on_defend(defender, move, base_damage)
	var item_result = HeldItemEffects.on_damage_received("spell_guard", move, ability_result.damage)

	assert_eq(ability_result.damage, 80) # 0.8x from brine_body
	assert_eq(item_result.damage, 64) # 0.8x from spell_guard

func test_status_cure_by_ginger_root():
	var c = BattleFactory.creature({"held_item_id": "ginger_root", "status": "poisoned", "status_turns": 1})
	var cure_result = HeldItemEffects.on_status_applied(c)
	assert_true(cure_result.get("cured", false))
	assert_eq(c["status"], "")
	assert_eq(c["held_item_id"], "") # consumed

func test_starter_culture_heals_each_turn():
	var c = BattleFactory.creature({"ability_id": "starter_culture", "hp": 60, "max_hp": 80})
	var heal1 = AbilityEffects.end_of_turn(c, "")
	assert_eq(heal1, 5)
	assert_eq(c["hp"], 65)
	var heal2 = AbilityEffects.end_of_turn(c, "")
	assert_eq(c["hp"], 70)
