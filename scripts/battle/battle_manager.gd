extends Node

const BattleCalculator = preload("res://scripts/battle/battle_calculator.gd")
const StatusEffects = preload("res://scripts/battle/status_effects.gd")

signal battle_started()
signal battle_ended(victory: bool)
signal turn_result_received(results: Array)

# Server state: active battles per player
var battles: Dictionary = {} # peer_id -> BattleState dict

# Client state
var in_battle: bool = false
var client_enemy: Dictionary = {}
var client_active_creature_idx: int = 0
var awaiting_action: bool = false

# Battle state structure (server-side per player):
# {
#   "player_party": Array of creature dicts,
#   "active_idx": int,
#   "enemy": creature dict,
#   "turn": int,
#   "state": "waiting_action" | "processing" | "ended"
# }

func _ready() -> void:
	pass

# === SERVER SIDE ===

func server_start_battle(peer_id: int, enemy_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	# Get player's party data (request from client)
	battles[peer_id] = {
		"enemy": enemy_data.duplicate(true),
		"active_idx": 0,
		"turn": 0,
		"state": "waiting_action"
	}
	# Request party data from client
	_request_party_data.rpc_id(peer_id)

@rpc("authority", "reliable")
func _request_party_data() -> void:
	# Client sends party to server
	var party_data = []
	for creature in PlayerData.party:
		var c = creature.duplicate(true)
		# Reset stat stages for battle
		c["attack_stage"] = 0
		c["defense_stage"] = 0
		c["sp_attack_stage"] = 0
		c["sp_defense_stage"] = 0
		c["speed_stage"] = 0
		c["status"] = ""
		c["status_turns"] = 0
		party_data.append(c)
	_receive_party_data.rpc_id(1, party_data)

@rpc("any_peer", "reliable")
func _receive_party_data(party_data: Array) -> void:
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender in battles:
		battles[sender]["player_party"] = party_data
		# Also initialize enemy stat stages
		var enemy = battles[sender]["enemy"]
		enemy["attack_stage"] = 0
		enemy["defense_stage"] = 0
		enemy["sp_attack_stage"] = 0
		enemy["sp_defense_stage"] = 0
		enemy["speed_stage"] = 0
		enemy["status"] = ""
		enemy["status_turns"] = 0

@rpc("any_peer", "reliable")
func request_battle_action(action_type: String, action_data: String) -> void:
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender not in battles:
		return
	var battle = battles[sender]
	if battle.state != "waiting_action":
		return
	battle.state = "processing"
	DataRegistry.ensure_loaded()
	match action_type:
		"move":
			_process_move_turn(sender, action_data)
		"switch":
			_process_switch(sender, action_data.to_int())
		"flee":
			_process_flee(sender)

func _process_move_turn(peer_id: int, move_id: String) -> void:
	var battle = battles[peer_id]
	var player_creature = battle.player_party[battle.active_idx]
	var enemy = battle.enemy
	var turn_log = []
	# Validate move
	var player_move = DataRegistry.get_move(move_id)
	if player_move == null:
		battle.state = "waiting_action"
		return
	# Check PP
	var move_idx = -1
	var moves_arr = player_creature.get("moves", [])
	for i in range(moves_arr.size()):
		if moves_arr[i] == move_id:
			move_idx = i
			break
	if move_idx == -1:
		battle.state = "waiting_action"
		return
	var pp_arr = player_creature.get("pp", [])
	if move_idx < pp_arr.size() and pp_arr[move_idx] <= 0:
		battle.state = "waiting_action"
		return
	# Deduct PP
	if move_idx < pp_arr.size():
		pp_arr[move_idx] -= 1
	# Pick enemy move
	var enemy_move_id = _pick_enemy_move(enemy)
	var enemy_move = DataRegistry.get_move(enemy_move_id)
	# Determine turn order
	var player_speed = BattleCalculator.get_speed(player_creature)
	var enemy_speed = BattleCalculator.get_speed(enemy)
	# Priority check
	var player_priority = player_move.priority if player_move else 0
	var enemy_priority = enemy_move.priority if enemy_move else 0
	var player_first = true
	if player_priority != enemy_priority:
		player_first = player_priority > enemy_priority
	elif player_speed != enemy_speed:
		player_first = player_speed > enemy_speed
	else:
		player_first = randf() > 0.5
	# Execute turns
	if player_first:
		var r1 = _execute_action(player_creature, enemy, player_move, "player")
		turn_log.append(r1)
		if enemy.hp > 0:
			var r2 = _execute_action(enemy, player_creature, enemy_move, "enemy")
			turn_log.append(r2)
	else:
		var r1 = _execute_action(enemy, player_creature, enemy_move, "enemy")
		turn_log.append(r1)
		if player_creature.hp > 0:
			var r2 = _execute_action(player_creature, enemy, player_move, "player")
			turn_log.append(r2)
	# End of turn effects
	if player_creature.hp > 0:
		var status_result = StatusEffects.apply_end_of_turn(player_creature)
		if status_result.damage > 0:
			turn_log.append({"actor": "player", "type": "status_damage", "damage": status_result.damage, "message": status_result.message})
	if enemy.hp > 0:
		var status_result = StatusEffects.apply_end_of_turn(enemy)
		if status_result.damage > 0:
			turn_log.append({"actor": "enemy", "type": "status_damage", "damage": status_result.damage, "message": status_result.message})
	battle.turn += 1
	# Check outcomes
	if enemy.hp <= 0:
		var drops = _calculate_drops(battle.enemy)
		turn_log.append({"type": "victory", "drops": drops})
		_send_turn_result.rpc_id(peer_id, turn_log, player_creature.hp, player_creature.get("pp", []), enemy.hp)
		_grant_battle_rewards.rpc_id(peer_id, drops)
		# Server-side inventory tracking for drops
		for item_id in drops:
			NetworkManager.server_add_inventory(peer_id, item_id, drops[item_id])
		_end_battle(peer_id, true)
		return
	if player_creature.hp <= 0:
		# Check if any alive creatures
		var alive_idx = _find_alive_creature(battle.player_party, battle.active_idx)
		if alive_idx == -1:
			turn_log.append({"type": "defeat"})
			_send_turn_result.rpc_id(peer_id, turn_log, 0, player_creature.get("pp", []), enemy.hp)
			_end_battle(peer_id, false)
			return
		else:
			turn_log.append({"type": "fainted", "need_switch": true})
	_send_turn_result.rpc_id(peer_id, turn_log, player_creature.hp, player_creature.get("pp", []), enemy.hp)
	battle.state = "waiting_action"

func _execute_action(attacker: Dictionary, defender: Dictionary, move, actor: String) -> Dictionary:
	var result = {
		"actor": actor,
		"move": move.display_name,
		"move_type": move.type,
		"type": "move"
	}
	# Check if can act
	if not BattleCalculator.can_act(attacker):
		result["skipped"] = true
		result["message"] = "can't move!"
		return result
	# Check accuracy
	if not BattleCalculator.check_accuracy(move, attacker, defender):
		result["missed"] = true
		return result
	# Calculate and apply damage
	if move.power > 0:
		var dmg_result = BattleCalculator.calculate_damage(attacker, defender, move, attacker.get("level", 5))
		defender["hp"] = max(0, defender.get("hp", 0) - dmg_result.damage)
		result["damage"] = dmg_result.damage
		result["effectiveness"] = BattleCalculator.get_effectiveness_text(dmg_result.effectiveness)
		result["critical"] = dmg_result.critical
		# Drain healing
		if move.drain_percent > 0 and dmg_result.damage > 0:
			var heal = int(dmg_result.damage * move.drain_percent)
			attacker["hp"] = min(attacker.get("max_hp", 40), attacker.get("hp", 0) + heal)
			result["drain_heal"] = heal
	# Healing
	if move.heal_percent > 0:
		var heal = int(attacker.get("max_hp", 40) * move.heal_percent)
		attacker["hp"] = min(attacker.get("max_hp", 40), attacker.get("hp", 0) + heal)
		result["heal"] = heal
	# Status effect
	if move.status_effect != "" and defender.get("hp", 0) > 0:
		var applied = StatusEffects.try_apply_status(defender, move.status_effect, move.status_chance)
		if applied:
			result["status_applied"] = move.status_effect
	# Stat changes (self-targeting)
	if move.stat_changes.size() > 0:
		var target = attacker if move.category == "status" else attacker
		var changes = BattleCalculator.apply_stat_changes(target, move.stat_changes)
		result["stat_changes"] = changes
	return result

func _pick_enemy_move(enemy: Dictionary) -> String:
	var moves = enemy.get("moves", [])
	var pp = enemy.get("pp", [])
	var available = []
	for i in range(moves.size()):
		if i < pp.size() and pp[i] > 0:
			available.append(i)
		elif i >= pp.size():
			available.append(i)
	if available.size() == 0:
		return "quick_bite" # fallback
	var idx = available[randi() % available.size()]
	if idx < pp.size():
		pp[idx] -= 1
	return moves[idx]

func _find_alive_creature(party: Array, exclude_idx: int) -> int:
	for i in range(party.size()):
		if i != exclude_idx and party[i].get("hp", 0) > 0:
			return i
	return -1

func _calculate_drops(enemy: Dictionary) -> Dictionary:
	var species = DataRegistry.get_species(enemy.get("species_id", ""))
	if species == null:
		return {}
	var drops = {}
	for drop_id in species.drop_ingredient_ids:
		var amount = randi_range(species.drop_min, species.drop_max)
		drops[drop_id] = amount
	return drops

func _process_switch(peer_id: int, new_idx: int) -> void:
	var battle = battles[peer_id]
	if new_idx < 0 or new_idx >= battle.player_party.size():
		battle.state = "waiting_action"
		return
	if battle.player_party[new_idx].get("hp", 0) <= 0:
		battle.state = "waiting_action"
		return
	var old_idx = battle.active_idx
	battle.active_idx = new_idx
	var switch_log = [{"type": "switch", "actor": "player", "from": old_idx, "to": new_idx}]
	# Enemy attacks after switch (unless current creature fainted)
	if battle.player_party[old_idx].get("hp", 0) > 0:
		var enemy = battle.enemy
		var enemy_move_id = _pick_enemy_move(enemy)
		var enemy_move = DataRegistry.get_move(enemy_move_id)
		if enemy_move:
			var r = _execute_action(enemy, battle.player_party[new_idx], enemy_move, "enemy")
			switch_log.append(r)
	var active = battle.player_party[battle.active_idx]
	_send_turn_result.rpc_id(peer_id, switch_log, active.hp, active.get("pp", []), battle.enemy.hp)
	battle.state = "waiting_action"

func _process_flee(peer_id: int) -> void:
	var battle = battles[peer_id]
	var player_speed = BattleCalculator.get_speed(battle.player_party[battle.active_idx])
	var enemy_speed = BattleCalculator.get_speed(battle.enemy)
	var flee_chance = 0.5 + 0.2 * (float(player_speed) / max(1, float(enemy_speed)) - 1.0)
	flee_chance = clampf(flee_chance, 0.2, 0.9)
	if randf() < flee_chance:
		_send_turn_result.rpc_id(peer_id, [{"type": "fled"}], 0, [], 0)
		_end_battle(peer_id, false)
	else:
		# Failed to flee, enemy attacks
		var enemy = battle.enemy
		var enemy_move_id = _pick_enemy_move(enemy)
		var enemy_move = DataRegistry.get_move(enemy_move_id)
		var log = [{"type": "flee_failed"}]
		if enemy_move:
			var r = _execute_action(enemy, battle.player_party[battle.active_idx], enemy_move, "enemy")
			log.append(r)
		var active = battle.player_party[battle.active_idx]
		_send_turn_result.rpc_id(peer_id, log, active.hp, active.get("pp", []), enemy.hp)
		battle.state = "waiting_action"

func _end_battle(peer_id: int, victory: bool) -> void:
	# Save party state server-side before erasing battle
	if peer_id in battles:
		var battle = battles[peer_id]
		if battle.has("player_party"):
			NetworkManager.server_update_party(peer_id, battle.player_party)
	battles.erase(peer_id)
	var encounter_mgr = get_node_or_null("/root/Main/GameWorld/EncounterManager")
	if encounter_mgr:
		encounter_mgr.end_encounter(peer_id)
	if victory:
		_battle_ended_client.rpc_id(peer_id, true)
	else:
		_battle_ended_client.rpc_id(peer_id, false)

# === CLIENT RPCs ===

@rpc("authority", "reliable")
func _send_turn_result(turn_log: Array, player_hp: int, player_pp: Array, enemy_hp: int) -> void:
	turn_result_received.emit(turn_log)
	# Update local state
	if client_active_creature_idx < PlayerData.party.size():
		PlayerData.party[client_active_creature_idx].hp = player_hp
		if player_pp.size() > 0:
			PlayerData.party[client_active_creature_idx].pp = player_pp
	client_enemy.hp = enemy_hp
	awaiting_action = true

@rpc("authority", "reliable")
func _grant_battle_rewards(drops: Dictionary) -> void:
	for item_id in drops:
		PlayerData.add_to_inventory(item_id, drops[item_id])
	print("Battle rewards: ", drops)

@rpc("authority", "reliable")
func _battle_ended_client(victory: bool) -> void:
	in_battle = false
	awaiting_action = false
	battle_ended.emit(victory)
	if not victory:
		# Teleport to restaurant on defeat
		PlayerData.heal_all_creatures()

# === CLIENT ACTIONS ===

func start_battle_client(enemy_data: Dictionary) -> void:
	in_battle = true
	client_enemy = enemy_data.duplicate(true)
	client_active_creature_idx = PlayerData.get_first_alive_creature()
	awaiting_action = true
	battle_started.emit()

func send_move(move_id: String) -> void:
	if not awaiting_action:
		return
	awaiting_action = false
	request_battle_action.rpc_id(1, "move", move_id)

func send_switch(creature_idx: int) -> void:
	if not awaiting_action:
		return
	awaiting_action = false
	request_battle_action.rpc_id(1, "switch", str(creature_idx))

func send_flee() -> void:
	if not awaiting_action:
		return
	awaiting_action = false
	request_battle_action.rpc_id(1, "flee", "")
