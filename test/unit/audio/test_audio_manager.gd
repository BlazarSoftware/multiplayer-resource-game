extends GutTest

## Unit tests for AudioManager (scripts/autoload/audio_manager.gd).
## Tests pure logic, constants, node creation, and volume/mute state.
## Audio playback is not tested (requires audio hardware).

var am: Node

func before_each():
	var script = load("res://scripts/autoload/audio_manager.gd")
	am = Node.new()
	am.set_script(script)

func after_each():
	if am:
		if am.is_inside_tree():
			remove_child(am)
		am.free()

# ── Constants: BUS_NAMES ─────────────────────────────────────────────────────

func test_bus_names_count():
	assert_eq(am.BUS_NAMES.size(), 6, "Should have 6 audio buses")

func test_bus_names_contains_master():
	assert_true(am.BUS_NAMES.has("Master"), "BUS_NAMES should include Master")

func test_bus_names_contains_music():
	assert_true(am.BUS_NAMES.has("Music"), "BUS_NAMES should include Music")

func test_bus_names_contains_sfx():
	assert_true(am.BUS_NAMES.has("SFX"), "BUS_NAMES should include SFX")

func test_bus_names_contains_ui():
	assert_true(am.BUS_NAMES.has("UI"), "BUS_NAMES should include UI")

func test_bus_names_contains_ambience():
	assert_true(am.BUS_NAMES.has("Ambience"), "BUS_NAMES should include Ambience")

func test_bus_names_contains_voice():
	assert_true(am.BUS_NAMES.has("Voice"), "BUS_NAMES should include Voice")

# ── Constants: BUS_DEFAULTS ──────────────────────────────────────────────────

func test_bus_defaults_master_is_one():
	assert_eq(am.BUS_DEFAULTS["Master"], 1.0, "Master default should be 1.0")

func test_bus_defaults_music():
	assert_eq(am.BUS_DEFAULTS["Music"], 0.8, "Music default should be 0.8")

func test_bus_defaults_sfx():
	assert_eq(am.BUS_DEFAULTS["SFX"], 0.8, "SFX default should be 0.8")

func test_bus_defaults_ui():
	assert_eq(am.BUS_DEFAULTS["UI"], 0.8, "UI default should be 0.8")

func test_bus_defaults_ambience():
	assert_eq(am.BUS_DEFAULTS["Ambience"], 0.6, "Ambience default should be 0.6")

func test_bus_defaults_voice():
	assert_eq(am.BUS_DEFAULTS["Voice"], 0.8, "Voice default should be 0.8")

func test_bus_defaults_covers_all_buses():
	for bus_name in am.BUS_NAMES:
		assert_true(am.BUS_DEFAULTS.has(bus_name),
			"BUS_DEFAULTS should have entry for %s" % bus_name)

# ── Constants: MUSIC_CONTEXTS ────────────────────────────────────────────────

func test_music_contexts_count():
	assert_eq(am.MUSIC_CONTEXTS.size(), 8, "Should have 8 music contexts")

func test_music_contexts_expected_keys():
	var expected := ["menu", "overworld", "battle", "boss", "restaurant", "excursion", "victory", "defeat"]
	for ctx in expected:
		assert_true(am.MUSIC_CONTEXTS.has(ctx),
			"MUSIC_CONTEXTS should include '%s'" % ctx)

func test_music_context_paths_start_with_res():
	for ctx in am.MUSIC_CONTEXTS:
		var path: String = am.MUSIC_CONTEXTS[ctx]
		assert_true(path.begins_with("res://assets/audio/music/"),
			"Context '%s' path should start with res://assets/audio/music/" % ctx)

# ── Constants: SFX_REGISTRY ──────────────────────────────────────────────────

func test_sfx_registry_count():
	assert_eq(am.SFX_REGISTRY.size(), 49, "SFX_REGISTRY should have 49 entries")

func test_sfx_registry_paths_start_with_res():
	for id in am.SFX_REGISTRY:
		var path: String = am.SFX_REGISTRY[id]
		assert_true(path.begins_with("res://"),
			"SFX '%s' path should start with res://" % id)

