@tool
extends Node
## Handles VFX composition requests (spring animation).

signal spring_done(result: Dictionary)


func _convert_typed_value(value) -> Variant:
	if typeof(value) != TYPE_DICTIONARY:
		return value
	if not value.has("_type"):
		return value
	var t: String = value.get("_type", "")
	match t:
		"Vector2":
			return Vector2(value.get("x", 0.0), value.get("y", 0.0))
		"Vector2i":
			return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
		"Vector3":
			return Vector3(value.get("x", 0.0), value.get("y", 0.0), value.get("z", 0.0))
		_:
			return value


func _safe_get_node_by_path(node_path: String) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if node_path == "/root":
		return tree.root
	return tree.root.get_node_or_null(node_path.trim_prefix("/root"))


func handle_spring_animation(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")
	var target_value = params.get("target_value", null)
	var stiffness: float = float(params.get("stiffness", 200))
	var damping: float = float(params.get("damping", 20))
	var mass: float = float(params.get("mass", 1.0))

	if node_path.is_empty() or property.is_empty() or target_value == null:
		return {"error": "node_path, property, and target_value are required"}

	var node := _safe_get_node_by_path(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}

	var converted_target = _convert_typed_value(target_value)

	# Create spring animator as child of the target node
	var animator := SpringAnimator.new()
	animator.target_node = node
	animator.target_property = property
	animator.target_value = converted_target
	animator.spring_stiffness = stiffness
	animator.spring_damping = damping
	animator.spring_mass = mass
	animator.done_signal = spring_done

	node.add_child(animator)

	return {
		"_deferred": spring_done
	}


class SpringAnimator extends Node:
	var target_node: Node = null
	var target_property: String = ""
	var target_value = null
	var spring_stiffness: float = 200.0
	var spring_damping: float = 20.0
	var spring_mass: float = 1.0
	var done_signal: Signal

	var _velocity = null
	var _started := false
	var _elapsed: float = 0.0
	var _max_duration: float = 5.0

	func _ready() -> void:
		_started = true
		var current = target_node.get(target_property)
		# Initialize velocity to zero with same type
		if current is Vector2:
			_velocity = Vector2.ZERO
		elif current is Vector3:
			_velocity = Vector3.ZERO
		else:
			_velocity = 0.0

	func _physics_process(delta: float) -> void:
		if not _started or target_node == null:
			return

		_elapsed += delta
		var current = target_node.get(target_property)

		# Compute spring force: F = -k*displacement - c*velocity
		var displacement = current - target_value
		var spring_force = -spring_stiffness * displacement - spring_damping * _velocity
		var acceleration = spring_force / spring_mass

		_velocity += acceleration * delta
		var new_value = current + _velocity * delta
		target_node.set(target_property, new_value)

		# Check if settled
		var disp_mag: float = 0.0
		var vel_mag: float = 0.0
		if displacement is Vector2:
			disp_mag = (new_value - target_value).length()
			vel_mag = _velocity.length()
		elif displacement is Vector3:
			disp_mag = (new_value - target_value).length()
			vel_mag = _velocity.length()
		else:
			disp_mag = abs(new_value - target_value)
			vel_mag = abs(_velocity)

		if (disp_mag < 0.01 and vel_mag < 0.01) or _elapsed > _max_duration:
			target_node.set(target_property, target_value)
			done_signal.emit({
				"status": "ok",
				"node": str(target_node.get_path()),
				"property": target_property,
				"settled": _elapsed <= _max_duration,
				"duration": _elapsed,
			})
			queue_free()
