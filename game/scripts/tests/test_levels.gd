extends TestSuite
## Tests für das Stufensystem (Ticket #27):
## - Regeln als reine Funktionen (LevelRules): Erfahrungskurve aus den Daten,
##   Übertrag, mehrere Aufstiege, Höchststufe, Stufenunterschied, graue Gegner,
##   Totenkopf, Rang, Gruppenbonus und Aufteilung nach Stufe.
## - Zusammenfassung (LevelUpSummary): Werte je Klasse, neue Fähigkeiten,
##   Spezialisierung, Talentpunkte, weitere Freischaltungen aus der Tabelle.
## - Mit echten Spielfiguren (ohne Netzwerk ist die eigene Instanz der Host):
##   Erfahrung gewähren, Aufstieg mit Auffüllen, Freischaltungen, Höchststufe,
##   Tote, Stufe setzen, Erfahrung für Kills (Radius, Gruppe), Speichern.
## - Netzweg: Clients können sich keine Erfahrung gutschreiben (RPCs prüfen den
##   Absender), Stand wandert über CharacterData/NetPlayerInfo zum Host.
## - Oberfläche: Erfahrungsbalken, Aufstiegsmeldung mit Klick, Totenkopf.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE := preload("res://scenes/units/training_dummy.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _root: Node3D = null


## Welt-Ersatz für ExperienceService: Spielerliste und Todesereignis.
class FakeWorld:
	extends Node
	signal unit_died(unit: Unit, killer: Unit)
	var players: Array[PlayerCharacter] = []

	func get_all_players() -> Array[PlayerCharacter]:
		return players


func before_all() -> void:
	_root = Node3D.new()
	_root.name = "LevelTest"
	tree.root.add_child(_root)


func after_all() -> void:
	if _root != null:
		_root.free()


func _player(peer_name: String, class_id: StringName, level: int, xp := 0) -> PlayerCharacter:
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	player.name = peer_name
	player.display_name = "Test" + peer_name
	player.race_id = &"human"
	player.class_id = class_id
	var c := CharacterData.new()
	c.character_name = player.display_name
	c.race_id = &"human"
	c.class_id = class_id
	c.level = level
	c.experience = xp
	player.setup_from_info(NetPlayerInfo.from_character(int(peer_name), c))
	_root.add_child(player)
	return player


func _dummy(dummy_name: String, level: int) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.name = dummy_name
	dummy.dummy_id = &"schadenspuppe_1"
	_root.add_child(dummy)
	dummy.get_stats().set_level_override(level)
	return dummy


# --- Regeln: Kurve und Aufstieg ----------------------------------------------

func test_kurve_aus_daten() -> void:
	check_equal(LevelRules.max_level(), 30, "Höchststufe 30 (spielkonstanten.csv)")
	check_equal(Data.hoechste_stufe(), 30, "Stufenregler nutzen dieselbe Höchststufe")
	var previous := 0
	for level in range(1, 30):
		var needed := LevelRules.needed_for(level)
		check(needed > previous, "Stufe %d braucht mehr als die vorige (%d > %d)" % [level, needed, previous])
		previous = needed
	check_equal(LevelRules.needed_for(1), 400, "Stufe 1: 400 (erfahrung.csv)")
	check(LevelRules.needed_for(29) > 10 * LevelRules.needed_for(1), "gegen Stufe 30 deutlich länger")
	check_equal(LevelRules.needed_for(30), 0, "Höchststufe: kein Bedarf")


func test_uebertrag_und_mehrere_aufstiege() -> void:
	var r := LevelRules.add_experience(1, 300, 150)
	check_equal([r["level"], r["experience"], r["levels"]], [2, 50, 1], "Überschuss geht in Stufe 2")
	r = LevelRules.add_experience(1, 0, 399)
	check_equal([r["level"], r["experience"]], [1, 399], "knapp darunter: kein Aufstieg")
	var big := LevelRules.needed_for(1) + LevelRules.needed_for(2) + LevelRules.needed_for(3) + 25
	r = LevelRules.add_experience(1, 0, big)
	check_equal([r["level"], r["experience"], r["levels"], r["added"]], [4, 25, 3, big],
			"Große Quest: drei Aufstiege auf einmal, Rest bleibt")


