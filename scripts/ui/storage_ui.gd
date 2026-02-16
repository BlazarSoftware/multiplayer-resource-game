extends CanvasLayer

@onready var party_label: Label = $Panel/MarginContainer/VBox/HBox/PartyPanel/PartyLabel
@onready var party_list: VBoxContainer = $Panel/MarginContainer/VBox/HBox/PartyPanel/PartyScroll/PartyList
@onready var storage_label: Label = $Panel/MarginContainer/VBox/HBox/StoragePanel/StorageLabel
@onready var storage_list: VBoxContainer = $Panel/MarginContainer/VBox/HBox/StoragePanel/StorageScroll/StorageList
@onready var upgrade_button: Button = $Panel/MarginContainer/VBox/HBox/StoragePanel/UpgradeButton
@onready var close_button: Button = $Panel/MarginContainer/VBox/CloseButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): _close())
	upgrade_button.pressed.connect(func(): _request_upgrade())
	PlayerData.party_changed.connect(_on_data_changed)
	PlayerData.storage_changed.connect(_on_data_changed)

func _on_data_changed() -> void:
	if visible:
		_refresh()

func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	NetworkManager.request_set_busy.rpc_id(1, true)
	_refresh()

func _close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	NetworkManager.request_set_busy.rpc_id(1, false)

func _refresh() -> void:
	# Party side
	party_label.text = "Party (%d/%d)" % [PlayerData.party.size(), PlayerData.MAX_PARTY_SIZE]
	for child in party_list.get_children():
		child.queue_free()
	for i in range(PlayerData.party.size()):
		var creature = PlayerData.party[i]
		var row = _create_creature_row(creature)
		party_list.add_child(row)
		# Deposit button
		var btn = Button.new()
		btn.text = "Deposit >"
		btn.disabled = PlayerData.party.size() <= 1 or PlayerData.creature_storage.size() >= PlayerData.storage_capacity
		var idx = i
		btn.pressed.connect(func(): NetworkManager.request_deposit_creature.rpc_id(1, idx))
		row.add_child(btn)

	# Storage side
	storage_label.text = "Storage (%d/%d)" % [PlayerData.creature_storage.size(), PlayerData.storage_capacity]
	for child in storage_list.get_children():
		child.queue_free()
	for i in range(PlayerData.creature_storage.size()):
		var creature = PlayerData.creature_storage[i]
		var row = _create_creature_row(creature)
		storage_list.add_child(row)
		# Withdraw button
		var btn = Button.new()
		btn.text = "< Withdraw"
		btn.disabled = PlayerData.party.size() >= PlayerData.MAX_PARTY_SIZE
		var idx = i
		btn.pressed.connect(func(): NetworkManager.request_withdraw_creature.rpc_id(1, idx))
		row.add_child(btn)

	# Upgrade button
	_update_upgrade_button()

func _create_creature_row(creature: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Color indicator
	DataRegistry.ensure_loaded()
	var species = DataRegistry.get_species(creature.get("species_id", ""))
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(24, 24)
	color_rect.color = species.mesh_color if species else Color.GRAY
	hbox.add_child(color_rect)
	# Info label
	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hp = creature.get("hp", 0)
	var max_hp = creature.get("max_hp", 1)
	label.text = "%s  Lv.%d  HP:%d/%d" % [creature.get("nickname", "???"), creature.get("level", 1), hp, max_hp]
	# Types
	var types = creature.get("types", [])
	if types.size() > 0:
		label.text += "  [%s]" % ", ".join(PackedStringArray(types))
	hbox.add_child(label)
	return hbox

func _update_upgrade_button() -> void:
	var current_tier = _get_current_tier()
	var next_tier = current_tier + 1
	if next_tier >= NetworkManager.STORAGE_TIERS.size():
		upgrade_button.text = "Max Capacity"
		upgrade_button.disabled = true
		return
	var tier_data = NetworkManager.STORAGE_TIERS[next_tier]
	var cost_text = "$%d" % tier_data["cost"]
	var ingredients = tier_data["ingredients"] as Dictionary
	if not ingredients.is_empty():
		var parts = []
		for item_id in ingredients:
			parts.append("%dx %s" % [int(ingredients[item_id]), item_id])
		cost_text += " + " + ", ".join(PackedStringArray(parts))
	upgrade_button.text = "Upgrade to %s (%d slots) — %s" % [tier_data["name"], tier_data["capacity"], cost_text]
	# Check if player can afford
	var can_afford = PlayerData.money >= tier_data["cost"]
	for item_id in ingredients:
		if not PlayerData.has_item(item_id, int(ingredients[item_id])):
			can_afford = false
			break
	upgrade_button.disabled = not can_afford

func _get_current_tier() -> int:
	for i in range(NetworkManager.STORAGE_TIERS.size()):
		if NetworkManager.STORAGE_TIERS[i]["capacity"] == PlayerData.storage_capacity:
			return i
	return 0

func _request_upgrade() -> void:
	var next_tier = _get_current_tier() + 1
	if next_tier < NetworkManager.STORAGE_TIERS.size():
		NetworkManager.request_upgrade_storage.rpc_id(1, next_tier)
