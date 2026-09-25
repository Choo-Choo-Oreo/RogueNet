extends Node2D

## The main menu's background: a real dungeon, generated and painted by the game's own
## DungeonAssembler and DungeonPainter, with a random party in random gear sets fighting
## that biome's minions in one of its rooms. It is staged, not the game: no AI,
## networking, stats or pathfinding, just enough stepping and swinging to look like a
## fight. More minions keep coming until the party falls, and a few seconds after the
## last one dies it cuts to a new dungeon.
##
## The menu's scrolls sit in the middle of the screen, so the fight is framed to one side
## of them (a random side each time) and nobody walks behind them.

const TILE := 16
## Where the dungeon's top-left corner is painted, in tiles.
const DUNGEON_ORIGIN := Vector2i(48, 48)
## Floor cells a room needs to host the fight.
const MIN_FIGHT_CELLS := 24
## A framing that fills this much of the screen with dungeon (floor or wall) is good
## enough; otherwise another dungeon gets a try (the last try keeps what it gets).
const GOOD_COVERAGE := 0.85
const PARTY_SIZE := Vector2i(2, 4)
const MAX_MINIONS := 10
## Chance a player also wears a back item when their set has none.
const BACK_ITEM_CHANCE := 0.4
## After the last player falls: how long before the fade to the next room.
const AFTER_WIPE := 2.5
## A fight that somehow stalls moves on to a new dungeon after this long anyway.
const MAX_FIGHT_TIME := 45.0
const FADE_TIME := 0.6
## So a fight doesn't drag on, minions hit harder the longer it lasts (extra damage per second).
const DOOM_RATE := 1.0 / 6.0
## Attacks come a bit slower than in a dive, so the swings read.
const ATTACK_SLOWDOWN := Vector2(1.2, 1.8)
const PLAYER_STEP_TIME := 0.28
## How far from the screen's middle the fight sits, as a share of the screen's width.
const FIGHT_SCREEN_X := 0.27
## Nobody walks within this many pixels of the screen's middle line: the scrolls and the
## weapon pointing at them cover it (the scrolls are 84 art pixels wide at 3x and the menu
## viewport is shrunk 3x, so here they cover about 42 pixels either side).
const MENU_HALF_WIDTH := 56.0
const GRAVES_DIR := "res://resources/gfx/objects/objects.graves/"
const PAINTER := preload("res://scripts/dungeon/DungeonPainter.gd")
const ATTACK_EFFECT := preload("res://scenes/entities/AttackEffect.tscn")
const PROJECTILE := preload("res://scenes/entities/ProjectileController.tscn")
const ENTITY_Z := 1000
const NO_CELL := Vector2i(-99999, -99999)
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

class Fighter:
	var node: Node2D
	var sprite: AnimatedSprite2D
	var animator: DirectionalAnimator
	var gear: GearLayers
	var is_player := false
	var cell := Vector2i.ZERO
	var hp := 1
	var attack := {}
	var cooldown := 0.0
	var step_time := 0.3
	## Seconds left of the step or swing in progress.
	var busy := 0.0
	var alive := true

var _tiles: TileInitialize
var _actors: Node2D
var _camera: Camera2D
var _fade: ColorRect
var _fighters: Array[Fighter] = []
var _occupied := {}       # cell -> Fighter
var _floor := {}          # every walkable cell of the dungeon -> true
var _walkable := {}       # the cells fighters may use: the fight's side of the screen
var _monsters := {}       # minion id -> weight, from the biome's defines.json
var _sets := {}           # set name -> {slot: item id}
var _back_items: Array[String] = []
var _graves: Array[Texture2D] = []
var _frames := {}         # sprite_frames cache, by json path or minion id
var _fight_time := 0.0
var _spawn_timer := 0.0
var _wiped_at := -1.0
var _changing := true
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_tiles = TileInitialize.new()
	_tiles.name = "Tiles"
	add_child(_tiles)
	_actors = Node2D.new()
	_actors.name = "Actors"
	_actors.y_sort_enabled = true
	# Each tile type draws at its own sort_order; fighters sit above them all, at the
	# same z as PlayerController.tscn and MinionController.tscn.
	_actors.z_index = ENTITY_Z
	add_child(_actors)
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	_load_gear()
	_load_graves()
	# the SubViewport gets its real size from its container a frame later
	await get_tree().process_frame
	_new_scene()
	_changing = false
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME)

