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

# Bond & IV system
@export var ivs: Dictionary = {} # {"hp": 0-31, "attack": 0-31, ...}
@export var battle_affinities: Dictionary = {} # {"attack": 5.2, "speed": 3.1, ...}
@export var bond_points: int = 0
@export var bond_level: int = 0 # 0-4, computed from bond_points thresholds

const BOND_THRESHOLDS: Array = [0, 50, 150, 300, 500]
const IV_STATS: Array = ["hp", "attack", "defense", "sp_attack", "sp_defense", "speed"]

static func create_from_species(species, lvl: int = 1) -> CreatureInstance:
	var inst = CreatureInstance.new()
	inst.species_id = species.species_id
	inst.nickname = species.display_name
	inst.level = lvl
	# Roll random IVs (0-31 per stat)
	inst.ivs = {}
	for stat in IV_STATS:
		inst.ivs[stat] = randi_range(0, 31)
	# Scale stats by level (+ EVs + IVs)
	var mult = 1.0 + (lvl - 1) * 0.1
	inst.max_hp = int(species.base_hp * mult) + inst.ivs.get("hp", 0)
	inst.hp = inst.max_hp
	inst.attack = int(species.base_attack * mult) + inst.ivs.get("attack", 0)
	inst.defense = int(species.base_defense * mult) + inst.ivs.get("defense", 0)
	inst.sp_attack = int(species.base_sp_attack * mult) + inst.ivs.get("sp_attack", 0)
	inst.sp_defense = int(species.base_sp_defense * mult) + inst.ivs.get("sp_defense", 0)
	inst.speed = int(species.base_speed * mult) + inst.ivs.get("speed", 0)
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
	inst.battle_affinities = {}
	inst.bond_points = 0
	inst.bond_level = 0
	return inst

static func compute_bond_level(points: int) -> int:
	for i in range(BOND_THRESHOLDS.size() - 1, -1, -1):
		if points >= BOND_THRESHOLDS[i]:
			return i
	return 0

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
		"ivs": ivs.duplicate(),
		"battle_affinities": battle_affinities.duplicate(),
		"bond_points": bond_points,
		"bond_level": bond_level,
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
	# Bond & IV system — auto-backfill IVs for old saves (like UUID backfill)
	inst.ivs = data.get("ivs", {})
	if inst.ivs.is_empty():
		for stat in IV_STATS:
			inst.ivs[stat] = randi_range(0, 31)
	inst.battle_affinities = data.get("battle_affinities", {})
	inst.bond_points = data.get("bond_points", 0)
	inst.bond_level = compute_bond_level(inst.bond_points)
	return inst
