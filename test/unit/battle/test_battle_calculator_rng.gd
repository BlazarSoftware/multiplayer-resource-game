extends GutTest

# Tests for BattleCalculator methods that depend on RNG or DataRegistry.
# Uses seed() for deterministic results, MockMove and BattleFactory helpers,
# and RegistrySeeder to populate DataRegistry.

func before_each():
	RegistrySeeder.seed_all()
	seed(12345)

func after_each():
	RegistrySeeder.clear_all()

# --- calculate_damage: physical formula ---

func test_physical_damage_basic():
	var attacker = BattleFactory.creature({"attack": 20, "types": ["spicy"]})
	var defender = BattleFactory.creature({"defense": 15, "types": ["grain"]})
	var move = MockMove.physical(50, "spicy")
	seed(42) # fix RNG
	var result = BattleCalculator.calculate_damage(attacker, defender, move, 5)
	assert_gt(result.damage, 0)
	assert_eq(result.effectiveness, 1.0) # spicy vs grain = neutral

func test_special_damage_basic():
	var attacker = BattleFactory.creature({"sp_attack": 25, "types": ["sweet"]})
	var defender = BattleFactory.creature({"sp_defense": 12, "types": ["sour"]})
	var move = MockMove.special(60, "sweet")
	seed(42)
	var result = BattleCalculator.calculate_damage(attacker, defender, move, 5)
	assert_gt(result.damage, 0)
	assert_eq(result.effectiveness, 2.0) # sweet vs sour = SE

func test_status_move_zero_damage():
	var attacker = BattleFactory.creature()
	var defender = BattleFactory.creature()
	var move = MockMove.status()
	var result = BattleCalculator.calculate_damage(attacker, defender, move, 5)
	assert_eq(result.damage, 0)
	assert_false(result.critical)

func test_stab_bonus():
	# Attacker is spicy, move is spicy -> 1.5x STAB
	var attacker = BattleFactory.creature({"attack": 20, "types": ["spicy"]})
	var defender = BattleFactory.creature({"defense": 15, "types": ["grain"]})
	var spicy_move = MockMove.physical(50, "spicy")
	var neutral_move = MockMove.physical(50, "grain")
	seed(42)
	var stab_result = BattleCalculator.calculate_damage(attacker, defender, spicy_move, 5)
	seed(42) # same RNG
	var neutral_result = BattleCalculator.calculate_damage(attacker, defender, neutral_move, 5)
	assert_gt(stab_result.damage, neutral_result.damage)

func test_type_effectiveness_in_damage():
	var attacker = BattleFactory.creature({"attack": 20, "types": ["grain"]})
	var defender_weak = BattleFactory.creature({"defense": 15, "types": ["sweet"]}) # grain SE vs sweet
	var defender_resist = BattleFactory.creature({"defense": 15, "types": ["sour"]}) # grain NVE vs sour
	var move = MockMove.physical(50, "grain")
	seed(42)
	var se_result = BattleCalculator.calculate_damage(attacker, defender_weak, move, 5)
	seed(42)
	var nve_result = BattleCalculator.calculate_damage(attacker, defender_resist, move, 5)
	assert_gt(se_result.damage, nve_result.damage)
	assert_eq(se_result.effectiveness, 2.0)
	assert_eq(nve_result.effectiveness, 0.5)

func test_weather_modifier_in_damage():
	var attacker = BattleFactory.creature({"sp_attack": 20, "types": ["grain"]})
	var defender = BattleFactory.creature({"sp_defense": 15, "types": ["grain"]})
	var move = MockMove.special(50, "spicy")
	seed(42)
	var boosted = BattleCalculator.calculate_damage(attacker, defender, move, 5, "spicy") # 1.5x
	seed(42)
	var normal = BattleCalculator.calculate_damage(attacker, defender, move, 5, "")
	assert_gt(boosted.damage, normal.damage)

func test_stat_stages_affect_damage():
	var attacker_boosted = BattleFactory.creature({"attack": 20, "attack_stage": 2})
	var attacker_normal = BattleFactory.creature({"attack": 20, "attack_stage": 0})
	var defender = BattleFactory.creature({"defense": 15})
	var move = MockMove.physical(50, "grain")
	seed(42)
	var boosted_result = BattleCalculator.calculate_damage(attacker_boosted, defender, move, 5)
	seed(42)
	var normal_result = BattleCalculator.calculate_damage(attacker_normal, defender, move, 5)
	assert_gt(boosted_result.damage, normal_result.damage)

