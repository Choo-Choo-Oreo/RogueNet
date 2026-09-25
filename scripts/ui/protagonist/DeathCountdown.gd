class_name DeathCountdown
extends Control

## Shown once every player in the party is dead; boots the party back to
## town after COUNTDOWN_SECONDS. Each peer watches its own local view of
## who's dead -- health isn't networked yet (damage is applied locally per
## peer, same simplification the attack system already has), so a host and
## a client could technically disagree here. NetworkSync.end_mission() is
## already host-only (a no-op on clients), so in practice only the host's
## own countdown actually sends anyone back; good enough for solo/local
## testing, real multiplayer death sync is later work.

const COUNTDOWN_SECONDS := 10.0

@onready var label: Label = $Label

var _time_left := 0.0
var _triggered := false

func _ready() -> void:
	hide()

func _process(delta: float) -> void:
	if _triggered:
		return
	if _all_players_dead():
		if not visible:
			show()
			_time_left = COUNTDOWN_SECONDS
		_time_left = maxf(_time_left - delta, 0.0)
		label.text = "Returning to town in %d..." % ceili(_time_left)
		if _time_left <= 0.0:
			_triggered = true
			NetworkSync.end_mission()
	elif visible:
		hide()

func _all_players_dead() -> bool:
	var players := get_tree().get_nodes_in_group("protagonist")
	if players.is_empty():
		return false
	for player in players:
		if player.stats.current_health > 0:
			return false
	return true
