extends Node
## Runtime bridge autoload — runs the MCP bridge inside a standalone game process.
## Add this as an autoload singleton (Project > Project Settings > Autoload).
## Listens on port 9081 (or MECHTURK_RUNTIME_BRIDGE_PORT env var, or --bridge-port=NNNN CLI arg).
## Optional bearer token auth via MECHTURK_RUNTIME_BRIDGE_TOKEN env var.

var _bridge: Node = null


func _ready() -> void:
	# Don't run in the editor — the editor bridge (plugin.gd) handles that on port 9080
	if Engine.is_editor_hint():
		return

	_bridge = preload("res://addons/mechanical_turk_mcp/bridge_server.gd").new()

	# Configure port (CLI arg > env var > default)
	_bridge.port = _get_bridge_port()

	# Configure auth token
	var token_env := OS.get_environment("MECHTURK_RUNTIME_BRIDGE_TOKEN")
	if not token_env.is_empty():
		_bridge.auth_token = token_env

	_bridge.bridge_mode = "runtime"

	add_child(_bridge)


func _exit_tree() -> void:
	if _bridge and is_instance_valid(_bridge):
		_bridge.stop_server()
		_bridge.queue_free()
		_bridge = null


## Determine the bridge port with priority: CLI user arg > env var > default (9081).
func _get_bridge_port() -> int:
	# 1. Check CLI user args (passed after "--")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bridge-port="):
			var port_str := arg.substr("--bridge-port=".length())
			if port_str.is_valid_int():
				return int(port_str)

	# 2. Check environment variable
	var port_env := OS.get_environment("MECHTURK_RUNTIME_BRIDGE_PORT")
	if not port_env.is_empty() and port_env.is_valid_int():
		return int(port_env)

	# 3. Default
	return 9081
