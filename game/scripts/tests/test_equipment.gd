extends TestSuite
## Tests der Ausrüstung (Ticket #29): Regeln (EquipmentRules) mit den echten
## Daten, die Datenprüfung, Inventar („Einzigartig“, Tausch), eine echte
## Spielfigur mit PlayerEquipment (ohne Netzwerk ist die eigene Instanz der
## Host): Anlegen und Ablegen mit Tasche, Werte, Auren, Waffen im Kampf,
## Kampf und globaler Cooldown, Speichern und Beitreten, Tooltip und
## Anzeige in Tasche und Charakterfenster.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ITEM_SLOT_SCENE := preload("res://scenes/ui/hud/item_slot.tscn")
const EQUIPMENT_SLOT_SCENE := preload("res://scenes/ui/hud/equipment_slot.tscn")

var _root: Node3D = null
var _warrior: PlayerCharacter = null
var _rogue: PlayerCharacter = null
var _inv: Inventory = null


func before_all() -> void:
	_root = Node3D.new()
	_root.name = "EquipmentTest"
	tree.root.add_child(_root)
	_warrior = _spawn_player("1", &"warrior", Vector3.ZERO)
	_rogue = _spawn_player("2", &"rogue", Vector3(3.0, 0.0, 0.0))


func after_all() -> void:
	if _root != null:
		_root.free()


func _spawn_player(node_name: String, class_id: StringName, position: Vector3) -> PlayerCharacter:
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	player.name = node_name
	player.display_name = "Spieler" + node_name
	player.race_id = &"human"
	player.class_id = class_id
	player.position = position
	_root.add_child(player)
	return player


## Leere Ausrüstung, frisches Inventar, Stufe 1, außerhalb des Kampfes.
func _reset(player: PlayerCharacter = _warrior, level := 1) -> PlayerEquipment:
	var equipment := player.get_equipment()
	player.get_stats().set_in_combat(false)
	player.get_stats().set_level_override(level)
	player.get_stats().refill()
	equipment.host_load({})
	player.get_caster_node().request_reset_cooldowns()
	_inv = Inventory.new(16)
	equipment.attach_inventory(_inv)
	return equipment


func _add(id: StringName) -> Vector2i:
	check_equal(_inv.add_item(id), Inventory.AddResult.ADDED, "%s ins Inventar" % id)
	return _inv.find_item(id)


func _equip(equipment: PlayerEquipment, id: StringName, place: StringName = &"") -> void:
	var at := _inv.find_item(id)
	if at.x < 0:
		at = _add(id)
	equipment.request_equip_from_bag(at.x, at.y, place)


# --- Daten -------------------------------------------------------------------

func test_daten_gueltig_ohne_warnungen() -> void:
	check(Data.is_valid(), "Tabellen gültig")
	check(Data.get_warnings().is_empty(), "Keine Warnungen (Rüstung und Waffenschaden stehen in den Zeilen)")
	for class_data in GameData.get_classes():
		check(Data.klassenausruestung(class_data.id) != null, "Klasse %s hat Ausrüstungsregeln" % class_data.id)
	for id: StringName in [&"eisen_helm", &"stahl_helm", &"leinen_brust", &"seide_brust", &"wildleder_beine",
			&"schattenleder_beine", &"schild_holz", &"schild_eisen", &"fokus_kristall", &"ring_kupfer",
			&"ring_wachsamkeit", &"kette_perlen", &"siegel_glut", &"talisman_wolfszahn", &"talisman_banditenmuenze",
			&"talisman_eberhauer", &"klinge_veteran", &"stab_runen"]:
		check(ItemInfo.exists(id), "Testgegenstand %s vorhanden" % id)
	for row in Data.rows("waffentypen"):
		var found := false
		for item in Data.gegenstaende():
			if str(item.get_value("waffentyp", "")) == row.id():
				found = true
		check(found, "Testgegenstand für Waffentyp %s" % row.id())


