extends GutTest

# Tests for crafting validation logic.
# Since CraftingSystem.request_craft() uses RPCs and NetworkManager,
# we test the validation rules independently using DataRegistry.

func before_each():
	RegistrySeeder.seed_all()
	# Add test recipes
	_add_test_recipes()

func after_each():
	RegistrySeeder.clear_all()

func _add_test_recipes():
	var recipe = RecipeDef.new()
	recipe.recipe_id = "test_food"
	recipe.display_name = "Test Food"
	recipe.result_food_id = "test_food_item"
	recipe.station = "kitchen"
	recipe.ingredients = {"herb": 3, "wheat_grain": 2}
	recipe.unlockable = false
	DataRegistry.recipes["test_food"] = recipe

	var locked_recipe = RecipeDef.new()
	locked_recipe.recipe_id = "locked_creature"
	locked_recipe.display_name = "Locked Creature"
	locked_recipe.result_species_id = "test_species"
	locked_recipe.station = "cauldron"
	locked_recipe.ingredients = {"herb": 5}
	locked_recipe.unlockable = true
	DataRegistry.recipes["locked_creature"] = locked_recipe

	var tool_recipe = RecipeDef.new()
	tool_recipe.recipe_id = "upgrade_hoe"
	tool_recipe.display_name = "Bronze Hoe"
	tool_recipe.result_tool_id = "tool_hoe_bronze"
	tool_recipe.station = "workbench"
	tool_recipe.ingredients = {"copper_ore": 3}
	tool_recipe.requires_tool_ingredient = "tool_hoe_basic"
	tool_recipe.unlockable = false
	DataRegistry.recipes["upgrade_hoe"] = tool_recipe

# --- Recipe lookup ---

func test_recipe_found():
	var recipe = DataRegistry.get_recipe("test_food")
	assert_not_null(recipe)
	assert_eq(recipe.recipe_id, "test_food")

func test_recipe_not_found():
	var recipe = DataRegistry.get_recipe("nonexistent")
	assert_null(recipe)

# --- Unlockable check ---

func test_locked_recipe_requires_unlock():
	var recipe = DataRegistry.get_recipe("locked_creature")
	assert_true(recipe.unlockable)

func test_unlocked_recipe_no_check():
	var recipe = DataRegistry.get_recipe("test_food")
	assert_false(recipe.unlockable)

# --- Ingredient validation ---

func test_has_all_ingredients():
	var recipe = DataRegistry.get_recipe("test_food")
	var inventory = {"herb": 5, "wheat_grain": 3}
	var has_all = true
	for ingredient_id in recipe.ingredients:
		var needed = int(recipe.ingredients[ingredient_id])
		if not (ingredient_id in inventory and inventory[ingredient_id] >= needed):
			has_all = false
			break
	assert_true(has_all)

func test_missing_one_ingredient():
	var recipe = DataRegistry.get_recipe("test_food")
	var inventory = {"herb": 5} # missing wheat_grain
	var has_all = true
	for ingredient_id in recipe.ingredients:
		var needed = int(recipe.ingredients[ingredient_id])
		if not (ingredient_id in inventory and inventory[ingredient_id] >= needed):
			has_all = false
			break
	assert_false(has_all)

func test_insufficient_quantity():
	var recipe = DataRegistry.get_recipe("test_food")
	var inventory = {"herb": 1, "wheat_grain": 2} # need 3 herbs
	var has_all = true
	for ingredient_id in recipe.ingredients:
		var needed = int(recipe.ingredients[ingredient_id])
		if not (ingredient_id in inventory and inventory[ingredient_id] >= needed):
			has_all = false
			break
	assert_false(has_all)

# --- Tool ingredient check ---

func test_tool_ingredient_required():
	var recipe = DataRegistry.get_recipe("upgrade_hoe")
	assert_eq(recipe.requires_tool_ingredient, "tool_hoe_basic")

func test_tool_ingredient_present():
	var recipe = DataRegistry.get_recipe("upgrade_hoe")
	var inventory = {"copper_ore": 3, "tool_hoe_basic": 1}
	var has_tool = recipe.requires_tool_ingredient in inventory
	assert_true(has_tool)

func test_tool_ingredient_missing():
	var recipe = DataRegistry.get_recipe("upgrade_hoe")
	var inventory = {"copper_ore": 3} # no hoe
	var has_tool = recipe.requires_tool_ingredient == "" or recipe.requires_tool_ingredient in inventory
	assert_false(has_tool)

# --- Party full check ---

func test_creature_recipe_party_full():
	var recipe = DataRegistry.get_recipe("locked_creature")
	assert_ne(recipe.result_species_id, "")
	# Party of 3 = full (MAX_PARTY_SIZE = 3)
	var party = [{}, {}, {}]
	var is_full = party.size() >= 3
	assert_true(is_full)

func test_creature_recipe_party_has_space():
	var recipe = DataRegistry.get_recipe("locked_creature")
	var party = [{}]
	var is_full = party.size() >= 3
	assert_false(is_full)

# --- Ingredient deduction simulation ---

func test_ingredient_deduction():
	var inventory = {"herb": 5, "wheat_grain": 3}
	var recipe = DataRegistry.get_recipe("test_food")
	for ingredient_id in recipe.ingredients:
		var needed = int(recipe.ingredients[ingredient_id])
		inventory[ingredient_id] -= needed
		if inventory[ingredient_id] <= 0:
			inventory.erase(ingredient_id)
	assert_eq(inventory["herb"], 2) # 5 - 3
	assert_eq(inventory["wheat_grain"], 1) # 3 - 2
