extends TestSuite
## Tests für Inventar und Taschen (Ticket #18) mit den Testgegenständen aus
## gegenstaende.csv: Stapeln, „voll“, Verschieben/Tauschen/Zusammenlegen,
## Teilen, Taschen anlegen/entfernen/tauschen, Sortieren, Geld, Speichern und
## Laden (auch über eine echte Datei) und das gebündelte Speichern.
## Die Oberfläche (Taschenfenster, Taschenleiste) prüft test_inventory_ui.

const SAVE_PATH := "user://tests/inventar_test.tres"


func _new() -> Inventory:
	return Inventory.new(16)


func _id_at(inv: Inventory, container: int, index: int) -> StringName:
	var slot := inv.get_slot(container, index)
	return slot.get("id", &"")


func _count_at(inv: Inventory, container: int, index: int) -> int:
	return int(inv.get_slot(container, index).get("count", 0))


# --- Daten -------------------------------------------------------------------

func test_testgegenstaende_aus_den_daten() -> void:
	check_equal(ItemInfo.bag_slots(&"tasche_klein"), 6, "Kleiner Beutel hat 6 Plätze")
	check_equal(ItemInfo.bag_slots(&"tasche_mittel"), 8, "Lederbeutel hat 8 Plätze")
	check_equal(ItemInfo.bag_slots(&"tasche_gross"), 10, "Reisetasche hat 10 Plätze")
	check_equal(ItemInfo.stack_size(&"wolfsfell"), 20, "Wolfsfell stapelt bis 20")
	check_equal(ItemInfo.stack_size(&"schwert_rostig"), 1, "Ausrüstung stapelt nicht")
	check(ItemInfo.is_bag(&"tasche_klein") and not ItemInfo.is_bag(&"wolfsfell"), "Taschen werden am Typ erkannt")
	check_equal(ItemInfo.rarity_name(&"leuchtkristall"), "Episch", "Seltenheitsname aus seltenheiten.csv")
	check_equal(ItemInfo.type_name(&"brot_hart"), "Verbrauchsgut", "Typname aus gegenstandstypen.csv")
	check(ItemInfo.has_rarity_frame(&"lederkappe"), "Rahmen ab Ungewöhnlich")
	check(not ItemInfo.has_rarity_frame(&"wolfsfell"), "Kein Rahmen bei Gewöhnlich")
	var theme := ThemeDB.get_project_theme()
	for key: StringName in [&"poor", &"common", &"uncommon", &"rare", &"epic"]:
		check(theme != null and theme.has_color(key, ItemInfo.RARITY_THEME_TYPE), "Theme hat RarityColors/%s" % key)


func test_rucksack_groesse_aus_konstanten() -> void:
	var inv := Inventory.new()
	check_equal(inv.get_total_slots(), int(Data.konstante(&"rucksack_plaetze")), "Rucksack aus rucksack_plaetze")
	check_equal(inv.get_total_slots(), 16, "Rucksack hat 16 Plätze")
	check_equal(inv.get_free_slots(), 16, "Anfangs alles frei")


# --- Hinzufügen und Stapeln --------------------------------------------------

func test_stapeln_und_erster_freier_platz() -> void:
	var inv := _new()
	check_equal(inv.add_item(&"wolfsfell", 15), Inventory.AddResult.ADDED, "15 Wolfsfelle")
	check_equal(inv.add_item(&"schwert_rostig"), Inventory.AddResult.ADDED, "Schwert")
	check_equal(inv.add_item(&"wolfsfell", 10), Inventory.AddResult.ADDED, "10 weitere Wolfsfelle")
	check_equal(_count_at(inv, 0, 0), 20, "Erst wird der vorhandene Stapel aufgefüllt")
	check_equal(_id_at(inv, 0, 1), &"schwert_rostig", "Schwert auf Platz 2")
	check_equal(_count_at(inv, 0, 2), 5, "Rest in den ersten freien Platz")
	check_equal(inv.count_item(&"wolfsfell"), 25, "25 Wolfsfelle insgesamt")
	check_equal(inv.get_free_slots(), 13, "13 Plätze frei")


