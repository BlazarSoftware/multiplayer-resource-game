extends SceneTree
## CLI Icon Bake Tool
##
## Run with: godot --path . --headless --script tools/bake_icons_cli.gd
##
## Renders Synty POLYGON_Icons .glb meshes through a kawaii toon shader pipeline
## and saves 256x256 PNG icon textures.

const ICON_SIZE := 256
const SYNTY_BASE := "res://assets/synty_icons/Models/"
const FOOD_BASE := "res://assets/food_models/"
const TREASURE_BASE := "res://assets/treasure_models/"
const OUTPUT_BASE := "res://assets/ui/textures/icons/"
const TOON_SHADER := "res://shaders/toon_icon.gdshader"
const OUTLINE_SHADER := "res://shaders/icon_outline.gdshader"
const SYNTY_PALETTE := "res://assets/synty_icons/Textures/PolygonIcons_Texture_01_A.png"

var icon_manifest: Dictionary = {
	# --- Ingredients (23) ---
	"tomato": {"glb": "SM_Icon_Food_Tomato_01.glb", "category": "ingredients"},
	"sugar": {"glb": "SM_Icon_Crafting_Powder_01.glb", "category": "ingredients"},
	"herb": {"glb": "SM_Icon_Crafting_Leaf_01.glb", "category": "ingredients"},
	"flour": {"glb": "SM_Icon_Crafting_Grain_01.glb", "category": "ingredients"},
	"butter": {"glb": "SM_Icon_Food_Cheese_01.glb", "category": "ingredients"},
	"egg": {"glb": "SM_Icon_Food_Egg_01.glb", "category": "ingredients"},
	"milk": {"glb": "SM_Icon_Food_Milk_01.glb", "category": "ingredients"},
	"rice": {"glb": "SM_Icon_Food_Rice_Bowl_01.glb", "category": "ingredients"},
	"fruit": {"glb": "SM_Icon_Food_Apple_01.glb", "category": "ingredients"},
	"mushroom": {"glb": "SM_Icon_Crafting_Mushroom_01.glb", "category": "ingredients"},
	"fish": {"glb": "SM_Icon_Food_Fish_Raw_01.glb", "category": "ingredients"},
	"honey": {"glb": "SM_Icon_Food_Lemon_01.glb", "category": "ingredients", "color_override": Color(1.0, 0.85, 0.2)},
	"spice": {"glb": "SM_Icon_Crafting_Root_01.glb", "category": "ingredients"},
	"seaweed": {"glb": "SM_Icon_Crafting_Leaf_01.glb", "category": "ingredients", "color_override": Color(0.1, 0.4, 0.15)},
	"chocolate": {"glb": "SM_Icon_Food_Muffin_01.glb", "category": "ingredients"},
	"citrus": {"glb": "SM_Icon_Food_Orange_01.glb", "category": "ingredients"},
	# New: renamed ingredient icons
	"soy_sauce": {"glb": "SM_Icon_Bowls_01.glb", "category": "ingredients", "color_override": Color(0.35, 0.2, 0.1)},
	"broth": {"glb": "SM_Icon_Bowls_01.glb", "category": "ingredients", "color_override": Color(0.85, 0.7, 0.3)},
	# New: additional ingredients
	"cheese": {"glb": "SM_Icon_Food_Cheese_02.glb", "category": "ingredients"},
	"carrot": {"glb": "SM_Icon_Food_Carrot_01.glb", "category": "ingredients"},
	"onion": {"glb": "SM_Icon_Crafting_Root_01.glb", "category": "ingredients", "color_override": Color(0.9, 0.8, 0.4)},
	"potato": {"glb": "SM_Icon_Crafting_Root_01.glb", "category": "ingredients", "color_override": Color(0.7, 0.55, 0.3)},
	"salt": {"glb": "SM_Icon_Crafting_Powder_02.glb", "category": "ingredients"},

	# --- Foods (18) ---
	"rice_bowl": {"glb": "SM_Icon_Food_Rice_Bowl_01.glb", "category": "foods"},
	"bread": {"glb": "SM_Icon_Food_Bread_Slice_01.glb", "category": "foods"},
	"soup": {"glb": "SM_Icon_Bowls_01.glb", "category": "foods"},
	"cake": {"glb": "SM_Icon_Food_Cupcake_01.glb", "category": "foods"},
	"stew": {"glb": "SM_Icon_Bowls_01.glb", "category": "foods", "color_override": Color(0.7, 0.4, 0.2)},
	"sushi": {"glb": "SM_Icon_Food_Fish_Raw_01.glb", "category": "foods"},
	"pasta": {"glb": "SM_Icon_Food_Pasta_01.glb", "category": "foods"},
	"salad": {"glb": "SM_Icon_Food_Broccoli_01.glb", "category": "foods"},
	"pie": {"glb": "SM_Icon_Food_Donut_01.glb", "category": "foods"},
	"sandwich": {"glb": "SM_Icon_Food_Burger_01.glb", "category": "foods"},
	"smoothie": {"glb": "SM_Icon_Food_Frozen_Drink_Cup_01.glb", "category": "foods"},
	"steak": {"glb": "SM_Icon_Food_Steak_01.glb", "category": "foods"},
	# New foods
	"pizza": {"glb": "SM_Icon_Food_Pizza_01.glb", "category": "foods"},
	"burger": {"glb": "SM_Icon_Food_Burger_01.glb", "category": "foods", "color_override": Color(0.8, 0.5, 0.2)},
	"pasta_dish": {"glb": "SM_Icon_Food_Pasta_01.glb", "category": "foods", "color_override": Color(0.9, 0.4, 0.2)},
	"fruit_salad": {"glb": "SM_Icon_Food_Broccoli_01.glb", "category": "foods", "color_override": Color(0.4, 0.8, 0.3)},
	"grilled_fish": {"glb": "SM_Icon_Food_Fish_Raw_01.glb", "category": "foods", "color_override": Color(0.7, 0.5, 0.2)},
	"egg_fried_rice": {"glb": "SM_Icon_Food_Rice_Bowl_01.glb", "category": "foods", "color_override": Color(0.9, 0.8, 0.4)},

	# --- Tools ---
	"hoe": {"glb": "SM_Icon_Farm_01.glb", "category": "tools"},
	"axe": {"glb": "SM_Icon_Axe_01.glb", "category": "tools"},
	"watering_can": {"glb": "SM_Icon_GasCan_01.glb", "category": "tools", "color_override": Color(0.3, 0.5, 0.9)},
	"pickaxe": {"glb": "SM_Icon_Axe_02.glb", "category": "tools"},

	# --- Battle Items ---
	"potion": {"glb": "SM_Icon_Potion_01.glb", "category": "battle_items"},
	"super_potion": {"glb": "SM_Icon_Potion_01.glb", "category": "battle_items", "color_override": Color(0.3, 0.7, 1.0)},
	"hyper_potion": {"glb": "SM_Icon_Potion_01.glb", "category": "battle_items", "color_override": Color(0.9, 0.3, 0.9)},
	"revive": {"glb": "SM_Icon_Potion_02.glb", "category": "battle_items"},
	"antidote": {"glb": "SM_Icon_Medical_01.glb", "category": "battle_items"},
	"status_heal": {"glb": "SM_Icon_Medical_01.glb", "category": "battle_items", "color_override": Color(0.2, 0.8, 0.4)},

	# --- Held Items (18) ---
	"chili_charm": {"glb": "SM_Icon_Gem_01.glb", "category": "held_items", "color_override": Color(1.0, 0.3, 0.1)},
	"herb_sachet": {"glb": "SM_Icon_Gem_01.glb", "category": "held_items", "color_override": Color(0.3, 0.8, 0.3)},
	"honey_drop": {"glb": "SM_Icon_Gem_01.glb", "category": "held_items", "color_override": Color(1.0, 0.85, 0.2)},
	"dashi_bead": {"glb": "SM_Icon_Gem_01.glb", "category": "held_items", "color_override": Color(0.5, 0.3, 0.2)},
	"vinegar_vial": {"glb": "SM_Icon_Gem_01.glb", "category": "held_items", "color_override": Color(0.8, 0.9, 0.2)},
	"breadcrumb_ring": {"glb": "SM_Icon_Gem_01.glb", "category": "held_items", "color_override": Color(0.8, 0.7, 0.3)},
	"choice_cleaver": {"glb": "SM_Icon_Sword_01.glb", "category": "held_items"},
	"choice_pot": {"glb": "SM_Icon_Bowls_01.glb", "category": "held_items"},
	"choice_whisk": {"glb": "SM_Icon_Wrench_01.glb", "category": "held_items"},
	"iron_skillet": {"glb": "SM_Icon_Shield_01.glb", "category": "held_items", "color_override": Color(0.5, 0.5, 0.55)},
	"oven_mitt": {"glb": "SM_Icon_Shield_01.glb", "category": "held_items", "color_override": Color(0.9, 0.5, 0.2)},
	"golden_truffle": {"glb": "SM_Icon_Crafting_Mushroom_01.glb", "category": "held_items", "color_override": Color(0.95, 0.8, 0.2)},
	"leftovers_pouch": {"glb": "SM_Icon_Food_Bread_Slice_01.glb", "category": "held_items"},
	"ginger_root": {"glb": "SM_Icon_Crafting_Root_01.glb", "category": "held_items", "color_override": Color(0.85, 0.65, 0.3)},
	"focus_spatula": {"glb": "SM_Icon_Wrench_01.glb", "category": "held_items", "color_override": Color(0.6, 0.6, 0.7)},
	"precision_grater": {"glb": "SM_Icon_Wrench_01.glb", "category": "held_items", "color_override": Color(0.7, 0.7, 0.75)},
	"flavor_crystal": {"glb": "SM_Icon_Gem_01.glb", "category": "held_items", "color_override": Color(0.6, 0.3, 0.8)},
	"espresso_shot": {"glb": "SM_Icon_Food_Coffee_Cup_01.glb", "category": "held_items"},

	# --- Recipe Scroll ---
	"recipe_scroll": {"glb": "SM_Icon_Crafting_Book_01.glb", "category": "held_items"},

	# --- World Pickup ---
	"world_pickup": {"glb": "SM_Icon_Present_01.glb", "category": "ui"},

	# --- Food model icons (use food 3D models instead of Synty) ---
	"tomato_3d": {"glb": "vegetables/Tomato_01.glb", "base": "food", "category": "ingredients"},
	"carrot_3d": {"glb": "vegetables/Carrot_01.glb", "base": "food", "category": "ingredients"},
	"potato_3d": {"glb": "vegetables/Potato_01.glb", "base": "food", "category": "ingredients"},
	"onion_3d": {"glb": "vegetables/Onion_01.glb", "base": "food", "category": "ingredients"},
	"mushroom_3d": {"glb": "mushrooms/Bell_Mushroom_01.glb", "base": "food", "category": "ingredients"},
	"cheese_3d": {"glb": "cheese/Cheddar_Cheese.glb", "base": "food", "category": "ingredients"},
	"pumpkin_3d": {"glb": "vegetables/Pumpkin.glb", "base": "food", "category": "ingredients"},
	"chili_pepper_3d": {"glb": "vegetables/Chili_Pepper_01.glb", "base": "food", "category": "ingredients"},
	"corn_3d": {"glb": "vegetables/Corn_01.glb", "base": "food", "category": "ingredients"},
	"broccoli_3d": {"glb": "vegetables/Broccoli.glb", "base": "food", "category": "ingredients"},
	"cabbage_3d": {"glb": "vegetables/Cabbage_01.glb", "base": "food", "category": "ingredients"},
	"garlic_3d": {"glb": "vegetables/Garlic_01.glb", "base": "food", "category": "ingredients"},
	"apple_3d": {"glb": "fruits/Apple_01.glb", "base": "food", "category": "ingredients"},
	"lemon_3d": {"glb": "fruits/Lemon_01.glb", "base": "food", "category": "ingredients"},
	"orange_3d": {"glb": "fruits/Orange_01.glb", "base": "food", "category": "ingredients"},
	"grapes_3d": {"glb": "fruits/Grapes_Dark_01.glb", "base": "food", "category": "ingredients"},
	"banana_3d": {"glb": "fruits/Banana_01.glb", "base": "food", "category": "ingredients"},
	"starfruit_3d": {"glb": "fruits/Carambola_01.glb", "base": "food", "category": "ingredients"},
	"salmon_3d": {"glb": "fish/Salmon_01.glb", "base": "food", "category": "ingredients"},
	"bluegill_3d": {"glb": "fish/Bluegill.glb", "base": "food", "category": "ingredients"},
	"honey_jar_3d": {"glb": "jars/Honey_01.glb", "base": "food", "category": "ingredients"},
	"bottle_3d": {"glb": "drinks/Bottle_01.glb", "base": "food", "category": "ingredients"},
	"carton_3d": {"glb": "drinks/Carton_01.glb", "base": "food", "category": "ingredients"},
	# Food model icons
	"loaf_3d": {"glb": "bread/Loaf_01.glb", "base": "food", "category": "foods"},
	"baguette_3d": {"glb": "bread/Baguette.glb", "base": "food", "category": "foods"},
	"cake_3d": {"glb": "dessert/Cake_01.glb", "base": "food", "category": "foods"},
	"cake_slice_3d": {"glb": "dessert/Cake_Slice_01.glb", "base": "food", "category": "foods"},
	"donut_3d": {"glb": "dessert/Donut_01.glb", "base": "food", "category": "foods"},
	"macaron_3d": {"glb": "dessert/Macaron_01.glb", "base": "food", "category": "foods"},
	"lollipop_3d": {"glb": "candy/Lollipop_01.glb", "base": "food", "category": "foods"},
	"salmon_meat_3d": {"glb": "fish/Salmon_Meat_01.glb", "base": "food", "category": "foods"},
	"ham_3d": {"glb": "meat/Ham_01.glb", "base": "food", "category": "foods"},
	"sausage_3d": {"glb": "meat/Sausage_01.glb", "base": "food", "category": "foods"},
	"jam_3d": {"glb": "jars/Jam_Round_01.glb", "base": "food", "category": "foods"},
	"can_3d": {"glb": "drinks/Can_01.glb", "base": "food", "category": "foods"},
	# Treasure model icons
	"chest_3d": {"glb": "chests/Basic_Chest_Full.glb", "base": "treasure", "category": "treasure"},
	"gold_chest_3d": {"glb": "chests/Gold_Chest_Full.glb", "base": "treasure", "category": "treasure"},
	"scroll_3d": {"glb": "scrolls/Sealed_Scroll_01.glb", "base": "treasure", "category": "treasure"},
	"gold_coin_3d": {"glb": "coins/Gold_Coin_01.glb", "base": "treasure", "category": "treasure"},
	"ruby_3d": {"glb": "gems/Ruby_01.glb", "base": "treasure", "category": "treasure"},
	"emerald_3d": {"glb": "gems/Emerald_01.glb", "base": "treasure", "category": "treasure"},
	"diamond_3d": {"glb": "gems/Diamond_01.glb", "base": "treasure", "category": "treasure"},
	"crown_3d": {"glb": "crowns/Crown_01.glb", "base": "treasure", "category": "treasure"},
	"key_3d": {"glb": "keys/Gold_Key_01.glb", "base": "treasure", "category": "treasure"},

	# --- UI Icons ---
	"ui_settings": {"glb": "SM_Icon_Settings_01.glb", "category": "ui"},
	"ui_inventory": {"glb": "SM_Icon_Chest_01.glb", "category": "ui"},
	"ui_crafting": {"glb": "SM_Icon_Wrench_Hammer_01.glb", "category": "ui"},
	"ui_battle": {"glb": "SM_Icon_Sword_01.glb", "category": "ui"},
	"ui_social": {"glb": "SM_Icon_Social_01.glb", "category": "ui"},
	"ui_quest": {"glb": "SM_Icon_Crafting_Book_01.glb", "category": "ui"},
	"ui_shop": {"glb": "SM_Icon_Shopping_Cart_01.glb", "category": "ui"},
	"ui_map": {"glb": "SM_Icon_Mountains_01.glb", "category": "ui"},
	"ui_heart": {"glb": "SM_Icon_Heart_01.glb", "category": "ui"},
	"ui_star": {"glb": "SM_Icon_Star_01.glb", "category": "ui"},
	"ui_coin": {"glb": "SM_Icon_Coin_01.glb", "category": "ui"},
	"ui_lock": {"glb": "SM_Icon_Padlock_01.glb", "category": "ui"},
	"ui_bell": {"glb": "SM_Icon_Bell_01.glb", "category": "ui"},
	"ui_calendar": {"glb": "SM_Icon_Calendar_01.glb", "category": "ui"},
	"ui_chat": {"glb": "SM_Icon_Chat_01.glb", "category": "ui"},
	"ui_home": {"glb": "SM_Icon_Home_01.glb", "category": "ui"},
	"ui_trophy": {"glb": "SM_Icon_Trophy_01.glb", "category": "ui"},
	"ui_crown": {"glb": "SM_Icon_Crown_01.glb", "category": "ui"},
	"ui_shield": {"glb": "SM_Icon_Shield_01.glb", "category": "ui"},
	"ui_key": {"glb": "SM_Icon_Key_01.glb", "category": "ui"},
}

