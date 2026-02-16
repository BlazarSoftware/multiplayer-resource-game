class_name ShopDef
extends Resource

@export var shop_id: String = ""
@export var display_name: String = ""
@export var items_for_sale: Array[Dictionary] = [] # [{item_id: String, buy_price: int}]
