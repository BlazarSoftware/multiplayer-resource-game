extends Area3D

var nearby_peers: Dictionary = {} # peer_id -> true

func _ready() -> void:
	add_to_group("bank_npc")
	collision_mask = 3 # bits 1 + 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_visual()

func _create_visual() -> void:
	# Collision shape
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	col.shape = shape
	add_child(col)

	# NPC mesh (gold capsule for banker)
	var mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	mesh_instance.mesh = capsule
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.7, 0.2) # gold
	mesh_instance.set_surface_override_material(0, mat)
	mesh_instance.position.y = 0.75
	add_child(mesh_instance)

	# Label
	var label = Label3D.new()
	UITheme.style_label3d(label, "Bank", "npc_name")
	label.position.y = 2.0
	add_child(label)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if not body is CharacterBody3D:
		return
	var peer_id = body.name.to_int()
	if peer_id <= 0:
		return
	nearby_peers[peer_id] = true
	if body.get("is_busy"):
		return
	_show_bank_prompt.rpc_id(peer_id)

func _on_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if body is CharacterBody3D:
		var peer_id = body.name.to_int()
		nearby_peers.erase(peer_id)
		_hide_bank_prompt.rpc_id(peer_id)

@rpc("any_peer", "reliable")
func request_open_bank() -> void:
	if not multiplayer.is_server():
		return
	var peer_id = multiplayer.get_remote_sender_id()
	if peer_id not in nearby_peers:
		return
	# Check not busy/in battle
	var player_node = NetworkManager._get_player_node(peer_id)
	if player_node and player_node.get("is_busy"):
		return
	var battle_mgr = get_node_or_null("/root/Main/GameWorld/BattleManager")
	if battle_mgr and peer_id in battle_mgr.player_battle_map:
		return
	# Delegate to NetworkManager bank logic
	NetworkManager._handle_open_bank(peer_id)

@rpc("authority", "reliable")
func _show_bank_prompt() -> void:
	var hud = get_node_or_null("/root/Main/GameWorld/UI/HUD")
	if hud and hud.has_method("show_trainer_prompt"):
		hud.show_trainer_prompt("Bank [Deposit & Withdraw]")

@rpc("authority", "reliable")
func _hide_bank_prompt() -> void:
	var hud = get_node_or_null("/root/Main/GameWorld/UI/HUD")
	if hud and hud.has_method("hide_trainer_prompt"):
		hud.hide_trainer_prompt()
