@tool
extends Node
## Handles execution of arbitrary GDScript code in the running game.

signal exec_ready(result: Dictionary)

var _pending := false  # Guard against double-emit


func handle_execute(params) -> Dictionary:
	# Must use call_deferred so the execution happens AFTER the bridge
	# server's await on exec_ready is registered.  Without this, the signal
	# fires synchronously before the await, causing an infinite hang.
	_pending = true
	call_deferred("_execute_deferred", params)
	return {"_deferred": exec_ready}


func _execute_deferred(params) -> void:
	if not params is Dictionary:
		_emit_result({"error": "Invalid params"})
		return

	var code: String = params.get("code", "")
	if code.is_empty():
		_emit_result({"error": "No code provided"})
		return

	var timeout_ms: int = clampi(int(params.get("timeout", 5000)), 100, 30000)

	# Build a GDScript that wraps the user's code in a function
	var script_source := _build_script(code)

	# Create and compile the script
	var script := GDScript.new()
	script.source_code = script_source
	var err := script.reload()
	if err != OK:
		_emit_result({"error": "Failed to compile GDScript: %s (error %d)" % [error_string(err), err], "source": script_source})
		return

	# Create a temporary node to execute the script
	var exec_node := Node.new()
	exec_node.set_script(script)
	get_tree().root.add_child(exec_node)

	# Safety timeout — if _mcp_execute() crashes (runtime error), this ensures
	# exec_ready still fires so the bridge doesn't hang forever.
	var safety_timer := get_tree().create_timer(timeout_ms / 1000.0)
	safety_timer.timeout.connect(func() -> void:
		if _pending:
			_emit_result({"error": "Execution timed out or crashed (no result after %dms)" % timeout_ms, "timed_out": true})
	)

	# Execute the function
	var result: Variant = null
	var exec_error: String = ""

	if exec_node.has_method("_mcp_execute"):
		result = exec_node._mcp_execute()
	else:
		exec_error = "Compiled script missing _mcp_execute method"

	# Clean up
	exec_node.queue_free()

	if not exec_error.is_empty():
		_emit_result({"error": exec_error})
		return

	# Convert result to JSON-safe format
	var safe_result = _make_json_safe(result)

	_emit_result({
		"status": "ok",
		"return_value": safe_result,
		"timed_out": false,
	})


## Emit result exactly once per request (guards against double-emit from
## both the normal path and the safety timeout).
func _emit_result(result: Dictionary) -> void:
	if not _pending:
		return
	_pending = false
	exec_ready.emit(result)


func _build_script(user_code: String) -> String:
	# Wrap user code in a script with a callable function
	# The user can set "return_value" to return data
	var lines := user_code.split("\n")
	var indented_code := ""
	for line in lines:
		indented_code += "\t" + line + "\n"

	return """extends Node

func _mcp_execute() -> Variant:
	var return_value: Variant = null
%s	return return_value
""" % indented_code


func _make_json_safe(value: Variant) -> Variant:
	if value == null:
		return null
	if value is bool or value is int or value is float or value is String:
		return value
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is Vector3:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Vector3i:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Color:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value is Rect2:
		return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
	if value is Transform2D:
		return {"origin": _make_json_safe(value.origin)}
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(_make_json_safe(item))
		return arr
	if value is Dictionary:
		var dict := {}
		for key in value:
			dict[str(key)] = _make_json_safe(value[key])
		return dict
	if value is NodePath:
		return str(value)
	if value is Node:
		return {"_node_path": str((value as Node).get_path()), "_class": (value as Node).get_class()}
	if value is Resource:
		return {"_type": "Resource", "class": value.get_class(), "path": value.resource_path}
	# Fallback: convert to string
	return str(value)
