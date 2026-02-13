class_name CreatureInstance
extends Resource

@export var species_id: String = ""
@export var nickname: String = ""
@export var level: int = 1
@export var hp: int = 0
@export var max_hp: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var sp_attack: int = 0
@export var sp_defense: int = 0
@export var speed: int = 0
@export var moves: PackedStringArray = []
@export var pp: PackedInt32Array = []
@export var types: PackedStringArray = []

# New fields for battle depth
@export var xp: int = 0
@export var xp_to_next: int = 100
@export var ability_id: String = ""
@export var held_item_id: String = ""
@export var evs: Dictionary = {} # e.g. {"attack": 4, "speed": 8}

static func create_from_species(species, lvl: int = 1) -> CreatureInstance:
	var inst = CreatureInstance.new()
	inst.species_id = species.species_id
	inst.nickname = species.display_name
	inst.level = lvl
	# Scale stats by level (+ EVs if any)
	var mult = 1.0 + (lvl - 1) * 0.1
	inst.max_hp = int(species.base_hp * mult)
	inst.hp = inst.max_hp
	inst.attack = int(species.base_attack * mult)
	inst.defense = int(species.base_defense * mult)
	inst.sp_attack = int(species.base_sp_attack * mult)
	inst.sp_defense = int(species.base_sp_defense * mult)
	inst.speed = int(species.base_speed * mult)
	inst.moves = species.moves.duplicate()
	inst.types = species.types.duplicate()
	# Set PP from move defs
	inst.pp.resize(species.moves.size())
	for i in range(species.moves.size()):
		var move = DataRegistry.get_move(species.moves[i])
		if move:
			inst.pp[i] = move.pp
		else:
			inst.pp[i] = 10
	# XP
	inst.xp = 0
	inst.xp_to_next = _calc_xp_to_next(lvl)
	# Randomly assign ability from species
	if species.ability_ids.size() > 0:
		inst.ability_id = species.ability_ids[randi() % species.ability_ids.size()]
	inst.evs = {}
	return inst

static func _calc_xp_to_next(lvl: int) -> int:
	# Simple cubic curve: XP needed grows with level
	return int(10 * lvl * lvl + 40 * lvl + 50)

func to_dict() -> Dictionary:
	return {
		"species_id": species_id,
		"nickname": nickname,
		"level": level,
		"hp": hp,
		"max_hp": max_hp,
		"attack": attack,
		"defense": defense,
		"sp_attack": sp_attack,
		"sp_defense": sp_defense,
		"speed": speed,
		"moves": Array(moves),
		"pp": Array(pp),
		"types": Array(types),
		"xp": xp,
		"xp_to_next": xp_to_next,
		"ability_id": ability_id,
		"held_item_id": held_item_id,
		"evs": evs.duplicate(),
	}

static func from_dict(data: Dictionary) -> CreatureInstance:
	var inst = CreatureInstance.new()
	inst.species_id = data.get("species_id", "")
	inst.nickname = data.get("nickname", "")
	inst.level = data.get("level", 1)
	inst.hp = data.get("hp", 1)
	inst.max_hp = data.get("max_hp", 1)
	inst.attack = data.get("attack", 10)
	inst.defense = data.get("defense", 10)
	inst.sp_attack = data.get("sp_attack", 10)
	inst.sp_defense = data.get("sp_defense", 10)
	inst.speed = data.get("speed", 10)
	inst.moves = PackedStringArray(data.get("moves", []))
	inst.pp = PackedInt32Array(data.get("pp", []))
	inst.types = PackedStringArray(data.get("types", []))
	inst.xp = data.get("xp", 0)
	inst.xp_to_next = data.get("xp_to_next", _calc_xp_to_next(inst.level))
	inst.ability_id = data.get("ability_id", "")
	inst.held_item_id = data.get("held_item_id", "")
	inst.evs = data.get("evs", {})
	return inst
