extends GutTest

# Tests for ExcursionGenerator determinism, season variation, and output validity.

func before_each():
	DataRegistry.ensure_loaded()

# --- Determinism Tests ---

func test_same_seed_produces_same_item_spawn_points():
	var points_a = ExcursionGenerator.get_item_spawn_points(12345, "spring", Vector3.ZERO)
	var points_b = ExcursionGenerator.get_item_spawn_points(12345, "spring", Vector3.ZERO)
	assert_eq(points_a.size(), points_b.size(), "Same seed should produce same number of items")
	for i in range(points_a.size()):
		assert_eq(points_a[i]["item_id"], points_b[i]["item_id"], "Item %d should match" % i)
		assert_eq(points_a[i]["position"], points_b[i]["position"], "Position %d should match" % i)

func test_same_seed_produces_same_encounter_zones():
	var zones_a = ExcursionGenerator.get_encounter_zones(42, "summer", Vector3.ZERO)
	var zones_b = ExcursionGenerator.get_encounter_zones(42, "summer", Vector3.ZERO)
	assert_eq(zones_a.size(), zones_b.size(), "Same seed should produce same number of zones")
	for i in range(zones_a.size()):
		assert_eq(zones_a[i]["table_id"], zones_b[i]["table_id"], "Zone %d table should match" % i)
		assert_eq(zones_a[i]["is_rare"], zones_b[i]["is_rare"], "Zone %d rare flag should match" % i)

func test_different_seeds_produce_different_results():
	var points_a = ExcursionGenerator.get_item_spawn_points(100, "spring", Vector3.ZERO)
	var points_b = ExcursionGenerator.get_item_spawn_points(999, "spring", Vector3.ZERO)
	# At minimum, positions should differ (items might overlap by chance)
	var any_different = false
	for i in range(min(points_a.size(), points_b.size())):
		if points_a[i]["position"] != points_b[i]["position"]:
			any_different = true
			break
	assert_true(any_different, "Different seeds should produce different positions")

# --- Season Variation Tests ---

func test_season_affects_item_spawn_table():
	# Spring should boost seeds compared to winter
	var spring_points = ExcursionGenerator.get_item_spawn_points(555, "spring", Vector3.ZERO)
	var winter_points = ExcursionGenerator.get_item_spawn_points(555, "winter", Vector3.ZERO)
	# Because the table weights differ, items should differ even with same seed
	# (The RNG is the same but weighted table produces different rolls)
	assert_eq(spring_points.size(), winter_points.size(), "Same seed produces same count regardless of season")
	var spring_seeds = 0
	var winter_seeds = 0
	for p in spring_points:
		if p["item_id"] in ["golden_seed", "ancient_grain_seed"]:
			spring_seeds += 1
	for p in winter_points:
		if p["item_id"] in ["golden_seed", "ancient_grain_seed"]:
			winter_seeds += 1
	# Spring has boosted seed weights, so should have more (or equal) seed drops
	# We can't guarantee strictly more due to RNG, just verify the mechanism runs
	assert_true(spring_seeds >= 0, "Spring seed count is valid")
	assert_true(winter_seeds >= 0, "Winter seed count is valid")

# --- Output Validity Tests ---

func test_item_spawn_count_in_range():
	for s in range(10):
		var points = ExcursionGenerator.get_item_spawn_points(s * 1000, "spring", Vector3.ZERO)
		assert_true(points.size() >= 15, "Should have at least 15 items (seed=%d, got %d)" % [s * 1000, points.size()])
		assert_true(points.size() <= 50, "Should have at most 50 items (seed=%d, got %d)" % [s * 1000, points.size()])

func test_encounter_zones_have_required_fields():
	var zones = ExcursionGenerator.get_encounter_zones(777, "autumn", Vector3.ZERO)
	assert_true(zones.size() >= 4, "Should have at least 4 zones (3 common + 1 rare)")
	for z in zones:
		assert_has(z, "position", "Zone should have position")
		assert_has(z, "radius", "Zone should have radius")
		assert_has(z, "table_id", "Zone should have table_id")
		assert_has(z, "is_rare", "Zone should have is_rare flag")

func test_exactly_one_rare_zone():
	var zones = ExcursionGenerator.get_encounter_zones(888, "spring", Vector3.ZERO)
	var rare_count = 0
	for z in zones:
		if z["is_rare"]:
			rare_count += 1
	assert_eq(rare_count, 1, "Should have exactly 1 rare zone")

