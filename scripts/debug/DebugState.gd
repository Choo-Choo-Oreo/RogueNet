class_name DebugState
extends RefCounted

## Every debug switch in one place, read by the systems they affect (GridMover
## for no clip, LightMap for see all, PlayerController for the attack guard,
## DebugDraw for the map draws). Static, so nothing needs a reference to the
## menu. Everything is local to this machine except god mode, which
## NetworkSync copies to the other peers.
##
## Same idea as Factorio's debug settings: options on the "always" tab draw
## whenever they are ticked; options on the "debug" tab only draw while the
## debug view (F5) is on, so a set-up can be kept ticked and shown on demand.

# --- Toggles (checked in hot paths, so plain static vars)
static var god_mode := false
static var no_clip := false
static var see_all := false
## Minions never notice the local player (tools tab, singleplayer only).
static var unseen := false
## Camera leaves the player and flies on the move keys; the player stands still
## (tools tab, singleplayer only).
static var free_cam := false

## F5. Gates every option on the "debug" tab.
static var debug_view := false

## Display option ticks, keyed "always:<option>" / "debug:<option>" ("always:show-fps", ...).
## The default set, used until the player saves their own: every useful overlay
## lives on the "debug" tab, so nothing shows until F5 is pressed.
const DEFAULT_FLAGS := {
	"debug:show-fps": true,
	"debug:show-coordinates": true,
	"debug:show-time-usage": true,
	"debug:show-minion-counts": true,
	"debug:show-session-info": true,
	"debug:show-room-outlines": true,
	"debug:show-room-ids": true,
	"debug:show-doors": true,
	"debug:show-minion-state": true,
}
const SETTINGS_PATH := "user://debug_settings.cfg"

static var flags := DEFAULT_FLAGS.duplicate()

# --- Click tools: "" (none), "spawn" or "teleport". The next left click on the
# map runs it, right click cancels.
static var click_tool := ""
static var spawn_type := ""
static var mouse_over_menu := false

# --- The last generated dungeon, set by DungeonPainter, for the room draws.
static var rooms: Dictionary = {}
static var placements: Array = []

## Is display option `name` on right now? Every option is listed on both tabs
## with its own tick: the "always" tick draws it all the time, the "debug" tick
## only while the debug view (F5) is on.
static func on(name: String) -> bool:
	return flags.get("always:" + name, false) or (debug_view and flags.get("debug:" + name, false))

# --- Persistence: every menu setting is saved to user:// on change and loaded
# the next time the menu opens. Only the overlay ticks are saved: F5 and
# everything on the tools tab (god mode, no clip, see all, spawn type) start
# fresh every run.
static var _loaded := false

static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	flags = config.get_value("debug", "flags", flags)

static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("debug", "flags", flags)
	config.save(SETTINGS_PATH)

## Back to the shipped overlay set (tools are never saved, so untouched).
static func reset_defaults() -> void:
	flags = DEFAULT_FLAGS.duplicate()
	save_settings()

static func set_flag(key: String, value: bool) -> void:
	flags[key] = value
	save_settings()

## Per-system time, in microseconds accumulated since the menu last read it.
## Systems wrap their work in add_time(); the menu turns it into ms per frame.
static var time_acc := {}
static var usage_ms := {}

static func add_time(key: String, usec: int) -> void:
	time_acc[key] = time_acc.get(key, 0) + usec

## A click that is meant for the menu or a debug tool must not also be an attack.
static func blocks_attack() -> bool:
	return click_tool != "" or mouse_over_menu or free_cam

## Index into `placements` of the room covering `tile`, or -1.
static func room_index_at(tile: Vector2i) -> int:
	for i in placements.size():
		var p = placements[i]
		var room: Dictionary = rooms.get(p.room_id, {})
		if room.is_empty():
			continue
		if Rect2i(p.offset, Vector2i(room["width"], room["height"])).has_point(tile):
			return i
	return -1