func test_voll_meldet_und_verliert_nichts() -> void:
	var inv := _new()
	for i in 16:
		inv.add_item(&"schwert_rostig")
	check_equal(inv.get_free_slots(), 0, "Rucksack voll")
	check_equal(inv.add_item(&"brot_hart"), Inventory.AddResult.FULL, "Voll wird gemeldet")
	check_equal(inv.count_item(&"brot_hart"), 0, "Nichts wurde hineingelegt")
	check_equal(inv.add_item(&"gibt_es_nicht"), Inventory.AddResult.UNKNOWN, "Unbekannter Gegenstand")
	check_equal(Inventory.MSG_FULL, "Inventar ist voll.", "Meldungstext")
	# Teilweise passend: alles oder nichts.
	var inv2 := _new()
	for i in 15:
		inv2.add_item(&"schwert_rostig")
	inv2.add_item(&"wolfsfell", 18)
	check_equal(inv2.add_item(&"wolfsfell", 3), Inventory.AddResult.FULL, "3 passen nicht mehr (nur 2 frei)")
	check_equal(inv2.count_item(&"wolfsfell"), 18, "Bei „voll“ bleibt der Stand unverändert")
	check_equal(inv2.add_item(&"wolfsfell", 2), Inventory.AddResult.ADDED, "2 passen noch")


# --- Verschieben, Tauschen, Zusammenlegen, Teilen ----------------------------

func test_verschieben_tauschen_zusammenlegen() -> void:
	var inv := _new()
	inv.add_item(&"wolfsfell", 20)
	inv.add_item(&"schwert_rostig")
	check_equal(inv.move(0, 1, 0, 5), "", "Verschieben auf leeren Platz")
	check_equal(_id_at(inv, 0, 5), &"schwert_rostig", "Schwert liegt auf Platz 6")
	check(inv.is_slot_empty(0, 1), "Alter Platz ist leer")
	check_equal(inv.move(0, 0, 0, 5), "", "Tauschen")
	check_equal(_id_at(inv, 0, 0), &"schwert_rostig", "Schwert jetzt vorn")
	check_equal(_id_at(inv, 0, 5), &"wolfsfell", "Felle jetzt auf Platz 6")
	# Zusammenlegen mit Rest.
	check_equal(inv.split(0, 5, 8), "", "8 Felle abteilen")
	check_equal(_count_at(inv, 0, 5), 12, "12 bleiben")
	check_equal(_count_at(inv, 0, 1), 8, "8 im ersten freien Platz")
	inv.add_item(&"wolfsfell", 0)
	check_equal(inv.move(0, 1, 0, 5), "", "Zusammenlegen")
	check_equal(_count_at(inv, 0, 5), 20, "Stapel voll")
	check(inv.is_slot_empty(0, 1), "Quelle leer")
	inv.add_item(&"wolfsfell", 15)
	var partial := -1
	for i in 16:
		if _id_at(inv, 0, i) == &"wolfsfell" and _count_at(inv, 0, i) == 15:
			partial = i
	check_equal(inv.move(0, partial, 0, 5), "", "Auf vollen Stapel ziehen")
	check_equal(_count_at(inv, 0, 5), 15, "Voller Stapel wird getauscht (15 liegen jetzt dort)")
	check_equal(_count_at(inv, 0, partial), 20, "… und der volle liegt am Ursprung")


func test_teilen_grenzen() -> void:
	var inv := _new()
	inv.add_item(&"wolfsfell", 5)
	check(inv.split(0, 0, 0) != "", "0 Stück teilen geht nicht")
	check(inv.split(0, 0, 5) != "", "Den ganzen Stapel teilen geht nicht")
	check(inv.split(0, 3, 1) != "", "Leerer Platz")
	for i in 15:
		inv.add_item(&"schwert_rostig")
	check_equal(inv.split(0, 0, 2), Inventory.MSG_FULL, "Teilen ohne freien Platz")
	check_equal(_count_at(inv, 0, 0), 5, "Stapel unverändert")


func test_zerstoeren_auch_questgegenstaende() -> void:
	var inv := _new()
	inv.add_item(&"brief_versiegelt")
	inv.add_item(&"wolfsfell", 7)
	check_equal(inv.destroy(0, 0), 1, "Questgegenstand zerstört")
	check_equal(inv.destroy(0, 1), 7, "Ganzer Stapel zerstört")
	check_equal(inv.get_free_slots(), 16, "Alles leer")