func test_hoechststufe() -> void:
	var r := LevelRules.add_experience(29, 45000, 5000)
	check_equal([r["level"], r["experience"]], [30, 0], "Auf 30 wird nichts mehr gesammelt")
	check_equal(r["added"], 760, "Nur der Teil bis Stufe 30 zählt")
	r = LevelRules.add_experience(30, 0, 1000)
	check_equal([r["level"], r["added"], r["levels"]], [30, 0, 0], "Auf Stufe 30: keine Erfahrung")
	check_equal(LevelRules.sanitize(31, 99), {"level": 30, "experience": 0}, "Stufe über 30 begrenzt")
	check_equal(LevelRules.sanitize(2, 5000), {"level": 2, "experience": 939}, "Erfahrung unter dem Bedarf")
	check_equal(LevelRules.sanitize(0, -5), {"level": 1, "experience": 0}, "Ungültiges korrigiert")


# --- Regeln: Gegner, Farben, Gruppe ------------------------------------------

func test_stufenunterschied() -> void:
	check_near(LevelRules.level_difference_factor(10, 10), 1.0, 0.001, "gleiche Stufe: 100 %")
	check_near(LevelRules.level_difference_factor(12, 10), 1.1, 0.001, "2 höher: +10 %")
	check_near(LevelRules.level_difference_factor(20, 10), 1.2, 0.001, "viel höher: höchstens +20 %")
	check_near(LevelRules.level_difference_factor(7, 10), 0.7, 0.001, "3 niedriger: −30 %")
	check_near(LevelRules.level_difference_factor(2, 10), 0.0, 0.001, "grau (−8): nichts")
	check(LevelRules.is_trivial(2, 10) and not LevelRules.is_trivial(3, 10), "grau ab −8 (wie die Farbe)")
	check_equal(UnitColors.difficulty(2, 10), UnitColors.Difficulty.TRIVIAL, "Farbe grau passt dazu")
	check(LevelRules.shows_skull(20, 10) and not LevelRules.shows_skull(19, 10), "Totenkopf ab 10 höher")


func test_kill_erfahrung() -> void:
	var base := LevelRules.kill_base(2)
	check_equal(base, 30, "Grundwert Stufe 2 (gegner_stufenwerte.csv)")
	check_equal(LevelRules.kill_base(25), LevelRules.kill_base(10), "fehlende Stufe: höchste darunter (#36: bis 10)")
	check_equal(LevelRules.kill_experience(2, "normal", 2), 30, "normal, gleiche Stufe")
	check_equal(LevelRules.kill_experience(2, "elite", 2), 60, "Elite: Faktor 2 (gegner_raenge.csv)")
	check_equal(LevelRules.kill_experience(2, "boss", 2), 150, "Boss: Faktor 5")
	check_equal(LevelRules.kill_experience(1, "normal", 12), 0, "grauer Gegner: nichts")


func test_gruppe() -> void:
	check_equal(LevelRules.group_total(100, 1), 100, "allein kein Bonus")
	check_equal(LevelRules.group_total(100, 3), 120, "drei: +10 % je weiterem Mitglied")
	var levels: Array[int] = [10, 10]
	check_equal(LevelRules.group_shares(110, levels), [55, 55] as Array[int], "gleiche Stufe: halbe-halbe")
	levels = [10, 5]
	var shares := LevelRules.group_shares(150, levels)
	check(shares[0] > shares[1], "höhere Stufe bekommt mehr")
	check_equal(shares, [100, 50] as Array[int], "nach Stufe gewichtet")
	# Gegner Stufe 3 ist für Stufe 12 grau: niemand bekommt etwas.
	levels = [12, 3]
	check_equal(LevelRules.kill_shares(3, "normal", levels), [0, 0] as Array[int], "grau für den Höchsten: nichts")
	levels = [3, 3]
	check_equal(LevelRules.kill_shares(3, "normal", levels), [22, 22] as Array[int],
			"Gruppe zu zweit: 40 + 10 % = 44, halbiert")


