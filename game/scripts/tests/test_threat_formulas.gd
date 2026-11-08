extends TestSuite
## Tests der Bedrohungsformeln (Ticket #35): Zielwechsel erst bei 110 % im
## Nahkampf bzw. 130 % auf Abstand, Spott, Faktoren der Auren, Bedrohung
## durch Schaden und Heilung (aufgeteilt), Anzeige am Zielrahmen.

const MELEE := 110.0
const RANGED := 130.0
const L := ThreatFormulas.Level


func _entry(key: String, threat: float, melee := true) -> Dictionary:
	return {"key": key, "threat": threat, "melee": melee}


func test_schwellen() -> void:
	check_near(ThreatFormulas.switch_factor(true, MELEE, RANGED), 1.1, 0.0001, "Nahkampf 110 %")
	check_near(ThreatFormulas.switch_factor(false, MELEE, RANGED), 1.3, 0.0001, "Abstand 130 %")
	check_near(ThreatFormulas.needed_to_pull(1000.0, true, MELEE, RANGED), 1100.0, 0.001, "1.000 → 1.100 nötig")
	check_near(ThreatFormulas.needed_to_pull(1000.0, false, MELEE, RANGED), 1300.0, 0.001, "1.000 → 1.300 nötig")


func test_erstes_ziel_hoechste_bedrohung() -> void:
	var entries := [_entry("a", 50.0), _entry("b", 80.0), _entry("c", 10.0)]
	check_equal(ThreatFormulas.choose_target(entries, null, MELEE, RANGED), "b", "Ohne Ziel: höchste Bedrohung")
	check_equal(ThreatFormulas.choose_target([], null, MELEE, RANGED), null, "Leere Liste: kein Ziel")
	check_equal(ThreatFormulas.choose_target(entries, "weg", MELEE, RANGED), "b",
			"Bisheriges Ziel nicht mehr auf der Liste: höchste Bedrohung")


func test_zielwechsel_nahkampf_110() -> void:
	var tank := _entry("tank", 1000.0)
	check_equal(ThreatFormulas.choose_target([tank, _entry("dd", 1099.0)], "tank", MELEE, RANGED), "tank",
			"109,9 % im Nahkampf: kein Wechsel")
	check_equal(ThreatFormulas.choose_target([tank, _entry("dd", 1100.0)], "tank", MELEE, RANGED), "dd",
			"110 % im Nahkampf: Wechsel")


func test_zielwechsel_abstand_130() -> void:
	var tank := _entry("tank", 1000.0)
	check_equal(ThreatFormulas.choose_target([tank, _entry("mage", 1250.0, false)], "tank", MELEE, RANGED),
			"tank", "125 % auf Abstand: kein Wechsel")
	check_equal(ThreatFormulas.choose_target([tank, _entry("mage", 1300.0, false)], "tank", MELEE, RANGED),
			"mage", "130 % auf Abstand: Wechsel")


func test_mehrere_ueber_der_schwelle_hoechster_gewinnt() -> void:
	var entries := [_entry("tank", 1000.0), _entry("a", 1200.0), _entry("b", 1500.0, false)]
	check_equal(ThreatFormulas.choose_target(entries, "tank", MELEE, RANGED), "b", "Höchster über der Schwelle")


func test_spott_geht_vor() -> void:
	var entries := [_entry("tank", 10.0), _entry("dd", 5000.0)]
	check_equal(ThreatFormulas.choose_target(entries, "dd", MELEE, RANGED, "tank"), "tank", "Spott zwingt")
	check_equal(ThreatFormulas.choose_target(entries, "dd", MELEE, RANGED, "weg"), "dd",
			"Spottender nicht auf der Liste: normale Regeln")
	check_equal(ThreatFormulas.taunt_threat(10.0, 5000.0), 5000.0, "Spott: höchste Bedrohung übernehmen")
	check_equal(ThreatFormulas.taunt_threat(6000.0, 5000.0), 6000.0, "Spott senkt nie")
	# Nach dem Spott hat der Tank 5.000 wie der Schadensverursacher: kein Rückwechsel.
	var after := [_entry("tank", 5000.0), _entry("dd", 5000.0)]
	check_equal(ThreatFormulas.choose_target(after, "tank", MELEE, RANGED), "tank", "Gleichstand: Ziel bleibt")


func test_faktoren() -> void:
	check_near(ThreatFormulas.modifier_factor(200.0), 3.0, 0.0001, "Tankhaltung +200 % = dreifach")
	check_near(ThreatFormulas.modifier_factor(-50.0), 0.5, 0.0001, "Verborgene Stellung −50 %")
	check_near(ThreatFormulas.modifier_factor(-150.0), 0.0, 0.0001, "Nie unter 0")
	check_near(ThreatFormulas.damage_threat(200.0, 1.0, 3.0), 600.0, 0.001, "200 Schaden × 3")
	check_near(ThreatFormulas.damage_threat(-5.0, 1.0, 1.0), 0.0, 0.001, "Kein negativer Schaden")


func test_heilung_aufgeteilt() -> void:
	check_near(ThreatFormulas.heal_threat_per_enemy(1000.0, 0.5, 1.0, 1), 500.0, 0.001, "Ein Gegner: 0,5 je Heilung")
	check_near(ThreatFormulas.heal_threat_per_enemy(1000.0, 0.5, 1.0, 4), 125.0, 0.001, "Vier Gegner: geteilt")
	check_near(ThreatFormulas.heal_threat_per_enemy(1000.0, 0.5, 0.5, 2), 125.0, 0.001, "Mit Faktor 0,5")
	check_near(ThreatFormulas.heal_threat_per_enemy(1000.0, 0.5, 1.0, 0), 0.0, 0.001, "Ohne Gegner: keine")


func test_anzeige() -> void:
	check_near(ThreatFormulas.display_percent(550.0, 1000.0, false, true, MELEE, RANGED), 50.0, 0.01,
			"550 von 1.100 nötigen = 50 %")
	check_near(ThreatFormulas.display_percent(650.0, 1000.0, false, false, MELEE, RANGED), 50.0, 0.01,
			"Auf Abstand: 650 von 1.300 = 50 %")
	check_equal(ThreatFormulas.display_percent(10.0, 1000.0, true, true, MELEE, RANGED), 100.0,
			"Selbst Ziel: 100 %")
	check_equal(ThreatFormulas.display_level(50.0, false, 80.0), L.SAFE, "Unter 80 %: grün")
	check_equal(ThreatFormulas.display_level(80.0, false, 80.0), L.WARNING, "Ab 80 %: gelb")
	check_equal(ThreatFormulas.display_level(100.0, true, 80.0), L.AGGRO, "Aufmerksamkeit: rot")
