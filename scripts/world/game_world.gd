extends Node3D

const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const FARM_MANAGER_PATH: NodePath = "Zones/FarmZone/FarmManager"

@onready var players_node: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $Players/MultiplayerSpawner

# UI scenes (loaded at runtime for the local player)
var hud_scene = preload("res://scenes/ui/hud.tscn")
var battle_ui_scene = preload("res://scenes/battle/battle_arena_ui.tscn")
var crafting_ui_scene = preload("res://scenes/ui/crafting_ui.tscn")
var pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var storage_ui_scene = preload("res://scenes/ui/storage_ui.tscn")
var shop_ui_scene = preload("res://scenes/ui/shop_ui.tscn")
var trade_ui_scene = preload("res://scenes/ui/trade_ui.tscn")
var dialogue_ui_scene = preload("res://scenes/ui/dialogue_ui.tscn")
var calendar_ui_scene = preload("res://scenes/ui/calendar_ui.tscn")
var compass_ui_scene = preload("res://scenes/ui/compass_ui.tscn")
var creature_destination_ui_scene = preload("res://scenes/ui/creature_destination_ui.tscn")
var hotbar_ui_scene = preload("res://scenes/ui/hotbar_ui.tscn")
var excursion_hud_scene = preload("res://scenes/ui/excursion_hud.tscn")
var bank_ui_scene = preload("res://scenes/ui/bank_ui.tscn")

var _toon_shader: Shader = null

func _ready() -> void:
	# Initialize DataRegistry
	DataRegistry.ensure_loaded()
	_toon_shader = load("res://shaders/world_toon.gdshader")
	_apply_world_label_theme()

	# Generate world decorations for Cast Iron Cove
	_generate_town_paths()
	_generate_district_signs()
	_generate_town_decorations()
	_generate_encounter_zone_overlays()
	_generate_horizon()
	_generate_coastline()
	_generate_lighthouse()
	_generate_district_props()
	_generate_wilderness_terrain()
	_spawn_calendar_board()
	_spawn_bank_npc()
	_generate_harvestables()
	_generate_dig_spots()
	_spawn_excursion_entrance()
	_spawn_fishing_spots()

	# Spawn FishingManager on ALL peers (needed for RPC routing; non-server is inert)
	var fishing_mgr_script = load("res://scripts/world/fishing_manager.gd")
	var fishing_mgr = Node.new()
	fishing_mgr.name = "FishingManager"
	fishing_mgr.set_script(fishing_mgr_script)
	add_child(fishing_mgr)

	if not multiplayer.is_server():
		_setup_ui()
		_ensure_fallback_camera()
		return

	# Connect bank interest to day_changed
	var season_mgr = $SeasonManager
	if season_mgr and season_mgr.has_signal("day_changed"):
		season_mgr.day_changed.connect(NetworkManager._on_day_changed_bank_interest)

	# Server: load world state from save
	_load_world_state.call_deferred()

	# Spawn existing players
	for peer_id in NetworkManager.players:
		if peer_id != 1: # Don't spawn server "player"
			_spawn_player(peer_id)
	# Listen for new connections / disconnections
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _apply_world_label_theme() -> void:
	var label_roles := {
		"Zones/RestaurantZone/CraftingTable/StationLabel": "station",
		"Zones/RestaurantZone/Pantry/StationLabel": "station",
		"Zones/RestaurantZone/Workbench/StationLabel": "station",
		"Zones/WildZone/Cauldron/StationLabel": "station",
		"Zones/RestaurantRow/SignLabel": "landmark",
		"Zones/RestaurantRow/SubSign": "station",
	}
	for label_path in label_roles:
		var label_node := get_node_or_null(label_path)
		if label_node and label_node is Label3D:
			UITheme.style_label3d(label_node, "", label_roles[label_path])

func has_spawn_path_ready() -> bool:
	return (
		players_node != null
		and spawner != null
		and is_instance_valid(players_node)
		and is_instance_valid(spawner)
	)

func _load_world_state() -> void:
	# Async load: signal-based for API mode, immediate for file fallback
	SaveManager.world_loaded.connect(_on_world_loaded, CONNECT_ONE_SHOT)
	SaveManager.load_world_async()

func _on_world_loaded(world_data: Dictionary) -> void:
	if world_data.is_empty():
		print("[GameWorld] No saved world state, starting fresh")
		return
	print("[GameWorld] Loading saved world state...")
	# Load season/calendar data
	var season_mgr = $SeasonManager
	if season_mgr:
		var season_data: Dictionary = {
			"current_year": world_data.get("current_year", 1),
			"day_timer": world_data.get("day_timer", 0.0),
			"total_day_count": world_data.get("total_day_count", 1),
			"current_weather": world_data.get("current_weather", 0),
			# Backward compat keys (used if current_month is missing)
			"season_timer": world_data.get("season_timer", 0.0),
			"day_count": world_data.get("day_count", 1),
			"current_season": world_data.get("season", 0),
			"day_in_season": world_data.get("day_in_season", 1),
		}
		# Pass new-format keys if present
		if world_data.has("current_month"):
			season_data["current_month"] = world_data.get("current_month", 3)
			season_data["day_in_month"] = world_data.get("day_in_month", 1)
		season_mgr.load_save_data(season_data)
	# Load farm plot data
	var farm_mgr = get_node_or_null(FARM_MANAGER_PATH)
	if farm_mgr and world_data.has("farm_plots"):
		farm_mgr.load_save_data(world_data.get("farm_plots", []))
	# Load recipe pickup claimed data
	var pickup_data = world_data.get("recipe_pickups", {})
	for pickup in get_tree().get_nodes_in_group("recipe_pickup"):
		if pickup.has_method("load_claimed_data") and pickup.pickup_id in pickup_data:
			pickup.load_claimed_data(pickup_data[pickup.pickup_id])
	# Load world items
	var item_mgr = get_node_or_null("WorldItemManager")
	if item_mgr and world_data.has("world_items"):
		item_mgr.load_save_data(world_data.get("world_items", []))
	# Load restaurant manager data
	var rest_mgr = get_node_or_null("RestaurantManager")
	if rest_mgr and world_data.has("restaurant_manager"):
		rest_mgr.load_save_data(world_data.get("restaurant_manager", {}))

func get_save_data() -> Dictionary:
	var data = {}
	var season_mgr = $SeasonManager
	if season_mgr:
		var sd = season_mgr.get_save_data()
		data["current_month"] = sd.get("current_month", 3)
		data["day_in_month"] = sd.get("day_in_month", 1)
		data["current_year"] = sd.get("current_year", 1)
		data["day_timer"] = sd.get("day_timer", 0.0)
		data["total_day_count"] = sd.get("total_day_count", 1)
		data["current_weather"] = sd.get("current_weather", 0)
		# Backward compat keys
		data["season"] = sd.get("current_season", 0)
		data["season_timer"] = sd.get("season_timer", 0.0)
		data["day_count"] = sd.get("day_count", 1)
		data["day_in_season"] = sd.get("day_in_season", 1)
	var farm_mgr = get_node_or_null(FARM_MANAGER_PATH)
	if farm_mgr:
		data["farm_plots"] = farm_mgr.get_save_data()
	# Save recipe pickup claimed data
	var pickup_data = {}
	for pickup in get_tree().get_nodes_in_group("recipe_pickup"):
		if pickup.has_method("get_claimed_data") and pickup.pickup_id != "":
			pickup_data[pickup.pickup_id] = pickup.get_claimed_data()
	if not pickup_data.is_empty():
		data["recipe_pickups"] = pickup_data
	# Save world items
	var item_mgr = get_node_or_null("WorldItemManager")
	if item_mgr:
		data["world_items"] = item_mgr.get_save_data()
	# Save restaurant manager data (index allocations)
	var rest_mgr = get_node_or_null("RestaurantManager")
	if rest_mgr:
		rest_mgr.update_all_restaurant_save_data()
		data["restaurant_manager"] = rest_mgr.get_save_data()
	return data

