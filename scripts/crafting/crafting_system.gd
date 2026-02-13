extends Node

signal craft_result(success: bool, creature_name: String)
signal item_craft_result(success: bool, item_name: String)

func _ready() -> void:
	pass

@rpc("any_peer", "reliable")
func request_craft_creature(recipe_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	DataRegistry.ensure_loaded()
	var recipe = DataRegistry.get_recipe(recipe_id)
	if recipe == null:
		_craft_result.rpc_id(sender, false, "", "Recipe not found")
		return
	# Validate ingredients (ask client)
	_validate_and_craft.rpc_id(sender, recipe_id)

@rpc("authority", "reliable")
func _validate_and_craft(recipe_id: String) -> void:
	# Client-side: check inventory and party space
	DataRegistry.ensure_loaded()
	var recipe = DataRegistry.get_recipe(recipe_id)
	if recipe == null:
		return
	# Check ingredients
	for ingredient_id in recipe.ingredients:
		var needed = recipe.ingredients[ingredient_id]
		if not PlayerData.has_item(ingredient_id, needed):
			_craft_failed_server.rpc_id(1, "Missing ingredients")
			return
	# Creature recipe
	if recipe.result_species_id != "":
		if PlayerData.party.size() >= PlayerData.MAX_PARTY_SIZE:
			_craft_failed_server.rpc_id(1, "Party is full")
			return
	# Deduct ingredients
	for ingredient_id in recipe.ingredients:
		var needed = recipe.ingredients[ingredient_id]
		PlayerData.remove_from_inventory(ingredient_id, needed)
	# Confirm to server
	_confirm_craft.rpc_id(1, recipe_id, multiplayer.get_unique_id())

@rpc("any_peer", "reliable")
func _confirm_craft(recipe_id: String, peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	DataRegistry.ensure_loaded()
	var recipe = DataRegistry.get_recipe(recipe_id)
	if recipe == null:
		return
	# Server-side: deduct ingredients from data store
	for ingredient_id in recipe.ingredients:
		var needed = recipe.ingredients[ingredient_id]
		NetworkManager.server_remove_inventory(peer_id, ingredient_id, needed)

	if recipe.result_species_id != "":
		# Creature recipe
		var species = DataRegistry.get_species(recipe.result_species_id)
		if species == null:
			return
		var creature = CreatureInstance.create_from_species(species, 1)
		var creature_data = creature.to_dict()
		if peer_id in NetworkManager.player_data_store:
			var server_party = NetworkManager.player_data_store[peer_id].get("party", [])
			server_party.append(creature_data)
			NetworkManager.player_data_store[peer_id]["party"] = server_party
		_receive_crafted_creature.rpc_id(peer_id, creature_data, species.display_name)
	elif recipe.result_item_id != "":
		# Held item recipe
		NetworkManager.server_add_inventory(peer_id, recipe.result_item_id, 1)
		var item = DataRegistry.get_held_item(recipe.result_item_id)
		var item_name = item.display_name if item else recipe.result_item_id
		_receive_crafted_item.rpc_id(peer_id, recipe.result_item_id, item_name)

@rpc("authority", "reliable")
func _receive_crafted_creature(creature_data: Dictionary, creature_name: String) -> void:
	PlayerData.add_creature_to_party(creature_data)
	craft_result.emit(true, creature_name)
	print(creature_name, " joined your party!")

@rpc("authority", "reliable")
func _receive_crafted_item(item_id: String, item_name: String) -> void:
	PlayerData.add_to_inventory(item_id, 1)
	item_craft_result.emit(true, item_name)
	print("Crafted ", item_name, "!")

@rpc("any_peer", "reliable")
func _craft_failed_server(reason: String) -> void:
	# Server relays failure back
	if multiplayer.is_server():
		var sender = multiplayer.get_remote_sender_id()
		_craft_result.rpc_id(sender, false, "", reason)

@rpc("authority", "reliable")
func _craft_result(success: bool, creature_name: String, reason: String) -> void:
	if not success:
		print("Crafting failed: ", reason)
	craft_result.emit(success, creature_name)

func get_available_recipes() -> Array:
	DataRegistry.ensure_loaded()
	var available = []
	for recipe_id in DataRegistry.recipes:
		var recipe = DataRegistry.recipes[recipe_id]
		var info = {
			"recipe_id": recipe.recipe_id,
			"display_name": recipe.display_name,
			"result_species_id": recipe.result_species_id,
			"result_item_id": recipe.result_item_id,
			"description": recipe.description,
			"can_craft": true,
			"ingredients": {}
		}
		for ingredient_id in recipe.ingredients:
			var needed = recipe.ingredients[ingredient_id]
			var have = PlayerData.get_item_count(ingredient_id)
			info.ingredients[ingredient_id] = {"needed": needed, "have": have}
			if have < needed:
				info.can_craft = false
		available.append(info)
	return available
