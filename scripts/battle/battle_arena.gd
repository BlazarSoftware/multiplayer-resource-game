extends Node3D

# 3D Battle Arena — client-only visual scene built programmatically.
# No class_name (not needed outside battle_arena_ui.gd which creates it directly).

const BATTLE_ARENA_OFFSET = Vector3(8000, 0, 0)

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

const WEATHER_LIGHT_COLORS = {
	"spicy": Color(1.0, 0.5, 0.2),
	"sweet": Color(1.0, 0.7, 0.9),
	"sour": Color(0.7, 0.9, 0.3),
	"herbal": Color(0.3, 0.8, 0.4),
	"umami": Color(0.6, 0.5, 0.7),
	"grain": Color(0.8, 0.7, 0.4),
}

# Camera presets (relative to BATTLE_ARENA_OFFSET via local coords)
const CAM_NEUTRAL = { "pos": Vector3(0, 5, 8), "rot": Vector3(-25, 0, 0), "fov": 55.0 }
const CAM_PLAYER_ATTACK = { "pos": Vector3(-2, 3, 5), "rot": Vector3(-15, 15, 0), "fov": 50.0 }
const CAM_ENEMY_ATTACK = { "pos": Vector3(2, 3, -1), "rot": Vector3(-15, -15, 0), "fov": 50.0 }

# Node references (set during build)
var arena_camera: Camera3D
var player_side: Node3D
var enemy_side: Node3D
var trainer_node: Node3D
var opponent_node: Node3D
var weather_light: OmniLight3D

# Per-side data
var _player_creature_mesh: MeshInstance3D
var _enemy_creature_mesh: MeshInstance3D

func build_arena(battle_mode: int, enemy_data: Dictionary, opponent_name: String) -> void:
	position = BATTLE_ARENA_OFFSET

	# Ground plane
	var ground = MeshInstance3D.new()
	ground.name = "GroundPlane"
	var ground_mesh = BoxMesh.new()
	ground_mesh.size = Vector3(20, 0.1, 12)
	ground.mesh = ground_mesh
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.45, 0.38, 0.28)
	ground.set_surface_override_material(0, ground_mat)
	ground.position = Vector3(0, -0.05, 0)
	add_child(ground)

	# Arena border ring
	var border = MeshInstance3D.new()
	border.name = "ArenaBorder"
	var border_mesh = CylinderMesh.new()
	border_mesh.top_radius = 9.5
	border_mesh.bottom_radius = 9.5
	border_mesh.height = 0.15
	border.mesh = border_mesh
	var border_mat = StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.6, 0.5, 0.35)
	border.set_surface_override_material(0, border_mat)
	border.position = Vector3(0, 0.02, 0)
	add_child(border)

	# Directional light
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "ArenaLight"
	dir_light.rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), 0)
	dir_light.light_energy = 1.2
	dir_light.shadow_enabled = true
	add_child(dir_light)

	# Ambient fill
	var fill = OmniLight3D.new()
	fill.name = "AmbientFill"
	fill.position = Vector3(0, 4, 0)
	fill.light_energy = 0.4
	fill.omni_range = 15.0
	fill.light_color = Color(0.95, 0.9, 0.8)
	add_child(fill)

	# Camera
	arena_camera = Camera3D.new()
	arena_camera.name = "ArenaCamera"
	arena_camera.position = CAM_NEUTRAL.pos
	arena_camera.rotation = Vector3(deg_to_rad(CAM_NEUTRAL.rot.x), deg_to_rad(CAM_NEUTRAL.rot.y), 0)
	arena_camera.fov = CAM_NEUTRAL.fov
	add_child(arena_camera)

	# Player side
	player_side = Node3D.new()
	player_side.name = "PlayerSide"
	player_side.position = Vector3(0, 0, 3)
	add_child(player_side)
	_build_creature_side(player_side, "player")

	# Enemy side
	enemy_side = Node3D.new()
	enemy_side.name = "EnemySide"
	enemy_side.position = Vector3(0, 0, -3)
	add_child(enemy_side)
	_build_creature_side(enemy_side, "enemy")

	# Trainer node (only for trainer battles)
	if battle_mode == 1: # TRAINER
		_build_trainer_node(enemy_data)
	elif battle_mode == 2: # PVP
		_build_opponent_node(opponent_name)

	# Weather light
	weather_light = OmniLight3D.new()
	weather_light.name = "WeatherLight"
	weather_light.position = Vector3(0, 6, 0)
	weather_light.omni_range = 18.0
	weather_light.light_energy = 0.0
	weather_light.light_color = Color.WHITE
	add_child(weather_light)

	# Initial creature setup
	var active_idx = 0
	var bm = _get_battle_manager()
	if bm:
		active_idx = bm.client_active_creature_idx
	if active_idx < PlayerData.party.size():
		update_player_creature(PlayerData.party[active_idx])
	update_enemy_creature(enemy_data)

