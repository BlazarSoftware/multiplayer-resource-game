class_name BattleFactory
extends RefCounted

# Factory for creating battle and creature dictionaries for testing.

static func creature(overrides: Dictionary = {}) -> Dictionary:
	var c = {
		"hp": 80,
		"max_hp": 80,
		"attack": 20,
		"defense": 15,
		"sp_attack": 18,
		"sp_defense": 14,
		"speed": 16,
		"attack_stage": 0,
		"defense_stage": 0,
		"sp_attack_stage": 0,
		"sp_defense_stage": 0,
		"speed_stage": 0,
		"accuracy_stage": 0,
		"evasion_stage": 0,
		"crit_stage": 0,
		"types": ["spicy"],
		"moves": ["test_move_a", "test_move_b"],
		"pp": [10, 10],
		"status": "",
		"status_turns": 0,
		"ability_id": "",
		"held_item_id": "",
		"bond_level": 0,
		"bond_boost_stat": "",
		"bond_nerf_stat": "",
		"substitute_hp": 0,
		"taunt_turns": 0,
		"encore_turns": 0,
		"last_move_used": "",
		"choice_locked_move": "",
		"protect_count": 0,
		"_item_threshold_triggered": false,
	}
	for key in overrides:
		c[key] = overrides[key]
	return c

static func battle(overrides: Dictionary = {}) -> Dictionary:
	var b = {
		"battle_id": 1,
		"mode": "wild",
		"side_a_party": [creature()],
		"side_b_party": [creature({"types": ["sweet"]})],
		"side_a_active_idx": 0,
		"side_b_active_idx": 0,
		"weather": "",
		"weather_turns": 0,
		"side_a_hazards": [],
		"side_b_hazards": [],
		"trick_room_turns": 0,
		"turn": 1,
		"trainer_id": "",
	}
	for key in overrides:
		b[key] = overrides[key]
	return b
