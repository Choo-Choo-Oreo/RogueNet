class_name HitFeedback
extends Node

## Everything a hit looks, sounds and feels like, for players and minions alike. Listens to its
## body's EntityStats.damaged / died, which fire on every peer, and never touches game state.
## On every peer, for every body:
## - the sprite flashes white, then red, and jolts a pixel or two away from whoever hit it,
## - a damage number pops up (grey "0" when resistances blocked it all), merging quick hits,
## - a few drops of blood or chips fly (ParticleBurst.hit_spray, by what the body is made of),
## - a sound: a player's hurt sound (by what hurt it) or a minion's impact; a minion's death.
## Only on the machine of the player who was hit:
## - a grunt now and then, screen shake scaled to the hit, controller rumble,
## - on a big hit, a red screen edge, a short muffle and a short visual-only hit-stop,
## - under LOW_HEALTH, a pulsing edge and a heartbeat (HurtOverlay), and a blinking health bar.
## Shake, screen flash and hit-stop can be turned off in Settings (ConfigFileHandler.feedback).
## Flash, shake and grunt fire at most once per MIN_GAP, so a swarm folds into a steady rhythm.

const FLASH_WHITE := Color(2.6, 2.6, 2.6)
const FLASH_RED := Color(1.7, 0.45, 0.45)
const WHITE_SECONDS := 0.06
const RED_SECONDS := 0.1
const RECOIL_PX := 2.0
const RECOIL_SECONDS := 0.12
const MIN_GAP := 0.25
## A hit bigger than this share of max health is a big hit.
const BIG_HIT := 0.15
const LOW_HEALTH := 0.25
const GRUNT_CHANCE := 3
const GRUNTS := ["grunt_1", "grunt_2", "grunt_3"]
const SHAKE_PER_SHARE := 18.0  # shake strength (px) for a hit worth all of max health
const SHAKE_MIN := 1.5
const SHAKE_MAX := 6.0
const HIT_STOP_SECONDS := 0.04
const HIT_STOP_REACH := 48.0   # px: sprites this close to the player freeze with it

var _body: Node2D
var _sprite: AnimatedSprite2D
var _stats: EntityStats
var _is_player := false
var _tags: Array = []

var _flash_left := 0.0
var _recoil_left := 0.0
var _recoil_dir := Vector2.ZERO
var _sprite_home := Vector2.ZERO
var _last_flash_msec := -100000
var _last_grunt := false
var _number: DamageNumber = null

func setup(body: Node2D, sprite: AnimatedSprite2D, stats: EntityStats, tags: Array = []) -> void:
	_body = body
	_sprite = sprite
	_stats = stats
	_is_player = body.is_in_group("protagonist")
	_tags = tags
	stats.damaged.connect(_on_damaged)
	stats.health_changed.connect(_on_health_changed)
	if not _is_player:
		stats.died.connect(_on_died)

## A minion's tags change with set_minion_type; the controller passes them on.
func set_tags(tags: Array) -> void:
	_tags = tags

func _is_local_player() -> bool:
	return _is_player and _body.is_multiplayer_authority()

func _on_damaged(amount: int, type: String, cause: String) -> void:
	if not _body.is_inside_tree():
		return
	var share := float(amount) / float(maxi(_stats.max_health, 1))
	var now := Time.get_ticks_msec()
	var rhythm_ok := now - _last_flash_msec >= int(MIN_GAP * 1000.0)
	var color := DamageNumber.BLOCKED if amount <= 0 else (DamageNumber.HURT if _is_player else DamageNumber.DEALT)
	_number = DamageNumber.show_on(_body, amount, color, _number)
	if amount <= 0:
		CombatSounds.play_impact(_body, _tags, 0)
		return
	if rhythm_ok:
		_last_flash_msec = now
		_flash_left = WHITE_SECONDS + RED_SECONDS
		_recoil(_away_from_nearest_foe())
	ParticleBurst.hit_spray(_body, "flesh" if _is_player else CombatSounds.material(_tags))
	if _is_player:
		CombatSounds.play_hurt(_body, type, cause, float(_stats.current_health) / float(maxi(_stats.max_health, 1)))
	else:
		CombatSounds.play_impact(_body, _tags, amount)
	if _is_local_player() and _stats.current_health > 0:
		_feel(share, rhythm_ok)

