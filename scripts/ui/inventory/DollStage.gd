class_name DollStage
extends Control

## The inventory's character preview: your chosen character (NetworkSync.peer_characters)
## wearing the current gear, standing on a
## rug in a candlelit stone alcove (resources/gfx/ui/storage/Stage.png).
## - Drag sideways, scroll, or press the brass arrows to turn them (8 ways).
## - Drop a piece of gear on them to put it on (PlayerInventory.equip_from).
## - Putting something on makes them hop and take a few steps, with a puff of sparks in
##   the item's rarity colour.
## The candle glow flickers and dust drifts in the light. InventoryPanel owns one and calls
## refresh() whenever the inventory changes.

const STAGE := "res://resources/gfx/ui/storage/Stage.png"
const ARROW := "res://resources/gfx/ui/storage/Arrow.png"
## Screen pixels per art pixel: the alcove, and the Human in it.
const STAGE_PX := 4
const DOLL_SCALE := 10
## Where the feet stand, in the alcove's art pixels (the middle of the rug).
const FEET := Vector2(26, 51)
## The candle flames in the alcove, in its art pixels.
const CANDLES: Array[Vector2] = [Vector2(11, 28), Vector2(40, 28)]
## Screen pixels of sideways drag per turn.
const DRAG_STEP := 28.0
const WALK_FPS := 8.0
const STRUT_SECONDS := 0.75

## The 8 ways the preview can face: which drawn sheet, mirrored or not.
const FACINGS := [
	["Down", false], ["DownRight", false], ["Right", false], ["UpRight", false],
	["Up", false], ["UpRight", true], ["Right", true], ["DownRight", true],
]

var _facing := 0
var _doll := Control.new()
var _body_sheets: Dictionary = {}   # DRAW_ORDER sheet -> the character's texture for it
var _character := ""
## The skin whose own copy of the gear is drawn ("" = the Human's; see GearLayers.body_id).
var _body_id := ""
var _glows: Array[TextureRect] = []
var _sparks := CPUParticles2D.new()
var _time := 0.0
var _strut_left := 0.0
var _frame := 0
var _worn_key := ""
var _drag_from := -1.0

func _init() -> void:
	var art := Parchment.pixel_texture(STAGE, STAGE_PX)
	custom_minimum_size = art.get_size()
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	tooltip_text = "Drag or scroll to turn around.\nDrop gear here to put it on."

	add_child(_ignore(_rect(art)))
	# warm light pooled on the floor, and a halo round each candle; all flicker in _process
	_glows.append(_glow(Vector2(FEET.x, FEET.y - 8) * STAGE_PX, Vector2(200, 150), Color(1.0, 0.62, 0.3, 0.22)))
	for candle in CANDLES:
		_glows.append(_glow(candle * STAGE_PX, Vector2(56, 56), Color(1.0, 0.72, 0.36, 0.35)))
	add_child(_dust())

	var side := ItemDatabase.FRAME_SIZE * DOLL_SCALE
	_doll.size = Vector2(side, side)
	_doll.position = (FEET * STAGE_PX - Vector2(side / 2.0, side)).round()
	_doll.pivot_offset = Vector2(side / 2.0, side)
	_ignore(_doll)
	add_child(_doll)

	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 18
	_sparks.lifetime = 0.8
	_sparks.explosiveness = 0.9
	_sparks.position = _doll.position + Vector2(side / 2.0, side * 0.55)
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.emission_rect_extents = Vector2(side * 0.22, side * 0.3)
	_sparks.direction = Vector2.UP
	_sparks.spread = 50.0
	_sparks.gravity = Vector2(0, 60)
	_sparks.initial_velocity_min = 40.0
	_sparks.initial_velocity_max = 90.0
	_sparks.scale_amount_min = 3.0
	_sparks.scale_amount_max = 4.0
	add_child(_sparks)

	for step in [-1, 1]:
		var arrow := TextureButton.new()
		arrow.texture_normal = Parchment.pixel_texture(ARROW, 3)
		arrow.flip_h = step > 0
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.tooltip_text = "Turn"
		arrow.size = arrow.texture_normal.get_size()
		arrow.position = Vector2(4 if step < 0 else custom_minimum_size.x - arrow.size.x - 4, custom_minimum_size.y - arrow.size.y - 14)
		arrow.pressed.connect(turn.bind(step))
		arrow.mouse_entered.connect(func(): arrow.modulate = Color(1.3, 1.3, 1.3))
		arrow.mouse_exited.connect(func(): arrow.modulate = Color.WHITE)
		add_child(arrow)

func turn(step: int) -> void:
	_facing = posmod(_facing + step, FACINGS.size())
	_draw_doll()

func refresh() -> void:
	var key := var_to_str(PlayerInventory.equipped)
	if _worn_key != "" and key != _worn_key:
		_celebrate(_newly_worn(str_to_var(_worn_key)))
	_worn_key = key
	_draw_doll()

# The item that just went on, if anything did (not when something only came off).
func _newly_worn(before: Dictionary) -> String:
	for slot in PlayerInventory.equipped:
		var id: String = PlayerInventory.equipped[slot]
		if id != "" and before.get(slot, "") != id:
			return id
	return ""

