extends TestSuite
## Tests des Magiers (Ticket #22) mit einer echten Spielfigur und drei
## Schadenspuppen (ohne Netzwerk ist die eigene Instanz der Host):
## - jede Fähigkeit (Grundzauber, Varianten, Talent-Fähigkeiten) über den
##   echten Weg (UnitCaster.host_use: Prüfungen, Kosten, Abklingzeit,
##   Effekte) gegen eine Übungspuppe,
## - Brand (Stapel, Ticks, Explosion), Verlangsamung und eisige Flächen,
##   Ladung und Donnerschlag, Schilde, Schritt, Fessel,
## - die Talente der drei Bäume,
## - Manaverbrauch (Blitz am höchsten) und Bereinigen alter Leisten.
##
## Zeit: Ticks von Auren und Flächen, Projektile und Zauberzeiten werden von
## Hand vorgespult (Hilfen unten), damit die Tests ohne Warten laufen.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE := preload("res://scenes/units/training_dummy.tscn")

var _root: Node3D = null
var _effects: Node3D = null
var _mage: PlayerCharacter = null
## Hauptziel 10 m vor dem Magier, „nah“ 3 m daneben, „fern“ 25 m daneben.
var _dummy: TrainingDummy = null
var _near: TrainingDummy = null
var _far: TrainingDummy = null


func before_all() -> void:
	_root = Node3D.new()
	_root.name = "MageTest"
	tree.root.add_child(_root)
	_effects = Node3D.new()
	_effects.name = "Effects"
	_effects.add_to_group(GroundArea.CONTAINER_GROUP)
	_root.add_child(_effects)
	_mage = PLAYER_SCENE.instantiate()
	_mage.name = "1"
	_mage.display_name = "Magier"
	_mage.race_id = &"human"
	_mage.class_id = &"mage"
	_root.add_child(_mage)
	_dummy = _spawn("Puppe", Vector3(0.0, 0.0, -10.0))
	_near = _spawn("Nah", Vector3(3.0, 0.0, -10.0))
	_far = _spawn("Fern", Vector3(25.0, 0.0, -10.0))


func after_all() -> void:
	if _root != null:
		_root.free()


func _spawn(node_name: String, position: Vector3) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.name = node_name
	dummy.dummy_id = &"schadenspuppe_10"
	dummy.position = position
	_root.add_child(dummy)
	return dummy


# --- Hilfen ------------------------------------------------------------------

## Stufe 30 (kein Verfehlen gegen Stufe-10-Puppen), Spezialisierung und Ränge.
func _setup(spec := "", ranks := {}) -> void:
	_clean()
	_mage.get_stats().set_level_override(30)
	_mage.get_talents().host_load({"spec": spec, "ranks": ranks})
	_mage.get_stats().refill()


## Puppen, Flächen, Projektile und sichtbare Auren des Magiers zurücksetzen.
func _clean() -> void:
	for child in _effects.get_children():
		child.free()
	for dummy: TrainingDummy in [_dummy, _near, _far]:
		dummy.get_combat().remove_all_auras(true)
		dummy.get_stats().refill()
	_mage.get_combat().remove_all_auras(false)
	_mage.global_transform = Transform3D.IDENTITY
	_mage.get_stats().refill()
	_mage.get_caster_node().host_reset_cooldowns()
	_mage.get_stats().set_in_combat(false)


func _ability(id: StringName) -> AbilityData:
	return GameData.get_ability(id)


## Fähigkeit über den echten Weg (Prüfungen, Kosten, Abklingzeit, Effekte);
## Zauberzeit und Kanalisieren werden vorgespult. Gibt den Code zurück.
func _use(id: StringName, target: Unit = null) -> int:
	var caster := _mage.get_caster_node()
	caster.host_reset_cooldowns()
	var result := caster.host_use(_ability(id), target if target != null else _dummy)
	_finish_cast()
	_flush()
	return int(result[0])


func _finish_cast() -> void:
	var caster := _mage.get_caster_node()
	if caster._cast.is_empty():
		return
	var shift := float(caster._cast["end"]) - float(caster._cast["start"]) + 0.01
	for key: String in ["start", "end", "next_tick"]:
		caster._cast[key] = float(caster._cast[key]) - shift
	caster._process_cast(Network.host_time())


## Projektile sofort einschlagen lassen.
func _flush() -> void:
	for pass_index in 3:
		for node in _effects.get_children():
			if node is Projectile and not node.is_queued_for_deletion():
				(node as Projectile)._process(100.0)


func _areas() -> Array[GroundArea]:
	var result: Array[GroundArea] = []
	for node in _effects.get_children():
		if node is GroundArea and not node.is_queued_for_deletion():
			result.append(node)
	return result


func _tick_areas() -> void:
	for area in _areas():
		area._tick()


## Einen Tick aller Auren einer Einheit sofort auslösen.
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


func _stacks(unit: Unit, aura_id: StringName) -> int:
	return unit.get_combat().get_stacks(aura_id)


func _aura(unit: Unit, aura_id: StringName) -> AuraInstance:
	for inst in unit.get_combat().get_auras():
		if inst.data.id == aura_id:
			return inst
	return null


func _lost(dummy: Unit, before: float) -> float:
	return before - dummy.get_stats().health


func _sp() -> float:
	return _mage.get_stats().get_value(&"spell_power")


## Grundschaden einer Zeile (Grundwert + Faktor × Zaubermacht).
func _base(id: StringName, base_key := "grundwert", factor_key := "faktor") -> float:
	var ability := _ability(id)
	return ability.get_number_for(_mage, base_key) + ability.get_number_for(_mage, factor_key) * _sp()


# --- Daten -------------------------------------------------------------------

