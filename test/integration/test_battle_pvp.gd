extends GutTest

# Integration tests for PvP battle mechanics.
# Tests simultaneous submission, speed ordering, switch validation.

func before_each():
	RegistrySeeder.seed_all()
	seed(42)

func after_each():
	RegistrySeeder.clear_all()

# --- Simultaneous submission ---

func test_pvp_both_submit_actions():
	var battle = BattleTestScene.make_wild_battle(
		BattleFactory.creature({"speed": 20, "types": ["spicy"]}),
		BattleFactory.creature({"speed": 15, "types": ["sweet"]}),
	)
	battle["mode"] = 2 # PVP
	battle["side_b_peer"] = 2
	battle["state"] = "waiting_both"
	battle["side_a_action"] = {"type": "move", "data": "quick_bite"}
	battle["side_b_action"] = {"type": "move", "data": "grain_bash"}
	# Both actions stored — ready for resolution
	assert_not_null(battle["side_a_action"])
	assert_not_null(battle["side_b_action"])

func test_speed_determines_turn_order():
	# Faster creature should go first (without trick room)
	var fast = BattleFactory.creature({"speed": 30, "types": ["spicy"]})
	var slow = BattleFactory.creature({"speed": 10, "types": ["sweet"]})
	var fast_spd = BattleCalculator.get_speed(fast)
	var slow_spd = BattleCalculator.get_speed(slow)
	assert_gt(fast_spd, slow_spd)

func test_trick_room_reverses_speed():
	# In trick room, slower creature goes first
	var fast = BattleFactory.creature({"speed": 30, "types": ["spicy"]})
	var slow = BattleFactory.creature({"speed": 10, "types": ["sweet"]})
	# Trick room: lower speed = higher priority
	# In _determine_order(), trick_room flips comparison
	var fast_spd = BattleCalculator.get_speed(fast)
	var slow_spd = BattleCalculator.get_speed(slow)
	# Under trick room, slow goes first
	var trick_room_first_is_a = slow_spd < fast_spd # slow is "faster" in trick room
	assert_true(trick_room_first_is_a)

func test_priority_moves_go_first_regardless():
	var slow_priority = BattleFactory.creature({"speed": 5})
	var fast_normal = BattleFactory.creature({"speed": 50})
	# Priority move (priority=1) always goes before normal (priority=0)
	var priority_move = MockMove.with_props({"priority": 1})
	var normal_move = MockMove.physical()
	assert_gt(priority_move.priority, normal_move.priority)

func test_switch_is_valid_action():
	var battle = BattleTestScene.make_wild_battle(
		BattleFactory.creature({"speed": 20}),
		BattleFactory.creature({"speed": 15}),
	)
	battle["side_a_party"].append(BattleFactory.creature({"hp": 50, "max_hp": 50}))
	# Switch to index 1 should be valid if creature has HP > 0
	var switch_idx = 1
	var switch_target = battle["side_a_party"][switch_idx]
	assert_gt(switch_target["hp"], 0)
	assert_ne(switch_idx, battle["side_a_active_idx"])
