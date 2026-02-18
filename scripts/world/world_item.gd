extends Area3D

var item_uid: int = -1
var item_id: String = ""
var amount: int = 1
var _bob_time: float = 0.0

@onready var item_mesh: MeshInstance3D = $ItemMesh
@onready var item_label: Label3D = $ItemLabel

func setup(uid: int, p_item_id: String, p_amount: int, pos: Vector3) -> void:
	item_uid = uid
	item_id = p_item_id
	amount = p_amount
	name = "WorldItem_" + str(uid)
	position = pos
	_bob_time = randf() * TAU # randomize starting phase

	# Set visuals from DataRegistry
	DataRegistry.ensure_loaded()
	var info = DataRegistry.get_item_display_info(p_item_id)
	var display_name = info.get("display_name", p_item_id)
	var icon_color: Color = info.get("icon_color", Color.WHITE)

	if item_label:
		if p_amount > 1:
			item_label.text = "%s x%d" % [display_name, p_amount]
		else:
			item_label.text = display_name
		UITheme.style_label3d(item_label, "", "world_item")
		item_label.modulate = icon_color

	if item_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = icon_color
		mat.emission_enabled = true
		mat.emission = icon_color * 0.3
		item_mesh.material_override = mat

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3 # Detect players on layer 2
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not item_mesh:
		return
	_bob_time += delta * 2.0
	item_mesh.position.y = 0.5 + sin(_bob_time) * 0.1
	item_mesh.rotation.y += delta * 1.5

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
