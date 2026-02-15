extends CanvasLayer

@onready var creature_list: VBoxContainer = $Panel/VBox/CreatureList
@onready var close_button: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	close_button.pressed.connect(func(): visible = false)
	PlayerData.party_changed.connect(_refresh)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_party"):
		visible = !visible
		if visible:
			_refresh()

func _refresh() -> void:
	for child in creature_list.get_children():
		child.queue_free()
	for i in range(PlayerData.party.size()):
		var creature = PlayerData.party[i]
		var panel = PanelContainer.new()
		creature_list.add_child(panel)
		var hbox = HBoxContainer.new()
		panel.add_child(hbox)
		# Color indicator
		DataRegistry.ensure_loaded()
		var species = DataRegistry.get_species(creature.get("species_id", ""))
		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(30, 30)
		color_rect.color = species.mesh_color if species else Color.GRAY
		hbox.add_child(color_rect)
		# Info
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vbox)
		var name_label = Label.new()
		name_label.text = "%s  Lv.%d" % [creature.get("nickname", "???"), creature.get("level", 1)]
		vbox.add_child(name_label)
		# HP
		var hp_label = Label.new()
		hp_label.text = "HP: %d/%d" % [creature.get("hp", 0), creature.get("max_hp", 1)]
		vbox.add_child(hp_label)
		# XP bar
		var xp_hbox = HBoxContainer.new()
		vbox.add_child(xp_hbox)
		var xp_label = Label.new()
		xp_label.text = "XP: "
		xp_hbox.add_child(xp_label)
		var xp_bar = ProgressBar.new()
		xp_bar.custom_minimum_size = Vector2(100, 12)
		xp_bar.show_percentage = false
		xp_bar.max_value = creature.get("xp_to_next", 100)
		xp_bar.value = creature.get("xp", 0)
		xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_hbox.add_child(xp_bar)
		var xp_num = Label.new()
		xp_num.text = "%d/%d" % [creature.get("xp", 0), creature.get("xp_to_next", 100)]
		xp_hbox.add_child(xp_num)
		# Stats
		var stats_label = Label.new()
		stats_label.text = "ATK:%d DEF:%d SPATK:%d SPDEF:%d SPD:%d" % [
			creature.get("attack", 0), creature.get("defense", 0),
			creature.get("sp_attack", 0), creature.get("sp_defense", 0),
			creature.get("speed", 0)]
		vbox.add_child(stats_label)
		# Types
		var types_label = Label.new()
		var types = creature.get("types", [])
		types_label.text = "Types: %s" % ", ".join(PackedStringArray(types))
		vbox.add_child(types_label)
		# Ability
		var ability_id = creature.get("ability_id", "")
		if ability_id != "":
			var ability = DataRegistry.get_ability(ability_id)
			var ability_label = Label.new()
			ability_label.text = "Ability: %s" % (ability.display_name if ability else ability_id)
			vbox.add_child(ability_label)
		# Held item
		var held_item_id = creature.get("held_item_id", "")
		var item_hbox = HBoxContainer.new()
		vbox.add_child(item_hbox)
		var item_label = Label.new()
		if held_item_id != "":
			var item = DataRegistry.get_held_item(held_item_id)
			item_label.text = "Held: %s" % (item.display_name if item else held_item_id)
		else:
			item_label.text = "Held: (none)"
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_hbox.add_child(item_label)
		# Equip/Unequip held item buttons (networked)
		if held_item_id != "":
			var unequip_btn = Button.new()
			unequip_btn.text = "Unequip"
			var cidx = i
			unequip_btn.pressed.connect(func(): _unequip_item(cidx))
			item_hbox.add_child(unequip_btn)
		else:
			var equip_btn = Button.new()
			equip_btn.text = "Equip"
			var cidx = i
			equip_btn.pressed.connect(func(): _show_equip_options(cidx))
			item_hbox.add_child(equip_btn)
		# Moves
		var moves_text = "Moves: "
		var creature_moves = creature.get("moves", [])
		for m in creature_moves:
			var move = DataRegistry.get_move(m)
			if move:
				moves_text += move.display_name + ", "
		var moves_label = Label.new()
		moves_label.text = moves_text.rstrip(", ")
		vbox.add_child(moves_label)
		# EVs (compact)
		var evs = creature.get("evs", {})
		if evs.size() > 0:
			var ev_text = "EVs: "
			for stat in evs:
				if int(evs[stat]) > 0:
					ev_text += "%s:%d " % [stat, int(evs[stat])]
			var ev_label = Label.new()
			ev_label.text = ev_text
			ev_label.add_theme_font_size_override("font_size", 12)
			vbox.add_child(ev_label)

func _unequip_item(creature_idx: int) -> void:
	# Send to server instead of modifying locally
	NetworkManager.request_unequip_held_item.rpc_id(1, creature_idx)

func _show_equip_options(creature_idx: int) -> void:
	# Find held items in inventory
	DataRegistry.ensure_loaded()
	var available_items = []
	for item_id in PlayerData.inventory:
		var item = DataRegistry.get_held_item(item_id)
		if item and PlayerData.inventory[item_id] > 0:
			available_items.append(item_id)
	if available_items.size() == 0:
		return
	# Equip the first available item via server RPC
	var item_id = available_items[0]
	NetworkManager.request_equip_held_item.rpc_id(1, creature_idx, item_id)