func test_grundzauber_und_stufen() -> void:
	var mage := GameData.get_class_data(&"mage")
	var expected := {&"magisches_geschoss": 1, &"magische_beruehrung": 2, &"magischer_einschlag": 4,
			&"magischer_schild": 5, &"magischer_schritt": 6, &"magische_nova": 8, &"magische_fessel": 9}
	check_equal(mage.abilities.size(), 7, "7 Grundzauber")
	for ability in mage.abilities:
		check(expected.has(ability.id), "%s ist ein Grundzauber" % ability.id)
		check_equal(ability.required_level, int(expected.get(ability.id, 0)), "%s: Stufe" % ability.id)
		check(ability.is_spell and ability.get_school() == &"arkan", "%s: Zauber der Schule Arkan" % ability.id)
		check_equal(ability.get_cost_resource(), &"mana", "%s kostet Mana" % ability.id)
	check_near(_ability(&"magisches_geschoss").get_cast_time(), 2.0, 0.001, "Geschoss 2,0 s")
	check_near(_ability(&"magischer_einschlag").get_cast_time(), 2.5, 0.001, "Einschlag 2,5 s")
	check_near(_ability(&"magischer_einschlag").get_cooldown(), 10.0, 0.001, "Einschlag 10 s Abklingzeit")
	check_near(_ability(&"magischer_schild").get_cooldown(), 30.0, 0.001, "Schild 30 s")
	check_near(_ability(&"magischer_schritt").get_cooldown(), 15.0, 0.001, "Schritt 15 s")
	check_near(_ability(&"magische_nova").get_cooldown(), 20.0, 0.001, "Nova 20 s")
	check_near(_ability(&"magische_fessel").get_cast_time(), 1.5, 0.001, "Fessel 1,5 s")
	check_near(_ability(&"magische_fessel").get_cooldown(), 20.0, 0.001, "Fessel 20 s")
	check_near(_ability(&"magisches_geschoss").get_range(), 30.0, 0.001, "Geschoss 30 m")
	_setup()
	_mage.get_stats().set_level_override(4)
	var abilities := _mage.get_abilities()
	check(abilities.is_learned(_ability(&"magischer_einschlag")), "Stufe 4: Einschlag erlernt")
	check(not abilities.is_learned(_ability(&"magischer_schild")), "Stufe 4: Schild noch nicht")


func test_schulen_an_allen_faehigkeiten() -> void:
	for ability in GameData.get_abilities():
		if ability.class_id != &"mage":
			continue
		check(ability.school != &"" and Data.schadensschule(ability.school) != null,
				"%s ist mit einer Schule gekennzeichnet" % ability.id)
	check_equal(_ability(&"feuerball").get_school(), &"feuer", "Feuerball: Feuer")
	check_equal(_ability(&"frostblitz").get_school(), &"frost", "Frostblitz: Frost")
	check_equal(_ability(&"blitzpfeil").get_school(), &"blitz", "Blitzpfeil: Blitz")


func test_verwandlungen_wie_in_der_tabelle() -> void:
	var table := {
		&"mage_feuer": [&"feuerball", &"entzuenden", &"meteor", &"feuernova", &"flammenschild", &"flammensprung", &"flammenfessel"],
		&"mage_frost": [&"frostblitz", &"erfrierung", &"gletschersplitter", &"frostnova", &"eisschild", &"frostschritt", &"eisfessel"],
		&"mage_blitz": [&"blitzpfeil", &"elektrisieren", &"donnerschlag", &"gewitternova", &"sturmschild", &"blitzsprung", &"statische_fessel"],
	}
	var bases := [&"magisches_geschoss", &"magische_beruehrung", &"magischer_einschlag", &"magische_nova",
			&"magischer_schild", &"magischer_schritt", &"magische_fessel"]
	for spec: StringName in table:
		_setup(spec)
		for index in bases.size():
			var resolved := _mage.get_abilities().resolve(_ability(bases[index]))
			check_equal(resolved.id, table[spec][index], "%s: %s → %s" % [spec, bases[index], table[spec][index]])
	check_near(_ability(&"feuerball").get_cast_time(), 3.0, 0.001, "Feuerball 3,0 s")
	check_near(_ability(&"frostblitz").get_cast_time(), 1.5, 0.001, "Frostblitz 1,5 s")
	check_near(_ability(&"blitzpfeil").get_cast_time(), 1.2, 0.001, "Blitzpfeil 1,2 s")
	check(_ability(&"blitzpfeil").get_cost() > _ability(&"magisches_geschoss").get_cost(), "Blitzpfeil kostet mehr Mana")
	check_near(_ability(&"meteor").get_cast_time(), 3.0, 0.001, "Meteor 3,0 s")
	check_near(_ability(&"gletschersplitter").get_cast_time(), 2.0, 0.001, "Gletschersplitter 2,0 s")
	check_near(_ability(&"donnerschlag").get_cast_time(), 1.5, 0.001, "Donnerschlag 1,5 s")


# --- Jede Fähigkeit gegen die Übungspuppen -----------------------------------