# --- Zusammenfassung ---------------------------------------------------------

func test_zusammenfassung_werte_je_klasse() -> void:
	var warrior := LevelUpSummary.build(&"warrior", 1, 2)
	check_equal(warrior.stat_text(), "Stärke +2, Ausdauer +2, Gewandtheit +1", "Krieger: viel Stärke und Ausdauer")
	var mage := LevelUpSummary.build(&"mage", 1, 2)
	check(mage.stat_text().begins_with("Intellekt +2"), "Magier: viel Intellekt (%s)" % mage.stat_text())
	var multi := LevelUpSummary.build(&"warrior", 1, 4)
	check_equal(multi.stat_text(), "Stärke +6, Ausdauer +6, Gewandtheit +3", "mehrere Stufen zusammengefasst")
	check_equal(LevelUpSummary.build(&"warrior", 5, 5).stat_text(), "", "kein Aufstieg: nichts")


func test_zusammenfassung_freischaltungen() -> void:
	var feuer := GameData.get_ability(&"magische_beruehrung")
	var hieb := GameData.get_ability(&"magisches_geschoss")
	var all: Array[AbilityData] = [hieb, feuer]
	var s := LevelUpSummary.build(&"mage", 1, 2, all)
	check_equal(s.abilities, [feuer] as Array[AbilityData], "neue Fähigkeit auf Stufe 2")
	check(s.lines().has("Neue Fähigkeit: %s" % feuer.display_name), "Zeile für die Fähigkeit")
	s = LevelUpSummary.build(&"mage", 9, 11)
	check(s.spec_unlocked, "Stufe 10: Spezialisierung wählbar")
	check_equal(s.talent_points, 1, "Stufe 11: ein Talentpunkt")
	check(s.lines().has("Du hast einen Talentpunkt erhalten."), "Hinweis Talentpunkt")
	s = LevelUpSummary.build(&"mage", 11, 14)
	check(not s.spec_unlocked, "schon über 10: kein neuer Hinweis")
	check_equal(s.talent_text(), "Du hast 3 Talentpunkte erhalten.", "mehrere Punkte")
	# Weitere Freischaltungen aus stufenfreischaltungen.csv (hier eigene Zeilen).
	var rows: Array = [_unlock_row("reittier", "", 20, "Du kannst jetzt reiten.", ""),
			_unlock_row("nur_krieger", "warrior", 12, "Kriegerfunktion", "talents")]
	var extras := LevelUpSummary.extras_between(&"mage", 19, 20, rows)
	check_equal(extras.size(), 1, "Reittier für alle Klassen")
	check_equal(LevelUpSummary.extras_between(&"mage", 10, 15, rows).size(), 0, "Kriegerzeile nicht für Magier")
	check_equal(LevelUpSummary.extras_between(&"warrior", 10, 15, rows)[0]["window"], &"talents", "Fenster aus Daten")
	check(LevelUpSummary.has_unlock(&"reittier", &"mage", 25, rows), "abfragbar ab Stufe 20")
	check(not LevelUpSummary.has_unlock(&"reittier", &"mage", 19, rows), "darunter nicht")


func _unlock_row(id: String, klasse: String, stufe: int, text: String, fenster: String) -> TableRow:
	var row := TableRow.new()
	row.table = LevelUpSummary.UNLOCK_TABLE
	row.values = {"id": id, "klasse": klasse, "stufe": stufe, "text": text, "fenster": fenster}
	return row


# --- Spielfigur (Host) -------------------------------------------------------

