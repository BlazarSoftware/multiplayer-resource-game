extends Area3D

## Server-authoritative dig spot. Players press E with shovel equipped to dig.
## Per-player, per-spot daily cooldown (resets each game day).

const UITokens = preload("res://scripts/ui/ui_tokens.gd")
const EXCLAMATION_MODEL := "res://assets/synty_icons/Models/SM_Icon_ExclamationMark_01.glb"

@export var spot_id: String = ""
@export var loot_table: Array = [] # [{item_id, weight, min, max}]
@export var dig_cooldown_days: int = 1

var _icon_node: Node3D = null
var _ground_ring: MeshInstance3D = null
var _bob_time: float = 0.0
var _pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("dig_spot")
	# Collision for detection
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.5
	col.shape = shape
	add_child(col)
	collision_layer = 0
	collision_mask = 2
	_bob_time = randf() * TAU
	_pulse_time = randf() * TAU
	var is_headless := DisplayServer.get_name() == "headless"
	if not is_headless:
		_create_ground_ring()
		_create_floating_icon()

func _process(delta: float) -> void:
	if not _icon_node:
		return
	_bob_time += delta * 2.0
	_pulse_time += delta * 1.2
	# Bob up and down
	_icon_node.position.y = 1.5 + sin(_bob_time) * 0.15
	# Slow rotation
	_icon_node.rotation.y += delta * 1.2
	# Gentle scale pulse
	var s := 1.0 + sin(_pulse_time) * 0.06
	_icon_node.scale = Vector3(s, s, s)
	# Pulse ground ring alpha
	if _ground_ring:
		var ring_mat := _ground_ring.get_surface_override_material(0) as StandardMaterial3D
		if ring_mat:
			ring_mat.albedo_color.a = 0.25 + sin(_pulse_time * 1.5) * 0.1

func _create_floating_icon() -> void:
	if not ResourceLoader.exists(EXCLAMATION_MODEL):
		_create_fallback_label()
		return
	var scene := load(EXCLAMATION_MODEL) as PackedScene
	if not scene:
		_create_fallback_label()
		return
	_icon_node = Node3D.new()
	_icon_node.name = "IconPivot"
	var model := scene.instantiate()
	model.scale = Vector3(1.8, 1.8, 1.8)
	_icon_node.add_child(model)
	_icon_node.position.y = 1.5
	add_child(_icon_node)
	_apply_toon_to_node(model)

func _create_fallback_label() -> void:
	_icon_node = Node3D.new()
	_icon_node.name = "IconPivot"
	var lbl := Label3D.new()
	UITheme.style_label3d(lbl, "!", "interaction_hint")
	lbl.font_size = 64
	lbl.modulate = Color(UITokens.STAMP_GOLD.r, UITokens.STAMP_GOLD.g, UITokens.STAMP_GOLD.b, 0.9)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon_node.add_child(lbl)
	_icon_node.position.y = 1.5
	add_child(_icon_node)

