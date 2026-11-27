extends TestSuite
## Tests für Gegner (Ticket #36), ohne Netzwerk (die eigene Instanz ist der
## Host):
## - Werte aus Stufe × Rang × Modifikatoren, fehlende Stufen, Farbe der Familie
## - Gegner-Einheit aus den Daten (Name, Titel, Rang, Gesinnung, Immunitäten,
##   Größe, Erfahrung beim Tod)
## - Spawnbereiche: Plätze, Stufen, Radius, feste Punkte, Respawn nach Zeit,
##   Verschiebung bei Spielern in der Nähe, seltene Gegner (Chance und Zeit),
##   Boss, Zurücksetzen, Alle töten
## - Leiche bleibt liegen (Konstanten), Datenprüfung der Spawngruppen

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TEST_IDS: Array[StringName] = [&"wolf_jung", &"bandit", &"banditenschuetze", &"banditenhexer",
		&"grizzly_alt", &"grauschnauze", &"banditenhauptmann"]

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
	_root.name = "EnemyTest"
	tree.root.add_child(_root)


func after_all() -> void:
	if _root != null:
		_root.free()


## Bereich mit Manager und eigenem %Units-Ersatz. Gibt [Manager, Bereich] zurück.
func _setup_area(group: StringName, radius: float, fixed_points: Array[Vector3] = []) -> Array:
	var holder := Node3D.new()
	holder.name = "Holder"
	_root.add_child(holder, true)
	var area := EnemySpawnArea.new()
	area.name = "Area"
	area.spawn_group = group
	area.radius = radius
	area.position = Vector3(100, 0, 100)
	for i in fixed_points.size():
		var marker := Marker3D.new()
		marker.name = "Punkt%d" % i
		marker.position = fixed_points[i]
		area.add_child(marker)
	holder.add_child(area)
	var units := Node3D.new()
	units.name = "Units"
	holder.add_child(units)
	var manager := EnemySpawnManager.new()
	holder.add_child(manager)
	manager.setup(units)
	manager.set_seed(36)
	return [manager, area, holder]


func _player(peer_name: String, at: Vector3, level := 1) -> PlayerCharacter:
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	player.name = peer_name
	player.display_name = "Test" + peer_name
	player.race_id = &"human"
	player.class_id = &"warrior"
	var c := CharacterData.new()
	c.character_name = player.display_name
	c.race_id = &"human"
	c.class_id = &"warrior"
	c.level = level
	player.setup_from_info(NetPlayerInfo.from_character(int(peer_name), c))
	player.position = at
	_root.add_child(player)
	return player


func _kill(enemy: Enemy, killer: Unit = null) -> void:
	Combat.deal_damage(killer, enemy, enemy.get_stats().health + 1.0, &"physisch")


# --- Daten und Werte ---------------------------------------------------------

func test_alle_testgegner_in_den_daten() -> void:
	for id in TEST_IDS:
		check(Data.gegner(id) != null, "%s steht in gegner.csv" % id)
	for level in range(1, 11):
		check(Data.gegner_stufenwerte(level) != null, "Stufe %d in gegner_stufenwerte.csv" % level)
	check(Data.gebiet(&"trainingsgelaende") != null, "trainingsgelaende in gebiete.csv")
	check_equal(Data.konstante(&"leiche_dauer"), 120.0, "Leiche bleibt 2 min")
	check_equal(Data.konstante(&"leiche_dauer_nach_beute"), 30.0, "Konstante für #38 angelegt")
	check_equal(Data.konstante(&"respawn_naehe_radius"), 15.0, "Nähe-Radius 15 m")
	check_equal(Data.konstante(&"respawn_verschiebung_s"), 10.0, "Verschiebung 10 s")
	var rudel := Data.spawngruppe(&"wolfswiese_rudel")
	check_equal(str(rudel.get_value("selten_gegner")), "grauschnauze", "Beispiel: Grauschnauze als seltener Gegner")
	check(not (rudel.get_value("gegner") as Dictionary).has("grauschnauze"), "nicht mehr normal gewichtet")


