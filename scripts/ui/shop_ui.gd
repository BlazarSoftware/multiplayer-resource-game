extends CanvasLayer

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

var title_label: Label = null
var tab_bar: TabBar = null
var item_list: VBoxContainer = null
var close_button: Button = null
var money_label: Label = null

var current_shop_id: String = ""
var current_shop_name: String = ""
var current_catalog: Array = [] # [{item_id, buy_price}]
var current_tab: int = 0 # 0=Buy, 1=Sell

func _ready() -> void:
	UITheme.init()
	visible = false
	_build_ui()

func _build_ui() -> void:
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.custom_minimum_size = UITheme.scaled_vec(Vector2(500, 400))
	UITheme.style_modal(panel)
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.text = "Shop"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_subheading(title_label)
	vbox.add_child(title_label)

	money_label = Label.new()
	money_label.text = "Money: $0"
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_body(money_label)
	vbox.add_child(money_label)

	tab_bar = TabBar.new()
	tab_bar.add_tab("Buy")
	tab_bar.add_tab("Sell")
	tab_bar.tab_changed.connect(_on_tab_changed)
	vbox.add_child(tab_bar)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 250
	vbox.add_child(scroll)

	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_list)

	close_button = Button.new()
	close_button.text = "Close"
	UITheme.style_button(close_button, "danger")
	close_button.pressed.connect(_close)
	vbox.add_child(close_button)

func open_shop(shop_id: String, shop_name: String, catalog: Array) -> void:
	current_shop_id = shop_id
	current_shop_name = shop_name
	current_catalog = catalog
	current_tab = 0
	if tab_bar:
		tab_bar.current_tab = 0
	title_label.text = shop_name
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.request_set_busy.rpc_id(1, true)
	_refresh()
	ScreenTransition.open(self, "fade_scale")

func _close() -> void:
	await ScreenTransition.close(self, "fade_scale")
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	NetworkManager.request_set_busy.rpc_id(1, false)

func _on_tab_changed(tab_idx: int) -> void:
	current_tab = tab_idx
	_refresh()

func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()
	money_label.text = "Money: $%d" % PlayerData.money
	if current_tab == 0:
		_refresh_buy()
	else:
		_refresh_sell()

func _refresh_buy() -> void:
	DataRegistry.ensure_loaded()
	for entry in current_catalog:
		var item_id = str(entry.get("item_id", ""))
		var buy_price = int(entry.get("buy_price", 0))
		var info = DataRegistry.get_item_display_info(item_id)

		var hbox = HBoxContainer.new()
		item_list.add_child(hbox)

		var icon = UITheme.create_item_icon(info, 20)
		hbox.add_child(icon)

		var label = Label.new()
		label.text = "  %s — $%d" % [info.get("display_name", item_id), buy_price]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_small(label)
		hbox.add_child(label)

		var btn = Button.new()
		btn.text = "Buy"
		UITheme.style_button(btn, "primary")
		btn.disabled = PlayerData.money < buy_price
		var iid = item_id
		var sid = current_shop_id
		btn.pressed.connect(func(): _buy_item(iid, 1, sid))
		hbox.add_child(btn)

func _refresh_sell() -> void:
	DataRegistry.ensure_loaded()
	for item_id in PlayerData.inventory:
		var count = PlayerData.inventory[item_id]
		if count <= 0:
			continue
		var sell_price = DataRegistry.get_sell_price(item_id)
		if sell_price <= 0:
			continue
		var info = DataRegistry.get_item_display_info(item_id)

		var hbox = HBoxContainer.new()
		item_list.add_child(hbox)

		var icon = UITheme.create_item_icon(info, 20)
		hbox.add_child(icon)

		var label = Label.new()
		label.text = "  %s x%d — $%d each" % [info.get("display_name", item_id), count, sell_price]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_small(label)
		hbox.add_child(label)

		var btn = Button.new()
		btn.text = "Sell 1"
		UITheme.style_button(btn, "secondary")
		var iid = item_id
		btn.pressed.connect(func(): _sell_item(iid, 1))
		hbox.add_child(btn)

func _buy_item(item_id: String, qty: int, shop_id: String) -> void:
	NetworkManager.request_buy_item.rpc_id(1, item_id, qty, shop_id)
	AudioManager.play_sfx("item_coin")
	# Refresh after a short delay to allow server sync
	get_tree().create_timer(0.2).timeout.connect(_refresh)

func _sell_item(item_id: String, qty: int) -> void:
	NetworkManager.request_sell_item.rpc_id(1, item_id, qty)
	AudioManager.play_sfx("item_coin")
	get_tree().create_timer(0.2).timeout.connect(_refresh)
