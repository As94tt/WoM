class_name GameWorld
extends Node3D
## Hauptszene der Startwelt (Ticket #15, ersetzt die Testszene aus #6/#16).
## Bindet je Gebiet eine Unterszene ein (scenes/world/zones/), dazu Gelände,
## Wege, Berge, Navigation, Spielfiguren und das Interface.
##
## Aufbau:
## - Navigation (NavigationRegion3D): alles Begehbare und alle Hindernisse
##   liegen darunter (Gelände, Wege, Gebiete, Ränder); daraus wird beim Start
##   das NavMesh für die Gegner-KI gebacken (nur auf dem Host).
## - Players: Spielfiguren, Knotenname = Peer-ID (wie später beim
##   MultiplayerSpawner, #30). Neue Figuren erscheinen am Startpunkt.
## - ZoneTracker: aktuelles Gebiet jeder Figur; für die eigene Figur zeigt das
##   HUD den Gebietsnamen.
## - MapRenderer: Kartenbild von oben für das Kartenfenster (M).
## - Hud: Name/Infozeile, Interface (#17), Entwickler-Panel (F10, nur Debug).
##
## Multiplayer: Alle Spieler laden dieselbe Szene; Gelände, Wald und Berge
## entstehen auf jeder Instanz gleich aus denselben Daten. Bisher rein lokal:
## die eigene Figur wird hier erzeugt. Mit #30 startet hier je nach
## GameSession.mode der Host (create_server) oder Client (create_client); der
## Host setzt dann über einen MultiplayerSpawner (spawn_path = Players) für
## jeden Spieler eine Figur an get_start_transform(index).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MAP_VIEW_SCENE := preload("res://scenes/ui/hud/map_view.tscn")
const DEV_PANEL_SCENE := preload("res://scenes/ui/dev/dev_panel.tscn")

## Abstand zwischen den Startplätzen mehrerer Spieler, in Metern.
const START_SPACING := 2.0
## Teleportziele werden so weit über dem Boden gesetzt (Figur fällt kurz).
const TELEPORT_LIFT := 0.3

## Weltdaten (Kartengröße).
@export var world_data: WorldData

var _zones: Array[WorldZone] = []
var _local_zone: WorldZone = null
var _nav_status := "noch nicht gebacken"
var _dev_info: Label = null

@onready var _players: Node3D = %Players
@onready var _navigation: NavigationRegion3D = %Navigation
@onready var _zone_tracker: ZoneTracker = %ZoneTracker
@onready var _map_renderer: MapRenderer = %MapRenderer
@onready var _hud: Hud = %GameHud


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(WorldZone.GROUP):
		var zone := node as WorldZone
		_zones.append(zone)
		_zone_tracker.register_zone(zone)
	_zones.sort_custom(func(a: WorldZone, b: WorldZone) -> bool: return a.data.order < b.data.order)
	_zone_tracker.zone_changed.connect(_on_zone_changed)
	_show_character_info()
	_spawn_local_player()
	_setup_map()
	if OS.is_debug_build():
		_setup_dev_panel()
	_bake_navigation.call_deferred()


## Figur des lokalen Spielers oder null.
func get_local_player() -> PlayerCharacter:
	return _players.get_node_or_null(NodePath(str(multiplayer.get_unique_id()))) as PlayerCharacter


## Startplatz für den Spieler mit der Nummer index (0 = erster). Weitere Spieler
## stehen nebeneinander, damit sie nicht ineinander erscheinen.
func get_start_transform(index := 0) -> Transform3D:
	var point := get_tree().get_first_node_in_group(WorldSpawnPoint.START_GROUP) as Node3D
	var t := point.global_transform if point != null else Transform3D.IDENTITY
	var offset := ceilf(index / 2.0) * START_SPACING * (1.0 if index % 2 == 1 else -1.0)
	t.origin += t.basis.x * offset
	return _on_ground(t)


## Alle Wiedereinstiegspunkte.
func get_respawn_points() -> Array[WorldSpawnPoint]:
	var result: Array[WorldSpawnPoint] = []
	for node in get_tree().get_nodes_in_group(WorldSpawnPoint.RESPAWN_GROUP):
		result.append(node as WorldSpawnPoint)
	return result