func test_werte_aus_stufe_und_rang() -> void:
	var wolf := Enemy.values_for(&"wolf_jung", 2)
	check_equal(wolf[&"max_health"], 55.0, "Junger Wolf Stufe 2: Leben 55 × normal")
	check_equal(wolf[&"armor"], 20.0, "Rüstung der Stufe")
	check_equal(wolf[&"dodge"], 5.0, "Ausweichen aus gegner.csv")
	var grizzly := Enemy.values_for(&"grizzly_alt", 7)
	check_equal(grizzly[&"max_health"], 390.0, "Elite: 130 × 3")
	check_equal(grizzly[&"armor"], 84.0, "Rüstung 70 × 1,2 (ruestung_mod)")
	check_near(grizzly[&"damage_min"], 12.0, 0.001, "Schaden 8 × 1,5")
	check_near(grizzly[&"damage_max"], 19.5, 0.001, "Schaden 13 × 1,5")
	check_equal(grizzly[&"experience"], 160, "Erfahrung 80 × 2")
	var rare := Enemy.values_for(&"grauschnauze", 6)
	check_equal(rare[&"max_health"], 230.0, "Selten: 115 × 2")
	check_equal(rare[&"armor"], 90.0, "+50 % Rüstung")
	check_equal(rare[&"dodge"], 10.0, "Ausweichen 10 %")
	var boss := Enemy.values_for(&"banditenhauptmann", 10)
	check_equal(boss[&"max_health"], 1750.0, "Boss: 175 × 10")
	check_near(boss[&"damage_max"], 34.0, 0.001, "Boss: Schaden × 2")
	var hexer := Enemy.values_for(&"banditenhexer", 4)
	check_equal(hexer[&"max_health"], 68.0, "leben_mod 0,8: 85 × 0,8")
	check_equal(hexer[&"spell_ward"], 8.0, "zauberschutz_mod 1,5: 5 × 1,5 (gerundet)")
	check(Enemy.values_for(&"gibt_es_nicht", 1).is_empty(), "unbekannter Gegner: leer")


func test_fehlende_stufe_hoechste_darunter() -> void:
	check(Enemy.level_row(25) == Data.gegner_stufenwerte(10), "Stufe 25: Werte der Stufe 10")
	check_equal(Enemy.values_for(&"wolf_jung", 25)[&"max_health"], 175.0, "Leben wie Stufe 10")


func test_farbe_der_familie() -> void:
	var tier: Color = Data.familie(&"tier").get_value("farbe")
	check_equal(Enemy.placeholder_color(&"wolf_jung"), tier, "Farbe der Familie Tier")
	check(Enemy.placeholder_color(&"bandit") != tier, "Humanoide anders")


# --- Gegner-Einheit ----------------------------------------------------------

func test_gegner_aus_daten() -> void:
	var parts := _setup_area(&"training_grizzly", 2.0)
	var manager: EnemySpawnManager = parts[0]
	var enemy := manager.spawn_free(&"banditenhauptmann", 10, Transform3D(Basis.IDENTITY, Vector3(5, 0, 5)))
	check(enemy != null, "Gegner erzeugt")
	check_equal(enemy.get_unit_name(), "Banditenhauptmann", "Name aus gegner.csv")
	check_equal(enemy.get_unit_title(), "<Anführer der Banditen>", "Titel")
	check_equal(enemy.get_level(), 10, "Stufe")
	check_equal(enemy.get_rank(), Unit.Rank.BOSS, "Rang Boss")
	check_equal(enemy.get_rank_id(), "boss", "Rang-ID")
	check_equal(enemy.get_base_reaction(), Unit.Reaction.HOSTILE, "feindlich")
	check_equal(enemy.get_stats().max_health, 1750.0, "Leben aus Stufe × Rang")
	check_equal(enemy.get_stats().health, 1750.0, "voll aufgefüllt")
	check_equal(enemy.get_stats().get_value(&"parry"), 10.0, "Parieren aus den Daten")
	check(enemy.get_combat().is_immune_to(&"betaeubung"), "immun gegen Betäubung")
	check(enemy.gives_experience(), "gibt Erfahrung")
	check_near(enemy.get_body_radius(), 0.4 * 1.3, 0.001, "Größe 1,3 (Kollision und Modell)")
	check_equal(enemy.get_family(), &"humanoid", "Familie")
	enemy.level = 3
	check_equal(enemy.get_stats().max_health, 700.0, "Stufe ändern: neue Werte (70 × 10)")
	parts[2].free()


func test_tod_leiche_und_erfahrung() -> void:
	var parts := _setup_area(&"training_woelfe", 6.0)
	var manager: EnemySpawnManager = parts[0]
	var player := _player("7", Vector3(0, 0, 0), 1)
	var world := FakeWorld.new()
	world.players = [player]
	_root.add_child(world)
	var service := ExperienceService.new()
	world.add_child(service)
	service.setup(world)
	var enemy := manager.spawn_free(&"wolf_jung", 2, Transform3D(Basis.IDENTITY, Vector3(3, 0, 0)))
	enemy.died.connect(func(killer: Unit) -> void: world.unit_died.emit(enemy, killer))
	_kill(enemy, player)
	check(enemy.is_dead(), "Gegner tot")
	check(enemy.is_inside_tree() and not enemy.is_queued_for_deletion(), "Leiche bleibt liegen")
	check(enemy.removes_corpse(), "Leiche verschwindet nach leiche_dauer")
	check_near((enemy.get_node(^"Model") as Node3D).rotation.x, -PI / 2.0, 0.001, "Modell kippt um")
	check(not enemy.is_tab_targetable(), "Leiche nicht per Tab wählbar")
	check_equal(player.get_experience().experience, LevelRules.kill_experience(2, "normal", 1),
			"Kill-Erfahrung (#27) mit echtem Gegner")
	world.free()
	player.free()
	parts[2].free()


