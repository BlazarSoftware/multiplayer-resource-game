extends Area3D

## Server-authoritative dig spot. Players press E with shovel equipped to dig.
## Per-player, per-spot daily cooldown (resets each game day).

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

@export var spot_id: String = ""
@export var loot_table: Array = [] # [{item_id, weight, min, max}]
@export var dig_cooldown_days: int = 1

var _visual_mesh: MeshInstance3D = null

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
	# Visual: dirt mound
	_visual_mesh = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.4
	mesh.bottom_radius = 0.6
	mesh.height = 0.15
	_visual_mesh.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.2)
	_visual_mesh.set_surface_override_material(0, mat)
	_visual_mesh.position.y = 0.08
	add_child(_visual_mesh)
	# Subtle sparkle label
	var hint = Label3D.new()
	UITheme.style_label3d(hint, "~", "interaction_hint")
	hint.modulate = Color(UITokens.STAMP_GOLD.r, UITokens.STAMP_GOLD.g, UITokens.STAMP_GOLD.b, 0.75)
	hint.position = Vector3(0, 0.5, 0)
	add_child(hint)

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