func _ensure_fallback_camera() -> void:
	if get_node_or_null("FallbackCameraRig"):
		return
	var rig: Node3D = Node3D.new()
	rig.name = "FallbackCameraRig"
	rig.position = Vector3(0, 14, 18)
	rig.rotation = Vector3(deg_to_rad(-30), 0, 0)
	add_child(rig)

	var cam: Camera3D = Camera3D.new()
	cam.name = "FallbackCamera"
	cam.current = true
	cam.fov = 70.0
	rig.add_child(cam)

func _setup_ui() -> void:
	# Use the existing UI node from game_world.tscn (contains PvPChallengeUI, TrainerDialogueUI)
	# Creating a new "UI" node would cause Godot to rename it (e.g. @Node@38),
	# breaking all path-based lookups like /root/Main/GameWorld/UI/BattleUI
	var ui_node = $UI

	var hud = hud_scene.instantiate()
	ui_node.add_child(hud)

	var battle_ui = battle_ui_scene.instantiate()
	ui_node.add_child(battle_ui)
	battle_ui.setup($BattleManager)

	var crafting_ui = crafting_ui_scene.instantiate()
	ui_node.add_child(crafting_ui)
	crafting_ui.setup($CraftingSystem)

	var pause_menu = pause_menu_scene.instantiate()
	ui_node.add_child(pause_menu)

	var storage_ui = storage_ui_scene.instantiate()
	ui_node.add_child(storage_ui)

	var shop_ui = shop_ui_scene.instantiate()
	ui_node.add_child(shop_ui)

	var trade_ui = trade_ui_scene.instantiate()
	ui_node.add_child(trade_ui)

	var dialogue_ui = dialogue_ui_scene.instantiate()
	ui_node.add_child(dialogue_ui)

	var calendar_ui = calendar_ui_scene.instantiate()
	ui_node.add_child(calendar_ui)

	var compass_ui = compass_ui_scene.instantiate()
	ui_node.add_child(compass_ui)

	var creature_destination_ui = creature_destination_ui_scene.instantiate()
	ui_node.add_child(creature_destination_ui)

	var hotbar_ui = hotbar_ui_scene.instantiate()
	ui_node.add_child(hotbar_ui)

	var excursion_hud = excursion_hud_scene.instantiate()
	ui_node.add_child(excursion_hud)

	var bank_ui = bank_ui_scene.instantiate()
	ui_node.add_child(bank_ui)

	var fishing_ui_script = load("res://scripts/ui/fishing_ui.gd")
	var fishing_ui = CanvasLayer.new()
	fishing_ui.name = "FishingUI"
	fishing_ui.set_script(fishing_ui_script)
	ui_node.add_child(fishing_ui)

	# Character creator (stays hidden until triggered)
	var creator_script = load("res://scripts/ui/character_creator_ui.gd")
	var creator = CanvasLayer.new()
	creator.name = "CharacterCreatorUI"
	creator.set_script(creator_script)
	ui_node.add_child(creator)
	creator.appearance_confirmed.connect(_on_appearance_confirmed)

	# Start overworld music + ambience (client only)
	AudioManager.play_music("overworld")
	AudioManager.play_ambience(0, "overworld")

	# Check if first-time customization is needed (deferred to let UI initialize)
	_check_first_time_customization.call_deferred()

func _check_first_time_customization() -> void:
	var app: Dictionary = PlayerData.appearance
	if app.get("needs_customization", false):
		open_character_creator(true)


func open_character_creator(first_time: bool = false) -> void:
	var creator = get_node_or_null("UI/CharacterCreatorUI")
	if creator and creator.has_method("open"):
		var app: Dictionary = PlayerData.appearance.duplicate()
		creator.open(app, first_time)


func _on_appearance_confirmed(appearance: Dictionary) -> void:
	# Send to server
	NetworkManager.request_update_appearance.rpc_id(1, appearance)
	# Optimistically update local player model
	PlayerData.appearance = appearance
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else -1
	var player_node = players_node.get_node_or_null(str(local_id))
	if player_node and player_node.has_method("update_appearance"):
		player_node.update_appearance(appearance)


func _spawn_calendar_board() -> void:
	var board_script = load("res://scripts/world/calendar_board.gd")
	var board = Area3D.new()
	board.set_script(board_script)
	board.name = "CalendarBoard"
	board.position = Vector3(3, 1, 10)  # Town Square, near Town Hall
	add_child(board)

func _spawn_bank_npc() -> void:
	var bank_script = load("res://scripts/world/bank_npc.gd")
	var bank = Area3D.new()
	bank.set_script(bank_script)
	bank.name = "BankNPC"
	bank.position = Vector3(10, 1, 8)  # Town Square, near General Store
	add_child(bank)

const EXCURSION_PORTALS: Array = [
	{"zone_type": "default", "position": Vector3(-18, 0, -15), "label": "The Wilds", "color": Color(0.6, 0.2, 0.8)},
	{"zone_type": "coastal_wreckage", "position": Vector3(-25, 0, 10), "label": "Coastal Wreckage", "color": Color(0.2, 0.6, 0.8)},
	{"zone_type": "fungal_hollow", "position": Vector3(30, 0, -20), "label": "Fungal Hollow", "color": Color(0.4, 0.2, 0.6)},
	{"zone_type": "volcanic_crest", "position": Vector3(-35, 0, -30), "label": "Volcanic Crest", "color": Color(0.9, 0.3, 0.1)},
	{"zone_type": "frozen_pantry", "position": Vector3(40, 0, -25), "label": "Frozen Pantry", "color": Color(0.5, 0.8, 0.95)},
]

func _spawn_excursion_entrance() -> void:
	for portal_data in EXCURSION_PORTALS:
		_spawn_single_portal(portal_data)

func _spawn_single_portal(portal_data: Dictionary) -> void:
	var zone_type: String = portal_data["zone_type"]
	var portal_color: Color = portal_data["color"]

	var entrance = Node3D.new()
	entrance.name = "ExcursionEntrance_" + zone_type
	entrance.position = portal_data["position"]
	entrance.add_to_group("excursion_portal")
	entrance.set_meta("zone_type", zone_type)
	add_child(entrance)

	# Signpost
	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.4, 0.25, 0.1)
	var post = MeshInstance3D.new()
	var post_mesh = BoxMesh.new()
	post_mesh.size = Vector3(0.2, 3.0, 0.2)
	post.mesh = post_mesh
	post.set_surface_override_material(0, post_mat)
	post.position = Vector3(0, 1.5, 0)
	entrance.add_child(post)

	var sign_label = Label3D.new()
	UITheme.style_label3d(sign_label, portal_data["label"], "station")
	sign_label.font_size = 36
	sign_label.position = Vector3(0, 3.5, 0)
	entrance.add_child(sign_label)

	# Glowing portal visual — color matches zone theme
	var portal_mesh = MeshInstance3D.new()
	var torus = CylinderMesh.new()
	torus.top_radius = 2.0
	torus.bottom_radius = 2.0
	torus.height = 0.3
	portal_mesh.mesh = torus
	var portal_mat = StandardMaterial3D.new()
	portal_mat.albedo_color = Color(portal_color.r, portal_color.g, portal_color.b, 0.5)
	portal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_mat.emission_enabled = true
	portal_mat.emission = portal_color
	portal_mat.emission_energy_multiplier = 2.0
	portal_mesh.set_surface_override_material(0, portal_mat)
	portal_mesh.position = Vector3(0, 0.2, 0)
	entrance.add_child(portal_mesh)

	# Magic pulse VFX on portal (client-side only)
	if not multiplayer.is_server():
		var vfx_path := "res://assets/vfx/magic_areas/assets/BinbunVFX/magic_areas/effects/pulse_area/pulse_area_vfx_01.tscn"
		if ResourceLoader.exists(vfx_path):
			var vfx_scene = load(vfx_path) as PackedScene
			if vfx_scene:
				var vfx_inst = vfx_scene.instantiate() as Node3D
				vfx_inst.position = Vector3(0, 0.5, 0)
				vfx_inst.scale = Vector3(1.5, 1.5, 1.5)
				entrance.add_child(vfx_inst)

	# Server-side interaction Area3D
	if multiplayer.is_server():
		var area = Area3D.new()
		area.name = "PortalArea"
		area.position = Vector3(0, 0, 0)
		area.collision_layer = 0
		area.collision_mask = 3

		var shape = CylinderShape3D.new()
		shape.radius = 3.0
		shape.height = 4.0
		var coll = CollisionShape3D.new()
		coll.shape = shape
		coll.position = Vector3(0, 2, 0)
		area.add_child(coll)

		entrance.add_child(area)

	# Hint label for clients
	var hint = Label3D.new()
	UITheme.style_label3d(hint, "Press E to Enter", "interaction_hint")
	hint.position = Vector3(0, 2.5, 0)
	entrance.add_child(hint)