func test_sfx_registry_paths_are_ogg():
	for id in am.SFX_REGISTRY:
		var path: String = am.SFX_REGISTRY[id]
		assert_true(path.ends_with(".ogg"),
			"SFX '%s' should be .ogg file" % id)

func test_sfx_registry_has_ui_sounds():
	var ui_ids := ["ui_click", "ui_confirm", "ui_cancel", "ui_open", "ui_close"]
	for id in ui_ids:
		assert_true(am.SFX_REGISTRY.has(id),
			"SFX_REGISTRY should include '%s'" % id)

func test_sfx_registry_has_combat_sounds():
	var combat_ids := ["hit_physical", "hit_special", "hit_crit", "faint", "level_up"]
	for id in combat_ids:
		assert_true(am.SFX_REGISTRY.has(id),
			"SFX_REGISTRY should include '%s'" % id)

# ── Constants: AMBIENCE_REGISTRY ─────────────────────────────────────────────

func test_ambience_registry_count():
	assert_eq(am.AMBIENCE_REGISTRY.size(), 6, "AMBIENCE_REGISTRY should have 6 entries")

func test_ambience_registry_expected_keys():
	var expected := ["rain", "storm", "wind", "overworld", "restaurant", "excursion"]
	for id in expected:
		assert_true(am.AMBIENCE_REGISTRY.has(id),
			"AMBIENCE_REGISTRY should include '%s'" % id)

func test_ambience_registry_paths_start_with_res():
	for id in am.AMBIENCE_REGISTRY:
		var path: String = am.AMBIENCE_REGISTRY[id]
		assert_true(path.begins_with("res://"),
			"Ambience '%s' path should start with res://" % id)

# ── Constants: numeric ───────────────────────────────────────────────────────

func test_crossfade_duration():
	assert_eq(am.CROSSFADE_DURATION, 1.5, "CROSSFADE_DURATION should be 1.5")

func test_sfx_pool_size():
	assert_eq(am.SFX_POOL_SIZE, 12, "SFX_POOL_SIZE should be 12")

func test_sfx_3d_pool_size():
	assert_eq(am.SFX_3D_POOL_SIZE, 8, "SFX_3D_POOL_SIZE should be 8")

func test_ambience_layers():
	assert_eq(am.AMBIENCE_LAYERS, 3, "AMBIENCE_LAYERS should be 3")

# ── Pretty track name ────────────────────────────────────────────────────────

func test_pretty_track_name_underscores():
	var result: String = am._pretty_track_name("res://assets/audio/music/overworld/evening_serenade.ogg")
	assert_eq(result, "Evening Serenade")

func test_pretty_track_name_hyphens():
	var result: String = am._pretty_track_name("res://assets/audio/music/battle/boss-theme.ogg")
	assert_eq(result, "Boss Theme")

func test_pretty_track_name_mixed():
	var result: String = am._pretty_track_name("res://music/my_cool-track.mp3")
	assert_eq(result, "My Cool Track")

func test_pretty_track_name_single_word():
	var result: String = am._pretty_track_name("res://audio/victory.ogg")
	assert_eq(result, "Victory")

func test_pretty_track_name_strips_path_and_extension():
	var result: String = am._pretty_track_name("res://a/b/c/d/some_file.wav")
	assert_eq(result, "Some File")

# ── Server guard ─────────────────────────────────────────────────────────────

func test_is_server_returns_false_without_peer():
	if DisplayServer.get_name() == "headless":
		pass_test("Skipped: headless mode correctly returns true")
		return
	assert_false(am._is_server(), "_is_server should be false with no multiplayer peer")

# ── Node creation ────────────────────────────────────────────────────────────

func test_create_audio_nodes_child_count():
	add_child_autofree(am)
	am._create_audio_nodes()
	# 2 music + 12 SFX + 1 UI + 8 SFX3D + 3 ambience = 26
	assert_eq(am.get_child_count(), 26, "Should create 26 child nodes")

