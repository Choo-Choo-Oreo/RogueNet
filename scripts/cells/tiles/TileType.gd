extends Resource
class_name TileType

enum Category { FLOOR, WALL }
enum Shape { DUAL_GRID, STATIC }

@export var tile_name: String = ""
@export var atlas_texture: Texture2D
@export var sort_order: int = 0
@export var category: Category = Category.FLOOR
@export var marker_color: Color = Color.WHITE
@export var shape: Shape = Shape.DUAL_GRID
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var orientable: bool = false