func test_jede_faehigkeit_gegen_puppen() -> void:
	# Je Spezialisierung zwei gültige Stände, damit jede Talent-Fähigkeit vorkommt.
	var sets := [
		[&"", {}],
		[&"mage_feuer", {"hitzewelle": 1, "glutkern": 3, "flammensalve": 1, "verbrennung": 3, "feuriger_pfad": 1,
				"kettenreaktion": 3, "inferno": 1}],
		[&"mage_feuer", {"schwelbrand": 1, "funkenflug": 3, "glutbombe": 1, "aschenregen": 3, "phoenixschild": 1,
				"gluehende_gedanken": 3, "sonnenzorn": 1}],
		[&"mage_frost", {"eiskalte_praezision": 1, "permafrost": 3, "schneesturm": 1, "kaeltefront": 3, "eisblock": 1,
				"lawine": 3, "absoluter_nullpunkt": 1}],
		[&"mage_frost", {"klirrende_kaelte": 1, "frostbiss": 3, "eissplittersalve": 1, "eisige_adern": 3,
				"splitterpanzer": 1, "kalter_kreislauf": 3, "eiszeit": 1}],
		[&"mage_blitz", {"ueberspannung": 1, "leitfaehigkeit": 3, "kettenblitz": 1, "gewitterfront": 3,
				"blitzableiter": 1, "rueckkopplung": 3, "sturmgewalt": 1}],
		[&"mage_blitz", {"funkenschlag": 1, "statische_aufladung": 3, "blitzsalve": 1, "hochspannung": 3,
				"zickzack": 1, "entladung": 3, "kugelblitz": 1}],
	]
	var tested := {}
	# Nah genug für die Novas (Gewitternova 5 m).
	_dummy.global_position = Vector3(0.0, 0.0, -4.0)
	for entry: Array in sets:
		_setup(entry[0], entry[1])
		check_equal(_mage.get_talents().get_ranks(), entry[1], "%s: Stand übernommen" % entry[0])
		var list: Array[AbilityData] = []
		list.append_array(GameData.get_class_data(&"mage").abilities)
		list.append_array(_mage.get_talents().get_granted_abilities())
		for base in list:
			var ability := _mage.get_abilities().resolve(base)
			_clean()
			var before := _dummy.get_stats().health
			var dummy_auras := _dummy.get_combat().get_auras().size()
			var own_auras := _mage.get_combat().get_auras().size()
			var mana := _mage.get_stats().mana
			var code := _use(base.id)
			check_equal(code, AbilityError.Code.OK, "%s: einsetzbar gegen die Puppe (%s)" % [ability.id, AbilityError.text(code)])
			for i in 3:
				_tick_auras(_dummy)
				_tick_auras(_mage)
				_tick_areas()
				_flush()
			var hit := _lost(_dummy, before) > 0.0 or _dummy.get_combat().get_auras().size() > dummy_auras
			var self_effect := _mage.get_combat().get_auras().size() > own_auras \
					or _mage.global_position.length() > 1.0
			check(hit or self_effect, "%s wirkt (Schaden oder Aura an der Puppe, Aura oder Sprung beim Magier)" % ability.id)
			check(_mage.get_stats().mana < mana or ability.get_cost() <= 0.0, "%s kostet Mana" % ability.id)
			tested[ability.id] = true
	_dummy.global_position = Vector3(0.0, 0.0, -10.0)
	for id: StringName in [&"magisches_geschoss", &"feuerball", &"meteor", &"glutbombe", &"sonnenzorn", &"inferno",
			&"frostblitz", &"gletschersplitter", &"schneesturm", &"eissplittersalve", &"eisblock", &"eiszeit",
			&"absoluter_nullpunkt", &"donnerschlag", &"kettenblitz", &"blitzsalve", &"sturmgewalt", &"kugelblitz",
			&"blitzsprung_zickzack", &"flammensalve"]:
		check(tested.has(id), "%s wurde getestet" % id)
	check_equal(tested.size(), 7 + 21 + 14, "Alle 42 Fähigkeiten (7 Grundzauber, 21 Varianten, 14 aus Talenten)")


# --- Feuer: Brand ------------------------------------------------------------

func test_brand_stapelt_tickt_und_explodiert() -> void:
	_setup(&"mage_feuer")
	_use(&"magisches_geschoss")
	check_equal(_stacks(_dummy, &"brand"), 1, "Feuerball: +1 Brand")
	_use(&"magische_beruehrung")
	check_equal(_stacks(_dummy, &"brand"), 3, "Entzünden: +2 Brand")
	for i in 3:
		_use(&"magisches_geschoss")
	check_equal(_stacks(_dummy, &"brand"), 5, "Höchstens 5 Stapel")
	var inst := _aura(_dummy, &"brand")
	check_near(inst.duration, 10.0, 0.01, "Brand hält 10 s")
	inst.expires_at = Network.host_time() + 1.0
	_use(&"magische_beruehrung")
	check(inst.remaining() > 9.0, "Neuer Stapel erneuert die Dauer")
	var before := _dummy.get_stats().health
	_tick_auras(_dummy)
	check(_lost(_dummy, before) >= 5.0 * _base(&"brand") - 0.5, "Tick: Schaden je Stapel × 5")
	# Explosion durch Meteor: verbraucht alle Stapel, Fläche um das Ziel.
	var near_before := _near.get_stats().health
	var far_before := _far.get_stats().health
	_use(&"magischer_einschlag")
	check_equal(_stacks(_dummy, &"brand"), 0, "Meteor verbraucht den Brand")
	var per_stack := _base(&"brand", "werte.explosion_schaden", "werte.explosion_faktor")
	check(_lost(_near, near_before) >= 5.0 * per_stack - 0.5, "Explosion trifft das nahe Ziel (Schaden je Stapel)")
	check_equal(_far.get_stats().health, far_before, "Fernes Ziel bleibt unberührt")
	# Ohne Brand keine Explosion.
	near_before = _near.get_stats().health
	_use(&"magischer_einschlag")
	check_equal(_near.get_stats().health, near_before, "Ohne Brand keine Explosion")


func test_feuer_talente() -> void:
	# Schwelbrand: 3 Brand, 15 s.
	_setup(&"mage_feuer", {"schwelbrand": 1})
	_use(&"magische_beruehrung")
	check_equal(_stacks(_dummy, &"brand"), 3, "Schwelbrand: Entzünden legt 3 Brand")
	check_near(_aura(_dummy, &"brand").duration, 15.0, 0.01, "Schwelbrand: Brand hält 15 s")
	# Funkenflug: Feuernova −3 s je Rang.
	_setup(&"mage_feuer", {"schwelbrand": 1, "funkenflug": 3})
	check_near(_ability(&"feuernova").get_number_for(_mage, "abklingzeit"), 11.0, 0.01, "Funkenflug 3: 20 − 9 s")
	# Glutkern: +1 m je Rang (Fernes Ziel liegt außerhalb, nahe Ziel immer drin).
	_setup(&"mage_feuer", {"schwelbrand": 1, "glutkern": 3})
	check_near(_ability(&"brand").get_number_for(_mage, "werte.radius"), 8.0, 0.01, "Glutkern 3: Radius 5 + 3")
	# Kettenreaktion 3/3: Explosionen legen sicher 1 Brand auf alle Getroffenen.
	_setup(&"mage_feuer", {"hitzewelle": 1, "glutkern": 3, "flammensalve": 1, "verbrennung": 3, "feuriger_pfad": 1,
			"kettenreaktion": 3})
	_use(&"magische_beruehrung")
	_use(&"magischer_einschlag")
	check_equal(_stacks(_near, &"brand"), 1, "Kettenreaktion: nahes Ziel bekommt 1 Brand")
	check_equal(_stacks(_dummy, &"brand"), 1, "Kettenreaktion: Hauptziel bekommt 1 Brand")
	# Verbrennung: Zuschlag nur für den Wurf, danach wieder normal.
	var crit_before := _mage.get_stats().get_value(&"crit_chance")
	_use(&"magisches_geschoss")
	check_near(_mage.get_stats().get_value(&"crit_chance"), crit_before, 0.001, "Krit-Zuschlag nur für den Wurf")
	check_near(_ability(&"feuerball").get_number_for(_mage, "werte.krit_je_brand"), 6.0, 0.01, "Verbrennung 3: 6 % je Brand")
	# Hitzewelle: Kritischer Feuerball → Meteor sofort.
	var crit := false
	for i in 200:
		_use(&"magisches_geschoss")
		if _stacks(_mage, &"hitzewelle") > 0:
			crit = true
			break
	check(crit, "Hitzewelle: nach einem kritischen Feuerball liegt „Hitzewelle“")
	var caster := _mage.get_caster_node()
	check_equal(caster.get_cast_type(_ability(&"meteor")), AbilityData.CastType.INSTANT, "Meteor ist sofort wirkbar")
	check(_mage.get_abilities().get_slot_state(_ability(&"magischer_einschlag"))["highlight"], "Slot leuchtet")
	caster.host_reset_cooldowns()
	caster.host_use(_ability(&"magischer_einschlag"), _dummy)
	check(caster._cast.is_empty(), "Meteor ohne Zauberzeit")
	check_equal(_stacks(_mage, &"hitzewelle"), 0, "Hitzewelle verbraucht")
	# Feuriger Pfad: Flammensprung legt Flächen, die Brand legen.
	_clean()
	_use(&"magischer_schritt")
	check_equal(_areas().size(), 4, "Feuriger Pfad: 4 Flächen auf der Strecke")
	check(_mage.global_position.distance_to(Vector3(0.0, 0.0, -15.0)) < 0.5 or _mage.global_position.z < -5.0,
			"Flammensprung springt nach vorn")


