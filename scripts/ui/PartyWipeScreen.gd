class_name PartyWipeScreen
extends Control

## Shown once every adventurer in the party is dead, in place of the dungeon: a
## moonlit graveyard with one headstone per adventurer, their name and what killed
## them engraved on it. The stones match the dungeon's biome. Hovering a stone lifts
## it; clicking it opens that adventurer's history (RunLog).
##
## There is no timer. Every player presses End (NetworkSync.vote_end), which lights
## a candle on their grave for everyone, and when the whole party has pressed, the
## host sends it back to town. A player who leaves counts as having pressed.
##
## Each peer decides on its own that the party is dead, from the health it sees;
## player damage reaches every peer (NetworkSync.relay_player_hit), so they agree.
##
## Art: resources/gfx/ui/party_wipe/ -- Graveyard.png (320x180), Headstone<Biome>.png
## (56x56, the engraving always on FACE), Candle.png (unlit, lit, lit: 7x13 each).

const ART := "res://resources/gfx/ui/party_wipe/"
## Screen pixels per art pixel.
const PX := 4
const STONE_SIZE := 56
## Where the engraving goes on every headstone, in art pixels.
const FACE := Rect2i(12, 19, 29, 26)
const CANDLE_SIZE := Vector2i(7, 13)
## The candle's spot, in art pixels from the headstone's top-left.
const CANDLE_AT := Vector2i(0, 36)
const FALLBACK_BIOME := "Dungeon"
## Seconds between the last death and the graves, so the death itself is seen.
const DELAY := 1.5
const TEXT := Color("#e9e4d6")
const TEXT_DIM := Color("#b9b3a4")
const SHADOW := Color("#07070d")

var _opened := false
var _voted := false
var _graves: Dictionary = {}          # peer id -> Grave
var _end_button: MenuScrollButton
var _ready_line: Label
var _history: Control

func _ready() -> void:
	hide()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	NetworkSync.end_votes_changed.connect(_show_votes)

func _process(_delta: float) -> void:
	if not _opened and _all_players_dead():
		_opened = true
		await get_tree().create_timer(DELAY).timeout
		_open()

func _all_players_dead() -> bool:
	var players := get_tree().get_nodes_in_group("protagonist")
	if players.is_empty():
		return false
	for player in players:
		if player.stats.current_health > 0:
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if _history != null and event.is_action_pressed("ui_cancel"):
		_close_history()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- building it

func _open() -> void:
	# The HUD has nothing left to say. The chat stays, so the party can talk.
	for sibling in get_parent().get_children():
		if sibling != self and sibling is CanvasItem and sibling.name != "ChatBox":
			sibling.hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()

	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var stage := Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.modulate.a = 0.0
	add_child(stage)

	var backdrop := TextureRect.new()
	backdrop.texture = load(ART + "Graveyard.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(backdrop)

	var peers := _party()
	var heading := VBoxContainer.new()
	heading.set_anchors_preset(Control.PRESET_TOP_WIDE)
	heading.offset_top = 52
	heading.add_theme_constant_override("separation", 8)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(_text("YOU HAVE FALLEN" if peers.size() == 1 else "THE PARTY HAS FALLEN", 52, TEXT, 10))
	heading.add_child(_text(_subtitle(peers), 20, TEXT_DIM, 6))
	stage.add_child(heading)

	var middle := VBoxContainer.new()
	middle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	middle.offset_top = 212
	middle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 10)
	_end_button = MenuScrollButton.new()
	_end_button.text = "End"
	_end_button.tooltip_text = "Everyone presses End to go back to town"
	_end_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_button.pressed.connect(_press_end)
	middle.add_child(_end_button)
	_ready_line = _text("", 18, TEXT_DIM, 6)
	middle.add_child(_ready_line)
	stage.add_child(middle)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -(STONE_SIZE * PX + 56)
	row.offset_bottom = -28
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28 if peers.size() > 3 else 48)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(row)
	var stone := _stone_texture()
	for peer_id in peers:
		var grave := Grave.new(peer_id, _name_of(peer_id), cause_of_death(RunLog.of(peer_id)), stone, peer_id == _local_id())
		grave.opened.connect(_open_history.bind(peer_id))
		row.add_child(grave)
		_graves[peer_id] = grave
	_show_votes()

	# Fade to black, then the graveyard fades up and the stones rise one by one.
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.6)
	tween.tween_property(stage, "modulate:a", 1.0, 1.2)
	_end_button.unroll(1.8)
	for i in peers.size():
		_graves[peers[i]].rise(1.0 + i * 0.18)

