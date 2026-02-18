extends CanvasLayer

## Excursion overlay HUD showing timer, member count, and leave button.
## Shown when player enters excursion, hidden on exit.

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

var timer_label: Label = null
var member_label: Label = null
var leave_button: Button = null
var warning_flash: ColorRect = null
var _flash_timer: float = 0.0
var _visible: bool = false

func _ready() -> void:
	layer = 6
	UITheme.init()

	# Container panel at top-right
	var panel := PanelContainer.new()
	panel.name = "ExcursionPanel"
	panel.anchor_left = 0.75
	panel.anchor_right = 0.98
	panel.anchor_top = 0.02
	panel.anchor_bottom = 0.15
	UITheme.apply_panel(panel)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "EXCURSION"
	UITheme.style_subheading(title)
	title.add_theme_color_override("font_color", UITokens.STAMP_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Timer
	timer_label = Label.new()
	timer_label.text = "15:00"
	UITheme.style_heading(timer_label)
	timer_label.add_theme_color_override("font_color", UITokens.INK_DARK)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(timer_label)

	# Member count
	member_label = Label.new()
	member_label.text = "Members: 1"
	UITheme.style_small(member_label)
	member_label.add_theme_color_override("font_color", UITokens.STAMP_BLUE)
	member_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(member_label)

	# Leave button
	leave_button = Button.new()
	leave_button.text = "Leave Excursion"
	UITheme.style_button(leave_button, "danger")
	leave_button.add_theme_font_size_override("font_size", UITheme.scaled(UITokens.FONT_SMALL))
	leave_button.pressed.connect(_on_leave_pressed)
	vbox.add_child(leave_button)

	# Warning flash overlay (full screen, hidden by default)
	warning_flash = ColorRect.new()
	warning_flash.name = "WarningFlash"
	warning_flash.anchors_preset = Control.PRESET_FULL_RECT
	warning_flash.anchor_right = 1.0
	warning_flash.anchor_bottom = 1.0
	warning_flash.color = Color(UITokens.STAMP_RED.r, UITokens.STAMP_RED.g, UITokens.STAMP_RED.b, 0.0)
	warning_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_flash.visible = false
	add_child(warning_flash)

	# Start hidden
	_set_visible(false)

func _process(delta: float) -> void:
	if _flash_timer > 0:
		_flash_timer -= delta
		if _flash_timer > 0:
			warning_flash.visible = true
			var alpha: float = sin(_flash_timer * 8.0) * 0.15 + 0.05
			warning_flash.color = Color(UITokens.STAMP_RED.r, UITokens.STAMP_RED.g, UITokens.STAMP_RED.b, maxf(alpha, 0.0))
		else:
			warning_flash.visible = false
			warning_flash.color = Color(UITokens.STAMP_RED.r, UITokens.STAMP_RED.g, UITokens.STAMP_RED.b, 0.0)

func show_excursion() -> void:
	_set_visible(true)
	timer_label.text = "15:00"
	member_label.text = "Members: 1"

func hide_excursion() -> void:
	_set_visible(false)

func update_status(time_remaining_sec: int, member_count: int) -> void:
	if timer_label:
		var mins: int = time_remaining_sec / 60
		var secs: int = time_remaining_sec % 60
		timer_label.text = "%d:%02d" % [mins, secs]
		# Color shift when low time
		if time_remaining_sec <= 30:
			timer_label.add_theme_color_override("font_color", UITokens.STAMP_RED)
		elif time_remaining_sec <= 120:
			timer_label.add_theme_color_override("font_color", UITokens.STAMP_GOLD)
		else:
			timer_label.add_theme_color_override("font_color", UITokens.INK_DARK)
	if member_label:
		member_label.text = "Members: %d" % member_count

func flash_warning() -> void:
	_flash_timer = 2.0

func _set_visible(state: bool) -> void:
	_visible = state
	for child in get_children():
		if child is Control or child is PanelContainer:
			child.visible = state

func _on_leave_pressed() -> void:
	var excursion_mgr := get_node_or_null("/root/Main/GameWorld/ExcursionManager")
	if excursion_mgr:
		excursion_mgr.request_exit_excursion.rpc_id(1)
