@tool
extends Node
## Handles signal subscription, polling, listing, and emission.

var _subscriptions: Dictionary = {}  # subscription_id -> {node_path, signal_name, events: Array}
var _next_sub_id: int = 0


func handle_subscribe_signal(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	var signal_name: String = params.get("signal_name", "")
	var subscription_id: String = params.get("subscription_id", "")

	if node_path.is_empty() or signal_name.is_empty():
		return {"error": "node_path and signal_name are required"}

	var tree := get_tree()
	if tree == null:
		return {"error": "No scene tree available"}

	var node: Node = tree.root.get_node_or_null(node_path.trim_prefix("/root"))
	if node_path == "/root":
		node = tree.root
	if node == null:
		return {"error": "Node not found: %s" % node_path}

	if not node.has_signal(signal_name):
		return {"error": "Node '%s' does not have signal '%s'" % [node_path, signal_name]}

	# Generate subscription ID if not provided
	if subscription_id.is_empty():
		_next_sub_id += 1
		subscription_id = "sub_%d" % _next_sub_id

	# Create subscription record
	_subscriptions[subscription_id] = {
		"node_path": node_path,
		"signal_name": signal_name,
		"events": [],
	}

	# Connect the signal
	var sub_id := subscription_id  # capture for lambda
	node.connect(signal_name, func() -> void:
		if _subscriptions.has(sub_id):
			(_subscriptions[sub_id]["events"] as Array).append({
				"timestamp_msec": Time.get_ticks_msec(),
				"signal": signal_name,
				"node": node_path,
			})
	)

	return {
		"status": "ok",
		"subscription_id": subscription_id,
		"node_path": node_path,
		"signal_name": signal_name,
	}


func handle_poll_events(params) -> Dictionary:
	var subscription_id: String = ""
	if params is Dictionary:
		subscription_id = params.get("subscription_id", "")

	var events: Array = []

	if not subscription_id.is_empty():
		# Return events for specific subscription
		if _subscriptions.has(subscription_id):
			events = _subscriptions[subscription_id]["events"].duplicate()
			_subscriptions[subscription_id]["events"] = []
		else:
			return {"error": "Subscription '%s' not found" % subscription_id}
	else:
		# Return all events from all subscriptions
		for sub_id in _subscriptions:
			var sub_events: Array = _subscriptions[sub_id]["events"]
			events.append_array(sub_events)
			_subscriptions[sub_id]["events"] = []

	return {
		"status": "ok",
		"events": events,
		"event_count": events.size(),
		"active_subscriptions": _subscriptions.size(),
	}


func handle_list_signals(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return {"error": "node_path is required"}

	var tree := get_tree()
	if tree == null:
		return {"error": "No scene tree available"}

	var node: Node = tree.root.get_node_or_null(node_path.trim_prefix("/root"))
	if node_path == "/root":
		node = tree.root
	if node == null:
		return {"error": "Node not found: %s" % node_path}

	var signals: Array = []
	for sig in node.get_signal_list():
		var sig_info := {
			"name": sig.get("name", ""),
		}
		var args: Array = sig.get("args", [])
		var arg_names: Array = []
		for arg in args:
			arg_names.append(arg.get("name", ""))
		sig_info["args"] = arg_names
		signals.append(sig_info)

	return {
		"status": "ok",
		"node": node_path,
		"class": node.get_class(),
		"signals": signals,
		"signal_count": signals.size(),
	}


func handle_emit_signal(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	var signal_name: String = params.get("signal_name", "")

	if node_path.is_empty() or signal_name.is_empty():
		return {"error": "node_path and signal_name are required"}

	var tree := get_tree()
	if tree == null:
		return {"error": "No scene tree available"}

	var node: Node = tree.root.get_node_or_null(node_path.trim_prefix("/root"))
	if node_path == "/root":
		node = tree.root
	if node == null:
		return {"error": "Node not found: %s" % node_path}

	if not node.has_signal(signal_name):
		return {"error": "Node '%s' does not have signal '%s'" % [node_path, signal_name]}

	# Emit with provided args
	var args: Array = params.get("args", [])
	match args.size():
		0: node.emit_signal(signal_name)
		1: node.emit_signal(signal_name, args[0])
		2: node.emit_signal(signal_name, args[0], args[1])
		3: node.emit_signal(signal_name, args[0], args[1], args[2])
		_: node.emit_signal(signal_name, args[0], args[1], args[2], args[3])

	return {
		"status": "ok",
		"node": node_path,
		"signal": signal_name,
		"args_count": args.size(),
	}