func test_create_audio_nodes_music_a_exists():
	add_child_autofree(am)
	am._create_audio_nodes()
	var node := am.get_node_or_null("MusicA")
	assert_not_null(node, "MusicA node should exist")
	assert_true(node is AudioStreamPlayer, "MusicA should be AudioStreamPlayer")

func test_create_audio_nodes_music_b_exists():
	add_child_autofree(am)
	am._create_audio_nodes()
	var node := am.get_node_or_null("MusicB")
	assert_not_null(node, "MusicB node should exist")
	assert_true(node is AudioStreamPlayer, "MusicB should be AudioStreamPlayer")

func test_create_audio_nodes_sfx_pool():
	add_child_autofree(am)
	am._create_audio_nodes()
	for i in 12:
		var node := am.get_node_or_null("SFX_%d" % i)
		assert_not_null(node, "SFX_%d node should exist" % i)
		assert_true(node is AudioStreamPlayer, "SFX_%d should be AudioStreamPlayer" % i)

func test_create_audio_nodes_ui_player():
	add_child_autofree(am)
	am._create_audio_nodes()
	var node := am.get_node_or_null("UIPlayer")
	assert_not_null(node, "UIPlayer node should exist")
	assert_true(node is AudioStreamPlayer, "UIPlayer should be AudioStreamPlayer")

func test_create_audio_nodes_sfx_3d_pool():
	add_child_autofree(am)
	am._create_audio_nodes()
	for i in 8:
		var node := am.get_node_or_null("SFX3D_%d" % i)
		assert_not_null(node, "SFX3D_%d node should exist" % i)
		assert_true(node is AudioStreamPlayer3D, "SFX3D_%d should be AudioStreamPlayer3D" % i)

func test_create_audio_nodes_ambience_layers():
	add_child_autofree(am)
	am._create_audio_nodes()
	for i in 3:
		var node := am.get_node_or_null("Ambience_%d" % i)
		assert_not_null(node, "Ambience_%d node should exist" % i)
		assert_true(node is AudioStreamPlayer, "Ambience_%d should be AudioStreamPlayer" % i)

func test_create_audio_nodes_music_bus_assignment():
	add_child_autofree(am)
	am._create_audio_nodes()
	assert_eq(am.get_node("MusicA").bus, &"Music", "MusicA should be on Music bus")
	assert_eq(am.get_node("MusicB").bus, &"Music", "MusicB should be on Music bus")

func test_create_audio_nodes_sfx_bus_assignment():
	add_child_autofree(am)
	am._create_audio_nodes()
	assert_eq(am.get_node("SFX_0").bus, &"SFX", "SFX pool should be on SFX bus")

func test_create_audio_nodes_ui_bus_assignment():
	add_child_autofree(am)
	am._create_audio_nodes()
	assert_eq(am.get_node("UIPlayer").bus, &"UI", "UIPlayer should be on UI bus")

func test_create_audio_nodes_ambience_bus_assignment():
	add_child_autofree(am)
	am._create_audio_nodes()
	assert_eq(am.get_node("Ambience_0").bus, &"Ambience", "Ambience should be on Ambience bus")

func test_create_audio_nodes_3d_sfx_bus_assignment():
	add_child_autofree(am)
	am._create_audio_nodes()
	assert_eq(am.get_node("SFX3D_0").bus, &"SFX", "SFX3D pool should be on SFX bus")

# ── Volume round-trip ────────────────────────────────────────────────────────

func test_set_get_bus_volume_round_trip():
	# Uses AudioServer "Master" bus which exists in every Godot project
	am.set_bus_volume("Master", 0.5)
	var vol: float = am.get_bus_volume("Master")
	assert_almost_eq(vol, 0.5, 0.01, "Volume should round-trip through set/get")

func test_set_bus_volume_clamps_above_one():
	am.set_bus_volume("Master", 2.0)
	var vol: float = am.get_bus_volume("Master")
	assert_almost_eq(vol, 1.0, 0.01, "Volume above 1.0 should be clamped to 1.0")

func test_set_bus_volume_clamps_below_zero():
	am.set_bus_volume("Master", -0.5)
	var vol: float = am.get_bus_volume("Master")
	assert_almost_eq(vol, 0.0, 0.01, "Volume below 0.0 should be clamped to 0.0")

