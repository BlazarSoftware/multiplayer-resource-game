class_name RecipeScrollDef
extends Resource

@export var scroll_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var unlocks_recipe_id: String = ""
@export var icon_color: Color = Color(0.9, 0.8, 0.3)
@export var icon_texture: Texture2D
@export var fragment_count: int = 0 # 0 = no fragments needed, >0 = requires N fragments to assemble