# --- Spawnbereiche -----------------------------------------------------------

func test_bereich_fuellt_plaetze_im_radius() -> void:
	var parts := _setup_area(&"training_woelfe", 6.0)
	var manager: EnemySpawnManager = parts[0]
	var area: EnemySpawnArea = parts[1]
	manager.start()
	check(manager.is_started(), "gestartet")
	check_equal(manager.get_slots().size(), 4, "anzahl 4 aus der Spawngruppe")
	check_equal(manager.get_enemies().size(), 4, "vier Gegner erschienen")
	for enemy in manager.get_enemies():
		check(enemy.enemy_id in [&"wolf_jung", &"grauschnauze"], "Typ aus der Gruppe")
		if enemy.enemy_id == &"wolf_jung":
			check(enemy.level >= 1 and enemy.level <= 3, "Stufe 1–3 (ist %d)" % enemy.level)
		else:
			check_equal(enemy.level, 6, "Grauschnauze Stufe 6 (selten_stufe)")
		var offset := enemy.global_position - area.global_position
		check(Vector2(offset.x, offset.z).length() <= 6.0 + 0.001, "im Radius")
	parts[2].free()


func test_respawn_nach_zeit_und_naehe() -> void:
	var parts := _setup_area(&"training_banditen", 3.0)
	var manager: EnemySpawnManager = parts[0]
	var area: EnemySpawnArea = parts[1]
	manager.start()
	var slot: EnemySpawnManager.Slot = manager.get_slots()[0]
	var first := slot.get_enemy()
	_kill(first)
	check(slot.get_enemy() == null, "Platz nach dem Tod leer")
	check_near(slot.respawn_at, manager.get_time() + 180.0, 0.001, "Timer ab dem Tod: respawn_s 180")
	manager.advance(179.0)
	check(slot.get_enemy() == null, "nach 179 s noch nicht")
	manager.advance(1.5)
	check(slot.get_enemy() != null and slot.get_enemy() != first, "nach 180 s neu erschienen")
	check(not first.is_queued_for_deletion() and first.is_dead(), "alte Leiche liegt noch (Respawn < Leichendauer)")
	# Spieler in der Nähe: Verschiebung um 10 s, bis niemand mehr dort steht.
	var player := _player("8", area.global_position)
	_kill(slot.get_enemy())
	manager.advance(181.0)
	check(slot.get_enemy() == null, "Spieler näher als 15 m: verschoben")
	check_equal(slot.delays, 1, "einmal verschoben")
	check_near(slot.respawn_at, manager.get_time() + 10.0, 0.001, "um respawn_verschiebung_s")
	manager.advance(10.0)
	check_equal(slot.delays, 2, "noch da: erneut verschoben")
	player.global_position = area.global_position + Vector3(40, 0, 0)
	manager.advance(10.0)
	check(slot.get_enemy() != null, "Spieler weg: erschienen")
	check_equal(slot.delays, 0, "Zähler zurückgesetzt")
	# Tote Spieler zählen nicht.
	player.global_position = area.global_position
	player.get_stats().set_health(0.0)
	_kill(slot.get_enemy())
	manager.advance(181.0)
	check(slot.get_enemy() != null, "toter Spieler verschiebt nicht")
	player.free()
	parts[2].free()


func test_feste_punkte_und_boss() -> void:
	var parts := _setup_area(&"training_hauptmann", 0.0, [Vector3(2, 0, 0)] as Array[Vector3])
	var manager: EnemySpawnManager = parts[0]
	var area: EnemySpawnArea = parts[1]
	manager.start()
	check_equal(manager.get_slots().size(), 1, "ein Platz je festem Punkt")
	var boss := manager.get_slots()[0].get_enemy()
	check(boss != null and boss.get_rank() == Unit.Rank.BOSS, "Boss erschienen")
	check(boss.global_position.is_equal_approx(area.global_position + Vector3(2, 0, 0)), "am festen Punkt")
	_kill(boss)
	check_near(manager.get_slots()[0].respawn_at - manager.get_time(), 1800.0, 0.001, "lange Respawnzeit des Bosses")
	parts[2].free()