# ---------------------------------------------------------------- content

func _load_gear() -> void:
	for id in ItemDatabase.all_ids():
		var item := ItemDatabase.get_item(id)
		var set_name: String = item.get("set", "")
		if set_name != "":
			if not _sets.has(set_name):
				_sets[set_name] = {}
			_sets[set_name][item["slot"]] = id
		elif item.get("slot", "") == "back":
			_back_items.append(id)

## The wooden crosses (not the Grave_Pile mounds, which are drawn for one floor each).
func _load_graves() -> void:
	for file_name in DirAccess.get_files_at(GRAVES_DIR):
		var png := file_name.trim_suffix(".import")    # an exported build lists only the .import files
		if png.begins_with("Grave_") and not png.begins_with("Grave_Pile") and png.ends_with(".png"):
			var texture := load(GRAVES_DIR + png) as Texture2D
			if texture != null and not _graves.has(texture):
				_graves.append(texture)

## The biome's minion table, minus bosses and anything bigger than one tile.
func _usable_monsters(weights: Dictionary) -> Dictionary:
	var result := {}
	for id in weights:
		if MinionIndex.has(id) and not MinionIndex.is_boss(id) and int(MinionIndex.load_data(id).get("size_tiles", 1)) <= 1:
			result[id] = weights[id]
	return result

func _sprite_frames(key: String, data: Dictionary) -> SpriteFrames:
	if not _frames.has(key):
		_frames[key] = SpriteFramesLoader.build(data["sprite_frames"])
	return _frames[key]

# ---------------------------------------------------------------- scenes

func _new_scene() -> void:
	_clear()
	var biomes := DungeonAssembler.list_biomes()
	for attempt in 8:
		if biomes.is_empty():
			return
		var biome: String = biomes.pick_random()
		var defines := DungeonAssembler.load_defines(biome)
		_monsters = _usable_monsters(defines.get("monsters", {}))
		if _monsters.is_empty():
			continue
		var rooms := DungeonAssembler.load_rooms(biome)
		var placements := DungeonAssembler.generate_with_retry(rooms, _rng.randi(), defines)
		if placements.is_empty():
			continue
		_paint(rooms, placements, defines)
		# The framing (room, and which side of the scrolls) that fills the most of the screen.
		var best_room := Rect2i()
		var best_side := 0.0
		var best_coverage := -1.0
		for p in placements:
			var room: Dictionary = rooms[p.room_id]
			var rect := Rect2i(p.offset, Vector2i(int(room["width"]), int(room["height"])))
			for side in [-1.0, 1.0]:
				if _frame_fight(rect, side) != NO_CELL:
					var coverage := _view_coverage()
					if coverage > best_coverage:
						best_room = rect
						best_side = side
						best_coverage = coverage
		if best_coverage < 0.0:
			continue
		if best_coverage < GOOD_COVERAGE and attempt < 7:
			continue
		var center := _frame_fight(best_room, best_side)
		if _start_fight(center):
			return

func _clear() -> void:
	for child in _actors.get_children():
		child.queue_free()
	_fighters.clear()
	_occupied.clear()
	_walkable.clear()

## Paints the whole dungeon with the dungeon's own painter, and floor_void out past
## where the camera can see.
func _paint(rooms: Dictionary, placements: Array, defines: Dictionary) -> void:
	var floor_data: TileMapLayer = _tiles.get_node("FloorData")
	var wall_data: TileMapLayer = _tiles.get_node("WallData")
	floor_data.clear()
	wall_data.clear()
	var bounds := Rect2i()
	for i in placements.size():
		var room: Dictionary = rooms[placements[i].room_id]
		var rect := Rect2i(placements[i].offset, Vector2i(int(room["width"]), int(room["height"])))
		bounds = rect if i == 0 else bounds.merge(rect)
	var shift := DUNGEON_ORIGIN - bounds.position
	for p in placements:
		p.offset += shift
	bounds.position = DUNGEON_ORIGIN
	# The painter fills floor_void over everything it painted plus a margin: two void
	# cells a screen beyond the dungeon's corners stretch that to wherever the camera looks.
	var registry := _tiles.tile_registry
	var void_id := registry.get_id("floor_void")
	var reach := Vector2i((get_viewport_rect().size / TILE).ceil())
	floor_data.set_cell(bounds.position - reach, void_id, Vector2i.ZERO)
	floor_data.set_cell(bounds.end + reach, void_id, Vector2i.ZERO)
	var painter: Node = PAINTER.new()
	painter._paint(rooms, placements, floor_data, wall_data, registry, defines)
	painter.free()
	_tiles.refresh_all()
	_floor.clear()
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var floor_id := floor_data.get_cell_source_id(cell)
			if wall_data.get_cell_source_id(cell) == -1 and floor_id != -1 and floor_id != void_id:
				_floor[cell] = true

