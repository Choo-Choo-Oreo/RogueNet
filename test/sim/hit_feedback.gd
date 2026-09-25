extends SceneTree

## Smoke check for hit feedback (HitFeedback, CombatSounds, DamageNumber, HurtOverlay) in a real
## dungeon: the player swings the real Slash, a minion is hit through NetworkSync, then killed,
## and the player takes a small and a big hit. Checks that numbers pop, sounds start and the
## player's own screen reacts. It does not judge how anything looks or sounds.
##
##   godot --headless -s res://test/sim/hit_feedback.gd
##
## A few seconds.
##
## Classes are loaded at run time, not named: a script run with -s is compiled before the autoloads
## (NetworkSync) exist, and naming a class that uses one would fail to compile it.

var _frames := 0
var _step := 0
var _player: Node2D
var _minion: Node2D
var _problems: Array[String] = []
var Sounds  # CombatSounds
var Player  # SoundPlayer
var Actions  # ActionIndex
var Runner  # ActionRunner
var Number  # DamageNumber

func _initialize() -> void:
	var sync := root.get_node("NetworkSync")
	sync.dungeon_seed = 1
	sync.dungeon_biome = "res://test/lab/development"
	change_scene_to_file("res://scenes/dungeon/Dungeon.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 120 or current_scene == null:
		return false
	if _frames % 20 != 0:
		return false
	_step += 1
	match _step:
		1:
			var players := get_nodes_in_group("protagonist")
			var minions := get_nodes_in_group("antagonist")
			if players.is_empty() or minions.is_empty():
				_problems.append("no player or no minion in the dungeon")
				return _finish()
			Sounds = load("res://scripts/audio/CombatSounds.gd")
			Player = load("res://scripts/audio/SoundPlayer.gd")
			Actions = load("res://scripts/actions/ActionIndex.gd")
			Runner = load("res://scripts/actions/ActionRunner.gd")
			Number = load("res://scripts/entities/DamageNumber.gd")
			_player = players[0]
			_minion = minions[0]
			# Stand the minion right next to the player so it is on screen and in reach.
			var ts: int = _player.grid_mover.tile_size
			_minion.grid_mover.teleport(_player.global_position + Vector2(ts, 0))
		2:
			var slash: Dictionary = Actions.resolve(["slash"])[0]
			Runner.perform(_player, _minion.global_position, slash)
			_expect(Player.voices(Sounds.attack_sound(slash)) > 0, "the slash made no swing sound")
		3:
			_expect(_count_numbers() > 0, "hitting the minion showed no damage number")
			_expect(Player.voices(Sounds.DIR + "impact/" + Sounds.material(_minion.tags) + ".wav") > 0 or _minion.stats.current_health <= 0, "hitting the minion made no impact sound")
			var hurt_before: int = _player.stats.current_health
			root.get_node("NetworkSync").relay_player_hit(int(str(_player.name)), 1, "Physical", "bite")
			_expect(_player.stats.current_health == hurt_before - 1, "the player took no damage")
			_expect(Player.voices(Sounds.hurt_path("Physical", "bite")) > 0, "the bite made no hurt sound")
		4:
			root.get_node("NetworkSync").relay_player_hit(int(str(_player.name)), maxi(2, _player.stats.max_health / 4), "Physical.Bludgeoning", "bludgeon")
			_expect(current_scene.get_node_or_null("HurtOverlay") != null, "a big hit made no HurtOverlay")
		5:
			var tags: Array = _minion.tags
			root.get_node("NetworkSync").report_minion_hit(int(str(_minion.name)), 9999, "Physical", "slash")
			_expect(Player.voices(Sounds.DIR + "death/" + Sounds.material(tags) + ".wav") > 0, "killing the minion made no death sound")
		6:
			return _finish()
	return false

func _count_numbers() -> int:
	var n := 0
	for child in current_scene.get_children():
		if child.get_script() == Number:
			n += 1
	return n

func _expect(ok: bool, problem: String) -> void:
	if not ok:
		_problems.append(problem)

func _finish() -> bool:
	print("PASS hit_feedback" if _problems.is_empty() else "FAIL hit_feedback: " + "; ".join(_problems))
	quit(0 if _problems.is_empty() else 1)
	return true
