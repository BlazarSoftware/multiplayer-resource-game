extends RefCounted

# Fire-and-forget GPUParticles3D effects for battle animations.
# All methods are static — create particles, add to parent, auto-free after lifetime.

const TYPE_EFFECT_CONFIGS = {
	"spicy": { "color": Color(0.9, 0.3, 0.1), "color2": Color(1.0, 0.6, 0.1), "direction": Vector3(0, 1.5, 0), "spread": 25.0, "count": 30, "lifetime": 0.6 },
	"sweet": { "color": Color(1.0, 0.5, 0.7), "color2": Color(1.0, 0.8, 0.9), "direction": Vector3(0.5, 1.0, 0.5), "spread": 45.0, "count": 20, "lifetime": 0.5 },
	"sour": { "color": Color(0.5, 0.8, 0.2), "color2": Color(0.8, 0.9, 0.1), "direction": Vector3(0, -1.0, 0), "spread": 30.0, "count": 25, "lifetime": 0.5 },
	"herbal": { "color": Color(0.2, 0.7, 0.3), "color2": Color(0.5, 0.9, 0.4), "direction": Vector3(0.3, 0.8, 0.3), "spread": 40.0, "count": 20, "lifetime": 0.6 },
	"umami": { "color": Color(0.5, 0.3, 0.6), "color2": Color(0.4, 0.25, 0.35), "direction": Vector3(0, 0.5, 0), "spread": 20.0, "count": 15, "lifetime": 0.7 },
	"grain": { "color": Color(0.8, 0.65, 0.2), "color2": Color(0.6, 0.45, 0.15), "direction": Vector3(0, 1.0, 0), "spread": 35.0, "count": 25, "lifetime": 0.5 },
}

static func _spawn_particles(parent: Node3D, pos: Vector3, config: Dictionary) -> GPUParticles3D:
	var particles = GPUParticles3D.new()
	particles.position = pos - parent.global_position
	particles.emitting = true
	particles.one_shot = true
	particles.amount = config.get("count", 20)
	particles.lifetime = config.get("lifetime", 0.5)
	particles.explosiveness = config.get("explosiveness", 0.8)

	var mat = ParticleProcessMaterial.new()
	mat.direction = config.get("direction", Vector3(0, 1, 0))
	mat.spread = config.get("spread", 30.0)
	mat.initial_velocity_min = config.get("velocity_min", 2.0)
	mat.initial_velocity_max = config.get("velocity_max", 4.0)
	mat.gravity = config.get("gravity", Vector3(0, -2, 0))
	mat.scale_min = config.get("scale_min", 0.05)
	mat.scale_max = config.get("scale_max", 0.15)
	mat.color = config.get("color", Color.WHITE)

	# Color ramp for fade-out
	var gradient = Gradient.new()
	var c1 = config.get("color", Color.WHITE)
	var c2 = config.get("color2", c1)
	gradient.set_color(0, c1)
	gradient.add_point(0.5, c2)
	gradient.set_color(gradient.get_point_count() - 1, Color(c2.r, c2.g, c2.b, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	particles.process_material = mat

	# Simple sphere mesh for particles
	var draw_pass = SphereMesh.new()
	draw_pass.radius = 0.06
	draw_pass.height = 0.12
	var draw_mat = StandardMaterial3D.new()
	draw_mat.albedo_color = config.get("color", Color.WHITE)
	draw_mat.emission_enabled = true
	draw_mat.emission = config.get("color", Color.WHITE)
	draw_mat.emission_energy_multiplier = 2.0
	draw_pass.material = draw_mat
	particles.draw_pass_1 = draw_pass

	parent.add_child(particles)

	# Auto-free after lifetime + buffer
	var lifetime = config.get("lifetime", 0.5)
	var timer = parent.get_tree().create_timer(lifetime + 0.5)
	timer.timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

	return particles

static func spawn_move_effect(parent: Node3D, pos: Vector3, move_type: String) -> void:
	var config = TYPE_EFFECT_CONFIGS.get(move_type, TYPE_EFFECT_CONFIGS.get("grain", {}))
	if config.is_empty():
		return
	_spawn_particles(parent, pos, config)

static func spawn_stat_effect(parent: Node3D, pos: Vector3, is_boost: bool) -> void:
	var config = {
		"color": Color(0.2, 0.8, 0.3) if is_boost else Color(0.8, 0.2, 0.2),
		"color2": Color(0.4, 1.0, 0.5) if is_boost else Color(1.0, 0.3, 0.3),
		"direction": Vector3(0, 2.0, 0) if is_boost else Vector3(0, -1.5, 0),
		"spread": 10.0,
		"count": 5,
		"lifetime": 0.4,
		"velocity_min": 1.5,
		"velocity_max": 3.0,
		"gravity": Vector3(0, 0, 0) if is_boost else Vector3(0, -3, 0),
		"scale_min": 0.04,
		"scale_max": 0.1,
		"explosiveness": 0.9,
	}
	_spawn_particles(parent, pos, config)

static func spawn_status_effect(parent: Node3D, pos: Vector3, status: String) -> void:
	var status_colors = {
		"burned": Color(0.9, 0.4, 0.1),
		"frozen": Color(0.3, 0.7, 1.0),
		"poisoned": Color(0.6, 0.2, 0.8),
		"drowsy": Color(0.7, 0.6, 0.9),
		"wilted": Color(0.5, 0.6, 0.3),
		"soured": Color(0.8, 0.8, 0.2),
		"brined": Color(0.2, 0.8, 0.8),
	}
	var color = status_colors.get(status, Color(0.8, 0.8, 0.2))
	var config = {
		"color": color,
		"color2": color.lightened(0.3),
		"direction": Vector3(0, 0.2, 0),
		"spread": 180.0,
		"count": 12,
		"lifetime": 0.5,
		"velocity_min": 0.5,
		"velocity_max": 1.5,
		"gravity": Vector3(0, 0, 0),
		"scale_min": 0.03,
		"scale_max": 0.08,
		"explosiveness": 0.5,
	}
	_spawn_particles(parent, pos, config)

static func spawn_heal_effect(parent: Node3D, pos: Vector3) -> void:
	var config = {
		"color": Color(0.3, 0.9, 0.4),
		"color2": Color(0.8, 1.0, 0.8),
		"direction": Vector3(0, 2.0, 0),
		"spread": 25.0,
		"count": 15,
		"lifetime": 0.5,
		"velocity_min": 1.0,
		"velocity_max": 2.5,
		"gravity": Vector3(0, 0.5, 0),
		"scale_min": 0.03,
		"scale_max": 0.1,
		"explosiveness": 0.7,
	}
	_spawn_particles(parent, pos, config)

static func spawn_hit_effect(parent: Node3D, pos: Vector3, effectiveness: String) -> void:
	var color = Color.WHITE
	var count = 12
	var scale_max = 0.1
	match effectiveness:
		"super_effective":
			color = Color(0.3, 0.8, 0.3)
			count = 20
			scale_max = 0.15
		"not_very_effective":
			color = Color(0.8, 0.7, 0.2)
			count = 8
			scale_max = 0.06
	var config = {
		"color": color,
		"color2": color.lightened(0.4),
		"direction": Vector3(0, 0.5, 0),
		"spread": 180.0,
		"count": count,
		"lifetime": 0.3,
		"velocity_min": 2.0,
		"velocity_max": 5.0,
		"gravity": Vector3(0, -4, 0),
		"scale_min": 0.03,
		"scale_max": scale_max,
		"explosiveness": 1.0,
	}
	_spawn_particles(parent, pos, config)
