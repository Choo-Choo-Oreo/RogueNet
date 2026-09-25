class_name GearLayers
extends Node

## Draws a player's worn gear. Each slot gets its own AnimatedSprite2D, added as
## a child of the body sprite so it moves, fades and hides with it. Nothing here
## plays an animation by itself: every frame each layer copies the body's
## animation, frame and flip, so the gear walks exactly in step with the body.
## The z_index follows ItemDatabase.DRAW_ORDER for the way the body faces, which
## puts a cape or a shield behind the character when that's how it's drawn.
## A full set's bonus effects (GearEffects) hang off the body the same way.

## Set when the player dies: the ghost skin uses the same animation names as the
## body, so the gear would otherwise float on the ghost.
var hidden := false

var _body: AnimatedSprite2D
var _layers: Dictionary = {}   # slot -> AnimatedSprite2D
var _sheet := ""
var _effects := GearEffects.new()

func setup(body: AnimatedSprite2D) -> void:
	_body = body
	for slot in ItemDatabase.SLOTS:
		var layer := AnimatedSprite2D.new()
		layer.name = "Gear_" + slot
		layer.visible = false
		_body.add_child(layer)
		_layers[slot] = layer
	_effects.name = "GearEffects"
	_body.add_child(_effects)

## worn: slot -> item id. Slots not in it are shown empty.
func set_equipment(worn: Dictionary) -> void:
	for slot in _layers:
		var layer: AnimatedSprite2D = _layers[slot]
		var item_id: String = worn.get(slot, "")
		# Items without "art" (rings) aren't drawn on the body; GearEffects still shows their bonus.
		if item_id == "" or ItemDatabase.get_item(item_id).get("art", "") == "":
			layer.sprite_frames = null
			layer.visible = false
		else:
			layer.sprite_frames = ItemDatabase.sprite_frames(item_id)
			layer.visible = not hidden
	_effects.set_equipment(worn)
	_sheet = ""

func _process(_delta: float) -> void:
	if _body == null or _body.sprite_frames == null:
		return
	var sheet: String = ItemDatabase.ANIMATION_SHEETS.get(_body.animation, "")
	_effects.set_active(sheet != "" and not hidden)
	for slot in _layers:
		var layer: AnimatedSprite2D = _layers[slot]
		if layer.sprite_frames == null:
			continue
		# A body with no matching gear sheet shows no gear.
		layer.visible = sheet != "" and not hidden
		if not layer.visible:
			continue
		if layer.animation != _body.animation:
			layer.animation = _body.animation
		layer.frame = _body.frame % ItemDatabase.FRAME_COUNT
		layer.flip_h = _body.flip_h
	if sheet != "" and sheet != _sheet:
		_sheet = sheet
		_apply_draw_order(sheet)

# z_index is relative to the body: negative is behind it, positive in front.
func _apply_draw_order(sheet: String) -> void:
	var order: Array = ItemDatabase.DRAW_ORDER[sheet]
	var body_index := order.find("body")
	for slot in _layers:
		_layers[slot].z_index = order.find(slot) - body_index