## Nächster Wiedereinstiegspunkt zu einer Position oder null.
func get_nearest_respawn(world_position: Vector3) -> WorldSpawnPoint:
	var best: WorldSpawnPoint = null
	for point in get_respawn_points():
		if best == null or point.global_position.distance_squared_to(world_position) \
				< best.global_position.distance_squared_to(world_position):
			best = point
	return best


## Setzt eine Figur an den nächsten Wiedereinstiegspunkt (nach dem Tod, M3).
## Nur auf der Instanz mit Authority der Figur aufrufen.
func respawn_player(player: PlayerCharacter) -> void:
	var point := get_nearest_respawn(player.global_position)
	if point != null:
		player.teleport_to(_on_ground(point.global_transform))


## Teleportiert die eigene Figur (Entwickler-Panel). Gilt nur für die eigene
## Figur; ihre neue Position überträgt später der Synchronizer.
func teleport_local_player(target: Transform3D) -> void:
	var player := get_local_player()
	if player != null:
		player.teleport_to(_on_ground(target))


## Aktuelles Gebiet der eigenen Figur oder null.
func get_local_zone() -> WorldZone:
	return _local_zone


## Setzt t auf die Geländehöhe (nie darunter), etwas angehoben.
func _on_ground(t: Transform3D) -> Transform3D:
	var terrain := WorldTerrain.find_in(get_tree())
	if terrain != null:
		t.origin.y = maxf(t.origin.y, terrain.get_surface_height(t.origin.x, t.origin.z))
	t.origin.y += TELEPORT_LIFT
	return t


func _show_character_info() -> void:
	var c := GameSession.selected_character
	if c == null:
		%NameLabel.text = "Kein Charakter gewählt"
		%InfoLabel.text = ""
		return
	var race := c.get_race()
	var class_data := c.get_class_data()
	%NameLabel.text = c.character_name
	%InfoLabel.text = "Stufe %d · %s · %s" % [
		c.level,
		race.display_name if race != null else String(c.race_id),
		class_data.display_name if class_data != null else String(c.class_id),
	]


## Setzt die Figur des lokalen Spielers an den Startpunkt. Der Knotenname ist
## die Peer-ID, wie später beim MultiplayerSpawner üblich.
func _spawn_local_player() -> void:
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	var peer_id := multiplayer.get_unique_id()
	player.name = str(peer_id)
	player.peer_id = peer_id
	_players.add_child(player)
	player.global_transform = get_start_transform(0)


func _on_zone_changed(body: Node3D, zone: WorldZone) -> void:
	if body != get_local_player():
		return
	_local_zone = zone
	_hud.show_zone_banner(zone.get_display_name(), zone.data.get_level_text())
	var map_window := _hud.get_hud_window(&"map")
	if map_window != null:
		map_window.title = "Karte – %s" % zone.get_display_name()


# --- Karte -------------------------------------------------------------------

func _setup_map() -> void:
	var map_window := _hud.get_hud_window(&"map")
	if map_window == null:
		return
	var map_view: MapView = MAP_VIEW_SCENE.instantiate()
	map_window.set_content(map_view)
	var half := world_data.map_half_extent
	map_view.world_rect = Rect2(-half, -half, 2.0 * half, 2.0 * half)
	for zone in _zones:
		map_view.add_zone_label(zone.get_display_name(), zone.get_map_label_position())
	for point in get_respawn_points():
		var p := point.global_position
		map_view.add_respawn_marker(point.display_name, Vector2(p.x, p.z))
	map_view.set_tracked_node(get_local_player())
	# Spielfiguren gehören nicht ins Kartenbild.
	_players.visible = false
	var on_rendered := func(texture: Texture2D) -> void:
		_players.visible = true
		map_view.set_map_texture(texture)
	_map_renderer.map_rendered.connect(on_rendered, CONNECT_ONE_SHOT)
	_map_renderer.render(map_view.world_rect)


# --- Navigation --------------------------------------------------------------