## Points the camera so a fight in `room` sits on one `side` of the menu's scrolls
## (-1 left, 1 right), and keeps fighters to the cells on that side they can walk to
## from the fight. Returns where the fight starts, or NO_CELL when that can't hold it.
func _frame_fight(room: Rect2i, side: float) -> Vector2i:
	var in_room := {}
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			if _floor.has(Vector2i(x, y)):
				in_room[Vector2i(x, y)] = true
	if in_room.size() < MIN_FIGHT_CELLS:
		return NO_CELL
	var center := _open_center(in_room, room.get_center())
	var half := Vector2.ONE * TILE / 2.0
	var view := get_viewport_rect().size
	_camera.position = (_cell_pos(center) + half - Vector2(view.x * FIGHT_SCREEN_X * side, 0)).round()
	var on_screen := Rect2(_camera.position - view / 2.0, view).grow(-TILE / 2.0)
	var allowed := {}
	for cell in _view_cells():
		var at := _cell_pos(cell) + half
		if _floor.has(cell) and (at.x - _camera.position.x) * side > MENU_HALF_WIDTH and on_screen.has_point(at):
			allowed[cell] = true
	# only what's reachable from the fight, so no minion turns up somewhere it can't leave
	_walkable.clear()
	if not allowed.has(center):
		return NO_CELL
	var queue: Array[Vector2i] = [center]
	_walkable[center] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for n in NEIGHBOURS:
			var next: Vector2i = cell + n
			if n.x != 0 and n.y != 0 and not (allowed.has(cell + Vector2i(n.x, 0)) and allowed.has(cell + Vector2i(0, n.y))):
				continue
			if allowed.has(next) and not _walkable.has(next):
				_walkable[next] = true
				queue.append(next)
	return center if _walkable.size() >= MIN_FIGHT_CELLS else NO_CELL

## Every cell the camera can see.
func _view_cells() -> Array[Vector2i]:
	var view := get_viewport_rect().size
	var top_left := Vector2i(((_camera.position - view / 2.0) / TILE).floor())
	var bottom_right := Vector2i(((_camera.position + view / 2.0) / TILE).ceil())
	var cells: Array[Vector2i] = []
	for y in range(top_left.y, bottom_right.y):
		for x in range(top_left.x, bottom_right.x):
			cells.append(Vector2i(x, y))
	return cells

## How much of the screen shows dungeon (floor or wall) rather than empty void, 0 to 1.
func _view_coverage() -> float:
	var floor_data: TileMapLayer = _tiles.get_node("FloorData")
	var wall_data: TileMapLayer = _tiles.get_node("WallData")
	var void_id := _tiles.tile_registry.get_id("floor_void")
	var cells := _view_cells()
	var filled := 0
	for cell in cells:
		var floor_id := floor_data.get_cell_source_id(cell)
		if wall_data.get_cell_source_id(cell) != -1 or (floor_id != -1 and floor_id != void_id):
			filled += 1
	return float(filled) / maxf(1.0, cells.size())

