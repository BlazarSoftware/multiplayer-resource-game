extends Node

signal encounter_started(peer_id: int, creature_data: Dictionary)

# Active battles: peer_id -> battle data
var active_encounters: Dictionary = {}

func start_encounter(peer_id: int, table_id: String) -> void:
	if not multiplayer.is_server():
		return
	if peer_id in active_encounters:
		return # Already in wild encounter
	# Check if player is in ANY battle (wild, trainer, or PvP)
	var battle_mgr = get_node_or_null("/root/Main/GameWorld/BattleManager")
	if battle_mgr and peer_id in battle_mgr.player_battle_map:
		return
	DataRegistry.ensure_loaded()
	var table = DataRegistry.get_encounter_table(table_id)
	if table == null:
		print("No encounter table: ", table_id)
		return
	# Roll creature from table
	var species_id = _roll_encounter(table)
	if species_id == "":
		return
	var species = DataRegistry.get_species(species_id)
	if species == null:
		return
	# Determine level
	var level_range = _get_level_range(table, species_id)
	var level = randi_range(level_range.x, level_range.y)
	# Create enemy creature instance
	var enemy = CreatureInstance.create_from_species(species, level)
	var enemy_data = enemy.to_dict()
	active_encounters[peer_id] = {
		"enemy": enemy_data,
		"table_id": table_id,
		"species_id": species_id
	}
	print("Encounter for peer ", peer_id, ": ", species.display_name, " Lv.", level)
	if battle_mgr:
		battle_mgr.server_start_battle(peer_id, enemy_data, table_id)
	encounter_started.emit(peer_id, enemy_data)

func get_encounter_rate_multiplier(peer_id: int) -> float:
	return NetworkManager.server_get_buff_value(peer_id, "encounter_rate") if NetworkManager.server_has_buff(peer_id, "encounter_rate") else 1.0

func _roll_encounter(table) -> String:
	var total_weight = 0
	for entry in table.entries:
		total_weight += entry.get("weight", 10)
	# Check season bonus
	var season_mgr = get_node_or_null("/root/Main/GameWorld/SeasonManager")
	var bonus_species = ""
	if season_mgr:
		var current_season = season_mgr.get_season_name()
		bonus_species = table.season_bonus.get(current_season, "")
	if bonus_species != "":
		total_weight += 20 # extra weight for seasonal bonus
	var roll = randi() % total_weight
	var cumulative = 0
	# Check bonus first
	if bonus_species != "":
		cumulative += 20
		if roll < cumulative:
			return bonus_species
	for entry in table.entries:
		cumulative += entry.get("weight", 10)
		if roll < cumulative:
			return entry.get("species_id", "")
	return table.entries[0].get("species_id", "") if table.entries.size() > 0 else ""

func _get_level_range(table, species_id: String) -> Vector2i:
	for entry in table.entries:
		if entry.get("species_id", "") == species_id:
			return Vector2i(entry.get("min_level", 2), entry.get("max_level", 5))
	return Vector2i(2, 5)

func end_encounter(peer_id: int) -> void:
	active_encounters.erase(peer_id)

func is_in_encounter(peer_id: int) -> bool:
	return peer_id in active_encounters

