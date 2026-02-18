extends Control

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

@onready var title_label: Label = $VBox/Title
@onready var name_input: LineEdit = $VBox/NameInput
@onready var ip_input: LineEdit = $VBox/IPInput
@onready var join_button: Button = $VBox/JoinButton
@onready var status_label: Label = $VBox/StatusLabel

const PREFS_PATH = "user://connect_prefs.cfg"
const PUBLIC_SERVER_IP = "207.32.216.76"
const CONNECTION_TIMEOUT_SEC = 10.0
var DEFAULT_IP: String = "127.0.0.1" if OS.has_feature("editor") else PUBLIC_SERVER_IP
var _timeout_timer: Timer

func _ready() -> void:
	UITheme.init()
	_apply_cookbook_theme()
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	# Connection timeout timer
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.wait_time = CONNECTION_TIMEOUT_SEC
	_timeout_timer.timeout.connect(_on_connection_timeout)
	add_child(_timeout_timer)
	# Load saved preferences
	_load_prefs()

func _apply_cookbook_theme() -> void:
	var bg := ColorRect.new()
	bg.color = UITokens.PAPER_BASE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	var edge_tint := ColorRect.new()
	edge_tint.color = Color(UITokens.STAMP_BROWN.r, UITokens.STAMP_BROWN.g, UITokens.STAMP_BROWN.b, 0.08)
	edge_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge_tint)
	move_child(edge_tint, 1)

	var vbox: VBoxContainer = $VBox
	var panel := PanelContainer.new()
	panel.name = "CookbookPanel"
	panel.anchor_left = vbox.anchor_left
	panel.anchor_top = vbox.anchor_top
	panel.anchor_right = vbox.anchor_right
	panel.anchor_bottom = vbox.anchor_bottom
	panel.offset_left = vbox.offset_left
	panel.offset_top = vbox.offset_top
	panel.offset_right = vbox.offset_right
	panel.offset_bottom = vbox.offset_bottom
	panel.grow_horizontal = vbox.grow_horizontal
	panel.grow_vertical = vbox.grow_vertical
	UITheme.apply_panel(panel)
	add_child(panel)
	vbox.reparent(panel)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_top = 24
	vbox.offset_right = -24
	vbox.offset_bottom = -24

	title_label.text = "Munchie Quest"
	UITheme.style_heading(title_label)
	title_label.add_theme_font_size_override("font_size", UITheme.scaled(max(UITokens.FONT_H1 + 6, 38)))
	title_label.add_theme_color_override("font_color", UITokens.STAMP_GOLD)

	UITheme.style_button(join_button, "primary")
	UITheme.style_input(name_input)
	UITheme.style_input(ip_input)
	UITheme.style_caption(status_label)

func _on_join_pressed() -> void:
	var player_name = name_input.text.strip_edges()
	if player_name == "":
		player_name = "Player"
	var address = ip_input.text.strip_edges()
	if address == "":
		address = DEFAULT_IP
	# Save preferences
	_save_prefs(player_name, address)
	var error = NetworkManager.join_game(address, player_name)
	if error == OK:
		status_label.text = "Connecting to %s..." % address
		join_button.disabled = true
		_timeout_timer.start()
	else:
		status_label.text = "Failed to connect: %s" % str(error)

func _on_connection_succeeded() -> void:
	_timeout_timer.stop()
	status_label.text = "Connected! Loading world..."

func _on_connection_failed() -> void:
	_timeout_timer.stop()
	status_label.text = "Connection failed!"
	join_button.disabled = false

func _on_connection_timeout() -> void:
	status_label.text = "Connection timed out. Server may be unreachable."
	join_button.disabled = false
	# Disconnect the stale peer so ENet cleans up
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null

func _save_prefs(player_name: String, address: String) -> void:
	var config = ConfigFile.new()
	config.set_value("connect", "name", player_name)
	config.set_value("connect", "address", address)
	config.save(PREFS_PATH)

func _load_prefs() -> void:
	var config = ConfigFile.new()
	if config.load(PREFS_PATH) == OK:
		name_input.text = config.get_value("connect", "name", "Player")
		# In editor, always default to localhost; in export, use saved or public IP
		if OS.has_feature("editor"):
			ip_input.text = DEFAULT_IP
		else:
			var saved_ip: String = config.get_value("connect", "address", DEFAULT_IP)
			# Don't use saved localhost in exported builds — it's a dev artifact
			if saved_ip == "127.0.0.1" or saved_ip == "localhost":
				ip_input.text = DEFAULT_IP
			else:
				ip_input.text = saved_ip
	else:
		ip_input.text = DEFAULT_IP