func _start_fight(center: Vector2i) -> bool:
	if _sets.is_empty():
		return false
	var set_names: Array = _sets.keys()
	set_names.shuffle()
	var party := _rng.randi_range(PARTY_SIZE.x, PARTY_SIZE.y)
	for i in party:
		var cell := _free_cell_near(center + Vector2i(-2, 0), 3)
		if cell != NO_CELL:
			_spawn_player(cell, _sets[set_names[i % set_names.size()]])
	for i in party + 1:
		var cell := _free_cell_near(center + Vector2i(3, 0), 3)
		if cell != NO_CELL:
			_spawn_minion(cell)
	_fight_time = 0.0
	_spawn_timer = 2.0
	_wiped_at = -1.0
	return _count(true) > 0

func _change_scene() -> void:
	_changing = true
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await out.finished
	_new_scene()
	_changing = false
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_TIME)

# ---------------------------------------------------------------- fighters

func _make_fighter(cell: Vector2i, frames: SpriteFrames) -> Fighter:
	var f := Fighter.new()
	f.node = Node2D.new()
	f.node.position = _cell_pos(cell)
	f.sprite = AnimatedSprite2D.new()
	f.sprite.name = "AnimatedSprite2D"     # DirectionalAnimator's default sprite_path
	f.sprite.sprite_frames = frames
	f.sprite.position = Vector2.ONE * TILE / 2.0
	f.node.add_child(f.sprite)
	f.animator = DirectionalAnimator.new()
	f.node.add_child(f.animator)
	_actors.add_child(f.node)
	f.cell = cell
	_occupied[cell] = f
	_fighters.append(f)
	return f

func _spawn_player(cell: Vector2i, gear_set: Dictionary) -> void:
	var body_path: String = PlayerController.CHARACTERS[PlayerController.DEFAULT_CHARACTER]
	var f := _make_fighter(cell, _sprite_frames(body_path, JsonOnloading.load_dict(body_path)))
	f.is_player = true
	f.gear = GearLayers.new()
	f.node.add_child(f.gear)
	f.gear.setup(f.sprite)
	var worn := gear_set.duplicate()
	if not worn.has("back") and not _back_items.is_empty() and _rng.randf() < BACK_ITEM_CHANCE:
		worn["back"] = _back_items.pick_random()
	f.gear.set_equipment(worn)
	var data := JsonOnloading.load_dict(PlayerController.PLAYER_DATA_PATH)
	f.hp = int(data.get("max_health", 20))
	f.attack = _player_attack(data.get("actions", []), worn.get("main_hand", ""))
	f.step_time = PLAYER_STEP_TIME
	f.animator.animate_facing(Vector2.RIGHT)

## The weapon decides the attack: staffs and wands cast, bows shoot, the rest slash.
## Picked from the player's own action list (player.json), so its numbers apply.
func _player_attack(entries: Array, main_hand: String) -> Dictionary:
	var wanted := "slash"
	if main_hand.contains("staff") or main_hand.contains("wand"):
		wanted = "entropia_bolt"
	elif main_hand.contains("bow"):
		wanted = "arrow_shot"
	for entry in entries:
		var id: String = entry if entry is String else str((entry as Dictionary).get("action", ""))
		if id == wanted:
			var resolved := ActionIndex.resolve([entry])
			if not resolved.is_empty():
				return resolved[0]
	var all := ActionIndex.resolve(entries)
	return all[0] if not all.is_empty() else {}

func _spawn_minion(cell: Vector2i) -> void:
	var id := MinionSpawning._roll_minion(_monsters, _rng)
	if id == "":
		return
	var data := MinionIndex.load_data(id)
	var f := _make_fighter(cell, _sprite_frames(id, data))
	f.animator.continuous_animation = data.get("flying", false)
	f.hp = int(data.get("max_health", 5))
	for attack in ActionIndex.resolve(data.get("actions", [])):
		if attack.has("amount"):    # the first action that does damage (not a taunt)
			f.attack = attack
			break
	f.step_time = clampf(1.0 / float(data.get("speed_tiles_per_second", 3.0)), 0.15, 0.5)
	f.animator.animate_facing(Vector2.LEFT)
	f.node.modulate.a = 0.0
	f.node.create_tween().tween_property(f.node, "modulate:a", 1.0, 0.3)

# ---------------------------------------------------------------- the fight

