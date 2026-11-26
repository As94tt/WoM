extends TestSuite
## Tests des Kriegers (Ticket #53) mit einer echten Spielfigur und drei
## Schadenspuppen (ohne Netzwerk ist die eigene Instanz der Host):
## - Grundfähigkeiten, Stufen, Wut (Erzeugen, Kosten, Verfall), Schildschlag
##   nur mit Schild, Sturmangriff mit Mindestreichweite,
## - jede Fähigkeit (Grundfähigkeiten, Varianten, Talent-Fähigkeiten) über
##   den echten Weg (UnitCaster.host_use) gegen eine Übungspuppe,
## - die Mechaniken der Spezialisierungen (Bollwerk-Haltung und Rache,
##   Raserei und Blutrausch, Tiefe Wunde und Hinrichten) und alle Talente,
## - grober Schadensvergleich Berserker gegen Schlachtmeister über 60 s an
##   einer Übungspuppe und ein Bollwerk gegen drei Angriffspuppen (die Zeit
##   wird dafür von Hand vorgespult, siehe _advance).
##
## Damit die Tests nicht vom Würfel abhängen, weichen die Puppen nie aus
## (Testmodifikator) und der Krieger trifft nie kritisch, außer in den
## Vergleichen über 60 s (fester Startwert des Zufalls).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE := preload("res://scenes/units/training_dummy.tscn")
const TEST_SOURCE := &"test:krieger"

var _root: Node3D = null
var _effects: Node3D = null
var _w: PlayerCharacter = null
## Hauptziel 3 m vor dem Krieger, „nah“ 2,5 m daneben, „fern“ 25 m daneben.
var _dummy: TrainingDummy = null
var _near: TrainingDummy = null
var _far: TrainingDummy = null


func before_all() -> void:
	_root = Node3D.new()
	_root.name = "WarriorTest"
	tree.root.add_child(_root)
	_effects = Node3D.new()
	_effects.name = "Effects"
	_effects.add_to_group(GroundArea.CONTAINER_GROUP)
	_root.add_child(_effects)
	_w = _spawn_player("1", Vector3.ZERO)
	_dummy = _spawn_dummy("Puppe", &"schadenspuppe_10", Vector3(0.0, 0.0, -3.0))
	_near = _spawn_dummy("Nah", &"schadenspuppe_10", Vector3(2.5, 0.0, -3.0))
	_far = _spawn_dummy("Fern", &"schadenspuppe_10", Vector3(25.0, 0.0, -3.0))
	Combat._random = RandomNumberGenerator.new()
	Combat._random.seed = 53


func after_all() -> void:
	Combat._random = null
	if _root != null:
		_root.free()


func _spawn_player(node_name: String, position: Vector3) -> PlayerCharacter:
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	player.name = node_name
	player.display_name = "Krieger" + node_name
	player.race_id = &"human"
	player.class_id = &"warrior"
	player.position = position
	_root.add_child(player)
	return player


func _spawn_dummy(node_name: String, dummy_id: StringName, position: Vector3) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.name = node_name
	dummy.dummy_id = dummy_id
	dummy.position = position
	_root.add_child(dummy)
	return dummy


# --- Hilfen ------------------------------------------------------------------

## Stufe 30, Spezialisierung und Ränge, Schild und Nahkampfwaffe.
func _setup(spec := "", ranks := {}) -> void:
	_w.get_talents().host_load({})
	_clean()
	_w.get_stats().set_level_override(30)
	_w.get_talents().host_load({"spec": spec, "ranks": ranks})
	_w.get_stats().refill()
	_weapons(true, true)


func _weapons(shield: bool, melee: bool) -> void:
	_w.get_stats().set_flag(StatBlock.FLAG_SHIELD, shield)
	_w.get_stats().set_flag(StatBlock.FLAG_MELEE_WEAPON, melee)


## Puppen, Flächen und sichtbare Auren zurücksetzen; Puppen weichen nie aus,
## der Krieger trifft nie kritisch.
func _clean() -> void:
	for child in _effects.get_children():
		child.free()
	for dummy: TrainingDummy in [_dummy, _near, _far]:
		dummy.get_combat().remove_all_auras(true)
		dummy.get_combat().clear_threat()
		dummy.get_stats().refill()
		dummy.get_stats().remove_source(TEST_SOURCE)
		dummy.get_stats().add_modifier(StatModifier.create(TEST_SOURCE, "", &"dodge", -100.0))
	_dummy.global_position = Vector3(0.0, 0.0, -3.0)
	_near.global_position = Vector3(2.5, 0.0, -3.0)
	_far.global_position = Vector3(25.0, 0.0, -3.0)
	_w.get_combat().remove_all_auras(false)
	_w.global_transform = Transform3D.IDENTITY
	var stats := _w.get_stats()
	stats.remove_source(TEST_SOURCE)
	stats.add_modifier(StatModifier.create(TEST_SOURCE, "", &"crit_chance", -100.0))
	stats.min_health = 0.0
	stats.refill()
	stats.set_in_combat(false)
	_w.get_caster_node().host_cancel()
	_w.get_caster_node().host_reset_cooldowns()
	_w.auto_attacking = false


func _ability(id: StringName) -> AbilityData:
	return GameData.get_ability(id)


func _rage(value: float) -> void:
	_w.get_stats().rage = value


## Fähigkeit über den echten Weg; Abklingzeiten vorher frei, Zauberzeit und
## Kanalisieren vorgespult. Gibt den Code zurück.
func _use(id: StringName, target: Unit = null) -> int:
	var caster := _w.get_caster_node()
	caster.host_reset_cooldowns()
	var result := caster.host_use(_ability(id), target if target != null else _dummy)
	_finish_cast(caster)
	return int(result[0])


func _finish_cast(caster: UnitCaster) -> void:
	if caster._cast.is_empty():
		return
	var shift := float(caster._cast["end"]) - float(caster._cast["start"]) + 0.01
	for key: String in ["start", "end", "next_tick"]:
		caster._cast[key] = float(caster._cast[key]) - shift
	caster._process_cast(Network.host_time())


func _stacks(unit: Unit, aura_id: StringName) -> int:
	return unit.get_combat().get_stacks(aura_id)


func _aura(unit: Unit, aura_id: StringName) -> AuraInstance:
	for inst in unit.get_combat().get_auras():
		if inst.data.id == aura_id:
			return inst
	return null


func _tick_auras(unit: Unit) -> void:
	var combat := unit.get_combat()
	for inst in combat.get_auras():
		if inst.next_tick >= 0.0:
			inst.next_tick = Network.host_time() - 0.001
	combat._process(0.0)


func _expire(unit: Unit, aura_id: StringName) -> void:
	var combat := unit.get_combat()
	for inst in combat.get_auras():
		if inst.data.id == aura_id:
			inst.expires_at = Network.host_time() - 0.01
	combat._process(0.0)


func _areas() -> Array[GroundArea]:
	var result: Array[GroundArea] = []
	for node in _effects.get_children():
		if node is GroundArea and not node.is_queued_for_deletion():
			result.append(node)
	return result


func _lost(unit: Unit, before: float) -> float:
	return before - unit.get_stats().health


