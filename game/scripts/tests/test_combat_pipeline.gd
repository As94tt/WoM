extends TestSuite
## Tests der Trefferberechnung mit echten Einheiten (Ticket #34): zwei bzw.
## drei Übungspuppen im Baum (ohne Netzwerk ist die eigene Instanz der Host).
## Prüft, dass Combat die Werte aus Wertesystem und Tabellen richtig in die
## Formeln gibt: Immunität, Positionsregeln, Rüstung, Blocken, Mindestschaden,
## vollständige Absorption, Modifikatoren aus Auren, Heilung mit Überheilung.

const DUMMY_SCENE := preload("res://scenes/units/training_dummy.tscn")
const O := HitFormulas.Outcome
const K := HitFormulas.AttackKind

var _root: Node3D = null
## Angreifer (Schadenspuppe Stufe 1, kritische Trefferchance 5 %).
var _attacker: TrainingDummy = null
## Ziel mit Rüstung, Abwehrwerten und Immunität gegen Feuer (Bosspuppe).
var _boss: TrainingDummy = null
## Ziel ohne Abwehrwerte (Schadenspuppe Stufe 1).
var _plain: TrainingDummy = null
var _healer_target: TrainingDummy = null


func before_all() -> void:
	_root = Node3D.new()
	_root.name = "CombatTest"
	tree.root.add_child(_root)
	# Bosspuppe im Ursprung, Blick nach −Z. Vor ihr steht man bei −Z.
	_boss = _spawn(&"bosspuppe", Vector3.ZERO)
	_attacker = _spawn(&"schadenspuppe_1", Vector3(0.0, 0.0, -3.0))
	_plain = _spawn(&"schadenspuppe_1", Vector3(10.0, 0.0, 0.0))
	_healer_target = _spawn(&"heilpuppe", Vector3(-10.0, 0.0, 0.0))


func after_all() -> void:
	if _root != null:
		_root.free()


func test_host_ohne_sitzung() -> void:
	check(Network.is_host(), "Ohne Sitzung ist die eigene Instanz der Host")


func test_werte_aus_tabelle() -> void:
	var stats := _boss.get_stats()
	check_equal(stats.get_value(&"armor"), 400.0, "Rüstung der Bosspuppe aus uebungspuppen.csv")
	check_equal(stats.get_value(&"parry"), 10.0, "Parieren aus uebungspuppen.csv")
	check_equal(stats.get_value(&"block_value"), 50.0, "Blockwert aus uebungspuppen.csv")
	check_equal(_plain.get_stats().get_value(&"dodge"), Data.konstante(&"ausweichen_grund"),
			"Leere Zelle: Ausweichen aus dem Wertesystem")
	check_equal(_attacker.get_stats().get_value(&"crit_damage"), Data.konstante(&"krit_grundschaden"),
			"Kritischer Schaden = Grundwert")


func test_immunitaet() -> void:
	var before := _boss.get_stats().health
	var result := Combat.roll_damage(_attacker, _boss, 500.0, &"feuer", K.SPELL)
	check(result != null and result.outcome == O.IMMUNE, "Feuer gegen Bosspuppe → Immun")
	check_equal(_boss.get_stats().health, before, "Kein Schaden bei Immunität")
	check_equal(result.amount, 0.0, "Menge 0")


