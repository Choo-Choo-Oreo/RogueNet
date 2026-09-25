class_name RunLog
extends RefCounted

## What happened to each adventurer on this dive, for the graves screen
## (PartyWipeScreen): how long they lived, damage dealt and taken, their biggest
## hit, the rooms they walked into, what they killed and what killed them.
##
## Nothing here is sent over the network. Every hit already reaches every peer
## with its attacker (NetworkSync's hit messages), and every peer sees every
## player move, so each peer fills in its own copy and the copies agree.
## Only the current dive is kept: begin() clears it when the dungeon loads.

static var _started_msec := 0
## peer id -> one record (see _new_record)
static var _players: Dictionary = {}

static func begin() -> void:
	_started_msec = Time.get_ticks_msec()
	_players.clear()

## The record of one adventurer; an empty one if nothing has happened to them yet.
static func of(peer_id: int) -> Dictionary:
	if not _players.has(peer_id):
		_players[peer_id] = _new_record()
	return _players[peer_id]

static func _new_record() -> Dictionary:
	return {
		"died_msec": -1,        # Time.get_ticks_msec() of the killing blow, -1 while alive
		"dealt": 0,
		"taken": 0,
		"biggest": 0,           # the biggest hit they landed
		"kills": {},            # minion type id -> how many
		"rooms": {},            # room index -> true, every room they walked into alive
		# The last hit they took; once they're dead, the killing blow.
		"hit_by": "",           # minion type id ("" = unknown)
		"hit_cause": "",        # action id
		"hit_type": "",
		"hit_amount": 0,
	}

## A player took `amount` (after resistances) from `attacker`, a minion type id.
static func player_hurt(peer_id: int, amount: int, type: String, cause: String, attacker: String, killed: bool) -> void:
	var record := of(peer_id)
	record["taken"] += amount
	record["hit_by"] = attacker
	record["hit_cause"] = cause
	record["hit_type"] = type
	record["hit_amount"] = amount
	if killed:
		record["died_msec"] = Time.get_ticks_msec()

## A minion of type `minion_type` took `amount` from the player `peer_id`.
static func minion_hurt(peer_id: int, amount: int, minion_type: String, killed: bool) -> void:
	var record := of(peer_id)
	record["dealt"] += amount
	record["biggest"] = maxi(record["biggest"], amount)
	if killed:
		record["kills"][minion_type] = record["kills"].get(minion_type, 0) + 1

static func visit(peer_id: int, room_index: int) -> void:
	if room_index >= 0:
		of(peer_id)["rooms"][room_index] = true

## How long the adventurer lived, in seconds (so far, if still alive).
static func seconds_alive(peer_id: int) -> int:
	var died: int = of(peer_id)["died_msec"]
	return floori(((died if died >= 0 else Time.get_ticks_msec()) - _started_msec) / 1000.0)

## "12m 05s"
static func duration_text(seconds: int) -> String:
	return "%dm %02ds" % [floori(seconds / 60.0), seconds % 60] if seconds >= 60 else "%ds" % seconds