## Zeit vorspulen: alle gespeicherten Zeitpunkte (Host-Zeit) um dt nach vorn
## schieben und die Abläufe einmal laufen lassen – wie dt Sekunden warten.
func _advance(dt: float, players: Array[PlayerCharacter], dummies: Array[TrainingDummy]) -> void:
	for player in players:
		var caster := player.get_caster_node()
		caster._gcd = [float(caster._gcd[0]) - dt, float(caster._gcd[1]) - dt]
		for key: String in caster._cooldowns:
			var window: Array = caster._cooldowns[key]
			caster._cooldowns[key] = [float(window[0]) - dt, float(window[1]) - dt]
		for key: String in caster._charges:
			var entry: Array = caster._charges[key]
			if float(entry[1]) > 0.0:
				entry[1] = float(entry[1]) - dt
		for key: String in caster._locks:
			caster._locks[key] = float(caster._locks[key]) - dt
		caster._main_at -= dt
		caster._off_at -= dt
		caster._ranged_at -= dt
		if not caster._cast.is_empty():
			for key: String in ["start", "end", "next_tick"]:
				caster._cast[key] = float(caster._cast[key]) - dt
	var units: Array[Unit] = []
	units.append_array(players)
	units.append_array(dummies)
	for unit in units:
		var combat := unit.get_combat()
		if combat._combat_until >= 0.0:
			combat._combat_until -= dt
		if combat._taunt_until >= 0.0:
			combat._taunt_until -= dt
		for inst in combat._auras:
			if inst.expires_at >= 0.0:
				inst.expires_at -= dt
			if inst.next_tick >= 0.0:
				inst.next_tick -= dt
			if inst.next_delay_tick >= 0.0:
				inst.next_delay_tick -= dt
			for index: int in inst.proc_ready_at:
				inst.proc_ready_at[index] = float(inst.proc_ready_at[index]) - dt
	for area in _areas():
		area.expires_at -= dt
		area._next_tick -= dt
	for dummy in dummies:
		dummy._next_attack -= dt
		if dummy.get_kind() == TrainingDummy.Kind.ATTACK:
			dummy._process_attack(dummy._now())
	for player in players:
		player.get_caster_node()._host_process()
		player.get_stats()._regenerate(dt)
	for unit in units:
		unit.get_combat()._process(0.0)
	for area in _areas():
		area._process(0.0)


# --- Grundfähigkeiten und Wut ------------------------------------------------

func test_grundfaehigkeiten_und_stufen() -> void:
	var warrior := GameData.get_class_data(&"warrior")
	var expected := {&"hieb": 1, &"spott": 2, &"schildschlag": 3, &"kampfschrei": 4, &"sturmangriff": 5,
			&"zerschmettern": 6, &"donnerknall": 8, &"letztes_gefecht": 9}
	check_equal(warrior.abilities.size(), 8, "8 Grundfähigkeiten")
	check_equal(warrior.resources, [&"rage"] as Array[StringName], "Ressource Wut")
	for ability in warrior.abilities:
		check(expected.has(ability.id), "%s ist eine Grundfähigkeit" % ability.id)
		check_equal(ability.required_level, int(expected.get(ability.id, 0)), "%s: Stufe" % ability.id)
		check(not ability.is_spell and ability.get_school() == &"physisch", "%s: körperlich" % ability.id)
	check(_ability(&"passiv_krieger") == null, "Platzhalter „Passiv (Krieger)“ entfernt")
	check_equal(_ability(&"zerschmettern").get_cost(), 30.0, "Zerschmettern kostet 30 Wut")
	check_equal(_ability(&"zerschmettern").get_cost_resource(), &"rage", "… Wut")
	check_equal(_ability(&"donnerknall").get_cost(), 10.0, "Donnerknall kostet 10 Wut")
	check_near(_ability(&"spott").get_cooldown(), 8.0, 0.001, "Spott 8 s")
	check(_ability(&"spott").ignores_gcd and _ability(&"letztes_gefecht").ignores_gcd,
			"Spott und Letztes Gefecht außerhalb des globalen Cooldowns")
	check_near(_ability(&"schildschlag").get_cooldown(), 6.0, 0.001, "Schildschlag 6 s")
	check_near(_ability(&"kampfschrei").get_cooldown(), 30.0, 0.001, "Kampfschrei 30 s")
	check_near(_ability(&"sturmangriff").get_cooldown(), 20.0, 0.001, "Sturmangriff 20 s")
	check_near(_ability(&"donnerknall").get_cooldown(), 6.0, 0.001, "Donnerknall 6 s")
	check_near(_ability(&"letztes_gefecht").get_cooldown(), 180.0, 0.001, "Letztes Gefecht 3 min")
	_setup()
	_w.get_stats().set_level_override(5)
	check(_w.get_abilities().is_learned(_ability(&"sturmangriff")), "Stufe 5: Sturmangriff erlernt")
	check(not _w.get_abilities().is_learned(_ability(&"zerschmettern")), "Stufe 5: Zerschmettern noch nicht")


func test_wut_entsteht_wird_bezahlt_und_verfaellt() -> void:
	_setup()
	check_equal(_w.get_stats().rage, 0.0, "Kampf beginnt mit 0 Wut")
	check_equal(_w.get_stats().max_rage, 100.0, "Wut 0–100")
	_use(&"hieb")
	check(_w.get_stats().rage >= 10.0, "Hieb erzeugt 10 Wut (dazu Wut aus Schaden): %s" % _w.get_stats().rage)
	_rage(20.0)
	check_equal(_use(&"zerschmettern"), AbilityError.Code.NO_RESOURCE, "Zerschmettern mit 20 Wut: nicht genug Wut")
	check_equal(AbilityError.text(AbilityError.Code.NO_RESOURCE, "rage"), "Nicht genug Wut.", "Meldung")
	_rage(50.0)
	var before := _dummy.get_stats().health
	check_equal(_use(&"zerschmettern"), AbilityError.Code.OK, "Zerschmettern mit 50 Wut")
	check(_lost(_dummy, before) > 0.0, "Zerschmettern trifft")
	check_near(_w.get_stats().rage, 50.0 - 30.0 + _lost(_dummy, before) * Data.konstante(&"wut_pro_schaden_ausgeteilt"),
			0.01, "30 Wut bezahlt (dazu Wut aus Schaden)")
	_rage(0.0)
	_w.get_stats().take_damage(_w.get_stats().max_health * 0.1)
	check_near(_w.get_stats().rage, Data.konstante(&"wut_pro_schaden_genommen") * 0.1, 0.01,
			"Erlittener Schaden erzeugt Wut")
	_rage(50.0)
	_w.get_stats().set_in_combat(false)
	_w.get_stats()._regenerate(2.0)
	check_near(_w.get_stats().rage, 50.0 - 2.0 * Data.konstante(&"wut_verfall_pro_s"), 0.01, "Wut verfällt außerhalb des Kampfes")
	_rage(50.0)
	_w.get_stats().set_in_combat(true)
	_w.get_stats()._regenerate(2.0)
	check_near(_w.get_stats().rage, 50.0, 0.01, "Im Kampf verfällt keine Wut")
	_w.get_stats().set_in_combat(false)
	_w.get_stats()._do_dev_action("rage_full", null)
	check_equal(_w.get_stats().rage, 100.0, "Entwickler-Panel: Wut auf 100")