func test_feuer_talente_explosionen() -> void:
	# Aschenregen 3: brennender Boden 3 s; Glühende Gedanken 3: Meteor −3 s je Explosion.
	_setup(&"mage_feuer", {"schwelbrand": 1, "funkenflug": 3, "glutbombe": 1, "aschenregen": 3, "phoenixschild": 1,
			"gluehende_gedanken": 3})
	_use(&"magische_beruehrung")
	var caster := _mage.get_caster_node()
	caster.host_reset_cooldowns()
	caster.host_use(_ability(&"magischer_einschlag"), _dummy)
	_finish_cast()
	check_equal(_areas().size(), 1, "Aschenregen: brennender Boden nach der Explosion")
	if not _areas().is_empty():
		check_near(_areas()[0].expires_at - Network.host_time(), 3.0, 0.1, "Aschenregen 3: 3 s")
	var meteor := _ability(&"meteor")
	var remaining := caster.get_cooldown(meteor).x
	check(remaining > 6.5 and remaining < 7.1, "Glühende Gedanken 3: Meteor 10 − 3 s (%s)" % remaining)
	# Glutbombe: Explosion beim Ablauf, lässt den Brand explodieren.
	_clean()
	_use(&"magische_beruehrung")
	_use(&"glutbombe")
	check_equal(_stacks(_dummy, &"glutbombe"), 1, "Glutbombe liegt")
	var near_before := _near.get_stats().health
	_expire(_dummy, &"glutbombe")
	check_equal(_stacks(_dummy, &"brand"), 0, "Glutbombe lässt den Brand explodieren")
	check(_lost(_near, near_before) > 0.0, "Explosion trifft das nahe Ziel")
	# Phönixschild: Flammenschild verhindert einmal tödlichen Schaden.
	_clean()
	_use(&"magischer_schild")
	var stats := _mage.get_stats()
	Combat.deal_damage(_dummy, _mage, stats.health * 10.0, &"physisch")
	check(not _mage.is_dead(), "Phönixschild: überlebt tödlichen Schaden")
	check_equal(_stacks(_mage, &"phoenix_erschoepft"), 1, "Danach erschöpft (2 Minuten)")
	Combat.deal_damage(_dummy, _mage, stats.health * 10.0, &"physisch")
	check(_mage.is_dead(), "Zweiter tödlicher Treffer: tot")
	stats.revive(100.0, 100.0)
	_mage.get_combat().check_death()
	_mage.get_combat().remove_aura(&"phoenix_erschoepft")


func test_inferno_und_sonnenzorn() -> void:
	_setup(&"mage_feuer", {"hitzewelle": 1, "glutkern": 3, "flammensalve": 1, "verbrennung": 3, "feuriger_pfad": 1,
			"kettenreaktion": 3, "inferno": 1})
	_use(&"inferno")
	check_equal(_stacks(_mage, &"inferno"), 1, "Inferno liegt")
	check_near(_ability(&"feuerball").get_number_for(_mage, "werte.krit_schaden_bonus"), 50.0, 0.01,
			"Inferno: Feuerball +50 % kritischer Schaden")
	var near_before := _near.get_stats().health
	_use(&"magische_beruehrung")
	_use(&"magische_beruehrung")
	_use(&"magisches_geschoss")
	check(_stacks(_dummy, &"brand") < 5, "Inferno: bei 5 Stapeln explodiert der Brand sofort")
	check(_lost(_near, near_before) > 0.0, "Automatische Explosion trifft das nahe Ziel")
	# Sonnenzorn verbraucht Brand für Bonusschaden.
	_setup(&"mage_feuer", {"schwelbrand": 1, "funkenflug": 3, "glutbombe": 1, "aschenregen": 3, "phoenixschild": 1,
			"gluehende_gedanken": 3, "sonnenzorn": 1})
	_use(&"magische_beruehrung")
	check_equal(_stacks(_dummy, &"brand"), 3, "3 Brand vor Sonnenzorn")
	var before := _dummy.get_stats().health
	_use(&"sonnenzorn")
	check_equal(_stacks(_dummy, &"brand"), 0, "Sonnenzorn verbraucht den Brand")
	# Ohne Krit mindestens Grundschaden × (1 + 3 × 20 %).
	check(_lost(_dummy, before) >= _base(&"sonnenzorn") * 1.6 - 1.0,
			"Sonnenzorn: Bonusschaden je Brand (%s, Grundschaden %s)" % [_lost(_dummy, before), _base(&"sonnenzorn")])


# --- Frost: Verlangsamung und Flächen ----------------------------------------

