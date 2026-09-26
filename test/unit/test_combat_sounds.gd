extends GutTest

## CombatSounds picks sounds from data that already exists (action ids, damage types, tags).
## These check the picking, and that every sound it can pick has a file.

const DIR := CombatSounds.DIR

func test_a_type_uses_its_own_hurt_sound() -> void:
	assert_eq(CombatSounds.hurt_path("Physical.Slashing"), DIR + "hurt/cut.wav")

func test_a_type_without_its_own_falls_back_to_its_parent() -> void:
	assert_eq(CombatSounds.hurt_path("Arcana.Ordo.Plenum"), DIR + "hurt/zap.wav", "Plenum -> Arcana")
	assert_eq(CombatSounds.hurt_path("Necrotic.Perditio"), DIR + "hurt/hiss.wav", "Perditio -> Necrotic")

func test_an_unknown_type_is_a_thump() -> void:
	assert_eq(CombatSounds.hurt_path("Nonsense"), DIR + "hurt/thump.wav")
	assert_eq(CombatSounds.hurt_path(""), DIR + "hurt/thump.wav")

func test_an_action_with_its_own_hurt_sound_wins_over_its_type() -> void:
	assert_eq(CombatSounds.hurt_path("Physical", "bite"), DIR + "hurt/bite.wav")
	assert_eq(CombatSounds.hurt_path("Physical.Slashing", "slash"), DIR + "hurt/cut.wav", "no hurt/slash, so by type")

func test_every_hurt_sound_in_the_table_has_a_file() -> void:
	for type in CombatSounds.HURT_BY_TYPE:
		assert_true(ResourceLoader.exists(CombatSounds.hurt_path(type)), type)

func test_material_comes_from_the_most_specific_tag() -> void:
	assert_eq(CombatSounds.material(["undead.skeleton"]), "bone")
	assert_eq(CombatSounds.material(["undead.ghoul"]), "flesh", "a zombie is flesh")
	assert_eq(CombatSounds.material(["beast.canine", "demon"]), "flesh")
	assert_eq(CombatSounds.material(["construct"]), "stone")

func test_every_material_has_an_impact_and_a_death_sound() -> void:
	var materials: Array = CombatSounds.MATERIAL_BY_TAG.values() + [CombatSounds.MATERIAL_FALLBACK]
	for m in materials:
		assert_true(ResourceLoader.exists(DIR + "impact/" + m + ".wav"), "impact " + m)
		assert_true(ResourceLoader.exists(DIR + "death/" + m + ".wav"), "death " + m)
	assert_true(ResourceLoader.exists(DIR + "impact/block.wav"))

func test_voice_by_id_then_tag_and_none_for_a_plain_beast() -> void:
	assert_eq(CombatSounds.voice("bat", ["beast"]), "screech")
	assert_eq(CombatSounds.voice("wolf", ["beast.canine"]), "growl")
	assert_eq(CombatSounds.voice("zombie", ["undead.ghoul"]), "moan")
	assert_eq(CombatSounds.voice("nobody", ["beast"]), "")

func test_every_minion_has_a_voice() -> void:
	for id in MinionIndex.ids():
		var data := JsonOnloading.load_dict(MinionIndex.path_of(id))
		assert_ne(CombatSounds.voice(id, data.get("tags", [])), "", id)

func test_every_voice_has_a_file() -> void:
	for v in CombatSounds.VOICE_BY_TAG.values() + CombatSounds.VOICE_BY_ID.values():
		assert_true(ResourceLoader.exists(DIR + "voice/" + v + ".wav"), v)

func test_every_action_with_damage_has_a_swing_sound() -> void:
	for id in ["slash", "bite", "bludgeon", "arrow_shot", "entropia_bolt", "perditio_touch", "wall_smash", "taunt", "throw_rock"]:
		assert_ne(CombatSounds.attack_sound({"id": id}), "", id)

func test_a_weapon_kind_comes_from_its_id() -> void:
	assert_eq(ItemDatabase.weapon_kind("militia_rusty_sword"), "sword")
	assert_eq(ItemDatabase.weapon_kind("assassin_fang"), "knife")
	assert_eq(ItemDatabase.weapon_kind("cleric_mace"), "blunt")
	assert_eq(ItemDatabase.weapon_kind("abyssal_trident"), "spear")
	assert_eq(ItemDatabase.weapon_kind("necromancer_bone_wand"), "staff")
	assert_eq(ItemDatabase.weapon_kind("wraith_bonebow"), "bow")
	assert_eq(ItemDatabase.weapon_kind(""), "", "empty hand")

func test_every_main_hand_item_has_a_weapon_kind() -> void:
	for id in ItemDatabase.all_ids():
		if ItemDatabase.item_slot(id) == "main_hand":
			assert_ne(ItemDatabase.weapon_kind(id), "", id)

func test_a_players_swing_matches_their_weapon() -> void:
	var player := Node.new()
	player.name = "7"
	player.add_to_group("protagonist")
	NetworkSync.peer_equipment[7] = {"main_hand": "cleric_mace"}
	assert_eq(CombatSounds.attack_sound({"id": "slash"}, player), DIR + "attacks/slash_blunt.wav")
	NetworkSync.peer_equipment[7] = {"main_hand": "rogue_longbow"}
	assert_eq(CombatSounds.attack_sound({"id": "arrow_shot"}, player), DIR + "attacks/arrow_shot.wav", "no variant: the plain one")
	NetworkSync.peer_equipment.erase(7)
	assert_eq(CombatSounds.attack_sound({"id": "slash"}, player), DIR + "attacks/slash.wav", "bare hands")
	player.free()

func test_a_minions_swing_matches_its_size_then_its_kind() -> void:
	var tagged := GDScript.new()   # a stand-in minion: all attack_variants reads is tags
	tagged.source_code = "extends Node
var tags: Array = []
"
	tagged.reload()
	var minion: Node = tagged.new()
	minion.set_meta("footprint", 3)
	minion.tags = ["beast.canine"]
	assert_eq(CombatSounds.attack_sound({"id": "bite"}, minion), DIR + "attacks/bite_big.wav")
	assert_eq(CombatSounds.attack_sound({"id": "slash"}, minion), DIR + "attacks/slash_beast.wav", "no slash_big: by tag")
	minion.set_meta("footprint", 1)
	assert_eq(CombatSounds.attack_sound({"id": "bite"}, minion), DIR + "attacks/bite.wav")
	minion.free()

func test_every_attack_variant_file_is_one_something_picks() -> void:
	var variants := ["big"]
	for pair in ItemDatabase.WEAPON_WORDS:
		variants.append(pair[1])
	for id in MinionIndex.ids():
		for tag in JsonOnloading.load_dict(MinionIndex.path_of(id)).get("tags", []):
			variants.append(str(tag).get_slice(".", 0))
	for file in DirAccess.get_files_at(DIR + "attacks/"):
		if file.ends_with(".wav") and file.get_basename().contains("_"):
			var parts := file.get_basename().rsplit("_", true, 1)
			if ResourceLoader.exists("res://game/actions/%s.json" % file.get_basename()):
				continue   # an action's own name (arrow_shot), not a variant
			assert_has(variants, parts[1], file)

func test_every_action_type_is_a_listed_damage_type() -> void:
	var types: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game/damage_types.json"))
	for id in ["slash", "bite", "bludgeon", "arrow_shot", "entropia_bolt", "perditio_touch"]:
		var action: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/actions/%s.json" % id))
		assert_has(types, action.get("type", ""), id)