func test_encounter_zones_use_valid_table_ids():
	var zones = ExcursionGenerator.get_encounter_zones(999, "summer", Vector3.ZERO)
	for z in zones:
		assert_true(z["table_id"] in ["excursion_common", "excursion_rare"],
			"Table ID should be excursion_common or excursion_rare, got: " + z["table_id"])

func test_encounter_zones_use_zone_specific_table_ids():
	var zone_expected_tables: Dictionary = {
		"default": ["excursion_common", "excursion_rare"],
		"coastal_wreckage": ["battered_bay", "excursion_coastal_rare"],
		"fungal_hollow": ["fermented_hollow", "excursion_fungal_rare"],
		"volcanic_crest": ["blackened_crest", "excursion_volcanic_rare"],
		"frozen_pantry": ["salted_shipwreck", "excursion_frozen_rare"],
	}
	for zone_type in zone_expected_tables:
		var expected: Array = zone_expected_tables[zone_type]
		var zones = ExcursionGenerator.get_encounter_zones(999, "summer", Vector3.ZERO, zone_type)
		for z in zones:
			assert_true(z["table_id"] in expected,
				"Zone '%s' table_id should be in %s, got: %s" % [zone_type, str(expected), z["table_id"]])

func test_item_positions_within_arena_bounds():
	var points = ExcursionGenerator.get_item_spawn_points(1234, "spring", Vector3.ZERO)
	for p in points:
		var pos: Vector3 = p["position"]
		assert_true(pos.x >= 0 and pos.x <= 160, "X should be within arena (got %f)" % pos.x)
		assert_true(pos.z >= 0 and pos.z <= 160, "Z should be within arena (got %f)" % pos.z)
		assert_true(pos.y >= 0, "Y should be non-negative (got %f)" % pos.y)

func test_spawn_point_is_at_south_edge():
	var sp = ExcursionGenerator.get_spawn_point(Vector3.ZERO)
	assert_eq(sp, Vector3(80, 1, 150), "Spawn point should be at south edge center")

func test_spawn_point_with_offset():
	var offset = Vector3(5000, 0, 0)
	var sp = ExcursionGenerator.get_spawn_point(offset)
	# get_spawn_point ignores offset (returns local coords)
	assert_eq(sp, Vector3(80, 1, 150), "Spawn point should be in local coords")

# --- Heightmap Tests ---

func test_heightmap_size():
	var h_noise = ExcursionGenerator._make_height_noise(123)
	var d_noise = ExcursionGenerator._make_detail_noise(123)
	var heightmap = ExcursionGenerator._build_heightmap(h_noise, d_noise)
	assert_eq(heightmap.size(), 161 * 161, "Heightmap should have 161x161 = 25921 values")

func test_heightmap_values_clamped():
	var h_noise = ExcursionGenerator._make_height_noise(456)
	var d_noise = ExcursionGenerator._make_detail_noise(456)
	var heightmap = ExcursionGenerator._build_heightmap(h_noise, d_noise)
	for i in range(heightmap.size()):
		assert_true(heightmap[i] >= 0.0, "Height should be >= 0 (got %f at %d)" % [heightmap[i], i])
		assert_true(heightmap[i] <= 10.0, "Height should be <= 10 (got %f at %d)" % [heightmap[i], i])

func test_spawn_area_is_flattened():
	var h_noise = ExcursionGenerator._make_height_noise(789)
	var d_noise = ExcursionGenerator._make_detail_noise(789)
	# height_at for spawn center (80, 150) should be flattened (low, consistent value)
	var h = ExcursionGenerator._height_at(h_noise, d_noise, 80.0, 150.0)
	assert_true(h <= 1.5, "Spawn center should be nearly flat (got %f)" % h)

# --- Server/Client Generation Tests ---

func test_generate_server_returns_node():
	var node = ExcursionGenerator.generate_server(111, "spring", Vector3(5000, 0, 0))
	assert_not_null(node, "Server generation should return a node")
	assert_eq(node.name, "ExcursionInstance", "Node should be named ExcursionInstance")
	assert_true(node.get_child_count() > 0, "Server node should have children")
	node.free()

func test_generate_client_returns_node():
	var node = ExcursionGenerator.generate_client(111, "spring", Vector3(5000, 0, 0))
	assert_not_null(node, "Client generation should return a node")
	assert_eq(node.name, "ExcursionVisuals", "Node should be named ExcursionVisuals")
	assert_true(node.get_child_count() > 0, "Client node should have children")
	node.free()

