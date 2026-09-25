class_name SpriteFramesLoader
extends RefCounted

## Builds a SpriteFrames resource at runtime from JSON data (see any entity's
## "sprite_frames" key, e.g. game/entities/entities.antagonist/rat.json) instead
## of a hand-built .tres -- same reasoning as TileType's atlas_texture
## loading. Each animation is one PNG strip, frames cut left to right.

static func build(data: Dictionary) -> SpriteFrames:
	var frame_size := vector_from_array(data.get("frame_size", [16, 16]))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name: String in data.get("animations", {}).keys():
		var anim: Dictionary = data["animations"][anim_name]
		var texture: Texture2D = load(anim["texture"])
		var frame_count: int = anim.get("frame_count", 1)
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, anim.get("loop", true))
		frames.set_animation_speed(anim_name, anim.get("speed", 20.0))
		for i in range(frame_count):
			var region := Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			frames.add_frame(anim_name, atlas)
	return frames

static func vector_from_array(values: Array) -> Vector2:
	return Vector2(values[0], values[1])