func test_verlangsamung() -> void:
	_setup(&"mage_frost")
	_use(&"magisches_geschoss")
	check(_dummy.get_combat().has_state(Combat.STATE_SLOWED), "Frostblitz verlangsamt")
	check_near(_dummy.get_combat().get_slow_percent(), 30.0, 0.01, "30 %")
	check_near(_aura(_dummy, &"kaelte").duration, 6.0, 0.01, "für 6 s")
	# Frostnova: 60 % für 4 s, stärkere überschreibt schwächere.
	_dummy.global_position = Vector3(0.0, 0.0, -5.0)
	_use(&"magische_nova")
	check_near(_dummy.get_combat().get_slow_percent(), 60.0, 0.01, "Frostnova: 60 % (stärkste gilt)")
	check_near(_aura(_dummy, &"tiefe_kaelte").duration, 4.0, 0.01, "für 4 s")
	_dummy.global_position = Vector3(0.0, 0.0, -10.0)
	# Erfrierung: Schaden über Zeit und Verlangsamung.
	_clean()
	_use(&"magische_beruehrung")
	check_equal(_stacks(_dummy, &"erfrierung"), 1, "Erfrierung liegt")
	check(_dummy.get_combat().has_state(Combat.STATE_SLOWED), "Erfrierung verlangsamt")
	var before := _dummy.get_stats().health
	_tick_auras(_dummy)
	check(_lost(_dummy, before) > 0.0, "Erfrierung: Schaden über Zeit")
	# Klirrende Kälte: 50 % länger.
	_setup(&"mage_frost", {"klirrende_kaelte": 1})
	_use(&"magisches_geschoss")
	check_near(_aura(_dummy, &"kaelte").duration, 9.0, 0.01, "Klirrende Kälte: 6 × 1,5 = 9 s")


func test_eisige_flaechen() -> void:
	_setup(&"mage_frost")
	_use(&"magischer_einschlag")
	var areas := _areas()
	check_equal(areas.size(), 1, "Gletschersplitter hinterlässt eine eisige Fläche")
	if areas.is_empty():
		return
	check_near(areas[0].radius, 5.0, 0.01, "Radius 5 m")
	check_near(areas[0].expires_at - Network.host_time(), 6.0, 0.1, "6 s")
	_dummy.get_combat().remove_all_auras(true)
	var before := _dummy.get_stats().health
	_tick_areas()
	check(_lost(_dummy, before) > 0.0, "Fläche: Schaden über Zeit")
	check(_dummy.get_combat().has_state(Combat.STATE_SLOWED), "Fläche verlangsamt")
	check(_near.get_combat().has_state(Combat.STATE_SLOWED), "Auch das nahe Ziel in der Fläche")
	check(not _far.get_combat().has_state(Combat.STATE_SLOWED), "Ferne Ziel nicht")
	# Permafrost 3 (+3 s) und Lawine 3 (+3 m), Absoluter Nullpunkt (doppelt so groß).
	_setup(&"mage_frost", {"eiskalte_praezision": 1, "permafrost": 3, "schneesturm": 1, "kaeltefront": 3, "eisblock": 1,
			"lawine": 3, "absoluter_nullpunkt": 1})
	_use(&"magischer_einschlag")
	check_near(_areas()[0].radius, 8.0, 0.01, "Lawine 3: 5 + 3 m")
	check_near(_areas()[0].expires_at - Network.host_time(), 9.0, 0.1, "Permafrost 3: 6 + 3 s")
	_clean()
	_use(&"absoluter_nullpunkt")
	_use(&"magischer_einschlag")
	check_near(_areas()[0].radius, 16.0, 0.01, "Absoluter Nullpunkt: doppelt so groß")
	# Kältefront 3: Frostnova hinterlässt eine Fläche (6 s + Permafrost 3 s).
	_clean()
	_use(&"magische_nova")
	check_equal(_areas().size(), 1, "Kältefront: Fläche nach Frostnova")
	if not _areas().is_empty():
		check_near(_areas()[0].expires_at - Network.host_time(), 9.0, 0.1, "Kältefront 3 + Permafrost 3: 9 s")
	_setup(&"mage_frost")
	_use(&"magische_nova")
	check_equal(_areas().size(), 0, "Ohne Kältefront keine Fläche")


func test_frost_talente() -> void:
	# Eiskalte Präzision: Frostblitz auf verlangsamtes Ziel → Gletschersplitter sofort.
	_setup(&"mage_frost", {"eiskalte_praezision": 1})
	_use(&"magisches_geschoss")
	check_equal(_stacks(_mage, &"eiskalte_praezision"), 0, "Erster Frostblitz: Ziel war nicht verlangsamt")
	_use(&"magisches_geschoss")
	check_equal(_stacks(_mage, &"eiskalte_praezision"), 1, "Zweiter Frostblitz auf verlangsamtes Ziel")
	check_equal(_mage.get_caster_node().get_cast_type(_ability(&"gletschersplitter")), AbilityData.CastType.INSTANT,
			"Gletschersplitter sofort wirkbar")
	_use(&"magischer_einschlag")
	check_equal(_stacks(_mage, &"eiskalte_praezision"), 0, "Verbraucht")
	# Eisige Adern 3: nach Frostschritt 3 Frostblitze sofort.
	_setup(&"mage_frost", {"klirrende_kaelte": 1, "frostbiss": 3, "eissplittersalve": 1, "eisige_adern": 3,
			"splitterpanzer": 1, "kalter_kreislauf": 3})
	_use(&"magischer_schritt")
	check_equal(_stacks(_mage, &"eisige_adern"), 3, "Eisige Adern 3: 3 Stapel")
	_mage.global_transform = Transform3D.IDENTITY
	var caster := _mage.get_caster_node()
	caster.host_reset_cooldowns()
	caster.host_use(_ability(&"magisches_geschoss"), _dummy)
	check(caster._cast.is_empty(), "Frostblitz sofort")
	check_equal(_stacks(_mage, &"eisige_adern"), 2, "Ein Stapel verbraucht")
	# Frostbiss 3: läuft Erfrierung aus, springt sie auf das nahe Ziel.
	_clean()
	_use(&"magische_beruehrung")
	_expire(_dummy, &"erfrierung")
	check_equal(_stacks(_near, &"erfrierung"), 1, "Frostbiss: Erfrierung springt auf das nahe Ziel")
	# Kalter Kreislauf 3: Treffer gegen verlangsamte Ziele geben 3 % Mana.
	_clean()
	_use(&"magisches_geschoss")
	var stats := _mage.get_stats()
	stats.change_resource(&"mana", -stats.max_mana * 0.5)
	var mana := stats.mana
	_use(&"magisches_geschoss")
	var cost := _ability(&"frostblitz").get_cost()
	check_near(stats.mana - (mana - cost), stats.max_mana * 0.03, 1.0, "Kalter Kreislauf 3: +3 % Mana")
	# Splitterpanzer: zerbricht der Eisschild, Schaden und Verlangsamung im Umkreis.
	_clean()
	_mage.global_position = Vector3(0.0, 0.0, -7.0)
	_use(&"magischer_schild")
	var before := _dummy.get_stats().health
	var shield := _aura(_mage, &"eisschild")
	Combat.deal_damage(_dummy, _mage, shield.absorb_left + 1.0, &"physisch")
	check_equal(_stacks(_mage, &"eisschild"), 0, "Eisschild zerbrochen")
	check(_lost(_dummy, before) > 0.0, "Splitter treffen Gegner im Umkreis")
	check(_dummy.get_combat().has_state(Combat.STATE_SLOWED), "und verlangsamen sie")
	_mage.global_transform = Transform3D.IDENTITY


