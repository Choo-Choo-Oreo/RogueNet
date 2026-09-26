extends GutTest

## CombatSounds picks sounds from data that already exists (action ids, damage types, tags).
## These check the picking, and that every sound it can pick has a file.

const MELEE := CombatSounds.EFFECTS_DIR + "effects.melee/"
const ARCANA := CombatSounds.EFFECTS_DIR + "effects.arcana/"
const NECROTIC := CombatSounds.EFFECTS_DIR + "effects.necrotic/"
const ENTITIES := CombatSounds.ENTITIES_DIR

func test_a_type_uses_its_own_hurt_sound() -> void:
	assert_eq(CombatSounds.hurt_path("Physical.Slashing"), MELEE + "physical.slashing.wav")

func test_a_type_without_its_own_falls_back_to_its_parent() -> void:
	assert_eq(CombatSounds.hurt_path("Arcana.Ordo.Plenum"), ARCANA + "arcana.wav", "Plenum -> Arcana")
	assert_eq(CombatSounds.hurt_path("Necrotic.Perditio"), NECROTIC + "necrotic.wav", "Perditio -> Necrotic")

func test_an_unknown_type_is_a_thump() -> void:
	assert_eq(CombatSounds.hurt_path("Nonsense"), MELEE + "physical.wav")
	assert_eq(CombatSounds.hurt_path(""), MELEE + "physical.wav")

func test_an_action_with_its_own_hurt_sound_wins_over_its_type() -> void:
	assert_eq(CombatSounds.hurt_path("Physical", "bite"), MELEE + "bite_hurt.wav")
	assert_eq(CombatSounds.hurt_path("Physical.Slashing", "slash"), MELEE + "physical.slashing.wav", "no slash_hurt, so by type")

func test_every_damage_type_has_a_hurt_sound() -> void:
	var types: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game/damage_types.json"))
	for type in types:
		assert_ne(CombatSounds.hurt_path(type), "", type)

func test_material_comes_from_the_most_specific_tag() -> void:
	assert_eq(CombatSounds.material(["undead.skeleton"]), "bone")
	assert_eq(CombatSounds.material(["undead.ghoul"]), "flesh", "a zombie is flesh")
	assert_eq(CombatSounds.material(["beast.canine", "demon"]), "flesh")
	assert_eq(CombatSounds.material(["construct"]), "stone")

func test_every_material_has_an_impact_and_a_death_sound() -> void:
	var materials: Array = CombatSounds.MATERIAL_BY_TAG.values() + [CombatSounds.MATERIAL_FALLBACK]
	for m in materials:
		assert_true(ResourceLoader.exists(ENTITIES + "impact/" + m + ".wav"), "impact " + m)
		assert_true(ResourceLoader.exists(ENTITIES + "death/" + m + ".wav"), "death " + m)
	assert_true(ResourceLoader.exists(ENTITIES + "impact/block.wav"))

func test_voice_by_id_then_tag_and_none_for_a_plain_beast() -> void:
	assert_eq(CombatSounds.voice("bat", ["beast"]), "screech")
	assert_eq(CombatSounds.voice("wolf", ["beast.canine"]), "growl")
	assert_eq(CombatSounds.voice("zombie", ["undead.ghoul"]), "moan")
	assert_eq(CombatSounds.voice("crab", ["beast"]), "")

func test_every_voice_has_a_file() -> void:
	for v in CombatSounds.VOICE_BY_TAG.values() + CombatSounds.VOICE_BY_ID.values():
		assert_true(ResourceLoader.exists(CombatSounds.VOICE_DIR + v + ".wav"), v)

func test_every_action_with_damage_has_a_swing_sound() -> void:
	for id in ["slash", "bite", "bludgeon", "arrow_shot", "entropia_bolt", "perditio_touch", "wall_smash", "taunt", "throw_rock"]:
		assert_ne(CombatSounds.attack_sound({"id": id}), "", id)

func test_every_action_type_is_a_listed_damage_type() -> void:
	var types: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game/damage_types.json"))
	for id in ["slash", "bite", "bludgeon", "arrow_shot", "entropia_bolt", "perditio_touch"]:
		var action: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/actions/%s.json" % id))
		assert_has(types, action.get("type", ""), id)
