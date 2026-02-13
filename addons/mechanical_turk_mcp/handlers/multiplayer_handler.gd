@tool
extends Node
## Handles live multiplayer configuration, authority, RPC, replication, and telemetry requests.

const MAX_EVENT_QUEUE: int = 512

var _event_queue: Array[Dictionary] = []
var _tracked_multiplayer: Dictionary = {}
var _tracked_synchronizers: Dictionary = {}


func _normalize_root_path(path: String) -> String:
	if path.is_empty() or path == "root" or path == ".":
		return "/root"
	if path.begins_with("/root"):
		return path
	if path.begins_with("/"):
		return "/root" + path
	if path.begins_with("root/"):
		return "/" + path
	return "/root/" + path


func _root_path_to_node_path(path: String) -> NodePath:
	var normalized := _normalize_root_path(path)
	if normalized == "/root":
		return NodePath("")
	return NodePath(normalized)


func _get_tree_safe() -> SceneTree:
	var tree := get_tree()
	return tree


func _get_node_by_path(path: String) -> Node:
	var tree := _get_tree_safe()
	if tree == null:
		return null

	var normalized := _normalize_root_path(path)
	if normalized == "/root":
		return tree.root

	var rel := normalized.trim_prefix("/root")
	if rel.begins_with("/"):
		rel = rel.substr(1)
	if rel.is_empty():
		return tree.root

	var node := tree.root.get_node_or_null(rel)
	if node != null:
		return node

	return tree.root.get_node_or_null(normalized)


func _convert_typed_value(value) -> Variant:
	if typeof(value) != TYPE_DICTIONARY:
		return value
	if not value.has("_type"):
		var result := {}
		for key in value:
			result[key] = _convert_typed_value(value[key])
		return result

	var t: String = value.get("_type", "")
	match t:
		"Vector2":
			return Vector2(value.get("x", 0.0), value.get("y", 0.0))
		"Vector2i":
			return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
		"Vector3":
			return Vector3(value.get("x", 0.0), value.get("y", 0.0), value.get("z", 0.0))
		"Vector3i":
			return Vector3i(int(value.get("x", 0)), int(value.get("y", 0)), int(value.get("z", 0)))
		"Color":
			return Color(value.get("r", 0.0), value.get("g", 0.0), value.get("b", 0.0), value.get("a", 1.0))
		"Rect2":
			return Rect2(value.get("x", 0.0), value.get("y", 0.0), value.get("w", 0.0), value.get("h", 0.0))
		"NodePath":
			return NodePath(value.get("path", ""))
		"PackedByteArray":
			if value.has("base64"):
				return Marshalls.base64_to_raw(value["base64"])
			return PackedByteArray()
		_:
			return value