func _process(delta: float) -> void:
	if _changing:
		return
	_fight_time += delta
	for f in _fighters.duplicate():
		if not f.alive:
			continue
		f.cooldown -= delta
		f.busy -= delta
		if f.busy <= 0.0:
			_act(f)
	var players := _count(true)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and players > 0:
		_spawn_timer = _rng.randf_range(1.2, 2.5)
		if _count(false) < mini(MAX_MINIONS, 2 + players + int(_fight_time / 4.0)):
			var cell := _far_cell()
			if cell != NO_CELL:
				_spawn_minion(cell)
	if _fight_time > MAX_FIGHT_TIME:
		_change_scene()
		return
	if players == 0:
		if _wiped_at < 0.0:
			_wiped_at = _fight_time
		elif _fight_time - _wiped_at > AFTER_WIPE:
			_change_scene()

func _act(f: Fighter) -> void:
	var target := _nearest_enemy(f)
	if target == null:
		f.animator.animate_idle()
		return
	var gap := target.cell - f.cell
	var reach := int(f.attack.get("range_tiles", 1))
	if maxi(absi(gap.x), absi(gap.y)) <= reach:
		f.animator.animate_facing(Vector2(gap))
		if f.cooldown <= 0.0 and not f.attack.is_empty():
			_attack(f, target)
		return
	_step_toward(f, target.cell)

func _attack(f: Fighter, target: Fighter) -> void:
	f.cooldown = float(f.attack.get("interval", 1.0)) * _rng.randf_range(ATTACK_SLOWDOWN.x, ATTACK_SLOWDOWN.y)
	f.busy = 0.25
	# a quick lunge toward the target
	var rest := Vector2.ONE * TILE / 2.0
	var lunge := f.node.create_tween()
	lunge.tween_property(f.sprite, "position", rest + (target.node.position - f.node.position).normalized() * 3.0, 0.06)
	lunge.tween_property(f.sprite, "position", rest, 0.1)
	var amount := float(f.attack.get("amount", 1))
	if not f.is_player:
		amount *= 1.0 + _fight_time * DOOM_RATE
	var land := _hit.bind(target, ceili(amount))
	var effect: Dictionary = f.attack.get("effect", {})
	var from := f.node.position
	var to := target.node.position
	if f.attack.get("verb", "") != "projectile":
		_play_effect(effect, from, to)
		get_tree().create_timer(0.12).timeout.connect(land)
		return
	# as ProjectileVerb: "attacker" on the shooter, the projectile's flight, "target" on arrival
	_play_effect(effect.get("attacker", {}), from, to)
	var impact := func() -> void:
		_play_effect(effect.get("target", {}), from, to)
		land.call()
	var texture: String = effect.get("projectile", "")
	if texture == "":
		get_tree().create_timer(0.12).timeout.connect(impact)
		return
	var projectile: ProjectileController = PROJECTILE.instantiate()
	_actors.add_child(projectile)
	projectile.position = from + Vector2.ONE * TILE / 2.0
	projectile.launch(texture, to + Vector2.ONE * TILE / 2.0, TILE, impact, func(_at: Vector2) -> bool: return false)

## One AttackEffect animation between two tile corners (as AttackEffect.play_between, minus the networking).
func _play_effect(data: Dictionary, from: Vector2, to: Vector2) -> void:
	if not data.has("texture"):
		return
	var effect: AttackEffect = ATTACK_EFFECT.instantiate()
	_actors.add_child(effect)
	effect.position = AttackEffect.effect_position(from, to, data)
	effect.play(data, to - from)

func _hit(target: Fighter, amount: int) -> void:
	if _changing or not target.alive or not is_instance_valid(target.node):
		return
	target.hp -= amount
	target.sprite.modulate = Color(1.0, 0.35, 0.35)
	target.node.create_tween().tween_property(target.sprite, "modulate", Color.WHITE, 0.2)
	if target.hp <= 0:
		_die(target)

