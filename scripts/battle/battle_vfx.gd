extends RefCounted

# BinbunVFX scene-based VFX spawner for battle effects.
# Layers rich scene effects on top of existing GPUParticles3D (BattleEffects).
# All methods static. Fire-and-forget: scenes auto-free after duration.

const _VFX_BASE = "res://assets/vfx/"

# Hit effects by effectiveness/crit
const HIT_EFFECTS: Dictionary = {
	"default": _VFX_BASE + "impact_explosions/assets/BinbunVFX/impact_explosions/effects/hit/vfx_hit_01.tscn",
	"super_effective": _VFX_BASE + "impact_explosions/assets/BinbunVFX/impact_explosions/effects/impact/vfx_impact_03.tscn",
	"not_very_effective": _VFX_BASE + "impact_explosions/assets/BinbunVFX/impact_explosions/effects/hit/vfx_hit_04.tscn",
	"critical": _VFX_BASE + "impact_explosions/assets/BinbunVFX/impact_explosions/effects/explosion/vfx_explosion_02.tscn",
}

# Move category fallback effects
const MOVE_CATEGORY_EFFECTS: Dictionary = {
	"physical": _VFX_BASE + "impact_explosions/assets/BinbunVFX/impact_explosions/effects/impact/vfx_impact_01.tscn",
	"special": _VFX_BASE + "magic_orbs/assets/BinbunVFX/magic_orbs/effects/magic_orb_flash/magic_orb_flash_vfx_01.tscn",
	"status": _VFX_BASE + "magic_areas/assets/BinbunVFX/magic_areas/effects/ripple_area/ripple_area_vfx_01.tscn",
}

# Type-specific move overrides (highest priority)
const TYPE_OVERRIDE_EFFECTS: Dictionary = {
	"spicy": _VFX_BASE + "fire_effects/assets/BinbunVFX/fire_effects/effects/Fire/fire_ball_01.tscn",
	"toxic": _VFX_BASE + "poison_effects/assets/BinbunVFX/poison_effects/effects/poison_cloud/poison_cloud_vfx_01.tscn",
	"smoked": _VFX_BASE + "smoke_effects/assets/BinbunVFX/smoke_effects/effects/smoke/smoke_vfx_01.tscn",
	"mineral": _VFX_BASE + "ice_effects/assets/BinbunVFX/ice_effects/effects/ice_shard/ice_shard_vfx_01.tscn",
	"liquid": _VFX_BASE + "magic_orbs/assets/BinbunVFX/magic_orbs/effects/magic_orb_big/magic_orb_big_vfx_03.tscn",
	"aromatic": _VFX_BASE + "magic_areas/assets/BinbunVFX/magic_areas/effects/pulse_area/pulse_area_vfx_01.tscn",
	"sweet": _VFX_BASE + "magic_orbs/assets/BinbunVFX/magic_orbs/effects/magic_orb_flare/magic_orb_flare_vfx_02.tscn",
	"sour": _VFX_BASE + "poison_effects/assets/BinbunVFX/poison_effects/effects/poison_bubble/poison_bubble_vfx_01.tscn",
	"herbal": _VFX_BASE + "magic_areas/assets/BinbunVFX/magic_areas/effects/lift_area/lift_area_vfx_02.tscn",
	"earthy": _VFX_BASE + "smoke_effects/assets/BinbunVFX/smoke_effects/effects/smoke_big/smoke_big_vfx_02.tscn",
	"protein": _VFX_BASE + "impact_explosions/assets/BinbunVFX/impact_explosions/effects/impact/impact_vfx_05.tscn",
	"grain": _VFX_BASE + "magic_projectiles/assets/BinbunVFX/magic_projectiles/effects/mprojectile_wave/mprojectile_wave_vfx_01.tscn",
	"tropical": _VFX_BASE + "magic_orbs/assets/BinbunVFX/magic_orbs/effects/magic_orb_basic/magic_orb_basic_vfx_01.tscn",
	"dairy": _VFX_BASE + "ice_effects/assets/BinbunVFX/ice_effects/effects/ice_mist/ice_mist_vfx_01.tscn",
	"bitter": _VFX_BASE + "smoke_effects/assets/BinbunVFX/smoke_effects/effects/smoke_thin/smoke_thin_vfx_03.tscn",
	"fermented": _VFX_BASE + "poison_effects/assets/BinbunVFX/poison_effects/effects/stink_big/stink_big_vfx_01.tscn",
	"spoiled": _VFX_BASE + "poison_effects/assets/BinbunVFX/poison_effects/effects/stink_small/stink_small_vfx_02.tscn",
	"umami": _VFX_BASE + "magic_areas/assets/BinbunVFX/magic_areas/effects/basic_area/basic_area_vfx_01.tscn",
}

