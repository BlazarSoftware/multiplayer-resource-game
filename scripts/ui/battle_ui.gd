extends CanvasLayer

# StatusEffects available via class_name

@onready var enemy_name: Label = $EnemyPanel/EnemyName
@onready var enemy_hp_bar: ProgressBar = $EnemyPanel/EnemyHPBar
@onready var enemy_status: Label = $EnemyPanel/EnemyStatus
@onready var enemy_mesh_rect: ColorRect = $EnemyMesh
@onready var player_name: Label = $PlayerPanel/PlayerCreatureName
@onready var player_hp_bar: ProgressBar = $PlayerPanel/PlayerHPBar
@onready var player_status: Label = $PlayerPanel/PlayerStatus
@onready var battle_log: RichTextLabel = $LogPanel/BattleLog
@onready var move_buttons: Array = [
	$ActionPanel/MoveGrid/Move1,
	$ActionPanel/MoveGrid/Move2,
	$ActionPanel/MoveGrid/Move3,
	$ActionPanel/MoveGrid/Move4
]
@onready var flee_button: Button = $ActionPanel/BottomButtons/FleeButton
@onready var switch_button: Button = $ActionPanel/BottomButtons/SwitchButton

# New UI elements (created dynamically)
var xp_bar: ProgressBar = null
var weather_label: Label = null
var hazard_label_a: Label = null
var hazard_label_b: Label = null
var waiting_label: Label = null

var battle_mgr: Node = null

const TYPE_COLORS = {
	"spicy": Color(0.9, 0.2, 0.1),
	"sweet": Color(0.9, 0.5, 0.7),
	"sour": Color(0.7, 0.8, 0.2),
	"herbal": Color(0.2, 0.7, 0.2),
	"umami": Color(0.5, 0.3, 0.2),
	"grain": Color(0.8, 0.7, 0.3),
}

const WEATHER_NAMES = {
	"spicy": "Blazing Heat",
	"sweet": "Sugar Hail",
	"sour": "Acid Rain",
	"herbal": "Herb Breeze",
	"umami": "Umami Fog",
	"grain": "Grain Dust",
}

func _ready() -> void:
	for i in range(move_buttons.size()):
		var idx = i
		move_buttons[i].pressed.connect(func(): _on_move_pressed(idx))
	flee_button.pressed.connect(_on_flee_pressed)
	switch_button.pressed.connect(_on_switch_pressed)
	_create_dynamic_ui()

func _create_dynamic_ui() -> void:
	# XP bar under player HP bar
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 8)
	xp_bar.show_percentage = false
	xp_bar.max_value = 100
	xp_bar.value = 0
	var player_panel = get_node_or_null("PlayerPanel")
	if player_panel:
		player_panel.add_child(xp_bar)

	# Weather label (top center)
	weather_label = Label.new()
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_label.add_theme_font_size_override("font_size", 14)
	weather_label.position = Vector2(300, 5)
	weather_label.visible = false
	add_child(weather_label)

	# Hazard labels
	hazard_label_a = Label.new()
	hazard_label_a.add_theme_font_size_override("font_size", 12)
	hazard_label_a.position = Vector2(20, 420)
	hazard_label_a.visible = false
	add_child(hazard_label_a)

	hazard_label_b = Label.new()
	hazard_label_b.add_theme_font_size_override("font_size", 12)
	hazard_label_b.position = Vector2(500, 100)
	hazard_label_b.visible = false
	add_child(hazard_label_b)

	# Waiting for opponent label (PvP)
	waiting_label = Label.new()
	waiting_label.text = "Waiting for opponent..."
	waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting_label.position = Vector2(250, 250)
	waiting_label.visible = false
	add_child(waiting_label)

func setup(battle_manager: Node) -> void:
	battle_mgr = battle_manager
	battle_mgr.battle_started.connect(_on_battle_started)
	battle_mgr.battle_ended.connect(_on_battle_ended)
	battle_mgr.turn_result_received.connect(_on_turn_result)
	battle_mgr.xp_result_received.connect(_on_xp_result)
	battle_mgr.pvp_challenge_received.connect(_on_pvp_challenge)
	battle_mgr.trainer_dialogue.connect(_on_trainer_dialogue)

