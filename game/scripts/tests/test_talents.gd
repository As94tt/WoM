extends TestSuite
## Tests für Spezialisierung und Talente (Ticket #20):
## - Regeln als reine Funktionen (TalentRules): Punkte je Stufe, Reihen,
##   Wahl und Ränge, Zurücknehmen, Voraussetzungen, ganzer Stand.
## - Daten: Bäume aller Klassen, Verwandlungen, Tabellenzeilen.
## - Mit einer echten Spielfigur (ohne Netzwerk ist die eigene Instanz der
##   Host): Wahl ab Stufe 10, Verwandlung in Zauberbuch und Leisten, neue,
##   veränderte und ersetzte Fähigkeiten, Talent-Auren, Kampf, Zurücksetzen,
##   Wechseln, Ruhen bei zu niedriger Stufe, Speichern und Laden.
## - Oberfläche per simulierter Eingabe: Talentfenster (Klick, Rechtsklick,
##   Übernehmen, Verwerfen, gesperrte Reiter), Zauberbuch, Hinweis-Punkt.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TALENT_PANEL_SCENE := preload("res://scenes/ui/hud/talent_panel.tscn")
const SPELLBOOK_PANEL_SCENE := preload("res://scenes/ui/hud/spellbook_panel.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _root: Node3D = null
var _mage: PlayerCharacter = null
var _talents: PlayerTalents = null
var _abilities: PlayerAbilities = null


func before_all() -> void:
	_root = Node3D.new()
	_root.name = "TalentTest"
	tree.root.add_child(_root)
	_mage = PLAYER_SCENE.instantiate()
	_mage.name = "1"
	_mage.display_name = "Magier"
	_mage.race_id = &"human"
	_mage.class_id = &"mage"
	_root.add_child(_mage)
	_talents = _mage.get_talents()
	_abilities = _mage.get_abilities()


func after_all() -> void:
	if _root != null:
		_root.free()


## Frischer Stand: Stufe, keine Spezialisierung, außerhalb des Kampfes.
func _reset(level: int) -> void:
	var stats := _mage.get_stats()
	stats.set_in_combat(false)
	_mage.get_combat()._combat_until = -1.0
	stats.set_level_override(level)
	_talents.host_load({})


func _ability(id: StringName) -> AbilityData:
	return GameData.get_ability(id)


func _feuer_tree() -> TalentTreeData:
	return GameData.get_class_data(&"mage").get_specialization(&"mage_feuer").talent_tree


# --- Regeln (reine Funktionen) -----------------------------------------------

func test_punkte_je_stufe() -> void:
	check_equal(TalentRules.points_for_level(10, 11, 1), 0, "Stufe 10: noch kein Punkt")
	check_equal(TalentRules.points_for_level(11, 11, 1), 1, "Stufe 11: erster Punkt")
	check_equal(TalentRules.points_for_level(30, 11, 1), 20, "Stufe 30 = 20 Punkte")
	check_equal(TalentRules.points_for_level(1, 11, 1), 0, "Stufe 1: keine Punkte")
	check_equal(TalentRules.spec_level(), 10, "Spezialisierung ab Stufe 10 (spielkonstanten.csv)")
	check_equal(TalentRules.total_points(13), 3, "Stufe 13 aus den Daten: 3 Punkte")
	check_equal(TalentRules.total_points(13, 2), 5, "Bonuspunkte zählen dazu")


func test_reihen_wahl_und_raenge() -> void:
	var tree := _feuer_tree()
	var ranks := {}
	check(TalentRules.is_row_unlocked(tree, ranks, 0), "Reihe 1 ist frei")
	check(not TalentRules.is_row_unlocked(tree, ranks, 1), "Reihe 2 braucht 1 Punkt")
	check(TalentRules.add_reason(tree, ranks, &"gluehende_kraft", 10).contains("Erfordert 1 Punkte"),
			"Gesperrte Reihe meldet die Schwelle")
	check_equal(TalentRules.add_reason(tree, ranks, &"flammenstoss", 10), "", "Wahl-Talent geht")
	ranks = TalentRules.with_added(ranks, &"flammenstoss")
	check(TalentRules.add_reason(tree, ranks, &"feuerkraft", 10).contains("schon"),
			"Wahl-Talente schließen sich aus")
	check(TalentRules.add_reason(tree, ranks, &"flammenstoss", 10).contains("Höchster Rang"),
			"Wahl: nur ein Rang")
	check(TalentRules.is_row_unlocked(tree, ranks, 1), "Reihe 2 nach einem Punkt frei")
	for i in 3:
		check_equal(TalentRules.add_reason(tree, ranks, &"gluehende_kraft", 10), "", "Rang %d geht" % (i + 1))
		ranks = TalentRules.with_added(ranks, &"gluehende_kraft")
	check(TalentRules.add_reason(tree, ranks, &"gluehende_kraft", 10).contains("Höchster Rang"), "3/3 ist das Maximum")
	check(TalentRules.is_row_unlocked(tree, ranks, 2), "Reihe 3 nach 4 Punkten frei (Schwelle 3)")
	check(TalentRules.add_reason(tree, ranks, &"feuerring", 4).contains("Keine Talentpunkte"), "Ohne freie Punkte nicht")
	ranks = TalentRules.with_added(ranks, &"feuerring")
	check_equal(TalentRules.validate(tree, ranks, 5), "", "Gültiger Stand mit 5 Punkten")
	check_equal(TalentRules.spent(ranks), 5, "5 Punkte ausgegeben")
	check(TalentRules.validate(tree, ranks, 4) != "", "Zu wenige Punkte: ungültig")


func test_zuruecknehmen() -> void:
	var tree := _feuer_tree()
	var ranks := {"flammenstoss": 1, "gluehende_kraft": 2, "feuerring": 1}
	check_equal(TalentRules.validate(tree, ranks, -1), "", "Ausgangsstand gültig")
	check(TalentRules.remove_reason(tree, ranks, &"flammenstoss").contains("tiefere Reihe"),
			"Rechtsklick wirkungslos, wenn eine tiefere Reihe ihre Schwelle verliert")
	check(TalentRules.remove_reason(tree, ranks, &"gluehende_kraft").contains("tiefere Reihe"),
			"Auch in der Mitte")
	check_equal(TalentRules.remove_reason(tree, ranks, &"feuerring"), "", "Unterste Reihe geht")
	ranks = TalentRules.with_removed(ranks, &"feuerring")
	check(not ranks.has("feuerring"), "Talent mit 0 Rängen fällt heraus")
	check_equal(TalentRules.remove_reason(tree, ranks, &"gluehende_kraft"), "", "Jetzt geht die Mitte")
	check(TalentRules.remove_reason(tree, {}, &"feuerring").contains("Kein Punkt"), "Ohne Punkt nichts zurück")


func test_voraussetzungen_und_pruefung() -> void:
	# Kleiner Baum nur für den Test: B setzt A (2 Ränge) voraus.
	var a := TalentData.new()
	a.id = &"a"
	a.display_name = "A"
	a.max_ranks = 2
	var b := TalentData.new()
	b.id = &"b"
	b.display_name = "B"
	b.requires = &"a"
	var row := TalentRowData.new()
	row.kind = TalentRowData.Kind.RANKS
	row.talents = [a, b]
	var tree := TalentTreeData.new()
	tree.rows = [row]
	check(tree.get_problems().is_empty(), "Testbaum ohne Datenfehler")
	check(TalentRules.add_reason(tree, {}, &"b", 5).contains("Erfordert „A“"), "Voraussetzung fehlt")
	check(TalentRules.add_reason(tree, {"a": 1}, &"b", 5) != "", "Voraussetzung muss voll gelernt sein")
	check_equal(TalentRules.add_reason(tree, {"a": 2}, &"b", 5), "", "Voll gelernt: geht")
	check(TalentRules.remove_reason(tree, {"a": 2, "b": 1}, &"a").contains("setzt dieses Talent voraus"),
			"Voraussetzung nicht zurücknehmen, solange B gelernt ist")
	check(TalentRules.validate(tree, {"b": 1}, 5) != "", "Stand ohne Voraussetzung ungültig")
	check(TalentRules.validate(tree, {"x": 1}, 5).contains("Unbekannt"), "Unbekanntes Talent ungültig")
	check(TalentRules.validate(tree, {"a": 3}, 5).contains("Rang"), "Zu hoher Rang ungültig")
	var choice := TalentRowData.new()
	choice.talents = [a]
	var broken := TalentTreeData.new()
	broken.rows = [choice]
	check(not broken.get_problems().is_empty(), "Wahl mit nur einem Talent ist ein Datenfehler")


# --- Daten -------------------------------------------------------------------

func test_daten_aller_klassen() -> void:
	for class_data in GameData.get_classes():
		for spec in class_data.get_specializations():
			check(spec.id != &"", "%s: Spezialisierung mit ID" % class_data.id)
			if spec.talent_tree != null:
				var problems := spec.talent_tree.get_problems()
				check(problems.is_empty(), "%s: %s" % [spec.id, ", ".join(problems)])
			for transform in spec.transformations:
				check(transform != null and transform.base != null and transform.variant != null,
						"%s: Verwandlung vollständig" % spec.id)
			if spec.talent_tree != null:
				for ability in spec.talent_tree.get_all_granted_abilities():
					check(Data.faehigkeitswerte(ability.id) != null, "%s hat eine Zeile in faehigkeitswerte.csv" % ability.id)
	var mage := GameData.get_class_data(&"mage")
	var specs := mage.get_specializations()
	check_equal(specs.size(), 3, "Magier: 3 Spezialisierungen")
	var locked := specs.filter(func(s: SpecializationData) -> bool: return s.locked)
	check_equal(locked.size(), 1, "davon 1 gesperrt")
	for spec in specs:
		check_equal(spec.talent_tree.rows.size(), 3, "%s: 3 Reihen" % spec.id)
		check(spec.talent_tree.rows[0].is_choice() and not spec.talent_tree.rows[1].is_choice()
				and spec.talent_tree.rows[2].is_choice(), "%s: Wahl, Ränge, Wahl" % spec.id)
	check(mage.get_specialization(&"mage_arkan").transformations.is_empty(), "Arkan ohne Verwandlung (optional)")


# --- Mit Spielfigur ----------------------------------------------------------

func test_wahl_erst_ab_stufe_10() -> void:
	_reset(9)
	check_equal(_talents.host_request("choose", "mage_feuer"), "Spezialisierung ab Stufe 10.", "Stufe 9: keine Wahl")
	_mage.get_stats().set_level_override(10)
	check_equal(_talents.get_total_points(), 0, "Stufe 10: 0 Punkte")
	check_equal(_talents.host_request("choose", "mage_arkan"), "Noch nicht entdeckt.", "Gesperrte nicht wählbar")
	check_equal(_talents.host_request("choose", "mage_feuer"), "", "Stufe 10: Wahl geht")
	check(_talents.is_spec_active(), "Feuer ist wirksam")
	check_equal(_talents.host_request("choose", "mage_frost"), "Erst die Spezialisierung wechseln.",
			"Zweite Wahl nur nach Wechsel")


func test_verwandlung_zauberbuch_und_leisten() -> void:
	_reset(10)
	var feuerball := _ability(&"feuerball")
	check(_abilities.resolve(feuerball) == feuerball, "Ohne Spezialisierung: Feuerball")
	var layout := ActionBarLayout.new()
	layout.reset(_abilities.get_default_bar_abilities())
	var bar: ActionBar = ActionBar.new()
	_root.add_child(bar)
	bar.setup(layout, _abilities)
	var slot := bar.get_slot(0)
	check_equal(slot.get_shown_ability().id, &"feuerball", "Leiste zeigt Feuerball")
	_talents.request_choose_spec(&"mage_feuer")
	check(_abilities.resolve(feuerball).id == &"glutball", "Wahl verwandelt sofort: Glutball")
	check_equal(layout.get_content(0, 0).id, &"feuerball", "Leiste speichert weiter die Grundfähigkeit")
	check_equal(slot.get_shown_ability().id, &"glutball", "Leiste zeigt sofort Glutball")
	check(slot.tooltip_text.begins_with("Glutball"), "Tooltip der Variante")
	check(_abilities.knows(_ability(&"glutball")), "Host kennt die Variante (Prüfung 1 beim Wirken)")
	var book: SpellbookPanel = SPELLBOOK_PANEL_SCENE.instantiate()
	_root.add_child(book)
	book.setup(_abilities)
	book.show_tab(1)
	var names: PackedStringArray = []
	for entry in book.get_entries():
		names.append(entry.get_shown_ability().display_name)
	check(names.has("Glutball") and not names.has("Feuerball"), "Zauberbuch zeigt Glutball: %s" % ", ".join(names))
	var titles: PackedStringArray = []
	for tab in book.get_tabs():
		titles.append(tab.title)
	check(titles.has("Feuer"), "Reiter der Spezialisierung: %s" % ", ".join(titles))
	_talents.request_clear_spec()
	check_equal(slot.get_shown_ability().id, &"feuerball", "Nach Wechsel wieder Feuerball")
	check_equal(layout.get_content(0, 0).id, &"feuerball", "Leiste bleibt belegt")
	book.free()
	bar.free()


func test_talente_wirken() -> void:
	_reset(13)
	_talents.request_choose_spec(&"mage_feuer")
	var learned: Array = []
	var unlearned: Array = []
	var on_learned := func(list: Array[AbilityData]) -> void: learned.append_array(list)
	var on_unlearned := func(list: Array[AbilityData]) -> void: unlearned.append_array(list)
	_abilities.abilities_learned.connect(on_learned)
	_abilities.abilities_unlearned.connect(on_unlearned)
	var flammenstoss := _ability(&"flammenstoss")
	check(not _abilities.is_learned(flammenstoss), "Talent-Fähigkeit vorher nicht erlernt")
	var ranks := {"flammenstoss": 1, "gluehende_kraft": 2}
	check_equal(_talents.host_request("apply", ranks), "", "Übernehmen geht")
	check(_abilities.is_learned(flammenstoss), "Neue Fähigkeit erlernt")
	check(learned.has(flammenstoss), "abilities_learned meldet Flammenstoß (→ erster freier Slot)")
	var glutball := _ability(&"glutball")
	check_near(glutball.get_number_for(_mage, "kosten"), 20.0, 0.01, "Glühende Kraft 2/3: Glutball kostet 30 − 2 × 5")
	check(AbilityTooltip.text(glutball, true, _mage).contains("20 Mana"), "Tooltip zeigt die veränderten Kosten")
	# Reihe 3: Feuerring ersetzt Frostnova (dritter Schritt der Auflösung).
	check(_talents.host_request("apply", {"flammenstoss": 1, "gluehende_kraft": 2, "feuerring": 1}) != "",
			"Mit 3 Punkten nicht 4 vergeben")
	_talents.request_dev("points", 1)
	check_equal(_talents.host_request("apply", {"flammenstoss": 1, "gluehende_kraft": 2, "feuerring": 1}), "",
			"Mit Bonuspunkt geht Reihe 3")
	check_equal(_abilities.resolve(_ability(&"frostnova")).id, &"feuerring", "Frostnova wird zu Feuerring")
	check(_abilities.knows(_ability(&"feuerring")), "Host kennt den Ersatz")
	# Kampf sperrt Änderungen.
	_mage.get_stats().set_in_combat(true)
	check_equal(_talents.host_request("reset", null), PlayerTalents.COMBAT_REASON, "Zurücksetzen im Kampf gesperrt")
	check_equal(_talents.host_request("clear", null), PlayerTalents.COMBAT_REASON, "Wechseln im Kampf gesperrt")
	check_equal(_talents.host_request("apply", {"flammenstoss": 1}), PlayerTalents.COMBAT_REASON,
			"Übernehmen im Kampf gesperrt")
	_mage.get_stats().set_in_combat(false)
	check_equal(_talents.host_request("reset", null), "", "Zurücksetzen außerhalb des Kampfes")
	check(not _abilities.is_learned(flammenstoss), "Talent-Fähigkeit verschwindet")
	check(unlearned.has(flammenstoss), "abilities_unlearned meldet Flammenstoß (→ von den Leisten)")
	check_near(glutball.get_number_for(_mage, "kosten"), 30.0, 0.01, "Kosten wieder normal")
	check_equal(_abilities.resolve(_ability(&"frostnova")).id, &"frostnova", "Frostnova wieder Frostnova")
	check(_talents.is_spec_active(), "Spezialisierung bleibt beim Zurücksetzen")
	_abilities.abilities_learned.disconnect(on_learned)
	_abilities.abilities_unlearned.disconnect(on_unlearned)


func test_talent_auren() -> void:
	_reset(13)
	var combat := _mage.get_combat()
	_talents.request_choose_spec(&"mage_feuer")
	check_equal(_talents.host_request("apply", {"feuerkraft": 1}), "", "Feuerkraft gewählt")
	check_equal(combat.get_stacks(&"talent_feuerkraft"), 1, "Passive Aura liegt")
	check_near(combat.get_amount_percent(AmountModifierData.Kind.DAMAGE_DONE, &"feuer"), 10.0, 0.01,
			"+10 % Feuerschaden für die Kampfberechnung")
	check_near(Combat.damage_factor(_mage, null, &"feuer"), 1.1, 0.001, "Combat rechnet mit dem Talent")
	check(_talents.host_request("apply", {"flammenstoss": 1, "feuerkraft": 1}) != "",
			"Beide Wahl-Talente einer Reihe: abgelehnt")
	check_equal(_talents.host_request("apply", {"flammenstoss": 1}), "", "Andere Wahl übernehmen")
	check_equal(combat.get_stacks(&"talent_feuerkraft"), 0, "Aura weg, wenn das Talent nicht mehr gelernt ist")
	check_equal(_talents.host_request("apply", {"feuerkraft": 1}), "", "Zurück zu Feuerkraft")
	_talents.host_request("reset", null)
	check_equal(combat.get_stacks(&"talent_feuerkraft"), 0, "Aura weg nach Zurücksetzen")
	# Gesperrte Arkan-Spezialisierung über das Entwickler-Panel, Aura mit Stapel je Rang.
	_talents.host_request("clear", null)
	_talents.request_dev("unlock", "")
	check(_talents.is_spec_unlocked(GameData.get_class_data(&"mage").get_specialization(&"mage_arkan")),
			"Entsperrt")
	check_equal(_talents.host_request("choose", "mage_arkan"), "", "Arkan jetzt wählbar")
	check_equal(_talents.host_request("apply", {"arkane_einsicht": 1, "arkane_konzentration": 1}), "", "Rang 1")
	check_equal(combat.get_stacks(&"talent_arkane_macht"), 1, "Stapel = Rang 1")
	check_equal(_talents.host_request("apply", {"arkane_einsicht": 1, "arkane_konzentration": 2}), "", "Rang 2")
	check_equal(combat.get_stacks(&"talent_arkane_macht"), 2, "Stapel = Rang 2")
	check_near(combat.get_amount_percent(AmountModifierData.Kind.DAMAGE_DONE, &"arkan"), 10.0, 0.01, "+10 % arkan")
	# Tod: Talent-Auren ruhen und kommen nach der Rückkehr wieder.
	var stats := _mage.get_stats()
	stats.set_health(0.0)
	combat._process(0.0)
	check(_mage.is_dead(), "tot")
	stats.revive(50.0, 50.0)
	combat.check_death()
	check_equal(combat.get_stacks(&"talent_arkane_macht"), 2, "Nach der Rückkehr wieder 2 Stapel")
	_talents.request_dev("reset_spec")
	check_equal(combat.get_stacks(&"talent_arkane_macht"), 0, "Entwickler-Panel: Spezialisierung zurückgesetzt")


func test_ruht_bei_niedriger_stufe() -> void:
	_reset(11)
	_talents.request_choose_spec(&"mage_frost")
	check_equal(_talents.host_request("apply", {"eislanze": 1}), "", "Eislanze gelernt")
	var frostnova := _ability(&"frostnova")
	check_equal(_abilities.resolve(frostnova).id, &"eiswelle", "Frostnova → Eiswelle")
	_mage.get_stats().set_level_override(5)
	check(not _talents.is_spec_active(), "Stufe 5: Spezialisierung ruht")
	check_equal(_abilities.resolve(frostnova).id, &"frostnova", "Ruhend: keine Verwandlung")
	check(not _abilities.is_learned(_ability(&"eislanze")), "Ruhend: Talent-Fähigkeit weg")
	check_equal(_talents.get_spec_id(), &"mage_frost", "Wahl bleibt gespeichert")
	_mage.get_stats().set_level_override(11)
	check_equal(_abilities.resolve(frostnova).id, &"eiswelle", "Stufe 11: wieder wirksam")
	check(_abilities.is_learned(_ability(&"eislanze")), "Eislanze wieder da")


func test_speichern_und_laden() -> void:
	var c := CharacterData.new()
	c.character_name = "Testmagier"
	c.race_id = &"human"
	c.class_id = &"mage"
	c.level = 12
	c.specialization_id = &"mage_feuer"
	c.talent_ranks = {"flammenstoss": 1, "gluehende_kraft": 1}
	c.unlocked_specializations = PackedStringArray(["mage_arkan"])
	c.bonus_talent_points = 2
	var copy := CharacterData.from_dict(c.to_dict())
	check_equal(copy.specialization_id, &"mage_feuer", "Spezialisierung übertragen")
	check_equal(copy.talent_ranks, {"flammenstoss": 1, "gluehende_kraft": 1}, "Ränge übertragen")
	check(copy.unlocked_specializations.has("mage_arkan"), "Freischaltung übertragen")
	check_equal(copy.bonus_talent_points, 2, "Bonuspunkte übertragen")
	var info := NetPlayerInfo.from_character(2, c)
	var info_copy := NetPlayerInfo.from_dict(info.to_dict())
	check_equal(info_copy.talents.get("spec"), "mage_feuer", "Spielerliste trägt den Stand zum Host")
	var path := "user://test_talente_charakter.tres"
	check_equal(ResourceSaver.save(c, path), OK, "Charakter speichern")
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterData
	check(loaded != null and loaded.specialization_id == &"mage_feuer" and loaded.talent_ranks.get("gluehende_kraft") == 1,
			"Gespeicherter Charakter hat Spezialisierung und Talente")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Host prüft den Stand beim Beitreten.
	var mage := GameData.get_class_data(&"mage")
	var clean := PlayerTalents.sanitize(mage, {"spec": "mage_arkan", "ranks": {"arkanschlag": 1}})
	check_equal(clean["spec"], "", "Gesperrt und nicht freigeschaltet: verworfen")
	clean = PlayerTalents.sanitize(mage, {"spec": "mage_feuer", "ranks": {"gibtsnicht": 1}})
	check_equal(clean["spec"], "mage_feuer", "Spezialisierung bleibt")
	check(clean["ranks"].is_empty(), "Ungültige Ränge verworfen")
	clean = PlayerTalents.sanitize(GameData.get_class_data(&"warrior"), {"spec": "mage_feuer"})
	check_equal(clean["spec"], "", "Fremde Klasse: verworfen")
	# Figur mit gespeichertem Stand (wie beim Beitreten).
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	player.name = "7"
	player.race_id = &"human"
	player.class_id = &"mage"
	var join := NetPlayerInfo.from_character(7, c)
	player.setup_from_info(join)
	_root.add_child(player)
	player.get_stats().set_level_override(12)
	check_equal(player.get_talents().get_rank(&"gluehende_kraft"), 1, "Host übernimmt die Ränge beim Erzeugen")
	check_equal(player.get_abilities().resolve(_ability(&"feuerball")).id, &"glutball", "und wendet sie an")
	player.free()


# --- Oberfläche (simulierte Eingabe) -----------------------------------------

func _click(button: Control, index: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = true
	button._gui_input(event)


func test_talentfenster() -> void:
	_reset(5)
	var panel: TalentPanel = TALENT_PANEL_SCENE.instantiate()
	var errors: Array = []
	panel.error.connect(func(text: String) -> void: errors.append(text))
	_root.add_child(panel)
	panel.setup(_mage)
	check_equal(panel.get_tab_buttons().size(), 3, "Ein Reiter je Spezialisierung")
	check_equal(panel.get_tab_buttons()[2].theme_type_variation, &"LockedChoiceButton", "Gesperrter Reiter ausgegraut")
	check(panel.get_tab_buttons()[2].tooltip_text.contains("Noch nicht entdeckt"), "Gesperrter Reiter: Hinweis")
	check_equal(panel.get_points_text(), "Spezialisierung ab Stufe 10", "Unter Stufe 10: Hinweis")
	check(panel.get_buttons()["choose"].disabled, "Unter Stufe 10: Wählen gesperrt")
	_click(panel.get_node_button(&"flammenstoss"), MOUSE_BUTTON_LEFT)
	check(not errors.is_empty() and errors[-1].contains("Stufe 10"), "Klick zur Ansicht meldet den Grund")
	panel.show_tab(2)
	check(_texts(panel).has("Noch nicht entdeckt"), "Gesperrte Seite zeigt „Noch nicht entdeckt“")
	check(panel.get_node_button(&"arkanschlag") == null, "Gesperrte Seite ohne Baum")
	panel.show_tab(0)
	_mage.get_stats().set_level_override(12)
	check(not panel.get_buttons()["choose"].disabled, "Ab Stufe 10: Wählen möglich")
	panel.get_buttons()["choose"].pressed.emit()
	check_equal(_talents.get_spec_id(), &"mage_feuer", "Button „Spezialisierung wählen“ wirkt")
	check_equal(panel.get_points_text(), "Verfügbare Punkte: 2", "Stufe 12: 2 Punkte")
	check(panel.get_buttons()["apply"].visible and panel.get_buttons()["apply"].disabled, "Übernehmen ohne Änderung gesperrt")
	# Klick vergibt vorläufig, Rechtsklick nimmt zurück.
	_click(panel.get_node_button(&"flammenstoss"), MOUSE_BUTTON_LEFT)
	check_equal(panel.get_rank_text(&"flammenstoss"), "1/1 (+1)", "Vorläufig mit Kennzeichen")
	check(panel.get_node_button(&"flammenstoss").is_marked_pending(), "Rahmen „vorläufig“")
	check_equal(_talents.get_rank(&"flammenstoss"), 0, "Noch nicht übernommen")
	check_equal(panel.get_points_text(), "Verfügbare Punkte: 1", "Punkte sinken vorläufig")
	_click(panel.get_node_button(&"feuerkraft"), MOUSE_BUTTON_LEFT)
	check(errors[-1].contains("schon"), "Zweites Wahl-Talent abgelehnt")
	_click(panel.get_node_button(&"gluehende_kraft"), MOUSE_BUTTON_LEFT)
	check_equal(panel.get_rank_text(&"gluehende_kraft"), "1/3 (+1)", "Ränge zeigen 1/3")
	_click(panel.get_node_button(&"flammenstoss"), MOUSE_BUTTON_RIGHT)
	check(errors[-1].contains("tiefere Reihe"), "Rechtsklick wirkungslos bei benötigtem Punkt")
	panel.get_buttons()["discard"].pressed.emit()
	check(not panel.has_pending_changes(), "Verwerfen macht alles rückgängig")
	check_equal(panel.get_rank_text(&"flammenstoss"), "0/1", "wieder 0/1")
	_click(panel.get_node_button(&"flammenstoss"), MOUSE_BUTTON_LEFT)
	_click(panel.get_node_button(&"gluehende_kraft"), MOUSE_BUTTON_LEFT)
	panel.get_buttons()["apply"].pressed.emit()
	check_equal(_talents.get_rank(&"gluehende_kraft"), 1, "Übernehmen schickt den Stand an den Host")
	check(not panel.has_pending_changes(), "Nach dem Übernehmen nichts mehr vorläufig")
	check(panel.get_node_button(&"flammenstoss").is_marked_learned(), "Rahmen „gelernt“")
	check(not panel.get_rank_text(&"feuerring").is_empty() and panel.get_node_button(&"feuerring").disabled,
			"Reihe 3 gesperrt (erfordert 3 Punkte)")
	# Kampf sperrt die Buttons.
	_mage.get_stats().set_in_combat(true)
	check(panel.get_buttons()["reset"].disabled and panel.get_buttons()["switch"].disabled,
			"Zurücksetzen und Wechseln im Kampf gesperrt")
	check(panel.get_status_text().contains("Im Kampf nicht möglich"), "Hinweis im Kampf")
	_mage.get_stats().set_in_combat(false)
	# Rückfrage über confirm_handler (wie Hud.ask): erst bei Bestätigung.
	var asked: Array = []
	panel.confirm_handler = func(title: String, _message: String, _ok: String, _cancel: String, action: Callable) -> void:
		asked.append([title, action])
	panel.get_buttons()["switch"].pressed.emit()
	check_equal(asked.size(), 1, "Wechseln fragt nach")
	check_equal(_talents.get_spec_id(), &"mage_feuer", "Ohne Bestätigung keine Änderung")
	(asked[0][1] as Callable).call()
	check_equal(_talents.get_spec_id(), &"", "Nach Bestätigung keine Spezialisierung mehr")
	check(panel.get_buttons()["choose"].visible, "Wieder „Spezialisierung wählen“")
	panel.free()


func test_hinweis_punkt_im_hud() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	_root.add_child(hud)
	check(not hud.has_window_hint(&"talents"), "Ohne Hinweis kein Punkt")
	hud.set_window_hint(&"talents", true, "Spezialisierung wählbar")
	check(hud.has_window_hint(&"talents"), "Hinweis-Punkt sichtbar")
	var button := hud.get_node("%MicroMenu/TalentsButton") as Button
	check(button.tooltip_text.ends_with("Spezialisierung wählbar"), "Zweites Signal im Tooltip: %s" % button.tooltip_text)
	hud.set_window_hint(&"talents", false)
	check(not hud.has_window_hint(&"talents"), "Punkt verschwindet")
	var dialog := hud.ask("Spezialisierung", "Du kannst jetzt eine Spezialisierung wählen.", "Talente öffnen", "Später",
			func() -> void: hud.open_window(&"talents"))
	(dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	check(hud.is_window_open(&"talents"), "„Talente öffnen“ öffnet das Fenster")
	hud.free()


func _texts(node: Node) -> PackedStringArray:
	var result: PackedStringArray = []
	for child in node.find_children("*", "Label", true, false):
		result.append((child as Label).text)
	return result
