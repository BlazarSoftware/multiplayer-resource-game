extends GutTest

# Tests for excursion loot sharing logic.
# Tests the data-level sharing rules without requiring full multiplayer context.

var mgr: Node

func before_each():
	DataRegistry.ensure_loaded()
	var script = load("res://scripts/world/excursion_manager.gd")
	mgr = Node.new()
	mgr.set_script(script)

func after_each():
	if mgr:
		mgr.free()

# --- Loot Distribution Tests ---

func test_loot_log_tracks_per_peer():
	var instance_id := "loot-test-1"
	mgr.excursion_instances[instance_id] = {
		"instance_id": instance_id,
		"loot_log": {},
	}
	mgr._log_loot(instance_id, 10, "golden_seed", 1)
	mgr._log_loot(instance_id, 11, "golden_seed", 1)
	mgr._log_loot(instance_id, 10, "wild_honey", 2)

	var log: Dictionary = mgr.excursion_instances[instance_id]["loot_log"]
	assert_eq(log["10"]["golden_seed"], 1)
	assert_eq(log["10"]["wild_honey"], 2)
	assert_eq(log["11"]["golden_seed"], 1)
	assert_false("wild_honey" in log.get("11", {}), "Peer 11 should not have wild_honey")

func test_loot_log_accumulates_same_item():
	var instance_id := "loot-test-2"
	mgr.excursion_instances[instance_id] = {
		"instance_id": instance_id,
		"loot_log": {},
	}
	mgr._log_loot(instance_id, 5, "truffle_shaving", 1)
	mgr._log_loot(instance_id, 5, "truffle_shaving", 3)
	mgr._log_loot(instance_id, 5, "truffle_shaving", 2)

	var log: Dictionary = mgr.excursion_instances[instance_id]["loot_log"]
	assert_eq(log["5"]["truffle_shaving"], 6, "Should accumulate to 6")

func test_late_joiner_not_in_initial_members():
	# Simulate: instance created with members [10, 11]
	# Late joiner (peer 12) joins later
	var instance_id := "late-join-test"
	mgr.excursion_instances[instance_id] = {
		"instance_id": instance_id,
		"party_id": 1,
		"members": [10, 11], # Only initial members
		"allowed_player_ids": ["player_a", "player_b"],
		"loot_log": {},
	}
	mgr.player_excursion_map[10] = instance_id
	mgr.player_excursion_map[11] = instance_id

	# When loot is distributed to inst["members"], peer 12 is NOT included
	var members = mgr.get_instance_members(instance_id)
	assert_eq(members.size(), 2)
	assert_false(12 in members, "Late joiner should not be in members before joining")

func test_late_joiner_in_members_after_join():
	var instance_id := "late-join-test-2"
	mgr.excursion_instances[instance_id] = {
		"instance_id": instance_id,
		"party_id": 1,
		"members": [10, 11],
		"allowed_player_ids": ["player_a", "player_b", "player_c"],
		"loot_log": {},
	}

	# Simulate late join by adding to members
	mgr.excursion_instances[instance_id]["members"].append(12)
	mgr.player_excursion_map[12] = instance_id

	var members = mgr.get_instance_members(instance_id)
	assert_eq(members.size(), 3)
	assert_true(12 in members, "Late joiner should be in members after joining")

func test_loot_not_logged_for_nonexistent_instance():
	# Should not crash when logging to nonexistent instance
	mgr._log_loot("nonexistent", 10, "herb_basil", 1)
	assert_true(mgr.excursion_instances.is_empty(), "No instance should be created")

func test_empty_loot_log_on_new_instance():
	var instance_id := "fresh-instance"
	mgr.excursion_instances[instance_id] = {
		"instance_id": instance_id,
		"loot_log": {},
	}
	var log: Dictionary = mgr.excursion_instances[instance_id]["loot_log"]
	assert_true(log.is_empty(), "New instance should have empty loot log")

# --- Excursion Bonus Drops ---

func test_bonus_ingredients_are_excursion_exclusive():
	for item_id in mgr.EXCURSION_BONUS_INGREDIENTS:
		var info = DataRegistry.get_item_display_info(item_id)
		assert_true(not info.is_empty(), "Bonus ingredient '%s' should exist in DataRegistry" % item_id)