func test_erfahrung_und_aufstieg() -> void:
	var player := _player("1", &"warrior", 1)
	var experience := player.get_experience()
	var stats := player.get_stats()
	var gained: Array = []
	var ups: Array = []
	var learned: Array = []
	experience.experience_gained.connect(func(amount: int, source: StringName, source_name: String) -> void:
		gained.append([amount, source, source_name]))
	experience.leveled_up.connect(func(previous: int, level: int) -> void: ups.append([previous, level]))
	player.get_abilities().abilities_learned.connect(func(list: Array[AbilityData]) -> void: learned.append_array(list))
	var strength_before := stats.get_value(&"strength")
	stats.take_damage(stats.max_health * 0.5)
	check_equal(experience.host_grant(150, PlayerExperience.SOURCE_QUEST, "Testquest"), 150, "angerechnet")
	check_equal([player.level, experience.experience], [1, 150], "noch Stufe 1")
	check_equal(gained, [[150, PlayerExperience.SOURCE_QUEST, "Testquest"]], "Besitzer erfährt Menge und Quelle")
	experience.host_grant(300, PlayerExperience.SOURCE_KILL, "Wolf")
	check_equal([player.level, experience.experience], [2, 50], "Aufstieg mit Übertrag")
	check_equal(ups, [[1, 2]], "Aufstieg gemeldet")
	check_equal(stats.get_level(), 2, "Werte rechnen mit Stufe 2")
	check_near(stats.get_value(&"strength") - strength_before, 2.0, 0.01, "Stärke +2 (klassenwachstum.csv)")
	check_near(stats.health, stats.max_health, 0.01, "Leben aufgefüllt")
	check(learned.has(GameData.get_ability(&"spott")), "Stufe-2-Fähigkeit erlernt (landet im ersten freien Slot)")
	# Mehrere Aufstiege auf einmal bis über Stufe 11.
	var big := 0
	for level in range(2, 11):
		big += LevelRules.needed_for(level)
	experience.host_grant(big, PlayerExperience.SOURCE_QUEST, "Große Quest")
	check_equal(player.level, 11, "mehrere Aufstiege auf einmal")
	check_equal(ups[-1], [2, 11], "eine Meldung für alle Stufen")
	check(player.get_talents().has_spec_level(), "Spezialisierung wählbar")
	check_equal(player.get_talents().get_total_points(), 1, "ein Talentpunkt ab Stufe 11")
	player.free()


func test_hoechststufe_und_tod() -> void:
	var player := _player("1", &"mage", 29, 45000)
	var experience := player.get_experience()
	check_equal(experience.host_grant(100000, PlayerExperience.SOURCE_DEV), 760, "nur bis Stufe 30")
	check_equal([player.level, experience.experience], [30, 0], "Stufe 30 erreicht")
	check(experience.is_max_level(), "Höchststufe")
	check_equal(experience.host_grant(500, PlayerExperience.SOURCE_KILL), 0, "auf 30 keine Erfahrung")
	check_equal(experience.get_progress_text(), "Höchststufe erreicht", "Text für die Höchststufe")
	player.free()
	# Tote steigen auf, werden aber nicht wiederbelebt; kein Erfahrungsverlust.
	var dead := _player("1", &"mage", 3, 100)
	dead.get_stats().set_health(0.0)
	check(dead.is_dead(), "tot")
	dead.get_experience().host_grant(LevelRules.needed_for(3), PlayerExperience.SOURCE_QUEST)
	check_equal(dead.level, 4, "Aufstieg auch im Tod")
	check(dead.is_dead(), "Aufstieg belebt nicht wieder")
	check_equal(dead.get_experience().experience, 100, "Erfahrung bleibt erhalten")
	dead.free()


func test_stufe_setzen_und_entwickler_panel() -> void:
	var player := _player("1", &"mage", 1)
	var experience := player.get_experience()
	var ups: Array = []
	experience.leveled_up.connect(func(previous: int, level: int) -> void: ups.append([previous, level]))
	experience.request_dev("add", 120)
	check_equal(experience.experience, 120, "Erfahrung hinzufügen")
	experience.request_dev("level_up")
	check_equal([player.level, experience.experience], [2, 0], "Zur nächsten Stufe aufsteigen")
	experience.request_dev("set_level", 12)
	check_equal(player.level, 12, "Stufe setzen")
	check_equal(ups[-1], [2, 12], "wie ein echter Aufstieg")
	check(player.get_talents().has_spec_level(), "Freischaltungen wie beim Aufstieg")
	experience.request_dev("set_level", 5)
	check_equal([player.level, ups.size()], [5, 2], "niedriger: nur die Stufe, keine Meldung")
	experience.request_dev("set_level", 99)
	check_equal(player.level, 30, "auf die Höchststufe begrenzt")
	player.free()


