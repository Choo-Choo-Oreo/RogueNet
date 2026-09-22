class_name EntityStats
extends Node

signal health_changed(current: int, max: int)
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

func load_from_data(data: Dictionary) -> void:
	max_health = data.get("max_health", FALLBACK_HEALTH)
	strength = data.get("strength", FALLBACK_ATTRIBUTE)
	dexterity = data.get("dexterity", FALLBACK_ATTRIBUTE)
	constitution = data.get("constitution", FALLBACK_ATTRIBUTE)
	cognitive = data.get("cognitive", FALLBACK_ATTRIBUTE)
	resistances = data.get("resistances", {})

func load_from_file(path: String) -> void:
	load_from_data(JsonOnloading.load_dict(path))

func take_damage(amount: int, type: String = "") -> void:
	_apply_health(-amount, type)

func take_heal(amount: int, type: String = "") -> void:
	_apply_health(amount, type)

## Placeholder for whatever the real heal-between-dives mechanic ends up being.
func heal_to_full() -> void:
	take_heal(max_health)

func _apply_health(delta: int, type: String) -> void:
	if delta < 0:
		delta += resistances.get(type, FALLBACK_RESISTANCE)
		delta = min(delta, 0)
	current_health = clamp(current_health + delta, 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()