func test_bonus_seeds_are_excursion_exclusive():
	for item_id in mgr.EXCURSION_BONUS_SEEDS:
		var info = DataRegistry.get_item_display_info(item_id)
		assert_true(not info.is_empty(), "Bonus seed '%s' should exist in DataRegistry" % item_id)

func test_bonus_drop_chances_reasonable():
	assert_true(mgr.EXCURSION_INGREDIENT_DROP_CHANCE > 0.0, "Ingredient drop chance should be positive")
	assert_true(mgr.EXCURSION_INGREDIENT_DROP_CHANCE < 1.0, "Ingredient drop chance should be < 100%")
	assert_true(mgr.EXCURSION_SEED_DROP_CHANCE > 0.0, "Seed drop chance should be positive")
	assert_true(mgr.EXCURSION_SEED_DROP_CHANCE < mgr.EXCURSION_INGREDIENT_DROP_CHANCE,
		"Seed drops should be rarer than ingredient drops")

# --- Shared Harvest Loot Tests ---

func test_harvest_loot_logged_for_all_members():
	var instance_id := "harvest-test-1"
	mgr.excursion_instances[instance_id] = {
		"instance_id": instance_id,
		"members": [10, 11, 12],
		"loot_log": {},
	}
	mgr.player_excursion_map[10] = instance_id
	mgr.player_excursion_map[11] = instance_id
	mgr.player_excursion_map[12] = instance_id

	# Simulate what _on_excursion_harvest does to the loot log
	var drops := {"wood": 2, "herb_basil": 1}
	for member_peer in mgr.excursion_instances[instance_id]["members"]:
		for item_id in drops:
			mgr._log_loot(instance_id, member_peer, item_id, drops[item_id])

	var log: Dictionary = mgr.excursion_instances[instance_id]["loot_log"]
	# All 3 members should have the same drops logged
	for peer_str in ["10", "11", "12"]:
		assert_eq(log[peer_str]["wood"], 2, "Peer %s should have 2 wood" % peer_str)
		assert_eq(log[peer_str]["herb_basil"], 1, "Peer %s should have 1 herb_basil" % peer_str)

func test_dig_loot_logged_for_all_members():
	var instance_id := "dig-test-1"
	mgr.excursion_instances[instance_id] = {
		"instance_id": instance_id,
		"members": [20, 21],
		"loot_log": {},
	}
	mgr.player_excursion_map[20] = instance_id
	mgr.player_excursion_map[21] = instance_id

	var items := {"golden_seed": 1, "stone": 2}
	for member_peer in mgr.excursion_instances[instance_id]["members"]:
		for item_id in items:
			mgr._log_loot(instance_id, member_peer, item_id, items[item_id])

	var log: Dictionary = mgr.excursion_instances[instance_id]["loot_log"]
	assert_eq(log["20"]["golden_seed"], 1)
	assert_eq(log["20"]["stone"], 2)
	assert_eq(log["21"]["golden_seed"], 1)
	assert_eq(log["21"]["stone"], 2)

func test_is_player_in_excursion():
	var instance_id := "check-test"
	mgr.player_excursion_map[50] = instance_id
	assert_true(mgr.is_player_in_excursion(50), "Peer 50 should be in excursion")
	assert_false(mgr.is_player_in_excursion(99), "Peer 99 should not be in excursion")

func test_harvestable_drop_tables_non_empty():
	for h_type in ["tree", "rock", "bush"]:
		var drops = ExcursionGenerator._get_harvestable_drops(h_type, "spring")
		assert_true(drops.size() > 0, "%s should have drops" % h_type)
		for d in drops:
			assert_has(d, "item_id", "Drop should have item_id")
			assert_true(float(d["weight"]) > 0.0, "Drop weight should be positive")

func test_dig_spot_loot_table_non_empty():
	var table = ExcursionGenerator._get_dig_spot_loot_table()
	assert_true(table.size() > 0, "Dig spot loot table should not be empty")
	for entry in table:
		assert_has(entry, "item_id", "Entry should have item_id")
		assert_has(entry, "weight", "Entry should have weight")
		assert_has(entry, "min", "Entry should have min")
		assert_has(entry, "max", "Entry should have max")
