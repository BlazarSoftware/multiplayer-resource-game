extends Area3D

@export var trainer_id: String = ""

var mesh_instance: MeshInstance3D = null
var label_3d: Label3D = null
var triggered_peers: Dictionary = {} # peer_id -> true (prevent re-triggering)

func _ready() -> void:
	# Detect players on collision layer 2 (players don't use layer 1 to avoid pushing each other)
	collision_mask = 3 # bits 1 + 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Create visual
	_create_visual()

func _create_visual() -> void:
	DataRegistry.ensure_loaded()
	var trainer = DataRegistry.get_trainer(trainer_id)
	var display_name = trainer.display_name if trainer else trainer_id

	# Collision shape
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	col.shape = shape
	add_child(col)

	# NPC mesh
	mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	mesh_instance.mesh = capsule
	var mat = StandardMaterial3D.new()
	# Color by difficulty
	if trainer:
		match trainer.ai_difficulty:
			"easy":
				mat.albedo_color = Color(0.3, 0.7, 0.3) # Green
			"medium":
				mat.albedo_color = Color(0.7, 0.7, 0.2) # Yellow
			"hard":
				mat.albedo_color = Color(0.8, 0.2, 0.2) # Red
			_:
				mat.albedo_color = Color(0.5, 0.5, 0.5)
	mesh_instance.set_surface_override_material(0, mat)
	mesh_instance.position.y = 0.75
	add_child(mesh_instance)

	# Label
	label_3d = Label3D.new()
	label_3d.text = display_name
	label_3d.font_size = 24
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.position.y = 2.0
	add_child(label_3d)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	# Only trigger for CharacterBody3D player nodes
	if not body is CharacterBody3D:
		return
	var peer_id = body.name.to_int()
	if peer_id <= 0:
		return
	# Don't re-trigger for same peer (until they leave and re-enter)
	if peer_id in triggered_peers:
		return
	triggered_peers[peer_id] = true
	print("[TrainerNPC] body_entered: peer ", peer_id, " near trainer '", trainer_id, "'")
	# Start trainer battle — check ALL battle types
	var battle_mgr = get_node_or_null("/root/Main/GameWorld/BattleManager")
	if battle_mgr:
		if peer_id in battle_mgr.player_battle_map:
			return # Already in any battle
		var encounter_mgr = get_node_or_null("/root/Main/GameWorld/EncounterManager")
		if encounter_mgr and encounter_mgr.is_in_encounter(peer_id):
			return # Already in wild encounter
		battle_mgr.server_start_trainer_battle(peer_id, trainer_id)

func _on_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if body is CharacterBody3D:
		var peer_id = body.name.to_int()
		triggered_peers.erase(peer_id)