# === CAST IRON COVE TOWN DECORATION ===

func _generate_town_paths() -> void:
	var paths_node = Node3D.new()
	paths_node.name = "Paths"
	add_child(paths_node)

	var cobble_mat = StandardMaterial3D.new()
	cobble_mat.albedo_color = Color(0.55, 0.5, 0.4)
	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.5, 0.4, 0.25)

	# Town Square paths (cobblestone)
	var cobble_segments = [
		# Central square plaza
		{"pos": Vector3(0, 0.03, 6), "size": Vector3(20, 0.05, 12)},
		# Town Square to Market Row (east)
		{"pos": Vector3(12, 0.03, 7), "size": Vector3(8, 0.05, 3.5)},
		# Market Row main street
		{"pos": Vector3(18, 0.03, 7), "size": Vector3(12, 0.05, 3.5)},
		# Town Square to Wharf Walk (west)
		{"pos": Vector3(-8, 0.03, 0), "size": Vector3(12, 0.05, 3.5)},
		# Wharf Walk boardwalk
		{"pos": Vector3(-12, 0.03, -4), "size": Vector3(14, 0.05, 10)},
	]
	for seg in cobble_segments:
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = seg.size
		mesh_inst.mesh = box
		mesh_inst.set_surface_override_material(0, cobble_mat)
		mesh_inst.position = seg.pos
		paths_node.add_child(mesh_inst)

	# Dirt paths to encounter zones and farm
	var dirt_segments = [
		# Town Square to wild zones (north)
		{"pos": Vector3(0, 0.03, -5), "size": Vector3(3.5, 0.05, 14)},
		# To Herb Garden & Fermented Hollow
		{"pos": Vector3(-12, 0.03, -15), "size": Vector3(20, 0.05, 3.5)},
		# To Flame Kitchen & Blackened Crest
		{"pos": Vector3(12, 0.03, -15), "size": Vector3(20, 0.05, 3.5)},
		# Deep wilderness path
		{"pos": Vector3(0, 0.03, -25), "size": Vector3(3.5, 0.05, 16)},
		# To Frost Pantry & Battered Bay
		{"pos": Vector3(-12, 0.03, -32), "size": Vector3(20, 0.05, 3.5)},
		# To Harvest Field & Salted Shipwreck
		{"pos": Vector3(12, 0.03, -32), "size": Vector3(20, 0.05, 3.5)},
		# Deep path to Cauldron
		{"pos": Vector3(0, 0.03, -45), "size": Vector3(3.5, 0.05, 20)},
		# To Sour Springs
		{"pos": Vector3(9, 0.03, -48), "size": Vector3(18, 0.05, 3.5)},
		# To Fusion Kitchen
		{"pos": Vector3(-9, 0.03, -48), "size": Vector3(18, 0.05, 3.5)},
		# Town to farm (east)
		{"pos": Vector3(15, 0.03, 2), "size": Vector3(20, 0.05, 3.5)},
		# Harbor Heights hill path
		{"pos": Vector3(2, 0.03, 20), "size": Vector3(3.5, 0.05, 16)},
		# Harbor Heights plateau
		{"pos": Vector3(5, 6.03, 38), "size": Vector3(16, 0.05, 16)},
	]
	for seg in dirt_segments:
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = seg.size
		mesh_inst.mesh = box
		mesh_inst.set_surface_override_material(0, dirt_mat)
		mesh_inst.position = seg.pos
		paths_node.add_child(mesh_inst)

func _generate_district_signs() -> void:
	var signs_node = Node3D.new()
	signs_node.name = "DistrictSigns"
	add_child(signs_node)

	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.4, 0.25, 0.1)

	var signposts = [
		{"pos": Vector3(0, 1, 12), "text": "Town Square"},
		{"pos": Vector3(-6, 0, -2), "text": "Wharf Walk"},
		{"pos": Vector3(12, 2, 5), "text": "Market Row"},
		{"pos": Vector3(2, 4, 25), "text": "Harbor Heights"},
		{"pos": Vector3(0, 0, -8), "text": "W: Herb Garden\nE: Flame Kitchen\nN: Deeper Wilds"},
		{"pos": Vector3(0, 0, -25), "text": "W: Frost Pantry / Battered Bay\nE: Harvest Field / Salted Shipwreck"},
		{"pos": Vector3(0, 0, -42), "text": "N: Cauldron\nW: Fusion Kitchen\nE: Sour Springs"},
		{"pos": Vector3(18, 0, 0), "text": "E: Community Farm"},
	]

	for sp in signposts:
		var post = MeshInstance3D.new()
		var post_mesh = BoxMesh.new()
		post_mesh.size = Vector3(0.2, 2.0, 0.2)
		post.mesh = post_mesh
		post.set_surface_override_material(0, post_mat)
		post.position = Vector3(sp.pos.x, sp.pos.y + 1.0, sp.pos.z)
		signs_node.add_child(post)

		var label = Label3D.new()
		UITheme.style_label3d(label, sp.text, "zone_sign")
		label.font_size = 36
		label.position = Vector3(sp.pos.x, sp.pos.y + 2.3, sp.pos.z)
		signs_node.add_child(label)