var _toon_shader: Shader
var _outline_shader: Shader
var _palette_texture: Texture2D
var _frames_waited := 0
var _pending_items: Array = []
var _current_item_id: String = ""
var _current_entry: Dictionary = {}
var _current_viewport: SubViewport = null
var _success_count := 0
var _skip_count := 0
var _total_count := 0

func _init() -> void:
	print("=== Icon Bake Tool (CLI) ===")

func _initialize() -> void:
	_toon_shader = load(TOON_SHADER) as Shader
	_outline_shader = load(OUTLINE_SHADER) as Shader
	_palette_texture = load(SYNTY_PALETTE) as Texture2D

	if not _toon_shader:
		printerr("ERROR: Could not load toon shader at %s" % TOON_SHADER)
		quit(1)
		return
	if not _outline_shader:
		printerr("ERROR: Could not load outline shader at %s" % OUTLINE_SHADER)
		quit(1)
		return
	if not _palette_texture:
		printerr("WARNING: Could not load palette texture at %s — icons will be white" % SYNTY_PALETTE)

	# Ensure output directories
	for cat in ["ingredients", "foods", "tools", "battle_items", "held_items", "ui", "treasure"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_BASE + cat))

	# Queue all items
	for item_id in icon_manifest:
		_pending_items.append(item_id)
	_total_count = _pending_items.size()
	print("Baking %d icons..." % _total_count)

	# Start processing
	_process_next_item()

