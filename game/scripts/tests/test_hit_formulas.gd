extends TestSuite
## Tests der reinen Formeln (Ticket #34): Trefferwürfel-Verteilung über
## 10.000 Würfe je Angriffsart, Positionsregeln, Verfehlen, Rüstungsminderung
## mit Durchschlag und abnehmendem Ertrag, Krit, Blocken, Mindestschaden,
## Heilung mit Überheilung, Waffenschaden, Abkürzung der Zahlen.

const ROLLS := 10000
## Erlaubte Abweichung der gemessenen Häufigkeit in Prozentpunkten (bei
## 10.000 Würfen ist eine Standardabweichung höchstens 0,5 Punkte).
const TOLERANCE := 2.0

const O := HitFormulas.Outcome
const K := HitFormulas.AttackKind

## Chancen wie aus dem Wertesystem.
var _raw := {O.MISS: 5.0, O.DODGE: 10.0, O.PARRY: 8.0, O.BLOCK: 12.0, O.CRIT: 20.0}


# --- Würfel ------------------------------------------------------------------

func test_verteilung_nahkampf() -> void:
	_check_distribution(K.MELEE, _raw, false,
			{O.MISS: 5.0, O.DODGE: 10.0, O.PARRY: 8.0, O.BLOCK: 12.0, O.CRIT: 20.0, O.HIT: 45.0})


func test_verteilung_fernkampf() -> void:
	_check_distribution(K.RANGED, _raw, false,
			{O.MISS: 5.0, O.DODGE: 10.0, O.PARRY: 0.0, O.BLOCK: 12.0, O.CRIT: 20.0, O.HIT: 53.0})


func test_verteilung_zauber() -> void:
	_check_distribution(K.SPELL, _raw, false,
			{O.MISS: 5.0, O.DODGE: 0.0, O.PARRY: 0.0, O.BLOCK: 0.0, O.CRIT: 20.0, O.HIT: 75.0})


func test_verteilung_heilung() -> void:
	_check_distribution(K.HEAL, _raw, false,
			{O.MISS: 0.0, O.DODGE: 0.0, O.PARRY: 0.0, O.BLOCK: 0.0, O.CRIT: 20.0, O.HIT: 80.0})


func test_verteilung_schaden_ueber_zeit() -> void:
	_check_distribution(K.PERIODIC, _raw, false,
			{O.MISS: 0.0, O.DODGE: 0.0, O.PARRY: 0.0, O.BLOCK: 0.0, O.CRIT: 20.0, O.HIT: 80.0})


func test_von_hinten_kein_parieren_und_blocken() -> void:
	_check_distribution(K.MELEE, _raw, true,
			{O.MISS: 5.0, O.DODGE: 10.0, O.PARRY: 0.0, O.BLOCK: 0.0, O.CRIT: 20.0, O.HIT: 65.0})
	var table := HitFormulas.chance_table(K.RANGED, _raw, true)
	check_equal(table[O.BLOCK], 0.0, "Fernkampf von hinten: kein Blocken")


func test_ohne_waffe_und_schild_kein_parieren_und_blocken() -> void:
	# Das Wertesystem liefert ohne Nahkampfwaffe bzw. Schild 0 – der Würfel
	# darf dann nie „Pariert“ oder „Geblockt“ ergeben.
	var raw := {O.MISS: 5.0, O.DODGE: 10.0, O.PARRY: 0.0, O.BLOCK: 0.0, O.CRIT: 20.0}
	_check_distribution(K.MELEE, raw, false,
			{O.MISS: 5.0, O.DODGE: 10.0, O.PARRY: 0.0, O.BLOCK: 0.0, O.CRIT: 20.0, O.HIT: 65.0})