func _die(f: Fighter) -> void:
	f.alive = false
	_occupied.erase(f.cell)
	if f.is_player:
		# a grave where they fell, and their ghost rising out of it
		if not _graves.is_empty():
			var grave := Sprite2D.new()
			grave.texture = _graves.pick_random()
			grave.centered = false
			grave.position = f.node.position
			_actors.add_child(grave)
		f.gear.hidden = true
		var ghost_path := PlayerController.GHOST_DATA_PATH
		f.sprite.sprite_frames = _sprite_frames(ghost_path, JsonOnloading.load_dict(ghost_path))
		f.animator.continuous_animation = true
		f.animator.animate_moving(Vector2.DOWN)
		f.node.z_index = 1
		var rise := f.node.create_tween().set_parallel()
		rise.tween_property(f.node, "position:y", f.node.position.y - 14.0, 1.6)
		rise.tween_property(f.node, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		var squash := f.node.create_tween().set_parallel()
		squash.tween_property(f.sprite, "scale", Vector2(1.3, 0.2), 0.25)
		squash.tween_property(f.node, "modulate:a", 0.0, 0.25)
		squash.chain().tween_callback(f.node.queue_free)

## One step to the free neighbouring cell closest to `goal`, never cutting a wall's corner.
func _step_toward(f: Fighter, goal: Vector2i) -> void:
	var best := f.cell
	var best_distance := Vector2(goal - f.cell).length()
	var free: Array[Vector2i] = []
	for n in NEIGHBOURS:
		var c := f.cell + n
		if not _walkable.has(c) or _occupied.has(c):
			continue
		if n.x != 0 and n.y != 0 and not (_walkable.has(f.cell + Vector2i(n.x, 0)) and _walkable.has(f.cell + Vector2i(0, n.y))):
			continue
		free.append(c)
		var distance := Vector2(goal - c).length()
		if distance < best_distance:
			best = c
			best_distance = distance
	if best == f.cell:
		# blocked: now and then shuffle aside, else wait a moment
		if free.is_empty() or _rng.randf() < 0.6:
			f.busy = _rng.randf_range(0.2, 0.5)
			f.animator.animate_idle()
			return
		best = free.pick_random()
	_occupied.erase(f.cell)
	_occupied[best] = f
	f.animator.animate_moving(Vector2(best - f.cell))
	f.cell = best
	f.busy = f.step_time
	f.node.create_tween().tween_property(f.node, "position", _cell_pos(best), f.step_time)

func _nearest_enemy(f: Fighter) -> Fighter:
	var nearest: Fighter = null
	var nearest_distance := INF
	for other in _fighters:
		if other.alive and other.is_player != f.is_player:
			var distance := Vector2(other.cell - f.cell).length()
			if distance < nearest_distance:
				nearest = other
				nearest_distance = distance
	return nearest

func _count(players: bool) -> int:
	var n := 0
	for f in _fighters:
		if f.alive and f.is_player == players:
			n += 1
	return n

# ---------------------------------------------------------------- cells

func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE)

## The cell of `cells` nearest `middle_cell` with the most open ground around it.
func _open_center(cells: Dictionary, middle_cell: Vector2i) -> Vector2i:
	var middle := Vector2(middle_cell)
	var best := NO_CELL
	var best_score := -INF
	for cell in cells:
		var open := 0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if cells.has(cell + Vector2i(dx, dy)):
					open += 1
		var score := open * 2.0 - Vector2(cell).distance_to(middle)
		if score > best_score:
			best = cell
			best_score = score
	return best

## A free walkable cell within `radius` of `target`, one of the closest few.
func _free_cell_near(target: Vector2i, radius: int) -> Vector2i:
	var cells: Array[Vector2i] = []
	for cell in _walkable:
		var gap: Vector2i = cell - target
		if not _occupied.has(cell) and maxi(absi(gap.x), absi(gap.y)) <= radius:
			cells.append(cell)
	if cells.is_empty():
		return NO_CELL
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - target).length() < Vector2(b - target).length())
	return cells[_rng.randi_range(0, mini(2, cells.size() - 1))]

## Somewhere for a new minion to come from: free, and away from every living player.
func _far_cell() -> Vector2i:
	for min_gap in [4, 2]:
		var cells: Array[Vector2i] = []
		for cell in _walkable:
			if _occupied.has(cell):
				continue
			var ok := true
			for f in _fighters:
				if f.alive and f.is_player and maxi(absi(f.cell.x - cell.x), absi(f.cell.y - cell.y)) < min_gap:
					ok = false
					break
			if ok:
				cells.append(cell)
		if not cells.is_empty():
			return cells.pick_random()
	return NO_CELL