func _serialize_value(value) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return {"_type": "Vector2", "x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"_type": "Vector3", "x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR2I:
			return {"_type": "Vector2i", "x": value.x, "y": value.y}
		TYPE_VECTOR3I:
			return {"_type": "Vector3i", "x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"_type": "Color", "r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_NODE_PATH:
			return {"_type": "NodePath", "path": str(value)}
		TYPE_PACKED_BYTE_ARRAY:
			return {"_type": "PackedByteArray", "base64": Marshalls.raw_to_base64(value), "size": value.size()}
		TYPE_ARRAY:
			var out_arr: Array = []
			for item in value:
				out_arr.append(_serialize_value(item))
			return out_arr
		TYPE_DICTIONARY:
			var out_dict: Dictionary = {}
			for key in value:
				out_dict[str(key)] = _serialize_value(value[key])
			return out_dict
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Resource:
				return {"_type": value.get_class(), "path": value.resource_path}
			return {"_type": value.get_class()}
		_:
			return value


func _queue_event(event_type: String, data: Dictionary = {}, root_path: String = "/root") -> void:
	var entry := {
		"type": event_type,
		"timestamp_msec": Time.get_ticks_msec(),
		"root_path": _normalize_root_path(root_path),
		"data": _serialize_value(data),
	}
	_event_queue.append(entry)
	if _event_queue.size() > MAX_EVENT_QUEUE:
		_event_queue.pop_front()


func _register_multiplayer_signals(multiplayer: MultiplayerAPI, root_path: String) -> void:
	if multiplayer == null:
		return

	var normalized := _normalize_root_path(root_path)
	_tracked_multiplayer[normalized] = multiplayer

	var on_peer_connected := Callable(self, "_on_peer_connected").bind(normalized)
	if not multiplayer.peer_connected.is_connected(on_peer_connected):
		multiplayer.peer_connected.connect(on_peer_connected)

	var on_peer_disconnected := Callable(self, "_on_peer_disconnected").bind(normalized)
	if not multiplayer.peer_disconnected.is_connected(on_peer_disconnected):
		multiplayer.peer_disconnected.connect(on_peer_disconnected)

	var on_connected_to_server := Callable(self, "_on_connected_to_server").bind(normalized)
	if not multiplayer.connected_to_server.is_connected(on_connected_to_server):
		multiplayer.connected_to_server.connect(on_connected_to_server)

	var on_connection_failed := Callable(self, "_on_connection_failed").bind(normalized)
	if not multiplayer.connection_failed.is_connected(on_connection_failed):
		multiplayer.connection_failed.connect(on_connection_failed)

	var on_server_disconnected := Callable(self, "_on_server_disconnected").bind(normalized)
	if not multiplayer.server_disconnected.is_connected(on_server_disconnected):
		multiplayer.server_disconnected.connect(on_server_disconnected)

	if multiplayer is SceneMultiplayer:
		var scene_mp := multiplayer as SceneMultiplayer

		var on_peer_authenticating := Callable(self, "_on_peer_authenticating").bind(normalized)
		if not scene_mp.peer_authenticating.is_connected(on_peer_authenticating):
			scene_mp.peer_authenticating.connect(on_peer_authenticating)

		var on_peer_auth_failed := Callable(self, "_on_peer_authentication_failed").bind(normalized)
		if not scene_mp.peer_authentication_failed.is_connected(on_peer_auth_failed):
			scene_mp.peer_authentication_failed.connect(on_peer_auth_failed)

		var on_peer_packet := Callable(self, "_on_peer_packet").bind(normalized)
		if not scene_mp.peer_packet.is_connected(on_peer_packet):
			scene_mp.peer_packet.connect(on_peer_packet)


func _resolve_multiplayer(root_path: String) -> Dictionary:
	var node := _get_node_by_path(root_path)
	if node == null:
		return {"error": "Node not found for root_path: %s" % _normalize_root_path(root_path)}

	var multiplayer := node.get_multiplayer()
	if multiplayer == null:
		return {"error": "No MultiplayerAPI available for root_path: %s" % _normalize_root_path(root_path)}

	_register_multiplayer_signals(multiplayer, root_path)
	return {
		"node": node,
		"multiplayer": multiplayer,
		"root_path": _normalize_root_path(root_path),
	}


func _parse_transfer_mode(value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	var mode := str(value).to_lower()
	match mode:
		"unreliable":
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		"unreliable_ordered", "unordered":
			return MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		"reliable":
			return MultiplayerPeer.TRANSFER_MODE_RELIABLE
		_:
			return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _parse_rpc_mode(value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	var mode := str(value).to_lower()
	match mode:
		"disabled":
			return MultiplayerAPI.RPC_MODE_DISABLED
		"any", "any_peer":
			return MultiplayerAPI.RPC_MODE_ANY_PEER
		"authority", "auth":
			return MultiplayerAPI.RPC_MODE_AUTHORITY
		_:
			return MultiplayerAPI.RPC_MODE_AUTHORITY


func _parse_replication_mode(value) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	var mode := str(value).to_lower()
	match mode:
		"never":
			return SceneReplicationConfig.REPLICATION_MODE_NEVER
		"always":
			return SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		"on_change", "watch":
			return SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		_:
			return SceneReplicationConfig.REPLICATION_MODE_ALWAYS


func _parse_channels_config(raw) -> Array:
	if not (raw is Array):
		return []
	var parsed: Array = []
	for entry in raw:
		parsed.append(_parse_transfer_mode(entry))
	return parsed


func _get_peer_summary(multiplayer: MultiplayerAPI) -> Dictionary:
	var summary := {
		"has_multiplayer_peer": multiplayer.has_multiplayer_peer(),
		"is_server": multiplayer.is_server(),
		"unique_id": multiplayer.get_unique_id(),
		"peers": multiplayer.get_peers(),
	}

	if multiplayer.has_multiplayer_peer():
		var peer := multiplayer.multiplayer_peer
		summary["peer_class"] = peer.get_class()
		summary["connection_status"] = peer.get_connection_status()
		summary["transfer_channel"] = peer.transfer_channel
		summary["transfer_mode"] = peer.transfer_mode
		summary["refuse_new_connections"] = peer.refuse_new_connections

		if peer is ENetMultiplayerPeer:
			var enet_peer := peer as ENetMultiplayerPeer
			var host := enet_peer.host
			if host != null:
				summary["enet"] = {
					"local_port": host.get_local_port(),
					"max_channels": host.get_max_channels(),
					"sent_data_delta": host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA),
					"sent_packets_delta": host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS),
					"received_data_delta": host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA),
					"received_packets_delta": host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS),
				}

	return summary


