extends RefCounted
class_name UITheme

const UITokens = preload("res://scripts/ui/ui_tokens.gd")

const HEADING_FONT_PATH := "res://assets/fonts/lilita_one_regular.ttf"
const BODY_FONT_PATH := "res://assets/fonts/fredoka_one_regular.ttf"
const BODY_BOLD_FONT_PATH := "res://assets/fonts/fredoka_one_regular.ttf"

static var _initialized := false
static var _heading_font: FontFile = null
static var _body_font: FontFile = null
static var _body_bold_font: FontFile = null

static var _font_scale: float = 1.0
static var _text_speed_cps: float = 40.0  # chars/sec, -1 = instant

static func scaled(size: int) -> int:
	return int(size * _font_scale)

static func scaled_vec(size: Vector2) -> Vector2:
	return Vector2(
		size.x * _font_scale if size.x > 0 else 0,
		size.y * _font_scale if size.y > 0 else 0
	)

static func set_font_scale(scale: float) -> void:
	_font_scale = scale

static func set_text_speed(cps: float) -> void:
	_text_speed_cps = cps

static func get_text_speed() -> float:
	return _text_speed_cps

static func init() -> void:
	if _initialized:
		return
	_heading_font = load(HEADING_FONT_PATH) as FontFile
	_body_font = load(BODY_FONT_PATH) as FontFile
	_body_bold_font = load(BODY_BOLD_FONT_PATH) as FontFile
	_load_settings()
	_initialized = true

static func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		_font_scale = config.get_value("accessibility", "font_scale", 1.0)
		_text_speed_cps = config.get_value("accessibility", "text_speed_cps", 40.0)

# Semantic text styles
static func style_title(label: Label, text: String = "") -> void:
	_style_label(label, text, _heading_font, UITokens.FONT_H1, UITokens.INK_PRIMARY)

static func style_section(label: Label, text: String = "") -> void:
	_style_label(label, text, _heading_font, UITokens.FONT_H2, UITokens.INK_PRIMARY)

static func style_body_text(label: Label, text: String = "") -> void:
	_style_label(label, text, _body_font, UITokens.FONT_BODY, UITokens.INK_PRIMARY)

static func style_caption(label: Label, text: String = "") -> void:
	_style_label(label, text, _body_font, UITokens.FONT_SMALL, UITokens.INK_SECONDARY)

static func style_emphasis(label: Label, text: String = "") -> void:
	_style_label(label, text, _body_bold_font, UITokens.FONT_BODY, UITokens.ACCENT_HONEY)

# Compatibility wrappers
static func style_heading(label: Label, text: String = "") -> void:
	style_title(label, text)

static func style_subheading(label: Label, text: String = "") -> void:
	style_section(label, text)

static func style_body(label: Label) -> void:
	style_body_text(label)

static func style_small(label: Label) -> void:
	style_caption(label)

static func style_toast(label: Label) -> void:
	style_emphasis(label)
	if label == null:
		return
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))

static func style_richtext_defaults(rich: RichTextLabel) -> void:
	init()
	if rich == null:
		return
	if _body_font:
		rich.add_theme_font_override("normal_font", _body_font)
	rich.add_theme_font_size_override("normal_font_size", scaled(UITokens.FONT_BODY))
	rich.add_theme_color_override("default_color", UITokens.INK_PRIMARY)
	rich.add_theme_constant_override("line_separation", 4)

# Panel and control styles
static func make_panel_style(
	bg_color: Color = UITokens.PAPER_CARD,
	border_color: Color = UITokens.STAMP_BROWN,
	radius: int = UITokens.CORNER_RADIUS,
	border_width: int = UITokens.BORDER_WIDTH
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_width)
	style.content_margin_left = UITokens.PANEL_MARGIN
	style.content_margin_top = UITokens.PANEL_MARGIN
	style.content_margin_right = UITokens.PANEL_MARGIN
	style.content_margin_bottom = UITokens.PANEL_MARGIN
	return style

static func make_panel_texture(_texture_path: String = "") -> StyleBox:
	return make_panel_style()

static func style_card(panel: Control) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", make_panel_style(UITokens.PAPER_CARD, UITokens.ACCENT_CHESTNUT))

static func style_modal(panel: Control) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", make_panel_style(UITokens.PAPER_BASE, UITokens.ACCENT_CHESTNUT, UITokens.CORNER_RADIUS_LG))