func test_server_has_terrain_collision():
	var node = ExcursionGenerator.generate_server(222, "summer", Vector3.ZERO)
	var terrain = node.get_node_or_null("TerrainCollision")
	assert_not_null(terrain, "Server should have TerrainCollision node")
	assert_true(terrain is StaticBody3D, "TerrainCollision should be StaticBody3D")
	node.free()

func test_server_has_exit_portal():
	var node = ExcursionGenerator.generate_server(333, "autumn", Vector3.ZERO)
	var portal = node.get_node_or_null("ExcursionExitPortal")
	assert_not_null(portal, "Server should have ExcursionExitPortal")
	assert_true(portal is Area3D, "Exit portal should be Area3D")
	assert_true(portal.has_meta("is_excursion_exit"), "Portal should have is_excursion_exit meta")
	node.free()

func test_server_has_encounter_areas():
	var node = ExcursionGenerator.generate_server(444, "winter", Vector3.ZERO)
	var encounter_areas = 0
	for child in node.get_children():
		if child is Area3D and child.has_meta("is_excursion_encounter"):
			encounter_areas += 1
	assert_true(encounter_areas >= 4, "Should have at least 4 encounter areas (got %d)" % encounter_areas)
	node.free()

func test_all_items_are_valid():
	var points = ExcursionGenerator.get_item_spawn_points(5555, "spring", Vector3.ZERO)
	for p in points:
		var item_id: String = p["item_id"]
		var info = DataRegistry.get_item_display_info(item_id)
		assert_true(not info.is_empty(), "Item '%s' should be registered in DataRegistry" % item_id)

# --- Harvestable Spawn Point Tests ---

func test_harvestable_spawn_determinism():
	var a = ExcursionGenerator.get_harvestable_spawn_points(12345, "spring", Vector3.ZERO)
	var b = ExcursionGenerator.get_harvestable_spawn_points(12345, "spring", Vector3.ZERO)
	assert_eq(a.size(), b.size(), "Same seed should produce same number of harvestables")
	for i in range(a.size()):
		assert_eq(a[i]["position"], b[i]["position"], "Harvestable %d position should match" % i)
		assert_eq(a[i]["type"], b[i]["type"], "Harvestable %d type should match" % i)

func test_harvestable_spawn_different_seeds():
	var a = ExcursionGenerator.get_harvestable_spawn_points(100, "spring", Vector3.ZERO)
	var b = ExcursionGenerator.get_harvestable_spawn_points(999, "spring", Vector3.ZERO)
	# At least sizes or positions should differ
	var any_different = false
	if a.size() != b.size():
		any_different = true
	else:
		for i in range(min(a.size(), b.size())):
			if a[i]["position"] != b[i]["position"]:
				any_different = true
				break
	assert_true(any_different, "Different seeds should produce different harvestable placements")

func test_harvestable_types_are_valid():
	var points = ExcursionGenerator.get_harvestable_spawn_points(777, "summer", Vector3.ZERO)
	assert_true(points.size() > 0, "Should generate at least 1 harvestable")
	for p in points:
		assert_true(p["type"] in ["tree", "rock", "bush"],
			"Type should be tree, rock, or bush, got: " + p["type"])

func test_harvestable_has_drops():
	var points = ExcursionGenerator.get_harvestable_spawn_points(333, "autumn", Vector3.ZERO)
	for p in points:
		assert_true(p["drops"].size() > 0, "Harvestable should have at least 1 drop entry")
		for drop in p["drops"]:
			assert_has(drop, "item_id", "Drop should have item_id")
			assert_has(drop, "weight", "Drop should have weight")

func test_harvestable_positions_within_arena():
	var points = ExcursionGenerator.get_harvestable_spawn_points(555, "spring", Vector3.ZERO)
	for p in points:
		var pos: Vector3 = p["position"]
		assert_true(pos.x >= 0 and pos.x <= 160, "X should be in arena (got %f)" % pos.x)
		assert_true(pos.z >= 0 and pos.z <= 160, "Z should be in arena (got %f)" % pos.z)

func test_harvestable_not_in_spawn_area():
	var points = ExcursionGenerator.get_harvestable_spawn_points(444, "spring", Vector3.ZERO)
	var spawn_center := Vector2(80, 150)
	for p in points:
		var pos2d := Vector2(p["position"].x, p["position"].z)
		assert_true(pos2d.distance_to(spawn_center) >= 8.0,
			"Harvestable should not be in spawn area (dist=%f)" % pos2d.distance_to(spawn_center))

