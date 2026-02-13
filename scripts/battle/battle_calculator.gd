class_name BattleCalculator
extends RefCounted

# Type effectiveness chart
# super effective = 2.0, not very effective = 0.5, neutral = 1.0
const TYPE_CHART: Dictionary = {
	"spicy": {"sweet": 2.0, "herbal": 2.0, "sour": 0.5, "umami": 0.5},
	"sweet": {"sour": 2.0, "umami": 2.0, "spicy": 0.5, "grain": 0.5},
	"sour": {"spicy": 2.0, "grain": 2.0, "sweet": 0.5, "herbal": 0.5},
	"herbal": {"sour": 2.0, "sweet": 2.0, "spicy": 0.5, "umami": 0.5},
	"umami": {"herbal": 2.0, "spicy": 2.0, "sweet": 0.5, "grain": 0.5},
	"grain": {"sweet": 2.0, "umami": 2.0, "sour": 0.5, "herbal": 0.5},
}

static func get_type_effectiveness(attack_type: String, defender_types: Array) -> float:
	if attack_type == "":
		return 1.0
	var multiplier = 1.0
	var chart = TYPE_CHART.get(attack_type, {})
	for def_type in defender_types:
		multiplier *= chart.get(def_type, 1.0)
	return multiplier

static func calculate_damage(attacker: Dictionary, defender: Dictionary, move, level: int, weather: String = "") -> Dictionary:
	if move.category == "status":
		return {"damage": 0, "effectiveness": 1.0, "critical": false}

	# Get attacking and defending stats
	var atk: float
	var def_stat: float
	if move.category == "physical":
		atk = float(attacker.get("attack", 10))
		def_stat = float(defender.get("defense", 10))
	else: # special
		atk = float(attacker.get("sp_attack", 10))
		def_stat = float(defender.get("sp_defense", 10))

	# Apply stat stages
	atk *= _stage_multiplier(attacker.get("attack_stage", 0) if move.category == "physical" else attacker.get("sp_attack_stage", 0))
	def_stat *= _stage_multiplier(defender.get("defense_stage", 0) if move.category == "physical" else defender.get("sp_defense_stage", 0))

	# Base damage formula (Pokemon-style)
	var base = ((2.0 * level / 5.0 + 2.0) * move.power * atk / def_stat) / 50.0 + 2.0

	# Type effectiveness
	var defender_types = defender.get("types", [])
	if defender_types is PackedStringArray:
		defender_types = Array(defender_types)
	var effectiveness = get_type_effectiveness(move.type, defender_types)
	base *= effectiveness

	# Weather modifier
	var weather_mod = FieldEffects.get_weather_modifier(weather, move.type)
	base *= weather_mod

	# Random factor (0.85 - 1.0)
	var random_factor = randf_range(0.85, 1.0)
	base *= random_factor

	# Critical hit (6.25% chance, 1.5x damage)
	var critical = randf() < 0.0625
	if critical:
		base *= 1.5

	# STAB (Same Type Attack Bonus)
	var attacker_types = attacker.get("types", [])
	if attacker_types is PackedStringArray:
		attacker_types = Array(attacker_types)
	if move.type in attacker_types:
		base *= 1.5

	var final_damage = max(1, int(base))
	return {"damage": final_damage, "effectiveness": effectiveness, "critical": critical}

static func _stage_multiplier(stage: int) -> float:
	stage = clampi(stage, -6, 6)
	if stage >= 0:
		return (2.0 + stage) / 2.0
	else:
		return 2.0 / (2.0 - stage)

static func check_accuracy(move, attacker: Dictionary, defender: Dictionary) -> bool:
	if move.accuracy <= 0 or move.accuracy >= 100:
		return true
	var acc = float(move.accuracy)
	# Apply accuracy/evasion stages
	var acc_stage = attacker.get("accuracy_stage", 0)
	var eva_stage = defender.get("evasion_stage", 0)
	var net_stage = clampi(acc_stage - eva_stage, -6, 6)
	acc *= _accuracy_stage_multiplier(net_stage)
	return randf() * 100.0 < acc

static func _accuracy_stage_multiplier(stage: int) -> float:
	# Accuracy/evasion uses 3/3, 3/4, 3/5... for negative and 3/3, 4/3, 5/3... for positive
	stage = clampi(stage, -6, 6)
	if stage >= 0:
		return (3.0 + stage) / 3.0
	else:
		return 3.0 / (3.0 - stage)

static func get_speed(creature: Dictionary) -> int:
	var base_speed = creature.get("speed", 10)
	var stage = creature.get("speed_stage", 0)
	return int(float(base_speed) * _stage_multiplier(stage))

static func apply_status_damage(creature: Dictionary, status: String) -> int:
	var max_hp = creature.get("max_hp", 40)
	match status:
		"burned", "poisoned":
			return max(1, max_hp / 8)
		_:
			return 0

static func can_act(creature: Dictionary) -> bool:
	var status = creature.get("status", "")
	match status:
		"frozen":
			# 25% chance to thaw each turn
			if randf() < 0.25:
				creature["status"] = ""
				creature["status_turns"] = 0
				return true
			return false
		"drowsy":
			# 50% chance to skip turn
			return randf() > 0.5
		_:
			return true

static func apply_stat_changes(creature: Dictionary, changes: Dictionary) -> Dictionary:
	var results = {}
	for stat in changes:
		var stage_key = stat + "_stage"
		var current = creature.get(stage_key, 0)
		var change = changes[stat]
		var new_val = clampi(current + change, -6, 6)
		creature[stage_key] = new_val
		results[stat] = change
	return results

static func get_effectiveness_text(effectiveness: float) -> String:
	if effectiveness >= 2.0:
		return "super_effective"
	elif effectiveness <= 0.5:
		return "not_very_effective"
	else:
		return "neutral"
