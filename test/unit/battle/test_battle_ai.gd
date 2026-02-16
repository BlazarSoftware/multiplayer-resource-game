extends GutTest

# Tests for BattleAI static methods.
# Requires RegistrySeeder for move/trainer lookups.

func before_each():
	RegistrySeeder.seed_all()
	seed(42)

func after_each():
	RegistrySeeder.clear_all()

# --- Easy AI (random) ---

func test_easy_returns_valid_move():
	var creature_a = BattleFactory.creature({"moves": ["quick_bite", "grain_bash"], "pp": [10, 10]})
	var creature_b = BattleFactory.creature()
	var battle = BattleFactory.battle({
		"side_b_party": [creature_a],
		"side_a_party": [creature_b],
		"trainer_id": "",
	})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_true(move_id in ["quick_bite", "grain_bash"])

func test_easy_skips_zero_pp():
	var creature = BattleFactory.creature({"moves": ["quick_bite", "grain_bash"], "pp": [0, 10]})
	var battle = BattleFactory.battle({"side_b_party": [creature], "trainer_id": ""})
	# Should always pick grain_bash since quick_bite has 0 PP
	for i in range(10):
		seed(i * 3)
		var c_copy = creature.duplicate(true)
		battle["side_b_party"] = [c_copy]
		var move_id = BattleAI.pick_move(battle, "b")
		assert_eq(move_id, "grain_bash")

func test_easy_respects_taunt():
	# Taunted creature can't use status moves
	var creature = BattleFactory.creature({
		"moves": ["status_burn", "quick_bite"],
		"pp": [10, 10],
		"taunt_turns": 2,
	})
	var battle = BattleFactory.battle({"side_b_party": [creature], "trainer_id": ""})
	for i in range(10):
		seed(i * 5)
		var c_copy = creature.duplicate(true)
		battle["side_b_party"] = [c_copy]
		var move_id = BattleAI.pick_move(battle, "b")
		assert_eq(move_id, "quick_bite") # only non-status option

func test_easy_fallback_when_all_pp_zero():
	var creature = BattleFactory.creature({"moves": ["quick_bite"], "pp": [0]})
	var battle = BattleFactory.battle({"side_b_party": [creature], "trainer_id": ""})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "quick_bite") # fallback

# --- Medium AI ---

func test_medium_prefers_super_effective():
	var creature = BattleFactory.creature({
		"moves": ["quick_bite", "sweet_beam"],
		"pp": [10, 10],
		"types": ["sweet"],
	})
	var opponent = BattleFactory.creature({"types": ["sour"]}) # sweet is SE vs sour
	var battle = BattleFactory.battle({
		"side_b_party": [creature],
		"side_a_party": [opponent],
		"trainer_id": "test_medium",
	})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "sweet_beam") # sweet SE vs sour

func test_medium_avoids_immune_moves():
	var creature = BattleFactory.creature({
		"moves": ["sour_spray", "quick_bite"],
		"pp": [10, 10],
		"types": ["sour"],
	})
	var opponent = BattleFactory.creature({"types": ["grain"]}) # sour is immune to grain
	var battle = BattleFactory.battle({
		"side_b_party": [creature],
		"side_a_party": [opponent],
		"trainer_id": "test_medium",
	})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "quick_bite") # avoid immune sour_spray

func test_medium_uses_heal_when_low():
	var creature = BattleFactory.creature({
		"moves": ["quick_bite", "heal_move"],
		"pp": [10, 5],
		"hp": 20,
		"max_hp": 80,
		"types": ["grain"],
	})
	var opponent = BattleFactory.creature({"types": ["grain"]})
	var battle = BattleFactory.battle({
		"side_b_party": [creature],
		"side_a_party": [opponent],
		"trainer_id": "test_medium",
	})
	# hp_ratio = 20/80 = 0.25 < 0.4, should prefer heal
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "heal_move")

# --- Hard AI ---

func test_hard_considers_weather():
	var creature = BattleFactory.creature({
		"moves": ["flame_burst", "sweet_beam"],
		"pp": [10, 10],
		"types": ["spicy"],
	})
	var opponent = BattleFactory.creature({"types": ["grain"]})
	var battle = BattleFactory.battle({
		"side_b_party": [creature],
		"side_a_party": [opponent],
		"weather": "spicy", # boosts spicy 1.5x
		"trainer_id": "test_hard",
	})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "flame_burst") # spicy boosted by weather

func test_hard_priority_for_low_foe():
	var creature = BattleFactory.creature({
		"moves": ["quick_bite", "priority_move"],
		"pp": [10, 10],
		"types": ["spicy"],
	})
	var opponent = BattleFactory.creature({"types": ["grain"], "hp": 5, "max_hp": 80}) # very low
	var battle = BattleFactory.battle({
		"side_b_party": [creature],
		"side_a_party": [opponent],
		"trainer_id": "test_hard",
	})
	# opp_hp_ratio = 5/80 = 0.0625 < 0.25, priority move gets 1.5x bonus
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "priority_move")

func test_hard_knock_off_against_item():
	var creature = BattleFactory.creature({
		"moves": ["quick_bite", "knock_off_move"],
		"pp": [10, 10],
		"types": ["sour"],
	})
	var opponent = BattleFactory.creature({"types": ["spicy"], "held_item_id": "leftovers"}) # sour SE vs spicy
	var battle = BattleFactory.battle({
		"side_b_party": [creature],
		"side_a_party": [opponent],
		"trainer_id": "test_hard",
	})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "knock_off_move") # knock_off gets 1.4x vs item holder

func test_hard_trick_room_when_slower():
	var creature = BattleFactory.creature({
		"moves": ["quick_bite", "trick_room_move"],
		"pp": [10, 5],
		"types": ["sweet"],
		"speed": 5,
	})
	var opponent = BattleFactory.creature({"speed": 30})
	var battle = BattleFactory.battle({
		"side_b_party": [creature],
		"side_a_party": [opponent],
		"trainer_id": "test_hard",
		"trick_room_turns": 0,
	})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "trick_room_move") # slower, wants trick room

# --- Overrides ---

func test_encore_lock_overrides():
	var creature = BattleFactory.creature({
		"moves": ["quick_bite", "grain_bash"],
		"pp": [10, 10],
		"encore_turns": 2,
		"last_move_used": "quick_bite",
	})
	var battle = BattleFactory.battle({"side_b_party": [creature], "trainer_id": ""})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "quick_bite") # locked by encore

func test_choice_lock_overrides():
	var creature = BattleFactory.creature({
		"moves": ["quick_bite", "grain_bash"],
		"pp": [10, 10],
		"choice_locked_move": "grain_bash",
	})
	var battle = BattleFactory.battle({"side_b_party": [creature], "trainer_id": ""})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "grain_bash") # locked by choice item

func test_hard_hazard_early_turn():
	var creature = BattleFactory.creature({
		"moves": ["quick_bite", "hazard_move"],
		"pp": [10, 5],
		"types": ["grain"],
	})
	var opponent = BattleFactory.creature({"types": ["grain"]})
	var battle = BattleFactory.battle({
		"side_b_party": [creature],
		"side_a_party": [opponent],
		"trainer_id": "test_hard",
		"turn": 1,
	})
	var move_id = BattleAI.pick_move(battle, "b")
	assert_eq(move_id, "hazard_move") # early turn = high hazard priority
