extends RefCounted

# Menu palette (readability-first)
const PAPER_BASE: Color = Color("FFF8EF")
const PAPER_CARD: Color = Color("F6EBDD")
const PAPER_EDGE: Color = Color("E6D3BC")
const INK_PRIMARY: Color = Color("2B241E")
const INK_SECONDARY: Color = Color("55483B")
const INK_DISABLED: Color = Color("7A6A59")
const ACCENT_TOMATO: Color = Color("A6473F")
const ACCENT_BASIL: Color = Color("3F6A47")
const ACCENT_HONEY: Color = Color("9C6A1A")
const ACCENT_BERRY: Color = Color("7B4B60")
const ACCENT_OCEAN: Color = Color("3E5C7A")
const ACCENT_CHESTNUT: Color = Color("6C4B2F")
const SCRIM_MENU: Color = Color(0.13, 0.10, 0.08, 0.72)

# Sidebar / cookbook spine
const SIDEBAR_BG: Color = Color("3D2E22")
const SIDEBAR_TEXT: Color = Color("E8D5B8")
const SIDEBAR_ACTIVE_BG: Color = Color("5A422F")
const SIDEBAR_HOVER_BG: Color = Color("4D3828")

# Explicit button background tokens
const BUTTON_PRIMARY_BG: Color = Color("F6ECD7")
const BUTTON_PRIMARY_BORDER: Color = Color("B8862D")
const BUTTON_SECONDARY_BG: Color = PAPER_CARD
const BUTTON_SECONDARY_BORDER: Color = ACCENT_CHESTNUT
const BUTTON_DANGER_BG: Color = Color("F2DDD8")
const BUTTON_DANGER_BORDER: Color = ACCENT_TOMATO
const BUTTON_INFO_BG: Color = Color("DFE8F2")
const BUTTON_INFO_BORDER: Color = ACCENT_OCEAN

# Compatibility aliases for existing UI code.
const PAPER_CREAM: Color = PAPER_BASE
const PAPER_TAN: Color = PAPER_CARD
const PARCHMENT_DARK: Color = PAPER_EDGE
const INK_DARK: Color = INK_PRIMARY
const INK_MEDIUM: Color = INK_SECONDARY
const INK_LIGHT: Color = INK_DISABLED
const STAMP_RED: Color = ACCENT_TOMATO
const STAMP_GREEN: Color = ACCENT_BASIL
const STAMP_GOLD: Color = ACCENT_HONEY
const STAMP_BLUE: Color = ACCENT_OCEAN
const STAMP_BROWN: Color = ACCENT_CHESTNUT
const SCRIM: Color = SCRIM_MENU
const PAPER_BG: Color = PAPER_BASE
const TEXT_INK: Color = INK_PRIMARY

# Text semantics
const TEXT_SUCCESS: Color = ACCENT_BASIL
const TEXT_WARNING: Color = ACCENT_HONEY
const TEXT_DANGER: Color = ACCENT_TOMATO
const TEXT_INFO: Color = ACCENT_OCEAN
const TEXT_MUTED: Color = INK_DISABLED

# Type colors (battle + tags)
const TYPE_SPICY: Color = Color("A84A3C")
const TYPE_SWEET: Color = Color("B56A7A")
const TYPE_SOUR: Color = Color("6E7A2F")
const TYPE_HERBAL: Color = Color("4A6B3E")
const TYPE_UMAMI: Color = Color("6B4E38")
const TYPE_GRAIN: Color = Color("8C6A2D")
const TYPE_MINERAL: Color = Color("7A8B99")
const TYPE_EARTHY: Color = Color("8B6D4A")
const TYPE_LIQUID: Color = Color("4A7B9B")
const TYPE_AROMATIC: Color = Color("9B6B8A")
const TYPE_TOXIC: Color = Color("6B8A4A")
const TYPE_PROTEIN: Color = Color("8B4A4A")
const TYPE_TROPICAL: Color = Color("6B9B5A")
const TYPE_DAIRY: Color = Color("C8B89A")
const TYPE_BITTER: Color = Color("5A4A3A")
const TYPE_SPOILED: Color = Color("7A6B5A")
const TYPE_FERMENTED: Color = Color("8A7A4A")
const TYPE_SMOKED: Color = Color("6B5A4A")

const TYPE_COLORS := {
	"spicy": TYPE_SPICY,
	"sweet": TYPE_SWEET,
	"sour": TYPE_SOUR,
	"herbal": TYPE_HERBAL,
	"umami": TYPE_UMAMI,
	"grain": TYPE_GRAIN,
	"mineral": TYPE_MINERAL,
	"earthy": TYPE_EARTHY,
	"liquid": TYPE_LIQUID,
	"aromatic": TYPE_AROMATIC,
	"toxic": TYPE_TOXIC,
	"protein": TYPE_PROTEIN,
	"tropical": TYPE_TROPICAL,
	"dairy": TYPE_DAIRY,
	"bitter": TYPE_BITTER,
	"spoiled": TYPE_SPOILED,
	"fermented": TYPE_FERMENTED,
	"smoked": TYPE_SMOKED,
}

# Typography
const FONT_H1: int = 36
const FONT_H2: int = 30
const FONT_H3: int = 24
const FONT_BODY: int = 20
const FONT_SMALL: int = 18
const FONT_TINY: int = 16

# VFX & screen flash colors
const FLASH_GOLD: Color = Color(1.0, 0.9, 0.6, 0.4)
const FLASH_CRAFT: Color = Color(1.0, 0.95, 0.7, 0.35)
const SHIMMER_GOLD: Color = Color(1.2, 1.1, 0.8, 1.0)
const TRANSITION_EDGE: Color = Color(0.85, 0.75, 0.55, 1.0)

# Layout
const PANEL_MARGIN: int = 14
const CORNER_RADIUS: int = 8
const CORNER_RADIUS_SM: int = 6
const CORNER_RADIUS_LG: int = 12
const BORDER_WIDTH: int = 2