func _process_next_item() -> void:
	if _pending_items.is_empty():
		_finish()
		return

	_current_item_id = _pending_items.pop_front()
	_current_entry = icon_manifest[_current_item_id]
	var base_dir: String = SYNTY_BASE
	if _current_entry.has("base"):
		match _current_entry["base"]:
			"food": base_dir = FOOD_BASE
			"treasure": base_dir = TREASURE_BASE
	var glb_path: String = base_dir + _current_entry["glb"]

	if not ResourceLoader.exists(glb_path):
		printerr("  SKIP: %s — GLB not found: %s" % [_current_item_id, glb_path])
		_skip_count += 1
		_process_next_item()
		return

	# Create SubViewport and scene
	_current_viewport = _create_bake_viewport(glb_path, _current_entry)
	if not _current_viewport:
		printerr("  FAIL: %s — could not create viewport" % _current_item_id)
		_skip_count += 1
		_process_next_item()
		return

	# Add to tree FIRST so global_transform works, then adjust framing
	root.add_child(_current_viewport)
	_frame_camera_on_model(_current_viewport)
	_frames_waited = 0

func _process(delta: float) -> bool:
	if _current_viewport == null:
		return false

	_frames_waited += 1
	# Wait 5 frames for shader compilation + viewport render
	if _frames_waited < 5:
		return false

	# Capture the rendered image
	var image := _current_viewport.get_texture().get_image()
	if image:
		var category: String = _current_entry["category"]
		var output_path: String = OUTPUT_BASE + category + "/" + _current_item_id + ".png"
		var global_path: String = ProjectSettings.globalize_path(output_path)
		var err := image.save_png(global_path)
		if err == OK:
			_success_count += 1
			print("  OK: %s → %s" % [_current_item_id, output_path])
		else:
			printerr("  FAIL: %s — save_png error %d" % [_current_item_id, err])
			_skip_count += 1
	else:
		printerr("  FAIL: %s — null image" % _current_item_id)
		_skip_count += 1

	# Cleanup
	root.remove_child(_current_viewport)
	_current_viewport.queue_free()
	_current_viewport = null

	# Next
	_process_next_item()
	return false