func test_slotzuordnung_und_handhabung() -> void:
	check_equal(EquipmentRules.places_for(&"ring_kupfer"), [&"ring_1", &"ring_2"] as Array[StringName], "Ring: zwei Plätze")
	check_equal(EquipmentRules.places_for(&"schwert_eisen"), [&"haupthand", &"nebenhand"] as Array[StringName],
			"Einhand: Haupt- und Nebenhand")
	check_equal(EquipmentRules.places_for(&"schwert_kriegs"), [&"haupthand"] as Array[StringName], "Haupthand-Waffe")
	check_equal(EquipmentRules.places_for(&"dolch_parier"), [&"nebenhand"] as Array[StringName], "Nebenhand-Waffe")
	check_equal(EquipmentRules.places_for(&"zauberstab_glut"), [&"fernkampf"] as Array[StringName], "Zauberstab: Fernkampf")
	check(EquipmentRules.occupies_both_hands(&"zweihandaxt_eisen"), "Zweihand belegt beide Hände")
	check(EquipmentRules.places_for(&"wolfsfell").is_empty(), "Material passt nirgends")
	check_equal(ItemInfo.slot_text(&"eisen_brust"), "Brust", "Tooltip links: Brust")
	check_equal(ItemInfo.kind_text(&"eisen_brust"), "Platte", "Tooltip rechts: Platte")
	check_equal(ItemInfo.kind_text(&"schwert_eisen"), "Schwert", "Tooltip rechts: Schwert")
	check(EquipmentRules.is_weapon_place(&"haupthand") and not EquipmentRules.is_weapon_place(&"helm"),
			"Nur Waffenplätze im Kampf wechselbar")


# --- Regeln ------------------------------------------------------------------

func test_klasse_ruestung_und_waffen() -> void:
	check_equal(EquipmentRules.class_reason(&"eisen_helm", &"mage"), EquipmentRules.MSG_CLASS, "Magier: keine Platte")
	check_equal(EquipmentRules.class_reason(&"eisen_helm", &"warrior"), "", "Krieger: Platte")
	check_equal(EquipmentRules.class_reason(&"wildleder_helm", &"warrior"), "", "Krieger: Leder (leichter)")
	check_equal(EquipmentRules.class_reason(&"leinen_helm", &"rogue"), "", "Schurke: Stoff (leichter)")
	check_equal(EquipmentRules.class_reason(&"eisen_helm", &"monk"), EquipmentRules.MSG_CLASS, "Mönch: keine Platte")
	check_equal(EquipmentRules.class_reason(&"zauberstab_glut", &"mage"), "", "Magier: Zauberstab")
	check_equal(EquipmentRules.class_reason(&"zauberstab_glut", &"warrior"), EquipmentRules.MSG_CLASS, "Krieger: kein Zauberstab")
	check_equal(EquipmentRules.class_reason(&"schild_holz", &"warrior"), "", "Krieger: Schild")
	check_equal(EquipmentRules.class_reason(&"schild_holz", &"rogue"), EquipmentRules.MSG_CLASS, "Schurke: kein Schild")
	check_equal(EquipmentRules.class_reason(&"fokus_kristall", &"mage"), "", "Magier: Fokus")
	for class_id: StringName in [&"warrior", &"rogue", &"monk", &"mage", &"druid"]:
		for bow: StringName in [&"bogen_jagd", &"langbogen_eibe", &"kurzbogen_esche", &"armbrust_leicht"]:
			check_equal(EquipmentRules.class_reason(bow, class_id), EquipmentRules.MSG_CLASS,
					"%s darf %s nicht tragen (kein Jäger)" % [class_id, bow])
	check_equal(EquipmentRules.class_reason(&"stab_runen", &"warrior"), EquipmentRules.MSG_CLASS,
			"Klasseneinschränkung: nur Magier")
	check_equal(EquipmentRules.class_reason(&"stab_runen", &"mage"), "", "Magier darf den Runenstab")
	check(EquipmentRules.can_dual_wield(&"rogue") and EquipmentRules.can_dual_wield(&"monk"), "Schurke und Mönch beidhändig")
	check(not EquipmentRules.can_dual_wield(&"warrior"), "Krieger nicht beidhändig (GDD)")


func test_mindeststufe() -> void:
	var r := EquipmentRules.check_equip(&"klinge_veteran", &"haupthand", {}, &"warrior", 1)
	check(not bool(r["ok"]), "Stufe 1: Klinge des Veteranen nicht")
	check_equal(r["reason"], "Benötigt Stufe 25.", "Grund nennt die Stufe")
	check(bool(EquipmentRules.check_equip(&"klinge_veteran", &"haupthand", {}, &"warrior", 25)["ok"]), "Stufe 25: geht")
	check_equal(EquipmentRules.usable_reason(&"klinge_veteran", &"warrior", 10), "Benötigt Stufe 25.", "Nicht nutzbar")