func test_tabelle_reihenfolge_und_grenzen() -> void:
	# Über 100 %: Was keinen Platz hat, fällt weg, zuerst „Kritisch“.
	var table := HitFormulas.chance_table(K.MELEE,
			{O.MISS: 40.0, O.DODGE: 30.0, O.PARRY: 20.0, O.BLOCK: 20.0, O.CRIT: 50.0}, false)
	check_equal(table[O.BLOCK], 10.0, "Blocken bekommt nur den Rest")
	check_equal(table[O.CRIT], 0.0, "Kritisch fällt weg")
	check_equal(table[O.HIT], 0.0, "Kein normaler Treffer mehr")
	# Grenzen des Wurfs.
	var simple := HitFormulas.chance_table(K.SPELL, {O.MISS: 10.0, O.CRIT: 30.0}, false)
	check_equal(HitFormulas.resolve(K.SPELL, simple, 0.0), O.MISS, "Wurf 0 → Verfehlt")
	check_equal(HitFormulas.resolve(K.SPELL, simple, 9.999), O.MISS, "Wurf knapp unter 10 → Verfehlt")
	check_equal(HitFormulas.resolve(K.SPELL, simple, 10.0), O.CRIT, "Wurf 10 → Kritisch")
	check_equal(HitFormulas.resolve(K.SPELL, simple, 40.0), O.HIT, "Wurf 40 → Treffer")
	check_equal(HitFormulas.resolve(K.SPELL, simple, 99.99), O.HIT, "Wurf 99,99 → Treffer")
	# Negative Chancen zählen als 0.
	var negative := HitFormulas.chance_table(K.SPELL, {O.MISS: -5.0, O.CRIT: 10.0}, false)
	check_equal(negative[O.MISS], 0.0, "Negative Chance → 0")


func test_verfehlen_nach_stufenunterschied() -> void:
	check_equal(HitFormulas.miss_chance(10, 10, 5.0, 2.0, 0.0, 60.0), 5.0, "Gleiche Stufe")
	check_equal(HitFormulas.miss_chance(10, 13, 5.0, 2.0, 0.0, 60.0), 11.0, "Ziel 3 Stufen höher")
	check_equal(HitFormulas.miss_chance(10, 7, 5.0, 2.0, 0.0, 60.0), 0.0, "Ziel 3 Stufen niedriger, Minimum 0")
	check_equal(HitFormulas.miss_chance(1, 60, 5.0, 2.0, 0.0, 60.0), 60.0, "Maximum 60")
	check_equal(HitFormulas.miss_chance(10, 10, 5.0, 2.0, 0.0, 60.0, 19.0), 24.0,
			"Beidhändig: zusätzliche Chance")
	check_equal(HitFormulas.miss_chance(1, 60, 5.0, 2.0, 0.0, 60.0, 50.0), 100.0, "Nie über 100")


# --- Schaden -----------------------------------------------------------------

func test_ruestung_minderung() -> void:
	check_equal(HitFormulas.mitigation_percent(0.0, 0.0, 200.0, 75.0), 0.0, "Ohne Rüstung keine Minderung")
	check_near(HitFormulas.mitigation_percent(200.0, 0.0, 200.0, 75.0), 50.0, 0.001, "Rüstung = K → 50 %")
	check_near(HitFormulas.mitigation_percent(100.0, 0.0, 200.0, 75.0), 100.0 / 3.0, 0.001,
			"Rüstung = K/2 → 33,3 %")
	check_equal(HitFormulas.mitigation_percent(100000.0, 0.0, 200.0, 75.0), 75.0, "Obergrenze 75 %")
	# Durchschlag 50 % halbiert die wirksame Rüstung.
	check_near(HitFormulas.mitigation_percent(400.0, 50.0, 200.0, 75.0),
			HitFormulas.mitigation_percent(200.0, 0.0, 200.0, 75.0), 0.001, "Durchschlag 50 %")
	check_equal(HitFormulas.mitigation_percent(400.0, 100.0, 200.0, 75.0), 0.0, "Durchschlag 100 %")
	# Stufenunterschied: kleineres K (niedriger Angreifer) → mehr Minderung.
	check(HitFormulas.mitigation_percent(200.0, 0.0, 100.0, 75.0)
			> HitFormulas.mitigation_percent(200.0, 0.0, 400.0, 75.0), "Niedriger Angreifer: Rüstung wirkt stärker")


