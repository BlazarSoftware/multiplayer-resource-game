class_name MockMove
extends RefCounted

# Factory for creating MoveDef Resources for testing without DataRegistry.

static func physical(power: int = 50, type: String = "spicy", accuracy: int = 100) -> MoveDef:
	var m = MoveDef.new()
	m.move_id = "test_physical"
	m.display_name = "Test Physical"
	m.category = "physical"
	m.power = power
	m.type = type
	m.accuracy = accuracy
	m.pp = 10
	m.is_contact = true
	return m

static func special(power: int = 50, type: String = "sweet", accuracy: int = 100) -> MoveDef:
	var m = MoveDef.new()
	m.move_id = "test_special"
	m.display_name = "Test Special"
	m.category = "special"
	m.power = power
	m.type = type
	m.accuracy = accuracy
	m.pp = 10
	return m

static func status(status_effect: String = "burned", chance: int = 100) -> MoveDef:
	var m = MoveDef.new()
	m.move_id = "test_status"
	m.display_name = "Test Status"
	m.category = "status"
	m.power = 0
	m.type = "spicy"
	m.accuracy = 100
	m.pp = 10
	m.status_effect = status_effect
	m.status_chance = chance
	return m

static func with_props(overrides: Dictionary) -> MoveDef:
	var m = MoveDef.new()
	m.move_id = overrides.get("move_id", "test_move")
	m.display_name = overrides.get("display_name", "Test Move")
	m.type = overrides.get("type", "spicy")
	m.category = overrides.get("category", "physical")
	m.power = overrides.get("power", 50)
	m.accuracy = overrides.get("accuracy", 100)
	m.pp = overrides.get("pp", 10)
	m.priority = overrides.get("priority", 0)
	m.status_effect = overrides.get("status_effect", "")
	m.status_chance = overrides.get("status_chance", 0)
	m.stat_changes = overrides.get("stat_changes", {})
	m.heal_percent = overrides.get("heal_percent", 0.0)
	m.drain_percent = overrides.get("drain_percent", 0.0)
	m.is_contact = overrides.get("is_contact", false)
	m.recoil_percent = overrides.get("recoil_percent", 0.0)
	m.multi_hit_min = overrides.get("multi_hit_min", 0)
	m.multi_hit_max = overrides.get("multi_hit_max", 0)
	m.is_protection = overrides.get("is_protection", false)
	m.weather_set = overrides.get("weather_set", "")
	m.hazard_type = overrides.get("hazard_type", "")
	m.clears_hazards = overrides.get("clears_hazards", false)
	m.switch_after = overrides.get("switch_after", false)
	m.force_switch = overrides.get("force_switch", false)
	m.trick_room = overrides.get("trick_room", false)
	m.taunt = overrides.get("taunt", false)
	m.encore = overrides.get("encore", false)
	m.substitute = overrides.get("substitute", false)
	m.knock_off = overrides.get("knock_off", false)
	m.self_crit_stage_change = overrides.get("self_crit_stage_change", 0)
	return m
