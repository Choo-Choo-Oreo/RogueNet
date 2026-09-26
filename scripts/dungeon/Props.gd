class_name Props
extends Node2D

## Props: the dungeon's clutter (barrels, crates...), placed in rooms with the Dungeon Maker's
## object tool and drawn here. A prop is a PNG in DIR, and its id is the file name in lower
## case (Barrel.png is "barrel"): adding a file is all it takes, it shows up in the Dungeon
## Maker's object list and in the game. Nothing is stored per prop.
##
## Cosmetic only, the same on every peer (drawn from the room data like the floor): nothing
## bumps into a prop, hides behind one or breaks one. Whether they should is a gameplay call.
## Room objects of other types (torch, chest, sign) are not props and are not drawn yet.
##
## A room object is {"type", "position": {x, y} (the picture's middle, in pixels from the
## room's top-left corner), "rotation" (degrees)}. Rooms the assembler turns take their
## objects with them (DungeonAssembler.rotate_room); the picture itself stays upright.

const DIR := "res://resources/gfx/objects/props/"
## Room object positions are pixels of this tile (DungeonMaker.TILE_SIZE).
const TILE := 16
## Over the floor and wall tiles (sort_order 100), under creatures (1000), like a door.
const Z := 101

static var _textures := {}

## id -> res:// path of every prop picture.
static func textures() -> Dictionary:
	if _textures.is_empty():
		for file_name in DirAccess.get_files_at(DIR):
			var png := file_name.trim_suffix(".import")   # an exported build lists only the .import files
			if png.ends_with(".png"):
				_textures[png.get_basename().to_lower()] = DIR + png
	return _textures

static func is_prop(type: String) -> bool:
	return textures().has(type)

## Draws the props of every placed room.
func build(rooms: Dictionary, placements: Array) -> void:
	for p in placements:
		for obj in rooms[p.room_id].get("objects", []):
			var type := str(obj.get("type", ""))
			if not is_prop(type):
				continue
			var sprite := Sprite2D.new()
			sprite.texture = load(textures()[type])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.z_index = Z
			var at: Dictionary = obj.get("position", {})
			sprite.position = Vector2(p.offset * TILE) + Vector2(float(at.get("x", 0)), float(at.get("y", 0)))
			sprite.rotation_degrees = float(obj.get("rotation", 0.0))
			add_child(sprite)

## Room objects after one clockwise quarter turn of a room `height` tiles tall.
static func rotate_objects(objects: Array, height: int) -> Array:
	var rotated: Array = []
	for obj in objects:
		var turned: Dictionary = (obj as Dictionary).duplicate(true)
		var at: Dictionary = obj.get("position", {})
		turned["position"] = {"x": height * TILE - float(at.get("y", 0)), "y": float(at.get("x", 0))}
		rotated.append(turned)
	return rotated
