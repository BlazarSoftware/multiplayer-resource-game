@tool
extends Node
## Handles 2D post-processing and environment property manipulation.

signal postfx_ready(result: Dictionary)

# Shader templates for common 2D post-processing effects (full-screen shaders)
const POSTFX_TEMPLATES := {
	"vignette": """shader_type canvas_item;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.5;
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.8;
void fragment() {
	float dist = distance(SCREEN_UV, vec2(0.5));
	float vignette = smoothstep(vignette_radius, vignette_radius - 0.3, dist);
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);
	COLOR = vec4(screen.rgb * mix(1.0 - vignette_strength, 1.0, vignette), screen.a);
}""",
	"crt": """shader_type canvas_item;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float curvature : hint_range(0.0, 0.1) = 0.02;
uniform float aberration : hint_range(0.0, 0.01) = 0.003;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	uv += d * dot(d, d) * curvature;
	float r = texture(SCREEN_TEXTURE, uv + vec2(aberration, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(aberration, 0.0)).b;
	float scanline = sin(uv.y * 800.0) * 0.5 + 0.5;
	float mask = 1.0 - scanline_strength * scanline;
	COLOR = vec4(vec3(r, g, b) * mask, 1.0);
}""",
	"chromatic_aberration": """shader_type canvas_item;
uniform float offset : hint_range(0.0, 0.05) = 0.005;
uniform float angle : hint_range(0.0, 6.28) = 0.0;
void fragment() {
	vec2 dir = vec2(cos(angle), sin(angle)) * offset;
	float r = texture(SCREEN_TEXTURE, SCREEN_UV + dir).r;
	float g = texture(SCREEN_TEXTURE, SCREEN_UV).g;
	float b = texture(SCREEN_TEXTURE, SCREEN_UV - dir).b;
	COLOR = vec4(r, g, b, 1.0);
}""",
	"pixelate": """shader_type canvas_item;
uniform float pixel_size : hint_range(1.0, 64.0) = 4.0;
void fragment() {
	vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0));
	vec2 uv = floor(SCREEN_UV * screen_size / pixel_size) * pixel_size / screen_size;
	COLOR = texture(SCREEN_TEXTURE, uv);
}""",
}


func _safe_get_node(node_path: String) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if node_path == "/root":
		return tree.root
	return tree.root.get_node_or_null(node_path.trim_prefix("/root"))


