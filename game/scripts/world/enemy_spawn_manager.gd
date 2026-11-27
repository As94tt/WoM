class_name EnemySpawnManager
extends Node
## Erzeugt und verwaltet die Gegner der Spawnbereiche (Ticket #36).
## Kindknoten „EnemySpawns“ der Welt (GameWorld legt ihn an). Entscheidungen
## trifft nur der Host: GameWorld ruft start() auf dem Host, sobald das NavMesh
## gebacken ist; auf Clients bleibt der Knoten untätig (Gegner kommen über den
## UnitSpawner).
##
## Jeder Spawnbereich (EnemySpawnArea) hat Plätze (Slot): einen je festem
## Punkt bzw. „anzahl“ aus der Spawngruppe. Jeder Platz hat einen eigenen
## Respawn-Timer ab dem Tod seines Gegners (respawn_s der Gruppe, kein
## Gruppen-Respawn). Beim Erscheinen werden gewürfelt:
## - der Gegnertyp nach Gewichtung (Spalte „gegner“),
## - die Stufe gleichverteilt zwischen stufe_min und stufe_max,
## - die Stelle (zufällig im Radius auf dem NavMesh bzw. fester Punkt).
## Steht dort eine lebende Spielfigur näher als respawn_naehe_radius, wird um
## respawn_verschiebung_s verschoben und dann erneut geprüft. Beim Start und
## beim Zurücksetzen erscheinen alle sofort (ohne diese Prüfung).
##
## Seltene Gegner (selten_gegner, höchstens einer je Bereich gleichzeitig):
## - selten_chance: Bei jedem Erscheinen ersetzt er mit dieser Chance den
##   normalen Gegner des Platzes; nach seinem Tod gilt respawn_s.
## - selten_zeit_min_s/max_s: Ein zusätzlicher Platz, auf dem er nach einer
##   zufälligen Zeit erscheint (ab Start bzw. ab seinem Tod).
## Bosse sind Gegner mit Rang „boss“ an festen Punkten; ihre lange Respawnzeit
## steht in ihrer Spawngruppe.
##
## Die Leiche bleibt liegen, bis UnitCombat sie nach leiche_dauer entfernt
## (unabhängig vom Respawn). Die Zeit zählt der Manager selbst (advance),
## damit Tests sie vorspulen können.

const NODE_NAME := "EnemySpawns"
const GROUP := &"enemy_spawn_manager"
const ENEMY_SCENE := preload("res://scenes/units/enemy.tscn")
## Höchster waagerechter Abstand zwischen gewünschter Stelle und NavMesh-Punkt,
## damit ein Punkt weit weg (anderes Gebiet) nicht genommen wird.
const NAV_SNAP_MAX := 3.0
## Wie oft die Beschriftung der Bereiche (Entwickler-Panel) erneuert wird.
const DEBUG_INTERVAL := 0.25


## Ein Platz in einem Spawnbereich.
class Slot:
	extends RefCounted
	var area: EnemySpawnArea
	var index := 0
	## Zusätzlicher Platz des seltenen Gegners nach Zeit (selten_zeit_*).
	var rare_timer := false
	## Lebender Gegner des Platzes oder null (tot bzw. noch nicht erschienen).
	var enemy: Enemy = null
	## Der aktuelle Gegner ist der seltene.
	var rare := false
	## Zeitpunkt des nächsten Erscheinens (Manager-Zeit in s), −1 = keiner.
	var respawn_at := -1.0
	## Wie oft das aktuelle Erscheinen verschoben wurde (Spieler in der Nähe).
	var delays := 0

	func get_enemy() -> Enemy:
		return enemy if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() else null


## Host: Ein Gegner ist erschienen (slot = null bei Gegnern aus dem
## Entwickler-Panel).
signal enemy_spawned(enemy: Enemy, slot: Slot)

## Entwickler-Panel: Respawn nach respawn_schnell_s statt respawn_s.
var fast_respawn := false

var _units: Node = null
var _slots: Array[Slot] = []
var _started := false
var _time := 0.0
var _counter := 0
var _rng := RandomNumberGenerator.new()
var _debug_visible := false
var _debug_elapsed := 0.0


func _init() -> void:
	name = NODE_NAME
	add_to_group(GROUP)
	_rng.randomize()


## Der Manager der laufenden Welt oder null.
static func get_instance(tree: SceneTree) -> EnemySpawnManager:
	return tree.get_first_node_in_group(GROUP) as EnemySpawnManager if tree != null else null