func test_schildschlag_nur_mit_schild() -> void:
	_setup()
	_weapons(false, true)
	var caster := _w.get_caster_node()
	check_equal(_use(&"schildschlag"), AbilityError.Code.NEED_WEAPON, "Ohne Schild: geht nicht")
	check_equal(AbilityError.text(AbilityError.Code.NEED_WEAPON, str(AbilityData.WeaponRequirement.SHIELD)),
			"Dafür braucht Ihr einen Schild.", "Meldung „Schild“")
	check_equal(caster.get_requirement_block(_ability(&"schildschlag"), _dummy)[0], AbilityError.Code.NEED_WEAPON,
			"Aktionsleiste: ausgegraut")
	_weapons(true, true)
	check_equal(caster.get_requirement_block(_ability(&"schildschlag"), _dummy)[0], AbilityError.Code.OK,
			"Mit Schild nicht mehr ausgegraut")
	_rage(0.0)
	var before := _dummy.get_stats().health
	check_equal(_use(&"schildschlag"), AbilityError.Code.OK, "Mit Schild")
	check(_lost(_dummy, before) > 0.0, "Schaden")
	check(_w.get_stats().rage >= 15.0, "Erzeugt 15 Wut")
	check(_dummy.get_combat().get_threat_of(_w) > _lost(_dummy, before) + 99.0, "Zusatzbedrohung 100")


func test_sturmangriff_kampfschrei_letztes_gefecht() -> void:
	_setup()
	_rage(0.0)
	check_equal(_use(&"sturmangriff"), AbilityError.Code.TOO_CLOSE, "Im Nahkampf: zu nah")
	check_equal(AbilityError.text(AbilityError.Code.TOO_CLOSE), "Ihr seid zu nah dran.", "Meldung")
	_dummy.global_position = Vector3(0.0, 0.0, -15.0)
	check_equal(_use(&"sturmangriff"), AbilityError.Code.OK, "Aus 15 m")
	check(_w.distance_to_unit(_dummy) < 2.0, "Krieger springt zum Ziel (%s m)" % _w.distance_to_unit(_dummy))
	check(_dummy.get_combat().has_state(Combat.STATE_STUNNED), "Ziel betäubt")
	check_near(_aura(_dummy, &"sturmangriff_betaeubung").duration, 1.0, 0.001, "1 s")
	check_equal(_w.get_stats().rage, 20.0, "20 Wut")
	_w.global_transform = Transform3D.IDENTITY
	_dummy.global_position = Vector3(0.0, 0.0, -30.0)
	check_equal(_use(&"sturmangriff"), AbilityError.Code.OUT_OF_RANGE, "Über 25 m: außer Reichweite")
	_clean()
	var ap := _w.get_stats().get_value(&"attack_power")
	_rage(0.0)
	check_equal(_use(&"kampfschrei"), AbilityError.Code.OK, "Kampfschrei")
	check_near(_w.get_stats().get_value(&"attack_power"), ap * 1.1, 0.5, "+10 % Kampfkraft")
	check_near(_aura(_w, &"kampfschrei").duration, 60.0, 0.001, "60 s")
	check_equal(_w.get_stats().rage, 20.0, "20 Wut")
	var health := _w.get_stats().max_health
	check_equal(_use(&"letztes_gefecht"), AbilityError.Code.OK, "Letztes Gefecht")
	check_near(_w.get_stats().max_health, health * 1.3, 0.5, "+30 % maximales Leben")
	check_near(_aura(_w, &"letztes_gefecht").duration, 15.0, 0.001, "15 s")


func test_spott_und_donnerknall() -> void:
	_setup()
	check_equal(_use(&"spott", _far), AbilityError.Code.OK, "Spott auf 25 m")
	check(_far.get_combat().get_taunting_unit() == _w, "Ziel greift den Krieger an")
	_rage(50.0)
	check_equal(_use(&"donnerknall"), AbilityError.Code.OK, "Donnerknall")
	for dummy: TrainingDummy in [_dummy, _near]:
		check(dummy.get_stats().health < dummy.get_stats().max_health, "%s getroffen" % dummy.name)
		check_near(dummy.get_combat().get_slow_percent(), 20.0, 0.001, "%s um 20 %% verlangsamt" % dummy.name)
		check_near(_aura(dummy, &"donnerknall").duration, 6.0, 0.001, "6 s")
		var lost := dummy.get_stats().max_health - dummy.get_stats().health
		check(dummy.get_combat().get_threat_of(_w) >= lost + 59.0, "%s: erhöhte Bedrohung" % dummy.name)
	check(_far.get_stats().health >= _far.get_stats().max_health, "25 m entfernt: nicht getroffen")


func test_verwandlungen_wie_in_der_tabelle() -> void:
	var table := {
		&"warrior_bollwerk": [&"schildstoss", &"schildschlag_bollwerk", &"vergeltung", &"donnerknall_bollwerk",
				&"sammelruf", &"spott", &"schildansturm", &"schildwall"],
		&"warrior_berserker": [&"wilder_hieb", &"wutschlag", &"raserei_schlag", &"wirbelwind",
				&"schlachtgebruell", &"herausforderung", &"rasender_ansturm", &"letztes_gefecht"],
		&"warrior_schlachtmeister": [&"klaffender_hieb", &"toedlicher_stoss", &"hinrichten", &"erdbeben",
				&"kriegsruf", &"bruellen", &"schwerer_ansturm", &"letztes_gefecht"],
	}
	var bases := [&"hieb", &"schildschlag", &"zerschmettern", &"donnerknall", &"kampfschrei", &"spott",
			&"sturmangriff", &"letztes_gefecht"]
	for spec: StringName in table:
		_setup(spec)
		for index in bases.size():
			var resolved := _w.get_abilities().resolve(_ability(bases[index]))
			check_equal(resolved.id, table[spec][index], "%s: %s → %s" % [spec, bases[index], table[spec][index]])
	check_near(_ability(&"schildschlag_bollwerk").get_cooldown(), 4.0, 0.001, "Bollwerk: Schildschlag 4 s")
	check_equal(_ability(&"wutschlag").required_weapon, AbilityData.WeaponRequirement.NONE, "Wutschlag ohne Schild")
	check_equal(_ability(&"toedlicher_stoss").required_weapon, AbilityData.WeaponRequirement.NONE,
			"Tödlicher Stoß ohne Schild")
	check_equal(_ability(&"vergeltung").get_cost(), 0.0, "Vergeltung kostet keine Wut")
	check_equal(_ability(&"raserei_schlag").get_cost(), 30.0, "Raserei-Schlag kostet 30 Wut")


func test_gesperrte_spezialisierungen() -> void:
	var warrior := GameData.get_class_data(&"warrior")
	var specs := warrior.get_specializations()
	check_equal(specs.size(), 6, "6 Spezialisierungen")
	var locked := {&"warrior_kriegsherr": "Banner", &"warrior_gladiator": "Netz", &"warrior_waechter": "Schaden auf sich"}
	for spec in specs:
		if locked.has(spec.id):
			check(spec.locked, "%s gesperrt" % spec.id)
			check(spec.get_short_description().contains(locked[spec.id]), "%s: Beschreibung" % spec.id)
			check(spec.transformations.is_empty() and spec.talent_tree == null, "%s: nur Platzhalter" % spec.id)
		else:
			check(not spec.locked and spec.talent_tree != null, "%s wählbar mit Baum" % spec.id)
			check_equal(spec.talent_tree.get_problems(), PackedStringArray(), "%s: Baum ohne Datenfehler" % spec.id)
			check_equal(spec.talent_tree.rows.size(), 7, "%s: 7 Reihen" % spec.id)
			var thresholds: Array[int] = []
			for row in spec.talent_tree.rows:
				thresholds.append(row.required_points)
			check_equal(thresholds, [0, 1, 4, 5, 8, 9, 12] as Array[int], "%s: Schwellen wie beim Magier" % spec.id)
	_setup()
	var clean := PlayerTalents.sanitize(warrior, {"spec": "warrior_gladiator"})
	check_equal(str(clean["spec"]), "", "Gesperrt nicht wählbar")
	clean = PlayerTalents.sanitize(warrior, {"spec": "warrior_gladiator", "unlocked": ["warrior_gladiator"]})
	check_equal(str(clean["spec"]), "warrior_gladiator", "Nach dem Entsperren wählbar")