## Everyone in the dungeon, you first, then by peer id.
func _party() -> Array:
	var peers: Array = []
	for player in get_tree().get_nodes_in_group("protagonist"):
		peers.append(int(str(player.name)))
	peers.sort()
	var me := _local_id()
	if peers.has(me):
		peers.erase(me)
		peers.push_front(me)
	return peers

func _local_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1

func _name_of(peer_id: int) -> String:
	return NetworkSync.peer_names.get(peer_id, "Adventurer")

func _biome() -> String:
	var biome := NetworkSync.dungeon_biome.capitalize()
	return biome if ResourceLoader.exists(ART + "Headstone%s.png" % biome) else FALLBACK_BIOME

func _stone_texture() -> Texture2D:
	return load(ART + "Headstone%s.png" % _biome())

func _subtitle(peers: Array) -> String:
	var longest := 0
	for peer_id in peers:
		longest = maxi(longest, RunLog.seconds_alive(peer_id))
	return "%s  ·  the dive lasted %s" % [_biome(), RunLog.duration_text(longest)]

## "Slain by a Rat", "Slain by the Minotaur" (bosses are one of a kind).
static func cause_of_death(record: Dictionary) -> String:
	var killer: String = record["hit_by"]
	if killer == "":
		return "Lost in the dark"
	var killer_name := MinionIndex.display_name(killer)
	var article := "the" if MinionIndex.is_boss(killer) else ("an" if "AEIOU".contains(killer_name.left(1)) else "a")
	return "Slain by %s %s" % [article, killer_name]

## "Bite, 5 piercing damage"
static func killing_blow(record: Dictionary) -> String:
	var cause: String = record["hit_cause"]
	var type: String = record["hit_type"]
	return "%s, %d %sdamage" % [cause.capitalize() if cause != "" else "A blow", record["hit_amount"], (type + " ") if type != "" else ""]

