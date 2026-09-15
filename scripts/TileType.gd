extends Resource
class_name TileType

enum Category { FLOOR, WALL }

@export var tile_name: String = ""
@export var atlas_texture: Texture2D
@export var sort_order: int = 0
@export var category: Category = Category.FLOOR
@export var marker_color: Color = Color.WHITE