# --- Jede Fähigkeit gegen die Übungspuppen -----------------------------------

const SETS := [
	[&"", {}],
	[&"warrior_bollwerk", {"gegenstoss": 1, "eiserne_haut": 3, "heldenwurf": 1, "standhaft": 3,
			"fels_in_der_brandung": 1, "bollwerk": 3, "unbeugsam": 1}],
	[&"warrior_bollwerk", {"schildmeister": 1, "wachsamkeit": 3, "schildwurf": 1, "grollen": 3, "abfangen": 1,
			"zorn_des_waechters": 3, "schildorkan": 1}],
	[&"warrior_berserker", {"blinde_wut": 1, "wutentbrannt": 3, "klingensturm": 1, "blutdurst": 3,
			"tollkuehnheit": 1, "wirbelnde_klingen": 3, "avatar_der_wut": 1}],
	[&"warrior_berserker", {"rasender_beginn": 1, "flinke_klinge": 3, "rasender_sprung": 1, "unaufhaltsam": 3,
			"siegesrausch": 1, "wilde_kraft": 3, "berserkerzorn": 1}],
	[&"warrior_schlachtmeister", {"tiefe_schnitte": 1, "schwere_waffe": 3, "ueberwaeltigen": 1, "schlachtenlaerm": 3,
			"ploetzlicher_tod": 1, "kriegsveteran": 3, "schlachtfeld_herrschaft": 1}],
	[&"warrior_schlachtmeister", {"taktiker": 1, "ausbluten": 3, "kolossales_schmettern": 1, "gnadenlos": 3,
			"blutige_ernte": 1, "zerreissen": 3, "klingenschwung": 1}],
]


func test_jede_faehigkeit_gegen_puppen() -> void:
	var tested := {}
	for entry: Array in SETS:
		_setup(entry[0], entry[1])
		check_equal(_w.get_talents().get_ranks(), entry[1], "%s: Stand übernommen" % entry[0])
		if entry[0] != &"":
			check(_w.get_talents().are_talents_active(), "%s: Talente wirken (13 Punkte)" % entry[0])
		var list: Array[AbilityData] = []
		list.append_array(GameData.get_class_data(&"warrior").abilities)
		list.append_array(_w.get_talents().get_granted_abilities())
		for base in list:
			var ability := _w.get_abilities().resolve(base)
			_clean()
			_rage(100.0)
			if ability.required_aura != &"":
				_w.get_combat().apply_aura(GameData.get_aura(ability.required_aura), _w)
			if _w.get_caster_node().get_min_range(ability) > 0.0 or ability.id == &"rasender_sprung":
				_dummy.global_position = Vector3(0.0, 0.0, -15.0)
			if ability.get_number_for(_w, "werte.ziel_leben_unter") > 0.0:
				_dummy.get_stats().set_health(_dummy.get_stats().max_health * 0.1)
			var before := _dummy.get_stats().health
			var dummy_auras := _dummy.get_combat().get_auras().size()
			var own_auras := _w.get_combat().get_auras().size()
			var code := _use(base.id)
			check_equal(code, AbilityError.Code.OK, "%s: einsetzbar gegen die Puppe (%s)" % [ability.id, AbilityError.text(code)])
			for i in 2:
				_tick_auras(_dummy)
				for area in _areas():
					area._tick()
			var hit := _lost(_dummy, before) > 0.0 or _dummy.get_combat().get_auras().size() > dummy_auras \
					or _dummy.get_combat().get_taunting_unit() == _w
			var self_effect := _w.get_combat().get_auras().size() > own_auras or _w.global_position.length() > 1.0
			check(hit or self_effect, "%s wirkt (Schaden, Aura oder Spott an der Puppe, Aura oder Sprung beim Krieger)" % ability.id)
			tested[ability.id] = true
	check_equal(tested.size(), 8 + 21 + 13, "Alle 42 Fähigkeiten (8 Grund, 21 Varianten, 13 aus Talenten)")


# --- Bollwerk ----------------------------------------------------------------

func test_bollwerk_haltung_und_rache() -> void:
	_setup(&"warrior_bollwerk")
	check(_aura(_w, &"bollwerk_haltung") != null, "Passive Aura Bollwerk-Haltung")
	check_near(Combat.threat_factor(_w), 3.0, 0.001, "Dreifache Bedrohung")
	check(Combat.is_tank(_w), "Gilt als Tank")
	check_near(Combat.damage_factor(_dummy, _w, &"physisch"), 0.9, 0.001, "−10 % erlittener Schaden")
	check(not _aura(_w, &"bollwerk_haltung").data.cancelable, "Nicht abschaltbar")
	_rage(50.0)
	check_equal(_use(&"zerschmettern"), AbilityError.Code.NEED_AURA, "Vergeltung ohne Rache: geht nicht")
	check_equal(_w.get_caster_node().get_requirement_block(_ability(&"vergeltung"), _dummy)[0],
			AbilityError.Code.NEED_AURA, "… ausgegraut")
	for event in [Combat.Event.DODGE, Combat.Event.PARRY, Combat.Event.BLOCK]:
		_w.get_combat().remove_aura(&"rache")
		Combat.notify_event(_w, event, _dummy, 10.0)
		check(_aura(_w, &"rache") != null, "Rache nach %s" % Combat.EVENT_NAMES[event])
	check_near(_aura(_w, &"rache").duration, 5.0, 0.001, "Rache hält 5 s")
	_rage(0.0)
	Combat.notify_event(_w, Combat.Event.BLOCK, _dummy, 10.0)
	check_equal(_w.get_stats().rage, 5.0, "Jeder Block erzeugt 5 Wut")
	var state := _w.get_abilities().get_slot_state(_ability(&"zerschmettern"))
	check(bool(state.get("highlight", false)), "Vergeltung leuchtet mit Rache")
	var before := _dummy.get_stats().health
	_rage(0.0)
	check_equal(_use(&"zerschmettern"), AbilityError.Code.OK, "Vergeltung mit Rache, ohne Wut")
	check(_lost(_dummy, before) > 0.0, "Vergeltung trifft")
	check(_aura(_w, &"rache") == null, "Rache verbraucht")
	_rage(0.0)
	before = _dummy.get_stats().health
	_dummy.get_combat().clear_threat()
	_use(&"hieb")
	var lost := _lost(_dummy, before)
	check_near(_dummy.get_combat().get_threat_of(_w), lost * 1.5 * 3.0, 0.5, "Schildstoß: +50 % Bedrohung, dreifach")
	# Echter Block durch eine Angriffspuppe (Schildorkan: alles von vorne wird
	# geblockt, was nicht verfehlt).
	var attacker := _spawn_dummy("Angreifer", &"angriffspuppe", Vector3(-2.0, 0.0, -2.0))
	_w.get_combat().apply_aura(GameData.get_aura(&"schildorkan"), _w)
	_w.get_combat().remove_aura(&"rache")
	var blocked := false
	for i in 30:
		_rage(0.0)
		var result := Combat.roll_damage(attacker, _w, 50.0, &"physisch", HitFormulas.AttackKind.MELEE)
		if result != null and result.outcome == HitFormulas.Outcome.BLOCK:
			blocked = true
			break
	check(blocked, "Angriff von vorne geblockt")
	check(_aura(_w, &"rache") != null, "Geblockter Angriff: Rache")
	check(_w.get_stats().rage >= 5.0, "Geblockter Angriff: Wut")
	attacker.free()


