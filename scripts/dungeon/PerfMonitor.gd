extends Node

## Temporary instrument for the "development" stress-test biome (see
## TODO.md, 2026-09-23) -- prints FPS/frame-time/enemy-count to the output
## console once a second, for measuring the 529-rat boss room. Not meant to
## ship: delete this node from Dungeon.tscn (and this file) once the perf
## question it was added for is answered.

const PRINT_INTERVAL := 1.0

## Toggle in the Inspector (Dungeon.tscn's PerfMonitor node) to mute/unmute
## without removing the node.
@export var enabled := true

var _timer := 0.0

func _process(delta: float) -> void:
	if not enabled:
		return
	_timer += delta
	if _timer < PRINT_INTERVAL:
		return
	_timer = 0.0
	var enemy_count := get_tree().get_nodes_in_group("antagonist").size()
	var fps := Engine.get_frames_per_second()
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var node_count: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("PerfMonitor: fps=%d  process=%.2fms  physics=%.2fms  enemies=%d  nodes=%d" % [fps, process_ms, physics_ms, enemy_count, node_count])
