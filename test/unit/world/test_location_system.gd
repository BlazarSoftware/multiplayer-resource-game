extends GutTest

# Tests for location discovery system

func before_each() -> void:
	RegistrySeeder.seed_all()

func after_each() -> void:
	RegistrySeeder.clear_all()

func test_location_def_fields() -> void:
	var loc = DataRegistry.get_location("test_hub")
	assert_not_null(loc, "test_hub should exist in registry")
	assert_eq(loc.location_id, "test_hub")
	assert_eq(loc.display_name, "Test Hub")
	assert_eq(loc.world_position, Vector3(0, 0, 0))
	assert_eq(loc.discovery_radius, 10.0)
	assert_eq(loc.category, "zone")

func test_discovery_within_radius() -> void:
	var loc = DataRegistry.get_location("test_hub")
	var player_pos = Vector3(5, 0, 0)
	var dist = player_pos.distance_to(loc.world_position)
	assert_true(dist <= loc.discovery_radius, "Player at (5,0,0) should be within 10.0 radius of (0,0,0)")

func test_discovery_outside_radius() -> void:
	var loc = DataRegistry.get_location("test_hub")
	var player_pos = Vector3(15, 0, 0)
	var dist = player_pos.distance_to(loc.world_position)
	assert_true(dist > loc.discovery_radius, "Player at (15,0,0) should be outside 10.0 radius of (0,0,0)")

func test_no_duplicate_discovery() -> void:
	var discovered: Array = ["test_hub"]
	var loc = DataRegistry.get_location("test_hub")
	# Simulate discovery check — should not add duplicate
	if loc.location_id not in discovered:
		discovered.append(loc.location_id)
	assert_eq(discovered.size(), 1, "Should not add duplicate location_id")

func test_discovery_skipped_in_restaurant() -> void:
	# Simulate restaurant location dict
	var player_location: Dictionary = {2: {"zone": "restaurant", "owner": "TestPlayer"}}
	var loc = player_location.get(2, {})
	var zone = loc.get("zone", "overworld")
	assert_eq(zone, "restaurant", "Player should be in restaurant zone")
	assert_true(zone != "overworld", "Should skip discovery when not in overworld")

func test_backfill_empty_array() -> void:
	var data: Dictionary = {"player_name": "Test"}
	if not data.has("discovered_locations"):
		data["discovered_locations"] = []
	assert_true(data.has("discovered_locations"))
	assert_eq(data["discovered_locations"].size(), 0)

func test_backfill_preserves_existing() -> void:
	var data: Dictionary = {
		"player_name": "Test",
		"discovered_locations": ["spawn_hub", "farm_zone"]
	}
	if not data.has("discovered_locations"):
		data["discovered_locations"] = []
	assert_eq(data["discovered_locations"].size(), 2)
	assert_true("spawn_hub" in data["discovered_locations"])
	assert_true("farm_zone" in data["discovered_locations"])

func test_multiple_locations_single_check() -> void:
	# Player at (0,0,0) should be near test_hub (radius 10) but not test_shop (at 20,0,0, radius 5)
	var player_pos = Vector3(0, 0, 0)
	var discovered: Array = []

	for loc_id in DataRegistry.locations:
		var loc = DataRegistry.locations[loc_id]
		var dist = player_pos.distance_to(loc.world_position)
		if dist <= loc.discovery_radius and loc.location_id not in discovered:
			discovered.append(loc.location_id)

	assert_true("test_hub" in discovered, "Should discover test_hub (within radius)")
	assert_false("test_shop" in discovered, "Should NOT discover test_shop (too far)")
	assert_false("test_wild" in discovered, "Should NOT discover test_wild (too far)")

func test_player_data_discovered_locations() -> void:
	# Test that PlayerData correctly stores and retrieves discovered locations
	PlayerData.discovered_locations.clear()
	assert_eq(PlayerData.discovered_locations.size(), 0)

	PlayerData.discovered_locations.append("test_hub")
	assert_eq(PlayerData.discovered_locations.size(), 1)
	assert_true("test_hub" in PlayerData.discovered_locations)

func test_player_data_compass_target() -> void:
	PlayerData.compass_target_id = ""
	PlayerData.set_compass_target("test_hub")
	assert_eq(PlayerData.compass_target_id, "test_hub")
	PlayerData.set_compass_target("")
	assert_eq(PlayerData.compass_target_id, "")

func test_player_data_to_dict_includes_discovered() -> void:
	PlayerData.discovered_locations = ["test_hub", "test_shop"]
	var d = PlayerData.to_dict()
	assert_true(d.has("discovered_locations"))
	assert_eq(d["discovered_locations"].size(), 2)
	assert_true("test_hub" in d["discovered_locations"])

func test_player_data_load_from_server_discovered() -> void:
	var data = {
		"player_name": "Test",
		"discovered_locations": ["spawn_hub", "farm_zone", "kitchen"],
	}
	PlayerData.load_from_server(data)
	assert_eq(PlayerData.discovered_locations.size(), 3)
	assert_true("spawn_hub" in PlayerData.discovered_locations)
	assert_true("kitchen" in PlayerData.discovered_locations)

func test_player_data_reset_clears_discovered() -> void:
	PlayerData.discovered_locations = ["test_hub"]
	PlayerData.compass_target_id = "test_hub"
	PlayerData.reset()
	assert_eq(PlayerData.discovered_locations.size(), 0)
	assert_eq(PlayerData.compass_target_id, "")

func test_all_seven_categories_in_registry() -> void:
	var expected_categories = ["zone", "wild_zone", "crafting", "shop", "trainer", "social_npc", "landmark"]
	var found_categories: Array = []
	for loc_id in DataRegistry.locations:
		var loc = DataRegistry.locations[loc_id]
		if loc.category not in found_categories:
			found_categories.append(loc.category)
	for cat in expected_categories:
		assert_true(cat in found_categories, "Category '%s' should be present in test locations" % cat)

func test_category_to_location_mapping() -> void:
	var category_map: Dictionary = {
		"zone": "test_hub",
		"shop": "test_shop",
		"wild_zone": "test_wild",
		"crafting": "test_crafting",
		"trainer": "test_trainer",
		"social_npc": "test_social_npc",
		"landmark": "test_landmark",
	}
	for cat in category_map:
		var loc_id: String = category_map[cat]
		var loc = DataRegistry.get_location(loc_id)
		assert_not_null(loc, "Location '%s' should exist" % loc_id)
		assert_eq(loc.category, cat, "Location '%s' should have category '%s'" % [loc_id, cat])

func test_undiscovered_locations_not_clickable() -> void:
	# Simulates the click filter: only discovered locations should be targetable
	PlayerData.discovered_locations = ["test_hub"]
	var targetable: Array = []
	for loc_id in DataRegistry.locations:
		if loc_id in PlayerData.discovered_locations:
			targetable.append(loc_id)
	assert_true("test_hub" in targetable)
	assert_false("test_wild" in targetable)
	assert_false("test_crafting" in targetable)

func test_undiscovered_locations_visible_on_map() -> void:
	# All locations should be iterated (no discovery filter), unlike click targeting
	PlayerData.discovered_locations = ["test_hub"]
	var visible_on_map: Array = []
	var discovered_on_map: Array = []
	for loc_id in DataRegistry.locations:
		visible_on_map.append(loc_id)
		if loc_id in PlayerData.discovered_locations:
			discovered_on_map.append(loc_id)
	assert_eq(visible_on_map.size(), DataRegistry.locations.size(), "All locations should be visible on map")
	assert_eq(discovered_on_map.size(), 1, "Only one location should be discovered")