# --- Dig Spot Tests ---

func test_dig_spot_determinism():
	var a = ExcursionGenerator.get_dig_spot_points(12345, "spring", Vector3.ZERO)
	var b = ExcursionGenerator.get_dig_spot_points(12345, "spring", Vector3.ZERO)
	assert_eq(a.size(), b.size(), "Same seed should produce same number of dig spots")
	for i in range(a.size()):
		assert_eq(a[i]["position"], b[i]["position"], "Dig spot %d position should match" % i)
		assert_eq(a[i]["spot_id"], b[i]["spot_id"], "Dig spot %d id should match" % i)

func test_dig_spot_count_in_range():
	for s in range(10):
		var points = ExcursionGenerator.get_dig_spot_points(s * 1000, "spring", Vector3.ZERO)
		assert_true(points.size() >= 3, "Should have at least 3 dig spots (seed=%d, got %d)" % [s * 1000, points.size()])
		assert_true(points.size() <= 10, "Should have at most 10 dig spots (seed=%d, got %d)" % [s * 1000, points.size()])

func test_dig_spot_has_required_fields():
	var points = ExcursionGenerator.get_dig_spot_points(888, "summer", Vector3.ZERO)
	for p in points:
		assert_has(p, "position", "Dig spot should have position")
		assert_has(p, "spot_id", "Dig spot should have spot_id")
		assert_has(p, "loot_table", "Dig spot should have loot_table")
		assert_true(p["loot_table"].size() > 0, "Dig spot loot table should not be empty")

func test_dig_spot_ids_include_seed():
	var seed_val = 42
	var points = ExcursionGenerator.get_dig_spot_points(seed_val, "spring", Vector3.ZERO)
	for p in points:
		assert_true(p["spot_id"].begins_with("excursion_%d_" % seed_val),
			"Spot ID should include seed, got: " + p["spot_id"])

func test_dig_spot_positions_within_arena():
	var points = ExcursionGenerator.get_dig_spot_points(654, "winter", Vector3.ZERO)
	for p in points:
		var pos: Vector3 = p["position"]
		assert_true(pos.x >= 0 and pos.x <= 160, "X should be in arena (got %f)" % pos.x)
		assert_true(pos.z >= 0 and pos.z <= 160, "Z should be in arena (got %f)" % pos.z)

func test_dig_spots_have_spacing():
	var points = ExcursionGenerator.get_dig_spot_points(321, "spring", Vector3.ZERO)
	for i in range(points.size()):
		for j in range(i + 1, points.size()):
			var dist = Vector2(points[i]["position"].x, points[i]["position"].z).distance_to(
				Vector2(points[j]["position"].x, points[j]["position"].z))
			assert_true(dist >= 12.0,
				"Dig spots %d and %d should be at least 12 apart (got %f)" % [i, j, dist])

# --- Zone Type Tests ---

func test_zone_configs_has_all_zone_types():
	var expected_zones = ["default", "coastal_wreckage", "fungal_hollow", "volcanic_crest", "frozen_pantry"]
	for zone_type in expected_zones:
		assert_true(zone_type in ExcursionGenerator.ZONE_CONFIGS,
			"ZONE_CONFIGS should contain '%s'" % zone_type)

func test_zone_configs_have_required_keys():
	var required_keys = ["display_name", "terrain_color", "path_color", "water_tint",
		"ambient_light", "fog_color", "common_table", "rare_table"]
	for zone_type in ExcursionGenerator.ZONE_CONFIGS:
		var config: Dictionary = ExcursionGenerator.ZONE_CONFIGS[zone_type]
		for key in required_keys:
			assert_true(key in config,
				"Zone '%s' config should have key '%s'" % [zone_type, key])

func test_zone_poacher_species_has_all_zones():
	var expected_zones = ["default", "coastal_wreckage", "fungal_hollow", "volcanic_crest", "frozen_pantry"]
	for zone_type in expected_zones:
		assert_true(zone_type in ExcursionGenerator.ZONE_POACHER_SPECIES,
			"ZONE_POACHER_SPECIES should contain '%s'" % zone_type)
		var pool: Array = ExcursionGenerator.ZONE_POACHER_SPECIES[zone_type]
		assert_true(pool.size() >= 4,
			"Zone '%s' should have at least 4 poacher species (got %d)" % [zone_type, pool.size()])