func _create_ground_ring() -> void:
	_ground_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 0.9
	torus.rings = 32
	torus.ring_segments = 12
	_ground_ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(UITokens.STAMP_GOLD.r, UITokens.STAMP_GOLD.g, UITokens.STAMP_GOLD.b, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_ground_ring.set_surface_override_material(0, mat)
	_ground_ring.position.y = 0.02
	# Flatten the torus to sit on the ground
	_ground_ring.scale.y = 0.15
	add_child(_ground_ring)

@rpc("any_peer", "reliable")
func request_dig() -> void:
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	# Validate proximity
	var player_node = NetworkManager._get_player_node(sender)
	if player_node == null:
		return
	if player_node.global_position.distance_to(global_position) > 3.5:
		return
	# Check busy
	if player_node.get("is_busy"):
		return
	# Validate shovel equipped
	if sender not in NetworkManager.player_data_store:
		return
	var et = NetworkManager.player_data_store[sender].get("equipped_tools", {})
	if not et.has("shovel"):
		return
	# Cooldown check (server tool cooldown)
	if not NetworkManager.check_tool_cooldown(sender, "dig", "shovel"):
		return
	# Per-player per-spot daily cooldown
	var dig_cds = NetworkManager.player_data_store[sender].get("dig_cooldowns", {})
	var season_mgr = get_node_or_null("/root/Main/GameWorld/SeasonManager")
	var current_day: int = 0
	if season_mgr:
		current_day = int(season_mgr.total_day_count)
	var last_dig_day: int = int(dig_cds.get(spot_id, 0))
	if current_day > 0 and last_dig_day >= current_day:
		_dig_rejected.rpc_id(sender, "Already dug here today.")
		return
	# Record dig
	dig_cds[spot_id] = current_day
	NetworkManager.player_data_store[sender]["dig_cooldowns"] = dig_cds
	# Roll loot
	var found_items: Dictionary = {}
	for entry in loot_table:
		var item_id: String = str(entry.get("item_id", ""))
		var weight: float = float(entry.get("weight", 1.0))
		var min_qty: int = int(entry.get("min", 1))
		var max_qty: int = int(entry.get("max", 1))
		if randf() <= weight:
			var qty = randi_range(min_qty, max_qty)
			if qty > 0:
				if item_id in found_items:
					found_items[item_id] += qty
				else:
					found_items[item_id] = qty
	# If nothing rolled, give 1 of the first item as pity
	if found_items.is_empty() and loot_table.size() > 0:
		var fallback_id: String = str(loot_table[0].get("item_id", ""))
		if fallback_id != "":
			found_items[fallback_id] = 1
	# Check if player is in an excursion — route through shared loot
	var excursion_mgr = get_node_or_null("/root/Main/GameWorld/ExcursionManager")
	if excursion_mgr and excursion_mgr.is_player_in_excursion(sender):
		excursion_mgr._on_excursion_dig(sender, found_items)
		return

	# Grant items (standard single-player)
	for item_id in found_items:
		NetworkManager.server_add_inventory(sender, item_id, found_items[item_id])
	NetworkManager._sync_inventory_full.rpc_id(sender, NetworkManager.player_data_store[sender].get("inventory", {}))
	# Toast
	var loot_text = ""
	for item_id in found_items:
		DataRegistry.ensure_loaded()
		var info = DataRegistry.get_item_display_info(item_id)
		var dname: String = str(info.get("display_name", item_id))
		if loot_text != "":
			loot_text += ", "
		loot_text += "%s x%d" % [dname, found_items[item_id]]
	_dig_success.rpc_id(sender, loot_text)
	print("[DigSpot] ", sender, " dug at ", spot_id, " — found: ", loot_text)

@rpc("authority", "reliable")
func _dig_success(loot_text: String) -> void:
	var hud = get_node_or_null("/root/Main/GameWorld/UI/HUD")
	if hud and hud.has_method("show_toast"):
		hud.show_toast("Dug up: " + loot_text)

@rpc("authority", "reliable")
func _dig_rejected(reason: String) -> void:
	var hud = get_node_or_null("/root/Main/GameWorld/UI/HUD")
	if hud and hud.has_method("show_toast"):
		hud.show_toast(reason)

func sync_to_client(_peer_id: int) -> void:
	# Dig spots are stateless from a visual perspective (no destroyed state)
	pass


func _apply_toon_to_node(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var toon_shader = load("res://shaders/toon_icon.gdshader") as Shader
			var outline_shader = load("res://shaders/icon_outline.gdshader") as Shader
			if not toon_shader or not outline_shader:
				continue
			var toon_mat := ShaderMaterial.new()
			toon_mat.shader = toon_shader
			var orig_mat = mi.mesh.surface_get_material(i)
			if orig_mat is StandardMaterial3D:
				var std_mat := orig_mat as StandardMaterial3D
				if std_mat.albedo_texture:
					toon_mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
					toon_mat.set_shader_parameter("albedo_color", std_mat.albedo_color)
					toon_mat.set_shader_parameter("use_texture", true)
				else:
					toon_mat.set_shader_parameter("albedo_color", Color(0.6, 0.45, 0.2))
					toon_mat.set_shader_parameter("use_texture", false)
			else:
				toon_mat.set_shader_parameter("albedo_color", Color(0.6, 0.45, 0.2))
				toon_mat.set_shader_parameter("use_texture", false)
			var outline_mat := ShaderMaterial.new()
			outline_mat.shader = outline_shader
			toon_mat.next_pass = outline_mat
			mi.set_surface_override_material(i, toon_mat)
	for child in node.get_children():
		_apply_toon_to_node(child)
