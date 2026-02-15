class_name AbilityEffects
extends RefCounted

# Dispatches ability effects at various trigger points in battle.
# All functions are static and operate on creature dictionaries.

static func on_enter(creature: Dictionary, foe: Dictionary, battle: Dictionary) -> Array:
	var messages: Array = []
	var ability_id = creature.get("ability_id", "")
	if ability_id == "":
		return messages
	var ability = DataRegistry.get_ability(ability_id)
	if ability == null:
		return messages

	match ability_id:
		"sour_aura":
			# Lower foe's Defense by 1 stage
			var stage_key = "defense_stage"
			foe[stage_key] = clampi(foe.get(stage_key, 0) - 1, -6, 6)
			messages.append({"message": "Sour Aura lowered foe's Defense!"})
		"grain_shield":
			# Raise own Defense by 1 during grain weather
			if battle.get("weather", "") == "grain":
				var stage_key = "defense_stage"
				creature[stage_key] = clampi(creature.get(stage_key, 0) + 1, -6, 6)
				messages.append({"message": "Grain Shield raised its Defense!"})

	return messages

static func on_attack(attacker: Dictionary, move, damage: int) -> Dictionary:
	var ability_id = attacker.get("ability_id", "")
	if ability_id == "" or damage <= 0:
		return {"damage": damage}

	match ability_id:
		"flash_fry":
			# Contact moves have 10% chance to burn (handled in status phase)
			pass
		"deep_umami":
			if move.type == "umami":
				return {"damage": int(damage * 1.3), "message": "Deep Umami boosted the attack!"}
		"sharp_zest":
			if move.type == "sour":
				return {"damage": int(damage * 1.3), "message": "Sharp Zest boosted the attack!"}
		"scoville_boost":
			if move.type == "spicy":
				return {"damage": int(damage * 1.3), "message": "Scoville Boost boosted the attack!"}
		"stretchy":
			if move.category == "physical":
				return {"damage": int(damage * 1.2), "message": "Stretchy boosted the attack!"}
	return {"damage": damage}

static func on_defend(defender: Dictionary, move, damage: int) -> Dictionary:
	var ability_id = defender.get("ability_id", "")
	if ability_id == "" or damage <= 0:
		return {"damage": damage}

	match ability_id:
		"brine_body":
			if move.category == "special":
				return {"damage": int(damage * 0.8), "message": "Brine Body weakened the attack!"}
		"crusty_armor":
			if move.category == "physical":
				return {"damage": int(damage * 0.8), "message": "Crusty Armor weakened the attack!"}
		"herbivore":
			# Herbal moves heal instead of dealing damage
			if move.type == "herbal":
				var heal = max(1, int(defender.get("max_hp", 40) * 0.25))
				defender["hp"] = min(defender.get("max_hp", 40), defender.get("hp", 0) + heal)
				return {"damage": 0, "message": "Herbivore absorbed the attack!", "heal": heal}
		"flavor_absorb":
			# Sweet moves heal instead of dealing damage
			if move.type == "sweet":
				var heal = max(1, int(defender.get("max_hp", 40) * 0.25))
				defender["hp"] = min(defender.get("max_hp", 40), defender.get("hp", 0) + heal)
				return {"damage": 0, "message": "Flavor Absorb absorbed the attack!", "heal": heal}
		"flash_freeze":
			# 15% chance to freeze attacker on contact
			if move.is_contact and randf() < 0.15:
				# We can't directly freeze the attacker from on_defend,
				# but we store a flag for the battle manager to process
				defender["_trigger_freeze_attacker"] = true
				return {"damage": damage, "message": "Flash Freeze may freeze the attacker!"}
	return {"damage": damage}

static func on_status_attempt(creature: Dictionary, status: String) -> Dictionary:
	# Returns {blocked: bool, message?: String}
	var ability_id = creature.get("ability_id", "")
	if ability_id == "":
		return {"blocked": false}

	match ability_id:
		"sugar_coat":
			# Immune to all status conditions
			if status != "stat_drop":
				return {"blocked": true, "message": "Sugar Coat blocked the status!"}
		"firm_press":
			# Blocks stat drops
			if status == "stat_drop":
				return {"blocked": true, "message": "Firm Press blocked the stat drop!"}
	return {"blocked": false}

static func end_of_turn(creature: Dictionary, weather: String) -> int:
	var ability_id = creature.get("ability_id", "")
	if ability_id == "":
		return 0

	var heal = 0
	match ability_id:
		"starter_culture":
			# Heals 6.25% HP per turn
			heal = max(1, int(creature.get("max_hp", 40) * 0.0625))
			creature["hp"] = min(creature.get("max_hp", 40), creature.get("hp", 0) + heal)
		"mycelium_net":
			# Heals 6.25% during umami weather
			if weather == "umami":
				heal = max(1, int(creature.get("max_hp", 40) * 0.0625))
				creature["hp"] = min(creature.get("max_hp", 40), creature.get("hp", 0) + heal)
		"photosynthesis":
			# Heals 12.5% during herbal weather
			if weather == "herbal":
				heal = max(1, int(creature.get("max_hp", 40) * 0.125))
				creature["hp"] = min(creature.get("max_hp", 40), creature.get("hp", 0) + heal)
	return heal

static func on_weather(creature: Dictionary, weather: String) -> Dictionary:
	var ability_id = creature.get("ability_id", "")
	if ability_id == "":
		return {}

	match ability_id:
		"fermentation":
			if weather == "sour":
				return {"speed_multiplier": 2.0}
	return {}
