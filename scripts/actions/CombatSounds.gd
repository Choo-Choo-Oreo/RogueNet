class_name CombatSounds
extends RefCounted

## Which sound a fight makes, and how loud (SoundPlayer does the playing and the crowd rules).
## Files follow docs/STRUCTURE.md; see resources/sfx/README.md. Nothing here is stored per
## creature or per action: every choice is derived from what already exists.
## - **sfx/effects/effects.<family>/<action id>**: the swing or cast, heard when the attack starts
##   (on every peer, carried by the attack's effect, see tag_effect). No file: silent.
## - **sfx/effects/effects.<family>/<damage type>**: a player being hit, named like the type's
##   look in gfx/effects (physical.slashing). <action id>_hurt if there is one (bite_hurt), else
##   the type, most specific first, else physical.
## - **sfx/entities/impact/<material>**, **death/<material>**: a minion hit or killed, by its tags
##   (material()).
## - **sfx/entities/entities.antagonist/voice/**: now and then a minion cries out as it attacks
##   (voice()).
## Who is involved sets the volume: your own attacks and hits on you loudest, your party's
## quieter, enemies' quieter still. A boss is loud and skips the crowd limits.

const EFFECTS_DIR := "res://resources/sfx/effects/"
const ENTITIES_DIR := "res://resources/sfx/entities/"
const VOICE_DIR := ENTITIES_DIR + "entities.antagonist/voice/"

const OWN_DB := 0.0
const PARTY_DB := -5.0
const ENEMY_DB := -8.0
const IMPACT_DB := -3.0
const BOSS_DB := 2.0
const JITTER := 0.06

## The hurt sound when a damage type has none of its own, nor any of its parents.
const HURT_FALLBACK := "physical"

## Tag -> what the body sounds like when hit or killed. Most specific tag first; anything
## else is flesh.
const MATERIAL_BY_TAG := {
	"undead.skeleton": "bone",
	"undead.ghostly": "ethereal",
	"elemental": "ethereal",
	"construct": "stone",
	"ooze": "organic",
	"plant": "organic",
	"beast.insect": "organic",
}
const MATERIAL_FALLBACK := "flesh"

## Tag -> voice. A plain `beast` is too broad to have one voice, so a few are named by id.
const VOICE_BY_TAG := {
	"beast.rodent": "squeak",
	"beast.canine": "growl",
	"beast.insect": "buzz",
	"undead": "moan",
	"ooze": "gurgle",
	"plant": "hiss",
	"humanoid": "cackle",
	"demon": "cackle",
	"giant": "roar",
	"elemental": "hiss",
}
const VOICE_BY_ID := {
	"bat": "screech", "bat_echo": "screech", "owl": "screech", "eagle": "screech",
	"snake": "hiss", "scorpion": "hiss", "spider": "hiss", "spiderling": "hiss",
	"toad": "gurgle", "dragon": "roar", "minotaur": "roar",
}
## A minion cries out on about one attack in VOICE_CHANCE, and never twice in a row per species.
const VOICE_CHANCE := 5
static var _last_voice_species := ""
## Sound name -> its path in sfx/effects ("" if none), found once.
static var _effect_paths := {}

## A copy of an attack's effect that also carries what every peer needs to play its sound:
## the file, the caster's team and peer, and whether it's a boss. Called by the verbs where
## they share the effect (AttackEffect.play_between), so the sound reaches everyone with it.
static func tag_effect(caster: Node, attack: Dictionary, effect: Dictionary) -> Dictionary:
	var tagged := effect.duplicate()
	tagged["sound"] = attack_sound(attack)
	tagged["team"] = "protagonist" if caster.is_in_group("protagonist") else "antagonist"
	tagged["peer"] = int(str(caster.name)) if caster.is_in_group("protagonist") else 0
	tagged["boss"] = bool(caster.get_meta("is_boss", false))
	if tagged["team"] == "antagonist" and "minion_id" in caster:
		tagged["voice"] = roll_voice(caster.minion_id, caster.tags)
	return tagged

## res:// path of an attack's swing sound ("" if it has none).
static func attack_sound(attack: Dictionary) -> String:
	return effect_sound(str(attack.get("sound", attack.get("id", ""))))