static func style_input(input: LineEdit) -> void:
	init()
	if input == null:
		return
	if _body_font:
		input.add_theme_font_override("font", _body_font)
	input.add_theme_font_size_override("font_size", scaled(UITokens.FONT_BODY))
	input.add_theme_color_override("font_color", UITokens.INK_PRIMARY)
	input.add_theme_color_override("font_placeholder_color", UITokens.INK_DISABLED)
	input.add_theme_stylebox_override("normal", make_panel_style(UITokens.PAPER_BASE, UITokens.STAMP_BROWN, UITokens.CORNER_RADIUS, 2))
	input.add_theme_stylebox_override("focus", make_panel_style(UITokens.PAPER_BASE, UITokens.ACCENT_HONEY, UITokens.CORNER_RADIUS, 3))

static func style_button(button: Button, variant: String = "primary") -> void:
	init()
	if button == null:
		return
	if _body_bold_font:
		button.add_theme_font_override("font", _body_bold_font)
	button.add_theme_font_size_override("font_size", scaled(UITokens.FONT_BODY))
	button.add_theme_color_override("font_color", UITokens.INK_PRIMARY)
	button.add_theme_color_override("font_hover_color", UITokens.INK_PRIMARY)
	button.add_theme_color_override("font_pressed_color", UITokens.INK_PRIMARY)
	button.add_theme_color_override("font_disabled_color", UITokens.INK_DISABLED)

	var normal_bg := UITokens.PAPER_BASE
	var hover_bg := UITokens.PAPER_BASE.lightened(0.03)
	var pressed_bg := UITokens.PAPER_BASE.darkened(0.04)
	var border_color := UITokens.STAMP_BROWN

	match variant:
		"danger":
			normal_bg = Color("F2DDD8")
			hover_bg = Color("F6E6E2")
			pressed_bg = Color("E7CBC5")
			border_color = UITokens.STAMP_RED
		"secondary":
			normal_bg = UITokens.PAPER_CARD
			hover_bg = UITokens.PAPER_CARD.lightened(0.04)
			pressed_bg = UITokens.PAPER_CARD.darkened(0.04)
			border_color = UITokens.STAMP_BROWN
		"info":
			normal_bg = Color("DFE8F2")
			hover_bg = Color("E9EFF6")
			pressed_bg = Color("D1DDEA")
			border_color = UITokens.STAMP_BLUE
		_:
			normal_bg = Color("F6ECD7")
			hover_bg = Color("FBF3E0")
			pressed_bg = Color("EBDDCA")
			border_color = UITokens.ACCENT_HONEY

	var r := UITokens.CORNER_RADIUS
	button.add_theme_stylebox_override("normal", _make_button_style(normal_bg, border_color, r, 2))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_bg, border_color, r, 2))
	button.add_theme_stylebox_override("pressed", _make_button_style(pressed_bg, border_color, r, 2))
	button.add_theme_stylebox_override("focus", _make_button_style(hover_bg, UITokens.ACCENT_HONEY, r, 3))
	button.add_theme_stylebox_override("disabled", _make_button_style(UITokens.PAPER_EDGE, UITokens.INK_DISABLED, r, 2))

static func apply_panel(panel: Control) -> void:
	style_card(panel)

# Sidebar helpers (dark walnut cookbook spine)
static func make_sidebar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UITokens.SIDEBAR_BG
	style.set_corner_radius_all(0)
	style.border_width_right = 2
	style.border_color = UITokens.ACCENT_CHESTNUT
	style.content_margin_left = 8
	style.content_margin_top = 10
	style.content_margin_right = 8
	style.content_margin_bottom = 10
	return style

static func style_sidebar_button(button: Button, is_active: bool = false) -> void:
	init()
	if button == null:
		return
	if _body_bold_font:
		button.add_theme_font_override("font", _body_bold_font)
	button.add_theme_font_size_override("font_size", scaled(UITokens.FONT_SMALL))
	button.add_theme_color_override("font_color", UITokens.SIDEBAR_TEXT)
	button.add_theme_color_override("font_hover_color", UITokens.PAPER_BASE)
	var bg = UITokens.SIDEBAR_ACTIVE_BG if is_active else Color(0, 0, 0, 0)
	var hover = UITokens.SIDEBAR_HOVER_BG
	button.add_theme_stylebox_override("normal", _make_button_style(bg, Color(0, 0, 0, 0), 4, 0))
	button.add_theme_stylebox_override("hover", _make_button_style(hover, Color(0, 0, 0, 0), 4, 0))
	button.add_theme_stylebox_override("pressed", _make_button_style(UITokens.SIDEBAR_ACTIVE_BG, UITokens.ACCENT_HONEY, 4, 1))
	button.add_theme_stylebox_override("focus", _make_button_style(hover, Color(0, 0, 0, 0), 4, 0))