func test_zweihand_und_nebenhand() -> void:
	var state := {"haupthand": "schwert_eisen", "nebenhand": "schild_holz"}
	var r := EquipmentRules.check_equip(&"zweihandschwert_eisen", &"haupthand", state, &"warrior", 5)
	check(bool(r["ok"]), "Zweihand anlegen")
	check_equal(r["displaced"], {"haupthand": "schwert_eisen", "nebenhand": "schild_holz"}, "verdrängt beide Hände")
	check_equal(r["state"], {"haupthand": "zweihandschwert_eisen"}, "nur die Haupthand belegt")
	r = EquipmentRules.check_equip(&"schild_holz", &"nebenhand", {"haupthand": "zweihandschwert_eisen"}, &"warrior", 5)
	check(bool(r["ok"]), "Schild trotz Zweihand anlegen")
	check_equal(r["displaced"], {"haupthand": "zweihandschwert_eisen"}, "Schild verdrängt die Zweihandwaffe")


func test_beidhaendigkeit() -> void:
	var state := {"haupthand": "schwert_eisen"}
	var r := EquipmentRules.check_equip(&"dolch_eisen", &"nebenhand", state, &"warrior", 5)
	check_equal(r["reason"], EquipmentRules.MSG_DUAL_WIELD, "Krieger: keine zweite Waffe")
	check(bool(EquipmentRules.check_equip(&"dolch_eisen", &"nebenhand", state, &"rogue", 5)["ok"]),
			"Schurke: zweite Waffe")
	check_equal(EquipmentRules.choose_place(&"dolch_eisen", state, &"warrior"), &"haupthand",
			"Rechtsklick Krieger: Haupthand (ersetzt)")
	check_equal(EquipmentRules.choose_place(&"dolch_eisen", state, &"rogue"), &"nebenhand",
			"Rechtsklick Schurke: freie Nebenhand")
	check_equal(EquipmentRules.usable_reason(&"dolch_parier", &"warrior", 5), EquipmentRules.MSG_DUAL_WIELD,
			"Nebenhand-Waffe ohne Beidhändigkeit nicht nutzbar")
	check_equal(EquipmentRules.usable_reason(&"dolch_parier", &"rogue", 5), "", "Schurke: Nebenhand-Waffe")
	check_equal(EquipmentRules.weapon_flags({"haupthand": "schwert_eisen", "nebenhand": "dolch_eisen"}),
			{"melee": true, "shield": false, "offhand": true, "ranged": false}, "Zustände bei zwei Waffen")


func test_ringe_talismane_einzigartig() -> void:
	var state := {"ring_1": "ring_kupfer"}
	check_equal(EquipmentRules.choose_place(&"ring_kupfer", state, &"warrior"), &"ring_2", "Rechtsklick: freier Ring")
	check(bool(EquipmentRules.check_equip(&"ring_kupfer", &"ring_2", state, &"warrior", 5)["ok"]),
			"Gleicher Ring zweimal, wenn nicht einzigartig angelegt")
	state = {"ring_1": "ring_wachsamkeit"}
	check_equal(EquipmentRules.check_equip(&"ring_wachsamkeit", &"ring_2", state, &"warrior", 5)["reason"],
			EquipmentRules.MSG_UNIQUE_EQUIPPED, "Einzigartig angelegt: nicht zweimal")
	check(bool(EquipmentRules.check_equip(&"ring_wachsamkeit", &"ring_1", state, &"warrior", 5)["ok"]),
			"Auf denselben Platz geht (ersetzt sich selbst)")
	state = {"talisman_1": "talisman_wolfszahn", "talisman_2": "talisman_banditenmuenze"}
	check_equal(EquipmentRules.choose_place(&"talisman_eberhauer", state, &"warrior"), &"talisman_3",
			"Dritter Talisman: freier Platz")
	check(bool(EquipmentRules.check_equip(&"talisman_eberhauer", &"talisman_3", state, &"warrior", 5)["ok"]),
			"Drei verschiedene Talismane")
	check_equal(EquipmentRules.check_equip(&"talisman_wolfszahn", &"talisman_3", state, &"warrior", 5)["reason"],
			EquipmentRules.MSG_UNIQUE_EQUIPPED, "Talisman immer einzigartig angelegt")
	check(ItemInfo.is_unique_equipped(&"siegel_glut"), "Siegel einzigartig angelegt")
	check(not ItemInfo.is_unique_equipped(&"ring_kupfer"), "Kupferring nicht")
	check_equal(EquipmentRules.choose_place(&"ring_kupfer", {"ring_1": "a", "ring_2": "b"}, &"warrior"), &"ring_1",
			"Alle belegt: der erste")