func test_ruestung_abnehmender_ertrag() -> void:
	var previous := 0.0
	var previous_gain := INF
	for step in range(1, 11):
		var value := HitFormulas.mitigation_percent(step * 100.0, 0.0, 200.0, 100.0)
		var gain := value - previous
		check(gain > 0.0, "Mehr Rüstung hilft immer (Schritt %d)" % step)
		check(gain < previous_gain, "Jeder Punkt hilft weniger (Schritt %d)" % step)
		previous = value
		previous_gain = gain


func test_schaden_reihenfolge() -> void:
	# 1000 × 1,2 (Modifikator) × 2 (Krit) × (1 − 25 %) = 1800.
	var result := HitFormulas.damage(1000.0, 1.2, true, 2.0, 25.0, false, 0.0)
	check_equal(result["amount"], 1800.0, "Modifikator, Krit, Minderung")
	check_equal(result["mitigated"], 600.0, "Durch Rüstung abgezogen")
	# Ohne Krit derselbe Weg.
	check_equal(HitFormulas.damage(1000.0, 1.2, false, 2.0, 25.0, false, 0.0)["amount"], 900.0, "Ohne Krit")
	# Blocken zieht nach der Minderung ab: 1000 × (1 − 50 %) − 45 = 455.
	var blocked := HitFormulas.damage(1000.0, 1.0, false, 2.0, 50.0, true, 45.0)
	check_equal(blocked["amount"], 455.0, "Blockwert nach Minderung")
	check_equal(blocked["blocked"], 45.0, "Geblockte Menge")


func test_krit_faktor() -> void:
	check_equal(HitFormulas.crit_factor(200.0), 2.0, "200 % → × 2")
	check_equal(HitFormulas.crit_factor(250.0), 2.5, "Mit Verheerung")
	check_equal(HitFormulas.crit_factor(50.0), 1.0, "Nie unter × 1")
	check_equal(HitFormulas.damage(100.0, 1.0, true, HitFormulas.crit_factor(200.0), 0.0, false, 0.0)["amount"],
			200.0, "Kritischer Treffer verdoppelt")


func test_mindestens_ein_schaden() -> void:
	check_equal(HitFormulas.damage(10.0, 1.0, false, 2.0, 0.0, true, 500.0)["amount"], 1.0,
			"Block größer als Schaden → 1")
	check_equal(HitFormulas.damage(10.0, 1.0, false, 2.0, 0.0, true, 500.0)["blocked"], 10.0,
			"Geblockt höchstens der Schaden")
	check_equal(HitFormulas.damage(0.2, 1.0, false, 2.0, 75.0, false, 0.0)["amount"], 1.0, "Winziger Schaden → 1")
	check_equal(HitFormulas.damage(100.0, 0.0, false, 2.0, 0.0, false, 0.0)["amount"], 1.0, "−100 % → trotzdem 1")


func test_prozent_modifikatoren() -> void:
	check_equal(HitFormulas.percent_factor(0.0), 1.0, "Ohne Modifikator")
	check_near(HitFormulas.percent_factor(30.0), 1.3, 0.0001, "+20 % und +10 % addieren sich")
	check_equal(HitFormulas.percent_factor(-150.0), 0.0, "Nie negativ")


func test_heilung_und_ueberheilung() -> void:
	var normal := HitFormulas.heal(500.0, 1.0, false, 2.0, 1000.0)
	check_equal(normal["amount"], 500.0, "Heilung")
	check_equal(normal["overheal"], 0.0, "Keine Überheilung")
	var crit := HitFormulas.heal(500.0, 1.5, true, 2.0, 1000.0)
	check_equal(crit["amount"], 1500.0, "Erhaltene Heilung +50 % und Krit")
	check_equal(crit["effective"], 1000.0, "Wirksam nur das fehlende Leben")
	check_equal(crit["overheal"], 500.0, "Überheilung erfasst")
	check_equal(HitFormulas.heal(300.0, 1.0, false, 2.0, 0.0)["overheal"], 300.0, "Volles Leben: alles Überheilung")