static func style_badge(label: Label, tone: String = "info") -> void:
	style_caption(label)
	if label == null:
		return
	match tone:
		"success":
			label.add_theme_color_override("font_color", UITokens.TEXT_SUCCESS)
		"danger":
			label.add_theme_color_override("font_color", UITokens.TEXT_DANGER)
		"warning":
			label.add_theme_color_override("font_color", UITokens.TEXT_WARNING)
		_:
			label.add_theme_color_override("font_color", UITokens.TEXT_INFO)

static func bbcode_color(tag: String) -> String:
	var color := UITokens.INK_PRIMARY
	match tag:
		"success": color = UITokens.TEXT_SUCCESS
		"warning": color = UITokens.TEXT_WARNING
		"danger": color = UITokens.TEXT_DANGER
		"info": color = UITokens.TEXT_INFO
		"muted": color = UITokens.TEXT_MUTED
		"accent": color = UITokens.STAMP_GOLD
		"sweet": color = UITokens.TYPE_SWEET
		"spicy": color = UITokens.TYPE_SPICY
		"sour": color = UITokens.TYPE_SOUR
		"herbal": color = UITokens.TYPE_HERBAL
		"umami": color = UITokens.TYPE_UMAMI
		"grain": color = UITokens.TYPE_GRAIN
	return color.to_html(false)

static func style_label3d(label: Label3D, text: String = "", role: String = "") -> void:
	init()
	if label == null:
		return
	if text != "":
		label.text = text

	var role_cfg := _get_label3d_role(role)
	var use_heading_font: bool = role_cfg.get("heading_font", false)
	var chosen_font: FontFile = _heading_font if use_heading_font else _body_font
	if chosen_font:
		label.font = chosen_font
	label.font_size = scaled(int(role_cfg.get("size", UITokens.FONT_H2)))
	label.modulate = role_cfg.get("color", UITokens.PAPER_BASE)
	label.outline_size = int(role_cfg.get("outline", 6))
	label.outline_modulate = role_cfg.get("outline_color", Color(0, 0, 0, 0.85))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

static func _get_label3d_role(role: String) -> Dictionary:
	match role:
		"station":
			return {"size": 48, "color": UITokens.STAMP_GOLD, "outline": 8, "outline_color": Color(0.15, 0.10, 0.08, 0.85), "heading_font": true}
		"landmark":
			return {"size": 72, "color": UITokens.STAMP_GOLD, "outline": 12, "outline_color": Color(0.15, 0.10, 0.08, 0.9), "heading_font": true}
		"npc_name":
			return {"size": 24, "color": UITokens.INK_DARK, "outline": 4, "outline_color": Color(0.96, 0.93, 0.86, 0.95), "heading_font": true}
		"quest_marker":
			return {"size": 48, "color": UITokens.STAMP_GOLD, "outline": 6, "outline_color": Color(0.15, 0.10, 0.08, 0.9), "heading_font": true}
		"interaction_hint":
			return {"size": 24, "color": UITokens.INK_LIGHT, "outline": 4, "outline_color": Color(0.1, 0.08, 0.06, 0.85), "heading_font": false}
		"zone_sign":
			return {"size": 36, "color": UITokens.PAPER_TAN, "outline": 8, "outline_color": Color(0.15, 0.10, 0.08, 0.88), "heading_font": true}
		"world_item":
			return {"size": 32, "color": UITokens.PAPER_CREAM, "outline": 6, "outline_color": Color(0.12, 0.09, 0.07, 0.9), "heading_font": false}
		"danger":
			return {"size": 28, "color": UITokens.STAMP_RED, "outline": 6, "outline_color": Color(0.16, 0.10, 0.08, 0.9), "heading_font": true}
		_:
			return {"size": 24, "color": UITokens.PAPER_BASE, "outline": 6, "outline_color": Color(0.12, 0.09, 0.07, 0.85), "heading_font": false}

static func _style_label(label: Label, text: String, font: FontFile, size: int, color: Color) -> void:
	init()
	if label == null:
		return
	if text != "":
		label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", scaled(size))
	label.add_theme_color_override("font_color", color)

static func _make_button_style(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.set_border_width_all(width)
	style.content_margin_left = UITokens.PANEL_MARGIN
	style.content_margin_top = 8
	style.content_margin_right = UITokens.PANEL_MARGIN
	style.content_margin_bottom = 8
	return style