func _generate_town_decorations() -> void:
	var decor_node = Node3D.new()
	decor_node.name = "TownDecorations"
	add_child(decor_node)

	# --- Synty Trees by district ---
	# Town Square — round trimmed trees (civic feel)
	var town_trees = [
		Vector3(-8, 0, 3), Vector3(8, 0, 3),
		Vector3(-8, 0, 10), Vector3(8, 0, 10),
	]
	for pos in town_trees:
		_place_synty(decor_node, "nature/models/SM_Tree_Round_01.glb", pos, 0.0, 1.5)

	# Market Row — birch trees
	var market_trees = [
		Vector3(14, 0, 3), Vector3(14, 0, 10),
		Vector3(22, 0, 3), Vector3(22, 0, 10),
	]
	for i in market_trees.size():
		var variant = "SM_Tree_Birch_0%d.glb" % (i % 4 + 1)
		_place_synty(decor_node, "nature/models/" + variant, market_trees[i], 0.0, 1.2)

	# Wharf Walk — tropical palms
	var wharf_trees = [Vector3(-6, 0, -8), Vector3(-16, 0, -8)]
	for i in wharf_trees.size():
		var variant = "SM_Env_Tree_Palm_0%d.glb" % (i % 4 + 1)
		_place_synty(decor_node, "tropical/models/" + variant, wharf_trees[i], randf() * TAU, 1.0)

	# Path to wilds — pine trees getting sparser
	var wild_path_trees = [
		Vector3(-3, 0, -10), Vector3(3, 0, -10),
		Vector3(-3, 0, -22), Vector3(3, 0, -22),
		Vector3(-3, 0, -35), Vector3(3, 0, -35),
	]
	for i in wild_path_trees.size():
		var variant: String
		if i < 2:
			variant = "SM_Tree_Pine_01.glb"
		elif i < 4:
			variant = "SM_Tree_Pine_Small_01.glb"
		else:
			variant = "SM_Tree_Pine_Dead_01.glb"
		_place_synty(decor_node, "nature/models/" + variant, wild_path_trees[i], randf() * TAU, 1.3)

	# Harbor Heights — willow trees on hillside
	var harbor_trees = [
		Vector3(0, 7, 35), Vector3(10, 7, 40),
		Vector3(-2, 7, 42), Vector3(12, 7, 35),
	]
	for pos in harbor_trees:
		_place_synty(decor_node, "nature/models/SM_Tree_Willow_Medium_01.glb", pos, randf() * TAU, 1.3)

	# Near farm — fruit trees
	_place_synty(decor_node, "farm/models/SM_Env_Tree_Apple_01.glb", Vector3(18, 0, -2), 0.0, 1.2)
	_place_synty(decor_node, "farm/models/SM_Env_Tree_Orange_01.glb", Vector3(18, 0, 5), 0.0, 1.2)

	# Encounter zone border trees
	_place_synty(decor_node, "nature/models/SM_Tree_Dead_01.glb", Vector3(-18, 0, -42), 0.0, 1.5)
	_place_synty(decor_node, "nature/models/SM_Tree_Dead_02.glb", Vector3(22, 0, -42), 0.0, 1.5)

	# --- Hedges along Town Square paths ---
	var hedge_positions = [
		{"pos": Vector3(-4, 0, 1), "rot": 0.0},
		{"pos": Vector3(4, 0, 1), "rot": 0.0},
		{"pos": Vector3(-4, 0, 11), "rot": 0.0},
		{"pos": Vector3(4, 0, 11), "rot": 0.0},
	]
	for h in hedge_positions:
		_place_synty(decor_node, "nature/models/SM_Plant_Hedge_Bush_01.glb", h.pos, h.rot, 1.5)

	# --- Flowers around fountain and bakery ---
	var flower_positions = [
		Vector3(-2, 0, 5), Vector3(2, 0, 5),
		Vector3(-2, 0, 7), Vector3(2, 0, 7),
		Vector3(-5, 0, 9), Vector3(-1, 0, 9),
	]
	for i in flower_positions.size():
		var variant = "SM_Plant_0%d.glb" % (i % 7 + 1)
		_place_synty(decor_node, "nature/models/" + variant, flower_positions[i], randf() * TAU, 1.2)

	# --- Ferns near wilderness edge ---
	var fern_positions = [
		Vector3(-5, 0, -7), Vector3(5, 0, -7),
		Vector3(-2, 0, -9), Vector3(2, 0, -9),
	]
	for i in fern_positions.size():
		var variant = "SM_Plant_Fern_0%d.glb" % (i % 3 + 1)
		_place_synty(decor_node, "nature/models/" + variant, fern_positions[i], randf() * TAU, 1.5)

	# --- Bushes in various districts ---
	_place_synty(decor_node, "nature/models/SM_Plant_Bush_Leaves_01.glb", Vector3(-6, 0, 5), 0.0, 1.3)
	_place_synty(decor_node, "nature/models/SM_Plant_Bush_Leaves_02.glb", Vector3(6, 0, 8), 0.0, 1.3)
	_place_synty(decor_node, "nature/models/SM_Plant_Bush_01.glb", Vector3(10, 0, 2), 0.0, 1.2)
	_place_synty(decor_node, "tropical/models/SM_Env_Bush_Palm_01.glb", Vector3(-14, 0, -5), 0.0, 1.0)
	_place_synty(decor_node, "tropical/models/SM_Env_Bush_Palm_02.glb", Vector3(-18, 0, -3), 0.0, 1.0)

	# Town fountain at Town Square center
	var fountain_mat = StandardMaterial3D.new()
	fountain_mat.albedo_color = Color(0.6, 0.6, 0.65)
	var fountain = MeshInstance3D.new()
	var fountain_mesh = CylinderMesh.new()
	fountain_mesh.top_radius = 1.5
	fountain_mesh.bottom_radius = 2.0
	fountain_mesh.height = 1.0
	fountain.mesh = fountain_mesh
	fountain.set_surface_override_material(0, fountain_mat)
	fountain.position = Vector3(0, 0.5, 6)
	decor_node.add_child(fountain)

	# Water in fountain
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.3, 0.5, 0.8, 0.6)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var water = MeshInstance3D.new()
	var water_mesh = CylinderMesh.new()
	water_mesh.top_radius = 1.4
	water_mesh.bottom_radius = 1.4
	water_mesh.height = 0.15
	water.mesh = water_mesh
	water.set_surface_override_material(0, water_mat)
	water.position = Vector3(0, 1.05, 6)
	decor_node.add_child(water)

	# Harbor Heights elevation (simple raised platform)
	var hill_mat = StandardMaterial3D.new()
	hill_mat.albedo_color = Color(0.35, 0.5, 0.3)
	var hill = MeshInstance3D.new()
	var hill_mesh = BoxMesh.new()
	hill_mesh.size = Vector3(30, 6, 30)
	hill.mesh = hill_mesh
	hill.set_surface_override_material(0, hill_mat)
	hill.position = Vector3(5, 3, 38)
	decor_node.add_child(hill)

	# Ocean plane (west of town) — uses animated water shader
	var water_shader = load("res://shaders/water.gdshader")
	var ocean_shader_mat = ShaderMaterial.new()
	ocean_shader_mat.shader = water_shader
	var ocean = MeshInstance3D.new()
	var ocean_mesh = PlaneMesh.new()
	ocean_mesh.size = Vector2(200, 160)
	ocean_mesh.subdivide_width = 40
	ocean_mesh.subdivide_depth = 32
	ocean.mesh = ocean_mesh
	ocean.material_override = ocean_shader_mat
	ocean.position = Vector3(-35, -0.3, -10)
	decor_node.add_child(ocean)

func _generate_encounter_zone_overlays() -> void:
	var overlays_node = Node3D.new()
	overlays_node.name = "ZoneOverlays"
	add_child(overlays_node)

	var zones = [
		# Original 6 zones
		{"pos": Vector3(-12, 0.02, -15), "color": Color(0.2, 0.5, 0.2, 0.3), "label": "Herb Garden"},
		{"pos": Vector3(12, 0.02, -15), "color": Color(0.5, 0.25, 0.15, 0.3), "label": "Flame Kitchen"},
		{"pos": Vector3(-18, 0.02, -35), "color": Color(0.25, 0.35, 0.6, 0.3), "label": "Frost Pantry"},
		{"pos": Vector3(18, 0.02, -35), "color": Color(0.5, 0.45, 0.15, 0.3), "label": "Harvest Field"},
		{"pos": Vector3(18, 0.02, -48), "color": Color(0.6, 0.7, 0.15, 0.3), "label": "Sour Springs"},
		{"pos": Vector3(-18, 0.02, -48), "color": Color(0.5, 0.25, 0.5, 0.3), "label": "Fusion Kitchen"},
		# 4 new zones
		{"pos": Vector3(-25, 0.02, -20), "color": Color(0.4, 0.35, 0.15, 0.3), "label": "Fermented Hollow"},
		{"pos": Vector3(25, 3.02, -20), "color": Color(0.5, 0.15, 0.1, 0.3), "label": "Blackened Crest"},
		{"pos": Vector3(-20, 0.02, -30), "color": Color(0.25, 0.4, 0.6, 0.3), "label": "Battered Bay"},
		{"pos": Vector3(20, 0.02, -30), "color": Color(0.45, 0.5, 0.35, 0.3), "label": "Salted Shipwreck"},
	]

	for z in zones:
		var overlay = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(14, 0.02, 14)
		overlay.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = z.color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.set_surface_override_material(0, mat)
		overlay.position = z.pos
		overlays_node.add_child(overlay)

		var label = Label3D.new()
		UITheme.style_label3d(label, z.label, "zone_sign")
		label.font_size = 36
		label.position = Vector3(z.pos.x, z.pos.y + 3.5, z.pos.z)
		overlays_node.add_child(label)

	# Rocks at zone borders
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.5, 0.48, 0.45)
	var rock_positions = [
		Vector3(-5, 0.4, -18), Vector3(5, 0.3, -18),
		Vector3(-8, 0.35, -30), Vector3(8, 0.35, -30),
		Vector3(-8, 0.4, -44), Vector3(8, 0.4, -44),
	]
	for rpos in rock_positions:
		var rock = MeshInstance3D.new()
		var rbox = BoxMesh.new()
		var rsize = randf_range(0.6, 1.2)
		rbox.size = Vector3(rsize, rsize * 0.6, rsize * 0.8)
		rock.mesh = rbox
		rock.set_surface_override_material(0, rock_mat)
		rock.position = rpos
		overlays_node.add_child(rock)

