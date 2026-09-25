class_name ProtagonistSave
extends CharacterSave

## A player's saved adventurer (see CharacterSave for the files and the shared fields), in
## user://characters/protagonist/. In multiplayer the host only ever learns what an adventurer
## wears (NetworkSync.peer_equipment); the rest stays on this machine.
##
## On top of the shared fields:
##   skin        a PlayerController.SKINS key ("human")
##   difficulty  reserved for the softcore / mediumcore / hardcore tiers (not used yet)
##   equipped    slot -> item id, only slots that hold something (PlayerInventory.worn())
##   bag         item ids, "" for an empty cell (PlayerInventory.bag); a new adventurer's
##               holds every starter kit
##   storage     the same for the town storage, which belongs to this adventurer

const DIFFICULTIES := ["softcore", "mediumcore", "hardcore"]
const STARTER_KITS_PATH := "res://game/entities/entities.protagonist/starter_kits.json"

func _init() -> void:
	super("protagonist")

func _team_fields() -> Dictionary:
	return {
		"skin": "human",
		"difficulty": DIFFICULTIES[0],
		"equipped": {},
		"bag": starter_bag(),
		"storage": [],
	}

## Every kit in starter_kits.json, one after another.
static func starter_bag() -> Array:
	var bag := []
	for kit in JsonOnloading.load_dict(STARTER_KITS_PATH).values():
		bag.append_array(kit)
	return bag