func _on_battle_started() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	battle_log.clear()

	var mode = battle_mgr.client_battle_mode if battle_mgr else 0
	match mode:
		0: # WILD
			battle_log.append_text("A wild creature appeared!\n")
		1: # TRAINER
			battle_log.append_text("Trainer battle!\n")
		2: # PVP
			battle_log.append_text("PvP battle!\n")

	# Hide flee for trainer/PvP
	flee_button.visible = (mode == 0)

	_refresh_ui()

func _on_battle_ended(victory: bool) -> void:
	if victory:
		battle_log.append_text("\n[color=green]Victory![/color]\n")
		await get_tree().create_timer(2.0).timeout
	else:
		battle_log.append_text("\n[color=red]Battle over.[/color]\n")
		await get_tree().create_timer(1.5).timeout
	visible = false
	weather_label.visible = false
	hazard_label_a.visible = false
	hazard_label_b.visible = false
	waiting_label.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_ui() -> void:
	if battle_mgr == null:
		return
	# Enemy info
	var enemy = battle_mgr.client_enemy
	var mode = battle_mgr.client_battle_mode if battle_mgr else 0
	var enemy_prefix = "Wild " if mode == 0 else ""
	enemy_name.text = "%s%s Lv.%d" % [enemy_prefix, enemy.get("nickname", "???"), enemy.get("level", 1)]
	var enemy_max_hp = enemy.get("max_hp", 1)
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy.get("hp", 0)
	enemy_status.text = StatusEffects.get_status_display_name(enemy.get("status", ""))
	# Set enemy color
	var species = DataRegistry.get_species(enemy.get("species_id", ""))
	if species:
		enemy_mesh_rect.color = species.mesh_color
	# Player creature
	var active_idx = battle_mgr.client_active_creature_idx
	if active_idx < PlayerData.party.size():
		var creature = PlayerData.party[active_idx]
		player_name.text = "%s Lv.%d" % [creature.get("nickname", "???"), creature.get("level", 1)]
		var max_hp = creature.get("max_hp", 1)
		player_hp_bar.max_value = max_hp
		player_hp_bar.value = creature.get("hp", 0)
		player_status.text = StatusEffects.get_status_display_name(creature.get("status", ""))
		# XP bar
		if xp_bar:
			xp_bar.max_value = creature.get("xp_to_next", 100)
			xp_bar.value = creature.get("xp", 0)
		# Move buttons
		var moves = creature.get("moves", [])
		var pp = creature.get("pp", [])
		for i in range(4):
			if i < moves.size():
				DataRegistry.ensure_loaded()
				var move = DataRegistry.get_move(moves[i])
				if move:
					var pp_text = ""
					if i < pp.size():
						pp_text = " (%d PP)" % pp[i]
					move_buttons[i].text = "%s%s" % [move.display_name, pp_text]
					var color = TYPE_COLORS.get(move.type, Color.GRAY)
					move_buttons[i].modulate = color.lerp(Color.WHITE, 0.5)
					move_buttons[i].visible = true
					move_buttons[i].disabled = (i < pp.size() and pp[i] <= 0)
				else:
					move_buttons[i].visible = false
			else:
				move_buttons[i].visible = false

func _on_move_pressed(idx: int) -> void:
	if battle_mgr == null or not battle_mgr.awaiting_action:
		return
	var active_idx = battle_mgr.client_active_creature_idx
	if active_idx >= PlayerData.party.size():
		return
	var moves = PlayerData.party[active_idx].get("moves", [])
	if idx < moves.size():
		battle_mgr.send_move(moves[idx])
		_set_buttons_enabled(false)
		if battle_mgr.client_battle_mode == 2: # PVP
			waiting_label.visible = true

func _on_flee_pressed() -> void:
	if battle_mgr:
		battle_mgr.send_flee()
		_set_buttons_enabled(false)