func _on_player_connected(peer_id: int, _info: Dictionary) -> void:
	_spawn_player(peer_id)
	# Register with restaurant manager (spawns overworld door, tracks location)
	var rest_mgr = get_node_or_null("RestaurantManager")
	if rest_mgr:
		rest_mgr.handle_player_connected(peer_id)
	# Sync world state to late joiner (deferred so player node exists)
	_sync_world_to_client.call_deferred(peer_id)

func _on_player_disconnected(peer_id: int) -> void:
	# Clean up fishing state
	var fishing_mgr = get_node_or_null("FishingManager")
	if fishing_mgr:
		fishing_mgr.handle_disconnect(peer_id)
	# Clean up excursion state (restore overworld position before despawn)
	var excursion_mgr = get_node_or_null("ExcursionManager")
	if excursion_mgr:
		excursion_mgr.handle_disconnect(peer_id)
	# Clean up restaurant state (save data, remove door, eject from restaurant)
	var rest_mgr = get_node_or_null("RestaurantManager")
	if rest_mgr:
		rest_mgr.handle_player_disconnect(peer_id)
	# Clean up battle/encounter state for this peer
	var battle_mgr = get_node_or_null("BattleManager")
	if battle_mgr:
		battle_mgr.handle_player_disconnect(peer_id)
	var encounter_mgr = get_node_or_null("EncounterManager")
	if encounter_mgr:
		encounter_mgr.end_encounter(peer_id)
	_despawn_player(peer_id)

func _spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	# Use saved position if available
	if peer_id in NetworkManager.player_data_store:
		var pos_data = NetworkManager.player_data_store[peer_id].get("position", {})
		if not pos_data.is_empty():
			var saved_pos = Vector3(pos_data.get("x", 0.0), pos_data.get("y", 1.0), pos_data.get("z", 3.0))
			# Migration: reset players at old layout positions to spawn
			if _is_old_layout_position(saved_pos):
				print("[GameWorld] Migrating player ", peer_id, " from old position ", saved_pos, " to spawn")
				player.position = _get_spread_spawn_position()
			else:
				player.position = saved_pos
		else:
			player.position = _get_spread_spawn_position()
	else:
		player.position = _get_spread_spawn_position()
	# Set visual properties from server data (BEFORE add_child for StateSync spawn-only replication)
	if peer_id in NetworkManager.player_data_store:
		var pdata = NetworkManager.player_data_store[peer_id]
		var cd = pdata.get("player_color", {})
		if cd is Dictionary and not cd.is_empty():
			player.player_color = Color(cd.get("r", 0.2), cd.get("g", 0.5), cd.get("b", 0.9))
		player.player_name_display = str(pdata.get("player_name", "Player"))
		player.appearance_data = pdata.get("appearance", {})
	# Keep exact numeric node names (peer_id) so authority/camera logic works on clients.
	players_node.add_child(player)
	print("Spawned player: ", peer_id)

func _despawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player_node = players_node.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
		print("Despawned player: ", peer_id)

func _is_old_layout_position(pos: Vector3) -> bool:
	# Old layout had WildZone at (-20,0,0) with zones at offsets like (-28,-12), (-36,16), etc.
	# New layout has everything along Z axis (north-south). Old positions had x < -15.
	# Also old farm was at (20,0,0), new is (25,0,0).
	# Old restaurant row was at (0,0,-15), now at (0,0,12).
	# Check if position is in old wild zone area (x < -15)
	if pos.x < -15.0:
		return true
	# Check if near old farm position (20,0,0) but not new (25,0,0)
	if abs(pos.x - 20.0) < 3.0 and abs(pos.z) < 10.0:
		return true
	return false

func _get_spread_spawn_position() -> Vector3:
	# Spread new players in a circle using golden angle to avoid overlap/stacking
	var idx = players_node.get_child_count() # 0-based count of existing children
	var angle = idx * 2.399 # golden angle in radians
	var radius = 2.0
	return Vector3(cos(angle) * radius, 1.0, sin(angle) * radius + 6.0)  # Town Square center

