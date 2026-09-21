extends Resource
class_name TileType

enum Category { FLOOR, WALL }
enum Shape { DUAL_GRID, STATIC }
enum Terrain { NORMAL, ROUGH, DIFFICULT, SEVERE }

const TERRAIN_SPEED := {
	Terrain.NORMAL: 1.0,
	Terrain.ROUGH: 0.8,
	Terrain.DIFFICULT: 0.5,
	Terrain.SEVERE: 0.2,
}

@export var tile_name: String = ""
@export var atlas_texture: Texture2D
@export var sort_order: int = 0
@export var category: Category = Category.FLOOR
@export var marker_color: Color = Color.WHITE
@export var shape: Shape = Shape.DUAL_GRID
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var orientable: bool = false
@export var casts_shadow: bool = false
@export var terrain: Terrain = Terrain.NORMAL

func move_speed() -> float:
	return TERRAIN_SPEED[terrain]