func test_bollwerk_talente() -> void:
	var base_armor := 0.0
	var base_parry := 0.0
	_setup(&"warrior_bollwerk")
	base_armor = _w.get_stats().get_value(&"armor")
	base_parry = _w.get_stats().get_value(&"parry")
	_setup(&"warrior_bollwerk", SETS[1][1])
	Combat.notify_event(_w, Combat.Event.DODGE, _dummy, 10.0)
	check_near(_aura(_w, &"rache").duration, 8.0, 0.001, "Gegenstoß: Rache 8 s")
	check_near(_w.get_stats().get_value(&"armor"), base_armor * 1.15, 1.0, "Eiserne Haut 3: +15 % Rüstung")
	check_near(Combat.damage_factor(_dummy, _w, &"physisch"), 0.84, 0.001, "Bollwerk 3: −6 % (dazu −10 % Haltung)")
	_w.get_stats().set_health(_w.get_stats().max_health * 0.5)
	var health := _w.get_stats().health
	Combat.notify_event(_w, Combat.Event.BLOCK, _dummy, 10.0)
	check_near(_w.get_stats().health - health, _w.get_stats().max_health * 0.03, 0.5, "Standhaft 3: Block heilt 3 %")
	check(_w.get_abilities().knows(_ability(&"heldenwurf")), "Heldenwurf erlernt")
	_far.global_position = Vector3(0.0, 0.0, -18.0)
	var before := _far.get_stats().health
	check_equal(_use(&"heldenwurf", _far), AbilityError.Code.OK, "Heldenwurf auf 18 m")
	var lost := _lost(_far, before)
	check(lost > 0.0, "Heldenwurf trifft")
	check_near(_far.get_combat().get_threat_of(_w), (lost + 150.0) * 3.0, 1.0, "Hohe Bedrohung")
	# Fels in der Brandung: Flächenspott.
	_clean()
	_use(&"spott")
	check(_dummy.get_combat().get_taunting_unit() == _w and _near.get_combat().get_taunting_unit() == _w,
			"Fels in der Brandung: Spott auf alle im Umkreis von 8 m")
	check(_far.get_combat().get_taunting_unit() == null, "25 m entfernt nicht")
	# Unbeugsam
	_clean()
	_use(&"unbeugsam")
	_w.get_stats().take_damage(_w.get_stats().max_health * 2.0)
	check_equal(_w.get_stats().health, 1.0, "Unbeugsam: nicht unter 1 Leben")
	_expire(_w, &"unbeugsam")
	check_equal(_w.get_stats().min_health, 0.0, "Danach wieder normal")
	_w.get_stats().refill()
	# Satz B
	_setup(&"warrior_bollwerk", SETS[2][1])
	check_near(_w.get_stats().get_value(&"parry"), base_parry + 3.0, 0.01, "Wachsamkeit 3: +3 % Parieren")
	_rage(0.0)
	_use(&"schildschlag")
	check(_w.get_stats().rage >= 25.0, "Schildmeister: Schildschlag erzeugt 25 Wut")
	check_near(_ability(&"donnerknall_bollwerk").get_number_for(_w, "abklingzeit"), 3.0, 0.001, "Grollen 3: Donnerknall 3 s")
	_rage(50.0)
	_use(&"donnerknall")
	check(_aura(_dummy, &"donnerknall_schwaechung") != null, "Bollwerk-Donnerknall: Schwächung")
	check_near(_dummy.get_stats().get_value(&"haste_pct"), -10.0, 0.01, "−10 % Angriffstempo")
	Combat.notify_event(_w, Combat.Event.PARRY, _dummy, 10.0)
	_rage(0.0)
	_use(&"zerschmettern")
	check(_w.get_stats().rage >= 15.0, "Zorn des Wächters 3: Vergeltung erzeugt 15 Wut")
	_clean()
	_dummy.global_position = Vector3(0.0, 0.0, -10.0)
	_near.global_position = Vector3(2.0, 0.0, -10.0)
	_far.global_position = Vector3(-2.0, 0.0, -10.0)
	check_equal(_use(&"schildwurf"), AbilityError.Code.OK, "Schildwurf")
	for dummy: TrainingDummy in [_dummy, _near, _far]:
		check(dummy.get_combat().get_threat_of(_w) > 0.0, "Schildwurf: Bedrohung auf %s" % dummy.name)
	# Abfangen: Verbündeter, nächster Angriff trifft den Krieger.
	_clean()
	var ally := _spawn_player("2", Vector3(10.0, 0.0, 0.0))
	check_equal(_use(&"abfangen", ally), AbilityError.Code.OK, "Abfangen auf einen Verbündeten")
	check(_w.distance_to_unit(ally) < 2.0, "Sprung zum Verbündeten")
	var ally_health := ally.get_stats().health
	var own := _w.get_stats().health
	Combat.deal_damage(_dummy, ally, 100.0, &"physisch")
	check_equal(ally.get_stats().health, ally_health, "Verbündeter nimmt keinen Schaden")
	check(_w.get_stats().health < own, "Krieger nimmt ihn")
	check(_aura(ally, &"abfangen") == null, "Nur der nächste Angriff")
	ally.free()
	# Schildorkan: jeder Angriff von vorne geblockt.
	_clean()
	_use(&"schildorkan")
	var attacker := _spawn_dummy("Angreifer", &"angriffspuppe", Vector3(0.0, 0.0, -2.0))
	var table := Combat.hit_table(attacker, _w, HitFormulas.AttackKind.MELEE)
	check_near(float(table[HitFormulas.Outcome.BLOCK]), 100.0 - float(table[HitFormulas.Outcome.MISS]), 0.01,
			"Schildorkan: alles außer Verfehlen wird geblockt")
	attacker.global_position = Vector3(0.0, 0.0, 2.0)
	table = Combat.hit_table(attacker, _w, HitFormulas.AttackKind.MELEE)
	check_equal(float(table[HitFormulas.Outcome.BLOCK]), 0.0, "Von hinten nicht")
	attacker.free()


# --- Berserker ---------------------------------------------------------------

