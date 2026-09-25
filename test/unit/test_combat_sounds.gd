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
	assert_eq(CombatSounds.voice("crab", ["beast"]), "")

func test_every_voice_has_a_file() -> void:
	for v in CombatSounds.VOICE_BY_TAG.values() + CombatSounds.VOICE_BY_ID.values():
		assert_true(ResourceLoader.exists(DIR + "voice/" + v + ".wav"), v)

func test_every_action_with_damage_has_a_swing_sound() -> void:
	for id in ["slash", "bite", "bludgeon", "arrow_shot", "entropia_bolt", "perditio_touch", "wall_smash", "taunt", "throw_rock"]:
		assert_ne(CombatSounds.attack_sound({"id": id}), "", id)

func test_every_action_type_is_a_listed_damage_type() -> void:
	var types: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game/damage_types.json"))
	for id in ["slash", "bite", "bludgeon", "arrow_shot", "entropia_bolt", "perditio_touch"]:
		var action: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/actions/%s.json" % id))
		assert_has(types, action.get("type", ""), id)