## `<name>.wav` in whichever sfx/effects folder has it ("" if none).
static func effect_sound(name: String) -> String:
	if not _effect_paths.has(name):
		_effect_paths[name] = ""
		for folder in DirAccess.get_directories_at(EFFECTS_DIR):
			if ResourceLoader.exists(EFFECTS_DIR + folder + "/" + name + ".wav"):
				_effect_paths[name] = EFFECTS_DIR + folder + "/" + name + ".wav"
				break
	return _effect_paths[name]

## Called wherever an effect is spawned (NetworkSync._spawn_effect), on every peer.
static func on_effect(from: Node, at: Vector2, data: Dictionary) -> void:
	var sound: String = data.get("sound", "")
	if sound == "":
		return
	var db := who_db(from, data.get("team", ""), int(data.get("peer", 0)), bool(data.get("boss", false)))
	SoundPlayer.play(from, sound, {"at": at, "volume_db": db, "jitter": JITTER, "always": data.get("boss", false)})
	var cry: String = data.get("voice", "")
	if cry != "":
		SoundPlayer.play(from, VOICE_DIR + cry + ".wav", {"at": at, "volume_db": db - 2.0, "jitter": JITTER, "max_voices": 2})

## Volume for something done by (or to) a member of `team`, as heard on this machine.
static func who_db(from: Node, team: String, peer: int, boss: bool) -> float:
	if boss:
		return BOSS_DB
	if team == "protagonist":
		return OWN_DB if peer == from.multiplayer.get_unique_id() else PARTY_DB
	return ENEMY_DB

## The hurt sound for a hit by action `cause` of damage `type`.
static func hurt_path(type: String, cause: String = "") -> String:
	if cause != "" and effect_sound(cause + "_hurt") != "":
		return effect_sound(cause + "_hurt")
	var parts := type.to_lower().split(".")
	for i in range(parts.size(), 0, -1):
		var path := effect_sound(".".join(parts.slice(0, i)))
		if path != "":
			return path
	return effect_sound(HURT_FALLBACK)

## What a creature with these tags is made of (a MATERIAL_BY_TAG value, or flesh).
static func material(tags: Array) -> String:
	for tag in tags:
		var found := _by_tag(MATERIAL_BY_TAG, str(tag))
		if found != "":
			return found
	return MATERIAL_FALLBACK

## A species' voice, or "" for one that has none.
static func voice(species: String, tags: Array) -> String:
	if VOICE_BY_ID.has(species):
		return VOICE_BY_ID[species]
	for tag in tags:
		var found := _by_tag(VOICE_BY_TAG, str(tag))
		if found != "":
			return found
	return ""

## Picks the voice for one attack: "" most of the time, and never the same species twice running.
static func roll_voice(species: String, tags: Array) -> String:
	if randi() % VOICE_CHANCE != 0 or species == _last_voice_species:
		return ""
	_last_voice_species = species
	return voice(species, tags)

## `tag` or its nearest listed parent ("undead.ghoul" -> "undead").
static func _by_tag(table: Dictionary, tag: String) -> String:
	var parts := tag.split(".")
	for i in range(parts.size(), 0, -1):
		var key := ".".join(parts.slice(0, i))
		if table.has(key):
			return table[key]
	return ""

## A player being hit: its own hurt sound, deeper as health runs low.
static func play_hurt(body: Node2D, type: String, cause: String, health_fraction: float) -> void:
	var peer := int(str(body.name))
	var db := who_db(body, "protagonist", peer, false)
	SoundPlayer.play(body, hurt_path(type, cause), {
		"at": body.global_position, "volume_db": db, "jitter": JITTER,
		"pitch": lerpf(0.85, 1.0, clampf(health_fraction, 0.0, 1.0)),
	})

## A minion being hit, or blocking a hit with its resistances (amount 0).
static func play_impact(body: Node2D, tags: Array, amount: int) -> void:
	var name := "block" if amount <= 0 else material(tags)
	SoundPlayer.play(body, ENTITIES_DIR + "impact/" + name + ".wav", {
		"at": body.global_position, "volume_db": IMPACT_DB, "jitter": JITTER,
		"always": body.get_meta("is_boss", false),
	})

## A minion dying.
static func play_death(body: Node2D, tags: Array) -> void:
	SoundPlayer.play(body, ENTITIES_DIR + "death/" + material(tags) + ".wav", {
		"at": body.global_position, "volume_db": IMPACT_DB, "jitter": JITTER, "max_voices": 4,
		"always": body.get_meta("is_boss", false),
	})