func test_waffenschaden() -> void:
	check_equal(HitFormulas.weapon_damage(10.0, 20.0, 0.0, 0.0, 14.0, 2.6), 10.0, "Minimum")
	check_equal(HitFormulas.weapon_damage(10.0, 20.0, 1.0, 0.0, 14.0, 2.6), 20.0, "Maximum")
	check_near(HitFormulas.weapon_damage(10.0, 20.0, 0.5, 140.0, 14.0, 2.0), 35.0, 0.0001,
			"Mitte plus Kampfkraft / 14 × Tempo")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 1000:
		var value := HitFormulas.weapon_damage(10.0, 20.0, rng.randf(), 0.0, 14.0, 2.6)
		if value < 10.0 or value > 20.0:
			check(false, "Waffenschaden außerhalb min–max: %s" % value)
			break


func test_zahlen_abkuerzen() -> void:
	check_equal(StatFormat.short_amount(9999.0), "9.999", "Unter der Grenze")
	check_equal(StatFormat.short_amount(10000.0), "10.000", "Genau die Grenze")
	check_equal(StatFormat.short_amount(12345.0), "12,3 Tsd.", "Über 10.000")
	check_equal(StatFormat.short_amount(123456.0), "123 Tsd.", "Ab 100 Tsd. ohne Komma")
	check_equal(StatFormat.short_amount(1234567.0), "1,2 Mio.", "Millionen")


func test_kampflog_text() -> void:
	var result := HitResult.new()
	result.source_name = "Arthas"
	result.target_name = "Übungspuppe"
	result.ability_name = "Feuerball"
	result.school = &"feuer"
	result.outcome = O.CRIT
	result.amount = 1240.0
	check_equal(result.log_text("Feuer"), "Arthas: Feuerball trifft Übungspuppe kritisch: 1.240 Schaden (Feuer)",
			"Kritischer Treffer")
	result.outcome = O.BLOCK
	result.amount = 300.0
	result.blocked = 45.0
	result.absorbed = 20.0
	check_equal(result.log_text("Physisch"),
			"Arthas: Feuerball trifft Übungspuppe: 300 Schaden (Physisch), 45 geblockt, 20 absorbiert", "Geblockt")
	result.outcome = O.DODGE
	check_equal(result.log_text("Physisch"), "Arthas: Feuerball – Übungspuppe weicht aus", "Ausgewichen")
	var heal := HitResult.new()
	heal.source_name = "Arthas"
	heal.target_name = "Heilpuppe"
	heal.ability_name = "Verjüngung"
	heal.flags = HitResult.FLAG_HEAL | HitResult.FLAG_PERIODIC
	heal.amount = 100.0
	heal.overheal = 30.0
	check_equal(heal.log_text(""), "Arthas: Verjüngung (über Zeit) heilt Heilpuppe: 100, 30 Überheilung",
			"Heilung über Zeit mit Überheilung")
	var copy := HitResult.from_array(result.to_array())
	check(copy != null and copy.outcome == result.outcome and copy.blocked == 45.0
			and copy.ability_name == "Feuerball", "Übertragung (to_array/from_array)")


# --- Hilfen ------------------------------------------------------------------

## Würfelt ROLLS-mal mit festem Startwert und vergleicht die Häufigkeiten.
func _check_distribution(kind: HitFormulas.AttackKind, raw: Dictionary, from_behind: bool,
		expected: Dictionary) -> void:
	var table := HitFormulas.chance_table(kind, raw, from_behind)
	var rng := RandomNumberGenerator.new()
	rng.seed = 34 + kind
	var counts := {}
	for i in ROLLS:
		var outcome := HitFormulas.roll(kind, table, rng)
		counts[outcome] = int(counts.get(outcome, 0)) + 1
	for outcome: int in expected:
		var percent := 100.0 * float(counts.get(outcome, 0)) / ROLLS
		var name: String = HitFormulas.OUTCOME_NAMES[outcome]
		if float(expected[outcome]) == 0.0:
			check_equal(int(counts.get(outcome, 0)), 0, "%s darf bei dieser Angriffsart nie vorkommen" % name)
		else:
			check_near(percent, float(expected[outcome]), TOLERANCE, "Häufigkeit %s in %d Würfen" % [name, ROLLS])