func test_kill_mit_gruppe_und_radius() -> void:
	var a := _player("1", &"warrior", 2)
	var b := _player("5", &"mage", 2)
	var dummy := _dummy("KillPuppe", 2)
	a.global_position = Vector3(0, 0, 0)
	b.global_position = Vector3(5, 0, 0)
	dummy.global_position = Vector3(2, 0, 0)
	var world := FakeWorld.new()
	world.players = [a, b]
	_root.add_child(world)
	var service := ExperienceService.new()
	world.add_child(service)
	service.setup(world)
	var members: Array[PlayerCharacter] = [a, b]
	check(not dummy.gives_experience(), "Übungspuppen geben sonst keine Erfahrung")
	world.unit_died.emit(dummy, a)
	check_equal(a.get_experience().experience, 0, "Tod einer Puppe: nichts")
	check_equal(ExperienceService.members_near(dummy, members).size(), 2, "beide in der Nähe")
	check_equal(service.get_group_members(a), members, "Gruppe = Spieler der Sitzung")
	var result := service.host_award_kill(dummy, a, true)
	check_equal([result.get(a), result.get(b)], [16, 16], "30 + 10 % = 33, je Hälfte 16")
	check_equal([a.get_experience().experience, b.get_experience().experience], [16, 16],
			"beide erhalten ihren Anteil")
	check(service.host_award_kill(dummy, null, true).is_empty(), "ohne Spieler als Töter: nichts")
	# Weit weg: bekommt nichts.
	b.global_position = Vector3(500, 0, 0)
	check_equal(ExperienceService.members_near(dummy, members), [a] as Array[PlayerCharacter], "außerhalb des Radius")
	result = service.host_award_kill(dummy, a, true)
	check_equal(result.get(a), 30, "allein in der Nähe: voller Wert")
	check(not result.has(b), "entferntes Mitglied: nichts")
	# Toter Töter in der Gruppe zählt nicht.
	b.global_position = Vector3(3, 0, 0)
	b.get_stats().set_health(0.0)
	check_equal(ExperienceService.members_near(dummy, members), [a] as Array[PlayerCharacter], "Tote bekommen nichts")
	# Grauer Gegner.
	dummy.get_stats().set_level_override(1)
	a.get_experience().host_set_level(12)
	check(service.host_award_kill(dummy, a, true).is_empty(), "grauer Gegner: keine Erfahrung")
	world.free()
	dummy.free()
	a.free()
	b.free()


# --- Speichern und Netzweg ---------------------------------------------------

