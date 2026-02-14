extends Control

@onready var name_input: LineEdit = $VBox/NameInput
@onready var ip_input: LineEdit = $VBox/IPInput
@onready var join_button: Button = $VBox/JoinButton
@onready var status_label: Label = $VBox/StatusLabel

const PREFS_PATH = "user://connect_prefs.cfg"

func _ready() -> void:
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	# Load saved preferences
	_load_prefs()

func _on_join_pressed() -> void:
	var player_name = name_input.text.strip_edges()
	if player_name == "":
		player_name = "Player"
	var address = ip_input.text.strip_edges()
	if address == "":
		address = "207.32.216.76"
	# Save preferences
	_save_prefs(player_name, address)
	var error = NetworkManager.join_game(address, player_name)
	if error == OK:
		status_label.text = "Connecting to %s..." % address
		join_button.disabled = true
	else:
		status_label.text = "Failed to connect: %s" % str(error)

func _on_connection_succeeded() -> void:
	status_label.text = "Connected! Loading world..."

func _on_connection_failed() -> void:
	status_label.text = "Connection failed!"
	join_button.disabled = false

func _save_prefs(player_name: String, address: String) -> void:
	var config = ConfigFile.new()
	config.set_value("connect", "name", player_name)
	config.set_value("connect", "address", address)
	config.save(PREFS_PATH)

func _load_prefs() -> void:
	var config = ConfigFile.new()
	if config.load(PREFS_PATH) == OK:
		var saved_name = config.get_value("connect", "name", "Player")
		var saved_addr = config.get_value("connect", "address", "207.32.216.76")
		name_input.text = saved_name
		ip_input.text = saved_addr