func test_min_damage_is_one():
	var attacker = BattleFactory.creature({"attack": 1})
	var defender = BattleFactory.creature({"defense": 999, "types": ["sour"]}) # NVE for spicy
	var move = MockMove.physical(1, "spicy")
	seed(42)
	var result = BattleCalculator.calculate_damage(attacker, defender, move, 1)
	assert_gte(result.damage, 1)

func test_bond_boost_increases_damage():
	var attacker_bond = BattleFactory.creature({"attack": 20, "types": ["grain"], "bond_boost_stat": "attack"})
	var attacker_none = BattleFactory.creature({"attack": 20, "types": ["grain"], "bond_boost_stat": ""})
	var defender = BattleFactory.creature({"defense": 15})
	var move = MockMove.physical(50, "grain")
	seed(42)
	var bond_result = BattleCalculator.calculate_damage(attacker_bond, defender, move, 5)
	seed(42)
	var normal_result = BattleCalculator.calculate_damage(attacker_none, defender, move, 5)
	assert_gte(bond_result.damage, normal_result.damage)

func test_bond_nerf_decreases_damage():
	var attacker_nerf = BattleFactory.creature({"attack": 20, "types": ["grain"], "bond_nerf_stat": "attack"})
	var attacker_none = BattleFactory.creature({"attack": 20, "types": ["grain"], "bond_nerf_stat": ""})
	var defender = BattleFactory.creature({"defense": 15})
	var move = MockMove.physical(50, "grain")
	seed(42)
	var nerf_result = BattleCalculator.calculate_damage(attacker_nerf, defender, move, 5)
	seed(42)
	var normal_result = BattleCalculator.calculate_damage(attacker_none, defender, move, 5)
	assert_lte(nerf_result.damage, normal_result.damage)

# --- check_accuracy ---

func test_accuracy_100_always_hits():
	var move = MockMove.physical(50, "spicy", 100)
	var attacker = BattleFactory.creature()
	var defender = BattleFactory.creature()
	# 100% accuracy always returns true
	for i in range(20):
		assert_true(BattleCalculator.check_accuracy(move, attacker, defender))

func test_accuracy_zero_always_hits():
	var move = MockMove.with_props({"accuracy": 0}) # 0 or 100 => always true
	var attacker = BattleFactory.creature()
	var defender = BattleFactory.creature()
	assert_true(BattleCalculator.check_accuracy(move, attacker, defender))

func test_accuracy_stages_affect_hit():
	var move = MockMove.with_props({"accuracy": 50}) # 50% base
	var attacker_boosted = BattleFactory.creature({"accuracy_stage": 6})
	var attacker_normal = BattleFactory.creature({"accuracy_stage": 0})
	var defender = BattleFactory.creature()
	# With +6 accuracy stage, 50% becomes 50 * 3.0 = 150%, always hits
	for i in range(10):
		assert_true(BattleCalculator.check_accuracy(move, attacker_boosted, defender))

func test_evasion_reduces_accuracy():
	var move = MockMove.with_props({"accuracy": 50})
	var attacker = BattleFactory.creature({"accuracy_stage": 0})
	var defender_evasive = BattleFactory.creature({"evasion_stage": 6}) # 3/(3+6) = 1/3
	# Net stage = 0 - 6 = -6 => multiplier = 3/9 = 0.333
	# acc = 50 * 0.333 = 16.65, so many misses
	var hits = 0
	for i in range(100):
		seed(i * 7)
		if BattleCalculator.check_accuracy(move, attacker, defender_evasive):
			hits += 1
	assert_lt(hits, 50) # should miss a lot

# --- check_critical ---

func test_critical_base_rate():
	# Stage 0: 1/16 chance
	var attacker = BattleFactory.creature({"crit_stage": 0, "bond_level": 0, "held_item_id": ""})
	var move = MockMove.physical()
	var crits = 0
	for i in range(1000):
		seed(i)
		if BattleCalculator.check_critical(attacker, move):
			crits += 1
	# Expected ~62.5 (1/16), allow wide range
	assert_gt(crits, 20)
	assert_lt(crits, 150)

func test_critical_high_stage():
	# Stage 3: 1/2 chance
	var attacker = BattleFactory.creature({"crit_stage": 3, "bond_level": 0, "held_item_id": ""})
	var move = MockMove.physical()
	var crits = 0
	for i in range(1000):
		seed(i)
		if BattleCalculator.check_critical(attacker, move):
			crits += 1
	# Expected ~500, allow range
	assert_gt(crits, 350)
	assert_lt(crits, 650)

