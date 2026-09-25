extends GutTest

## The dive's history behind the graves screen (RunLog, PartyWipeScreen): hits and
## kills are credited to the right adventurer, the last hit a player takes is what
## killed them, and the stone's wording follows from it.

func before_each() -> void:
	RunLog.begin()

func test_a_players_kills_and_damage_are_counted() -> void:
	RunLog.minion_hurt(2, 4, "rat", false)
	RunLog.minion_hurt(2, 6, "rat", true)
	RunLog.minion_hurt(2, 9, "wolf", true)
	var record := RunLog.of(2)
	assert_eq(record["dealt"], 19)
	assert_eq(record["biggest"], 9)
	assert_eq(record["kills"], {"rat": 1, "wolf": 1})
	assert_eq(RunLog.of(3)["dealt"], 0, "someone else's record is untouched")

func test_the_last_hit_taken_is_the_killing_blow() -> void:
	RunLog.player_hurt(1, 5, "physical", "bite", "wolf", false)
	assert_eq(RunLog.of(1)["died_msec"], -1, "still alive")
	RunLog.player_hurt(1, 14, "physical", "gore", "minotaur", true)
	var record := RunLog.of(1)
	assert_eq(record["taken"], 19)
	assert_eq(record["hit_by"], "minotaur")
	assert_true(record["died_msec"] >= 0)
	assert_eq(PartyWipeScreen.killing_blow(record), "Gore, 14 physical damage")

func test_the_engraving_names_the_killer() -> void:
	RunLog.player_hurt(1, 3, "", "bite", "rat", true)
	assert_eq(PartyWipeScreen.cause_of_death(RunLog.of(1)), "Slain by a Rat")
	RunLog.player_hurt(2, 3, "", "bite", "imp", true)
	assert_eq(PartyWipeScreen.cause_of_death(RunLog.of(2)), "Slain by an Imp")
	RunLog.player_hurt(3, 3, "", "gore", "minotaur", true)
	assert_eq(PartyWipeScreen.cause_of_death(RunLog.of(3)), "Slain by the Minotaur", "a boss is one of a kind")
	assert_eq(PartyWipeScreen.cause_of_death(RunLog.of(4)), "Lost in the dark", "nothing known")

func test_rooms_count_once_each() -> void:
	for room in [0, 1, 1, 2, -1]:
		RunLog.visit(5, room)
	assert_eq(RunLog.of(5)["rooms"].size(), 3, "-1 is outside every room")

func test_every_biome_has_a_headstone() -> void:
	for biome in DungeonAssembler.list_biomes():
		if biome == "fallback":
			continue
		assert_true(ResourceLoader.exists(PartyWipeScreen.ART + "Headstone%s.png" % biome.capitalize()), biome)