func _register_synchronizer_signals(sync: MultiplayerSynchronizer) -> void:
	if sync == null:
		return
	var key := str(sync.get_instance_id())
	if _tracked_synchronizers.has(key):
		return

	var node_path := str(sync.get_path())
	var on_visibility := Callable(self, "_on_sync_visibility_changed").bind(node_path)
	if not sync.visibility_changed.is_connected(on_visibility):
		sync.visibility_changed.connect(on_visibility)

	var on_sync := Callable(self, "_on_sync_state_received").bind(node_path)
	if not sync.synchronized.is_connected(on_sync):
		sync.synchronized.connect(on_sync)

	var on_delta_sync := Callable(self, "_on_sync_delta_state_received").bind(node_path)
	if not sync.delta_synchronized.is_connected(on_delta_sync):
		sync.delta_synchronized.connect(on_delta_sync)

	_tracked_synchronizers[key] = sync


func _on_peer_connected(peer_id: int, root_path: String) -> void:
	_queue_event("multiplayer.peer_connected", {"peer_id": peer_id}, root_path)


func _on_peer_disconnected(peer_id: int, root_path: String) -> void:
	_queue_event("multiplayer.peer_disconnected", {"peer_id": peer_id}, root_path)


func _on_connected_to_server(root_path: String) -> void:
	_queue_event("multiplayer.connected_to_server", {}, root_path)


func _on_connection_failed(root_path: String) -> void:
	_queue_event("multiplayer.connection_failed", {}, root_path)


func _on_server_disconnected(root_path: String) -> void:
	_queue_event("multiplayer.server_disconnected", {}, root_path)


func _on_peer_authenticating(peer_id: int, root_path: String) -> void:
	_queue_event("multiplayer.peer_authenticating", {"peer_id": peer_id}, root_path)


func _on_peer_authentication_failed(peer_id: int, root_path: String) -> void:
	_queue_event("multiplayer.peer_authentication_failed", {"peer_id": peer_id}, root_path)


func _on_peer_packet(peer_id: int, packet: PackedByteArray, root_path: String) -> void:
	_queue_event("multiplayer.peer_packet", {
		"peer_id": peer_id,
		"packet_size": packet.size(),
		"packet_base64": Marshalls.raw_to_base64(packet),
	}, root_path)


func _on_sync_visibility_changed(for_peer: int, node_path: String) -> void:
	_queue_event("multiplayer.replication_visibility_changed", {
		"node_path": node_path,
		"for_peer": for_peer,
	})


func _on_sync_state_received(node_path: String) -> void:
	_queue_event("multiplayer.replication_synchronized", {"node_path": node_path})


func _on_sync_delta_state_received(node_path: String) -> void:
	_queue_event("multiplayer.replication_delta_synchronized", {"node_path": node_path})


func _on_auth_callback(peer_id: int, data: PackedByteArray, root_path: String) -> void:
	_queue_event("multiplayer.auth_data_received", {
		"peer_id": peer_id,
		"data_size": data.size(),
		"data_base64": Marshalls.raw_to_base64(data),
	}, root_path)


func handle_get_runtime_capabilities(_params) -> Dictionary:
	var tree := _get_tree_safe()
	if tree == null:
		return {"error": "No scene tree available"}

	var capabilities := {
		"engine_version": Engine.get_version_info(),
		"platform": {
			"name": OS.get_name(),
			"features": {
				"dotnet": OS.has_feature("dotnet"),
				"headless": OS.has_feature("headless"),
				"editor": Engine.is_editor_hint(),
			},
		},
		"supported_classes": {
			"MultiplayerAPI": ClassDB.class_exists("MultiplayerAPI"),
			"SceneMultiplayer": ClassDB.class_exists("SceneMultiplayer"),
			"ENetMultiplayerPeer": ClassDB.class_exists("ENetMultiplayerPeer"),
			"WebSocketMultiplayerPeer": ClassDB.class_exists("WebSocketMultiplayerPeer"),
			"WebRTCMultiplayerPeer": ClassDB.class_exists("WebRTCMultiplayerPeer"),
			"MultiplayerSpawner": ClassDB.class_exists("MultiplayerSpawner"),
			"MultiplayerSynchronizer": ClassDB.class_exists("MultiplayerSynchronizer"),
			"SceneReplicationConfig": ClassDB.class_exists("SceneReplicationConfig"),
		},
		"scene_tree": {
			"multiplayer_poll_enabled": tree.is_multiplayer_poll_enabled(),
			"root": str(tree.root.get_path()),
		},
		"tracked_multiplayer_roots": _tracked_multiplayer.keys(),
		"pending_event_count": _event_queue.size(),
	}

	return capabilities


