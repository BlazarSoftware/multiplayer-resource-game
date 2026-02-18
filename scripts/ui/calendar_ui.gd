extends CanvasLayer

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

var is_open: bool = false
var current_month: int = 3
var current_day: int = 1
var current_year: int = 1
var viewing_month: int = 3
var viewing_year: int = 1

# UI nodes (built in _ready)
var panel: PanelContainer
var month_label: Label
var year_label: Label
var prev_btn: Button
var next_btn: Button
var grid: GridContainer
var event_panel: PanelContainer
var event_label: RichTextLabel
var close_btn: Button
var day_buttons: Array = []

const DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const MONTH_NAMES = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
]

func _ready() -> void:
	layer = 10
	UITheme.init()
	_build_ui()
	visible = false

func _build_ui() -> void:
	# Root panel
	panel = PanelContainer.new()
	panel.anchor_left = 0.15
	panel.anchor_right = 0.85
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	UITheme.style_modal(panel)
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Header row: prev btn, month + year, next btn
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 40)
	UITheme.style_button(prev_btn, "secondary")
	prev_btn.pressed.connect(_on_prev_month)
	header.add_child(prev_btn)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(title_box)

	month_label = Label.new()
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_title(month_label)
	month_label.add_theme_font_size_override("font_size", UITheme.scaled(UITokens.FONT_H2))
	month_label.add_theme_color_override("font_color", UITokens.STAMP_GOLD)
	title_box.add_child(month_label)

	year_label = Label.new()
	year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_caption(year_label)
	year_label.add_theme_color_override("font_color", UITokens.INK_MEDIUM)
	title_box.add_child(year_label)

	next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(40, 40)
	UITheme.style_button(next_btn, "secondary")
	next_btn.pressed.connect(_on_next_month)
	header.add_child(next_btn)

	# Day-of-week headers
	var day_header = GridContainer.new()
	day_header.columns = 7
	for d in DAY_NAMES:
		var lbl = Label.new()
		lbl.text = d
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.style_small(lbl)
		lbl.add_theme_color_override("font_color", UITokens.INK_MEDIUM)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		day_header.add_child(lbl)
	vbox.add_child(day_header)

	# Day grid (7 cols x 4 rows = 28 days)
	grid = GridContainer.new()
	grid.columns = 7
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in range(28):
		var btn = Button.new()
		btn.text = str(i + 1)
		btn.custom_minimum_size = Vector2(50, 50)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		UITheme.style_button(btn, "secondary")
		var day_num = i + 1
		btn.pressed.connect(_on_day_clicked.bind(day_num))
		grid.add_child(btn)
		day_buttons.append(btn)
	vbox.add_child(grid)

	# Event detail panel
	event_panel = PanelContainer.new()
	event_panel.custom_minimum_size = UITheme.scaled_vec(Vector2(0, 120))
	UITheme.style_card(event_panel)
	vbox.add_child(event_panel)

	event_label = RichTextLabel.new()
	event_label.bbcode_enabled = true
	UITheme.style_richtext_defaults(event_label)
	event_label.text = "[color=#%s]Click a day to see events.[/color]" % UITokens.INK_MEDIUM.to_html(false)
	event_label.fit_content = true
	event_panel.add_child(event_label)

	# Close button
	close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = UITheme.scaled_vec(Vector2(100, 36))
	UITheme.style_button(close_btn, "secondary")
	close_btn.pressed.connect(close_calendar)
	vbox.add_child(close_btn)

func open_calendar(month: int, day: int, year: int) -> void:
	current_month = month
	current_day = day
	current_year = year
	viewing_month = month
	viewing_year = year
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.request_set_busy.rpc_id(1, true)
	_refresh_display()

func close_calendar() -> void:
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	NetworkManager.request_set_busy.rpc_id(1, false)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		close_calendar()
		get_viewport().set_input_as_handled()

func _on_prev_month() -> void:
	viewing_month -= 1
	if viewing_month < 1:
		viewing_month = 12
		viewing_year -= 1
		if viewing_year < 1:
			viewing_year = 1
			viewing_month = 1
	_refresh_display()

func _on_next_month() -> void:
	viewing_month += 1
	if viewing_month > 12:
		viewing_month = 1
		viewing_year += 1
	_refresh_display()

func _on_day_clicked(day_num: int) -> void:
	var events = CalendarEvents.get_events_for_day(viewing_month, day_num)
	if events.is_empty():
		event_label.text = "[color=#%s]%s %d - No events.[/color]" % [
			UITokens.INK_MEDIUM.to_html(false),
			MONTH_NAMES[viewing_month - 1],
			day_num
		]
	else:
		var text = "[b][color=#%s]%s %d[/color][/b]\n" % [
			UITokens.INK_DARK.to_html(false),
			MONTH_NAMES[viewing_month - 1],
			day_num
		]
		for ev in events:
			var icon = ""
			match str(ev.get("type", "")):
				"birthday":
					icon = "[color=#%s]B[/color] " % UITokens.TYPE_SWEET.to_html(false)
				"festival":
					icon = "[color=#%s]*[/color] " % UITokens.STAMP_GOLD.to_html(false)
				"holiday":
					icon = "[color=#%s]*[/color] " % UITokens.STAMP_BLUE.to_html(false)
			text += icon + "[b][color=#%s]%s[/color][/b] [color=#%s]- %s[/color]\n" % [
				UITokens.INK_DARK.to_html(false),
				str(ev["name"]),
				UITokens.INK_MEDIUM.to_html(false),
				str(ev["description"])
			]
		event_label.text = text

func _refresh_display() -> void:
	month_label.text = MONTH_NAMES[viewing_month - 1]
	year_label.text = "Year " + str(viewing_year)

	# Get events for this month
	var month_events = CalendarEvents.get_events_for_month(viewing_month)
	var event_days: Dictionary = {} # day -> Array of events
	for ev in month_events:
		var d = int(ev["day"])
		if d not in event_days:
			event_days[d] = []
		event_days[d].append(ev)

	# Update day buttons
	for i in range(28):
		var day_num = i + 1
		var btn: Button = day_buttons[i]
		btn.text = str(day_num)
		btn.add_theme_color_override("font_color", UITokens.INK_DARK)
		btn.add_theme_color_override("font_hover_color", UITokens.INK_DARK)
		btn.add_theme_color_override("font_pressed_color", UITokens.INK_DARK)

		# Reset style
		var style = UITheme.make_panel_style(UITokens.PAPER_TAN, UITokens.STAMP_BROWN, 4, 1)
		style.content_margin_left = 4
		style.content_margin_top = 4
		style.content_margin_right = 4
		style.content_margin_bottom = 4

		# Current day highlight
		if viewing_month == current_month and viewing_year == current_year and day_num == current_day:
			style.bg_color = UITokens.PAPER_CREAM
			style.border_color = UITokens.STAMP_GOLD
			style.set_border_width_all(3)

		# Event markers
		if day_num in event_days:
			var events = event_days[day_num]
			var marker = ""
			for ev in events:
				match str(ev.get("type", "")):
					"birthday":
						style.bg_color = UITokens.PAPER_TAN
						style.border_color = UITokens.TYPE_SWEET
						marker += " B"
					"festival":
						style.bg_color = UITokens.PAPER_TAN
						style.border_color = UITokens.STAMP_GOLD
						marker += " *"
					"holiday":
						style.bg_color = UITokens.PAPER_TAN
						style.border_color = UITokens.STAMP_BLUE
						marker += " *"
			btn.text = str(day_num) + marker

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)

	event_label.text = "[color=#%s]Click a day to see events.[/color]" % UITokens.INK_MEDIUM.to_html(false)
