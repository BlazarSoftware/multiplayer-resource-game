extends Node

signal inventory_changed()
signal party_changed()
signal tool_changed(tool_name: String)

# Inventory: ingredient_id -> count
var inventory: Dictionary = {}

# Party: array of CreatureInstance data (dictionaries for now)
var party: Array = []
const MAX_PARTY_SIZE = 4

# Current tool
enum Tool { HANDS, HOE, AXE, WATERING_CAN, SEEDS }
var current_tool: Tool = Tool.HANDS
var selected_seed_id: String = ""

# Watering can
var watering_can_capacity: int = 10
var watering_can_current: int = 10

# Player state
var player_name: String = "Player"

func _ready() -> void:
	# Only give starter creature for offline/singleplayer testing
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if multiplayer.has_multiplayer_peer():
			return # Server doesn't need local player data
		# Offline mode: give starter creature
		var starter = {
			"species_id": "rice_ball",
			"nickname": "Rice Ball",
			"level": 5,
			"hp": 45,
			"max_hp": 45,
			"attack": 12,
			"defense": 14,
			"sp_attack": 10,
			"sp_defense": 14,
			"speed": 10,
			"moves": ["grain_bash", "quick_bite", "bread_wall", "taste_test"],
			"pp": [15, 25, 10, 5],
			"types": ["grain"]
		}
		party.append(starter)

func load_from_server(data: Dictionary) -> void:
	player_name = data.get("player_name", "Player")
	# Load inventory
	inventory.clear()
	var inv = data.get("inventory", {})
	for key in inv:
		inventory[key] = int(inv[key])
	# Load party
	party.clear()
	var party_data = data.get("party", [])
	for creature in party_data:
		party.append(creature)
	# Load watering can
	watering_can_current = int(data.get("watering_can_current", watering_can_capacity))
	# Reset tool
	current_tool = Tool.HANDS
	selected_seed_id = ""
	inventory_changed.emit()
	party_changed.emit()

func to_dict() -> Dictionary:
	return {
		"player_name": player_name,
		"inventory": inventory.duplicate(),
		"party": party.duplicate(true),
		"watering_can_current": watering_can_current
	}

func reset() -> void:
	inventory.clear()
	party.clear()
	current_tool = Tool.HANDS
	selected_seed_id = ""
	watering_can_current = watering_can_capacity
	player_name = "Player"
	inventory_changed.emit()
	party_changed.emit()

func add_to_inventory(item_id: String, amount: int = 1) -> void:
	if item_id in inventory:
		inventory[item_id] += amount
	else:
		inventory[item_id] = amount
	inventory_changed.emit()

func remove_from_inventory(item_id: String, amount: int = 1) -> bool:
	if item_id not in inventory or inventory[item_id] < amount:
		return false
	inventory[item_id] -= amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
	inventory_changed.emit()
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	return item_id in inventory and inventory[item_id] >= amount

func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

func add_creature_to_party(creature_data: Dictionary) -> bool:
	if party.size() >= MAX_PARTY_SIZE:
		return false
	party.append(creature_data)
	party_changed.emit()
	return true

func remove_creature_from_party(index: int) -> void:
	if index >= 0 and index < party.size() and party.size() > 1:
		party.remove_at(index)
		party_changed.emit()

func get_first_alive_creature() -> int:
	for i in range(party.size()):
		if party[i]["hp"] > 0:
			return i
	return -1

func heal_all_creatures() -> void:
	for creature in party:
		creature["hp"] = creature["max_hp"]
		pass
	party_changed.emit()

func set_tool(tool_type: Tool) -> void:
	current_tool = tool_type
	tool_changed.emit(Tool.keys()[tool_type])

func refill_watering_can() -> void:
	watering_can_current = watering_can_capacity

func use_watering_can() -> bool:
	if watering_can_current > 0:
		watering_can_current -= 1
		return true
	return false
