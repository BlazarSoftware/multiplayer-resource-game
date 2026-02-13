class_name FieldEffects
extends RefCounted

# Weather definitions: each weather boosts one type 1.5x and weakens another 0.5x
# Lasts 5 turns
const WEATHER_DATA: Dictionary = {
	"spicy": {"boost_type": "spicy", "weaken_type": "sweet", "name": "Sizzle Sun"},
	"sweet": {"boost_type": "sweet", "weaken_type": "sour", "name": "Sugar Hail"},
	"sour": {"boost_type": "sour", "weaken_type": "herbal", "name": "Acid Rain"},
	"herbal": {"boost_type": "herbal", "weaken_type": "spicy", "name": "Herb Breeze"},
	"umami": {"boost_type": "umami", "weaken_type": "grain", "name": "Umami Fog"},
	"grain": {"boost_type": "grain", "weaken_type": "umami", "name": "Grain Dust"},
}

const WEATHER_DURATION: int = 5

# Hazard definitions
# caltrops: 12.5% max HP damage on switch-in
# slippery_oil: -1 speed stage on switch-in
const HAZARD_DATA: Dictionary = {
	"caltrops": {"damage_percent": 0.125, "name": "Caltrops"},
	"slippery_oil": {"stat": "speed", "stages": -1, "name": "Slippery Oil"},
}

static func get_weather_modifier(weather: String, move_type: String) -> float:
	if weather == "" or move_type == "":
		return 1.0
	var data = WEATHER_DATA.get(weather, {})
	if data.is_empty():
		return 1.0
	if move_type == data.get("boost_type", ""):
		return 1.5
	if move_type == data.get("weaken_type", ""):
		return 0.5
	return 1.0

static func get_weather_name(weather: String) -> String:
	var data = WEATHER_DATA.get(weather, {})
	return data.get("name", "")

static func apply_hazards_on_switch(creature: Dictionary, hazards: Array) -> Array:
	var results = []
	for hazard in hazards:
		var data = HAZARD_DATA.get(hazard, {})
		if data.is_empty():
			continue
		if data.has("damage_percent"):
			var dmg = max(1, int(creature.get("max_hp", 40) * data.damage_percent))
			creature["hp"] = max(0, creature.get("hp", 0) - dmg)
			results.append({"type": "hazard_damage", "hazard": hazard, "damage": dmg, "message": "was hurt by " + data.get("name", hazard) + "!"})
		if data.has("stat"):
			var stage_key = data.stat + "_stage"
			var current = creature.get(stage_key, 0)
			var new_val = clampi(current + data.stages, -6, 6)
			creature[stage_key] = new_val
			results.append({"type": "hazard_stat", "hazard": hazard, "stat": data.stat, "stages": data.stages, "message": "'s Speed fell from " + data.get("name", hazard) + "!"})
	return results