# --- Taschen -----------------------------------------------------------------

func test_taschen_anlegen_erweitert_das_inventar() -> void:
	var inv := _new()
	inv.add_item(&"tasche_klein")
	inv.add_item(&"tasche_gross")
	check_equal(inv.equip_bag(0, 0, 1), "", "Kleiner Beutel in Taschenplatz 1")
	check_equal(inv.get_bag(1), &"tasche_klein", "Tasche angelegt")
	check_equal(inv.get_total_slots(), 22, "16 + 6 Plätze")
	check_equal(inv.equip_bag(0, 1, 2), "", "Reisetasche in Taschenplatz 2")
	check_equal(inv.get_total_slots(), 32, "16 + 6 + 10 Plätze")
	check_equal(inv.get_free_slots(), 32, "Alle frei (Taschen liegen nicht mehr im Rucksack)")
	check_equal(inv.get_container_name(2), "Reisetasche", "Gruppenname = Name der Tasche")
	inv.add_item(&"wolfsfell")
	check_equal(inv.equip_bag(0, 0, 3), Inventory.MSG_NOT_A_BAG, "Nur Taschen")


func test_volle_tasche_laesst_sich_nicht_entfernen() -> void:
	var inv := _new()
	inv.add_item(&"tasche_klein")
	inv.equip_bag(0, 0, 1)
	inv.add_item(&"brot_hart")
	check_equal(inv.move(0, 0, 1, 2), "", "Brot in die Tasche legen")
	check_equal(inv.unequip_bag(1), Inventory.MSG_BAG_NOT_EMPTY, "Nicht leer: Meldung")
	check_equal(Inventory.MSG_BAG_NOT_EMPTY, "Die Tasche ist nicht leer.", "Meldungstext")
	check_equal(inv.get_bag(1), &"tasche_klein", "Tasche bleibt angelegt")
	# Tauschen gegen eine andere Tasche geht ebenfalls nicht.
	inv.add_item(&"tasche_mittel")
	check_equal(inv.equip_bag(0, 0, 1), Inventory.MSG_BAG_NOT_EMPTY, "Tauschen nur mit leerer Tasche")
	# Leer: entfernen und auf einen bestimmten Platz legen.
	inv.move(1, 2, 0, 5)
	check_equal(inv.unequip_bag(1, 0, 9), "", "Leere Tasche entfernen")
	check_equal(_id_at(inv, 0, 9), &"tasche_klein", "Tasche liegt auf dem gewünschten Platz")
	check_equal(inv.get_total_slots(), 16, "Wieder nur der Rucksack")
	check_equal(inv.unequip_bag(1), Inventory.MSG_NO_BAG, "Leerer Taschenplatz")


func test_leere_tasche_tauschen() -> void:
	var inv := _new()
	inv.add_item(&"tasche_klein")
	inv.add_item(&"tasche_gross")
	inv.equip_bag(0, 0, 1)
	check_equal(inv.equip_bag(0, 1, 1), "", "Reisetasche gegen leeren Beutel tauschen")
	check_equal(inv.get_bag(1), &"tasche_gross", "Reisetasche angelegt")
	check_equal(_id_at(inv, 0, 1), &"tasche_klein", "Alter Beutel liegt am Platz der neuen Tasche")
	check_equal(inv.get_container_size(1), 10, "10 Plätze")


func test_entfernen_ohne_platz() -> void:
	var inv := _new()
	inv.add_item(&"tasche_klein")
	inv.equip_bag(0, 0, 1)
	for i in 16:
		inv.add_item(&"schwert_rostig")
	# Die letzten Schwerter liegen in der Tasche; Rucksack voll machen und Tasche leeren.
	for i in 6:
		if not inv.is_slot_empty(1, i):
			inv.destroy(1, i)
	inv.add_item(&"schwert_rostig")
	inv.destroy(1, 0)
	check_equal(inv.get_free_slots(), 6, "Nur die Tasche hat noch Platz")
	check_equal(inv.unequip_bag(1), Inventory.MSG_FULL, "Kein Platz außerhalb der Tasche")


