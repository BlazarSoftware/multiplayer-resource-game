extends CanvasLayer

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

var challenger_name: String = ""
var challenger_peer: int = 0

@onready var panel: PanelContainer = $Panel
@onready var message_label: Label = $Panel/VBox/MessageLabel
@onready var accept_button: Button = $Panel/VBox/HBox/AcceptButton
@onready var decline_button: Button = $Panel/VBox/HBox/DeclineButton

func _ready() -> void:
	visible = false
	UITheme.init()
	UITheme.style_modal(panel)
	UITheme.style_body(message_label)
	UITheme.style_button(accept_button, "primary")
	UITheme.style_button(decline_button, "danger")
	accept_button.pressed.connect(_on_accept)
	decline_button.pressed.connect(_on_decline)

func show_challenge(player_name: String, peer: int) -> void:
	challenger_name = player_name
	challenger_peer = peer
	message_label.text = "%s challenges you to a battle!" % player_name
	message_label.add_theme_color_override("font_color", UITokens.INK_DARK)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_accept() -> void:
	var battle_mgr = get_node_or_null("/root/Main/GameWorld/BattleManager")
	if battle_mgr:
		battle_mgr.respond_to_pvp_challenge(challenger_peer, true)
	visible = false

func _on_decline() -> void:
	var battle_mgr = get_node_or_null("/root/Main/GameWorld/BattleManager")
	if battle_mgr:
		battle_mgr.respond_to_pvp_challenge(challenger_peer, false)
	visible = false