func test_kampfregeln() -> void:
	var state := {"haupthand": "schwert_eisen", "helm": "eisen_helm"}
	check_equal(EquipmentRules.check_equip(&"stahl_helm", &"helm", state, &"warrior", 15, true)["reason"],
			EquipmentRules.MSG_COMBAT, "Rüstung im Kampf gesperrt")
	check_equal(EquipmentRules.check_equip(&"axt_eisen", &"haupthand", state, &"warrior", 15, true, true)["reason"],
			EquipmentRules.MSG_NOT_READY, "Waffe im Kampf bei laufendem GCD: noch nicht bereit")
	check(bool(EquipmentRules.check_equip(&"axt_eisen", &"haupthand", state, &"warrior", 15, true)["ok"]),
			"Waffenwechsel im Kampf")
	check_equal(EquipmentRules.check_unequip(&"helm", state, true)["reason"], EquipmentRules.MSG_COMBAT,
			"Helm im Kampf nicht ablegen")
	check(bool(EquipmentRules.check_unequip(&"haupthand", state, true)["ok"]), "Waffe im Kampf ablegen")


func test_bereinigen_beim_beitreten() -> void:
	var data := {"helm": "eisen_helm", "brust": "leinen_brust", "haupthand": "zweihandaxt_eisen",
			"nebenhand": "schild_holz", "ring_1": "gibt_es_nicht", "ring_2": "eisen_helm", "kein_platz": "ring_kupfer",
			"talisman_1": "talisman_wolfszahn", "talisman_2": "talisman_wolfszahn", "beine": "stahl_beine"}
	var result := EquipmentRules.sanitize(data, &"warrior", 5)
	check_equal(result["state"], {"helm": "eisen_helm", "brust": "leinen_brust", "haupthand": "zweihandaxt_eisen",
			"talisman_1": "talisman_wolfszahn"}, "Nur gültige Einträge bleiben")
	check_equal((result["removed"] as Array).size(), 6, "Sechs Einträge verworfen")
	result = EquipmentRules.sanitize({"helm": "eisen_helm"}, &"mage", 30)
	check((result["state"] as Dictionary).is_empty(), "Magier verliert den Plattenhelm")
	check_equal(EquipmentRules.average_item_level({"helm": "eisen_helm", "brust": "stahl_brust",
			"haupthand": "zweihandaxt_eisen"}), 25.0 / 3.0, "Durchschnitt der Gegenstandsstufe")
	check_equal(EquipmentRules.average_item_level({}), 0.0, "Ohne Ausrüstung 0")


# --- Inventar ----------------------------------------------------------------

