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
@export var terrain: Terrain = Terrain.NORMAL

@export var overlay_texture: Texture2D
@export_range(0.0, 1.0) var overlay_density := 0.2

@export var glow_radius := 0.0
@export var glow_color := Color.WHITE

## Liquids only (see Wading): how much of a body wading in it shows below the surface,
## 0 hidden (lava) to 1 clear.
@export_range(0.0, 1.0) var see_through := 0.45

func move_speed() -> float:
	return TERRAIN_SPEED[terrain]

const CATEGORY_NAMES := {"floor": Category.FLOOR, "wall": Category.WALL}
const SHAPE_NAMES := {"dual_grid": Shape.DUAL_GRID, "static": Shape.STATIC}
const TERRAIN_NAMES := {
	"normal": Terrain.NORMAL,
	"rough": Terrain.ROUGH,
	"difficult": Terrain.DIFFICULT,
	"severe": Terrain.SEVERE,
}

func load_from_data(data: Dictionary) -> void:
	tile_name = data.get("tile_name", "")
	atlas_texture = _load_atlas_texture(data)
	overlay_texture = _load_texture(data.get("overlay_texture", ""))
	sort_order = data.get("sort_order", 0)
	category = CATEGORY_NAMES.get(data.get("category", ""), Category.FLOOR)
	shape = SHAPE_NAMES.get(data.get("shape", ""), Shape.DUAL_GRID)
	terrain = TERRAIN_NAMES.get(data.get("terrain", ""), Terrain.NORMAL)
	marker_color = _color_from_array(data.get("marker_color", []), Color.WHITE)
	glow_color = _color_from_array(data.get("glow_color", []), Color.WHITE)
	var coords: Array = data.get("atlas_coords", [])
	atlas_coords = Vector2i(coords[0], coords[1]) if coords.size() == 2 else Vector2i.ZERO
	orientable = data.get("orientable", false)
	glow_radius = data.get("glow_radius", 0.0)
	overlay_density = data.get("overlay_density", 0.2)
	see_through = data.get("see_through", 0.45)

func load_from_file(path: String) -> void:
	load_from_data(JsonOnloading.load_dict(path))

func _load_texture(path: String) -> Texture2D:
	return load(path) if path != "" else null

# Lit tiles give a diffuse PNG and a normal-map PNG as two separate paths
# instead of pointing at a pre-made CanvasTexture .tres -- built here instead
# so the JSON stays plain data, not a reference to a hardcoded resource file.
func _load_atlas_texture(data: Dictionary) -> Texture2D:
	var diffuse_path: String = data.get("atlas_texture", "")
	if diffuse_path == "":
		return null
	var normal_path: String = data.get("normal_texture", "")
	if normal_path == "":
		return _load_texture(diffuse_path)
	var texture := CanvasTexture.new()
	texture.diffuse_texture = _load_texture(diffuse_path)
	texture.normal_texture = _load_texture(normal_path)
	texture.specular_color = _color_from_array(data.get("specular_color", []), Color.WHITE)
	return texture

func _color_from_array(arr: Array, fallback: Color) -> Color:
	return Color(arr[0], arr[1], arr[2], arr[3] if arr.size() > 3 else 1.0) if arr.size() >= 3 else fallback
