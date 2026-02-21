extends Area3D

@export var shop_id: String = ""

var nearby_peers: Dictionary = {} # peer_id -> true
var _anim_state: Dictionary = {}

func _ready() -> void:
	add_to_group("shop_npc")
	collision_mask = 3 # bits 1 + 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_visual()

func _create_visual() -> void:
	DataRegistry.ensure_loaded()
	var shop = DataRegistry.get_shop(shop_id)
	var display_name = shop.display_name if shop else shop_id

	# Collision shape
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	col.shape = shape
	add_child(col)

	# Animated mannequin model (client only — server skips visuals)
	if not multiplayer.is_server():
		var config := {
			"idle": NpcAnimator.SHOP_ANIMS.get("idle", "Idle"),
			"actions": NpcAnimator.SHOP_ANIMS.get("actions", ["Yes"]),
			"color": Color(0.2, 0.7, 0.7),
		}
		_anim_state = NpcAnimator.create_character(self, config)

	# Label
	var label = Label3D.new()
	UITheme.style_label3d(label, display_name, "npc_name")
	label.position.y = 2.0
	add_child(label)

func _process(delta: float) -> void:
	if multiplayer.is_server():
		return
	NpcAnimator.update(_anim_state, delta, self)

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
	_show_shop_prompt.rpc_id(peer_id, shop_id)

func _on_body_exited(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if body is CharacterBody3D:
		var peer_id = body.name.to_int()
		nearby_peers.erase(peer_id)
		_hide_shop_prompt.rpc_id(peer_id)

@rpc("any_peer", "reliable")
func request_open_shop() -> void:
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
	# Send shop catalog to client
	DataRegistry.ensure_loaded()
	var shop = DataRegistry.get_shop(shop_id)
	if shop == null:
		return
	_open_shop_client.rpc_id(peer_id, shop_id, shop.display_name, shop.items_for_sale)

@rpc("authority", "reliable")
func _open_shop_client(sid: String, shop_name: String, catalog: Array) -> void:
	var shop_ui = get_node_or_null("/root/Main/GameWorld/UI/ShopUI")
	if shop_ui and shop_ui.has_method("open_shop"):
		shop_ui.open_shop(sid, shop_name, catalog)

@rpc("authority", "reliable")
func _show_shop_prompt(sid: String) -> void:
	NpcAnimator.play_reaction(_anim_state, "Counter_Show")
	var hud = get_node_or_null("/root/Main/GameWorld/UI/HUD")
	if hud and hud.has_method("show_trainer_prompt"):
		DataRegistry.ensure_loaded()
		var shop = DataRegistry.get_shop(sid)
		var name_text = shop.display_name if shop else sid
		hud.show_trainer_prompt(name_text + " [Shop]")

@rpc("authority", "reliable")
func _hide_shop_prompt() -> void:
	var hud = get_node_or_null("/root/Main/GameWorld/UI/HUD")
	if hud and hud.has_method("hide_trainer_prompt"):
		hud.hide_trainer_prompt()
