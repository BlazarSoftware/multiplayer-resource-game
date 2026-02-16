class_name BattleTestScene
extends RefCounted

# Helper to create a BattleManager for integration testing.
# Since BattleManager uses RPCs and multiplayer state,
# we test the core battle logic directly using _execute_action and _process_move_turn.
# RPC methods are not called — we invoke the internal methods per CLAUDE.md testing pattern.

# Creates a minimal battle dict for testing
static func make_wild_battle(player_creature: Dictionary, enemy_creature: Dictionary, weather: String = "") -> Dictionary:
	return {
		"battle_id": 1,
		"mode": 0, # WILD
		"state": "waiting_action",
		"side_a_peer": 1,
		"side_a_party": [player_creature],
		"side_a_active_idx": 0,
		"side_a_action": null,
		"side_b_peer": 0,
		"side_b_party": [enemy_creature],
		"side_b_active_idx": 0,
		"side_b_action": null,
		"turn": 1,
		"trainer_id": "",
		"weather": weather,
		"weather_turns": 5 if weather != "" else 0,
		"side_a_hazards": [],
		"side_b_hazards": [],
		"participants_a": [0],
		"participants_b": [0],
		"timeout_timer": 0.0,
		"trick_room_turns": 0,
	}

static func init_creature_for_battle(creature: Dictionary) -> Dictionary:
	# Add battle-only fields that _init_creature_battle_state would add
	var defaults = {
		"attack_stage": 0,
		"defense_stage": 0,
		"sp_attack_stage": 0,
		"sp_defense_stage": 0,
		"speed_stage": 0,
		"accuracy_stage": 0,
		"evasion_stage": 0,
		"status": "",
		"status_turns": 0,
		"is_protecting": false,
		"protect_count": 0,
		"is_charging": false,
		"charged_move_id": "",
		"crit_stage": 0,
		"taunt_turns": 0,
		"encore_turns": 0,
		"last_move_used": "",
		"substitute_hp": 0,
		"choice_locked_move": "",
		"bond_endure_used": false,
		"bond_boost_stat": "",
		"bond_nerf_stat": "",
	}
	for key in defaults:
		if not creature.has(key):
			creature[key] = defaults[key]
	return creature
