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
		var hp_label = Label.new()
		hp_label.text = "HP: %d/%d" % [creature.get("hp", 0), creature.get("max_hp", 1)]
		vbox.add_child(hp_label)
		var stats_label = Label.new()
		stats_label.text = "ATK:%d DEF:%d SPD:%d" % [creature.get("attack", 0), creature.get("defense", 0), creature.get("speed", 0)]
		vbox.add_child(stats_label)
		var types_label = Label.new()
		var types = creature.get("types", [])
		types_label.text = "Types: %s" % ", ".join(PackedStringArray(types))
		vbox.add_child(types_label)
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
		# Release button (if not last creature)
		if PlayerData.party.size() > 1:
			var btn = Button.new()
			btn.text = "Release"
			var idx = i
			btn.pressed.connect(func(): PlayerData.remove_creature_from_party(idx); _refresh())
			hbox.add_child(btn)