func test_eisblock_und_frost_ueberladungen() -> void:
	_setup(&"mage_frost", {"eiskalte_praezision": 1, "permafrost": 3, "schneesturm": 1, "kaeltefront": 3, "eisblock": 1,
			"lawine": 3, "absoluter_nullpunkt": 1})
	_use(&"magischer_schild")
	check_equal(_stacks(_mage, &"eisblock"), 1, "Eisblock statt Eisschild")
	check(_mage.get_combat().has_state(Combat.STATE_INVULNERABLE), "unverwundbar")
	check(not _mage.get_combat().can_act(), "handlungsunfähig")
	var before := _mage.get_stats().health
	Combat.deal_damage(_dummy, _mage, 100.0, &"physisch")
	check_equal(_mage.get_stats().health, before, "Kein Schaden im Eisblock")
	_clean()
	# Absoluter Nullpunkt: Frostblitz trifft ein zweites Ziel.
	_use(&"absoluter_nullpunkt")
	var near_before := _near.get_stats().health
	_use(&"magisches_geschoss")
	check(_lost(_near, near_before) > 0.0, "Absoluter Nullpunkt: zweites Ziel getroffen")
	# Schneesturm: Fläche am Ziel, Schaden und Verlangsamung.
	_clean()
	before = _dummy.get_stats().health
	_use(&"schneesturm")
	check(_areas().size() >= 5, "Schneesturm: je Tick eine Fläche am Ziel (%d)" % _areas().size())
	_tick_areas()
	check(_lost(_dummy, before) > 0.0 and _dummy.get_combat().has_state(Combat.STATE_SLOWED), "Schneesturm wirkt")
	# Eiszeit: Fläche um den Magier.
	_setup(&"mage_frost", {"klirrende_kaelte": 1, "frostbiss": 3, "eissplittersalve": 1, "eisige_adern": 3,
			"splitterpanzer": 1, "kalter_kreislauf": 3, "eiszeit": 1})
	_use(&"eiszeit")
	before = _dummy.get_stats().health
	_tick_auras(_mage)
	check(_lost(_dummy, before) > 0.0, "Eiszeit: Schaden über Zeit im Umkreis")
	check_near(_dummy.get_combat().get_slow_percent(), 70.0, 0.01, "Eiszeit: stark verlangsamt (70 %)")
	check(_far.get_combat().get_slow_percent() == 0.0, "Außerhalb von 15 m nicht")
	# Eissplittersalve: 5 Splitter.
	_clean()
	before = _dummy.get_stats().health
	var near_hp := _near.get_stats().health
	_use(&"eissplittersalve")
	check(_lost(_dummy, before) + _lost(_near, near_hp) > 0.0, "Eissplittersalve trifft Gegner im Umkreis")


# --- Blitz: Ladung und Donnerschlag ------------------------------------------

func test_ladung_und_donnerschlag() -> void:
	_setup(&"mage_blitz")
	_use(&"magisches_geschoss")
	check_equal(_stacks(_dummy, &"ladung"), 1, "Blitzpfeil: +1 Ladung")
	_use(&"magische_beruehrung")
	check_equal(_stacks(_dummy, &"ladung"), 3, "Elektrisieren: +2 Ladungen")
	check_near(_aura(_dummy, &"ladung").duration, 8.0, 0.01, "Ladung hält 8 s")
	# Jeder Stapel erhöht den Blitzschaden gegen das Ziel.
	var factor := _dummy.get_combat().modify_incoming_damage(100.0, &"blitz", _mage)
	check_near(factor, 115.0, 0.01, "3 Ladungen: +15 % Blitzschaden")
	check_near(_dummy.get_combat().modify_incoming_damage(100.0, &"feuer", _mage), 100.0, 0.01, "Andere Schulen nicht")
	for i in 3:
		_use(&"magisches_geschoss")
	check_equal(_stacks(_dummy, &"ladung"), 5, "Höchstens 5")
	var near_before := _near.get_stats().health
	var far_before := _far.get_stats().health
	var before := _dummy.get_stats().health
	_use(&"magischer_einschlag")
	check_equal(_stacks(_dummy, &"ladung"), 0, "Donnerschlag verbraucht alle Ladungen")
	var main := _lost(_dummy, before)
	var base := _base(&"donnerschlag")
	check(main >= base * 2.0 - 1.0, "Bonusschaden je Ladung (5 × 20 %% = doppelt: %s)" % main)
	check(_lost(_near, near_before) > 0.0, "Springt auf ein weiteres Ziel")
	check_equal(_far.get_stats().health, far_before, "aber nicht auf ein drittes")