func _celebrate(item_id: String) -> void:
	if item_id == "":
		return
	_strut_left = STRUT_SECONDS
	var hop := create_tween()
	hop.tween_property(_doll, "scale", Vector2(1.06, 0.94), 0.06)
	hop.tween_property(_doll, "scale", Vector2(0.96, 1.05), 0.08)
	hop.tween_property(_doll, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var color: Color = ItemSlot.RARITY_COLORS[ItemDatabase.rarity(item_id)]
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	_sparks.color_ramp = fade
	_sparks.amount = 12 + 6 * ItemDatabase.rarity_rank(item_id)
	_sparks.restart()

func _notification(what: int) -> void:
	# the character may have been changed in town while the panel was shut
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_draw_doll()

# Loads the body sheets of the character this machine's player picked, when it changes.
func _update_character() -> void:
	var character_id: String = NetworkSync.peer_characters.get(multiplayer.get_unique_id(), PlayerController.DEFAULT_CHARACTER)
	if character_id == _character:
		return
	_character = character_id
	var data := PlayerController.character_data(character_id)
	_body_id = "" if data.get("fits_gear", true) else character_id
	var animations: Dictionary = data["sprite_frames"]["animations"]
	for animation in ItemDatabase.ANIMATION_SHEETS:
		_body_sheets[ItemDatabase.ANIMATION_SHEETS[animation]] = load(animations[animation]["texture"])

# The same layering the game uses (ItemDatabase.DRAW_ORDER); one frame of each sheet.
func _draw_doll() -> void:
	_update_character()
	for child in _doll.get_children():
		child.queue_free()
	var sheet: String = FACINGS[_facing][0]
	var mirrored: bool = FACINGS[_facing][1]
	var facing: String = ItemDatabase.LEFT_SHEETS[sheet] if mirrored else sheet
	for slot in ItemDatabase.draw_order(facing):
		var texture: Texture2D
		var flip := mirrored
		if slot == "body":
			texture = _body_sheets[sheet]
		else:
			var item_id: String = PlayerInventory.equipped.get(slot, "")
			if item_id == "":
				continue
			var item_sheet := sheet
			# facing left, held items keep to their own hand (ItemDatabase.held_left)
			if mirrored and slot in ItemDatabase.HELD_SLOTS:
				var view := ItemDatabase.held_left(item_id, facing, _body_id)
				item_sheet = view[0]
				flip = view[1]
			var path := ItemDatabase.sheet_path(item_id, item_sheet, _body_id)
			# a skin with its own body only wears the pieces drawn for it so far
			texture = load(path) if ResourceLoader.exists(path) else null
		if texture == null:
			continue
		# gear drawn without step frames has fewer frames than the body
		var frames := maxi(1, texture.get_width() / ItemDatabase.FRAME_SIZE)
		var layer := _rect(ItemDatabase.frame_texture(texture, _frame % frames))
		layer.size = _doll.size
		layer.flip_h = flip
		_doll.add_child(_ignore(layer))

func _process(delta: float) -> void:
	_time += delta
	# candlelight: two slow waves and a quick one, so it never repeats visibly
	for i in _glows.size():
		var t := _time + i * 1.7
		_glows[i].modulate.a = 0.8 + 0.12 * sin(t * 2.3) + 0.08 * sin(t * 5.9 + 1.1) + 0.05 * sin(t * 13.0)
	var frame := 0
	if _strut_left > 0.0:
		_strut_left -= delta
		frame = int(_time * WALK_FPS) % 4 if _strut_left > 0.0 else 0
	if frame != _frame:
		_frame = frame
		_draw_doll()

# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			turn(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag_from = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = -1.0
	elif event is InputEventMouseMotion and _drag_from >= 0.0 and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var moved: float = event.position.x - _drag_from
		if absf(moved) >= DRAG_STEP:
			turn(1 if moved > 0 else -1)
			_drag_from = event.position.x

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("inventory_from")):
		return false
	var from: Dictionary = data["inventory_from"]
	return from["where"] != PlayerInventory.EQUIP and ItemDatabase.item_slot(PlayerInventory.get_at(from)) != ""

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var item := PlayerInventory.get_at(data["inventory_from"])
	if PlayerInventory.equip_from(data["inventory_from"]):
		ItemSounds.play_item(self, item)

# ---------------------------------------------------------------- building

func _glow(center: Vector2, glow_size: Vector2, color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = int(glow_size.x)
	texture.height = int(glow_size.y)
	var rect := _rect(texture)
	rect.size = glow_size
	rect.position = center - glow_size / 2.0
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rect.material = add
	add_child(_ignore(rect))
	return rect

# Specks of dust drifting up through the candlelight.
func _dust() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.amount = 10
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.position = Vector2(FEET.x * STAGE_PX, 34 * STAGE_PX)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(16, 12) * STAGE_PX
	dust.direction = Vector2.UP
	dust.spread = 40.0
	dust.gravity = Vector2(0, -1.5)
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 6.0
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 2.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	fade.colors = PackedColorArray([Color(1, 0.85, 0.6, 0.0), Color(1, 0.85, 0.6, 0.5), Color(1, 0.85, 0.6, 0.0)])
	dust.color_ramp = fade
	return dust

static func _rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size = texture.get_size()
	return rect

static func _ignore(control: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control
