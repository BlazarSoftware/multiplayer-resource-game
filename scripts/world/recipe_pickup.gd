extends Area3D

@export var scroll_id: String = "" # recipe scroll to grant
@export var pickup_id: String = "" # unique identifier for save tracking

var _claimed_players: Dictionary = {} # player_name -> true

func _ready() -> void:
	add_to_group("recipe_pickup")
	collision_layer = 0
	collision_mask = 3 # Detect players on layer 2
	body_entered.connect(_on_body_entered)

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
	var pname = NetworkManager.player_data_store[peer_id].get("player_name", "")
	if pname == "" or pname in _claimed_players:
		return
	if scroll_id == "":
		return
	# Grant scroll
	_claimed_players[pname] = true
	NetworkManager.server_add_inventory(peer_id, scroll_id, 1)
	NetworkManager._sync_inventory_full.rpc_id(peer_id, NetworkManager.player_data_store[peer_id].get("inventory", {}))
	DataRegistry.ensure_loaded()
	var scroll = DataRegistry.get_recipe_scroll(scroll_id)
	var scroll_name = scroll.display_name if scroll else scroll_id
	NetworkManager._notify_recipe_unlocked.rpc_id(peer_id, "", "Found " + scroll_name + "!")
	print("[RecipePickup] ", peer_id, " found ", scroll_name, " at ", pickup_id)

func get_claimed_data() -> Dictionary:
	return _claimed_players.duplicate()

func load_claimed_data(data: Dictionary) -> void:
	_claimed_players = data.duplicate()