func test_seltener_gegner_chance() -> void:
	var parts := _setup_area(&"training_woelfe", 6.0)
	var manager: EnemySpawnManager = parts[0]
	manager.start()
	for enemy in manager.get_enemies():
		enemy.queue_free()
	for slot in manager.get_slots():
		slot.enemy = null
		slot.rare = false
	var slot: EnemySpawnManager.Slot = manager.get_slots()[0]
	var rare := 0
	for i in 2000:
		if bool(manager.choose(slot)[2]):
			rare += 1
	check(rare > 200 and rare < 400, "etwa 15 %% selten (%d von 2000)" % rare)
	# Lebt ein seltener Gegner im Bereich, kommt kein zweiter.
	var other: EnemySpawnManager.Slot = manager.get_slots()[1]
	other.enemy = manager.spawn_free(&"grauschnauze", 6, Transform3D.IDENTITY)
	other.rare = true
	check(manager.has_rare_alive(other.area), "seltener Gegner lebt")
	var any := false
	for i in 500:
		any = any or bool(manager.choose(slot)[2])
	check(not any, "höchstens einer gleichzeitig")
	parts[2].free()


func test_seltener_gegner_nach_zeit() -> void:
	var parts := _setup_area(&"wolfswiese_rudel", 6.0)
	var manager: EnemySpawnManager = parts[0]
	manager.start()
	check_equal(manager.get_slots().size(), 5, "4 normale Plätze + 1 für den seltenen")
	var rare_slot: EnemySpawnManager.Slot = manager.get_slots()[4]
	check(rare_slot.rare_timer and rare_slot.get_enemy() == null, "seltener Gegner noch nicht da")
	var wait := rare_slot.respawn_at - manager.get_time()
	check(wait >= 1200.0 and wait <= 2400.0, "erscheint nach 20–40 min (%d s)" % int(wait))
	for enemy in manager.get_enemies():
		check(enemy.enemy_id == &"wolf_jung", "normale Plätze ohne Grauschnauze")
	manager.advance(2400.0)
	var rare := rare_slot.get_enemy()
	check(rare != null and rare.enemy_id == &"grauschnauze", "Grauschnauze erschienen")
	check(rare != null and rare.level == 6, "Stufe 6")
	check(rare != null and rare.get_rank() == Unit.Rank.RARE, "Rang selten")
	_kill(rare)
	wait = rare_slot.respawn_at - manager.get_time()
	check(wait >= 1200.0 and wait <= 2400.0, "nach dem Tod wieder 20–40 min")
	parts[2].free()


func test_alle_toeten_und_zuruecksetzen() -> void:
	var parts := _setup_area(&"training_woelfe", 6.0)
	var manager: EnemySpawnManager = parts[0]
	manager.start()
	var free := manager.spawn_free(&"bandit", 4, Transform3D.IDENTITY)
	check_equal(manager.kill_all(), 5, "fünf Gegner getötet (auch freie)")
	for enemy in manager.get_enemies():
		check(enemy.is_dead(), "%s tot" % enemy.name)
	for slot in manager.get_slots():
		check(slot.respawn_at > manager.get_time(), "Respawn geplant")
	manager.reset_all()
	check(free.is_queued_for_deletion(), "Leichen und freie Gegner entfernt")
	var alive := 0
	for enemy in manager.get_enemies():
		if not enemy.is_dead():
			alive += 1
	check_equal(alive, 4, "alle Plätze sofort neu gefüllt")
	parts[2].free()


func test_gewichtung() -> void:
	var weights := {"a": 3, "b": 1}
	check_equal(EnemySpawnManager.pick_weighted(weights, 0.0), &"a", "Anfang: a")
	check_equal(EnemySpawnManager.pick_weighted(weights, 0.74), &"a", "drei Viertel: a")
	check_equal(EnemySpawnManager.pick_weighted(weights, 0.76), &"b", "letztes Viertel: b")
	check_equal(EnemySpawnManager.pick_weighted({}, 0.5), &"", "leer")


func test_datenpruefung_spawngruppen() -> void:
	var data_set := DataSet.new()
	var row := TableRow.new()
	row.table = "spawngruppen"
	row.line = 3
	row.values = {"id": "kaputt", "stufe_min": 5, "stufe_max": 3, "selten_gegner": "", "selten_chance": 0.0,
			"selten_zeit_min_s": 0.0, "selten_zeit_max_s": 0.0, "selten_stufe": 0}
	var row2 := TableRow.new()
	row2.table = "spawngruppen"
	row2.line = 4
	row2.values = {"id": "selten_ohne", "stufe_min": 1, "stufe_max": 2, "selten_gegner": "", "selten_chance": 10.0,
			"selten_zeit_min_s": 50.0, "selten_zeit_max_s": 0.0, "selten_stufe": 0}
	data_set.tables["spawngruppen"] = [row, row2]
	data_set.tables["gegner_stufenwerte"] = []
	EnemyDataCheck.check(data_set)
	check_equal(data_set.errors.size(), 3, "Stufenbereich, selten ohne Gegner, Zeit nur halb")
	check(data_set.warnings.size() >= 1, "fehlende Stufenwerte als Warnung")