func handle_postfx_2d_apply(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var tree := get_tree()
	if tree == null:
		return {"error": "No scene tree available"}

	var effect_name: String = params.get("effect_name", "PostFX")
	var template: String = params.get("template", "")
	var shader_code: String = params.get("shader_code", "")
	var shader_params: Dictionary = params.get("params", {})
	var layer: int = int(params.get("layer", 100))
	var parent_path: String = params.get("parent_path", "")

	if template.is_empty():
		return {"error": "template is required"}

	# Handle bloom template via WorldEnvironment glow
	if template == "bloom":
		var env_node := _find_world_environment(tree.root)
		if env_node == null:
			# Create a WorldEnvironment with Environment
			env_node = WorldEnvironment.new()
			env_node.name = "WorldEnvironment"
			var env := Environment.new()
			env_node.environment = env
			var scene_root = tree.current_scene if tree.current_scene else tree.root
			scene_root.add_child(env_node)
		var env := env_node.environment
		env.glow_enabled = true
		env.glow_intensity = float(shader_params.get("intensity", 1.0))
		env.glow_strength = float(shader_params.get("strength", 1.0))
		env.glow_bloom = float(shader_params.get("bloom", 0.5))
		return {
			"status": "ok",
			"effect_name": effect_name,
			"template": "bloom",
			"path": str(env_node.get_path()),
			"note": "Bloom applied via WorldEnvironment glow properties",
		}

	# Get shader code from template or custom
	var final_code: String = ""
	if template == "custom":
		if shader_code.is_empty():
			return {"error": "shader_code is required when template='custom'"}
		final_code = shader_code
	elif POSTFX_TEMPLATES.has(template):
		final_code = POSTFX_TEMPLATES[template]
	else:
		return {"error": "Unknown template: %s. Available: %s" % [template, ", ".join(POSTFX_TEMPLATES.keys())]}

	# Find parent
	var parent: Node = null
	if not parent_path.is_empty():
		parent = _safe_get_node(parent_path)
	if parent == null:
		parent = tree.current_scene if tree.current_scene else tree.root

	# Check if effect already exists and remove it
	var existing := parent.get_node_or_null(effect_name)
	if existing != null:
		existing.queue_free()
		# Wait a frame for cleanup
		await tree.process_frame

	# Create CanvasLayer
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = effect_name
	canvas_layer.layer = layer

	# Create full-screen ColorRect
	var color_rect := ColorRect.new()
	color_rect.name = "FullscreenRect"
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create shader + material
	var shader := Shader.new()
	shader.code = final_code

	var mat := ShaderMaterial.new()
	mat.shader = shader

	for key in shader_params:
		mat.set_shader_parameter(key, shader_params[key])

	color_rect.material = mat
	canvas_layer.add_child(color_rect)
	parent.add_child(canvas_layer)

	return {
		"status": "ok",
		"effect_name": effect_name,
		"template": template,
		"layer": layer,
		"path": str(canvas_layer.get_path()),
	}


func handle_postfx_2d_remove(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var effect_name: String = params.get("effect_name", "")
	var parent_path: String = params.get("parent_path", "")

	if effect_name.is_empty():
		return {"error": "effect_name is required"}

	var tree := get_tree()
	if tree == null:
		return {"error": "No scene tree available"}

	var parent: Node = null
	if not parent_path.is_empty():
		parent = _safe_get_node(parent_path)
	if parent == null:
		parent = tree.current_scene if tree.current_scene else tree.root

	var node := parent.get_node_or_null(effect_name)
	if node == null:
		return {"error": "PostFX layer not found: %s" % effect_name}

	var node_path := str(node.get_path())
	node.get_parent().remove_child(node)
	node.queue_free()

	return {"status": "ok", "removed": effect_name, "path": node_path}


func handle_set_environment_property(params) -> Dictionary:
	if not params is Dictionary:
		return {"error": "Invalid params"}

	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")
	var value = params.get("value", null)

	if property.is_empty():
		return {"error": "property is required"}

	var tree := get_tree()
	if tree == null:
		return {"error": "No scene tree available"}

	var env_node: WorldEnvironment = null

	if not node_path.is_empty():
		var node := _safe_get_node(node_path)
		if node is WorldEnvironment:
			env_node = node as WorldEnvironment
		else:
			return {"error": "Node is not a WorldEnvironment: %s" % node_path}
	else:
		# Auto-detect first WorldEnvironment
		env_node = _find_world_environment(tree.root)

	if env_node == null:
		return {"error": "No WorldEnvironment node found in scene"}

	if env_node.environment == null:
		return {"error": "WorldEnvironment has no Environment resource"}

	var env := env_node.environment
	if not env.has_method("set") or not property in _get_environment_properties():
		# Try setting anyway — Godot will handle invalid properties gracefully
		pass

	env.set(property, value)

	return {
		"status": "ok",
		"node": str(env_node.get_path()),
		"property": property,
		"value_type": typeof(value),
	}


func _find_world_environment(root: Node) -> WorldEnvironment:
	if root is WorldEnvironment:
		return root as WorldEnvironment
	for child in root.get_children():
		var result := _find_world_environment(child)
		if result != null:
			return result
	return null


func _get_environment_properties() -> Array[String]:
	return [
		"background_mode", "background_color", "background_energy_multiplier",
		"glow_enabled", "glow_intensity", "glow_strength", "glow_bloom",
		"fog_enabled", "fog_light_color", "fog_density",
		"tonemap_mode", "tonemap_exposure", "tonemap_white",
		"ssao_enabled", "ssao_radius", "ssao_intensity",
		"ssr_enabled", "ssr_max_steps", "ssr_fade_in",
		"ssil_enabled", "ssil_radius", "ssil_intensity",
		"sdfgi_enabled",
		"volumetric_fog_enabled", "volumetric_fog_density",
		"adjustment_enabled", "adjustment_brightness", "adjustment_contrast", "adjustment_saturation",
	]