# Status aura effects (looping, attach to creature)
const STATUS_AURA_EFFECTS: Dictionary = {
	"burned": _VFX_BASE + "fire_effects/assets/BinbunVFX/fire_effects/effects/Fire/fire_area_01.tscn",
	"frozen": _VFX_BASE + "ice_effects/assets/BinbunVFX/ice_effects/effects/ice_area/ice_area_vfx_01.tscn",
	"poisoned": _VFX_BASE + "poison_effects/assets/BinbunVFX/poison_effects/effects/stink_small/stink_small_vfx_01.tscn",
	"drowsy": _VFX_BASE + "smoke_effects/assets/BinbunVFX/smoke_effects/effects/smoke_thin/smoke_thin_vfx_01.tscn",
	"wilted": _VFX_BASE + "poison_effects/assets/BinbunVFX/poison_effects/effects/poison_puddle/poison_puddle_vfx_01.tscn",
	"soured": _VFX_BASE + "poison_effects/assets/BinbunVFX/poison_effects/effects/poison_bubble/poison_bubble_vfx_03.tscn",
	"brined": _VFX_BASE + "ice_effects/assets/BinbunVFX/ice_effects/effects/ice_mist/ice_mist_vfx_02.tscn",
}

# Preloaded scene cache to avoid repeated disk access
static var _scene_cache: Dictionary = {}

static func _load_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var scene = load(path) as PackedScene
	_scene_cache[path] = scene
	return scene

static func spawn_vfx(parent: Node3D, pos: Vector3, scene_path: String, duration: float = 2.0) -> Node3D:
	var scene = _load_scene(scene_path)
	if scene == null:
		return null
	var instance = scene.instantiate() as Node3D
	if instance == null:
		return null
	instance.position = pos - parent.global_position
	parent.add_child(instance)
	# Auto-free after duration
	var tree = parent.get_tree()
	if tree:
		var timer = tree.create_timer(duration)
		timer.timeout.connect(func():
			if is_instance_valid(instance):
				instance.queue_free()
		)
	return instance

static func spawn_hit_vfx(parent: Node3D, pos: Vector3, effectiveness: String, is_critical: bool) -> void:
	var path: String
	if is_critical:
		path = HIT_EFFECTS.get("critical", HIT_EFFECTS["default"])
	elif effectiveness == "super_effective":
		path = HIT_EFFECTS.get("super_effective", HIT_EFFECTS["default"])
	elif effectiveness == "not_very_effective":
		path = HIT_EFFECTS.get("not_very_effective", HIT_EFFECTS["default"])
	else:
		path = HIT_EFFECTS["default"]
	spawn_vfx(parent, pos, path, 1.5)

static func spawn_move_vfx(parent: Node3D, pos: Vector3, move_type: String, category: String) -> void:
	# Type override takes priority, then category fallback
	var path = TYPE_OVERRIDE_EFFECTS.get(move_type, "")
	if path == "":
		path = MOVE_CATEGORY_EFFECTS.get(category, MOVE_CATEGORY_EFFECTS.get("physical", ""))
	if path != "":
		spawn_vfx(parent, pos, path, 2.0)

static func spawn_status_aura(parent: Node3D, creature_side_node: Node3D, status: String) -> Node3D:
	var path = STATUS_AURA_EFFECTS.get(status, "")
	if path == "":
		return null
	var scene = _load_scene(path)
	if scene == null:
		return null
	var instance = scene.instantiate() as Node3D
	if instance == null:
		return null
	instance.position = Vector3(0, 0.5, 0)
	creature_side_node.add_child(instance)
	return instance

static func clear_status_aura(aura_node: Node3D) -> void:
	if aura_node and is_instance_valid(aura_node):
		aura_node.queue_free()
