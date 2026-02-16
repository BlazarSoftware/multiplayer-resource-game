extends Area3D

@export var npc_id: String = ""

var nearby_peers: Dictionary = {} # peer_id -> true

func _ready() -> void:
	add_to_group("social_npc")
	collision_mask = 3 # bits 1 + 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_visual()

func _create_visual() -> void:
	DataRegistry.ensure_loaded()
	var npc_def = DataRegistry.get_npc(npc_id)
	var display_name: String = npc_def.display_name if npc_def else npc_id
	var npc_color: Color = npc_def.visual_color if npc_def else Color(0.7, 0.5, 0.8)
	var occupation: String = npc_def.occupation if npc_def else ""

	# Collision shape
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	col.shape = shape
	add_child(col)

	# NPC mesh (capsule with occupation color)
	var mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.5
	mesh_instance.mesh = capsule
	var mat = StandardMaterial3D.new()
	mat.albedo_color = npc_color
	mesh_instance.set_surface_override_material(0, mat)
	mesh_instance.position.y = 0.75
	add_child(mesh_instance)

	# Name label
	var label = Label3D.new()
	var label_text = display_name
	if occupation != "":
		label_text += "\n[" + occupation + "]"
	label.text = label_text
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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
	_show_npc_prompt.rpc_id(peer_id, npc_id)

func _on_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if body is CharacterBody3D:
		var peer_id = body.name.to_int()
		nearby_peers.erase(peer_id)
		_hide_npc_prompt.rpc_id(peer_id)

@rpc("any_peer", "reliable")
func request_talk() -> void:
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
	# Delegate to SocialManager
	var social_mgr = get_node_or_null("/root/Main/GameWorld/SocialManager")
	if social_mgr:
		social_mgr.handle_talk_request(peer_id, npc_id)

@rpc("any_peer", "reliable")
func request_give_gift(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id = multiplayer.get_remote_sender_id()
	if peer_id not in nearby_peers:
		return
	var player_node = NetworkManager._get_player_node(peer_id)
	if player_node and player_node.get("is_busy"):
		return
	var battle_mgr = get_node_or_null("/root/Main/GameWorld/BattleManager")
	if battle_mgr and peer_id in battle_mgr.player_battle_map:
		return
	var social_mgr = get_node_or_null("/root/Main/GameWorld/SocialManager")
	if social_mgr:
		social_mgr.handle_gift_request(peer_id, npc_id, item_id)

@rpc("authority", "reliable")
func _show_npc_prompt(_npc_id: String) -> void:
	var hud = get_node_or_null("/root/Main/GameWorld/UI/HUD")
	if hud and hud.has_method("show_trainer_prompt"):
		DataRegistry.ensure_loaded()
		var npc_def = DataRegistry.get_npc(_npc_id)
		var name_text = npc_def.display_name if npc_def else _npc_id
		hud.show_trainer_prompt(name_text + " (E: Talk)")

@rpc("authority", "reliable")
func _hide_npc_prompt() -> void:
	var hud = get_node_or_null("/root/Main/GameWorld/UI/HUD")
	if hud and hud.has_method("hide_trainer_prompt"):
		hud.hide_trainer_prompt()