func test_blitz_talente() -> void:
	# Überspannung: bei 5 Ladungen ist der nächste Donnerschlag sofort.
	_setup(&"mage_blitz", {"ueberspannung": 1, "leitfaehigkeit": 3, "kettenblitz": 1, "gewitterfront": 3,
			"blitzableiter": 1, "rueckkopplung": 3})
	for i in 2:
		_use(&"magische_beruehrung")
	check_equal(_stacks(_mage, &"ueberspannung"), 0, "4 Ladungen: noch nicht")
	_use(&"magisches_geschoss")
	check_equal(_stacks(_mage, &"ueberspannung"), 1, "5 Ladungen: Überspannung")
	check_equal(_mage.get_caster_node().get_cast_type(_ability(&"donnerschlag")), AbilityData.CastType.INSTANT,
			"Donnerschlag sofort")
	# Gewitterfront 3: 5 Ladungen verbraucht → 6 % Mana.
	var stats := _mage.get_stats()
	stats.change_resource(&"mana", -stats.max_mana * 0.5)
	var mana := stats.mana
	# Leitfähigkeit 3: 3 Ziele; Rückkopplung 3: Sprungziele behalten 1 Ladung.
	_far.global_position = Vector3(6.0, 0.0, -10.0)
	var far_before := _far.get_stats().health
	_use(&"magischer_einschlag")
	check_equal(_stacks(_mage, &"ueberspannung"), 0, "Überspannung verbraucht")
	check_near(stats.mana - (mana - _ability(&"donnerschlag").get_cost()), stats.max_mana * 0.06, 1.0,
			"Gewitterfront 3: +6 % Mana")
	check(_lost(_far, far_before) > 0.0, "Leitfähigkeit: drittes Ziel getroffen")
	check_equal(_stacks(_near, &"ladung"), 1, "Rückkopplung: Sprungziel behält 1 Ladung")
	check_equal(_stacks(_far, &"ladung"), 1, "Rückkopplung: auch das dritte")
	check_near(_ability(&"donnerschlag").get_number_for(_mage, "werte.sprung_prozent"), 95.0, 0.01,
			"Leitfähigkeit 3: Sprungschaden 50 + 45 %")
	_far.global_position = Vector3(25.0, 0.0, -10.0)
	# Kettenblitz: 3 Ziele, je 1 Ladung.
	_clean()
	_far.global_position = Vector3(6.0, 0.0, -10.0)
	_use(&"kettenblitz")
	check(_stacks(_dummy, &"ladung") == 1 and _stacks(_near, &"ladung") == 1 and _stacks(_far, &"ladung") == 1,
			"Kettenblitz: 3 Ziele, je 1 Ladung")
	_far.global_position = Vector3(25.0, 0.0, -10.0)
	# Blitzableiter: Sturmschild betäubt Angreifer, höchstens einmal alle 10 s.
	_clean()
	_dummy.global_position = Vector3(0.0, 0.0, -2.0)
	_use(&"magischer_schild")
	Combat.deal_damage(_dummy, _mage, 10.0, &"physisch")
	check_equal(_stacks(_dummy, &"ladung"), 1, "Sturmschild: Angreifer erhält 1 Ladung")
	check(_dummy.get_combat().has_state(Combat.STATE_STUNNED), "Blitzableiter: betäubt")
	_dummy.get_combat().remove_aura(&"blitzableiter")
	Combat.deal_damage(_dummy, _mage, 10.0, &"physisch")
	check(not _dummy.get_combat().has_state(Combat.STATE_STUNNED), "Blitzableiter: nicht erneut innerhalb von 10 s")
	_dummy.global_position = Vector3(0.0, 0.0, -10.0)
	# Funkenschlag, Statische Aufladung, Hochspannung, Zickzack, Entladung.
	_setup(&"mage_blitz", {"funkenschlag": 1, "statische_aufladung": 3, "blitzsalve": 1, "hochspannung": 3,
			"zickzack": 1, "entladung": 3})
	var extra := false
	for i in 60:
		_dummy.get_combat().remove_all_auras(true)
		_use(&"magisches_geschoss")
		if _stacks(_dummy, &"ladung") == 2:
			extra = true
			break
	check(extra, "Funkenschlag: Blitzpfeil legt manchmal 2 Ladungen")
	check_near(_aura(_dummy, &"ladung").duration, 14.0, 0.01, "Statische Aufladung 3: 8 + 6 s")
	check_near(_ability(&"elektrisieren").get_number_for(_mage, "abklingzeit"), 4.0, 0.01, "Hochspannung 3: 10 − 6 s")
	check_equal(_mage.get_abilities().resolve(_ability(&"magischer_schritt")).id, &"blitzsprung_zickzack", "Zickzack")
	check_equal(_ability(&"blitzsprung_zickzack").get_charges(), 2, "Zickzack: 2 Aufladungen")
	# Entladung 3: Stirbt ein Ziel mit Ladungen, springen sie auf das nächste.
	_clean()
	_use(&"magische_beruehrung")
	_dummy.get_stats().set_health(0.0)
	_dummy.get_combat()._process(0.0)
	check_equal(_stacks(_near, &"ladung"), 2, "Entladung: 2 Ladungen springen auf das nahe Ziel")
	_dummy.get_stats().refill()
	_dummy.get_combat()._process(0.0)


func test_blitz_ueberladungen() -> void:
	_setup(&"mage_blitz", {"ueberspannung": 1, "leitfaehigkeit": 3, "kettenblitz": 1, "gewitterfront": 3,
			"blitzableiter": 1, "rueckkopplung": 3, "sturmgewalt": 1})
	var pfeil := _ability(&"blitzpfeil")
	var cost := pfeil.get_number_for(_mage, "kosten")
	_use(&"sturmgewalt")
	check_near(_mage.get_caster_node().get_cast_time(pfeil), 1.2 * 0.7 / _haste(), 0.01, "Sturmgewalt: −30 % Zauberzeit")
	check_near(pfeil.get_number_for(_mage, "kosten"), cost * 1.5, 0.01, "Sturmgewalt: +50 % Manakosten")
	_use(&"magisches_geschoss")
	check_equal(_stacks(_dummy, &"ladung"), 2, "Sturmgewalt: Blitzpfeil legt 2 Ladungen")
	# Kugelblitz: fliegt geradeaus, trifft alles auf dem Weg einmal, je 2 Ladungen.
	_setup(&"mage_blitz", {"funkenschlag": 1, "statische_aufladung": 3, "blitzsalve": 1, "hochspannung": 3,
			"zickzack": 1, "entladung": 3, "kugelblitz": 1})
	_use(&"kugelblitz")
	var orb := _aura(_mage, &"kugelblitz")
	check(orb != null, "Kugelblitz fliegt")
	if orb == null:
		return
	orb.custom["start"] = Network.host_time() - 9.0 / 6.0
	var before := _dummy.get_stats().health
	_tick_auras(_mage)
	check(_lost(_dummy, before) > 0.0, "Kugel trifft die Puppe auf ihrem Weg")
	check_equal(_stacks(_dummy, &"ladung"), 2, "je 2 Ladungen")
	before = _dummy.get_stats().health
	_tick_auras(_mage)
	check_equal(_dummy.get_stats().health, before, "Jede Einheit nur einmal")
	check(not _areas().is_empty(), "Graubox-Fläche zeigt die Kugel")