func test_inventar_einzigartig_und_tausch() -> void:
	var inv := Inventory.new(4)
	check_equal(inv.add_item(&"talisman_eberhauer"), Inventory.AddResult.ADDED, "Einzigartig: einmal")
	check_equal(inv.add_item(&"talisman_eberhauer"), Inventory.AddResult.UNIQUE, "Einzigartig: kein zweites Mal")
	check_equal(inv.count_item(&"talisman_eberhauer"), 1, "Nur einer im Inventar")
	inv.clear()
	inv.owned_elsewhere = func(id: StringName) -> int: return 1 if id == &"talisman_eberhauer" else 0
	check_equal(inv.add_item(&"talisman_eberhauer"), Inventory.AddResult.UNIQUE, "Angelegt zählt mit")
	check_equal(inv.add_item(&"talisman_eberhauer", 1, false), Inventory.AddResult.ADDED, "Ablegen prüft nicht")
	inv.clear()
	inv.add_item(&"zweihandaxt_eisen")
	inv.add_item(&"wolfsfell")
	inv.add_item(&"wolfsfell", 20)
	inv.add_item(&"brot_hart", 20)
	check_equal(inv.get_free_slots(), 0, "Voll")
	check_equal(inv.replace_item(0, 0, &"zweihandaxt_eisen", [&"schwert_eisen", &"schild_holz"] as Array[StringName]),
			Inventory.MSG_FULL, "Zwei verdrängte passen nicht in einen Platz")
	check_equal(inv.get_slot(0, 0).get("id"), &"zweihandaxt_eisen", "Nichts geändert")
	check_equal(inv.replace_item(0, 0, &"zweihandaxt_eisen", [&"schwert_eisen"] as Array[StringName]), "", "Tausch")
	check_equal(inv.get_slot(0, 0).get("id"), &"schwert_eisen", "Verdrängter liegt auf dem frei gewordenen Platz")


# --- Spielfigur --------------------------------------------------------------

func test_anlegen_ablegen_mit_werten() -> void:
	var equipment := _reset(_warrior, 5)
	var stats := _warrior.get_stats()
	var armor := stats.get_value(&"armor")
	var strength := stats.get_value(&"strength")
	_equip(equipment, &"eisen_brust")
	check_equal(equipment.get_item(&"brust"), &"eisen_brust", "Brust angelegt")
	check_equal(_inv.count_item(&"eisen_brust"), 0, "Nicht mehr in der Tasche")
	check_near(stats.get_value(&"armor"), armor + ItemInfo.number(&"eisen_brust", "ruestung"), 0.01, "Rüstung steigt")
	check_near(stats.get_value(&"strength"), strength + ItemInfo.number(&"eisen_brust", "staerke"), 0.01, "Stärke steigt")
	var sources: PackedStringArray = []
	for m in stats.block.get_modifiers(&"armor"):
		sources.append(String(m.source))
	check(sources.has("item:eisen_brust:brust"), "Quelle item:ID:PLATZ")
	_equip(equipment, &"stahl_brust")
	check_equal(equipment.get_item(&"brust"), &"eisen_brust", "Stufe 15 bei Stufe 5 abgelehnt")
	check_equal(_inv.count_item(&"stahl_brust"), 1, "Bleibt in der Tasche")
	var at := _inv.find_item(&"stahl_brust")
	_warrior.get_stats().set_level_override(15)
	_equip(equipment, &"stahl_brust")
	check_equal(equipment.get_item(&"brust"), &"stahl_brust", "Ersetzt")
	check_equal(_inv.get_slot(at.x, at.y).get("id"), &"eisen_brust", "Alter liegt auf dem Platz des neuen")
	equipment.request_unequip(&"brust")
	check(not equipment.has_item(&"brust"), "Abgelegt")
	check_equal(_inv.count_item(&"stahl_brust"), 1, "Zurück in der Tasche")
	check_near(stats.get_value(&"armor"), armor, 0.01, "Rüstung wieder wie vorher")
	# Mindeststufe nur beim Anlegen: Stufe sinkt, Gegenstand bleibt.
	_equip(equipment, &"stahl_brust")
	_warrior.get_stats().set_level_override(1)
	check_equal(equipment.get_item(&"brust"), &"stahl_brust", "Stufe gesunken: bleibt angelegt")
	check(stats.get_value(&"armor") > armor, "und wirkt weiter")