func test_speichern_und_netzweg() -> void:
	var c := CharacterData.new()
	c.character_name = "Stufentest"
	c.race_id = &"human"
	c.class_id = &"mage"
	c.level = 7
	c.experience = 1234
	var copy := CharacterData.from_dict(c.to_dict())
	check_equal([copy.level, copy.experience], [7, 1234], "Stufe und Erfahrung gehen zum Host")
	check_equal(Network.CHARACTER_RULES.validate(c.to_dict()), "", "Host akzeptiert den Charakter")
	var info := NetPlayerInfo.from_dict(NetPlayerInfo.from_character(3, c).to_dict())
	check_equal([info.level, info.experience], [7, 1234], "Spielerliste trägt Erfahrung")
	var path := "user://test_stufen_charakter.tres"
	check_equal(ResourceSaver.save(c, path), OK, "Charakter speichern")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterData
	check(loaded != null and loaded.level == 7 and loaded.experience == 1234, "gespeichert mit Stufe und Erfahrung")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Host übernimmt die Erfahrung beim Erzeugen und prüft sie.
	var joined := _player("7", &"mage", 2, 99999)
	check_equal(joined.get_experience().experience, LevelRules.needed_for(2) - 1, "zu viel Erfahrung begrenzt")
	# Fremde Figur (Peer 7): Meldungen gehen per RPC an ihn, nicht an diese Instanz.
	var gained: Array = []
	joined.get_experience().experience_gained.connect(func(amount: int, _s: StringName, _n: String) -> void:
		gained.append(amount))
	joined.get_experience().host_grant(10, PlayerExperience.SOURCE_KILL)
	check(gained.is_empty(), "Meldung nur beim Besitzer")
	# RPCs prüfen den Absender: direkte Aufrufe (Absender 0) wirken nicht.
	var ups: Array = []
	joined.get_experience().leveled_up.connect(func(previous: int, level: int) -> void: ups.append(level))
	joined.get_experience()._rpc_leveled_up(1, 5)
	joined.get_experience()._rpc_dev("add", 100000)
	check(ups.is_empty(), "Aufstieg nur vom Host")
	check_equal([joined.level, joined.get_experience().experience], [3, 9],
			"Client kann sich keine Erfahrung gutschreiben (nur die 10 vom Host zählen)")
	joined.free()
	# Besitzer schreibt den bestätigten Stand in den Charakter.
	var local := CharacterData.make_test_character()
	var before: CharacterData = GameSession.selected_character
	GameSession.selected_character = local
	var own := _player("1", &"mage", 1)
	own.get_experience().host_grant(500, PlayerExperience.SOURCE_QUEST)
	check_equal([local.level, local.experience], [2, 100], "Stand im eigenen Charakter")
	own.free()
	GameSession.selected_character = before


# --- Oberfläche --------------------------------------------------------------

func test_balken_meldung_und_totenkopf() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	tree.root.add_child(hud)
	var player := _player("1", &"mage", 3, 1250)
	hud.setup_experience(player.get_experience())
	var bar := hud.get_experience_bar()
	check(bar.visible, "Balken sichtbar")
	check_equal([bar.value, bar.max_value], [1250.0, 1560.0], "Füllstand")
	check_equal(bar.tooltip_text, "Erfahrung (Stufe 3): 1.250 / 1.560 (80 %)", "Tooltip mit Prozent")
	player.get_experience().host_set_level(30)
	check(not bar.visible, "auf Stufe 30 ausgeblendet")
	# Aufstiegsmeldung: Titel, Zeilen, Klick öffnet das Fenster.
	var summary := LevelUpSummary.build(&"mage", 9, 11, [GameData.get_ability(&"absoluter_nullpunkt")])
	hud.show_level_up(summary)
	var banner := hud.get_level_up_banner()
	check(banner.visible, "Meldung sichtbar")
	check_equal(banner.get_node("%TitleLabel").text, "Stufe 11 erreicht!", "Titel")
	var lines := banner.get_line_texts()
	check(lines.has("Du hast einen Talentpunkt erhalten."), "Talentpunkt in der Meldung")
	check(lines.has("Neue Fähigkeit: %s" % GameData.get_ability(&"absoluter_nullpunkt").display_name), "Fähigkeit")
	check(lines[0].begins_with("Intellekt +4"), "gestiegene Werte zuerst (%s)" % lines[0])
	for child in banner.get_node("%Lines").get_children():
		if child is Button and (child as Button).text == "Du hast einen Talentpunkt erhalten.":
			(child as Button).pressed.emit()
	check(hud.is_window_open(&"talents"), "Klick auf den Talenthinweis öffnet das Talentfenster")
	for child in banner.get_node("%Lines").get_children():
		if child is Button and (child as Button).text.begins_with("Neue Fähigkeit"):
			(child as Button).pressed.emit()
	check(hud.is_window_open(&"spellbook"), "Klick auf eine neue Fähigkeit öffnet das Zauberbuch")
	player.free()
	hud.free()
	# Totenkopf statt Zahl.
	check_equal(UnitColors.level_text(20, 10), UnitColors.SKULL_TEXT, "10 höher: Totenkopf")
	check_equal(UnitColors.level_text(19, 10), "19", "9 höher: Zahl")
	check_equal(UnitColors.level_label(25, 10), "Stufe ??", "Tooltip ohne Zahl")