func _haste() -> float:
	return 1.0 + _mage.get_stats().get_value(&"haste_pct") / 100.0


# --- Schild, Schritt, Fessel, Nova -------------------------------------------

func test_schild_schritt_fessel() -> void:
	_setup()
	_use(&"magischer_schild")
	var shield := _aura(_mage, &"magischer_schild")
	check(shield != null, "Magischer Schild liegt")
	var expected := _base(&"magischer_schild", "werte.schild", "werte.schild_faktor")
	check_near(shield.absorb_left, expected, 0.01, "Absorption = 100 + 2 × Zaubermacht")
	var before := _mage.get_stats().health
	Combat.deal_damage(_dummy, _mage, 50.0, &"physisch")
	check_equal(_mage.get_stats().health, before, "Schild fängt Schaden ab")
	# Schritt: 15 m nach vorn.
	_clean()
	_use(&"magischer_schritt")
	check_near(_mage.global_position.z, -15.0, 0.01, "Magischer Schritt: 15 m nach vorn")
	_mage.global_transform = Transform3D.IDENTITY
	# Fessel: hält fest, endet bei Schaden.
	_use(&"magische_fessel")
	check(_dummy.get_combat().has_state(Combat.STATE_ROOTED), "Fessel hält fest")
	check_near(_aura(_dummy, &"magische_fessel").duration, 6.0, 0.01, "6 s")
	Combat.deal_damage(_mage, _dummy, 10.0, &"arkan")
	check(not _dummy.get_combat().has_state(Combat.STATE_ROOTED), "Schaden beendet die Fessel")
	# Nova: alle Gegner im Umkreis von 8 m.
	_clean()
	_dummy.global_position = Vector3(0.0, 0.0, -5.0)
	var hp := _dummy.get_stats().health
	var far_hp := _far.get_stats().health
	_use(&"magische_nova")
	check(_lost(_dummy, hp) > 0.0, "Nova trifft im Umkreis")
	check_equal(_far.get_stats().health, far_hp, "nicht außerhalb")
	_dummy.global_position = Vector3(0.0, 0.0, -10.0)


func test_schilde_der_spezialisierungen() -> void:
	_setup(&"mage_feuer")
	_dummy.global_position = Vector3(0.0, 0.0, -2.0)
	_use(&"magischer_schild")
	Combat.deal_damage(_dummy, _mage, 10.0, &"physisch")
	check_equal(_stacks(_dummy, &"brand"), 1, "Flammenschild: Nahkampf-Angreifer erhält 1 Brand")
	Combat.deal_damage(_far, _mage, 10.0, &"physisch")
	check_equal(_stacks(_far, &"brand"), 0, "Fernkampf-Angreifer nicht")
	_setup(&"mage_frost")
	_dummy.global_position = Vector3(0.0, 0.0, -2.0)
	_use(&"magischer_schild")
	Combat.deal_damage(_dummy, _mage, 10.0, &"physisch")
	check(_dummy.get_combat().has_state(Combat.STATE_SLOWED), "Eisschild: Nahkampf-Angreifer verlangsamt")
	_setup(&"mage_blitz")
	_use(&"magischer_schild")
	Combat.deal_damage(_far, _mage, 10.0, &"physisch")
	check_equal(_stacks(_far, &"ladung"), 1, "Sturmschild: jeder Angreifer erhält 1 Ladung")
	_dummy.global_position = Vector3(0.0, 0.0, -10.0)


# --- Mana und Leisten --------------------------------------------------------

func test_blitz_verbraucht_am_meisten_mana() -> void:
	var per_second := {}
	for spec: StringName in [&"mage_feuer", &"mage_frost", &"mage_blitz"]:
		_setup(spec)
		var filler := _mage.get_abilities().resolve(_ability(&"magisches_geschoss"))
		var time := maxf(Data.konstante(&"gcd", 1.5), filler.get_cast_time())
		per_second[spec] = filler.get_cost() / time
	check(per_second[&"mage_blitz"] > per_second[&"mage_feuer"] * 1.4, "Blitz deutlich mehr Mana je Sekunde als Feuer %s" % per_second)
	check(per_second[&"mage_blitz"] > per_second[&"mage_frost"] * 1.4, "und als Frost")


func test_alte_leisten_bereinigen() -> void:
	_setup()
	# Unbekannte IDs (z. B. „gegenzauber“) leert schon ActionBarLayout.load_save
	# (#21, mit Warnung); hier die Fähigkeiten, die es gibt, die aber nicht
	# (mehr) zur Figur gehören.
	var layout := ActionBarLayout.new()
	for entry: Array in [[0, 1, &"feuerball"], [0, 2, &"magisches_geschoss"], [0, 3, &"test_blitz"], [1, 0, &"schildschlag"]]:
		layout.set_content(entry[0], entry[1], ActionSlotContent.ability(entry[2]))
	var removed := _mage.get_abilities().clean_bar_layout(layout)
	check_equal(removed, PackedStringArray(["feuerball", "schildschlag"]),
			"Variante (Feuerball) und fremde Klasse (Schildschlag) entfernt")
	check(layout.get_content(0, 1) == null, "Feuerball (Variante) geleert")
	check_equal(layout.get_content(0, 2).id, &"magisches_geschoss", "Grundzauber bleibt")
	check_equal(layout.get_content(0, 3).id, &"test_blitz", "Testfähigkeit (Allgemein) bleibt")
	check(layout.get_content(1, 0) == null, "Schildschlag (Krieger) geleert")
	_mage.get_talents().host_load({"spec": "mage_frost", "ranks": {"eiskalte_praezision": 1, "permafrost": 3,
			"schneesturm": 1}})
	check(_mage.get_abilities().belongs_to_character(_ability(&"schneesturm")), "Talent-Fähigkeit gehört zur Figur")
	check(_mage.get_abilities().belongs_to_character(_ability(&"eissplittersalve")),
			"auch die andere Wahl (bleibt beim Wechsel auf der Leiste, bis das Talent sie nimmt)")