func _build_creature_side(side: Node3D, which: String) -> void:
	# Creature mesh placeholder
	var creature_mesh = MeshInstance3D.new()
	creature_mesh.name = "CreatureMesh"
	creature_mesh.position = Vector3(0, 1.0, 0)
	side.add_child(creature_mesh)

	# Store references
	if which == "player":
		_player_creature_mesh = creature_mesh
	else:
		_enemy_creature_mesh = creature_mesh

func _build_trainer_node(_enemy_data: Dictionary) -> void:
	trainer_node = Node3D.new()
	trainer_node.name = "TrainerNode"
	trainer_node.position = Vector3(-2, 0, -5)
	add_child(trainer_node)

	var trainer_mesh = MeshInstance3D.new()
	trainer_mesh.name = "TrainerMesh"
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	trainer_mesh.mesh = capsule
	var mat = StandardMaterial3D.new()
	# Color by difficulty
	var bm = _get_battle_manager()
	var trainer_id = ""
	if bm:
		trainer_id = bm.get("client_trainer_id") if "client_trainer_id" in bm else ""
	var trainer_def = DataRegistry.get_trainer(trainer_id) if trainer_id != "" else null
	var difficulty = trainer_def.ai_difficulty if trainer_def else "easy"
	match difficulty:
		"easy": mat.albedo_color = Color(0.3, 0.7, 0.3)
		"medium": mat.albedo_color = Color(0.8, 0.6, 0.2)
		"hard": mat.albedo_color = Color(0.8, 0.2, 0.2)
		_: mat.albedo_color = Color(0.5, 0.5, 0.5)
	trainer_mesh.set_surface_override_material(0, mat)
	trainer_mesh.position = Vector3(0, 0.9, 0)
	trainer_node.add_child(trainer_mesh)

	var trainer_label = Label3D.new()
	trainer_label.name = "TrainerLabel"
	trainer_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	trainer_label.font_size = UITheme.scaled(28)
	trainer_label.outline_size = 4
	var display_name = trainer_def.display_name if trainer_def else "Trainer"
	trainer_label.text = display_name
	trainer_label.modulate = Color(1.0, 0.9, 0.6)
	trainer_label.position = Vector3(0, 2.2, 0)
	trainer_node.add_child(trainer_label)

func _build_opponent_node(opponent_name: String) -> void:
	opponent_node = Node3D.new()
	opponent_node.name = "OpponentNode"
	opponent_node.position = Vector3(-2, 0, -5)
	add_child(opponent_node)

	var opp_mesh = MeshInstance3D.new()
	opp_mesh.name = "OpponentMesh"
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	opp_mesh.mesh = capsule
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.7)
	opp_mesh.set_surface_override_material(0, mat)
	opp_mesh.position = Vector3(0, 0.9, 0)
	opponent_node.add_child(opp_mesh)

	var opp_label = Label3D.new()
	opp_label.name = "OpponentLabel"
	opp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	opp_label.font_size = UITheme.scaled(28)
	opp_label.outline_size = 4
	opp_label.text = opponent_name
	opp_label.modulate = Color(0.8, 0.8, 1.0)
	opp_label.position = Vector3(0, 2.2, 0)
	opponent_node.add_child(opp_label)

# === CREATURE MESH HELPERS ===

func _create_creature_mesh_shape(species_id: String) -> Dictionary:
	var species = DataRegistry.get_species(species_id) if species_id != "" else null
	var mesh_type = species.mesh_type if species else "capsule"
	var mesh_color = species.mesh_color if species else Color.GRAY
	var mesh_scale = species.mesh_scale if species else Vector3.ONE

	var m: Mesh
	match mesh_type:
		"sphere":
			var s = SphereMesh.new()
			s.radius = 0.6
			s.height = 1.2
			m = s
		"box":
			var b = BoxMesh.new()
			b.size = Vector3(1.0, 1.0, 1.0)
			m = b
		"cylinder":
			var c = CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.2
			m = c
		_: # "capsule" or default
			var c = CapsuleMesh.new()
			c.radius = 0.45
			c.height = 1.2
			m = c

	var mat = StandardMaterial3D.new()
	mat.albedo_color = mesh_color
	return {"mesh": m, "material": mat, "scale": mesh_scale}

func update_player_creature(creature_data: Dictionary) -> void:
	if _player_creature_mesh == null:
		return
	var species_id = creature_data.get("species_id", "")
	var result = _create_creature_mesh_shape(species_id)
	_player_creature_mesh.mesh = result.mesh
	_player_creature_mesh.set_surface_override_material(0, result.material)
	_player_creature_mesh.scale = result.scale

func update_enemy_creature(enemy_data: Dictionary) -> void:
	if _enemy_creature_mesh == null:
		return
	var species_id = enemy_data.get("species_id", "")
	var result = _create_creature_mesh_shape(species_id)
	_enemy_creature_mesh.mesh = result.mesh
	_enemy_creature_mesh.set_surface_override_material(0, result.material)
	_enemy_creature_mesh.scale = result.scale