func test_berserker_raserei_und_blutrausch() -> void:
	_setup(&"warrior_berserker")
	check(_aura(_w, &"wut_kreislauf") != null, "Passive Aura Wut-Kreislauf")
	var haste := _w.get_stats().get_value(&"haste_pct")
	_rage(100.0)
	_use(&"zerschmettern")
	check_equal(_stacks(_w, &"raserei"), 2, "Raserei-Schlag: +1 Raserei und 30 ausgegebene Wut +1")
	check_near(_w.get_stats().get_value(&"haste_pct"), haste + 6.0, 0.01, "+3 % Tempo je Stapel")
	check_near(_aura(_w, &"raserei").duration, 10.0, 0.001, "Raserei hält 10 s")
	_w.get_combat().on_resource_spent(&"rage", 20.0)
	check_equal(_stacks(_w, &"raserei"), 2, "20 Wut: noch kein Stapel")
	_w.get_combat().on_resource_spent(&"rage", 10.0)
	check_equal(_stacks(_w, &"raserei"), 3, "zusammen 30: ein Stapel")
	check(_aura(_w, &"blutrausch") == null, "Noch kein Blutrausch")
	_w.get_combat().on_resource_spent(&"rage", 60.0)
	check_equal(_stacks(_w, &"raserei"), 5, "5 Stapel")
	check(_aura(_w, &"blutrausch") != null, "Blutrausch bei 5 Stapeln")
	check_near(_aura(_w, &"blutrausch").duration, 8.0, 0.001, "8 s")
	check_equal(_w.get_caster_node().get_cost(_ability(&"raserei_schlag")), 0.0, "Fähigkeiten kosten keine Wut")
	_rage(0.0)
	check_equal(_use(&"zerschmettern"), AbilityError.Code.OK, "Raserei-Schlag ohne Wut im Blutrausch")
	var expires := _aura(_w, &"blutrausch").expires_at
	_w.get_combat().on_resource_spent(&"rage", 30.0)
	check_near(_aura(_w, &"blutrausch").expires_at, expires, 0.001, "Weitere Stapel verlängern Blutrausch nicht")
	_expire(_w, &"blutrausch")
	check_equal(_stacks(_w, &"raserei"), 0, "Danach fallen alle Stapel ab")
	check(_w.get_caster_node().get_cost(_ability(&"raserei_schlag")) > 0.0, "Danach kostet es wieder Wut")
	# Wilder Hieb: zwei Schläge, 12 Wut
	_clean()
	_rage(0.0)
	check_equal(_ability(&"wilder_hieb").get_number_for(_w, "werte.schlaege"), 2.0, "Wilder Hieb: 2 Schläge")
	var before := _dummy.get_stats().health
	_dummy.get_combat().clear_threat()
	_use(&"hieb")
	var lost := _lost(_dummy, before)
	check(lost > 0.0, "Wilder Hieb trifft")
	check_near(_w.get_stats().rage, 12.0 + lost * Data.konstante(&"wut_pro_schaden_ausgeteilt"), 0.01,
			"Erzeugt 12 Wut (dazu Wut aus dem Schaden beider Schläge)")
	# Schlachtgebrüll: Kampfschrei und +1 Raserei
	_clean()
	_use(&"kampfschrei")
	check(_aura(_w, &"kampfschrei") != null and _stacks(_w, &"raserei") == 1, "Schlachtgebrüll: +10 % Kampfkraft, +1 Raserei")
	# Wirbelwind: alle im Umkreis von 8 m (höchstens 4)
	_clean()
	_rage(50.0)
	_use(&"donnerknall")
	check(_dummy.get_stats().health < _dummy.get_stats().max_health and _near.get_stats().health < _near.get_stats().max_health,
			"Wirbelwind trifft beide nahen Puppen")
	check(_aura(_dummy, &"donnerknall") == null, "keine Verlangsamung")


func test_berserker_talente() -> void:
	_setup(&"warrior_berserker", SETS[3][1])
	_w.get_combat().on_resource_spent(&"rage", 150.0)
	check_near(_aura(_w, &"blutrausch").duration, 10.0, 0.001, "Blinde Wut: Blutrausch 10 s")
	check(_aura(_w, &"tollkuehnheit") != null, "Tollkühnheit während Blutrausch")
	check_near(Combat.damage_factor(_dummy, _w, &"physisch"), 1.2, 0.001, "+20 % erlittener Schaden")
	_clean()
	_rage(0.0)
	Combat.notify_event(_w, Combat.Event.AUTO_ATTACK, _dummy, 10.0)
	check_equal(_w.get_stats().rage, 6.0, "Wutentbrannt 3: +6 Wut je automatischem Angriff")
	_w.get_stats().set_health(_w.get_stats().max_health * 0.5)
	var health := _w.get_stats().health
	Combat.notify_event(_w, Combat.Event.CRIT, _dummy, 10.0)
	check_near(_w.get_stats().health - health, _w.get_stats().max_health * 0.03, 0.5, "Blutdurst 3: Krit heilt 3 %")
	check_equal(int(_ability(&"wirbelwind").get_number_for(_w, "werte.ziele")), 7, "Wirbelnde Klingen 3: 7 Ziele")
	_rage(50.0)
	var before := [_dummy.get_stats().health, _near.get_stats().health]
	check_equal(_use(&"klingensturm"), AbilityError.Code.OK, "Klingensturm")
	check(_lost(_dummy, before[0]) > 0.0 and _lost(_near, before[1]) > 0.0, "Klingensturm trifft alle im Umkreis")
	_clean()
	_use(&"avatar_der_wut")
	check_near(Combat.damage_factor(_w, _dummy, &"physisch"), 1.25, 0.001, "Avatar der Wut: +25 % Schaden")
	_w.get_combat().on_resource_spent(&"rage", 30.0)
	check_equal(_stacks(_w, &"raserei"), 2, "Avatar der Wut: Raserei stapelt doppelt")
	# Satz B
	_setup(&"warrior_berserker", SETS[4][1])
	var haste := _w.get_stats().get_value(&"haste_pct")
	_setup(&"warrior_berserker")
	var base_haste := _w.get_stats().get_value(&"haste_pct")
	_setup(&"warrior_berserker", SETS[4][1])
	check_near(haste - base_haste, 6.0, 0.01, "Flinke Klinge 3: +6 % Tempo")
	_dummy.global_position = Vector3(0.0, 0.0, -15.0)
	_use(&"sturmangriff")
	check_equal(_stacks(_w, &"raserei"), 2, "Rasender Beginn: Sturmangriff gibt 2 Raserei")
	check_near(_aura(_w, &"raserei").duration, 16.0, 0.001, "Unaufhaltsam 3: Raserei 16 s")
	_w.get_stats().set_health(_w.get_stats().max_health * 0.5)
	health = _w.get_stats().health
	Combat.notify_event(_w, Combat.Event.KILL, _dummy, 10.0)
	check_near(_w.get_stats().health - health, _w.get_stats().max_health * 0.2, 0.5, "Siegesrausch: Tod des Ziels heilt 20 %")
	check_near(_ability(&"wilder_hieb").get_number_for(_w, "faktor"), 0.4 * 1.15, 0.001, "Wilde Kraft 3: +15 %")
	_clean()
	_use(&"berserkerzorn")
	check(_aura(_w, &"blutrausch") != null, "Berserkerzorn: 5 Raserei → Blutrausch")
	check(_w.get_combat().is_immune_to(&"betaeubung") and _w.get_combat().is_immune_to(&"furcht"),
			"Immun gegen Betäubung und Furcht")
	_clean()
	_dummy.global_position = Vector3(0.0, 0.0, -15.0)
	_near.global_position = Vector3(1.5, 0.0, -15.0)
	var near_before := _near.get_stats().health
	check_equal(_use(&"rasender_sprung"), AbilityError.Code.OK, "Rasender Sprung")
	check(_w.distance_to_unit(_dummy) < 2.0, "Sprung zum Ziel")
	check(_lost(_near, near_before) > 0.0, "Flächenschaden beim Aufprall")


# --- Schlachtmeister ---------------------------------------------------------

