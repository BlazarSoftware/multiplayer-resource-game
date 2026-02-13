class_name HeldItemEffects
extends RefCounted

# Dispatches held item effects at various trigger points in battle.
# All functions are static and operate on creature dictionaries.

static func on_damage_calc(item_id: String, move, damage: int) -> int:
	if item_id == "" or damage <= 0:
		return damage
	var item = DataRegistry.get_held_item(item_id)
	if item == null:
		return damage

	if item.effect_type == "type_boost":
		var boost_type = item.effect_params.get("type", "")
		if move.type == boost_type:
			return int(damage * item.effect_params.get("multiplier", 1.0))
	return damage

static func on_damage_received(item_id: String, move, damage: int) -> int:
	if item_id == "" or damage <= 0:
		return damage
	var item = DataRegistry.get_held_item(item_id)
	if item == null:
		return damage

	if item.effect_type == "damage_reduction":
		var category = item.effect_params.get("category", "")
		if move.category == category:
			return int(damage * item.effect_params.get("multiplier", 1.0))
	return damage

static func end_of_turn(creature: Dictionary) -> int:
	var item_id = creature.get("held_item_id", "")
	if item_id == "":
		return 0
	var item = DataRegistry.get_held_item(item_id)
	if item == null:
		return 0

	if item.effect_type == "end_of_turn":
		var heal_pct = item.effect_params.get("heal_percent", 0.0)
		if heal_pct > 0:
			var heal = max(1, int(creature.get("max_hp", 40) * heal_pct))
			creature["hp"] = min(creature.get("max_hp", 40), creature.get("hp", 0) + heal)
			return heal
	return 0

static func on_status_applied(creature: Dictionary) -> void:
	var item_id = creature.get("held_item_id", "")
	if item_id == "":
		return
	var item = DataRegistry.get_held_item(item_id)
	if item == null:
		return

	if item.effect_type == "on_status" and item.effect_params.get("cure_status", false):
		# Ginger Root: cure status and consume
		creature["status"] = ""
		creature["status_turns"] = 0
		if item.consumable:
			creature["held_item_id"] = ""

static func on_hp_threshold(creature: Dictionary) -> Dictionary:
	var item_id = creature.get("held_item_id", "")
	if item_id == "":
		return {}
	var item = DataRegistry.get_held_item(item_id)
	if item == null:
		return {}

	if item.effect_type != "on_hp_threshold":
		return {}

	var hp = creature.get("hp", 0)
	var max_hp = creature.get("max_hp", 40)
	var threshold = item.effect_params.get("hp_threshold", 0.25)
	if float(hp) / float(max_hp) > threshold:
		return {}

	# Check if already triggered (prevent double-trigger)
	if creature.get("_item_threshold_triggered", false):
		return {}
	creature["_item_threshold_triggered"] = true

	var result = {}

	# Espresso Shot: boost speed
	if item.effect_params.has("stat"):
		var stat = item.effect_params.get("stat", "speed")
		var mult = item.effect_params.get("multiplier", 1.5)
		var base = creature.get(stat, 10)
		creature[stat] = int(float(base) * mult)
		result["stat_boost"] = stat
		result["message"] = "used its " + item.display_name + "!"

	# Golden Truffle: heal
	if item.effect_params.has("heal_percent"):
		var heal_pct = item.effect_params.get("heal_percent", 0.25)
		var heal = max(1, int(max_hp * heal_pct))
		creature["hp"] = min(max_hp, hp + heal)
		result["heal"] = heal
		result["message"] = "used its " + item.display_name + "!"

	if item.consumable:
		creature["held_item_id"] = ""

	return result
