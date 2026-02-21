@tool
extends EditorScript
## Icon Bake Tool
##
## Renders Synty POLYGON_Icons .glb meshes through a kawaii toon shader pipeline
## and saves 256x256 PNG icon textures for use in the game UI.
##
## Usage: Open in the Godot editor, then File > Run Script (or Ctrl+Shift+X).
## Requires Synty icons imported at res://assets/synty_icons/Models/
##
## Output: res://assets/ui/textures/icons/<category>/<item_id>.png

const ICON_SIZE := 256
const SYNTY_BASE := "res://assets/synty_icons/Models/"
const OUTPUT_BASE := "res://assets/ui/textures/icons/"

# Toon shader + outline shader paths
const TOON_SHADER := "res://shaders/toon_icon.gdshader"
const OUTLINE_SHADER := "res://shaders/icon_outline.gdshader"

# ============================================================
# ICON MANIFEST
# Maps item_id → {glb, category, color_override (optional)}
# color_override tints the mesh albedo for reuse variants
# ============================================================

var icon_manifest: Dictionary = {
	# --- Ingredients (16) ---
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

	# --- Foods (12) ---
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


func _run() -> void:
	print("=== Icon Bake Tool ===")
	print("Baking %d icons..." % icon_manifest.size())

	var toon_shader := load(TOON_SHADER) as Shader
	var outline_shader := load(OUTLINE_SHADER) as Shader

	if not toon_shader:
		printerr("ERROR: Could not load toon shader at %s" % TOON_SHADER)
		return
	if not outline_shader:
		printerr("ERROR: Could not load outline shader at %s" % OUTLINE_SHADER)
		return

	# Ensure output directories exist
	var categories := ["ingredients", "foods", "tools", "battle_items", "held_items", "ui"]
	for cat in categories:
		DirAccess.make_dir_recursive_absolute(OUTPUT_BASE.path_join(cat))

	var success_count := 0
	var skip_count := 0

	for item_id: String in icon_manifest:
		var entry: Dictionary = icon_manifest[item_id]
		var glb_path: String = SYNTY_BASE + entry["glb"]
		var category: String = entry["category"]
		var output_path: String = OUTPUT_BASE.path_join(category).path_join(item_id + ".png")

		if not ResourceLoader.exists(glb_path):
			printerr("  SKIP: %s — GLB not found: %s" % [item_id, glb_path])
			skip_count += 1
			continue

		var icon_image := await _bake_single_icon(glb_path, toon_shader, outline_shader, entry)
		if icon_image:
			icon_image.save_png(output_path)
			success_count += 1
			print("  OK: %s → %s" % [item_id, output_path])
		else:
			printerr("  FAIL: %s — render failed" % item_id)
			skip_count += 1

	print("")
	print("=== Bake Complete ===")
	print("  Success: %d" % success_count)
	print("  Skipped: %d" % skip_count)
	print("  Total:   %d" % icon_manifest.size())


func _bake_single_icon(glb_path: String, toon_shader: Shader, outline_shader: Shader, entry: Dictionary) -> Image:
	# Create SubViewport
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X

	# Camera (orthographic, looking at origin)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.2  # ortho size to frame most icons
	camera.position = Vector3(0.3, 0.3, 1.0)
	camera.look_at(Vector3.ZERO)
	viewport.add_child(camera)

	# WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.9, 1.0)
	env.ambient_light_energy = 0.4
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.05
	env.adjustment_contrast = 0.95
	env.adjustment_saturation = 0.85

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	# Key light (upper-left-front)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-45, -30, 0)
	key_light.light_color = Color(1.0, 0.97, 0.92)
	key_light.light_energy = 1.2
	viewport.add_child(key_light)

	# Fill light (lower-right)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.5, -0.3, 0.5)
	fill_light.light_color = Color(0.85, 0.82, 0.95)
	fill_light.light_energy = 0.3
	fill_light.omni_range = 4.0
	viewport.add_child(fill_light)

	# Load GLB scene
	var packed_scene := load(glb_path) as PackedScene
	if not packed_scene:
		viewport.queue_free()
		return null

	var model := packed_scene.instantiate()

	# Apply toon shader to all mesh surfaces
	_apply_toon_shader(model, toon_shader, outline_shader, entry)

	# Center the model by computing its AABB
	viewport.add_child(model)
	var aabb := _get_combined_aabb(model)
	if aabb.size.length() > 0.001:
		model.position = -aabb.get_center()
		# Adjust camera size to frame the model
		var max_dim := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		camera.size = max_dim * 1.6

	# Add viewport to editor tree temporarily
	get_editor_interface().get_base_control().add_child(viewport)

	# Wait for render
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	# Capture
	var image := viewport.get_texture().get_image()
	if image:
		image.flip_y()

	# Cleanup
	viewport.queue_free()

	return image


func _apply_toon_shader(node: Node, toon_shader: Shader, outline_shader: Shader, entry: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var orig_mat := mi.mesh.surface_get_material(i)

			# Create toon material
			var toon_mat := ShaderMaterial.new()
			toon_mat.shader = toon_shader

			# Transfer albedo color from original material
			if orig_mat is StandardMaterial3D:
				var std_mat := orig_mat as StandardMaterial3D
				toon_mat.set_shader_parameter("albedo_color", std_mat.albedo_color)
				if std_mat.albedo_texture:
					toon_mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
					toon_mat.set_shader_parameter("use_texture", true)
				else:
					toon_mat.set_shader_parameter("use_texture", false)

			# Apply color override if specified
			if entry.has("color_override"):
				toon_mat.set_shader_parameter("albedo_color", entry["color_override"])
				toon_mat.set_shader_parameter("use_texture", false)

			# Create outline pass
			var outline_mat := ShaderMaterial.new()
			outline_mat.shader = outline_shader
			toon_mat.next_pass = outline_mat

			mi.set_surface_override_material(i, toon_mat)

	for child in node.get_children():
		_apply_toon_shader(child, toon_shader, outline_shader, entry)


func _get_combined_aabb(node: Node) -> AABB:
	var result := AABB()
	var found := false

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh_aabb := mi.mesh.get_aabb()
		mesh_aabb = mi.global_transform * mesh_aabb
		if not found:
			result = mesh_aabb
			found = true
		else:
			result = result.merge(mesh_aabb)

	for child in node.get_children():
		var child_aabb := _get_combined_aabb(child)
		if child_aabb.size.length() > 0.001:
			if not found:
				result = child_aabb
				found = true
			else:
				result = result.merge(child_aabb)

	return result