func _sync_world_to_client(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Sync season/calendar/weather
	var season_mgr = $SeasonManager
	if season_mgr:
		season_mgr._broadcast_time.rpc_id(peer_id, season_mgr.current_year, season_mgr.current_month, season_mgr.day_in_month, season_mgr.total_day_count, season_mgr.current_weather, season_mgr.day_timer)
	# Sync farm plots
	var farm_mgr = get_node_or_null(FARM_MANAGER_PATH)
	if farm_mgr:
		for plot in farm_mgr.plots:
			plot._sync_state.rpc_id(peer_id, plot.plot_state, plot.planted_seed_id, plot.growth_progress, plot.water_level, plot.owner_peer_id)
	# Sync world items
	var item_mgr = get_node_or_null("WorldItemManager")
	if item_mgr:
		item_mgr.sync_all_to_client(peer_id)
	# Sync restaurant doors to late joiner
	var rest_mgr = get_node_or_null("RestaurantManager")
	if rest_mgr:
		rest_mgr.sync_doors_to_client(peer_id)
	# Sync gatekeeper states (open gates for defeated trainers)
	for npc in get_tree().get_nodes_in_group("trainer_npc"):
		if npc.is_gatekeeper:
			npc.update_gate_for_peer(peer_id)
	# Sync harvestable objects
	for h in get_tree().get_nodes_in_group("harvestable_object"):
		if h.has_method("sync_to_client"):
			h.sync_to_client(peer_id)
	# Sync dig spots
	for ds in get_tree().get_nodes_in_group("dig_spot"):
		if ds.has_method("sync_to_client"):
			ds.sync_to_client(peer_id)

# === World Harvestable Objects ===

var harvestable_scene = preload("res://scenes/world/harvestable_object.tscn")

func _generate_harvestables() -> void:
	var harvestables_node = Node3D.new()
	harvestables_node.name = "Harvestables"
	add_child(harvestables_node)

	# Trees: axe, 3 hits, 120s respawn
	var tree_positions = [
		Vector3(-8, 0, -12), Vector3(8, 0, -12),
		Vector3(-14, 0, -32), Vector3(14, 0, -32),
		Vector3(-14, 0, -45), Vector3(14, 0, -45),
	]
	for pos in tree_positions:
		var h = harvestable_scene.instantiate()
		h.harvestable_type = "tree"
		h.required_tool = "axe"
		h.max_health = 3
		h.respawn_time = 120.0
		h.drops = [
			{"item_id": "wood", "min": 1, "max": 3, "weight": 1.0},
			{"item_id": "herb_basil", "min": 1, "max": 1, "weight": 0.2},
		]
		h.position = pos
		h.name = "Tree_%d_%d" % [int(pos.x), int(pos.z)]
		harvestables_node.add_child(h)

	# Rocks: axe, 4 hits, 150s respawn
	var rock_positions = [
		Vector3(-16, 0, -18), Vector3(16, 0, -18),
		Vector3(-12, 0, -50), Vector3(12, 0, -50),
	]
	for pos in rock_positions:
		var h = harvestable_scene.instantiate()
		h.harvestable_type = "rock"
		h.required_tool = "axe"
		h.max_health = 4
		h.respawn_time = 150.0
		h.drops = [
			{"item_id": "stone", "min": 1, "max": 2, "weight": 1.0},
			{"item_id": "chili_powder", "min": 1, "max": 1, "weight": 0.1},
		]
		h.position = pos
		h.name = "Rock_%d_%d" % [int(pos.x), int(pos.z)]
		harvestables_node.add_child(h)

	# Bushes: no tool (hands), 1 hit, 90s respawn
	var bush_positions = [
		Vector3(-10, 0, -14), Vector3(10, 0, -14),
		Vector3(-16, 0, -38), Vector3(16, 0, -38),
	]
	for pos in bush_positions:
		var h = harvestable_scene.instantiate()
		h.harvestable_type = "bush"
		h.required_tool = ""
		h.max_health = 1
		h.respawn_time = 90.0
		h.drops = [
			{"item_id": "berry", "min": 1, "max": 2, "weight": 1.0},
		]
		h.position = pos
		h.name = "Bush_%d_%d" % [int(pos.x), int(pos.z)]
		harvestables_node.add_child(h)

# === Dig Spots ===

func _generate_dig_spots() -> void:
	var digs_node = Node3D.new()
	digs_node.name = "DigSpots"
	add_child(digs_node)

	var dig_spot_script = load("res://scripts/world/dig_spot.gd")
	var spots = [
		# Herb Garden (2)
		{"pos": Vector3(-14, 0, -13), "id": "herb_1", "loot": [{"item_id": "broth", "weight": 0.6, "min": 1, "max": 1}, {"item_id": "herb_basil", "weight": 0.4, "min": 1, "max": 2}]},
		{"pos": Vector3(-10, 0, -17), "id": "herb_2", "loot": [{"item_id": "broth", "weight": 0.5, "min": 1, "max": 1}, {"item_id": "herb_basil", "weight": 0.5, "min": 1, "max": 2}]},
		# Flame Kitchen (2)
		{"pos": Vector3(14, 0, -13), "id": "flame_1", "loot": [{"item_id": "chili_powder", "weight": 0.5, "min": 1, "max": 1}, {"item_id": "chili_pepper", "weight": 0.5, "min": 1, "max": 2}]},
		{"pos": Vector3(10, 0, -17), "id": "flame_2", "loot": [{"item_id": "chili_powder", "weight": 0.6, "min": 1, "max": 1}, {"item_id": "chili_pepper", "weight": 0.4, "min": 1, "max": 1}]},
		# Frost Pantry (2)
		{"pos": Vector3(-20, 0, -33), "id": "frost_1", "loot": [{"item_id": "mint", "weight": 0.6, "min": 1, "max": 2}]},
		{"pos": Vector3(-16, 0, -37), "id": "frost_2", "loot": [{"item_id": "mint", "weight": 0.5, "min": 1, "max": 1}]},
		# Harvest Field (2)
		{"pos": Vector3(20, 0, -33), "id": "harvest_1", "loot": [{"item_id": "wheat", "weight": 0.6, "min": 1, "max": 2}, {"item_id": "flour", "weight": 0.3, "min": 1, "max": 1}]},
		{"pos": Vector3(16, 0, -37), "id": "harvest_2", "loot": [{"item_id": "wheat", "weight": 0.5, "min": 1, "max": 2}, {"item_id": "flour", "weight": 0.4, "min": 1, "max": 1}]},
		# Sour Springs (1)
		{"pos": Vector3(20, 0, -46), "id": "sour_1", "loot": [{"item_id": "mushroom", "weight": 0.5, "min": 1, "max": 2}]},
		# Fusion Kitchen (1)
		{"pos": Vector3(-20, 0, -46), "id": "fusion_1", "loot": [{"item_id": "sugar", "weight": 0.4, "min": 1, "max": 1}, {"item_id": "soy_sauce", "weight": 0.3, "min": 1, "max": 1}]},
	]

	for spot in spots:
		var ds = Area3D.new()
		ds.set_script(dig_spot_script)
		ds.name = "DigSpot_" + str(spot["id"])
		ds.position = spot["pos"]
		ds.spot_id = str(spot["id"])
		ds.loot_table = spot["loot"]
		digs_node.add_child(ds)

# === Fishing Spots ===

func _spawn_fishing_spots() -> void:
	var fishing_node = Node3D.new()
	fishing_node.name = "FishingSpots"
	add_child(fishing_node)

	var spots = [
		{"pos": Vector3(-14, 0, -6), "table_id": "pond", "label": "Cove Pond"},
		{"pos": Vector3(-10, 0, -12), "table_id": "river", "label": "Wharf Pier"},
		{"pos": Vector3(-22, 0, -10), "table_id": "ocean", "label": "Open Ocean"},
	]

	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.2, 0.4, 0.7, 0.5)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for spot in spots:
		var spot_node = Node3D.new()
		spot_node.name = "FishingSpot_" + spot["table_id"]
		spot_node.position = spot["pos"]
		spot_node.add_to_group("fishing_spot")
		spot_node.set_meta("fishing_table_id", spot["table_id"])
		fishing_node.add_child(spot_node)

		# Water visual (flat disc)
		var water = MeshInstance3D.new()
		var disc = CylinderMesh.new()
		disc.top_radius = 3.0
		disc.bottom_radius = 3.0
		disc.height = 0.1
		water.mesh = disc
		water.set_surface_override_material(0, water_mat)
		water.position = Vector3(0, 0.05, 0)
		spot_node.add_child(water)

		# Label
		var label = Label3D.new()
		UITheme.style_label3d(label, spot["label"] + " - Fishing Spot", "station")
		label.font_size = 28
		label.position = Vector3(0, 2.5, 0)
		spot_node.add_child(label)

		# Hint
		var hint = Label3D.new()
		UITheme.style_label3d(hint, "Equip Rod + Press E", "interaction_hint")
		hint.position = Vector3(0, 2.0, 0)
		spot_node.add_child(hint)

# === SYNTY MODEL HELPERS ===

func _place_synty(parent: Node3D, asset_path: String, pos: Vector3, rot_y: float = 0.0, scale_val: float = 1.0) -> Node3D:
	var scene = load("res://assets/synty/" + asset_path) as PackedScene
	if not scene:
		push_warning("[GameWorld] Could not load Synty asset: " + asset_path)
		return null
	var instance = scene.instantiate()
	instance.position = pos
	if rot_y != 0.0:
		instance.rotation.y = rot_y
	if scale_val != 1.0:
		instance.scale = Vector3(scale_val, scale_val, scale_val)
	_apply_toon_shader(instance)
	parent.add_child(instance)
	return instance

func _apply_toon_shader(node: Node) -> void:
	if not _toon_shader:
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			for surf_idx in mesh.get_surface_count():
				var existing_mat = mi.get_active_material(surf_idx)
				var shader_mat = ShaderMaterial.new()
				shader_mat.shader = _toon_shader
				# Transfer texture from original material if present
				if existing_mat is StandardMaterial3D:
					var std_mat := existing_mat as StandardMaterial3D
					if std_mat.albedo_texture:
						shader_mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
						shader_mat.set_shader_parameter("use_texture", true)
					else:
						shader_mat.set_shader_parameter("use_texture", false)
						shader_mat.set_shader_parameter("albedo_color", std_mat.albedo_color)
				elif existing_mat is ShaderMaterial:
					# Already a shader material — skip
					continue
				else:
					shader_mat.set_shader_parameter("use_texture", false)
				mi.set_surface_override_material(surf_idx, shader_mat)
	for child in node.get_children():
		_apply_toon_shader(child)

# === PHASE 1: SKYBOX AND HORIZON ===

func _generate_horizon() -> void:
	var horizon_node = Node3D.new()
	horizon_node.name = "Horizon"
	add_child(horizon_node)

	# North mountains — block the north void
	_place_synty(horizon_node, "nature/models/MountainSkybox.glb", Vector3(0, -2, 90), 0.0, 4.0)
	_place_synty(horizon_node, "nature/models/MountainSkybox.glb", Vector3(-35, -3, 95), 0.5, 3.5)
	_place_synty(horizon_node, "nature/models/MountainSkybox.glb", Vector3(35, -1, 85), -0.3, 3.8)

	# East ridge — block the east void
	_place_synty(horizon_node, "nature/models/SM_Terrain_Mountain_01.glb", Vector3(70, -2, -20), 0.0, 5.0)
	_place_synty(horizon_node, "nature/models/SM_Terrain_Mountain_02.glb", Vector3(65, -1, 10), 0.4, 4.5)

	# South hills — behind the Cauldron area
	_place_synty(horizon_node, "pirate/models/SM_Env_Background_Hills_01.glb", Vector3(0, -1, -75), 0.0, 3.0)
	_place_synty(horizon_node, "nature/models/SM_Terrain_Mountain_03.glb", Vector3(-30, -2, -80), 0.3, 4.0)

	# West islands — visible in the ocean, sells "cove" feel
	_place_synty(horizon_node, "pirate/models/SM_Env_Background_Island_01.glb", Vector3(-80, -1, -15), 0.0, 2.5)
	_place_synty(horizon_node, "pirate/models/SM_Env_Background_Island_02.glb", Vector3(-90, -1, -30), 0.5, 2.0)
	_place_synty(horizon_node, "pirate/models/SM_Env_Background_Island_03.glb", Vector3(-75, -1, 5), -0.3, 2.2)

