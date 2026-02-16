extends GutTest

# Tests for BattleItemDef resource class and DataRegistry integration

func before_each() -> void:
	RegistrySeeder.seed_all()
	_seed_battle_items()

func after_each() -> void:
	RegistrySeeder.clear_all()

func _seed_battle_items() -> void:
	var item = BattleItemDef.new()
	item.item_id = "test_heal"
	item.display_name = "Test Heal"
	item.description = "A test healing item"
	item.icon_color = Color.GREEN
	item.effect_type = "heal_hp"
	item.effect_value = 30
	item.target = "single"
	item.sell_price = 15
	DataRegistry.battle_items["test_heal"] = item

	var item2 = BattleItemDef.new()
	item2.item_id = "test_revive"
	item2.display_name = "Test Revive"
	item2.description = "A test revive item"
	item2.icon_color = Color.YELLOW
	item2.effect_type = "revive"
	item2.effect_value = 50
	item2.target = "single"
	item2.sell_price = 0
	DataRegistry.battle_items["test_revive"] = item2

func test_battle_item_def_creation() -> void:
	var item = BattleItemDef.new()
	item.item_id = "new_item"
	item.display_name = "New Item"
	item.effect_type = "heal_hp"
	item.effect_value = 10
	assert_eq(item.item_id, "new_item")
	assert_eq(item.effect_type, "heal_hp")
	assert_eq(item.effect_value, 10)

func test_battle_item_registry_get() -> void:
	var item = DataRegistry.get_battle_item("test_heal")
	assert_not_null(item)
	assert_eq(item.display_name, "Test Heal")
	assert_eq(item.effect_type, "heal_hp")
	assert_eq(item.effect_value, 30)

func test_battle_item_registry_get_nonexistent() -> void:
	var item = DataRegistry.get_battle_item("does_not_exist")
	assert_null(item)

func test_battle_item_target_field() -> void:
	var item = DataRegistry.get_battle_item("test_heal")
	assert_eq(item.target, "single")

func test_battle_item_sell_price() -> void:
	var item = DataRegistry.get_battle_item("test_heal")
	assert_eq(item.sell_price, 15)

func test_battle_item_icon_color() -> void:
	var item = DataRegistry.get_battle_item("test_heal")
	assert_eq(item.icon_color, Color.GREEN)

func test_battle_item_default_values() -> void:
	var item = BattleItemDef.new()
	assert_eq(item.item_id, "")
	assert_eq(item.display_name, "")
	assert_eq(item.effect_type, "")
	assert_eq(item.effect_value, 0)
	assert_eq(item.target, "single")
	assert_eq(item.sell_price, 0)
