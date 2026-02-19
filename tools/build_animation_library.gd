extends SceneTree

const ANIM_CLIPS := [
	"idle",
	"walk_forward",
	"walk_backward",
	"jog_forward",
	"jog_backward",
	"run",
	"run_to_stop",
	"crouch_idle",
	"crouch_walk",
	"falling",
	"turn_left",
	"turn_right",
	"hoe_swing",
	"axe_chop",
	"watering",
	"harvest_pickup",
	"crafting_interact",
	"fishing_cast",
]

const LOOP_CLIPS := {
	"idle": true,
	"walk_forward": true,
	"walk_backward": true,
	"jog_forward": true,
	"jog_backward": true,
	"run": true,
	"crouch_idle": true,
	"crouch_walk": true,
	"falling": true,
	"turn_left": true,
	"turn_right": true,
}

func _initialize() -> void:
	var library = AnimationLibrary.new()

	for clip in ANIM_CLIPS:
		var path := "res://assets/animations/%s.glb" % clip
		var scene := load(path)
		if scene == null:
			push_error("Missing animation scene: %s" % path)
			continue

		var inst = scene.instantiate()
		var anim_player = inst.find_child("AnimationPlayer", true, false)
		if anim_player == null:
			push_error("AnimationPlayer not found in %s" % path)
			continue

		var anim_list = anim_player.get_animation_list()
		if anim_list.is_empty():
			push_error("No animations found in %s" % path)
			continue

		var anim = anim_player.get_animation(anim_list[0]).duplicate()
		anim.loop_mode = Animation.LOOP_LINEAR if LOOP_CLIPS.has(clip) else Animation.LOOP_NONE
		library.add_animation(clip, anim)

	var save_path := "res://assets/animations/player_animation_library.tres"
	var err := ResourceSaver.save(library, save_path)
	if err != OK:
		push_error("Failed to save AnimationLibrary: %s" % err)

	quit()