func _finish() -> void:
	print("")
	print("=== Bake Complete ===")
	print("  Success: %d" % _success_count)
	print("  Skipped: %d" % _skip_count)
	print("  Total:   %d" % _total_count)
	quit(0)

func _create_bake_viewport(glb_path: String, entry: Dictionary) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "BakeViewport"
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X

	# Camera (orthographic) — position will be adjusted in _frame_camera_on_model
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.2
	camera.position = Vector3(0.5, 0.4, 1.0)
	# Set rotation manually instead of look_at (avoids not-in-tree error)
	camera.rotation_degrees = Vector3(-15, 20, 0)
	viewport.add_child(camera)

	# WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.9, 1.0)
	env.ambient_light_energy = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.0
	env.adjustment_saturation = 0.92
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	# Key light
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45, -30, 0)
	key_light.light_color = Color(1.0, 0.97, 0.92)
	key_light.light_energy = 1.2
	viewport.add_child(key_light)

	# Fill light
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.5, -0.3, 0.5)
	fill_light.light_color = Color(0.85, 0.82, 0.95)
	fill_light.light_energy = 0.3
	fill_light.omni_range = 4.0
	viewport.add_child(fill_light)

	# Load GLB
	var packed_scene := load(glb_path) as PackedScene
	if not packed_scene:
		viewport.queue_free()
		return null

	var model := packed_scene.instantiate()
	model.name = "Model"
	_apply_toon_shader(model, entry)
	viewport.add_child(model)

	return viewport