func test_zweihand_mit_tasche() -> void:
	var equipment := _reset()
	_equip(equipment, &"schwert_eisen")
	_equip(equipment, &"schild_holz")
	check(_warrior.get_stats().has_flag(StatBlock.FLAG_SHIELD), "Schild-Zustand aus der Ausrüstung")
	check(_warrior.get_stats().has_flag(StatBlock.FLAG_MELEE_WEAPON), "Nahkampfwaffe aus der Ausrüstung")
	_equip(equipment, &"zweihandschwert_eisen")
	check_equal(equipment.get_item(&"haupthand"), &"zweihandschwert_eisen", "Zweihand in der Haupthand")
	check(not equipment.has_item(&"nebenhand") and equipment.is_off_hand_blocked(), "Nebenhand leer und belegt")
	check_equal(_inv.count_item(&"schwert_eisen") + _inv.count_item(&"schild_holz"), 2, "Beide in der Tasche")
	check(not _warrior.get_stats().has_flag(StatBlock.FLAG_SHIELD), "Kein Schild mehr")
	# Tasche voll: Schild anlegen verdrängt die Zweihandwaffe, die passt auf den Platz des Schilds.
	while _inv.get_free_slots() > 0:
		_inv.add_item(&"brot_hart", 20)
	_equip(equipment, &"schild_holz")
	check_equal(equipment.get_item(&"nebenhand"), &"schild_holz", "Schild trotz voller Tasche (Tausch)")
	check_equal(_inv.count_item(&"zweihandschwert_eisen"), 1, "Zweihand in der Tasche")
	_equip(equipment, &"schwert_eisen")
	while _inv.get_free_slots() > 0:
		_inv.add_item(&"brot_hart", 20)
	var failed: Array[String] = []
	equipment.request_failed.connect(func(reason: String) -> void: failed.append(reason), CONNECT_ONE_SHOT)
	_equip(equipment, &"zweihandschwert_eisen")
	check_equal(failed, [Inventory.MSG_FULL] as Array[String], "Zwei verdrängte, Tasche voll: Abbruch mit Meldung")
	check_equal(equipment.get_item(&"haupthand"), &"schwert_eisen", "Nichts geändert")


func test_waffen_im_kampf_und_reihen() -> void:
	var equipment := _reset()
	check_equal(str(Combat.weapon_row(_warrior).get_value("name")), "Fäuste", "Ohne Waffe unbewaffnet")
	_equip(equipment, &"axt_eisen")
	var row := Combat.weapon_row(_warrior)
	check_near(float(row.get_value("tempo")), 2.6, 0.001, "Tempo der Axt")
	check_equal(float(row.get_value("schaden_min")), float(ItemInfo.number(&"axt_eisen", "schaden_min")), "Schaden der Axt")
	_equip(equipment, &"armbrust_leicht")
	check(not equipment.has_item(&"fernkampf"), "Krieger: keine Armbrust")
	var caster := _warrior.get_caster_node()
	_warrior.get_stats().set_in_combat(true)
	var failed: Array[String] = []
	var collect := func(reason: String) -> void: failed.append(reason)
	equipment.request_failed.connect(collect)
	_equip(equipment, &"eisen_helm")
	check_equal(failed.back() if not failed.is_empty() else "", EquipmentRules.MSG_COMBAT, "Helm im Kampf: Meldung")
	_equip(equipment, &"schwert_eisen")
	check_equal(equipment.get_item(&"haupthand"), &"schwert_eisen", "Waffenwechsel im Kampf")
	check(caster.get_gcd().x > 0.0, "Wechsel startet den globalen Cooldown")
	_equip(equipment, &"axt_eisen")
	check_equal(failed.back(), EquipmentRules.MSG_NOT_READY, "Während des GCD: noch nicht bereit")
	equipment.request_failed.disconnect(collect)
	_warrior.get_stats().set_in_combat(false)
	caster.request_reset_cooldowns()
	# Schurke: Nebenhand aus der Ausrüstung.
	var rogue_eq := _rogue.get_equipment()
	_rogue.get_stats().set_in_combat(false)
	rogue_eq.host_load({"haupthand": "schwert_eisen", "nebenhand": "dolch_eisen"})
	check(_rogue.get_stats().has_flag(StatBlock.FLAG_OFFHAND_WEAPON), "Schurke: Nebenhandwaffe")
	check_equal(str(Combat.offhand_row(_rogue).get_value("name")), "Eisendolch", "Nebenhand aus dem Gegenstand")
	rogue_eq.host_load({})
	check_equal(str(Combat.offhand_row(_rogue).get_value("name")), "Platzhalter-Dolch", "Ohne: Platzhalter")


