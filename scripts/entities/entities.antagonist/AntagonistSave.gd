class_name AntagonistSave
extends CharacterSave

## A player-driven antagonist's save (see CharacterSave for the files and the shared
## fields), in user://characters/antagonist/. What an antagonist keeps between runs is
## not decided yet, so it only has the shared fields; add them in _team_fields().

func _init() -> void:
	super("antagonist")