func test_positionsregeln() -> void:
	check(_boss.is_in_front(_attacker), "Angreifer steht vor der Bosspuppe")
	var front := Combat.hit_table(_attacker, _boss, K.MELEE)
	check_equal(front[O.PARRY], 10.0, "Von vorne: Parieren")
	check_equal(front[O.BLOCK], 20.0, "Von vorne: Blocken")
	check_equal(front[O.DODGE], 10.0, "Ausweichen")
	check_near(front[O.CRIT], Data.konstante(&"krit_grundchance"), 0.001, "Krit des Angreifers")
	var level_gap := _boss.get_level() - _attacker.get_level()
	check_near(front[O.MISS], StatBlock.miss_chance(_attacker.get_level(), _boss.get_level()), 0.001,
			"Verfehlen nach Stufenunterschied (%d Stufen)" % level_gap)
	var ranged := Combat.hit_table(_attacker, _boss, K.RANGED)
	check_equal(ranged[O.PARRY], 0.0, "Fernkampf: kein Parieren")
	var spell := Combat.hit_table(_attacker, _boss, K.SPELL)
	check_equal(spell[O.DODGE], 0.0, "Zauber: kein Ausweichen")
	var dual := Combat.hit_table(_attacker, _boss, K.MELEE, Combat.FLAG_DUAL_WIELD)
	check(dual[O.MISS] > front[O.MISS], "Beidhändig verfehlt häufiger")
	_attacker.global_position = Vector3(0.0, 0.0, 3.0)
	check(_attacker.is_behind(_boss), "Angreifer steht hinter der Bosspuppe")
	var behind := Combat.hit_table(_attacker, _boss, K.MELEE)
	check_equal(behind[O.PARRY], 0.0, "Von hinten: kein Parieren")
	check_equal(behind[O.BLOCK], 0.0, "Von hinten: kein Blocken")
	var outcomes := {}
	for i in 2000:
		var result := Combat.roll_damage(_attacker, _boss, 100.0, &"physisch", K.MELEE)
		outcomes[result.outcome] = true
	check(not outcomes.has(O.PARRY) and not outcomes.has(O.BLOCK), "2000 Schläge von hinten: nie pariert/geblockt")
	_attacker.global_position = Vector3(0.0, 0.0, -3.0)
	outcomes.clear()
	for i in 2000:
		var result := Combat.roll_damage(_attacker, _boss, 100.0, &"physisch", K.MELEE)
		outcomes[result.outcome] = true
	check(outcomes.has(O.PARRY) and outcomes.has(O.BLOCK) and outcomes.has(O.DODGE),
			"2000 Schläge von vorne: pariert, geblockt und ausgewichen kommen vor")


func test_ruestung_und_zauberschutz() -> void:
	var k := float(Data.umrechnung(_attacker.get_level()).get_value("ruestung_konstante"))
	var expected := HitFormulas.mitigation_percent(400.0, 0.0, k, Data.konstante(&"obergrenze_ruestung"))
	check_near(Combat.mitigation_percent(_attacker, _boss, &"physisch"), expected, 0.001,
			"Körperlich: Rüstung mit K der Angreiferstufe")
	var k_ward := float(Data.umrechnung(_attacker.get_level()).get_value("zauberschutz_konstante"))
	check_near(Combat.mitigation_percent(_attacker, _boss, &"frost"),
			HitFormulas.mitigation_percent(200.0, 0.0, k_ward, Data.konstante(&"obergrenze_zauberschutz")), 0.001,
			"Magisch: Zauberschutz")
	check_equal(Combat.mitigation_percent(_attacker, _plain, &"physisch"), 0.0, "Ohne Rüstung keine Minderung")
	# Ein normaler Treffer zieht genau den geminderten Betrag ab.
	var hits := 0
	for i in 200:
		var before := _boss.get_stats().health
		var result := Combat.roll_damage(_attacker, _boss, 1000.0, &"physisch", K.SPELL)
		if result.outcome == O.HIT:
			hits += 1
			var amount := roundf(1000.0 * (1.0 - expected / 100.0))
			check_equal(result.amount, amount, "Treffer nach Rüstung")
			check_equal(before - _boss.get_stats().health, amount, "Leben sinkt um den Treffer")
			break
	check(hits > 0, "Mindestens ein normaler Treffer in 200 Versuchen")


func test_blocken_und_kritisch() -> void:
	var blocked_seen := false
	var crit_seen := false
	for i in 3000:
		var result := Combat.roll_damage(_attacker, _boss, 1000.0, &"physisch", K.MELEE)
		var after_armor := 1000.0 * (1.0 - Combat.mitigation_percent(_attacker, _boss, &"physisch") / 100.0)
		if result.outcome == O.BLOCK and not blocked_seen:
			blocked_seen = true
			check_equal(result.blocked, 50.0, "Blockwert abgezogen")
			check_equal(result.amount, roundf(after_armor - 50.0), "Geblockt: Rüstung, dann Blockwert")
		if result.outcome == O.CRIT and not crit_seen:
			crit_seen = true
			check_equal(result.amount, roundf(after_armor * 2.0), "Kritisch: × 2 (200 %) vor der Rüstung")
		if blocked_seen and crit_seen:
			break
	check(blocked_seen, "Blocken kam vor")
	check(crit_seen, "Kritisch kam vor")