## The hurt player's own screen: grunt, shake, rumble, and on a big hit the edge, muffle and stop.
func _feel(share: float, rhythm_ok: bool) -> void:
	if rhythm_ok:
		if not _last_grunt and randi() % GRUNT_CHANCE == 0:
			SoundPlayer.play(_body, CombatSounds.DIR + "player/" + GRUNTS.pick_random() + ".wav", {"jitter": 0.05, "max_voices": 1, "volume_db": -3.0})
			_last_grunt = true
		else:
			_last_grunt = false
		var strength := clampf(share * SHAKE_PER_SHARE, SHAKE_MIN, SHAKE_MAX)
		var camera := _body.get_node_or_null("Camera2D")
		if camera and camera.has_method("shake"):
			camera.shake(strength)
		Input.start_joy_vibration(0, clampf(share * 2.0, 0.2, 1.0), clampf(share * 3.0, 0.3, 1.0), 0.12 + share * 0.3)
	if share >= BIG_HIT:
		var overlay := HurtOverlay.get_for(_body)
		if overlay:
			overlay.big_hit()
		if ConfigFileHandler.feedback("hit_stop"):
			_hit_stop()

func _on_health_changed(current: int, max_health: int) -> void:
	if not _is_local_player():
		return
	var overlay := HurtOverlay.get_for(_body)
	if overlay:
		overlay.set_low_health(current > 0 and float(current) / float(maxi(max_health, 1)) < LOW_HEALTH)

func _on_died() -> void:
	CombatSounds.play_death(_body, _tags)

## Visual-only: every sprite near the player holds its frame for a moment. Game time, movement
## and the network carry on, so no peer falls out of step.
func _hit_stop() -> void:
	var frozen: Array[AnimatedSprite2D] = []
	for group in ["protagonist", "antagonist"]:
		for creature in _body.get_tree().get_nodes_in_group(group):
			var sprite := creature.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if sprite and creature.global_position.distance_to(_body.global_position) <= HIT_STOP_REACH and sprite.speed_scale > 0.0:
				sprite.speed_scale = 0.0
				frozen.append(sprite)
	_body.get_tree().create_timer(HIT_STOP_SECONDS).timeout.connect(func():
		for sprite in frozen:
			if is_instance_valid(sprite):
				sprite.speed_scale = 1.0)

## Direction from the nearest living creature of the other team to this body (zero if none is
## close), which is where the hit most likely came from.
func _away_from_nearest_foe() -> Vector2:
	var team := "antagonist" if _is_player else "protagonist"
	var best: Node2D = null
	var best_dist := 64.0
	for foe in _body.get_tree().get_nodes_in_group(team):
		if foe.stats.is_ghost:
			continue
		var dist: float = foe.global_position.distance_to(_body.global_position)
		if dist < best_dist:
			best = foe
			best_dist = dist
	if best == null:
		return Vector2.ZERO
	var away := _body.global_position - best.global_position
	return away.normalized() if away.length() > 0.0 else Vector2.ZERO

func _recoil(direction: Vector2) -> void:
	if _recoil_left <= 0.0:
		_sprite_home = _sprite.position
	_recoil_dir = direction
	_recoil_left = RECOIL_SECONDS

func _process(delta: float) -> void:
	if _sprite == null:
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		var c := FLASH_WHITE if _flash_left > RED_SECONDS else FLASH_RED
		if _flash_left <= 0.0:
			c = Color.WHITE
		_sprite.modulate = Color(c.r, c.g, c.b, _sprite.modulate.a)
	if _recoil_left > 0.0:
		_recoil_left -= delta
		var push := maxf(_recoil_left, 0.0) / RECOIL_SECONDS
		_sprite.position = _sprite_home + (_recoil_dir * RECOIL_PX * push).round()
