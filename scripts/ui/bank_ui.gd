extends CanvasLayer

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

var title_label: Label = null
var money_label: Label = null
var balance_label: Label = null
var interest_label: Label = null
var fee_label: Label = null
var message_label: Label = null
var amount_input: SpinBox = null
var deposit_button: Button = null
var withdraw_button: Button = null
var deposit_all_button: Button = null
var withdraw_all_button: Button = null
var close_button: Button = null

var is_open: bool = false
var current_balance: int = 0
var current_money: int = 0
var current_fee_pct: float = 0.02

func _ready() -> void:
	UITheme.init()
	visible = false
	layer = 10
	_build_ui()

func _build_ui() -> void:
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.custom_minimum_size = UITheme.scaled_vec(Vector2(450, 380))
	UITheme.style_modal(panel)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "Bank"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_heading(title_label)
	vbox.add_child(title_label)

	# Info section
	money_label = Label.new()
	money_label.text = "Wallet: $0"
	UITheme.style_body(money_label)
	vbox.add_child(money_label)

	balance_label = Label.new()
	balance_label.text = "Bank Balance: $0"
	UITheme.style_body(balance_label)
	vbox.add_child(balance_label)

	interest_label = Label.new()
	interest_label.text = "Daily Interest: 0.5%  |  Max: $500/day"
	UITheme.style_small(interest_label)
	vbox.add_child(interest_label)

	fee_label = Label.new()
	fee_label.text = "Withdrawal Fee: 2%"
	UITheme.style_small(fee_label)
	vbox.add_child(fee_label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Amount input
	var input_hbox = HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(input_hbox)

	var amount_label = Label.new()
	amount_label.text = "Amount:"
	UITheme.style_small(amount_label)
	input_hbox.add_child(amount_label)

	amount_input = SpinBox.new()
	amount_input.min_value = 1
	amount_input.max_value = 999999
	amount_input.value = 100
	amount_input.step = 1
	amount_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_input(amount_input.get_line_edit())
	input_hbox.add_child(amount_input)

	# Action buttons row 1
	var btn_row1 = HBoxContainer.new()
	btn_row1.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row1)

	deposit_button = Button.new()
	deposit_button.text = "Deposit"
	deposit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(deposit_button, "primary")
	deposit_button.pressed.connect(_on_deposit)
	btn_row1.add_child(deposit_button)

	withdraw_button = Button.new()
	withdraw_button.text = "Withdraw"
	withdraw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(withdraw_button, "secondary")
	withdraw_button.pressed.connect(_on_withdraw)
	btn_row1.add_child(withdraw_button)

	# Action buttons row 2
	var btn_row2 = HBoxContainer.new()
	btn_row2.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row2)

	deposit_all_button = Button.new()
	deposit_all_button.text = "Deposit All"
	deposit_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(deposit_all_button, "secondary")
	deposit_all_button.pressed.connect(_on_deposit_all)
	btn_row2.add_child(deposit_all_button)

	withdraw_all_button = Button.new()
	withdraw_all_button.text = "Withdraw All"
	withdraw_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_button(withdraw_all_button, "secondary")
	withdraw_all_button.pressed.connect(_on_withdraw_all)
	btn_row2.add_child(withdraw_all_button)

	# Message label (feedback)
	message_label = Label.new()
	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_small(message_label)
	message_label.add_theme_color_override("font_color", UITokens.TEXT_SUCCESS)
	vbox.add_child(message_label)

	# Close button
	close_button = Button.new()
	close_button.text = "Close"
	UITheme.style_button(close_button, "danger")
	close_button.pressed.connect(_close)
	vbox.add_child(close_button)

func open_bank(balance: int, money: int, interest_earned: int, rate: float, fee_pct: float) -> void:
	current_balance = balance
	current_money = money
	current_fee_pct = fee_pct
	_update_labels()
	if interest_earned > 0:
		message_label.text = "Interest earned while away: +$%d" % interest_earned
	else:
		message_label.text = ""
	interest_label.text = "Daily Interest: %.1f%%  |  Max: $500/day" % (rate * 100.0)
	fee_label.text = "Withdrawal Fee: %d%%" % int(fee_pct * 100.0)
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.request_set_busy.rpc_id(1, true)
	ScreenTransition.open(self, "fade_scale")

func update_data(balance: int, money: int, message: String) -> void:
	current_balance = balance
	current_money = money
	_update_labels()
	if message != "":
		message_label.text = message

func show_error(reason: String) -> void:
	message_label.add_theme_color_override("font_color", UITokens.TEXT_DANGER)
	message_label.text = reason
	# Reset color after a moment
	get_tree().create_timer(2.0).timeout.connect(func():
		if message_label:
			message_label.add_theme_color_override("font_color", UITokens.TEXT_SUCCESS)
	)

func _update_labels() -> void:
	money_label.text = "Wallet: $%d" % current_money
	balance_label.text = "Bank Balance: $%d" % current_balance

func _on_deposit() -> void:
	var amount = int(amount_input.value)
	if amount <= 0:
		return
	NetworkManager.request_deposit.rpc_id(1, amount)

func _on_withdraw() -> void:
	var amount = int(amount_input.value)
	if amount <= 0:
		return
	NetworkManager.request_withdraw.rpc_id(1, amount)

func _on_deposit_all() -> void:
	if current_money <= 0:
		return
	NetworkManager.request_deposit.rpc_id(1, current_money)

func _on_withdraw_all() -> void:
	if current_balance <= 0:
		return
	NetworkManager.request_withdraw.rpc_id(1, current_balance)

func _close() -> void:
	await ScreenTransition.close(self, "fade_scale")
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	NetworkManager.request_set_busy.rpc_id(1, false)
	NetworkManager.request_close_bank.rpc_id(1)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