func test_mindestschaden_und_absorption() -> void:
	var result: HitResult = null
	for i in 200:
		result = Combat.roll_damage(_attacker, _plain, 0.1, &"natur", K.PERIODIC)
		if result.outcome == O.HIT:
			break
	check_equal(result.amount, 1.0, "Mindestens 1 Schaden")
	var shield := AuraData.new()
	shield.id = &"test_pruef_schild"
	shield.display_name = "Prüfschild"
	shield.duration = 30.0
	shield.absorb_amount = 100000.0
	_plain.get_combat().apply_aura(shield, _plain)
	var before := _plain.get_stats().health
	for i in 200:
		result = Combat.roll_damage(_attacker, _plain, 500.0, &"natur", K.PERIODIC)
		if result.outcome == O.HIT:
			break
	check_equal(result.amount, 0.0, "Vollständig absorbiert: 0 Schaden")
	check_equal(result.absorbed, 500.0, "Absorbierte Menge")
	check_equal(_plain.get_stats().health, before, "Leben unverändert")
	_plain.get_combat().remove_all_auras(true)


func test_modifikatoren_aus_auren() -> void:
	var aura := AuraData.new()
	aura.id = &"test_pruef_feuer"
	aura.display_name = "Prüffeuer"
	aura.duration = 30.0
	var modifier := AmountModifierData.new()
	modifier.kind = AmountModifierData.Kind.DAMAGE_DONE
	modifier.percent = 50.0
	modifier.schools = PackedStringArray(["feuer"])
	aura.amount_modifiers = [modifier]
	_attacker.get_combat().apply_aura(aura, _attacker)
	check_near(Combat.damage_factor(_attacker, _plain, &"feuer"), 1.5, 0.0001, "+50 % Feuerschaden")
	check_near(Combat.damage_factor(_attacker, _plain, &"frost"), 1.0, 0.0001, "Andere Schule unverändert")
	var taken := AuraData.new()
	taken.id = &"test_pruef_verwundbar"
	taken.display_name = "Prüfverwundbar"
	taken.duration = 30.0
	taken.max_stacks = 5
	taken.stack_mode = AuraData.StackMode.ADD_STACK
	var vulnerable := AmountModifierData.new()
	vulnerable.kind = AmountModifierData.Kind.DAMAGE_TAKEN
	vulnerable.percent = 10.0
	taken.amount_modifiers = [vulnerable]
	_plain.get_combat().apply_aura(taken, _attacker, null, 2)
	check_near(Combat.damage_factor(_attacker, _plain, &"feuer"), 1.5 * 1.2, 0.0001,
			"Verursacht × erlitten, Stapel zählen")
	_attacker.get_combat().remove_all_auras(true)
	_plain.get_combat().remove_all_auras(true)


func test_testauren_aus_daten() -> void:
	var fire := GameData.get_aura(&"test_feuermacht")
	check(fire != null and fire.amount_modifiers.size() == 1, "Testaura Feuermacht mit Modifikator")
	var heal := GameData.get_aura(&"test_heilempfang")
	check(heal != null and heal.amount_modifiers.size() == 1
			and heal.amount_modifiers[0].kind == AmountModifierData.Kind.HEALING_TAKEN,
			"Testaura Heilempfang: erhaltene Heilung")
	if heal == null:
		return
	_healer_target.get_combat().apply_aura(heal, _attacker)
	check_near(Combat.heal_factor(_attacker, _healer_target), 1.5, 0.0001, "+50 % erhaltene Heilung")
	_healer_target.get_combat().remove_all_auras(true)


func test_heilung_mit_ueberheilung() -> void:
	var stats := _healer_target.get_stats()
	var result: HitResult = null
	for i in 200:
		stats.set_health(stats.max_health - 100.0)
		result = Combat.roll_heal(_attacker, _healer_target, 500.0)
		if result.outcome == O.HIT:
			break
	check(result.is_heal(), "Ergebnis ist eine Heilung")
	check_equal(result.amount, 500.0, "Heilung 500")
	check_equal(result.overheal, 400.0, "Überheilung 400")
	check_equal(stats.health, stats.max_health, "Leben voll")
	var crit_seen := false
	for i in 500:
		stats.set_health(stats.max_health - 100.0)
		result = Combat.roll_heal(_attacker, _healer_target, 500.0)
		if result.outcome == O.CRIT:
			crit_seen = true
			check_equal(result.amount, 1000.0, "Kritische Heilung × 2")
			check_equal(result.overheal, 900.0, "Überheilung bei Krit")
			break
	check(crit_seen, "Kritische Heilung kam vor")


func _spawn(dummy_id: StringName, position: Vector3) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.name = String(dummy_id).capitalize().replace(" ", "") + str(_root.get_child_count())
	dummy.dummy_id = dummy_id
	dummy.position = position
	_root.add_child(dummy)
	return dummy