func test_schlachtmeister_wunde_und_hinrichten() -> void:
	_setup(&"warrior_schlachtmeister")
	for i in 4:
		_use(&"hieb")
	check_equal(_stacks(_dummy, &"tiefe_wunde"), 3, "Tiefe Wunde stapelt bis 3")
	check_near(_aura(_dummy, &"tiefe_wunde").duration, 12.0, 0.001, "hält 12 s")
	var before := _dummy.get_stats().health
	_tick_auras(_dummy)
	var tick := _lost(_dummy, before)
	var row := _ability(&"tiefe_wunde")
	var per_stack := row.get_number_for(_w, "grundwert") + row.get_number_for(_w, "faktor") \
			* _w.get_stats().get_value(&"attack_power")
	check(tick > 0.0 and tick <= per_stack * 3.0 + 0.5, "Tick: Schaden je Stapel (%s)" % tick)
	# Hinrichten
	_rage(100.0)
	check_equal(_use(&"zerschmettern"), AbilityError.Code.TARGET_HEALTH_TOO_HIGH, "Hinrichten bei vollem Leben: nein")
	check_equal(AbilityError.text(AbilityError.Code.TARGET_HEALTH_TOO_HIGH), "Euer Ziel hat noch zu viel Leben.", "Meldung")
	check(bool(_w.get_caster_node().get_requirement_block(_ability(&"hinrichten"), _dummy)[0]
			== AbilityError.Code.TARGET_HEALTH_TOO_HIGH), "… ausgegraut")
	var max_health := _dummy.get_stats().max_health
	_dummy.get_stats().set_health(max_health * 0.19)
	_rage(10.0)
	before = _dummy.get_stats().health
	check_equal(_use(&"zerschmettern"), AbilityError.Code.OK, "Unter 20 %: Hinrichten")
	var small := _lost(_dummy, before)
	check_near(_w.get_stats().rage, minf(100.0, small * Data.konstante(&"wut_pro_schaden_ausgeteilt")), 0.01,
			"Nur die Kosten, keine Zusatzwut da")
	_dummy.get_stats().set_health(max_health * 0.19)
	_rage(100.0)
	before = _dummy.get_stats().health
	_use(&"zerschmettern")
	var big := _lost(_dummy, before)
	check(_w.get_stats().rage < 100.0 - 10.0 - 40.0 + big * Data.konstante(&"wut_pro_schaden_ausgeteilt") + 0.5,
			"Verbraucht 10 + 40 Wut")
	check(big > small * 1.35, "40 zusätzliche Wut: deutlich mehr Schaden (%s statt %s)" % [big, small])
	# Tödlicher Stoß
	_dummy.get_stats().refill()
	_rage(50.0)
	_use(&"schildschlag")
	check(_aura(_dummy, &"toedliche_wunde") != null, "Tödlicher Stoß: −50 % erhaltene Heilung")
	check_near(Combat.heal_factor(null, _dummy), 0.5, 0.001, "Heilfaktor am Ziel 0,5")
	# Erdbeben
	_clean()
	_rage(50.0)
	check_equal(_use(&"donnerknall"), AbilityError.Code.OK, "Erdbeben")
	var areas := _areas()
	check_equal(areas.size(), 1, "Eine Fläche um den Krieger")
	if not areas.is_empty():
		check_near(areas[0].expires_at - Network.host_time(), 6.0, 0.1, "6 s")
		areas[0]._tick()
	check(_stacks(_dummy, &"tiefe_wunde") >= 1 and _stacks(_near, &"tiefe_wunde") >= 1, "Wunden auf allen darin")


func test_schlachtmeister_talente() -> void:
	_setup(&"warrior_schlachtmeister", SETS[5][1])
	for i in 6:
		_use(&"hieb")
	check_equal(_stacks(_dummy, &"tiefe_wunde"), 5, "Tiefe Schnitte: bis 5")
	check_near(Combat.damage_factor(_w, _dummy, &"physisch"), 1.09, 0.001, "Schwere Waffe 3: +9 %")
	check_near(_ability(&"erdbeben").get_number_for(_w, "werte.flaeche_radius"), 11.0, 0.001, "Schlachtenlärm 3: 11 m")
	check_near(_ability(&"toedlicher_stoss").get_number_for(_w, "abklingzeit"), 3.0, 0.001, "Kriegsveteran 3: 3 s")
	# Überwältigen nach Ausweichen
	_rage(0.0)
	check_equal(_use(&"ueberwaeltigen"), AbilityError.Code.NEED_AURA, "Überwältigen ohne Ausweichen: nein")
	Combat.notify_event(_w, Combat.Event.TARGET_DODGED, _dummy, 10.0)
	check(_aura(_w, &"ueberwaeltigen_bereit") != null, "Nach Ausweichen des Ziels verfügbar")
	check_near(_aura(_w, &"ueberwaeltigen_bereit").duration, 5.0, 0.001, "5 s")
	_dummy.get_stats().remove_source(TEST_SOURCE)
	_dummy.get_stats().add_modifier(StatModifier.create(TEST_SOURCE, "", &"dodge", 100.0))
	var before := _dummy.get_stats().health
	check_equal(_use(&"ueberwaeltigen"), AbilityError.Code.OK, "Überwältigen")
	check(_lost(_dummy, before) > 0.0, "Kann nicht verfehlen (Puppe weicht sonst immer aus)")
	check(_aura(_w, &"ueberwaeltigen_bereit") == null, "Verbraucht")
	# Echtes Ausweichen löst es aus (Ausweichen höchstens 30 %, daher mehrmals).
	for i in 40:
		_use(&"hieb")
		if _aura(_w, &"ueberwaeltigen_bereit") != null:
			break
	check(_aura(_w, &"ueberwaeltigen_bereit") != null, "Ausgewichener Hieb: Überwältigen bereit")
	_clean()
	_use(&"schlachtfeld_herrschaft")
	Combat.notify_event(_w, Combat.Event.HIT, _near, 10.0)
	check_equal(_stacks(_near, &"tiefe_wunde"), 1, "Schlachtfeld-Herrschaft: jeder Treffer eine Wunde")
	_clean()
	_dummy.get_stats().set_health(_dummy.get_stats().max_health * 0.5)
	_w.get_combat().apply_aura(GameData.get_aura(&"ploetzlicher_tod"), _w)
	check_equal(_w.get_caster_node().get_requirement_block(_ability(&"hinrichten"), _dummy)[0], AbilityError.Code.OK,
			"Plötzlicher Tod: Hinrichten unabhängig vom Leben")
	_rage(10.0)
	check_equal(_use(&"zerschmettern"), AbilityError.Code.OK, "Hinrichten bei 50 %")
	check(_aura(_w, &"ploetzlicher_tod") == null, "Plötzlicher Tod verbraucht")
	# Satz B
	_setup(&"warrior_schlachtmeister", SETS[6][1])
	_use(&"hieb")
	check_near(_aura(_dummy, &"tiefe_wunde").duration, 18.0, 0.001, "Ausbluten 3: Wunde 18 s")
	check_near(_ability(&"hinrichten").get_number_for(_w, "werte.krit_bonus"), 15.0, 0.001, "Gnadenlos 3: +15 % Krit")
	# Zerreißen: 15 % je Tick (Zufall, 200 Ticks); Wut aus dem Schaden abziehen.
	var procs := 0
	for i in 200:
		_rage(0.0)
		var health := _dummy.get_stats().health
		_tick_auras(_dummy)
		var from_damage := maxf(0.0, health - _dummy.get_stats().health) * Data.konstante(&"wut_pro_schaden_ausgeteilt")
		if _w.get_stats().rage > from_damage + 1.0:
			procs += 1
	check(procs > 5 and procs < 70, "Zerreißen 3: etwa 15 %% der Ticks erzeugen 5 Wut (%d von 200)" % procs)
	# Taktiker und Blutige Ernte
	_clean()
	_use(&"hieb")
	_use(&"hieb")
	_dummy.get_stats().set_health(10.0)
	_rage(10.0)
	_use(&"zerschmettern")
	check(_w.get_stats().rage >= 20.0, "Taktiker: Ziel stirbt → 20 Wut zurück")
	check_equal(_stacks(_near, &"tiefe_wunde"), 2, "Blutige Ernte: Wunden auf nahe Ziele verbreitet")
	_clean()
	_use(&"kolossales_schmettern")
	check_near(_w.get_stats().get_value(&"penetration_pct"), 30.0, 0.01, "Kolossales Schmettern: 30 % Durchschlag")
	_clean()
	_use(&"klingenschwung")
	var near_before := _near.get_stats().health
	Combat.notify_event(_w, Combat.Event.HIT, _dummy, 100.0)
	check_near(_lost(_near, near_before), 100.0, 0.5, "Klingenschwung: Treffer auch am zweiten Ziel")


