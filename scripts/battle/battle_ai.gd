class_name BattleAI
extends RefCounted

# AI for trainer battles with three difficulty tiers.

static func pick_move(battle: Dictionary, side: String) -> String:
	var difficulty = "easy"
	if battle.trainer_id != "":
		var trainer = DataRegistry.get_trainer(battle.trainer_id)
		if trainer:
			difficulty = trainer.ai_difficulty

	var ai_creature = battle["side_" + side + "_party"][battle["side_" + side + "_active_idx"]]
	var opponent_side = "a" if side == "b" else "b"
	var opponent = battle["side_" + opponent_side + "_party"][battle["side_" + opponent_side + "_active_idx"]]

	# Encore override: forced into locked move
	if ai_creature.get("encore_turns", 0) > 0 and ai_creature.get("last_move_used", "") != "":
		var locked = ai_creature["last_move_used"]
		var midx = -1
		var moves = ai_creature.get("moves", [])
		for i in range(moves.size()):
			if moves[i] == locked:
				midx = i
				break
		if midx >= 0:
			var pp = ai_creature.get("pp", [])
			if midx < pp.size() and pp[midx] > 0:
				pp[midx] -= 1
			return locked

	# Choice lock override
	var choice_locked = ai_creature.get("choice_locked_move", "")
	if choice_locked != "":
		var midx = -1
		var moves = ai_creature.get("moves", [])
		for i in range(moves.size()):
			if moves[i] == choice_locked:
				midx = i
				break
		if midx >= 0:
			var pp = ai_creature.get("pp", [])
			if midx < pp.size() and pp[midx] > 0:
				pp[midx] -= 1
			return choice_locked

	match difficulty:
		"easy":
			return _pick_random(ai_creature)
		"medium":
			return _pick_medium(ai_creature, opponent, battle)
		"hard":
			return _pick_hard(ai_creature, opponent, battle)
		_:
			return _pick_random(ai_creature)

static func pick_action(battle: Dictionary, side: String, _difficulty: String) -> Dictionary:
	# Returns {type: "move"/"switch", data: String}
	# For now, AI only picks moves
	var move_id = pick_move(battle, side)
	return {"type": "move", "data": move_id}

static func _pick_random(creature: Dictionary) -> String:
	var moves = creature.get("moves", [])
	var pp = creature.get("pp", [])
	var is_taunted = creature.get("taunt_turns", 0) > 0
	var available = []
	for i in range(moves.size()):
		if i < pp.size() and pp[i] <= 0:
			continue
		# Filter status moves when taunted
		if is_taunted:
			var move = DataRegistry.get_move(moves[i])
			if move and move.category == "status":
				continue
		available.append(i)
	if available.size() == 0:
		return "quick_bite"
	var idx = available[randi() % available.size()]
	if idx < pp.size():
		pp[idx] -= 1
	return moves[idx]

static func _pick_medium(creature: Dictionary, opponent: Dictionary, battle: Dictionary) -> String:
	var moves = creature.get("moves", [])
	var pp = creature.get("pp", [])
	var is_taunted = creature.get("taunt_turns", 0) > 0
	var available_indices = []
	for i in range(moves.size()):
		if i < pp.size() and pp[i] <= 0:
			continue
		if is_taunted:
			var m = DataRegistry.get_move(moves[i])
			if m and m.category == "status":
				continue
		available_indices.append(i)
	if available_indices.size() == 0:
		return "quick_bite"

	# Score each move
	var best_idx = available_indices[0]
	var best_score = -999.0

	var opponent_types = opponent.get("types", [])
	if opponent_types is PackedStringArray:
		opponent_types = Array(opponent_types)

	var hp_ratio = float(creature.get("hp", 1)) / float(max(1, creature.get("max_hp", 1)))

	for i in available_indices:
		var move = DataRegistry.get_move(moves[i])
		if move == null:
			continue
		var score = 0.0

		if move.power > 0:
			# Base score from power
			score = float(move.power)
			# Type effectiveness bonus
			var eff = BattleCalculator.get_type_effectiveness(move.type, opponent_types)
			if eff == 0.0:
				score = 0.0 # Never use immune moves
				if score >= best_score:
					pass # skip
				continue
			score *= eff
			# STAB
			var creature_types = creature.get("types", [])
			if creature_types is PackedStringArray:
				creature_types = Array(creature_types)
			if move.type in creature_types:
				score *= 1.5
		elif move.heal_percent > 0 and hp_ratio < 0.4:
			score = 80.0
		elif move.status_effect != "" and opponent.get("status", "") == "":
			score = 50.0
		elif move.taunt and opponent.get("taunt_turns", 0) <= 0:
			score = 45.0
		elif move.encore and opponent.get("encore_turns", 0) <= 0:
			score = 40.0
		elif move.substitute and creature.get("substitute_hp", 0) <= 0 and hp_ratio > 0.3:
			score = 50.0
		elif move.trick_room:
			score = 35.0
		elif move.stat_changes.size() > 0:
			score = 30.0
		elif move.weather_set != "" and battle.get("weather", "") == "":
			score = 40.0
		elif move.hazard_type != "":
			score = 35.0
		else:
			score = 10.0

		# Don't stack status
		if move.status_effect != "" and opponent.get("status", "") != "":
			score *= 0.3

		if score > best_score:
			best_score = score
			best_idx = i

	if best_idx < pp.size():
		pp[best_idx] -= 1
	return moves[best_idx]