## units = Knoten, unter dem die Gegner entstehen (%Units, UnitSpawner).
func setup(units: Node) -> void:
	_units = units


## Host: Plätze aller Spawnbereiche anlegen und die Gegner erscheinen lassen.
func start() -> void:
	if not Network.is_host() or _started:
		return
	_started = true
	_build_slots()
	_spawn_initial()


func is_started() -> bool:
	return _started


## Für Tests: Zufall mit festem Startwert.
func set_seed(value: int) -> void:
	_rng.seed = value


func get_time() -> float:
	return _time


func get_slots() -> Array[Slot]:
	return _slots


func _process(delta: float) -> void:
	if not _started or not Network.is_host():
		return
	advance(delta)
	if _debug_visible:
		_debug_elapsed += delta
		if _debug_elapsed >= DEBUG_INTERVAL:
			_debug_elapsed = 0.0
			_update_debug_texts()


## Host: Zeit weiterzählen und fällige Plätze erscheinen lassen.
func advance(seconds: float) -> void:
	_time += seconds
	for slot in _slots:
		if slot.enemy != null and slot.get_enemy() == null:
			# Ohne Tod verschwunden (z. B. entfernt): wie ein Tod behandeln.
			_on_slot_enemy_gone(slot)
		if slot.get_enemy() == null and slot.respawn_at >= 0.0 and _time >= slot.respawn_at:
			_try_spawn(slot, true)


# --- Entwickler-Panel --------------------------------------------------------