# === CAMERA CUT SYSTEM (Pokemon Stadium hard cuts) ===

func cut_camera(preset: String) -> void:
	if arena_camera == null:
		return
	var cam_data: Dictionary
	match preset:
		"player_attack":
			cam_data = CAM_PLAYER_ATTACK
		"enemy_attack":
			cam_data = CAM_ENEMY_ATTACK
		_:
			cam_data = CAM_NEUTRAL
	arena_camera.position = cam_data.pos
	arena_camera.rotation = Vector3(deg_to_rad(cam_data.rot.x), deg_to_rad(cam_data.rot.y), deg_to_rad(cam_data.rot.z))
	arena_camera.fov = cam_data.fov

# === CREATURE POSITION HELPER ===

func get_creature_position(side: String) -> Vector3:
	if side == "player":
		return player_side.global_position + Vector3(0, 1.0, 0)
	return enemy_side.global_position + Vector3(0, 1.0, 0)

# === HP TINT COLOR (used by UI cards) ===

func _hp_tint_color(pct: float) -> Color:
	if pct > 0.5:
		return UITokens.STAMP_GREEN
	if pct > 0.25:
		return UITokens.STAMP_GOLD
	return UITokens.STAMP_RED

# === WEATHER ===

func update_weather(weather_type: String) -> void:
	if weather_light == null:
		return
	if weather_type == "":
		weather_light.light_energy = 0.0
		return
	weather_light.light_energy = 0.6
	weather_light.light_color = WEATHER_LIGHT_COLORS.get(weather_type, Color.WHITE)

# === VISUAL EFFECTS ===

func flash_creature(side: String) -> void:
	var mesh_node: MeshInstance3D
	if side == "player":
		mesh_node = _player_creature_mesh
	else:
		mesh_node = _enemy_creature_mesh
	if mesh_node == null:
		return
	var mat = mesh_node.get_surface_override_material(0) as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 3.0
	var tween = create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.2)
	tween.tween_callback(func():
		mat.emission_enabled = false
	)

func camera_shake(duration: float = 0.3, intensity: float = 0.15) -> void:
	if arena_camera == null:
		return
	var original_pos = arena_camera.position
	var tween = create_tween()
	var steps = 6
	var step_dur = duration / steps
	for i in range(steps):
		var offset = Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.5, intensity * 0.5)
		)
		tween.tween_property(arena_camera, "position", original_pos + offset, step_dur)
	tween.tween_property(arena_camera, "position", original_pos, step_dur)

func spawn_damage_number(amount: int, side: String, effectiveness: String = "") -> void:
	var spawn_pos: Vector3
	if side == "enemy":
		spawn_pos = enemy_side.position + Vector3(0, 2.5, 0)
	else:
		spawn_pos = player_side.position + Vector3(0, 2.5, 0)

	var label = Label3D.new()
	label.text = str(amount)
	label.font_size = UITheme.scaled(48)
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = spawn_pos

	match effectiveness:
		"super_effective":
			label.modulate = UITokens.STAMP_GREEN
		"not_very_effective":
			label.modulate = UITokens.STAMP_GOLD
		_:
			label.modulate = Color(1, 1, 1)

	add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", spawn_pos.y + 2.0, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

# === CREATURE ENTRY ANIMATION ===

func play_creature_entry(side: String) -> void:
	var mesh_node: MeshInstance3D
	if side == "player":
		mesh_node = _player_creature_mesh
	else:
		mesh_node = _enemy_creature_mesh
	if mesh_node == null:
		return
	var target_scale = mesh_node.scale
	mesh_node.scale = Vector3.ZERO
	var tween = create_tween()
	tween.tween_property(mesh_node, "scale", target_scale, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

# === SWAP ANIMATION ===

func swap_creature_animation(side: String, new_creature_data: Dictionary) -> void:
	var mesh_node: MeshInstance3D
	if side == "player":
		mesh_node = _player_creature_mesh
	else:
		mesh_node = _enemy_creature_mesh
	if mesh_node == null:
		if side == "player":
			update_player_creature(new_creature_data)
		else:
			update_enemy_creature(new_creature_data)
		return

	# Shrink out
	var tween = create_tween()
	tween.tween_property(mesh_node, "scale", Vector3.ZERO, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if side == "player":
			update_player_creature(new_creature_data)
		else:
			update_enemy_creature(new_creature_data)
		mesh_node.scale = Vector3.ZERO
	)
	# Grow in
	var target_scale = Vector3.ONE
	var species = DataRegistry.get_species(new_creature_data.get("species_id", ""))
	if species:
		target_scale = species.mesh_scale
	tween.tween_property(mesh_node, "scale", target_scale, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _get_battle_manager() -> Node:
	return get_node_or_null("/root/Main/GameWorld/BattleManager")
