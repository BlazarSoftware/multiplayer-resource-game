class_name WorldItemModels
## Maps item_id -> 3D model info for world item drops.
## Lazy-loads PackedScenes with an LRU cache (max 30 entries).
## Falls back to the gift box model for unmapped items.

const FOOD_BASE := "res://assets/food_models/"
const TREASURE_BASE := "res://assets/treasure_models/"
const FALLBACK_SCENE := "res://scenes/world/world_item.tscn"

# {scene_path, scale, y_offset}
const MODEL_MAP: Dictionary = {
	# --- Ingredients ---
	"tomato": {"path": "vegetables/Tomato_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"carrot": {"path": "vegetables/Carrot_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"potato": {"path": "vegetables/Potato_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"onion": {"path": "vegetables/Onion_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"mushroom": {"path": "mushrooms/Bell_Mushroom_01.glb", "base": "food", "scale": 3.0, "y_offset": 0.0},
	"cheese": {"path": "cheese/Cheddar_Cheese.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"egg": {"path": "fruits/Lemon_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"honey": {"path": "jars/Honey_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"fish": {"path": "fish/Salmon_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"fruit": {"path": "fruits/Apple_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"herb_basil": {"path": "vegetables/Spring_Onion_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"herb_leaf": {"path": "vegetables/Spring_Onion_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"rice": {"path": "vegetables/Corn_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"milk": {"path": "drinks/Carton_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"butter": {"path": "cheese/Yellow_Cheese_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"flour": {"path": "bread/Loaf_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"sugar": {"path": "candy/Round_Candy_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"spice_pepper": {"path": "vegetables/Chili_Pepper_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"chili_powder": {"path": "vegetables/Chili_Pepper_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"chili_pepper": {"path": "vegetables/Chili_Pepper_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"seaweed": {"path": "vegetables/Cabbage_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"chocolate": {"path": "dessert/Macaron_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"citrus": {"path": "fruits/Orange_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"lemon": {"path": "fruits/Lemon_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"soy_sauce": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"broth": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"vinegar": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"pickle_brine": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"mint": {"path": "vegetables/Spring_Onion_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"starfruit": {"path": "fruits/Carambola_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"wheat": {"path": "vegetables/Corn_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"salt": {"path": "candy/Round_Candy_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"berry": {"path": "fruits/Grapes_Dark_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"pumpkin": {"path": "vegetables/Pumpkin.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"wood": {"path": "vegetables/Corn_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"stone": {"path": "vegetables/Potato_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	# Fish species
	"bass": {"path": "fish/Bluegill.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"salmon": {"path": "fish/Salmon_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"trout": {"path": "fish/Salmon_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"catfish": {"path": "fish/Halibut_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"tuna": {"path": "fish/Halibut_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"sardine": {"path": "fish/Bluegill.glb", "base": "food", "scale": 1.8, "y_offset": 0.0},
	"eel": {"path": "meat/Sausage_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"ice_fish": {"path": "fish/Salmon_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"golden_koi": {"path": "fish/Salmon_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},

	# --- Foods (crafted) ---
	"rice_ball_deluxe": {"path": "cheese/White_Cheese_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"grain_bread": {"path": "bread/Loaf_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"sweet_cake": {"path": "dessert/Cake_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"fruit_salad": {"path": "fruits/Apple_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"herb_salad": {"path": "vegetables/Broccoli.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"tomato_soup": {"path": "jars/Jam_Round_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"sushi": {"path": "fish/Salmon_Meat_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"pasta_dish": {"path": "bread/Pretzel.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"grilled_fish": {"path": "fish/Salmon_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"mushroom_risotto": {"path": "mushrooms/Shiitake.glb", "base": "food", "scale": 3.0, "y_offset": 0.0},
	"cheese_fondue": {"path": "cheese/Hole_Cheese_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"spicy_curry": {"path": "jars/Jam_Round_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"honey_toast": {"path": "bread/Baguette.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"veggie_stir_fry": {"path": "vegetables/Bell_Pepper_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"fish_stew": {"path": "jars/Jam_Hex_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"sashimi_platter": {"path": "fish/Salmon_Meat_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"chocolate_truffle": {"path": "dessert/Macaron_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"citrus_sorbet": {"path": "fruits/Lemon_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"mint_tea": {"path": "drinks/Can_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"pumpkin_pie": {"path": "dessert/Cake_Slice_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"umami_stew": {"path": "jars/Jam_Round_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"chili_oil": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"sour_punch_juice": {"path": "drinks/Can_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"egg_fried_rice": {"path": "jars/Jam_Round_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"burger": {"path": "bread/Bread_Round_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"pizza": {"path": "dessert/Cake_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"rainbow_creature": {"path": "candy/Lollipop_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
	"excursion_berry": {"path": "fruits/Grapes_Dark_01.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},

	# --- Excursion-exclusive items ---
	"golden_seed": {"path": "gems/Topaz_01.glb", "base": "treasure", "scale": 2.0, "y_offset": 0.0},
	"mystic_herb": {"path": "gems/Emerald_01.glb", "base": "treasure", "scale": 2.0, "y_offset": 0.0},
	"truffle_shaving": {"path": "gems/Ruby_01.glb", "base": "treasure", "scale": 2.0, "y_offset": 0.0},
	"ancient_grain_seed": {"path": "gems/Sapphire_01.glb", "base": "treasure", "scale": 2.0, "y_offset": 0.0},
	"wild_honey": {"path": "jars/Honey_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},

	# --- Battle items ---
	"herb_poultice": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"spicy_tonic": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"mint_extract": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"revival_soup": {"path": "jars/Jam_Round_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"flavor_essence": {"path": "drinks/Bottle_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},
	"full_feast": {"path": "dessert/Cake_01.glb", "base": "food", "scale": 2.0, "y_offset": 0.0},

	# --- Treasure (dig spots / special) ---
	"__dig_chest__": {"path": "chests/Basic_Chest_Full.glb", "base": "treasure", "scale": 1.5, "y_offset": -0.15},
	"__gold_chest__": {"path": "chests/Gold_Chest_Full.glb", "base": "treasure", "scale": 1.5, "y_offset": -0.15},
}

# Category-level fallbacks for item_id prefixes
const CATEGORY_FALLBACKS: Dictionary = {
	"recipe_scroll": {"path": "scrolls/Sealed_Scroll_01.glb", "base": "treasure", "scale": 2.5, "y_offset": 0.0},
	"scroll_": {"path": "scrolls/Sealed_Scroll_01.glb", "base": "treasure", "scale": 2.5, "y_offset": 0.0},
	"fragment_": {"path": "scrolls/Basic_Scroll_01.glb", "base": "treasure", "scale": 2.5, "y_offset": 0.0},
	"seed_": {"path": "vegetables/Radish.glb", "base": "food", "scale": 2.5, "y_offset": 0.0},
}

# Lazy-loaded PackedScene cache (LRU, max 30)
static var _cache: Dictionary = {} # path -> PackedScene
static var _cache_order: Array[String] = []
const MAX_CACHE := 30

static func get_model_info(item_id: String) -> Dictionary:
	# Direct match
	if item_id in MODEL_MAP:
		return MODEL_MAP[item_id]
	# Category prefix fallback
	for prefix in CATEGORY_FALLBACKS:
		if item_id.begins_with(prefix):
			return CATEGORY_FALLBACKS[prefix]
	# No match
	return {}

static func _resolve_path(info: Dictionary) -> String:
	var base_path: String = FOOD_BASE if info.get("base", "food") == "food" else TREASURE_BASE
	return base_path + str(info.get("path", ""))

static func load_model_scene(item_id: String) -> PackedScene:
	# Server headless guard
	if DisplayServer.get_name() == "headless":
		return null
	var info := get_model_info(item_id)
	if info.is_empty():
		return null
	var full_path := _resolve_path(info)
	# Check cache
	if full_path in _cache:
		# Move to front of LRU
		_cache_order.erase(full_path)
		_cache_order.push_front(full_path)
		return _cache[full_path]
	# Load
	if not ResourceLoader.exists(full_path):
		return null
	var scene := load(full_path) as PackedScene
	if not scene:
		return null
	# Cache with LRU eviction
	_cache[full_path] = scene
	_cache_order.push_front(full_path)
	while _cache_order.size() > MAX_CACHE:
		var evict: String = _cache_order.pop_back()
		_cache.erase(evict)
	return scene

static func get_scale(item_id: String) -> float:
	var info := get_model_info(item_id)
	return float(info.get("scale", 1.0))

static func get_y_offset(item_id: String) -> float:
	var info := get_model_info(item_id)
	return float(info.get("y_offset", 0.0))