func test_taschenplaetze_tauschen() -> void:
	var inv := _new()
	inv.add_item(&"tasche_klein")
	inv.equip_bag(0, 0, 1)
	inv.add_item(&"wolfsfell", 3)
	inv.move(0, 0, 1, 4)
	check_equal(inv.swap_bag_slots(1, 3), "", "Taschenplätze tauschen")
	check_equal(inv.get_bag(3), &"tasche_klein", "Tasche jetzt auf Platz 3")
	check_equal(_id_at(inv, 3, 4), &"wolfsfell", "Inhalt wandert mit")
	check(not inv.has_container(1), "Platz 1 leer")


# --- Sortieren ---------------------------------------------------------------

func test_sortieren() -> void:
	var inv := _new()
	inv.add_item(&"tasche_klein")
	inv.equip_bag(0, 0, 2)
	for entry: Array in [[&"zahn_zerbrochen", 4], [&"wolfsfell", 12], [&"brief_versiegelt", 1],
			[&"leuchtkristall", 3], [&"brot_hart", 5], [&"lederkappe", 1], [&"tasche_mittel", 1],
			[&"schwert_rostig", 1], [&"wolfsfell", 0]]:
		if entry[1] > 0:
			inv.add_item(entry[0], entry[1])
	# Wolfsfelle auf zwei Stapel verteilen (Teilen) und in die Tasche schieben.
	var fell := -1
	for i in 16:
		if _id_at(inv, 0, i) == &"wolfsfell":
			fell = i
	inv.split(0, fell, 5)
	inv.move(0, 0, 2, 5)
	inv.sort()
	var expected: Array[StringName] = [
		&"tasche_mittel",      # Tasche
		&"lederkappe",         # Ausrüstung, ungewöhnlich
		&"schwert_rostig",     # Ausrüstung, gewöhnlich
		&"brot_hart",          # Verbrauchsgut
		&"leuchtkristall",     # Material, episch
		&"wolfsfell",          # Material, gewöhnlich (zusammengelegt)
		&"brief_versiegelt",   # Questgegenstand
		&"zahn_zerbrochen",    # Plunder
	]
	for i in expected.size():
		check_equal(_id_at(inv, 0, i), expected[i], "Platz %d nach dem Sortieren" % (i + 1))
	check_equal(_count_at(inv, 0, 5), 12, "Wolfsfelle zu einem Stapel zusammengelegt")
	check_equal(inv.get_free_slots(), 16 + 6 - 8, "Freie Plätze stimmen")
	check(inv.is_slot_empty(2, 0), "Tasche nach dem Rucksack leer (alles passt in den Rucksack)")


func test_sortieren_ueber_mehrere_taschen() -> void:
	var inv := _new()
	inv.add_item(&"tasche_klein")
	inv.equip_bag(0, 0, 1)
	for i in 18:
		inv.add_item(&"zahn_zerbrochen")  # 2 Stapel (10 + 8)
	for i in 17:
		inv.add_item(&"schwert_rostig")
	inv.sort()
	for i in 16:
		check_equal(_id_at(inv, 0, i), &"schwert_rostig", "Rucksack zuerst mit Ausrüstung (%d)" % i)
	check_equal(_id_at(inv, 1, 0), &"schwert_rostig", "17. Schwert in der Tasche")
	check_equal(_count_at(inv, 1, 1), 10, "Plunder voller Stapel")
	check_equal(_count_at(inv, 1, 2), 8, "Plunder Rest")


# --- Geld --------------------------------------------------------------------

func test_geld() -> void:
	var inv := _new()
	check(inv.add_money(12345), "Geld hinzufügen")
	check_equal(inv.money, 12345, "Ganzzahl in Kupfer")
	check_equal(ItemInfo.money_parts(12345), Vector3i(1, 23, 45), "1 Gold 23 Silber 45 Kupfer")
	check_equal(ItemInfo.money_text(12345), "1 Gold 23 Silber 45 Kupfer", "Text")
	check_equal(ItemInfo.money_text(0), "0 Kupfer", "Kein Geld")
	check_equal(ItemInfo.money_text(500), "5 Silber", "Nullen entfallen")
	check(not inv.add_money(-20000), "Nicht unter 0")
	check_equal(inv.money, 12345, "Unverändert")


# --- Speichern und Laden -----------------------------------------------------

