extends GutTest

func before_each() -> void:
	RegistrySeeder.seed_all()
	PlayerData.reset()

func after_each() -> void:
	RegistrySeeder.clear_all()

func test_default_hotbar_init() -> void:
	PlayerData._init_hotbar()
	assert_eq(PlayerData.hotbar.size(), PlayerData.HOTBAR_SIZE, "Hotbar should have 8 slots")
	# All 8 slots should be empty
	for i in range(8):
		assert_true(PlayerData.hotbar[i].is_empty(), "Slot %d should be empty" % i)

func test_hotbar_size_constant() -> void:
	assert_eq(PlayerData.HOTBAR_SIZE, 8, "HOTBAR_SIZE should be 8")

func test_select_empty_slot_gives_hands() -> void:
	PlayerData._init_hotbar()
	PlayerData.select_hotbar_slot(0)
	assert_eq(PlayerData.selected_hotbar_slot, 0)
	assert_eq(PlayerData.current_tool_slot, "", "Empty slot should map to hands (empty string)")

func test_select_hotbar_slot_tool() -> void:
	PlayerData._init_hotbar()
	PlayerData.assign_hotbar_slot(0, "hoe", "tool_slot")
	PlayerData.select_hotbar_slot(0)
	assert_eq(PlayerData.selected_hotbar_slot, 0)
	assert_eq(PlayerData.current_tool_slot, "hoe")

func test_select_hotbar_slot_seeds() -> void:
	PlayerData._init_hotbar()
	PlayerData.assign_hotbar_slot(2, "tomato_seed", "seed")
	PlayerData.select_hotbar_slot(2)
	assert_eq(PlayerData.selected_hotbar_slot, 2)
	assert_eq(PlayerData.current_tool_slot, "seeds")

func test_assign_hotbar_slot() -> void:
	PlayerData._init_hotbar()
	PlayerData.assign_hotbar_slot(5, "herb_poultice", "food")
	assert_eq(PlayerData.hotbar[5].get("item_id", ""), "herb_poultice")
	assert_eq(PlayerData.hotbar[5].get("item_type", ""), "food")

func test_clear_hotbar_slot() -> void:
	PlayerData._init_hotbar()
	PlayerData.assign_hotbar_slot(5, "herb_poultice", "food")
	PlayerData.clear_hotbar_slot(5)
	assert_true(PlayerData.hotbar[5].is_empty(), "Cleared slot should be empty")

func test_hotbar_save_load_roundtrip() -> void:
	PlayerData._init_hotbar()
	PlayerData.assign_hotbar_slot(3, "test_food", "food")
	var saved = PlayerData.to_dict()
	assert_true(saved.has("hotbar"), "Save data should include hotbar")
	assert_eq(saved["hotbar"].size(), PlayerData.HOTBAR_SIZE)
	# Simulate load
	PlayerData.reset()
	PlayerData.load_from_server(saved)
	assert_eq(PlayerData.hotbar.size(), PlayerData.HOTBAR_SIZE)
	assert_eq(PlayerData.hotbar[3].get("item_id", ""), "test_food")

func test_hotbar_migration_from_empty() -> void:
	# Simulate old save with no hotbar data
	var data = PlayerData.to_dict()
	data.erase("hotbar")
	PlayerData.reset()
	PlayerData.load_from_server(data)
	assert_eq(PlayerData.hotbar.size(), PlayerData.HOTBAR_SIZE, "Should auto-init hotbar")
	# All slots should be empty after migration
	for i in range(PlayerData.HOTBAR_SIZE):
		assert_true(PlayerData.hotbar[i].is_empty(), "Slot %d should be empty after migration" % i)

func test_select_out_of_bounds() -> void:
	PlayerData._init_hotbar()
	PlayerData.select_hotbar_slot(99)
	# Should be unchanged (still 0 from reset)
	assert_eq(PlayerData.selected_hotbar_slot, 0)
	PlayerData.select_hotbar_slot(-1)
	assert_eq(PlayerData.selected_hotbar_slot, 0)

func test_assign_all_slot_types() -> void:
	PlayerData._init_hotbar()
	PlayerData.assign_hotbar_slot(0, "hoe", "tool_slot")
	PlayerData.assign_hotbar_slot(1, "axe", "tool_slot")
	PlayerData.assign_hotbar_slot(2, "watering_can", "tool_slot")
	PlayerData.assign_hotbar_slot(3, "shovel", "tool_slot")
	PlayerData.assign_hotbar_slot(4, "tomato_seed", "seed")
	PlayerData.assign_hotbar_slot(5, "herb_poultice", "food")
	PlayerData.assign_hotbar_slot(6, "revive_herb", "battle_item")
	# Slot 7 stays empty
	assert_eq(PlayerData.hotbar[0].get("item_id", ""), "hoe")
	assert_eq(PlayerData.hotbar[4].get("item_type", ""), "seed")
	assert_eq(PlayerData.hotbar[6].get("item_type", ""), "battle_item")
	assert_true(PlayerData.hotbar[7].is_empty())

func test_hotbar_migration_from_old_10_slots() -> void:
	# Simulate old save with 10 slots (old format)
	var data = PlayerData.to_dict()
	data["hotbar"] = [
		{},
		{"item_id": "hoe", "item_type": "tool_slot"},
		{"item_id": "axe", "item_type": "tool_slot"},
		{"item_id": "watering_can", "item_type": "tool_slot"},
		{"item_id": "seeds", "item_type": "seed"},
		{"item_id": "shovel", "item_type": "tool_slot"},
		{}, {}, {}, {},
	]
	PlayerData.reset()
	PlayerData.load_from_server(data)
	# Should reinitialize to 8 empty slots since size doesn't match
	assert_eq(PlayerData.hotbar.size(), PlayerData.HOTBAR_SIZE, "Should resize to 8 slots")