func _text(words: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", SHADOW)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_y", outline / 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

# ---------------------------------------------------------------- End

func _press_end() -> void:
	if _voted:
		return
	_voted = true
	ItemSounds.play(self, ItemSounds.SORT)
	NetworkSync.vote_end()
	_end_button.disabled = true
	_end_button.burn()
	_show_votes()

func _show_votes() -> void:
	if _ready_line == null:
		return
	var votes := NetworkSync.end_votes
	var ready := 0
	for peer_id in _graves:
		var voted: bool = votes.has(peer_id) or (peer_id == _local_id() and _voted)
		_graves[peer_id].set_voted(voted)
		if voted:
			ready += 1
	var total := _graves.size()
	if total <= 1:
		_ready_line.text = "Returning to town..." if _voted else ""
	elif _voted:
		_ready_line.text = "%d / %d ready  ·  waiting for the others" % [ready, total]
	else:
		_ready_line.text = "%d / %d ready" % [ready, total]

# ---------------------------------------------------------------- the history page

func _open_history(peer_id: int) -> void:
	_close_history()
	for id in _graves:
		_graves[id].selected = id == peer_id
	var record := RunLog.of(peer_id)
	_history = Control.new()
	_history.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_history)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_history())
	_history.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history.add_child(center)
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", Parchment.page_style(20))
	page.custom_minimum_size.x = 600
	center.add_child(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	page.add_child(column)

	# who
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	var portrait := PanelContainer.new()
	portrait.add_theme_stylebox_override("panel", Parchment.paper_box(Parchment.PAPER_LIGHT, Parchment.OUTLINE))
	var body := _picture(SpriteFramesLoader.first_frame(
			JsonOnloading.load_dict(PlayerController.CHARACTERS[PlayerController.DEFAULT_CHARACTER])["sprite_frames"]), 64)
	portrait.add_child(body)
	top.add_child(portrait)
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_child(Parchment.ink_label(_name_of(peer_id), 30))
	var species := Parchment.ink_label("Human adventurer", 16)
	species.modulate.a = 0.75
	who.add_child(species)
	top.add_child(who)
	var close := Button.new()
	close.text = "X"
	close.tooltip_text = "Close (Esc)"
	Parchment.button_look(close)
	close.custom_minimum_size = Vector2(40, 40)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(_close_history)
	top.add_child(close)
	column.add_child(top)

	# numbers
	var kills := 0
	for n in record["kills"].values():
		kills += n
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for stat in [["Lived", RunLog.duration_text(RunLog.seconds_alive(peer_id))], ["Rooms explored", record["rooms"].size()],
			["Kills", kills], ["Damage dealt", record["dealt"]], ["Damage taken", record["taken"]], ["Biggest hit", record["biggest"]]]:
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_stylebox_override("panel", Parchment.paper_box(Parchment.PAPER_LIGHT, Parchment.PAPER_DARK))
		var pair := VBoxContainer.new()
		pair.add_theme_constant_override("separation", 0)
		var label := Parchment.ink_label(stat[0], 13)
		label.modulate.a = 0.7
		pair.add_child(label)
		pair.add_child(Parchment.ink_label(str(stat[1]), 24))
		box.add_child(pair)
		grid.add_child(box)
	column.add_child(grid)

	# what they killed
	var slain_title := Parchment.ink_label("Creatures slain", 13)
	slain_title.modulate.a = 0.7
	column.add_child(slain_title)
	var slain := HFlowContainer.new()
	slain.add_theme_constant_override("h_separation", 18)
	slain.add_theme_constant_override("v_separation", 6)
	var kinds: Array = record["kills"].keys()
	kinds.sort_custom(func(a, b): return record["kills"][a] > record["kills"][b])
	for kind in kinds:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 6)
		entry.add_child(_picture(MinionIndex.icon(kind), 32))
		entry.add_child(Parchment.ink_label("%s ×%d" % [MinionIndex.display_name(kind), record["kills"][kind]], 18))
		slain.add_child(entry)
	if kinds.is_empty():
		slain.add_child(Parchment.ink_label("None", 18))
	column.add_child(slain)

	# what killed them
	var blow := PanelContainer.new()
	blow.add_theme_stylebox_override("panel", Parchment.paper_box(Color("#d9a489"), Parchment.OUTLINE))
	var blow_row := HBoxContainer.new()
	blow_row.add_theme_constant_override("separation", 14)
	if record["hit_by"] != "":
		blow_row.add_child(_picture(MinionIndex.icon(record["hit_by"]), 48))
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(Parchment.ink_label(cause_of_death(record), 20))
	if record["hit_by"] != "":
		words.add_child(Parchment.ink_label(killing_blow(record), 15))
	blow_row.add_child(words)
	blow.add_child(blow_row)
	column.add_child(blow)

	page.modulate.a = 0.0
	page.scale = Vector2(0.96, 0.96)
	page.pivot_offset = Vector2(300, 200)
	var tween := create_tween().set_parallel()
	tween.tween_property(page, "modulate:a", 1.0, 0.15)
	tween.tween_property(page, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ItemSounds.play(self, ItemSounds.TAB)

func _close_history() -> void:
	if _history == null:
		return
	_history.queue_free()
	_history = null
	for id in _graves:
		_graves[id].selected = false

func _picture(texture: Texture2D, side: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(side, side)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

# ---------------------------------------------------------------- one grave

## A headstone with the adventurer's name and cause of death carved into its face,
## a candle that lights once they press End, and "You" / "Ready" underneath.
class Grave extends Control:
	signal opened

	const LIFT := PX
	var selected := false:
		set(value):
			selected = value
			_update_look()
	var _body := Control.new()
	var _outline := TextureRect.new()
	var _candle := TextureRect.new()
	var _tag: Label
	var _is_local := false
	var _voted := false
	var _hover := false
	var _flicker := 0.0

	static var _outlines: Dictionary = {}

	func _init(_peer_id: int, who: String, cause: String, stone: Texture2D, is_local: bool) -> void:
		_is_local = is_local
		custom_minimum_size = Vector2(STONE_SIZE * PX, STONE_SIZE * PX + 28)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "%s's history" % who
		_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_body)

		_outline.texture = _outline_of(stone)
		_outline.position = -Vector2.ONE * PX
		_art(_outline, (STONE_SIZE + 2) * PX)
		_outline.visible = false
		_body.add_child(_outline)
		var slab := TextureRect.new()
		slab.texture = stone
		_art(slab, STONE_SIZE * PX)
		_body.add_child(slab)

		# The engraving: letters in the stone's own shade, darker (or lighter on a dark
		# stone), with a light edge below, the way a chisel cut catches the light.
		var face := _face_color(stone)
		var dark := face.get_luminance() < 0.3
		var ink := face.lightened(0.55) if dark else face.darkened(0.62)
		var edge := face.darkened(0.5) if dark else face.lightened(0.3)
		var carving := VBoxContainer.new()
		carving.position = Vector2(FACE.position * PX)
		carving.size = Vector2(FACE.size * PX)
		carving.alignment = BoxContainer.ALIGNMENT_CENTER
		carving.add_theme_constant_override("separation", 4)
		carving.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carving.add_child(_carved(who.to_upper(), 17, ink, edge))
		var line := ColorRect.new()
		line.color = ink
		line.custom_minimum_size = Vector2(12 * PX, 2)
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		carving.add_child(line)
		carving.add_child(_carved(cause, 14, ink, edge))
		_body.add_child(carving)

		var flame := AtlasTexture.new()
		flame.atlas = load(ART + "Candle.png")
		flame.region = Rect2(Vector2.ZERO, CANDLE_SIZE)
		_candle.texture = flame
		_candle.position = Vector2(CANDLE_AT * PX)
		_art(_candle, 0)
		_candle.size = Vector2(CANDLE_SIZE * PX)
		_candle.visible = false
		_body.add_child(_candle)

		_tag = Label.new()
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tag.position = Vector2(0, STONE_SIZE * PX + 2)
		_tag.size = Vector2(STONE_SIZE * PX, 24)
		_tag.add_theme_font_size_override("font_size", 16)
		_tag.add_theme_color_override("font_outline_color", SHADOW)
		_tag.add_theme_constant_override("outline_size", 6)
		_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tag)

		mouse_entered.connect(func():
			_hover = true
			_update_look())
		mouse_exited.connect(func():
			_hover = false
			_update_look())
		_update_look()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			opened.emit()
			accept_event()

	## Comes up out of the ground after `delay` seconds.
	func rise(delay: float) -> void:
		_body.position.y = 24 * PX
		_body.modulate.a = 0.0
		var tween := create_tween().set_parallel()
		tween.tween_property(_body, "position:y", 0.0, 0.5).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_body, "modulate:a", 1.0, 0.3).set_delay(delay)

	func set_voted(on: bool) -> void:
		if on and not _voted:
			_candle.visible = true
		_voted = on
		set_process(on)
		_update_look()

	func _process(delta: float) -> void:
		_flicker += delta
		var frame := 1 + int(_flicker * 6.0) % 2
		(_candle.texture as AtlasTexture).region.position.x = frame * CANDLE_SIZE.x

	func _update_look() -> void:
		var up := _hover or selected
		_outline.visible = up
		if _body.modulate.a >= 1.0:
			_body.position.y = -LIFT if up else 0.0
		var words: Array[String] = []
		if _is_local:
			words.append("You")
		if _voted:
			words.append("Ready")
		_tag.text = "  ·  ".join(words)
		_tag.add_theme_color_override("font_color", Parchment.GOLD if _voted else TEXT)

	static func _art(rect: TextureRect, side: int) -> void:
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.size = Vector2(side, side)

	static func _carved(words: String, font_size: int, ink: Color, edge: Color) -> Label:
		var label := Label.new()
		label.text = words
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = FACE.size.x * PX
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", ink)
		label.add_theme_color_override("font_shadow_color", edge)
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 2)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return label

	## The colour in the middle of the stone's face.
	static func _face_color(stone: Texture2D) -> Color:
		var image := stone.get_image()
		if image.is_compressed():
			image.decompress()
		return image.get_pixelv(FACE.get_center())

	## A one-art-pixel gold line around the stone's shape, for hover.
	static func _outline_of(stone: Texture2D) -> Texture2D:
		if _outlines.has(stone.resource_path):
			return _outlines[stone.resource_path]
		var image := stone.get_image()
		if image.is_compressed():
			image.decompress()
		var size := image.get_size()
		var out := Image.create(size.x + 2, size.y + 2, false, Image.FORMAT_RGBA8)
		var inside := func(px: int, py: int) -> bool:
			return px >= 0 and py >= 0 and px < size.x and py < size.y and image.get_pixel(px, py).a > 0.5
		for y in size.y + 2:
			for x in size.x + 2:
				if inside.call(x - 1, y - 1):
					continue
				if inside.call(x - 2, y - 1) or inside.call(x, y - 1) or inside.call(x - 1, y - 2) or inside.call(x - 1, y):
					out.set_pixel(x, y, Parchment.GOLD)
		var texture := ImageTexture.create_from_image(out)
		_outlines[stone.resource_path] = texture
		return texture
