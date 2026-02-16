extends CanvasLayer

# Trade request panel
var request_panel: PanelContainer = null
var request_label: Label = null
var accept_button: Button = null
var decline_button: Button = null
var pending_requester_peer: int = 0

# Trade panel
var trade_panel: PanelContainer = null
var partner_label: Label = null
var my_offer_list: VBoxContainer = null
var their_offer_list: VBoxContainer = null
var my_inventory_list: VBoxContainer = null
var confirm_button: Button = null
var cancel_button: Button = null
var status_label: Label = null

var partner_name: String = ""
var my_offer: Dictionary = {} # item_id -> count
var their_offer: Dictionary = {} # item_id -> count
var is_confirmed: bool = false

func _ready() -> void:
	visible = false
	_build_request_panel()
	_build_trade_panel()
	NetworkManager.trade_request_received.connect(_on_trade_request)
	NetworkManager.trade_started.connect(_on_trade_started)
	NetworkManager.trade_offer_updated.connect(_on_offer_updated)
	NetworkManager.trade_confirmed.connect(_on_trade_confirmed)
	NetworkManager.trade_completed.connect(_on_trade_completed)
	NetworkManager.trade_cancelled.connect(_on_trade_cancelled)

func _build_request_panel() -> void:
	request_panel = PanelContainer.new()
	request_panel.name = "RequestPanel"
	request_panel.anchors_preset = Control.PRESET_CENTER
	request_panel.custom_minimum_size = Vector2(350, 120)
	request_panel.visible = false
	add_child(request_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	request_panel.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	request_panel.add_child(margin)

	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(inner_vbox)

	request_label = Label.new()
	request_label.text = "Player wants to trade!"
	request_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(request_label)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	inner_vbox.add_child(hbox)

	accept_button = Button.new()
	accept_button.text = "Accept"
	accept_button.custom_minimum_size.x = 100
	accept_button.pressed.connect(_on_accept_trade)
	hbox.add_child(accept_button)

	decline_button = Button.new()
	decline_button.text = "Decline"
	decline_button.custom_minimum_size.x = 100
	decline_button.pressed.connect(_on_decline_trade)
	hbox.add_child(decline_button)

func _build_trade_panel() -> void:
	trade_panel = PanelContainer.new()
	trade_panel.name = "TradePanel"
	trade_panel.anchors_preset = Control.PRESET_FULL_RECT
	trade_panel.anchor_left = 0.05
	trade_panel.anchor_top = 0.05
	trade_panel.anchor_right = 0.95
	trade_panel.anchor_bottom = 0.95
	trade_panel.visible = false
	add_child(trade_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	trade_panel.add_child(margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(outer_vbox)

	partner_label = Label.new()
	partner_label.text = "Trading with: ..."
	partner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	partner_label.add_theme_font_size_override("font_size", 20)
	outer_vbox.add_child(partner_label)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	outer_vbox.add_child(status_label)

	# Three columns: My Offer | Their Offer | My Inventory
	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	outer_vbox.add_child(columns)

	# My Offer column
	var my_offer_col = _make_column("Your Offer")
	columns.add_child(my_offer_col)
	my_offer_list = my_offer_col.get_node("Scroll/Items")

	# Their Offer column
	var their_offer_col = _make_column("Their Offer")
	columns.add_child(their_offer_col)
	their_offer_list = their_offer_col.get_node("Scroll/Items")

	# My Inventory column (for adding items)
	var inv_col = _make_column("Your Inventory")
	columns.add_child(inv_col)
	my_inventory_list = inv_col.get_node("Scroll/Items")

	# Bottom buttons
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	outer_vbox.add_child(btn_row)

	confirm_button = Button.new()
	confirm_button.text = "Confirm Trade"
	confirm_button.custom_minimum_size = Vector2(150, 40)
	confirm_button.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(confirm_button)

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(150, 40)
	cancel_button.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(cancel_button)

func _make_column(title: String) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl = Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(lbl)

	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	var items = VBoxContainer.new()
	items.name = "Items"
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items)

	return col

# --- Signal handlers ---

func _on_trade_request(requester_name: String, requester_peer: int) -> void:
	pending_requester_peer = requester_peer
	request_label.text = "%s wants to trade!" % requester_name
	request_panel.visible = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_accept_trade() -> void:
	request_panel.visible = false
	NetworkManager.respond_trade.rpc_id(1, pending_requester_peer, true)
	pending_requester_peer = 0

func _on_decline_trade() -> void:
	request_panel.visible = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	NetworkManager.respond_trade.rpc_id(1, pending_requester_peer, false)
	pending_requester_peer = 0

func _on_trade_started(p_name: String) -> void:
	partner_name = p_name
	my_offer = {}
	their_offer = {}
	is_confirmed = false
	partner_label.text = "Trading with: %s" % partner_name
	status_label.text = ""
	confirm_button.text = "Confirm Trade"
	confirm_button.disabled = false
	request_panel.visible = false
	trade_panel.visible = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.request_set_busy.rpc_id(1, true)
	_refresh_all()

func _on_offer_updated(new_my_offer: Dictionary, new_their_offer: Dictionary) -> void:
	my_offer = new_my_offer
	their_offer = new_their_offer
	# Reset confirmation when offers change
	is_confirmed = false
	confirm_button.text = "Confirm Trade"
	confirm_button.disabled = false
	status_label.text = ""
	_refresh_all()

func _on_trade_confirmed(who: String) -> void:
	status_label.text = "%s confirmed the trade" % who

func _on_trade_completed(received_items: Dictionary) -> void:
	var msg = "Trade complete! Received: "
	var parts: Array[String] = []
	DataRegistry.ensure_loaded()
	for item_id in received_items:
		var info = DataRegistry.get_item_display_info(item_id)
		parts.append("%s x%d" % [info.get("display_name", item_id), received_items[item_id]])
	if parts.is_empty():
		msg += "nothing"
	else:
		msg += ", ".join(parts)
	status_label.text = msg
	# Close after a brief delay
	get_tree().create_timer(2.0).timeout.connect(_close)

func _on_trade_cancelled(reason: String) -> void:
	status_label.text = reason
	# Close after a brief delay
	get_tree().create_timer(1.5).timeout.connect(_close)

# --- UI actions ---

func _on_confirm_pressed() -> void:
	is_confirmed = true
	confirm_button.text = "Waiting..."
	confirm_button.disabled = true
	NetworkManager.confirm_trade.rpc_id(1)

func _on_cancel_pressed() -> void:
	NetworkManager.cancel_trade.rpc_id(1)
	_close()

func _close() -> void:
	trade_panel.visible = false
	request_panel.visible = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	NetworkManager.request_set_busy.rpc_id(1, false)
	my_offer = {}
	their_offer = {}
	is_confirmed = false

# --- Refresh ---

func _refresh_all() -> void:
	_refresh_offer_list(my_offer_list, my_offer, true)
	_refresh_offer_list(their_offer_list, their_offer, false)
	_refresh_inventory()

func _refresh_offer_list(list_node: VBoxContainer, offer: Dictionary, can_remove: bool) -> void:
	for child in list_node.get_children():
		child.queue_free()
	DataRegistry.ensure_loaded()
	for item_id in offer:
		var count = offer[item_id]
		if count <= 0:
			continue
		var info = DataRegistry.get_item_display_info(item_id)
		var hbox = HBoxContainer.new()
		list_node.add_child(hbox)

		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = info.get("icon_color", Color.GRAY)
		hbox.add_child(color_rect)

		var lbl = Label.new()
		lbl.text = " %s x%d" % [info.get("display_name", item_id), count]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		if can_remove:
			var btn = Button.new()
			btn.text = "-"
			btn.custom_minimum_size.x = 30
			var iid = item_id
			btn.pressed.connect(func(): _remove_from_offer(iid))
			hbox.add_child(btn)

func _refresh_inventory() -> void:
	for child in my_inventory_list.get_children():
		child.queue_free()
	DataRegistry.ensure_loaded()
	for item_id in PlayerData.inventory:
		var total = PlayerData.inventory[item_id]
		var offered = my_offer.get(item_id, 0)
		var available = total - offered
		if available <= 0:
			continue
		var info = DataRegistry.get_item_display_info(item_id)
		var hbox = HBoxContainer.new()
		my_inventory_list.add_child(hbox)

		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = info.get("icon_color", Color.GRAY)
		hbox.add_child(color_rect)

		var lbl = Label.new()
		lbl.text = " %s x%d" % [info.get("display_name", item_id), available]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		var btn = Button.new()
		btn.text = "+"
		btn.custom_minimum_size.x = 30
		var iid = item_id
		btn.pressed.connect(func(): _add_to_offer(iid))
		hbox.add_child(btn)

func _add_to_offer(item_id: String) -> void:
	NetworkManager.update_trade_offer.rpc_id(1, item_id, 1)

func _remove_from_offer(item_id: String) -> void:
	NetworkManager.update_trade_offer.rpc_id(1, item_id, -1)
