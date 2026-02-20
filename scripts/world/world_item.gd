extends Area3D

var item_uid: int = -1
var item_id: String = ""
var amount: int = 1
var _bob_time: float = 0.0
var _pulse_time: float = 0.0
var _is_headless: bool = false

@onready var item_mesh: Node3D = $ItemMesh
@onready var item_label: Label3D = $ItemLabel

func setup(uid: int, p_item_id: String, p_amount: int, pos: Vector3) -> void:
	item_uid = uid
	item_id = p_item_id
	amount = p_amount
	name = "WorldItem_" + str(uid)
	position = pos
	_bob_time = randf() * TAU # randomize starting phase
	_pulse_time = randf() * TAU
	_is_headless = DisplayServer.get_name() == "headless"

	# Set label from DataRegistry
	DataRegistry.ensure_loaded()
	var info = DataRegistry.get_item_display_info(p_item_id)
	var display_name = info.get("display_name", p_item_id)

	if item_label:
		if p_amount > 1:
			item_label.text = "%s x%d" % [display_name, p_amount]
		else:
			item_label.text = display_name
		UITheme.style_label3d(item_label, "", "world_item")

	# Swap model if a 3D food/treasure model is available (client only)
	if item_mesh and not _is_headless:
		_swap_model(p_item_id)

func _swap_model(p_item_id: String) -> void:
	var scene := WorldItemModels.load_model_scene(p_item_id)
	if not scene:
		# No mapped model — keep default gift box, apply toon shader
		_apply_toon_material(item_mesh, false)
		return
	# Remove existing mesh children (gift box)
	for child in item_mesh.get_children():
		child.queue_free()
	# Instantiate the new model
	var model := scene.instantiate()
	var s: float = WorldItemModels.get_scale(p_item_id)
	model.scale = Vector3(s, s, s)
	model.position.y = WorldItemModels.get_y_offset(p_item_id)
	item_mesh.add_child(model)
	# Apply toon shader, preserving original textures
	_apply_toon_material(model, true)

func _apply_toon_material(node: Node, preserve_texture: bool = false) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var toon_shader = load("res://shaders/toon_icon.gdshader") as Shader
			var outline_shader = load("res://shaders/icon_outline.gdshader") as Shader
			if not toon_shader or not outline_shader:
				continue
			var toon_mat := ShaderMaterial.new()
			toon_mat.shader = toon_shader
			# Check if the original material has a texture we should preserve
			var orig_mat = mi.mesh.surface_get_material(i)
			var has_texture := false
			if preserve_texture and orig_mat is StandardMaterial3D:
				var std_mat := orig_mat as StandardMaterial3D
				if std_mat.albedo_texture:
					toon_mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)
					toon_mat.set_shader_parameter("albedo_color", std_mat.albedo_color)
					toon_mat.set_shader_parameter("use_texture", true)
					has_texture = true
			if not has_texture:
				toon_mat.set_shader_parameter("albedo_color", Color(0.95, 0.8, 0.3))
				toon_mat.set_shader_parameter("use_texture", false)
			var outline_mat := ShaderMaterial.new()
			outline_mat.shader = outline_shader
			toon_mat.next_pass = outline_mat
			mi.set_surface_override_material(i, toon_mat)
	for child in node.get_children():
		_apply_toon_material(child, preserve_texture)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3 # Detect players on layer 2
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not item_mesh:
		return
	_bob_time += delta * 2.0
	_pulse_time += delta * 1.2
	# Bob up and down
	item_mesh.position.y = 0.5 + sin(_bob_time) * 0.1
	# Rotate
	item_mesh.rotation.y += delta * 1.5
	# Gentle scale pulse
	var scale_factor := 1.0 + sin(_pulse_time) * 0.05
	item_mesh.scale = Vector3(scale_factor, scale_factor, scale_factor)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if not body is CharacterBody3D:
		return
	var peer_id = body.name.to_int()
	if peer_id <= 0:
		return
	if peer_id not in NetworkManager.player_data_store:
		return
	var item_mgr = get_node_or_null("/root/Main/GameWorld/WorldItemManager")
	if item_mgr:
		item_mgr.try_pickup(peer_id, item_uid)
