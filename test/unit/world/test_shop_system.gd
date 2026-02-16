extends GutTest

# Tests for shop system: DataRegistry.get_sell_price(), shop catalog, buy/sell logic
# Uses RegistrySeeder — NO preload

func before_each() -> void:
	RegistrySeeder.seed_all()
	_seed_shops()
	_seed_sellable_items()

func after_each() -> void:
	RegistrySeeder.clear_all()

func _seed_shops() -> void:
	var shop = ShopDef.new()
	shop.shop_id = "test_shop"
	shop.display_name = "Test Shop"
	shop.items_for_sale.append({"item_id": "herb_sprig", "buy_price": 50})
	shop.items_for_sale.append({"item_id": "chili_flake", "buy_price": 80})
	DataRegistry.shops["test_shop"] = shop

	var shop2 = ShopDef.new()
	shop2.shop_id = "empty_shop"
	shop2.display_name = "Empty Shop"
	DataRegistry.shops["empty_shop"] = shop2

func _seed_sellable_items() -> void:
	# Seed an ingredient with sell_price
	var ing = IngredientDef.new()
	ing.ingredient_id = "herb_sprig"
	ing.display_name = "Herb Sprig"
	ing.sell_price = 25
	ing.icon_color = Color.GREEN
	DataRegistry.ingredients["herb_sprig"] = ing

	var ing2 = IngredientDef.new()
	ing2.ingredient_id = "chili_flake"
	ing2.display_name = "Chili Flake"
	ing2.sell_price = 0 # not sellable
	ing2.icon_color = Color.RED
	DataRegistry.ingredients["chili_flake"] = ing2

	# Seed a food with sell_price
	var food = FoodDef.new()
	food.food_id = "bread_roll"
	food.display_name = "Bread Roll"
	food.sell_price = 40
	DataRegistry.foods["bread_roll"] = food

# --- Shop lookup tests ---

func test_get_shop_valid() -> void:
	var shop = DataRegistry.get_shop("test_shop")
	assert_not_null(shop)
	assert_eq(shop.display_name, "Test Shop")
	assert_eq(shop.items_for_sale.size(), 2)

func test_get_shop_invalid_returns_null() -> void:
	var shop = DataRegistry.get_shop("nonexistent_shop")
	assert_null(shop)

func test_shop_catalog_item_ids() -> void:
	var shop = DataRegistry.get_shop("test_shop")
	var item_ids: Array[String] = []
	for entry in shop.items_for_sale:
		item_ids.append(str(entry.get("item_id", "")))
	assert_true("herb_sprig" in item_ids)
	assert_true("chili_flake" in item_ids)

func test_shop_catalog_prices() -> void:
	var shop = DataRegistry.get_shop("test_shop")
	for entry in shop.items_for_sale:
		if str(entry.get("item_id", "")) == "herb_sprig":
			assert_eq(int(entry.get("buy_price", 0)), 50)
		elif str(entry.get("item_id", "")) == "chili_flake":
			assert_eq(int(entry.get("buy_price", 0)), 80)

# --- Sell price tests ---

func test_sell_price_ingredient_with_price() -> void:
	var price = DataRegistry.get_sell_price("herb_sprig")
	assert_eq(price, 25)

func test_sell_price_ingredient_no_price() -> void:
	var price = DataRegistry.get_sell_price("chili_flake")
	assert_eq(price, 0)

func test_sell_price_food() -> void:
	var price = DataRegistry.get_sell_price("bread_roll")
	assert_eq(price, 40)

func test_sell_price_unknown_item() -> void:
	var price = DataRegistry.get_sell_price("nonexistent_item")
	assert_eq(price, 0)

# --- Buy validation logic (pure logic, no RPC) ---

func test_buy_item_in_catalog() -> void:
	var shop = DataRegistry.get_shop("test_shop")
	var buy_price = -1
	for entry in shop.items_for_sale:
		if str(entry.get("item_id", "")) == "herb_sprig":
			buy_price = int(entry.get("buy_price", 0))
			break
	assert_eq(buy_price, 50, "Item should be in catalog with price 50")

func test_buy_item_not_in_catalog() -> void:
	var shop = DataRegistry.get_shop("test_shop")
	var buy_price = -1
	for entry in shop.items_for_sale:
		if str(entry.get("item_id", "")) == "nonexistent_item":
			buy_price = int(entry.get("buy_price", 0))
			break
	assert_eq(buy_price, -1, "Item not in catalog should return -1")

func test_buy_from_empty_shop() -> void:
	var shop = DataRegistry.get_shop("empty_shop")
	assert_eq(shop.items_for_sale.size(), 0, "Empty shop has no items")
	var buy_price = -1
	for entry in shop.items_for_sale:
		if str(entry.get("item_id", "")) == "herb_sprig":
			buy_price = int(entry.get("buy_price", 0))
			break
	assert_eq(buy_price, -1, "Can't buy from empty shop")
