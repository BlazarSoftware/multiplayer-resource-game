class_name CharacterAssembler
extends RefCounted

## Assembles a modular character from Synty parts on a shared skeleton.
## Loads base model (with Armature > Skeleton3D), hides default meshes,
## attaches selected part meshes, and applies the shared texture atlas material.

const MANNEQUIN_FALLBACK := "res://assets/models/mannequin_f.glb"

# Categories and their appearance dict keys
const PART_CATEGORIES := {
	"head": "head_id",
	"hair": "hair_id",
	"torso": "torso_id",
	"pants": "pants_id",
	"shoes": "shoes_id",
	"arms": "arms_id",
	"hats": "hat_id",
	"glasses": "glasses_id",
	"beard": "beard_id",
}

# Shared atlas material (loaded once, reused)
static var _atlas_material: Material = null


## Assemble a character model from an appearance dictionary.
## Returns the assembled Node3D named "CharacterModel".
## If assembly fails, returns a fallback mannequin.
static func assemble(parent: Node3D, appearance: Dictionary, old_model: Node3D = null) -> Node3D:
	# Free existing model
	if old_model and is_instance_valid(old_model):
		old_model.queue_free()

	var gender: String = appearance.get("gender", "female")
	var base_path := CharacterPartRegistry.get_base_model_path(gender)

	# Try loading base model
	var base_scene: PackedScene = load(base_path)
	if base_scene == null:
		push_warning("[CharacterAssembler] Base model not found at %s, trying fallback" % base_path)
		return _create_fallback(parent, appearance)

	var model: Node3D = base_scene.instantiate()
	model.name = "CharacterModel"

	# Find the Skeleton3D in the base model
	var skeleton := _find_skeleton(model)
	if skeleton == null:
		push_warning("[CharacterAssembler] No Skeleton3D in base model, using fallback")
		model.queue_free()
		return _create_fallback(parent, appearance)

	# Hide all default mesh instances on the base model
	_set_meshes_visible(model, false)

	# Load and attach parts
	var atlas_mat := _get_atlas_material()
	for category in PART_CATEGORIES:
		var key: String = PART_CATEGORIES[category]
		var part_id: String = appearance.get(key, "")
		if part_id == "":
			continue
		_attach_part(skeleton, gender, category, part_id, atlas_mat)

	parent.add_child(model)
	return model


## Reassemble a character in-place (for appearance changes).
## Removes old model, builds new one, returns it.
static func reassemble(parent: Node3D, appearance: Dictionary) -> Node3D:
	var old_model := parent.get_node_or_null("CharacterModel")
	return assemble(parent, appearance, old_model)


## Create a fallback mannequin (original UAL model with color tint).
static func _create_fallback(parent: Node3D, appearance: Dictionary) -> Node3D:
	var scene: PackedScene = load(MANNEQUIN_FALLBACK)
	if scene == null:
		push_error("[CharacterAssembler] Cannot load fallback mannequin!")
		# Last resort: empty Node3D
		var empty := Node3D.new()
		empty.name = "CharacterModel"
		parent.add_child(empty)
		return empty

	var model: Node3D = scene.instantiate()
	model.name = "CharacterModel"
	parent.add_child(model)
	return model


## Attach a part mesh to the skeleton.
static func _attach_part(skeleton: Skeleton3D, gender: String, category: String, part_id: String, atlas_mat: Material) -> void:
	var part_path := CharacterPartRegistry.get_part_path(gender, category, part_id)
	var part_scene: PackedScene = load(part_path)
	if part_scene == null:
		# Silently skip missing parts — they might not be imported yet
		return

	var part_inst: Node3D = part_scene.instantiate()

	# Extract all MeshInstance3D nodes from the part and reparent to skeleton
	var meshes := _find_all_mesh_instances(part_inst)
	for mi: MeshInstance3D in meshes:
		# Detach from part instance
		mi.get_parent().remove_child(mi)
		mi.name = category + "_" + part_id + "_" + str(meshes.find(mi))

		# Apply atlas material if available
		if atlas_mat:
			mi.material_override = atlas_mat

		# Add to skeleton so skinning works
		skeleton.add_child(mi)

	# Cleanup the now-empty part instance
	part_inst.queue_free()


## Get or create the shared atlas material.
static func _get_atlas_material() -> Material:
	if _atlas_material:
		return _atlas_material

	var atlas_path := CharacterPartRegistry.get_texture_atlas_path()
	var atlas_tex: Texture2D = load(atlas_path)
	if atlas_tex == null:
		return null

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atlas_tex
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_atlas_material = mat
	return _atlas_material


## Find Skeleton3D in node tree.
static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null


## Find all MeshInstance3D nodes recursively.
static func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_mesh_instances(child))
	return result


## Set visibility on all MeshInstance3D children.
static func _set_meshes_visible(node: Node, visible: bool) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = visible
	for child in node.get_children():
		_set_meshes_visible(child, visible)