# --- Vergleiche über 60 s ----------------------------------------------------

## Prioritätenliste je Spezialisierung (Grundfähigkeiten; der Host löst die
## Varianten auf).
const ROTATION := {
	&"warrior_berserker": [&"kampfschrei", &"schildschlag", &"zerschmettern", &"hieb"],
	&"warrior_schlachtmeister": [&"kampfschrei", &"zerschmettern", &"schildschlag", &"donnerknall", &"hieb"],
}


## Schaden pro Sekunde an der Schadenspuppe über seconds Sekunden. Ab
## execute_from hat die Puppe 15 % Leben (Hinrichten-Phase).
func _simulate(spec: StringName, ranks: Dictionary, seconds: float, execute_from: float) -> float:
	_setup(spec, ranks)
	_w.get_stats().remove_source(TEST_SOURCE)
	Combat._random.seed = 53
	seed(53)
	_near.global_position = Vector3(40.0, 0.0, 0.0)
	_dummy._reset()
	var caster := _w.get_caster_node()
	var players: Array[PlayerCharacter] = [_w]
	var dummies: Array[TrainingDummy] = [_dummy]
	var step := 0.1
	var elapsed := 0.0
	while elapsed < seconds - 0.001:
		var stats := _dummy.get_stats()
		stats.set_health(stats.max_health * (0.15 if elapsed >= execute_from else 1.0))
		for id: StringName in ROTATION[spec]:
			if int(caster.host_use(_ability(id), _dummy)[0]) == AbilityError.Code.OK:
				break
		_advance(step, players, dummies)
		elapsed += step
	return _dummy._total / seconds


func test_schadensvergleich_berserker_schlachtmeister() -> void:
	var results := {}
	for label: String in ["ohne Talente", "mit Talenten"]:
		for spec: StringName in [&"warrior_berserker", &"warrior_schlachtmeister"]:
			var ranks: Dictionary = {} if label == "ohne Talente" \
					else (SETS[3][1] if spec == &"warrior_berserker" else SETS[5][1])
			var plain := _simulate(spec, ranks, 60.0, 999.0)
			var with_execute := _simulate(spec, ranks, 60.0, 48.0)
			results["%s %s" % [spec, label]] = [plain, with_execute]
	_clean()
	print("Schadensvergleich 60 s an der Schadenspuppe (Stufe 30, Schaden pro Sekunde: ohne / mit Hinrichten-Phase in den letzten 12 s):")
	for key: String in results:
		print("  %s: %d / %d" % [key, roundi(results[key][0]), roundi(results[key][1])])
	for label: String in ["ohne Talente", "mit Talenten"]:
		var berserker: Array = results["warrior_berserker %s" % label]
		var master: Array = results["warrior_schlachtmeister %s" % label]
		var ratio := float(master[1]) / maxf(1.0, float(berserker[1]))
		# Ohne Talente eng, mit Talenten grob (Balancing der Talente folgt).
		var tolerance := 0.15 if label == "ohne Talente" else 0.35
		check(ratio > 1.0 - tolerance and ratio < 1.0 + tolerance,
				"%s: Schlachtmeister und Berserker ähnlich (60 s mit Hinrichten-Phase, Verhältnis %.2f)" % [label, ratio])
		check(float(master[1]) > float(master[0]), "%s: Schlachtmeister hat ein starkes Ende" % label)


func test_bollwerk_haelt_drei_angriffspuppen() -> void:
	_setup(&"warrior_bollwerk")
	_w.get_stats().remove_source(TEST_SOURCE)
	Combat._random.seed = 53
	seed(53)
	var attackers: Array[TrainingDummy] = []
	for index in 3:
		attackers.append(_spawn_dummy("Angriff%d" % index, &"angriffspuppe", Vector3(-2.5 + 2.5 * index, 0.0, -3.0)))
	_dummy.global_position = Vector3(40.0, 0.0, 0.0)
	_near.global_position = Vector3(42.0, 0.0, 0.0)
	var dd := _spawn_player("2", Vector3(0.0, 0.0, -5.5))
	dd.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.0, 1.0)), Vector3(0.0, 0.0, -5.5))
	dd.get_stats().set_level_override(30)
	dd.get_talents().host_load({"spec": "warrior_berserker"})
	dd.get_stats().set_flag(StatBlock.FLAG_MELEE_WEAPON, true)
	var players: Array[PlayerCharacter] = [_w, dd]
	var tank_caster := _w.get_caster_node()
	var dd_caster := dd.get_caster_node()
	var focus := attackers[1]
	var tank_rotation := [&"donnerknall", &"schildschlag", &"zerschmettern", &"hieb"]
	var lost_targets := 0
	var elapsed := 0.0
	while elapsed < 30.0:
		# Tank: Spott auf jede Puppe, die jemand anderen angreift.
		for attacker in attackers:
			var target := attacker.get_combat().get_threat_target()
			if target != null and target != _w:
				tank_caster.host_use(_ability(&"spott"), attacker)
		for id: StringName in tank_rotation:
			if int(tank_caster.host_use(_ability(id), focus)[0]) == AbilityError.Code.OK:
				break
		if elapsed >= 2.0:
			for id: StringName in ROTATION[&"warrior_berserker"]:
				if int(dd_caster.host_use(_ability(id), focus)[0]) == AbilityError.Code.OK:
					break
		_advance(0.1, players, attackers)
		elapsed += 0.1
		if elapsed >= 3.0:
			for attacker in attackers:
				if attacker.get_combat().get_threat_target() != _w:
					lost_targets += 1
	var lines: PackedStringArray = []
	for attacker in attackers:
		var combat := attacker.get_combat()
		lines.append("%s: Tank %d, Schaden %d" % [attacker.name, roundi(combat.get_threat_of(_w)),
				roundi(combat.get_threat_of(dd))])
		check(combat.get_threat_target() == _w, "%s greift den Tank an" % attacker.name)
	print("Bollwerk gegen drei Angriffspuppen (30 s, Bedrohung): ", ", ".join(lines))
	check_equal(lost_targets, 0, "Keine Puppe wechselt ab Sekunde 3 auf den Schadensspieler")
	check(not _w.is_dead(), "Der Tank lebt")
	check(_w.get_stats().health > _w.get_stats().max_health * 0.5, "und hat mehr als die Hälfte seines Lebens")
	for attacker in attackers:
		attacker.free()
	dd.free()