# === PHASE 2: COASTLINE ===

func _generate_coastline() -> void:
	var coast_node = Node3D.new()
	coast_node.name = "Coastline"
	add_child(coast_node)

	# --- Cliff face along western edge (defines the cove) ---
	var cliff_positions = [
		{"pos": Vector3(-27, 0, 15), "rot": 1.57, "scale": 2.0, "model": "SM_Env_Rock_Cliff_01.glb"},
		{"pos": Vector3(-28, 0, 10), "rot": 1.6, "scale": 2.2, "model": "SM_Env_Rock_Cliff_02.glb"},
		{"pos": Vector3(-26, 0, 5), "rot": 1.5, "scale": 1.8, "model": "SM_Env_Rock_Cliff_01.glb"},
		{"pos": Vector3(-27, 0, 0), "rot": 1.57, "scale": 2.0, "model": "SM_Env_Rock_Cliff_03.glb"},
		# Gap from z=-5 to z=-10 for beach access
		{"pos": Vector3(-27, 0, -12), "rot": 1.57, "scale": 2.0, "model": "SM_Env_Rock_Cliff_02.glb"},
		{"pos": Vector3(-28, 0, -16), "rot": 1.5, "scale": 1.8, "model": "SM_Env_Rock_Cliff_01.glb"},
		{"pos": Vector3(-26, 0, -20), "rot": 1.6, "scale": 2.2, "model": "SM_Env_Rock_Cliff_03.glb"},
		{"pos": Vector3(-27, 0, -25), "rot": 1.57, "scale": 2.0, "model": "SM_Env_Rock_Cliff_02.glb"},
	]
	for cliff in cliff_positions:
		_place_synty(coast_node, "tropical/models/" + cliff.model, cliff.pos, cliff.rot, cliff.scale)

	# --- Beach sand pieces in the gap ---
	var beach_positions = [
		{"pos": Vector3(-22, -0.1, -6), "model": "SM_Env_Beach_01.glb"},
		{"pos": Vector3(-24, -0.1, -8), "model": "SM_Env_Beach_02.glb"},
		{"pos": Vector3(-20, -0.1, -9), "model": "SM_Env_Beach_03.glb"},
		{"pos": Vector3(-23, -0.1, -11), "model": "SM_Env_Beach_04.glb"},
		{"pos": Vector3(-21, -0.1, -13), "model": "SM_Env_Beach_05.glb"},
		{"pos": Vector3(-25, -0.2, -7), "model": "SM_Env_Beach_06.glb"},
	]
	for b in beach_positions:
		_place_synty(coast_node, "pirate/models/" + b.model, b.pos, randf() * TAU, 1.5)

	# --- Driftwood on beach ---
	var driftwood_positions = [
		Vector3(-23, 0, -7), Vector3(-21, 0, -10),
		Vector3(-24, 0, -12), Vector3(-20, 0, -8),
	]
	for i in driftwood_positions.size():
		var variant = "SM_Env_DriftWood_0%d.glb" % (i % 5 + 1)
		_place_synty(coast_node, "tropical/models/" + variant, driftwood_positions[i], randf() * TAU, 1.2)

	# --- Rock arch at beach entrance ---
	_place_synty(coast_node, "tropical/models/SM_Env_Rock_Arch_01.glb", Vector3(-24, 0, -3), 1.2, 2.0)

	# --- Wharf Pier docks extending over water ---
	_place_synty(coast_node, "pirate/models/SM_Bld_Dock_01.glb", Vector3(-12, 0, -12), PI, 1.5)
	_place_synty(coast_node, "pirate/models/SM_Bld_Dock_02.glb", Vector3(-15, 0, -12), PI, 1.5)
	_place_synty(coast_node, "pirate/models/SM_Bld_Dock_03.glb", Vector3(-18, 0, -12), PI, 1.5)
	_place_synty(coast_node, "pirate/models/SM_Bld_Dock_Stairs_01.glb", Vector3(-11, 0, -11), PI, 1.5)

	# --- Rickety dock at Open Ocean fishing spot ---
	_place_synty(coast_node, "pirate/models/SM_Bld_Rickety_Dock_01.glb", Vector3(-22, 0, -10), 0.0, 1.3)
	_place_synty(coast_node, "pirate/models/SM_Bld_Rickety_Dock_02.glb", Vector3(-25, -0.1, -10), 0.0, 1.3)

# === PHASE 4: THE LIGHTHOUSE ===

func _generate_lighthouse() -> void:
	var lighthouse_node = Node3D.new()
	lighthouse_node.name = "Lighthouse"
	add_child(lighthouse_node)

	# Base — fort base on the cliff edge
	_place_synty(lighthouse_node, "pirate/models/SM_Bld_Fort_Base_Circle_01.glb", Vector3(-25, 0, 15), 0.0, 2.0)

	# Tower — stacked fort tower pieces for height
	_place_synty(lighthouse_node, "pirate/models/SM_Bld_Fort_Tower_01.glb", Vector3(-25, 3, 15), 0.0, 2.0)
	_place_synty(lighthouse_node, "pirate/models/SM_Bld_Fort_Tower_Room_01.glb", Vector3(-25, 8, 15), 0.0, 2.0)

	# Beacon light at the top — warm yellow, visible at night
	var beacon = OmniLight3D.new()
	beacon.name = "LighthouseBeacon"
	beacon.position = Vector3(-25, 13, 15)
	beacon.light_color = Color(1.0, 0.9, 0.5)
	beacon.light_energy = 2.0
	beacon.omni_range = 50.0
	lighthouse_node.add_child(beacon)

	# Beacon glow mesh (small glowing sphere)
	var glow_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	glow_mesh.mesh = sphere
	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.95, 0.6)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.9, 0.4)
	glow_mat.emission_energy_multiplier = 3.0
	glow_mesh.set_surface_override_material(0, glow_mat)
	glow_mesh.position = Vector3(-25, 13, 15)
	lighthouse_node.add_child(glow_mesh)

	# Label
	var label = Label3D.new()
	UITheme.style_label3d(label, "The Lighthouse", "landmark")
	label.font_size = 36
	label.position = Vector3(-25, 15, 15)
	lighthouse_node.add_child(label)

# === PHASE 5: DISTRICT IDENTITY PROPS ===