## Backt das NavMesh aus allem unter Navigation (Kollisionen der Ebenen „Welt“
## und „Unsichtbare Wände“). Nur der Host braucht es (Gegner-KI läuft dort);
## ohne Netzwerk ist die eigene Instanz der Host.
func _bake_navigation() -> void:
	if not multiplayer.is_server():
		_nav_status = "nicht nötig (Client)"
		return
	var start := Time.get_ticks_msec()
	_nav_status = "wird gebacken …"
	_replace_csg_collisions(_navigation)
	var on_baked := func() -> void:
		var polygons := _navigation.navigation_mesh.get_polygon_count()
		_nav_status = "%d Polygone, %d ms" % [polygons, Time.get_ticks_msec() - start]
		print("NavMesh fertig: ", _nav_status)
	_navigation.bake_finished.connect(on_baked, CONNECT_ONE_SHOT)
	_navigation.bake_navigation_mesh(true)


## CSG-Formen (Häuser, Zäune, Parcours) bringen ihre Kollision selbst mit;
## beim Backen müsste der NavMesh-Baker dafür die Grafik-Meshes von der
## Grafikkarte zurücklesen (langsam, Warnung). Deshalb bekommt jede CSG-Form
## mit Kollision einmal einen gleichwertigen StaticBody3D aus
## bake_collision_shape(); die CSG-eigene Kollision wird abgeschaltet.
func _replace_csg_collisions(node: Node) -> void:
	for child in node.get_children():
		_replace_csg_collisions(child)
	var csg := node as CSGShape3D
	if csg == null or not csg.is_root_shape() or not csg.use_collision:
		return
	var body := StaticBody3D.new()
	body.name = "BakedCollision"
	body.collision_layer = csg.collision_layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = csg.bake_collision_shape()
	body.add_child(shape)
	csg.add_child(body)
	csg.use_collision = false


# --- Entwickler-Panel --------------------------------------------------------

func _setup_dev_panel() -> void:
	var panel: DevPanel = DEV_PANEL_SCENE.instantiate()
	%HudLayer.add_child(panel)

	var teleport := panel.add_section("Teleport")
	var points: Array[TeleportPoint] = []
	for node in get_tree().get_nodes_in_group(TeleportPoint.GROUP):
		points.append(node as TeleportPoint)
	points.sort_custom(func(a: TeleportPoint, b: TeleportPoint) -> bool: return a.order < b.order)
	for point in points:
		panel.add_button(teleport, point.display_name,
				func() -> void: teleport_local_player(point.global_transform))

	var respawn := panel.add_section("Wiedereinstieg")
	for point in get_respawn_points():
		panel.add_button(respawn, "Wiedereinstieg: %s" % point.display_name,
				func() -> void: teleport_local_player(point.global_transform))
	var to_nearest := func() -> void:
		var player := get_local_player()
		if player != null:
			respawn_player(player)
	panel.add_button(respawn, "Zum nächsten Wiedereinstiegspunkt", to_nearest)

	var display := panel.add_section("Anzeige")
	panel.add_toggle(display, "Platzhalter anzeigen", true, _set_placeholders_visible)
	panel.add_toggle(display, "Gebietsgrenzen anzeigen", false, _set_bounds_visible)
	panel.add_toggle(display, "NavMesh anzeigen", false, NavigationServer3D.set_debug_enabled)

	var info := panel.add_section("Info")
	_dev_info = panel.add_info(info)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_dev_info)
	panel.add_child(timer)


func _set_placeholders_visible(on: bool) -> void:
	for node in get_tree().get_nodes_in_group(PlaceholderPost.GROUP):
		(node as Node3D).visible = on


func _set_bounds_visible(on: bool) -> void:
	for zone in _zones:
		zone.set_bounds_visible(on)


func _update_dev_info() -> void:
	if _dev_info == null or not _dev_info.is_visible_in_tree():
		return
	var player := get_local_player()
	var pos := player.global_position if player != null else Vector3.ZERO
	_dev_info.text = "\n".join([
		"Gebiet: %s" % (_local_zone.get_display_name() if _local_zone != null else "–"),
		"Position: %d / %d / %d" % [pos.x, pos.y, pos.z],
		"Bilder/s: %d" % Performance.get_monitor(Performance.TIME_FPS),
		"Zeichenaufrufe: %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"NavMesh: %s" % _nav_status,
	])
