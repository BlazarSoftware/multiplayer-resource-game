extends Area3D

var item_uid: int = -1
var item_id: String = ""
var amount: int = 1
var _bob_time: float = 0.0
var _pulse_time: float = 0.0

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

	# Apply toon shader to all mesh instances in the gift box
	if item_mesh:
		_apply_toon_material(item_mesh)

func _apply_toon_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var toon_shader = load("res://shaders/toon_icon.gdshader") as Shader
			var outline_shader = load("res://shaders/icon_outline.gdshader") as Shader
			if not toon_shader or not outline_shader:
				continue
			var toon_mat := ShaderMaterial.new()
			toon_mat.shader = toon_shader
			toon_mat.set_shader_parameter("albedo_color", Color(0.95, 0.8, 0.3))
			toon_mat.set_shader_parameter("use_texture", false)
			var outline_mat := ShaderMaterial.new()
			outline_mat.shader = outline_shader
			toon_mat.next_pass = outline_mat
			mi.set_surface_override_material(i, toon_mat)
	for child in node.get_children():
		_apply_toon_material(child)

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
