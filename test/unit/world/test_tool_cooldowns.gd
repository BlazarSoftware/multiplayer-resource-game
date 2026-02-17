extends GutTest

# Tests for the server-side tool cooldown system in NetworkManager.

var _peer_id: int = 100

func before_each() -> void:
	RegistrySeeder.seed_all()
	NetworkManager.player_data_store[_peer_id] = {
		"equipped_tools": {
			"hoe": "tool_hoe_basic",
			"axe": "tool_axe_basic",
			"watering_can": "tool_watering_can_basic",
			"shovel": "tool_shovel_basic",
		},
	}
	NetworkManager.tool_cooldowns.clear()

func after_each() -> void:
	RegistrySeeder.clear_all()
	NetworkManager.player_data_store.erase(_peer_id)
	NetworkManager.tool_cooldowns.clear()

func test_first_action_always_allowed() -> void:
	var result = NetworkManager.check_tool_cooldown(_peer_id, "farm_till", "hoe")
	assert_true(result, "First action should be allowed")

func test_rapid_action_blocked() -> void:
	# First action should pass
	var first = NetworkManager.check_tool_cooldown(_peer_id, "farm_till", "hoe")
	assert_true(first, "First action should pass")
	# Immediate second action should fail (800ms cd for basic hoe)
	var second = NetworkManager.check_tool_cooldown(_peer_id, "farm_till", "hoe")
	assert_false(second, "Rapid action should be blocked")

func test_independent_action_types() -> void:
	# Till cooldown
	NetworkManager.check_tool_cooldown(_peer_id, "farm_till", "hoe")
	# Different action type should still work
	var chop_result = NetworkManager.check_tool_cooldown(_peer_id, "chop", "axe")
	assert_true(chop_result, "Different action type should be independent")

func test_speed_mult_reduces_cooldown() -> void:
	# Use gold hoe (speed_mult = 2.0)
	NetworkManager.player_data_store[_peer_id]["equipped_tools"]["hoe"] = "tool_hoe_gold"
	var first = NetworkManager.check_tool_cooldown(_peer_id, "farm_till", "hoe")
	assert_true(first, "First action with gold hoe should pass")
	# Gold hoe: 0.8s / 2.0 = 0.4s cooldown
	# Remaining should be less than 800 (base)
	var remaining = NetworkManager.get_remaining_cooldown_ms(_peer_id, "farm_till", "hoe")
	assert_lt(remaining, 500, "Gold hoe cooldown should be under 500ms")

func test_remaining_cooldown_zero_when_no_action() -> void:
	var remaining = NetworkManager.get_remaining_cooldown_ms(_peer_id, "farm_till", "hoe")
	assert_eq(remaining, 0, "No prior action should mean 0 remaining")

func test_unknown_action_has_no_cooldown() -> void:
	var result = NetworkManager.check_tool_cooldown(_peer_id, "unknown_action", "hoe")
	assert_true(result, "Unknown action type should always pass (no base cd)")