func _on_switch_pressed() -> void:
	if battle_mgr == null:
		return
	var current = battle_mgr.client_active_creature_idx
	for i in range(PlayerData.party.size()):
		if i != current and PlayerData.party[i].get("hp", 0) > 0:
			battle_mgr.send_switch(i)
			_set_buttons_enabled(false)
			if battle_mgr.client_battle_mode == 2:
				waiting_label.visible = true
			return
	battle_log.append_text("No other creatures available!\n")

func _on_turn_result(turn_log: Array) -> void:
	waiting_label.visible = false
	for entry in turn_log:
		var msg = _format_log_entry(entry)
		if msg != "":
			battle_log.append_text(msg + "\n")
	_refresh_ui()
	if battle_mgr and battle_mgr.awaiting_action:
		_set_buttons_enabled(true)

func _on_xp_result(results: Dictionary) -> void:
	for r in results.get("results", []):
		var xp = r.get("xp_gained", 0)
		if xp > 0:
			battle_log.append_text("[color=cyan]+%d XP[/color]\n" % xp)
		for lvl in r.get("level_ups", []):
			battle_log.append_text("[color=yellow]Level up! Now Lv.%d![/color]\n" % lvl)
		for m in r.get("new_moves", []):
			var move_def = DataRegistry.get_move(m.get("move_id", ""))
			var move_name = move_def.display_name if move_def else m.get("move_id", "???")
			if m.get("auto", false):
				battle_log.append_text("[color=green]Learned %s![/color]\n" % move_name)
			else:
				battle_log.append_text("[color=yellow]Wants to learn %s! (Full moveset)[/color]\n" % move_name)
				# TODO: Show move-replace dialog
		if r.get("evolved", false):
			var new_species = DataRegistry.get_species(r.get("new_species_id", ""))
			var evo_name = new_species.display_name if new_species else r.get("new_species_id", "")
			battle_log.append_text("[color=magenta]Evolved into %s![/color]\n" % evo_name)
	_refresh_ui()

func _on_pvp_challenge(challenger_name: String, challenger_peer: int) -> void:
	# Show a simple accept/decline in the battle log area or use a dedicated UI
	var ui = get_node_or_null("/root/Main/GameWorld/UI/PvPChallengeUI")
	if ui and ui.has_method("show_challenge"):
		ui.show_challenge(challenger_name, challenger_peer)

func _on_trainer_dialogue(trainer_name: String, text: String, _is_before: bool) -> void:
	var ui = get_node_or_null("/root/Main/GameWorld/UI/TrainerDialogueUI")
	if ui and ui.has_method("show_dialogue"):
		ui.show_dialogue(trainer_name, text)
	else:
		battle_log.append_text("[color=orange]%s: %s[/color]\n" % [trainer_name, text])

