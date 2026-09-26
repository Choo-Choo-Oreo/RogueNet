class_name GearLayers
extends Node

## Draws a player's worn gear. Each slot gets its own AnimatedSprite2D, added as
## a child of the body sprite so it moves, fades and hides with it. Nothing here
## plays an animation by itself: every frame each layer copies the body's
## animation, frame, flip and offset, so the gear walks (and lunges, breathes and
## topples, see DirectionalAnimator) exactly in step with the body.
## The z_index follows ItemDatabase.DRAW_ORDER for the way the body faces, which
## puts a cape or a shield behind the character when that's how it's drawn.
## Facing left, held items keep to their own hand instead of being mirrored
## with the body (ItemDatabase.held_left).
## A full set's bonus effects (GearEffects) hang off the body the same way.

## Set when the player dies: the ghost skin uses the same animation names as the
## body, so the gear would otherwise float on the ghost.
var hidden := false

## Whose copy of each piece to draw: "" the Human's, else a skin with a body of its own
## (ItemDatabase.sheet_path). A piece not drawn for that body yet isn't shown.
var body_id := ""

var _body: AnimatedSprite2D
var _layers: Dictionary = {}   # slot -> AnimatedSprite2D
var _sheet := ""   # the sheet the layers are set up for: a DRAW_ORDER or LEFT_SHEETS one
var _worn: Dictionary = {}   # slot -> item id
var _held_view: Dictionary = {}   # held slot -> [animation, mirrored], only while facing left
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
			layer.sprite_frames = ItemDatabase.sprite_frames(item_id, body_id)
			layer.visible = layer.sprite_frames != null and not hidden
	_worn = worn.duplicate()
	_effects.set_equipment(worn)
	_sheet = ""

## Draw the gear for another body (a character skin, see body_id).
func set_body(id: String) -> void:
	if id == body_id:
		return
	body_id = id
	set_equipment(_worn)

func _process(_delta: float) -> void:
	if _body == null or _body.sprite_frames == null:
		return
	var sheet: String = ItemDatabase.ANIMATION_SHEETS.get(_body.animation, "")
	if _body.flip_h and ItemDatabase.LEFT_SHEETS.has(sheet):
		sheet = ItemDatabase.LEFT_SHEETS[sheet]
	_effects.set_active(sheet != "" and not hidden)
	if sheet != "" and sheet != _sheet:
		_sheet = sheet
		_apply_draw_order(sheet)
		_pick_held_views(sheet)
	for slot in _layers:
		var layer: AnimatedSprite2D = _layers[slot]
		if layer.sprite_frames == null:
			continue
		# A body with no matching gear sheet shows no gear.
		layer.visible = sheet != "" and not hidden
		if not layer.visible:
			continue
		var view: Array = _held_view.get(slot, [_body.animation, _body.flip_h])
		if layer.animation != view[0]:
			layer.animation = view[0]
		layer.frame = _body.frame % ItemDatabase.FRAME_COUNT
		layer.flip_h = view[1]
		layer.offset = _body.offset

# z_index is relative to the body: negative is behind it, positive in front.
func _apply_draw_order(sheet: String) -> void:
	var order: Array = ItemDatabase.draw_order(sheet)
	var body_index := order.find("body")
	for slot in _layers:
		_layers[slot].z_index = order.find(slot) - body_index

# Facing left: which animation each held item plays, and mirrored or not (ItemDatabase.held_left).
func _pick_held_views(sheet: String) -> void:
	_held_view.clear()
	if not ItemDatabase.HELD_LEFT.has(sheet):
		return
	for slot in ItemDatabase.HELD_SLOTS:
		var item_id: String = _worn.get(slot, "")
		if item_id == "" or _layers[slot].sprite_frames == null:
			continue
		var view := ItemDatabase.held_left(item_id, sheet, body_id)
		var animation = "Left" if view[0] == "Left" else ItemDatabase.ANIMATION_SHEETS.find_key(view[0])
		_held_view[slot] = [animation, view[1]]