## Aktion aus dem Entwickler-Panel (EnemyDevSection): auf dem Host sofort,
## sonst als Wunsch an ihn. Aktionen: „spawn“ [id, Stufe, Transform3D],
## „kill_all“, „reset“, „fast“ (bool).
func request_dev(action: String, value: Variant = null) -> void:
	if Network.is_host():
		_do_dev(action, value)
	else:
		_rpc_dev.rpc_id(1, action, value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_dev(action: String, value: Variant) -> void:
	if not Network.is_host() or not OS.is_debug_build():
		return
	_do_dev(action, value)


func _do_dev(action: String, value: Variant) -> void:
	match action:
		"spawn":
			if value is Array and value.size() >= 3 and value[2] is Transform3D:
				spawn_free(StringName(str(value[0])), int(value[1]), value[2])
		"kill_all":
			kill_all()
		"reset":
			reset_all()
		"fast":
			fast_respawn = bool(value)
			if fast_respawn:
				# Laufende Timer ebenfalls verkürzen.
				for slot in _slots:
					if slot.respawn_at >= 0.0:
						slot.respawn_at = minf(slot.respawn_at, _time + respawn_delay(slot))
		_:
			push_warning("EnemySpawnManager: unbekannte Entwickler-Aktion %s." % action)


## Host: einen Gegner frei erzeugen (Entwickler-Panel, „am Mauszeiger“). Er
## gehört zu keinem Bereich und erscheint nach dem Tod nicht neu.
func spawn_free(enemy_id: StringName, enemy_level: int, at: Transform3D) -> Enemy:
	if not Network.is_host() or Data.gegner(enemy_id) == null:
		return null
	var enemy := _create(enemy_id, enemy_level, _on_ground(at))
	enemy_spawned.emit(enemy, null)
	return enemy


## Host: alle lebenden Gegner töten (ohne Töter, also ohne Erfahrung). Die
## Plätze erscheinen danach nach ihren Regeln neu.
func kill_all() -> int:
	var count := 0
	for enemy in get_enemies():
		if enemy.is_dead():
			continue
		var stats := enemy.get_stats()
		Combat.deal_damage(null, enemy, stats.health, &"physisch")
		if not enemy.is_dead():
			stats.set_health(0.0)
		if enemy.get_combat() != null:
			enemy.get_combat().check_death()
		count += 1
	return count


## Host: alle Gegner (auch Leichen und freie) entfernen, Timer verwerfen und
## alle Bereiche wie beim Start neu füllen.
func reset_all() -> void:
	if not Network.is_host():
		return
	for enemy in get_enemies():
		enemy.queue_free()
	for slot in _slots:
		slot.enemy = null
		slot.rare = false
		slot.respawn_at = -1.0
		slot.delays = 0
	if not _started:
		start()
		return
	_spawn_initial()


## Alle Gegner unter %Units (lebend und tot).
func get_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	if _units == null:
		return result
	for child in _units.get_children():
		var enemy := child as Enemy
		if enemy != null and not enemy.is_queued_for_deletion():
			result.append(enemy)
	return result


## Umrisse der Spawnbereiche zeigen (auf jeder Instanz; Respawnzeiten kennt
## nur der Host).
func set_debug_visible(on: bool) -> void:
	_debug_visible = on
	for area in _areas():
		area.set_debug_visible(on)
	if on:
		_update_debug_texts()


## Beschriftung eines Bereichs: Spawngruppe und Stand jedes Platzes.
func get_debug_text(area: EnemySpawnArea) -> String:
	var lines: PackedStringArray = [String(area.spawn_group)]
	if not _started:
		lines.append("Respawnzeiten nur beim Host" if not Network.is_host() else "noch nicht gestartet")
		return "\n".join(lines)
	var number := 0
	for slot in _slots:
		if slot.area != area:
			continue
		number += 1
		var label := "S" if slot.rare_timer else str(number)
		var enemy := slot.get_enemy()
		if enemy != null:
			lines.append("%s: %s, Stufe %d" % [label, enemy.get_unit_name(), enemy.get_level()])
		elif slot.respawn_at >= 0.0:
			var text := "%s: erscheint in %d s" % [label, ceili(maxf(0.0, slot.respawn_at - _time))]
			if slot.delays > 0:
				text += " (verschoben ×%d)" % slot.delays
			lines.append(text)
		else:
			lines.append("%s: –" % label)
	return "\n".join(lines)


# --- Regeln ------------------------------------------------------------------

## Wartezeit bis zum Wiedererscheinen eines Platzes nach dem Tod.
func respawn_delay(slot: Slot) -> float:
	if fast_respawn:
		return Data.konstante(&"respawn_schnell_s", 10.0)
	var row := slot.area.get_group_row()
	if row == null:
		return 180.0
	if slot.rare_timer:
		return _rng.randf_range(float(row.get_value("selten_zeit_min_s", 0.0)),
				float(row.get_value("selten_zeit_max_s", 0.0)))
	return float(row.get_value("respawn_s", 180.0))


## Steht eine lebende Spielfigur näher als respawn_naehe_radius an position?
func players_near(position: Vector3) -> bool:
	var radius := Data.konstante(&"respawn_naehe_radius", 15.0)
	for unit in Unit.all_units(get_tree()):
		if unit.is_player_unit() and not unit.is_dead() and unit.global_position.distance_to(position) < radius:
			return true
	return false


## Gegnertyp nach Gewichtung (Werte-Paare gegner_id:gewichtung).
static func pick_weighted(weights: Dictionary, roll: float) -> StringName:
	var total := 0.0
	for id: String in weights:
		total += maxf(0.0, float(weights[id]))
	if total <= 0.0:
		return &""
	var threshold := roll * total
	var last := &""
	for id: String in weights:
		var weight := maxf(0.0, float(weights[id]))
		if weight <= 0.0:
			continue
		last = StringName(id)
		if threshold < weight:
			return last
		threshold -= weight
	return last


## Was auf dem Platz erscheinen soll: [Gegner-ID, Stufe, selten].
func choose(slot: Slot) -> Array:
	var row := slot.area.get_group_row()
	if row == null:
		return [&"", 1, false]
	var low := int(row.get_value("stufe_min", 1))
	var high := maxi(low, int(row.get_value("stufe_max", low)))
	var rare_id := StringName(str(row.get_value("selten_gegner", "")))
	var rare_level := int(row.get_value("selten_stufe", 0))
	var rare := false
	if rare_id != &"":
		if slot.rare_timer:
			rare = true
		elif float(row.get_value("selten_chance", 0.0)) > 0.0 and not has_rare_alive(slot.area):
			rare = _rng.randf() * 100.0 < float(row.get_value("selten_chance", 0.0))
	if rare:
		return [rare_id, rare_level if rare_level > 0 else _rng.randi_range(low, high), true]
	return [pick_weighted(row.get_value("gegner", {}), _rng.randf()), _rng.randi_range(low, high), false]


## Lebt im Bereich gerade ein seltener Gegner?
func has_rare_alive(area: EnemySpawnArea) -> bool:
	for slot in _slots:
		if slot.area == area and slot.rare and slot.get_enemy() != null and not slot.enemy.is_dead():
			return true
	return false


# --- Intern ------------------------------------------------------------------

func _areas() -> Array[EnemySpawnArea]:
	var result: Array[EnemySpawnArea] = []
	if not is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group(EnemySpawnArea.GROUP):
		if node is EnemySpawnArea:
			result.append(node)
	return result


func _build_slots() -> void:
	_slots.clear()
	for area in _areas():
		var row := area.get_group_row()
		if row == null:
			push_warning("Spawnbereich %s: Spawngruppe „%s“ fehlt in spawngruppen.csv." % [
					area.get_path(), area.spawn_group])
			continue
		for i in area.get_slot_count():
			var slot := Slot.new()
			slot.area = area
			slot.index = i
			_slots.append(slot)
		if str(row.get_value("selten_gegner", "")) != "" and float(row.get_value("selten_zeit_max_s", 0.0)) > 0.0:
			var rare := Slot.new()
			rare.area = area
			rare.index = 0
			rare.rare_timer = true
			_slots.append(rare)


## Alle normalen Plätze sofort füllen, seltene nach ihrer Zeit planen.
func _spawn_initial() -> void:
	for slot in _slots:
		if slot.rare_timer:
			slot.respawn_at = _time + respawn_delay(slot)
		else:
			_try_spawn(slot, false)


## Platz füllen; check_players = Nähe-Prüfung (sonst sofort).
func _try_spawn(slot: Slot, check_players: bool) -> Enemy:
	var choice := choose(slot)
	var enemy_id: StringName = choice[0]
	if enemy_id == &"" or Data.gegner(enemy_id) == null:
		slot.respawn_at = -1.0
		return null
	if slot.rare_timer and has_rare_alive(slot.area):
		# Höchstens ein seltener Gegner gleichzeitig: später erneut versuchen.
		slot.respawn_at = _time + Data.konstante(&"respawn_verschiebung_s", 10.0)
		return null
	var at := _on_ground(slot.area.get_spawn_point(slot.index, _rng))
	if check_players and players_near(at.origin):
		slot.respawn_at = _time + Data.konstante(&"respawn_verschiebung_s", 10.0)
		slot.delays += 1
		return null
	var enemy := _create(enemy_id, int(choice[1]), at)
	slot.enemy = enemy
	slot.rare = bool(choice[2])
	slot.respawn_at = -1.0
	slot.delays = 0
	enemy.died.connect(_on_slot_enemy_died.bind(slot), CONNECT_ONE_SHOT)
	enemy_spawned.emit(enemy, slot)
	return enemy


func _create(enemy_id: StringName, enemy_level: int, at: Transform3D) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	_counter += 1
	# Gleicher Name auf allen Instanzen (Spawner), eindeutig auch neben Leichen.
	enemy.name = "Gegner%d" % _counter
	enemy.enemy_id = enemy_id
	enemy.level = clampi(enemy_level, 1, Data.hoechste_stufe())
	enemy.transform = at
	_units.add_child(enemy, true)
	return enemy


func _on_slot_enemy_died(_killer: Unit, slot: Slot) -> void:
	_on_slot_enemy_gone(slot)


## Respawn-Timer ab dem Tod (die Leiche bleibt davon unberührt liegen).
func _on_slot_enemy_gone(slot: Slot) -> void:
	slot.enemy = null
	slot.respawn_at = _time + respawn_delay(slot)
	slot.delays = 0


## Stelle auf begehbaren Boden setzen: nächster Punkt auf dem NavMesh (wenn
## gebacken und nah genug), sonst Geländehöhe, sonst unverändert.
func _on_ground(t: Transform3D) -> Transform3D:
	var origin := t.origin
	var snapped := false
	if is_inside_tree():
		var map := get_viewport().find_world_3d().navigation_map
		if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0 \
				and not NavigationServer3D.map_get_regions(map).is_empty():
			var point := NavigationServer3D.map_get_closest_point(map, origin)
			if Vector2(point.x - origin.x, point.z - origin.z).length() <= NAV_SNAP_MAX:
				origin = point
				snapped = true
		if not snapped:
			var terrain := WorldTerrain.find_in(get_tree())
			if terrain != null:
				origin.y = terrain.get_surface_height(origin.x, origin.z)
	return Transform3D(t.basis, origin)


func _update_debug_texts() -> void:
	for area in _areas():
		area.set_debug_text(get_debug_text(area))