func _format_log_entry(entry: Dictionary) -> String:
	var entry_type = entry.get("type", "move")
	match entry_type:
		"move":
			var actor_name = "You" if entry.get("actor") == "player" else "Enemy"
			var move_name = entry.get("move", "???")
			var text = "%s used %s!" % [actor_name, move_name]
			if entry.get("missed", false):
				return text + " But it missed!"
			if entry.get("skipped", false):
				return "%s %s" % [actor_name, entry.get("message", "can't move!")]
			if entry.get("charging", false):
				return "%s %s" % [actor_name, entry.get("message", "is charging up!")]
			if entry.get("protecting", false):
				return "%s %s" % [actor_name, entry.get("message", "protected itself!")]
			if entry.get("blocked", false):
				return "%s's attack %s" % [actor_name, entry.get("message", "was blocked!")]
			if entry.has("damage"):
				text += " Dealt %d damage." % entry.damage
			if entry.get("hit_count", 1) > 1:
				text += " Hit %d times!" % entry.hit_count
			if entry.get("effectiveness") == "super_effective":
				text += " [color=green]Super effective![/color]"
			elif entry.get("effectiveness") == "not_very_effective":
				text += " [color=yellow]Not very effective...[/color]"
			if entry.get("critical", false):
				text += " Critical hit!"
			if entry.has("recoil"):
				text += " %s took %d recoil!" % [actor_name, entry.recoil]
			if entry.has("drain_heal"):
				text += " Drained %d HP!" % entry.drain_heal
			if entry.has("status_applied"):
				text += " Inflicted %s!" % StatusEffects.get_status_display_name(entry.status_applied)
			if entry.has("heal"):
				text += " Healed %d HP!" % entry.heal
			if entry.has("stat_changes"):
				for stat in entry.stat_changes:
					var change = entry.stat_changes[stat]
					var direction = "rose" if change > 0 else "fell"
					var amount = "sharply " if abs(change) >= 2 else ""
					text += " %s %s%s!" % [stat.capitalize(), amount, direction]
			if entry.has("target_stat_changes"):
				for stat in entry.target_stat_changes:
					var change = entry.target_stat_changes[stat]
					var direction = "rose" if change > 0 else "fell"
					text += " Foe's %s %s!" % [stat.capitalize(), direction]
			if entry.has("weather_set"):
				var wname = WEATHER_NAMES.get(entry.weather_set, entry.weather_set)
				text += " %s started!" % wname
			if entry.has("hazard_set"):
				text += " Set %s!" % entry.hazard_set
			if entry.has("hazards_cleared"):
				text += " Cleared hazards!"
			if entry.has("defender_item_trigger"):
				var msg = entry.defender_item_trigger.get("message", "")
				if msg != "":
					text += " Foe " + msg
			if entry.has("attacker_item_trigger"):
				var msg = entry.attacker_item_trigger.get("message", "")
				if msg != "":
					text += " " + actor_name + " " + msg
			return text
		"status_damage":
			var actor_name = "Your creature" if entry.get("actor") == "player" else "Enemy"
			return "%s %s (%d damage)" % [actor_name, entry.get("message", ""), entry.get("damage", 0)]
		"ability_heal":
			var actor_name = "Your creature" if entry.get("actor") == "player" else "Enemy"
			return "%s %s (+%d HP)" % [actor_name, entry.get("message", ""), entry.get("heal", 0)]
		"item_heal":
			var actor_name = "Your creature" if entry.get("actor") == "player" else "Enemy"
			return "%s %s (+%d HP)" % [actor_name, entry.get("message", ""), entry.get("heal", 0)]
		"weather_cleared":
			var wname = WEATHER_NAMES.get(entry.get("weather", ""), "weather")
			return "The %s subsided." % wname
		"hazard_damage":
			var actor_name = "Your creature" if entry.get("actor") == "player" else "Enemy"
			return "%s was hurt by %s! (%d damage)" % [actor_name, entry.get("hazard", "hazards"), entry.get("damage", 0)]
		"hazard_effect":
			var actor_name = "Your creature" if entry.get("actor") == "player" else "Enemy"
			return "%s was affected by %s!" % [actor_name, entry.get("hazard", "hazards")]
		"trainer_switch":
			return "Trainer sent out the next creature!"
		"victory":
			var drops = entry.get("drops", {})
			var drop_text = ""
			for item_id in drops:
				var ingredient = DataRegistry.get_ingredient(item_id)
				var item_name = ingredient.display_name if ingredient else item_id
				drop_text += "%s x%d " % [item_name, drops[item_id]]
			if drop_text == "":
				return "[color=green]Victory![/color]"
			return "[color=green]Enemy defeated![/color] Got: %s" % drop_text
		"defeat":
			return "[color=red]All your creatures fainted![/color]"
		"fled":
			return "Got away safely!"
		"flee_failed":
			return "Couldn't escape!"
		"fainted":
			return "[color=red]Your creature fainted![/color] Switch to another!"
		"switch":
			return "Switched creature!"
	return ""

func _set_buttons_enabled(enabled: bool) -> void:
	for btn in move_buttons:
		btn.disabled = not enabled
	var mode = battle_mgr.client_battle_mode if battle_mgr else 0
	flee_button.disabled = not enabled
	flee_button.visible = (mode == 0) # Only show flee for wild
	switch_button.disabled = not enabled