func test_zauberstab_schiesst() -> void:
	var mage := _spawn_player("3", &"mage", Vector3(6.0, 0.0, 0.0))
	var equipment := mage.get_equipment()
	equipment.host_load({"fernkampf": "zauberstab_glut"})
	check(mage.get_stats().has_flag(StatBlock.FLAG_RANGED_WEAPON), "Zauberstab setzt die Fernkampfwaffe")
	var row := Combat.weapon_row(mage, true)
	check_equal(str(row.get_value("name")), "Glutzauberstab", "Schuss mit dem Zauberstab")
	check_near(float(row.get_value("reichweite")), 30.0, 0.01, "Reichweite aus waffentypen.csv")
	mage.free()


func test_auren_der_gegenstaende() -> void:
	var equipment := _reset()
	var combat := _warrior.get_combat()
	var crit := _warrior.get_stats().get_value(&"crit_chance")
	_equip(equipment, &"talisman_wolfszahn")
	check(_has_aura(combat, &"item_talisman_wolfszahn"), "Talisman-Aura aktiv")
	check_near(_warrior.get_stats().get_value(&"crit_chance"), crit + 2.0, 0.01, "+2 % kritische Trefferchance")
	_equip(equipment, &"siegel_glut")
	check(_has_aura(combat, &"item_siegel_glut"), "Siegel-Aura (Auslöser) aktiv")
	equipment.request_unequip(&"talisman_1")
	check(not _has_aura(combat, &"item_talisman_wolfszahn"), "Aura beim Ablegen entfernt")
	check(_has_aura(combat, &"item_siegel_glut"), "Andere Aura bleibt")
	check_near(_warrior.get_stats().get_value(&"crit_chance"), crit, 0.01, "Wert wieder wie vorher")
	equipment.host_load({})
	check(not _has_aura(combat, &"item_siegel_glut"), "Leerer Stand entfernt alle Auren")


func _has_aura(combat: UnitCombat, aura_id: StringName) -> bool:
	for inst in combat.get_auras():
		if inst.data.id == aura_id:
			return true
	return false


func test_einzigartig_mit_ausruestung() -> void:
	var equipment := _reset()
	_equip(equipment, &"talisman_eberhauer")
	check_equal(equipment.get_item(&"talisman_1"), &"talisman_eberhauer", "Angelegt")
	check_equal(_inv.add_item(&"talisman_eberhauer"), Inventory.AddResult.UNIQUE, "Angelegt zählt als Besitz")
	equipment.request_unequip(&"talisman_1")
	check_equal(_inv.count_item(&"talisman_eberhauer"), 1, "Ablegen geht trotz Einzigartig")


func test_tod_sperrt() -> void:
	var equipment := _reset()
	_add(&"eisen_helm")
	var result := equipment.host_request("equip", &"eisen_helm", &"helm")
	check(bool(result["ok"]), "Lebend: geht")
	_warrior.get_stats().set_health(0.0)
	result = equipment.host_request("unequip", &"", &"helm")
	check_equal(result["reason"], EquipmentRules.MSG_DEAD, "Tot: nichts ausrüsten")
	_warrior.get_stats().refill()


# --- Speichern und Netzwerk --------------------------------------------------

func test_speichern_und_beitreten() -> void:
	var c := CharacterData.new()
	c.character_name = "Test"
	c.class_id = &"warrior"
	c.race_id = &"human"
	c.equipment = {"helm": "eisen_helm", "haupthand": "schwert_eisen"}
	var copy := CharacterData.from_dict(c.to_dict())
	check_equal(copy.equipment, c.equipment, "Ausrüstung über to_dict/from_dict")
	var info := NetPlayerInfo.from_character(2, c)
	check_equal(NetPlayerInfo.from_dict(info.to_dict()).equipment, c.equipment, "Ausrüstung in der Spielerliste")
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	player.name = "4"
	player.setup_from_info(info)
	_root.add_child(player)
	check_equal(player.get_equipment().equipment_state, c.equipment, "Host übernimmt den mitgebrachten Stand")
	check(player.get_stats().has_flag(StatBlock.FLAG_MELEE_WEAPON), "Und wendet ihn an")
	player.free()


# --- Anzeige -----------------------------------------------------------------