## Called AFTER viewport is added to the tree so global_transform works.
func _frame_camera_on_model(viewport: SubViewport) -> void:
	var camera: Camera3D = viewport.get_node("Camera")
	var model: Node3D = viewport.get_node("Model")
	if not camera or not model:
		return

	# Compute AABB using local mesh AABBs (works regardless of tree state)
	var aabb := _get_local_aabb(model)
	if aabb.size.length() > 0.001:
		var center := aabb.get_center()
		model.position = -center
		var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		camera.size = max_dim * 1.8  # Extra padding for outline

	# Position camera and look at origin
	var cam_pos := Vector3(0.5, 0.4, 1.0)
	camera.position = cam_pos
	camera.look_at_from_position(cam_pos, Vector3.ZERO)

func _apply_toon_shader(node: Node, entry: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var orig_mat := mi.mesh.surface_get_material(i)

			var toon_mat := ShaderMaterial.new()
			toon_mat.shader = _toon_shader

			if orig_mat is StandardMaterial3D:
				var std_mat := orig_mat as StandardMaterial3D
				toon_mat.set_shader_parameter("albedo_color", std_mat.albedo_color)
				# Use embedded texture if present, otherwise fall back to shared palette
				var tex: Texture2D = std_mat.albedo_texture if std_mat.albedo_texture else _palette_texture
				if tex:
					toon_mat.set_shader_parameter("albedo_texture", tex)
					toon_mat.set_shader_parameter("use_texture", true)
				else:
					toon_mat.set_shader_parameter("use_texture", false)
			else:
				# No material or unknown type — use palette
				if _palette_texture:
					toon_mat.set_shader_parameter("albedo_texture", _palette_texture)
					toon_mat.set_shader_parameter("use_texture", true)
				else:
					toon_mat.set_shader_parameter("use_texture", false)

			if entry.has("color_override"):
				toon_mat.set_shader_parameter("albedo_color", entry["color_override"])
				toon_mat.set_shader_parameter("use_texture", false)

			var outline_mat := ShaderMaterial.new()
			outline_mat.shader = _outline_shader
			toon_mat.next_pass = outline_mat

			mi.set_surface_override_material(i, toon_mat)

	for child in node.get_children():
		_apply_toon_shader(child, entry)

## Compute AABB using only local mesh data (no global_transform needed).
func _get_local_aabb(node: Node) -> AABB:
	var result := AABB()
	var found := false

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var mesh_aabb := mi.mesh.get_aabb()
			# Apply the node's local transform
			mesh_aabb = mi.transform * mesh_aabb
			if not found:
				result = mesh_aabb
				found = true
			else:
				result = result.merge(mesh_aabb)

	for child in node.get_children():
		var child_aabb := _get_local_aabb(child)
		if child_aabb.size.length() > 0.001:
			if not found:
				result = child_aabb
				found = true
			else:
				result = result.merge(child_aabb)

	return result
