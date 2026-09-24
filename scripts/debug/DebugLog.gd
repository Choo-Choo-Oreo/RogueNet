class_name DebugLog
extends RefCounted

## Debug events, kept in memory and written out with the performance capture
## (DebugMenu "save"). Never sent to chat. Works the same in an exported build,
## where there is no console to read.

const MAX_LINES := 5000

static var lines: Array[String] = []

static func add(text: String) -> void:
	var stamp := "%.1f" % (Time.get_ticks_msec() / 1000.0)
	lines.append("[%ss] %s" % [stamp, text])
	if lines.size() > MAX_LINES:
		lines.pop_front()
	print("DebugLog: ", text)