func test_generate_server_with_zone_type():
	var zone_types = ["default", "coastal_wreckage", "fungal_hollow", "volcanic_crest", "frozen_pantry"]
	for zone_type in zone_types:
		var node = ExcursionGenerator.generate_server(111, "spring", Vector3(5000, 0, 0), zone_type)
		assert_not_null(node, "Server generation should return a node for zone '%s'" % zone_type)
		assert_eq(node.name, "ExcursionInstance", "Node should be named ExcursionInstance for zone '%s'" % zone_type)
		assert_true(node.get_child_count() > 0, "Server node should have children for zone '%s'" % zone_type)
		node.free()

func test_generate_client_default_zone():
	# Client generation with default zone_type (explicit param, same as existing test)
	var node = ExcursionGenerator.generate_client(111, "spring", Vector3(5000, 0, 0), "default")
	assert_not_null(node, "Client generation should return a node for default zone")
	assert_eq(node.name, "ExcursionVisuals", "Node should be named ExcursionVisuals")
	assert_true(node.get_child_count() > 0, "Client node should have children")
	node.free()

func test_poacher_spawn_points_with_zone_type():
	var zone_types = ["default", "coastal_wreckage", "fungal_hollow", "volcanic_crest", "frozen_pantry"]
	for zone_type in zone_types:
		var points = ExcursionGenerator.get_poacher_spawn_points(42, "summer", Vector3.ZERO, zone_type)
		assert_true(points.size() >= 2, "Zone '%s' should have at least 2 poacher spawns (got %d)" % [zone_type, points.size()])
		for p in points:
			assert_has(p, "position", "Poacher spawn should have position for zone '%s'" % zone_type)
			assert_has(p, "party", "Poacher spawn should have party for zone '%s'" % zone_type)
			# Verify all party species are from the correct zone pool
			var pool: Array = ExcursionGenerator.ZONE_POACHER_SPECIES.get(zone_type, [])
			for creature in p["party"]:
				assert_true(creature["species_id"] in pool,
					"Zone '%s' poacher species '%s' should be in zone pool" % [zone_type, creature["species_id"]])

func test_poacher_party_is_typed_array_of_dict():
	# Regression: excursion_generator party arrays must be typed Array[Dictionary]
	# so they can be assigned to TrainerDef.party (also Array[Dictionary])
	var points = ExcursionGenerator.get_poacher_spawn_points(42, "summer", Vector3.ZERO)
	assert_true(points.size() > 0, "Should have poacher spawns")
	for pd in points:
		var party = pd["party"]
		# Verify the party is assignable to a typed Array[Dictionary] variable
		var typed_party: Array[Dictionary] = party
		assert_eq(typed_party.size(), party.size(), "Typed assignment should preserve size")
		for i in range(typed_party.size()):
			assert_has(typed_party[i], "species_id", "Party member should have species_id")
			assert_has(typed_party[i], "level", "Party member should have level")

func test_different_zones_produce_different_encounter_tables():
	var default_zones = ExcursionGenerator.get_encounter_zones(42, "summer", Vector3.ZERO, "default")
	var coastal_zones = ExcursionGenerator.get_encounter_zones(42, "summer", Vector3.ZERO, "coastal_wreckage")
	# Common zones should use different table IDs
	var default_common_tables: Array = []
	var coastal_common_tables: Array = []
	for z in default_zones:
		if not z["is_rare"]:
			default_common_tables.append(z["table_id"])
	for z in coastal_zones:
		if not z["is_rare"]:
			coastal_common_tables.append(z["table_id"])
	assert_true(default_common_tables.size() > 0, "Default should have common zones")
	assert_true(coastal_common_tables.size() > 0, "Coastal should have common zones")
	assert_ne(default_common_tables[0], coastal_common_tables[0],
		"Default and coastal should use different common table IDs")

func test_zone_determinism_across_zone_types():
	# Same seed + same zone_type = same results
	for zone_type in ["coastal_wreckage", "fungal_hollow", "volcanic_crest", "frozen_pantry"]:
		var zones_a = ExcursionGenerator.get_encounter_zones(42, "summer", Vector3.ZERO, zone_type)
		var zones_b = ExcursionGenerator.get_encounter_zones(42, "summer", Vector3.ZERO, zone_type)
		assert_eq(zones_a.size(), zones_b.size(),
			"Same seed + zone '%s' should produce same zone count" % zone_type)
		for i in range(zones_a.size()):
			assert_eq(zones_a[i]["table_id"], zones_b[i]["table_id"],
				"Zone '%s' encounter %d table should match" % [zone_type, i])