func test_speichern_und_laden() -> void:
	var inv := _new()
	inv.add_item(&"tasche_mittel")
	inv.equip_bag(0, 0, 3)
	inv.add_item(&"wolfsfell", 25)
	inv.add_item(&"brief_versiegelt")
	inv.move(0, 1, 3, 7)
	inv.money = 4321
	var c := CharacterData.new()
	c.character_name = "Inventartest"
	var saver := InventorySaver.new(inv, c, Callable())
	saver.write_to_character()
	var loaded := _new()
	var warnings := InventorySaver.load_into(loaded, c)
	check(warnings.is_empty(), "Keine Warnungen: %s" % [warnings])
	check_equal(loaded.get_bag(3), &"tasche_mittel", "Tasche wieder angelegt")
	check_equal(_count_at(loaded, 0, 0), 20, "Voller Stapel an seinem Platz")
	check_equal(_id_at(loaded, 3, 7), &"wolfsfell", "Rest in der Tasche an seinem Platz")
	check_equal(_id_at(loaded, 0, 2), &"brief_versiegelt", "Questgegenstand an seinem Platz")
	check_equal(loaded.money, 4321, "Geld geladen")
	check_equal(loaded.get_free_slots(), inv.get_free_slots(), "Gleich viele freie Plätze")


func test_speichern_in_datei() -> void:
	var inv := _new()
	inv.add_item(&"leuchtkristall", 7)
	inv.money = 99
	var c := CharacterData.new()
	c.character_name = "Inventardatei"
	InventorySaver.new(inv, c, Callable()).write_to_character()
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	check_equal(ResourceSaver.save(c, SAVE_PATH), OK, "Charakter gespeichert")
	var restored := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterData
	check(restored != null, "Charakter geladen")
	if restored != null:
		var loaded := _new()
		InventorySaver.load_into(loaded, restored)
		check_equal(loaded.count_item(&"leuchtkristall"), 7, "Gegenstände nach Neustart erhalten")
		check_equal(loaded.money, 99, "Geld nach Neustart erhalten")
	DirAccess.remove_absolute(SAVE_PATH)


func test_laden_mit_geaenderten_daten() -> void:
	var data := {
		"version": 1,
		"taschen": ["", "wolfsfell", "tasche_klein", "gibt_es_nicht", ""],
		"plaetze": [
			[["wolfsfell", 50], [], ["unbekannt", 2]],
			[],
			[[], [], [], [], [], [], [], ["brot_hart", 3]],  # Platz 8 gibt es in einer 6er-Tasche nicht
		],
	}
	var inv := _new()
	var warnings := inv.load_save(data)
	check_equal(inv.get_bag(1), &"", "Keine Tasche: kein Taschenplatz")
	check_equal(inv.get_bag(2), &"tasche_klein", "Gültige Tasche angelegt")
	check_equal(inv.count_item(&"wolfsfell"), 51, "Überzählige Stapel und falsche Tasche landen in freien Plätzen")
	check_equal(_count_at(inv, 0, 0), 20, "Stapel auf Stapelgröße begrenzt")
	check_equal(inv.count_item(&"brot_hart"), 3, "Gegenstand außerhalb der Tasche umgelegt")
	check_equal(warnings.size(), 2, "Warnungen für unbekannte Tasche und Gegenstand: %s" % [warnings])


func test_speichern_hoechstens_einmal_pro_frame() -> void:
	var inv := _new()
	var c := CharacterData.new()
	var calls := [0]
	var saver := InventorySaver.new(inv, c, func() -> void: calls[0] += 1)
	inv.add_item(&"wolfsfell", 3)
	inv.add_item(&"brot_hart", 2)
	inv.money = 10
	inv.sort()
	check(saver.is_pending(), "Speichern steht aus")
	check_equal(calls[0], 0, "Noch nicht gespeichert (erst am Ende des Frames)")
	saver.flush()
	saver.flush()
	check_equal(calls[0], 1, "Vier Änderungen = einmal gespeichert")
	check_equal(c.money_copper, 10, "Geld im Charakter")
	check(not (c.inventory as Dictionary).is_empty(), "Inventar im Charakter")
	inv.add_item(&"wolfsfell")
	saver.flush()
	check_equal(calls[0], 2, "Nächste Änderung speichert erneut")
