extends Node3D

## Test scene for retarget pipeline verification.
## Loads character GLBs and applies animations from the UAL animation library.

@export var animation_library_path: String = "res://assets/animations/player_animation_library.tres"
@export var animation_name: String = "Idle_Loop"

var characters: Array[Node3D] = []

func _ready() -> void:
	# Load animation library
	var anim_lib: AnimationLibrary = load(animation_library_path)
	if not anim_lib:
		push_error("Failed to load animation library: %s" % animation_library_path)
		return
	print("Loaded animation library with %d animations" % anim_lib.get_animation_list().size())

	# Character GLBs to test
	var glb_paths: Array[String] = [
		"res://assets/characters/test/modular_male.glb",      # Known-good control
		"res://assets/characters/test/zombie_retarget_test.glb",  # Pipeline test
	]

	var x_offset := 0.0
	for path in glb_paths:
		var scene: PackedScene = load(path)
		if not scene:
			push_error("Failed to load: %s" % path)
			continue

		var instance := scene.instantiate()
		instance.position = Vector3(x_offset, 0, 0)
		add_child(instance)
		characters.append(instance)

		# Find skeleton
		var skeleton: Skeleton3D = _find_skeleton(instance)
		if not skeleton:
			push_error("%s: No Skeleton3D found!" % path)
			x_offset += 2.0
			continue

		# Print bone info
		var bone_count := skeleton.get_bone_count()
		var bone_names: Array[String] = []
		for i in range(bone_count):
			bone_names.append(skeleton.get_bone_name(i))
		print("%s: %d bones: %s" % [path.get_file(), bone_count, bone_names])

		# Check required UAL bones
		var required_bones := ["root", "pelvis", "spine_01", "spine_02", "spine_03",
			"neck_01", "Head", "clavicle_l", "upperarm_l", "lowerarm_l", "hand_l",
			"clavicle_r", "upperarm_r", "lowerarm_r", "hand_r",
			"thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]
		var missing: Array[String] = []
		for bone in required_bones:
			if skeleton.find_bone(bone) == -1:
				missing.append(bone)
		if missing.is_empty():
			print("%s: All required UAL bones present!" % path.get_file())
		else:
			push_error("%s: Missing bones: %s" % [path.get_file(), missing])

		# Set up AnimationPlayer + AnimationTree
		var anim_player := AnimationPlayer.new()
		instance.add_child(anim_player)
		anim_player.owner = instance
		anim_player.add_animation_library("", anim_lib)

		var anim_tree := AnimationTree.new()
		instance.add_child(anim_tree)
		anim_tree.owner = instance
		anim_tree.anim_player = anim_tree.get_path_to(anim_player)

		# Use AnimationNodeAnimation to play a specific animation
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = animation_name
		anim_tree.tree_root = anim_node
		anim_tree.active = true

		print("%s: Playing '%s'" % [path.get_file(), animation_name])
		x_offset += 2.0

	# Add a camera
	var cam := Camera3D.new()
	cam.position = Vector3(1, 1.5, 4)
	cam.look_at(Vector3(1, 0.8, 0))
	add_child(cam)

	# Add a light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -45, 0)
	add_child(light)

	# Add ground plane
	var ground := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(10, 10)
	ground.mesh = plane_mesh
	add_child(ground)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null