func test_tooltip() -> void:
	var equipment := _reset(_warrior, 5)
	var text := ItemTooltip.text(&"eisen_brust", 0, equipment)
	for part in ["Eisenbrustplatte", "Ungewöhnlich", "Wird beim Anlegen gebunden", "Brust  Platte", "Rüstung",
			"Stärke", "Gegenstandsstufe 5"]:
		check(text.contains(part), "Tooltip enthält „%s“" % part)
	text = ItemTooltip.text(&"schwert_eisen", 0, equipment)
	check(text.contains("Schaden") and text.contains("Tempo 2,6") and text.contains("Schaden pro Sekunde"),
			"Waffenschaden, Tempo und Schaden pro Sekunde")
	text = ItemTooltip.text(&"ring_wachsamkeit", 0, equipment)
	check(text.contains("Einzigartig angelegt") and text.contains("Anlegen: +3 Präzision"), "Wertung grün mit „Anlegen:“")
	text = ItemTooltip.text(&"talisman_wolfszahn", 0, equipment)
	check(text.contains("Anlegen: +2 % kritische Trefferchance") and text.contains("Rudelführers, der"),
			"Effekt und Herkunft")
	var entries := ItemTooltip.entries(&"klinge_veteran", 0, equipment)
	var level_entry := {}
	for entry in entries:
		if str(entry["text"]) == "Benötigt Stufe 25":
			level_entry = entry
	check_equal(level_entry.get("color"), ItemTooltip.COLOR_MISSING, "Benötigt Stufe 25 in Rot")
	text = ItemTooltip.text(&"stab_runen", 0, equipment)
	check(text.contains("Klassen: Magier"), "Klasseneinschränkung")
	_equip(equipment, &"eisen_helm")
	text = ItemTooltip.text(&"wildleder_helm", 0, equipment, true)
	check(text.contains("Beim Anlegen:"), "Vergleich mit dem angelegten Helm")
	var diff := ItemInfo.number(&"wildleder_helm", "ruestung") - ItemInfo.number(&"eisen_helm", "ruestung")
	check(text.contains("%s%d Rüstung" % [StatFormat.MINUS, absi(diff)]), "Weniger Rüstung mit Minus")
	check(text.contains("+3 Gewandtheit"), "Mehr Gewandtheit mit Plus")
	var box := ItemTooltip.create(&"wildleder_helm", 0, equipment, true)
	check(box is HBoxContainer and box.get_child_count() == 2, "Daneben der angelegte Gegenstand")
	box.free()


func test_tasche_und_charakterfenster() -> void:
	var equipment := _reset(_rogue)
	var holder := Control.new()
	_root.add_child(holder)
	_inv.add_item(&"eisen_helm")
	_inv.add_item(&"wildleder_helm")
	var blocked: ItemSlot = ITEM_SLOT_SCENE.instantiate()
	holder.add_child(blocked)
	blocked.equipment = equipment
	blocked.setup(_inv, 0, 0)
	check((blocked.get_node(^"%Unusable") as Panel).visible, "Platte beim Schurken: roter Schleier")
	var fine: ItemSlot = ITEM_SLOT_SCENE.instantiate()
	holder.add_child(fine)
	fine.equipment = equipment
	fine.setup(_inv, 0, 1)
	check(not (fine.get_node(^"%Unusable") as Panel).visible, "Leder beim Schurken: ohne Schleier")
	equipment.host_load({"helm": "wildleder_helm"})
	var slot: EquipmentSlot = EQUIPMENT_SLOT_SCENE.instantiate()
	holder.add_child(slot)
	slot.set_equipment(equipment)
	slot.setup(&"helm")
	check_equal(slot.get_item_id(), &"wildleder_helm", "Platz zeigt den Gegenstand")
	check(slot.icon != null, "mit Icon (leather_cap)")
	check((slot.get_node(^"%RarityFrame") as Panel).visible, "und Seltenheitsrahmen")
	var off: EquipmentSlot = EQUIPMENT_SLOT_SCENE.instantiate()
	holder.add_child(off)
	off.set_equipment(equipment)
	off.setup(&"nebenhand")
	check(off.tooltip_text.contains("(leer)"), "Leerer Platz")
	var warrior_eq := _warrior.get_equipment()
	warrior_eq.host_load({"haupthand": "kampfstab_eiche"})
	off.set_equipment(warrior_eq)
	check(off.disabled and off.tooltip_text.contains("Zweihandwaffe"), "Zweihand: Nebenhand belegt")
	holder.free()
	equipment.host_load({})
	warrior_eq.host_load({})