static func _pick_hard(creature: Dictionary, opponent: Dictionary, battle: Dictionary) -> String:
	# Hard AI: everything medium does + more nuance
	var moves = creature.get("moves", [])
	var pp = creature.get("pp", [])
	var is_taunted = creature.get("taunt_turns", 0) > 0
	var available_indices = []
	for i in range(moves.size()):
		if i < pp.size() and pp[i] <= 0:
			continue
		if is_taunted:
			var m = DataRegistry.get_move(moves[i])
			if m and m.category == "status":
				continue
		available_indices.append(i)
	if available_indices.size() == 0:
		return "quick_bite"

	var best_idx = available_indices[0]
	var best_score = -999.0

	var opponent_types = opponent.get("types", [])
	if opponent_types is PackedStringArray:
		opponent_types = Array(opponent_types)

	var hp_ratio = float(creature.get("hp", 1)) / float(max(1, creature.get("max_hp", 1)))
	var opp_hp_ratio = float(opponent.get("hp", 1)) / float(max(1, opponent.get("max_hp", 1)))
	var trick_room_active = battle.get("trick_room_turns", 0) > 0

	for i in available_indices:
		var move = DataRegistry.get_move(moves[i])
		if move == null:
			continue
		var score = 0.0

		if move.power > 0:
			var eff = BattleCalculator.get_type_effectiveness(move.type, opponent_types)
			if eff == 0.0:
				continue # Never use immune moves
			score = float(move.power)
			score *= eff
			var creature_types = creature.get("types", [])
			if creature_types is PackedStringArray:
				creature_types = Array(creature_types)
			if move.type in creature_types:
				score *= 1.5
			# Weather boost
			if battle.get("weather", "") != "":
				var weather_mod = FieldEffects.get_weather_modifier(battle.weather, move.type)
				score *= weather_mod
			# Prioritize finishing off low HP opponents
			if opp_hp_ratio < 0.3:
				score *= 1.3
			# Priority moves when opponent is low
			if move.priority > 0 and opp_hp_ratio < 0.25:
				score *= 1.5
			# Knock Off: value removing opponent's item
			if move.knock_off and opponent.get("held_item_id", "") != "":
				score *= 1.4
			# U-turn: high mobility value
			if move.switch_after:
				score *= 1.1
			# Target has substitute: prefer multi-hit to break it
			if opponent.get("substitute_hp", 0) > 0 and move.multi_hit_max > 0:
				score *= 1.5
		elif move.heal_percent > 0:
			if hp_ratio < 0.3:
				score = 100.0
			elif hp_ratio < 0.5:
				score = 70.0
			else:
				score = 10.0
		elif move.is_protection:
			if creature.get("protect_count", 0) == 0:
				score = 45.0
			else:
				score = 5.0
		elif move.substitute and creature.get("substitute_hp", 0) <= 0 and hp_ratio > 0.35:
			score = 55.0
		elif move.taunt and opponent.get("taunt_turns", 0) <= 0:
			# Taunt is great against setup / status-heavy opponents
			score = 50.0
		elif move.encore and opponent.get("encore_turns", 0) <= 0 and opponent.get("last_move_used", "") != "":
			score = 45.0
		elif move.trick_room:
			# Value trick room when we're slower (or to undo it)
			var our_spd = BattleCalculator.get_speed(creature)
			var opp_spd = BattleCalculator.get_speed(opponent)
			if trick_room_active:
				score = 10.0 # Don't undo our own trick room
			elif our_spd < opp_spd:
				score = 60.0 # We're slower, trick room benefits us
			else:
				score = 15.0
		elif move.force_switch:
			# Roar: remove stat boosts
			var total_boosts = 0
			for stat in ["attack_stage", "sp_attack_stage", "defense_stage", "sp_defense_stage", "speed_stage"]:
				total_boosts += max(0, opponent.get(stat, 0))
			if total_boosts >= 2:
				score = 65.0
			else:
				score = 20.0
		elif move.status_effect != "" and opponent.get("status", "") == "":
			score = 55.0
		elif move.weather_set != "" and battle.get("weather", "") == "":
			score = 50.0
		elif move.hazard_type != "":
			if battle.turn < 3:
				score = 55.0
			else:
				score = 20.0
		elif move.stat_changes.size() > 0:
			if battle.turn < 2:
				score = 45.0
			else:
				score = 25.0
		elif move.self_crit_stage_change > 0:
			if creature.get("crit_stage", 0) < 2:
				score = 40.0
			else:
				score = 5.0
		elif move.clears_hazards:
			var side = "side_b_hazards"
			if battle.get(side, []).size() > 0:
				score = 60.0
			else:
				score = 5.0
		else:
			score = 10.0

		if move.status_effect != "" and opponent.get("status", "") != "":
			score *= 0.2

		if score > best_score:
			best_score = score
			best_idx = i

	if best_idx < pp.size():
		pp[best_idx] -= 1
	return moves[best_idx]