func _generate_district_props() -> void:
	var props_node = Node3D.new()
	props_node.name = "DistrictProps"
	add_child(props_node)

	# --- Town Square (civic center feel) ---

	# Stone benches near fountain
	_place_synty(props_node, "pirate/models/SM_Prop_Bench_01.glb", Vector3(-3, 0, 5), 0.0, 1.3)
	_place_synty(props_node, "pirate/models/SM_Prop_Bench_01.glb", Vector3(3, 0, 7), PI, 1.3)

	# --- Wharf Walk (maritime character) ---

	# Anchor at the waterfront
	_place_synty(props_node, "pirate/models/SM_Prop_Anchor_01.glb", Vector3(-15, 0, -5), 0.3, 1.5)

	# Barrel clusters near warehouse and docks
	_place_synty(props_node, "pirate/models/SM_Prop_Barrel_01.glb", Vector3(-8, 0, -6), 0.0, 1.2)
	_place_synty(props_node, "pirate/models/SM_Prop_Barrel_02.glb", Vector3(-9, 0, -5.5), 0.3, 1.2)
	_place_synty(props_node, "pirate/models/SM_Prop_Barrel_03.glb", Vector3(-7.5, 0, -5), -0.2, 1.2)
	_place_synty(props_node, "pirate/models/SM_Prop_Barrel_01.glb", Vector3(-14, 0, -9), 0.0, 1.2)
	_place_synty(props_node, "pirate/models/SM_Prop_Barrel_04.glb", Vector3(-13, 0, -10), 0.5, 1.2)

	# Rope fence along waterfront
	_place_synty(props_node, "pirate/models/SM_Prop_Rope_Fence_01.glb", Vector3(-10, 0, -7), 0.0, 1.3)
	_place_synty(props_node, "pirate/models/SM_Prop_Rope_Fence_01.glb", Vector3(-14, 0, -7), 0.0, 1.3)

	# --- Market Row (shopping street) ---

	# Produce stand near Bloom & Grow
	_place_synty(props_node, "farm/models/SM_Bld_ProduceStand_01.glb", Vector3(19, 0, 9), -PI / 2.0, 1.3)

	# --- Farm Zone (pastoral) ---

	# Scarecrow in plots
	_place_synty(props_node, "farm/models/SM_Prop_Scarecrow_01.glb", Vector3(25, 0, 2), 0.5, 1.5)

	# Greenhouse near water source
	_place_synty(props_node, "farm/models/SM_Bld_Greenhouse_01.glb", Vector3(32, 0, 5), 0.0, 1.2)

	# --- Harbor Heights (elevated garden district) ---

	# Stone retaining walls
	_place_synty(props_node, "nature/models/SM_Prop_StoneWall_01.glb", Vector3(-3, 3, 30), 0.0, 2.0)
	_place_synty(props_node, "nature/models/SM_Prop_StoneWall_02.glb", Vector3(3, 3, 30), 0.0, 2.0)
	_place_synty(props_node, "nature/models/SM_Prop_StoneWall_03.glb", Vector3(9, 3, 30), 0.0, 2.0)

	# Boulder hillside dressing
	_place_synty(props_node, "nature/models/SM_Rock_Boulder_01.glb", Vector3(-2, 1, 28), 0.4, 2.5)
	_place_synty(props_node, "nature/models/SM_Rock_Boulder_01.glb", Vector3(8, 2, 29), -0.3, 2.0)
	_place_synty(props_node, "nature/models/SM_Rock_Boulder_01.glb", Vector3(12, 1, 27), 0.6, 1.8)

	# Vine wall for Cordelia's Cottage area
	_place_synty(props_node, "pirate/models/SM_Bld_Cuba_VineWall_01.glb", Vector3(0, 6, 35), PI / 2.0, 1.5)

# === PHASE 6: WILDERNESS PROGRESSION AND GATEKEEPER LANDMARKS ===

func _generate_wilderness_terrain() -> void:
	var wild_node = Node3D.new()
	wild_node.name = "WildernessTerrain"
	add_child(wild_node)

	# --- Tier 1: Outskirts (z=-5 to z=-20) — healthy but thinning ---

	# Small rocks along path edges
	var tier1_rocks = [
		Vector3(-5, 0, -8), Vector3(5, 0, -9),
		Vector3(-7, 0, -12), Vector3(7, 0, -13),
		Vector3(-4, 0, -16), Vector3(6, 0, -17),
	]
	for i in tier1_rocks.size():
		var variant = "SM_Rock_0%d.glb" % (i % 4 + 1)
		_place_synty(wild_node, "nature/models/" + variant, tier1_rocks[i], randf() * TAU, 1.5)

	# Stumps and undergrowth
	_place_synty(wild_node, "nature/models/SM_Tree_Stump_01.glb", Vector3(-6, 0, -14), 0.0, 1.5)
	_place_synty(wild_node, "nature/models/SM_Tree_Stump_02.glb", Vector3(6, 0, -11), 0.3, 1.5)
	_place_synty(wild_node, "nature/models/SM_Plant_Undergrowth_01.glb", Vector3(-4, 0, -11), 0.0, 2.0)
	_place_synty(wild_node, "nature/models/SM_Plant_Undergrowth_01.glb", Vector3(4, 0, -15), 0.5, 2.0)

	# --- Gatekeeper #1 Archway: Chef Umami at z=-20 ---
	_place_synty(wild_node, "nature/models/SM_Prop_Pillar_Arch_01.glb", Vector3(0, 0, -20), 0.0, 2.5)

	# --- Tier 2: Mid-Wilderness (z=-20 to z=-40) — larger formations ---

	# Larger rock formations as natural walls
	var tier2_rocks = [
		Vector3(-8, 0, -24), Vector3(8, 0, -25),
		Vector3(-10, 0, -28), Vector3(10, 0, -29),
		Vector3(-6, 0, -33), Vector3(7, 0, -34),
		Vector3(-9, 0, -37), Vector3(9, 0, -38),
	]
	for i in tier2_rocks.size():
		_place_synty(wild_node, "nature/models/SM_Rock_Boulder_01.glb", tier2_rocks[i], randf() * TAU, 2.0 + randf() * 0.5)

	# Stone wall fragments — old ruins
	_place_synty(wild_node, "nature/models/SM_Prop_StoneWall_01.glb", Vector3(-7, 0, -26), 0.4, 1.5)
	_place_synty(wild_node, "nature/models/SM_Prop_StoneWall_02.glb", Vector3(7, 0, -31), -0.3, 1.5)

	# Swamp trees and dead trees for atmosphere
	_place_synty(wild_node, "nature/models/SM_Tree_Swamp_01.glb", Vector3(-12, 0, -26), 0.0, 1.5)
	_place_synty(wild_node, "nature/models/SM_Tree_Swamp_02.glb", Vector3(12, 0, -27), 0.3, 1.5)
	_place_synty(wild_node, "nature/models/SM_Tree_Dead_02.glb", Vector3(-10, 0, -34), 0.0, 1.5)
	_place_synty(wild_node, "nature/models/SM_Tree_Dead_03.glb", Vector3(10, 0, -36), -0.2, 1.5)

	# --- Gatekeeper #2 Archway: Head Chef Roux at z=-40 ---
	_place_synty(wild_node, "nature/models/SM_Prop_Pillar_Arch_Broken_Moss_01.glb", Vector3(0, 0, -40), 0.0, 2.5)

	# --- Tier 3: Deep Wilds (z=-40 to z=-55) — sparse, atmospheric ---

	# Cave entrances flanking the Cauldron
	_place_synty(wild_node, "nature/models/SM_Rock_CaveEntrance_01.glb", Vector3(-6, 0, -52), 0.5, 2.5)
	_place_synty(wild_node, "nature/models/SM_Rock_CaveEntrance_02.glb", Vector3(6, 0, -53), -0.5, 2.5)

	# Broken pillars with moss — ancient site
	_place_synty(wild_node, "nature/models/SM_Prop_Pillar_Broken_01.glb", Vector3(-4, 0, -48), 0.3, 2.0)
	_place_synty(wild_node, "nature/models/SM_Prop_Pillar_Broken_02.glb", Vector3(4, 0, -49), -0.2, 2.0)
	_place_synty(wild_node, "nature/models/SM_Prop_Pillar_Moss_01.glb", Vector3(-3, 0, -54), 0.0, 2.0)

	# Large rock walls creating an arena feel around the Cauldron
	_place_synty(wild_node, "nature/models/SM_Rock_Wall_01.glb", Vector3(-8, 0, -55), 0.8, 2.5)
	_place_synty(wild_node, "nature/models/SM_Rock_Wall_02.glb", Vector3(8, 0, -55), -0.8, 2.5)

	# Sparse dead trees and branches
	_place_synty(wild_node, "nature/models/SM_Tree_Dead_01.glb", Vector3(-10, 0, -46), 0.2, 1.8)
	_place_synty(wild_node, "nature/models/SM_Tree_Dead_03.glb", Vector3(10, 0, -50), -0.1, 1.8)
	_place_synty(wild_node, "nature/models/SM_Tree_Branch_01.glb", Vector3(-5, 0, -44), 0.4, 2.0)
	_place_synty(wild_node, "nature/models/SM_Tree_Stump_03.glb", Vector3(5, 0, -46), 0.0, 1.5)

	# Mushrooms in the deep wilds
	_place_synty(wild_node, "nature/models/SM_Plant_Mushrooms_01.glb", Vector3(-3, 0, -50), 0.0, 2.5)
	_place_synty(wild_node, "nature/models/SM_Plant_Mushrooms_03.glb", Vector3(2, 0, -52), 0.5, 2.5)