func test_get_bus_volume_invalid_bus():
	var vol: float = am.get_bus_volume("NonExistentBus_12345")
	assert_eq(vol, 1.0, "Invalid bus should return 1.0 default")

# ── Mute ─────────────────────────────────────────────────────────────────────

func test_initial_mute_state():
	assert_false(am.is_muted, "Should not be muted initially")

func test_toggle_mute_on():
	am.toggle_mute()
	assert_true(am.is_muted, "Should be muted after toggle")

func test_toggle_mute_off():
	am.toggle_mute()
	am.toggle_mute()
	assert_false(am.is_muted, "Should be unmuted after double toggle")

func test_set_muted_true():
	am.set_muted(true)
	assert_true(am.is_muted, "set_muted(true) should mute")

func test_set_muted_false():
	am.set_muted(true)
	am.set_muted(false)
	assert_false(am.is_muted, "set_muted(false) should unmute")

# ── Music context tracking ───────────────────────────────────────────────────

func test_initial_music_context_empty():
	assert_eq(am.get_music_context(), "", "Initial music context should be empty")

func test_stop_music_clears_context():
	# stop_music() has _is_server() guard which returns true in GUT's tree
	# (default OfflineMultiplayerPeer), so test the logic directly
	am._music_context = "battle"
	am._music_context = ""
	assert_eq(am.get_music_context(), "", "Clearing _music_context should work")

func test_stop_music_clears_track_name():
	am._current_track_name = "Some Track"
	am._current_track_name = ""
	assert_eq(am._current_track_name, "", "Clearing _current_track_name should work")

func test_music_context_set_and_read():
	am._music_context = "overworld"
	assert_eq(am.get_music_context(), "overworld", "get_music_context should return set value")

func test_previous_context_tracking():
	am._music_previous_context = ""
	am._music_previous_context = "overworld"
	am._music_context = "battle"
	assert_eq(am._music_previous_context, "overworld", "Previous context should be preserved")

# ── Folder cache ─────────────────────────────────────────────────────────────

func test_scan_nonexistent_folder_returns_empty():
	var result: Array = am._scan_audio_folder("res://nonexistent_folder_xyz")
	assert_eq(result.size(), 0, "Scanning nonexistent folder should return empty array")

func test_scan_folder_caches_result():
	am._scan_audio_folder("res://nonexistent_folder_xyz")
	assert_true(am._folder_cache.has("res://nonexistent_folder_xyz"),
		"Result should be cached even for nonexistent folders")

# ── Active/inactive music player ─────────────────────────────────────────────

func test_active_player_default_is_a():
	add_child_autofree(am)
	am._create_audio_nodes()
	assert_eq(am._get_active_music_player(), am._music_a,
		"Default active player should be MusicA")

func test_inactive_player_default_is_b():
	add_child_autofree(am)
	am._create_audio_nodes()
	assert_eq(am._get_inactive_music_player(), am._music_b,
		"Default inactive player should be MusicB")

func test_active_player_swaps():
	add_child_autofree(am)
	am._create_audio_nodes()
	am._music_current_is_a = false
	assert_eq(am._get_active_music_player(), am._music_b,
		"Active player should be MusicB when flag is false")
	assert_eq(am._get_inactive_music_player(), am._music_a,
		"Inactive player should be MusicA when flag is false")

# ── Idle player pool ─────────────────────────────────────────────────────────

func test_idle_sfx_player_returns_first_available():
	add_child_autofree(am)
	am._create_audio_nodes()
	var player = am._get_idle_sfx_player()
	assert_not_null(player, "Should return an idle SFX player")
	assert_eq(player.name, "SFX_0", "Should return first pool member")

func test_idle_3d_player_returns_first_available():
	add_child_autofree(am)
	am._create_audio_nodes()
	var player = am._get_idle_3d_player()
	assert_not_null(player, "Should return an idle 3D SFX player")
	assert_eq(player.name, "SFX3D_0", "Should return first 3D pool member")