func handle_transport_create(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var tree := _get_tree_safe()
	if tree == null:
		return {"error": "No scene tree available"}

	var root_path := _normalize_root_path(str(params.get("root_path", "/root")))
	var transport := str(params.get("transport", "enet")).to_lower()
	var mode := str(params.get("mode", "server")).to_lower()

	var multiplayer: MultiplayerAPI = MultiplayerAPI.create_default_interface()
	if multiplayer == null:
		return {"error": "Failed to create default MultiplayerAPI interface"}

	var peer: MultiplayerPeer = null
	var err := OK

	match transport:
		"enet":
			var enet_peer := ENetMultiplayerPeer.new()
			var bind_ip := str(params.get("bind_ip", ""))
			if not bind_ip.is_empty():
				enet_peer.set_bind_ip(bind_ip)

			var channel_count := int(params.get("channel_count", 0))
			var in_bandwidth := int(params.get("in_bandwidth", 0))
			var out_bandwidth := int(params.get("out_bandwidth", 0))

			if mode == "server":
				var server_port := int(params.get("port", 0))
				if server_port <= 0:
					return {"error": "port must be provided and > 0 for server mode"}
				var max_clients := int(params.get("max_clients", 32))
				err = enet_peer.create_server(server_port, max_clients, channel_count, in_bandwidth, out_bandwidth)
			elif mode == "client":
				var address := str(params.get("address", ""))
				var client_port := int(params.get("port", 0))
				if address.is_empty() or client_port <= 0:
					return {"error": "address and port are required for client mode"}
				var local_port := int(params.get("local_port", 0))
				err = enet_peer.create_client(address, client_port, channel_count, in_bandwidth, out_bandwidth, local_port)
			elif mode == "mesh":
				var unique_id := int(params.get("unique_id", 1))
				if unique_id <= 0:
					unique_id = 1
				err = enet_peer.create_mesh(unique_id)
			else:
				return {"error": "Unsupported ENet mode: %s" % mode}

			peer = enet_peer

		"websocket":
			var ws_peer := WebSocketMultiplayerPeer.new()
			if mode == "server":
				var ws_port := int(params.get("port", 0))
				if ws_port <= 0:
					return {"error": "port must be provided and > 0 for websocket server mode"}
				var bind_address := str(params.get("bind_address", "*"))
				err = ws_peer.create_server(ws_port, bind_address)
			elif mode == "client":
				var url := str(params.get("url", ""))
				if url.is_empty():
					var ws_address := str(params.get("address", ""))
					var ws_client_port := int(params.get("port", 0))
					if ws_address.is_empty() or ws_client_port <= 0:
						return {"error": "url or address+port are required for websocket client mode"}
					var secure := bool(params.get("secure", false))
					var scheme := "wss" if secure else "ws"
					url = "%s://%s:%d" % [scheme, ws_address, ws_client_port]
				err = ws_peer.create_client(url)
			else:
				return {"error": "Unsupported WebSocket mode: %s" % mode}

			peer = ws_peer

		"webrtc":
			var rtc_peer := WebRTCMultiplayerPeer.new()
			var channels_cfg := _parse_channels_config(params.get("channels_config", []))
			if mode == "server":
				err = rtc_peer.create_server(channels_cfg)
			elif mode == "client":
				var peer_id := int(params.get("peer_id", 2))
				err = rtc_peer.create_client(peer_id, channels_cfg)
			elif mode == "mesh":
				var mesh_peer_id := int(params.get("peer_id", 1))
				err = rtc_peer.create_mesh(mesh_peer_id, channels_cfg)
			else:
				return {"error": "Unsupported WebRTC mode: %s" % mode}

			peer = rtc_peer

		_:
			return {"error": "Unsupported transport: %s" % transport}

	if err != OK:
		return {"error": "Failed to create transport", "transport": transport, "mode": mode, "code": err, "code_string": error_string(err)}

	multiplayer.multiplayer_peer = peer
	tree.set_multiplayer(multiplayer, _root_path_to_node_path(root_path))

	if params.has("multiplayer_poll"):
		tree.set_multiplayer_poll_enabled(bool(params.get("multiplayer_poll", true)))

	_register_multiplayer_signals(multiplayer, root_path)
	_queue_event("multiplayer.transport_configured", {
		"transport": transport,
		"mode": mode,
		"peer_class": peer.get_class(),
	}, root_path)

	return {
		"status": "ok",
		"root_path": root_path,
		"transport": transport,
		"mode": mode,
		"peer": _get_peer_summary(multiplayer),
	}


func handle_transport_close(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var root_path := _normalize_root_path(str(params.get("root_path", "/root")))
	var resolved := _resolve_multiplayer(root_path)
	if resolved.has("error"):
		return resolved

	var multiplayer := resolved["multiplayer"] as MultiplayerAPI
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	_queue_event("multiplayer.transport_closed", {}, root_path)

	return {
		"status": "ok",
		"root_path": root_path,
		"peer": _get_peer_summary(multiplayer),
	}


func handle_peer_assign_to_tree(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var source_root := _normalize_root_path(str(params.get("source_root_path", "/root")))
	var target_root := _normalize_root_path(str(params.get("target_root_path", "/root")))
	var share_api := bool(params.get("share_api", false))

	var source := _resolve_multiplayer(source_root)
	if source.has("error"):
		return source

	var source_api := source["multiplayer"] as MultiplayerAPI
	if not source_api.has_multiplayer_peer():
		return {"error": "Source root has no active MultiplayerPeer", "source_root_path": source_root}

	var target_api: MultiplayerAPI
	if share_api:
		target_api = source_api
	else:
		target_api = MultiplayerAPI.create_default_interface()
		target_api.multiplayer_peer = source_api.multiplayer_peer

	var tree := _get_tree_safe()
	if tree == null:
		return {"error": "No scene tree available"}
	tree.set_multiplayer(target_api, _root_path_to_node_path(target_root))
	_register_multiplayer_signals(target_api, target_root)

	_queue_event("multiplayer.peer_assigned_to_tree", {
		"source_root_path": source_root,
		"target_root_path": target_root,
		"share_api": share_api,
	}, target_root)

	return {
		"status": "ok",
		"source_root_path": source_root,
		"target_root_path": target_root,
		"share_api": share_api,
		"peer": _get_peer_summary(target_api),
	}


func handle_authority_set(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var node_path := str(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "node_path is required"}

	var node := _get_node_by_path(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}

	var authority_id := int(params.get("authority_id", 1))
	var recursive := bool(params.get("recursive", true))
	node.set_multiplayer_authority(authority_id, recursive)

	_queue_event("multiplayer.authority_changed", {
		"node_path": str(node.get_path()),
		"authority_id": authority_id,
		"recursive": recursive,
	})

	return {
		"status": "ok",
		"node_path": str(node.get_path()),
		"authority_id": node.get_multiplayer_authority(),
		"is_local_authority": node.is_multiplayer_authority(),
	}


func handle_authority_get(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var node_path := str(params.get("node_path", ""))
	if node_path.is_empty():
		return {"error": "node_path is required"}

	var node := _get_node_by_path(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}

	return {
		"status": "ok",
		"node_path": str(node.get_path()),
		"authority_id": node.get_multiplayer_authority(),
		"is_local_authority": node.is_multiplayer_authority(),
	}


func handle_rpc_configure(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var node_path := str(params.get("node_path", ""))
	var method_name := str(params.get("method", ""))
	if node_path.is_empty() or method_name.is_empty():
		return {"error": "node_path and method are required"}

	var node := _get_node_by_path(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}

	if bool(params.get("disable", false)):
		node.rpc_config(method_name, null)
		return {
			"status": "ok",
			"node_path": str(node.get_path()),
			"method": method_name,
			"disabled": true,
			"rpc_config": _serialize_value(node.get_node_rpc_config()),
		}

	var config: Dictionary = {}
	if params.has("config") and params["config"] is Dictionary:
		config = params["config"].duplicate(true)
	else:
		config = {
			"rpc_mode": _parse_rpc_mode(params.get("rpc_mode", "authority")),
			"transfer_mode": _parse_transfer_mode(params.get("transfer_mode", "reliable")),
			"call_local": bool(params.get("call_local", false)),
			"channel": int(params.get("channel", 0)),
		}

	if config.has("rpc_mode"):
		config["rpc_mode"] = _parse_rpc_mode(config["rpc_mode"])
	if config.has("transfer_mode"):
		config["transfer_mode"] = _parse_transfer_mode(config["transfer_mode"])
	if config.has("call_local"):
		config["call_local"] = bool(config["call_local"])
	if config.has("channel"):
		config["channel"] = int(config["channel"])

	node.rpc_config(method_name, config)

	return {
		"status": "ok",
		"node_path": str(node.get_path()),
		"method": method_name,
		"applied_config": _serialize_value(config),
		"rpc_config": _serialize_value(node.get_node_rpc_config()),
	}


func handle_rpc_invoke(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var node_path := str(params.get("node_path", ""))
	var method_name := str(params.get("method", ""))
	if node_path.is_empty() or method_name.is_empty():
		return {"error": "node_path and method are required"}

	var node := _get_node_by_path(node_path)
	if node == null:
		return {"error": "Node not found: %s" % node_path}

	var converted_args: Array = []
	if params.has("arguments") and params["arguments"] is Array:
		for arg in params["arguments"]:
			converted_args.append(_convert_typed_value(arg))

	var rpc_result = OK
	if params.has("peer_id"):
		var call_args: Array = [int(params.get("peer_id", 0)), method_name]
		call_args.append_array(converted_args)
		rpc_result = int(node.callv("rpc_id", call_args))
	else:
		var call_args_broadcast: Array = [method_name]
		call_args_broadcast.append_array(converted_args)
		rpc_result = int(node.callv("rpc", call_args_broadcast))

	if rpc_result != OK:
		return {
			"error": "RPC invoke failed",
			"code": rpc_result,
			"code_string": error_string(rpc_result),
			"node_path": str(node.get_path()),
			"method": method_name,
		}

	return {
		"status": "ok",
		"node_path": str(node.get_path()),
		"method": method_name,
		"peer_id": int(params.get("peer_id", 0)) if params.has("peer_id") else null,
		"arg_count": converted_args.size(),
	}


func handle_replication_spawner_configure(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var spawner_path := str(params.get("spawner_path", ""))
	var create_if_missing := bool(params.get("create_if_missing", false))
	var spawner: MultiplayerSpawner = null

	if not spawner_path.is_empty():
		var existing := _get_node_by_path(spawner_path)
		if existing != null and existing is MultiplayerSpawner:
			spawner = existing as MultiplayerSpawner

	if spawner == null and create_if_missing:
		var parent_path := str(params.get("parent_path", "/root"))
		var parent := _get_node_by_path(parent_path)
		if parent == null:
			return {"error": "Parent node not found: %s" % parent_path}
		spawner = MultiplayerSpawner.new()
		spawner.name = str(params.get("node_name", "MultiplayerSpawner"))
		parent.add_child(spawner)

	if spawner == null:
		return {"error": "MultiplayerSpawner not found. Provide spawner_path or set create_if_missing=true"}

	if params.has("spawn_path"):
		spawner.spawn_path = NodePath(str(params.get("spawn_path", "")))
	if params.has("spawn_limit"):
		spawner.spawn_limit = int(params.get("spawn_limit", 0))

	if bool(params.get("clear_spawnable_scenes", false)):
		spawner.clear_spawnable_scenes()

	if params.has("spawnable_scenes") and params["spawnable_scenes"] is Array:
		var existing_paths: Dictionary = {}
		for i in range(spawner.get_spawnable_scene_count()):
			existing_paths[spawner.get_spawnable_scene(i)] = true
		for scene_path in params["spawnable_scenes"]:
			var path_str := str(scene_path)
			if path_str.is_empty():
				continue
			if not existing_paths.has(path_str):
				spawner.add_spawnable_scene(path_str)
				existing_paths[path_str] = true

	var scenes: Array = []
	for i in range(spawner.get_spawnable_scene_count()):
		scenes.append(spawner.get_spawnable_scene(i))

	return {
		"status": "ok",
		"spawner_path": str(spawner.get_path()),
		"spawn_path": str(spawner.spawn_path),
		"spawn_limit": spawner.spawn_limit,
		"spawnable_scenes": scenes,
	}


func handle_replication_sync_configure(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var sync_path := str(params.get("synchronizer_path", ""))
	var create_if_missing := bool(params.get("create_if_missing", false))
	var sync: MultiplayerSynchronizer = null

	if not sync_path.is_empty():
		var existing := _get_node_by_path(sync_path)
		if existing != null and existing is MultiplayerSynchronizer:
			sync = existing as MultiplayerSynchronizer

	if sync == null and create_if_missing:
		var parent_path := str(params.get("parent_path", "/root"))
		var parent := _get_node_by_path(parent_path)
		if parent == null:
			return {"error": "Parent node not found: %s" % parent_path}
		sync = MultiplayerSynchronizer.new()
		sync.name = str(params.get("node_name", "MultiplayerSynchronizer"))
		parent.add_child(sync)

	if sync == null:
		return {"error": "MultiplayerSynchronizer not found. Provide synchronizer_path or set create_if_missing=true"}

	_register_synchronizer_signals(sync)

	if params.has("root_path"):
		sync.root_path = NodePath(str(params.get("root_path", "..")))
	if params.has("replication_interval"):
		sync.replication_interval = float(params.get("replication_interval", 0.0))
	if params.has("delta_interval"):
		sync.delta_interval = float(params.get("delta_interval", 0.0))
	if params.has("public_visibility"):
		sync.public_visibility = bool(params.get("public_visibility", true))
	if params.has("visibility_update_mode"):
		sync.visibility_update_mode = int(params.get("visibility_update_mode", MultiplayerSynchronizer.VISIBILITY_PROCESS_IDLE))

	var config: SceneReplicationConfig = sync.replication_config
	if config == null:
		config = SceneReplicationConfig.new()

	if bool(params.get("clear_properties", false)):
		var existing_properties = config.get_properties()
		for path in existing_properties:
			config.remove_property(path)

		if params.has("properties") and params["properties"] is Array:
			for property_entry in params["properties"]:
				var path_str := ""
				var set_replication_mode := false
				var replication_mode := SceneReplicationConfig.REPLICATION_MODE_ALWAYS
				var set_spawn := false
				var spawn_enabled := true

				if typeof(property_entry) == TYPE_STRING:
					path_str = str(property_entry)
				elif property_entry is Dictionary:
					path_str = str(property_entry.get("path", ""))
					if property_entry.has("replication_mode") or property_entry.has("replicationMode"):
						set_replication_mode = true
						replication_mode = _parse_replication_mode(property_entry.get("replication_mode", property_entry.get("replicationMode")))
					if property_entry.has("spawn"):
						set_spawn = true
						spawn_enabled = bool(property_entry["spawn"])
				else:
					continue

				if path_str.is_empty():
					continue

				var prop_path := NodePath(path_str)
				if not config.has_property(prop_path):
					config.add_property(prop_path)
				if set_replication_mode:
					config.property_set_replication_mode(prop_path, replication_mode)
				if set_spawn:
					config.property_set_spawn(prop_path, spawn_enabled)

	sync.replication_config = config

	if params.has("visible_peers") and params["visible_peers"] is Array:
		for peer_id in params["visible_peers"]:
			sync.set_visibility_for(int(peer_id), true)

	if params.has("hidden_peers") and params["hidden_peers"] is Array:
		for peer_id in params["hidden_peers"]:
			sync.set_visibility_for(int(peer_id), false)

	if bool(params.get("update_visibility", false)):
		sync.update_visibility(int(params.get("for_peer", 0)))

	var serialized_properties: Array = []
	for path in sync.replication_config.get_properties():
		serialized_properties.append({
			"path": str(path),
			"replication_mode": sync.replication_config.property_get_replication_mode(path),
			"spawn": sync.replication_config.property_get_spawn(path),
		})

	return {
		"status": "ok",
		"synchronizer_path": str(sync.get_path()),
		"root_path": str(sync.root_path),
		"public_visibility": sync.public_visibility,
		"replication_interval": sync.replication_interval,
		"delta_interval": sync.delta_interval,
		"visibility_update_mode": sync.visibility_update_mode,
		"properties": serialized_properties,
	}


func handle_session_auth_configure(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var root_path := _normalize_root_path(str(params.get("root_path", "/root")))
	var resolved := _resolve_multiplayer(root_path)
	if resolved.has("error"):
		return resolved

	var multiplayer := resolved["multiplayer"] as MultiplayerAPI
	if not (multiplayer is SceneMultiplayer):
		return {"error": "Session auth is only available with SceneMultiplayer", "root_path": root_path}

	var scene_mp := multiplayer as SceneMultiplayer

	if params.has("auth_timeout"):
		scene_mp.auth_timeout = float(params.get("auth_timeout", 3.0))
	if params.has("server_relay"):
		scene_mp.server_relay = bool(params.get("server_relay", true))
	if params.has("allow_object_decoding"):
		scene_mp.allow_object_decoding = bool(params.get("allow_object_decoding", false))

	var manual_auth := bool(params.get("manual_auth", false))
	if manual_auth:
		scene_mp.auth_callback = Callable(self, "_on_auth_callback").bind(root_path)
	else:
		scene_mp.auth_callback = Callable()

	return {
		"status": "ok",
		"root_path": root_path,
		"manual_auth": manual_auth,
		"auth_timeout": scene_mp.auth_timeout,
		"server_relay": scene_mp.server_relay,
		"allow_object_decoding": scene_mp.allow_object_decoding,
	}


func handle_session_send_auth(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var root_path := _normalize_root_path(str(params.get("root_path", "/root")))
	var resolved := _resolve_multiplayer(root_path)
	if resolved.has("error"):
		return resolved

	var multiplayer := resolved["multiplayer"] as MultiplayerAPI
	if not (multiplayer is SceneMultiplayer):
		return {"error": "Session auth is only available with SceneMultiplayer", "root_path": root_path}

	var scene_mp := multiplayer as SceneMultiplayer
	var peer_id := int(params.get("peer_id", 0))
	if peer_id <= 0:
		return {"error": "peer_id must be > 0"}

	var data := PackedByteArray()
	if params.has("data_base64"):
		data = Marshalls.base64_to_raw(str(params.get("data_base64", "")))
	elif params.has("data"):
		var raw_data = params["data"]
		if raw_data is PackedByteArray:
			data = raw_data
		elif raw_data is Array:
			for v in raw_data:
				data.append(int(v) & 0xFF)
		elif raw_data is String:
			data = String(raw_data).to_utf8_buffer()
	else:
		return {"error": "data_base64 or data is required"}

	var err := scene_mp.send_auth(peer_id, data)
	if err != OK:
		return {"error": "send_auth failed", "code": err, "code_string": error_string(err), "peer_id": peer_id}

	return {
		"status": "ok",
		"peer_id": peer_id,
		"bytes_sent": data.size(),
	}


func handle_session_complete_auth(params) -> Dictionary:
	if not (params is Dictionary):
		return {"error": "Invalid params"}

	var root_path := _normalize_root_path(str(params.get("root_path", "/root")))
	var resolved := _resolve_multiplayer(root_path)
	if resolved.has("error"):
		return resolved

	var multiplayer := resolved["multiplayer"] as MultiplayerAPI
	if not (multiplayer is SceneMultiplayer):
		return {"error": "Session auth is only available with SceneMultiplayer", "root_path": root_path}

	var scene_mp := multiplayer as SceneMultiplayer
	var peer_id := int(params.get("peer_id", 0))
	if peer_id <= 0:
		return {"error": "peer_id must be > 0"}

	var err := scene_mp.complete_auth(peer_id)
	if err != OK:
		return {"error": "complete_auth failed", "code": err, "code_string": error_string(err), "peer_id": peer_id}

	return {
		"status": "ok",
		"peer_id": peer_id,
		"authenticating_peers": scene_mp.get_authenticating_peers(),
	}


func handle_telemetry_snapshot(params) -> Dictionary:
	if not (params is Dictionary):
		params = {}

	var root_path := _normalize_root_path(str(params.get("root_path", "/root")))
	var resolved := _resolve_multiplayer(root_path)
	if resolved.has("error"):
		return resolved

	var tree := _get_tree_safe()
	if tree == null:
		return {"error": "No scene tree available"}

	var multiplayer := resolved["multiplayer"] as MultiplayerAPI
	var telemetry := {
		"timestamp_msec": Time.get_ticks_msec(),
		"root_path": root_path,
		"multiplayer_poll_enabled": tree.is_multiplayer_poll_enabled(),
		"peer": _get_peer_summary(multiplayer),
		"performance": {
			"fps": Performance.get_monitor(Performance.TIME_FPS),
			"process_time": Performance.get_monitor(Performance.TIME_PROCESS),
			"physics_process_time": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
			"memory_static": Performance.get_monitor(Performance.MEMORY_STATIC),
			"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		},
		"pending_event_count": _event_queue.size(),
	}

	if bool(params.get("include_events", false)):
		telemetry["events"] = _event_queue.duplicate(true)

	return telemetry


func handle_poll_events(params) -> Dictionary:
	if not (params is Dictionary):
		params = {}

	var max_events := int(params.get("max_events", 100))
	if max_events <= 0:
		max_events = 1

	var root_filter := ""
	if params.has("root_path"):
		root_filter = _normalize_root_path(str(params.get("root_path", "/root")))

	var out_events: Array = []
	var kept_events: Array[Dictionary] = []

	for event in _event_queue:
		var matches := true
		if not root_filter.is_empty() and str(event.get("root_path", "")) != root_filter:
			matches = false

		if matches and out_events.size() < max_events:
			out_events.append(event)
		else:
			kept_events.append(event)

	if bool(params.get("consume", true)):
		_event_queue = kept_events

	return {
		"status": "ok",
		"events": out_events,
		"remaining_event_count": _event_queue.size(),
	}