func test_critical_move_crit_boost():
	# Move with self_crit_stage_change adds to crit stage
	var attacker = BattleFactory.creature({"crit_stage": 0, "bond_level": 0, "held_item_id": ""})
	var crit_move = MockMove.with_props({"self_crit_stage_change": 2})
	# Effective stage = 0 + 2 = 2 -> 1/4
	var crits = 0
	for i in range(1000):
		seed(i)
		if BattleCalculator.check_critical(attacker, crit_move):
			crits += 1
	# Expected ~250
	assert_gt(crits, 150)
	assert_lt(crits, 400)

func test_critical_precision_grater_boost():
	# Precision Grater (crit_boost effect) adds +1 stage
	var attacker = BattleFactory.creature({"crit_stage": 0, "bond_level": 0, "held_item_id": "precision_grater"})
	var move = MockMove.physical()
	# Stage = 0 + 1 (item) = 1 -> 1/8
	var crits = 0
	for i in range(1000):
		seed(i)
		if BattleCalculator.check_critical(attacker, move):
			crits += 1
	# Expected ~125
	assert_gt(crits, 50)
	assert_lt(crits, 250)

func test_critical_bond_level_boost():
	# Bond level >= 1 adds +1 crit stage
	var attacker = BattleFactory.creature({"crit_stage": 0, "bond_level": 1, "held_item_id": ""})
	var move = MockMove.physical()
	# Stage = 0 + 1 (bond) = 1 -> 1/8
	var crits = 0
	for i in range(1000):
		seed(i)
		if BattleCalculator.check_critical(attacker, move):
			crits += 1
	assert_gt(crits, 50)
	assert_lt(crits, 250)

# --- get_speed ---

func test_speed_base():
	var c = BattleFactory.creature({"speed": 20, "speed_stage": 0, "status": "", "held_item_id": ""})
	assert_eq(BattleCalculator.get_speed(c), 20)

func test_speed_with_stage():
	var c = BattleFactory.creature({"speed": 20, "speed_stage": 2, "status": "", "held_item_id": ""})
	# stage 2 mult = (2+2)/2 = 2.0
	assert_eq(BattleCalculator.get_speed(c), 40)

func test_speed_with_brined():
	var c = BattleFactory.creature({"speed": 20, "speed_stage": 0, "status": "brined", "held_item_id": ""})
	# brined = 0.5x
	assert_eq(BattleCalculator.get_speed(c), 10)

func test_speed_with_bond_boost():
	var c = BattleFactory.creature({"speed": 20, "speed_stage": 0, "status": "", "held_item_id": "", "bond_boost_stat": "speed"})
	# 1.1x
	assert_eq(BattleCalculator.get_speed(c), 22) # int(20 * 1.1)

func test_speed_with_bond_nerf():
	var c = BattleFactory.creature({"speed": 20, "speed_stage": 0, "status": "", "held_item_id": "", "bond_nerf_stat": "speed"})
	assert_eq(BattleCalculator.get_speed(c), 18) # int(20 * 0.9)

func test_speed_with_choice_whisk():
	var c = BattleFactory.creature({"speed": 20, "speed_stage": 0, "status": "", "held_item_id": "choice_whisk"})
	# 1.5x
	assert_eq(BattleCalculator.get_speed(c), 30)

func test_speed_wilted_reduces():
	var c = BattleFactory.creature({"speed": 20, "speed_stage": 0, "status": "wilted", "held_item_id": ""})
	# wilted speed = 0.75x
	assert_eq(BattleCalculator.get_speed(c), 15)

# --- can_act ---

func test_can_act_no_status():
	var c = BattleFactory.creature({"status": ""})
	assert_true(BattleCalculator.can_act(c))

func test_can_act_burned():
	var c = BattleFactory.creature({"status": "burned"})
	assert_true(BattleCalculator.can_act(c)) # burn doesn't prevent acting

func test_frozen_sometimes_thaws():
	var c = BattleFactory.creature({"status": "frozen", "status_turns": 0})
	var acted = 0
	for i in range(200):
		var test_c = c.duplicate()
		seed(i)
		if BattleCalculator.can_act(test_c):
			acted += 1
	# 25% thaw rate
	assert_gt(acted, 20)
	assert_lt(acted, 100)

func test_drowsy_half_skip():
	var c = BattleFactory.creature({"status": "drowsy"})
	var acted = 0
	for i in range(200):
		seed(i)
		if BattleCalculator.can_act(c):
			acted += 1
	# ~50% rate
	assert_gt(acted, 60)
	assert_lt(acted, 140)

func test_brined_quarter_skip():
	var c = BattleFactory.creature({"status": "brined"})
	var acted = 0
	for i in range(200):
		seed(i)
		if BattleCalculator.can_act(c):
			acted += 1
	# ~75% act rate
	assert_gt(acted, 100)
	assert_lt(acted, 190)
