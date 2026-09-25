class_name EntityStats
extends Node

signal health_changed(current: int, max: int)
## A hit landed: `amount` after resistances (0 = fully blocked), its damage `type`, and `cause`,
## the action id that dealt it ("" if unknown). Fires on every peer. HitFeedback listens.
signal damaged(amount: int, type: String, cause: String)
signal died

const FALLBACK_HEALTH := 1
const FALLBACK_ATTRIBUTE := 0
const FALLBACK_RESISTANCE := 0

var max_health: int = FALLBACK_HEALTH

## -1 means "never explicitly set" -> reads as max_health until something
## (taking damage, healing, a future save loader) sets a real value.
var _current_health: int = -1
var current_health: int:
	get:
		return max_health if _current_health < 0 else _current_health
	set(value):
		_current_health = value

var strength: int = FALLBACK_ATTRIBUTE
var dexterity: int = FALLBACK_ATTRIBUTE
var constitution: int = FALLBACK_ATTRIBUTE
var cognitive: int = FALLBACK_ATTRIBUTE

## Flat reduction per damage type, e.g. resistances["fire"] = 5
var resistances: Dictionary = {}

## Blanket immunity flag -- minions don't target/track a ghost, slows and
## (later) other status effects skip it too. One flag checked wherever it's
## relevant, instead of a group/tag per system.
var is_ghost: bool = false

func load_from_data(data: Dictionary) -> void:
	max_health = data.get("max_health", FALLBACK_HEALTH)
	strength = data.get("strength", FALLBACK_ATTRIBUTE)
	dexterity = data.get("dexterity", FALLBACK_ATTRIBUTE)
	constitution = data.get("constitution", FALLBACK_ATTRIBUTE)
	cognitive = data.get("cognitive", FALLBACK_ATTRIBUTE)
	resistances = data.get("resistances", {})

func load_from_file(path: String) -> void:
	load_from_data(JsonOnloading.load_dict(path))

func take_damage(amount: int, type: String = "", cause: String = "") -> void:
	_apply_health(-amount, type, cause)

func take_heal(amount: int, type: String = "") -> void:
	_apply_health(amount, type)

## Placeholder for whatever the real heal-between-dives mechanic ends up being.
func heal_to_full() -> void:
	take_heal(max_health)

func _apply_health(delta: int, type: String, cause: String = "") -> void:
	var is_hit := delta < 0
	if is_hit:
		delta += resistances.get(type, FALLBACK_RESISTANCE)
		delta = min(delta, 0)
	var was_alive := current_health > 0
	var before := current_health
	current_health = clamp(current_health + delta, 0, max_health)
	health_changed.emit(current_health, max_health)
	if is_hit and was_alive:
		damaged.emit(before - current_health, type, cause)
	# Only the hit that kills bleeds; a ghost taking more damage does not bleed again.
	if was_alive and current_health == 0:
		ParticleBurst.blood(get_parent())
	if current_health == 0:
		died.emit()
