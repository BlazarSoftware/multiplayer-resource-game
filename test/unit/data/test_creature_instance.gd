extends GutTest

# Tests for CreatureInstance pure methods (no DataRegistry dependency)

# --- compute_bond_level ---

func test_bond_level_zero_points():
	assert_eq(CreatureInstance.compute_bond_level(0), 0)

func test_bond_level_just_below_one():
	assert_eq(CreatureInstance.compute_bond_level(49), 0)

func test_bond_level_at_fifty():
	assert_eq(CreatureInstance.compute_bond_level(50), 1)

func test_bond_level_at_150():
	assert_eq(CreatureInstance.compute_bond_level(150), 2)

func test_bond_level_at_300():
	assert_eq(CreatureInstance.compute_bond_level(300), 3)

func test_bond_level_at_500():
	assert_eq(CreatureInstance.compute_bond_level(500), 4)

func test_bond_level_high_points():
	assert_eq(CreatureInstance.compute_bond_level(9999), 4)

# --- _calc_xp_to_next ---

func test_xp_level_one():
	# 10*1*1 + 40*1 + 50 = 100
	assert_eq(CreatureInstance._calc_xp_to_next(1), 100)

func test_xp_level_five():
	# 10*25 + 40*5 + 50 = 250 + 200 + 50 = 500
	assert_eq(CreatureInstance._calc_xp_to_next(5), 500)

func test_xp_level_ten():
	# 10*100 + 40*10 + 50 = 1000 + 400 + 50 = 1450
	assert_eq(CreatureInstance._calc_xp_to_next(10), 1450)

# --- to_dict / from_dict round-trip ---

func test_round_trip_basic():
	var inst = CreatureInstance.new()
	inst.species_id = "rice_ball"
	inst.nickname = "Ricey"
	inst.level = 5
	inst.hp = 42
	inst.max_hp = 45
	inst.attack = 12
	inst.defense = 10
	inst.sp_attack = 8
	inst.sp_defense = 9
	inst.speed = 11
	inst.moves = PackedStringArray(["grain_bash", "quick_bite"])
	inst.pp = PackedInt32Array([10, 15])
	inst.types = PackedStringArray(["grain"])
	inst.xp = 50
	inst.xp_to_next = 500
	inst.ability_id = "starter_culture"
	inst.held_item_id = ""
	inst.ivs = {"hp": 15, "attack": 20, "defense": 10, "sp_attack": 5, "sp_defense": 25, "speed": 18}
	inst.bond_points = 200
	inst.bond_level = 2

	var d = inst.to_dict()
	var restored = CreatureInstance.from_dict(d)

	assert_eq(restored.species_id, "rice_ball")
	assert_eq(restored.nickname, "Ricey")
	assert_eq(restored.level, 5)
	assert_eq(restored.hp, 42)
	assert_eq(restored.max_hp, 45)
	assert_eq(restored.attack, 12)
	assert_eq(restored.speed, 11)
	assert_eq(Array(restored.moves), ["grain_bash", "quick_bite"])
	assert_eq(Array(restored.types), ["grain"])
	assert_eq(restored.xp, 50)
	assert_eq(restored.ability_id, "starter_culture")
	assert_eq(restored.bond_points, 200)
	assert_eq(restored.bond_level, 2)
	assert_eq(restored.ivs["hp"], 15)

func test_from_dict_defaults_for_missing_fields():
	var d = {"species_id": "test", "level": 3}
	var inst = CreatureInstance.from_dict(d)
	assert_eq(inst.species_id, "test")
	assert_eq(inst.level, 3)
	assert_eq(inst.attack, 10) # default
	assert_eq(inst.held_item_id, "")
	assert_eq(inst.bond_points, 0)

func test_from_dict_backfills_empty_ivs():
	seed(99)
	var d = {"species_id": "test", "level": 5, "ivs": {}}
	var inst = CreatureInstance.from_dict(d)
	# Should have all 6 IV stats filled
	for stat in CreatureInstance.IV_STATS:
		assert_true(inst.ivs.has(stat), "Missing IV: %s" % stat)
		assert_gte(inst.ivs[stat], 0)
		assert_lte(inst.ivs[stat], 31)

func test_from_dict_bond_level_computed_from_points():
	var d = {"bond_points": 300}
	var inst = CreatureInstance.from_dict(d)
	assert_eq(inst.bond_level, 3) # 300 >= threshold[3]

func test_from_dict_preserves_existing_ivs():
	var ivs = {"hp": 5, "attack": 10, "defense": 15, "sp_attack": 20, "sp_defense": 25, "speed": 30}
	var d = {"ivs": ivs}
	var inst = CreatureInstance.from_dict(d)
	assert_eq(inst.ivs["hp"], 5)
	assert_eq(inst.ivs["speed"], 30)
