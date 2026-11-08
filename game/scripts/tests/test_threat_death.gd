extends TestSuite
## Tests von Bedrohung und Tod mit echten Einheiten (Ticket #35): zwei
## Spielfiguren und eine Angriffspuppe im Baum (ohne Netzwerk ist die eigene
## Instanz der Host). Prüft Bedrohung durch Schaden und Heilung, Faktor der
## Tankhaltung, Zielwechsel, Spott, Zurücksetzen, Kampfzustand durch die
## Liste, Tod (Leben 0, Auren, Listen) und Rückkehr.

const DUMMY_SCENE := preload("res://scenes/units/training_dummy.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _root: Node3D = null
var _dummy: TrainingDummy = null
var _tank: PlayerCharacter = null
var _dd: PlayerCharacter = null


func before_all() -> void:
	_root = Node3D.new()
	_root.name = "ThreatTest"
	tree.root.add_child(_root)
	_dummy = DUMMY_SCENE.instantiate()
	_dummy.name = "Angriffspuppe"
	_dummy.dummy_id = &"angriffspuppe"
	_root.add_child(_dummy)
	_tank = _spawn_player("1", &"warrior", Vector3(0.0, 0.0, -1.5))
	_dd = _spawn_player("2", &"rogue", Vector3(1.5, 0.0, -1.5))


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


func _reset() -> void:
	_dummy.get_combat().clear_threat()
	for player in [_tank, _dd]:
		player.get_stats().refill()
		player.get_combat().remove_all_auras(true)


func test_angriffspuppe_aus_tabelle() -> void:
	check_equal(_dummy.get_kind(), TrainingDummy.Kind.ATTACK, "art „angriff“")
	check(_dummy.get_combat().holds_threat(), "Puppe führt eine Bedrohungsliste")
	check(not _tank.get_combat().holds_threat(), "Spieler führen keine")


func test_bedrohung_durch_schaden_und_faktor() -> void:
	_reset()
	Combat.deal_damage(_tank, _dummy, 100.0, &"physisch")
	check_near(_dummy.get_combat().get_threat_of(_tank), 100.0, 0.01, "100 Schaden = 100 Bedrohung")
	check(_tank.get_stats().is_in_combat(), "Angreifer im Kampf")
	var aura := GameData.get_aura(&"test_tankhaltung")
	_tank.get_combat().apply_aura(aura, _tank)
	check_near(Combat.threat_factor(_tank), 3.0, 0.001, "Tankhaltung: Faktor 3")
	check(Combat.is_tank(_tank), "Gilt als Tank")
	Combat.deal_damage(_tank, _dummy, 100.0, &"physisch")
	check_near(_dummy.get_combat().get_threat_of(_tank), 400.0, 0.01, "Mit Tankhaltung dreifach")
	_dummy.get_combat()._update_threat_target(Network.host_time())
	check(_dummy.get_combat().get_threat_target() == _tank, "Ziel: Tank")
	check(_dummy.current_target == _tank, "current_target folgt der Bedrohung")


func test_zielwechsel_und_spott() -> void:
	_reset()
	var combat := _dummy.get_combat()
	Combat.deal_damage(_tank, _dummy, 1000.0, &"physisch")
	combat._update_threat_target(Network.host_time())
	check(combat.get_threat_target() == _tank, "Tank hat die Aufmerksamkeit")
	Combat.deal_damage(_dd, _dummy, 1090.0, &"physisch")
	combat._update_threat_target(Network.host_time())
	check(combat.get_threat_target() == _tank, "109 % im Nahkampf: kein Wechsel")
	Combat.deal_damage(_dd, _dummy, 20.0, &"physisch")
	combat._update_threat_target(Network.host_time())
	check(combat.get_threat_target() == _dd, "111 % im Nahkampf: Wechsel")
	Combat.taunt(_tank, _dummy, 3.0)
	check(combat.get_threat_target() == _tank, "Spott holt den Gegner zurück")
	check_near(combat.get_threat_of(_tank), combat.get_threat_of(_dd), 0.01, "Spott: höchste Bedrohung")
	Combat.reset_threat(_tank, _dummy)
	check(not combat.is_on_threat_list(_tank), "Zurücksetzen: Tank nicht mehr auf der Liste")
	check(combat.get_threat_target() == _dd, "Gegner wählt neu")


func test_heilung_bringt_in_den_kampf() -> void:
	_reset()
	_dd.get_combat()._combat_until = -1.0
	_dd.get_stats().set_in_combat(false)
	Combat.deal_damage(_tank, _dummy, 100.0, &"physisch")
	_tank.get_stats().set_health(_tank.get_stats().max_health - 50.0)
	Combat.heal(_dd, _tank, 1000.0)
	check(_dd.get_stats().is_in_combat(), "Heiler gerät in den Kampf")
	check_near(_dummy.get_combat().get_threat_of(_dd), 25.0, 0.01,
			"50 wirksame Heilung × 0,5 = 25 Bedrohung (Überheilung zählt nicht)")


func test_liste_haelt_im_kampf() -> void:
	_reset()
	Combat.deal_damage(_tank, _dummy, 10.0, &"physisch")
	var combat := _tank.get_combat()
	combat._combat_until = Network.host_time() - 1.0
	combat._process(0.0)
	check(_tank.get_stats().is_in_combat(), "Auf der Liste: bleibt im Kampf, auch nach kampf_dauer")
	Combat.reset_threat(_tank, _dummy)
	combat._process(0.0)
	check(not _tank.get_stats().is_in_combat(), "Von der Liste: verlässt den Kampf")


func test_tod_und_rueckkehr() -> void:
	_reset()
	Combat.deal_damage(_dd, _dummy, 100.0, &"physisch")
	_dd.get_combat().apply_aura(GameData.get_aura(&"test_leise"), _dd)
	var died := [false]
	_dd.died.connect(func(_killer: Unit) -> void: died[0] = true, CONNECT_ONE_SHOT)
	Combat.deal_damage(_dummy, _dd, _dd.get_stats().health + 10.0, &"physisch")
	check(_dd.is_dead(), "Leben 0: tot")
	check(died[0], "Signal died")
	check_equal(_dd.get_stats().health, 0.0, "Leben fällt auf 0 (nicht mehr auf 1)")
	check(not _dummy.get_combat().is_on_threat_list(_dd), "Von der Bedrohungsliste entfernt")
	check_equal(_dd.get_combat().get_stacks(&"test_leise"), 0, "Auren enden")
	check(not _dd.get_combat().can_move() and not _dd.get_combat().can_act(), "Steuerung gesperrt")
	check(not _dd.get_stats().is_in_combat(), "Tote sind nicht im Kampf")
	var dead_check := _dd.get_caster_node().check(GameData.get_ability(&"aufhelfen"), _tank)
	check_equal(dead_check[0], AbilityError.Code.DEAD, "Fähigkeiten gesperrt")
	# Aufhelfen: Prüfung der Fähigkeit beim Helfer.
	var help := GameData.get_ability(&"aufhelfen")
	_tank.get_combat()._combat_until = -1.0
	_tank.get_combat().clear_threat()
	Combat.reset_threat(_tank, _dummy)
	_tank.get_stats().set_in_combat(false)
	var ok := _tank.get_caster_node().check(help, _dd)
	check_equal(ok[0], AbilityError.Code.OK, "Aufhelfen außerhalb des Kampfes geht")
	_tank.get_stats().set_in_combat(true)
	var in_combat := _tank.get_caster_node().check(help, _dd)
	check_equal(in_combat[0], AbilityError.Code.IN_COMBAT, "Aufhelfen im Kampf geht nicht")
	_tank.get_stats().set_in_combat(false)
	var alive := _tank.get_caster_node().check(help, _tank)
	check(alive[0] != AbilityError.Code.OK, "Aufhelfen nur an toten Mitspielern")
	# Rückkehr wie nach „Annehmen“: 30 %, ohne Geschwächt.
	var service := RevivalService.new()
	_root.add_child(service)
	service.host_revive(_dd, 30.0, 30.0, false)
	check(not _dd.is_dead(), "Wieder lebendig")
	check_near(_dd.get_stats().health, _dd.get_stats().max_health * 0.3, 0.5, "30 % Leben")
	check_equal(_dd.get_combat().get_stacks(&"geschwaecht"), 0, "Aufhelfen ohne Geschwächt")
	# Wiedereinstieg: 50 % und Geschwächt.
	_dd.get_stats().set_health(0.0)
	_dd.get_combat()._process(0.0)
	service.host_revive(_dd, 50.0, 50.0, true)
	check_equal(_dd.get_combat().get_stacks(&"geschwaecht"), 1, "Wiedereinstieg mit Geschwächt")
	var stats := _dd.get_stats()
	var base := stats.block.get_value(&"agility")
	check(base > 0.0, "Gewandtheit vorhanden (%s)" % base)
	_dd.get_combat().remove_aura(&"geschwaecht")
	check(stats.block.get_value(&"agility") > base, "Geschwächt senkt die Attribute")
	service.free()


func test_puppe_stirbt_nie() -> void:
	_reset()
	Combat.deal_damage(_tank, _dummy, _dummy.get_stats().max_health * 2.0, &"physisch")
	check(not _dummy.is_dead(), "Angriffspuppe füllt sich bei 0 wieder auf")
