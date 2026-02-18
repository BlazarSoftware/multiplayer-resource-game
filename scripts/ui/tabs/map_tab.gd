extends Control

# Map tab content for PauseMenu. Hosts the MinimapUI control.
const UITokens = preload("res://scripts/ui/ui_tokens.gd")

var minimap: Control
var indoor_label: Label
var hint_label: Label

func _ready() -> void:
	UITheme.init()
	_build_ui()

func _build_ui() -> void:
	# Minimap control (fills content area)
	var minimap_script = load("res://scripts/ui/minimap_ui.gd")
	minimap = Control.new()
	minimap.set_script(minimap_script)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap.clip_contents = true
	add_child(minimap)

	# Indoor label (shown when in restaurant)
	indoor_label = Label.new()
	indoor_label.text = "Indoor - Map unavailable"
	UITheme.style_subheading(indoor_label)
	indoor_label.add_theme_color_override("font_color", UITokens.INK_MEDIUM)
	indoor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indoor_label.set_anchors_preset(Control.PRESET_CENTER)
	indoor_label.position = Vector2(-150, -20)
	indoor_label.size = Vector2(300, 40)
	indoor_label.visible = false
	add_child(indoor_label)

	# Hint at bottom
	hint_label = Label.new()
	hint_label.text = "Scroll to zoom  |  Click to set target"
	UITheme.style_small(hint_label)
	hint_label.add_theme_color_override("font_color", UITokens.INK_MEDIUM)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.position = Vector2(-200, -30)
	hint_label.size = Vector2(400, 30)
	add_child(hint_label)

func activate() -> void:
	var is_indoor := (PlayerData.current_zone == "restaurant")
	minimap.visible = not is_indoor
	indoor_label.visible = is_indoor

func deactivate() -> void:
	pass
