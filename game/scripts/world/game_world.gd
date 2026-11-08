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
## - Players: Spielfiguren, Knotenname = Peer-ID. Der PlayerSpawner
##   (MultiplayerSpawner, #30) überträgt Figuren, die der Host hier anlegt,
##   an alle Mitspieler. Neue Figuren erscheinen am Startpunkt.
## - ZoneTracker: aktuelles Gebiet jeder Figur; für die eigene Figur zeigt das
##   HUD den Gebietsnamen.
## - MapRenderer: Kartenbild von oben für das Kartenfenster (M).
## - Hud: Name/Infozeile, Interface (#17), Entwickler-Panel (F10, nur Debug).
##
## Multiplayer (#30): Alle Spieler laden dieselbe Szene; Gelände, Wald und
## Berge entstehen auf jeder Instanz gleich aus denselben Daten. Die
## Verbindung baut vorher der Autoload „Network“ auf. Ist die Welt geladen,
## meldet sie das (Network.notify_world_ready); der Host erzeugt daraufhin die
## Figur des Spielers an get_start_transform(index), der Spawner überträgt
## sie. Verlässt ein Spieler die Sitzung, entfernt der Host seine Figur bei
## allen. Teleports (Entwickler-Panel) und Wiedereinstieg entscheidet der
## Host: Clients schicken einen Wunsch per RPC, der Host setzt die Figur über
## PlayerCharacter.server_teleport, damit seine Bewegungsprüfung Bescheid weiß.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MAP_VIEW_SCENE := preload("res://scenes/ui/hud/map_view.tscn")
const DEV_PANEL_SCENE := preload("res://scenes/ui/dev/dev_panel.tscn")

## Weitere Spieler stehen im Kreis mit diesem Abstand um den Startpunkt, in
## Metern (#30).
const START_SPACING := 1.5
const NETWORK_SETTINGS: NetworkSettings = preload("res://data/network/network_settings.tres")
## Teleportziele werden so weit über dem Boden gesetzt (Figur fällt kurz).
const TELEPORT_LIFT := 0.3

## Weltdaten (Kartengröße).
@export var world_data: WorldData

var _zones: Array[WorldZone] = []
var _local_zone: WorldZone = null
var _nav_status := "noch nicht gebacken"
var _dev_info: Label = null
var _map_view: MapView = null

@onready var _players: Node3D = %Players
@onready var _navigation: NavigationRegion3D = %Navigation
@onready var _zone_tracker: ZoneTracker = %ZoneTracker
@onready var _map_renderer: MapRenderer = %MapRenderer
@onready var _hud: Hud = %GameHud
@onready var _spawner: MultiplayerSpawner = %PlayerSpawner


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(WorldZone.GROUP):
		var zone := node as WorldZone
		_zones.append(zone)
		_zone_tracker.register_zone(zone)
	_zones.sort_custom(func(a: WorldZone, b: WorldZone) -> bool: return a.data.order < b.data.order)
	_zone_tracker.zone_changed.connect(_on_zone_changed)
	_spawner.add_spawnable_scene(PLAYER_SCENE.resource_path)
	_players.child_entered_tree.connect(_on_player_node_added)
	Network.player_entered_world.connect(_on_player_entered_world)
	Network.player_left_world.connect(_on_player_left_world)
	Network.players_changed.connect(_on_players_changed)
	_show_character_info()
	_setup_map()
	_start_autosave()
	if OS.is_debug_build():
		_setup_dev_panel()
	_bake_navigation.call_deferred()
	# Host bzw. offline: eigene Figur entsteht sofort; Client: Host erzeugt sie.
	Network.notify_world_ready()


## Figur des lokalen Spielers oder null.
func get_local_player() -> PlayerCharacter:
	return get_player(multiplayer.get_unique_id())


## Figur des Spielers mit dieser Peer-ID oder null.
func get_player(peer_id: int) -> PlayerCharacter:
	return _players.get_node_or_null(NodePath(str(peer_id))) as PlayerCharacter


## Startplatz für den Spieler mit der Nummer index (0 = erster). Der erste
## steht auf dem Startpunkt, weitere im Kreis mit START_SPACING darum, damit
## sie nicht ineinander erscheinen.
func get_start_transform(index := 0) -> Transform3D:
	var point := get_tree().get_first_node_in_group(WorldSpawnPoint.START_GROUP) as Node3D
	var t := point.global_transform if point != null else Transform3D.IDENTITY
	if index > 0:
		var places := maxi(NETWORK_SETTINGS.max_players - 1, 1)
		var angle := TAU * float((index - 1) % places) / float(places)
		t.origin += (t.basis.x * cos(angle) + t.basis.z * sin(angle)) * START_SPACING
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
## Entscheidet der Host; auf einem Client wird der Wunsch an ihn geschickt
## (nur für die eigene Figur).
func respawn_player(player: PlayerCharacter) -> void:
	if not Network.is_host():
		if player == get_local_player():
			_rpc_request_respawn.rpc_id(1)
		return
	var point := get_nearest_respawn(player.global_position)
	if point != null:
		player.server_teleport(_on_ground(point.global_transform))


## Teleportiert die eigene Figur (Entwickler-Panel). Auf einem Client
## entscheidet der Host (Wunsch per RPC), damit seine Bewegungsprüfung den
## Teleport erwartet; die neue Position überträgt der Synchronizer.
func teleport_local_player(target: Transform3D) -> void:
	if not Network.is_host():
		_rpc_request_teleport.rpc_id(1, target)
		return
	var player := get_local_player()
	if player != null:
		player.server_teleport(_on_ground(target))


## Wunsch eines Clients: eigene Figur teleportieren (Entwickler-Panel, nur
## wenn der Host ein Debug-Build ist).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_teleport(target: Transform3D) -> void:
	if not Network.is_host() or not OS.is_debug_build():
		return
	var player := get_player(multiplayer.get_remote_sender_id())
	if player != null:
		player.server_teleport(_on_ground(target))


## Wunsch eines Clients: eigene Figur zum nächsten Wiedereinstiegspunkt.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_respawn() -> void:
	if not Network.is_host():
		return
	var player := get_player(multiplayer.get_remote_sender_id())
	if player != null:
		respawn_player(player)


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
	# Name im Spiel, falls der Host einen Zusatz vergeben hat („Arthas (2)“).
	var info := Network.get_local_player_info()
	%NameLabel.text = info.display_name if info != null else c.character_name
	%InfoLabel.text = "Stufe %d · %s · %s" % [
		c.level,
		race.display_name if race != null else String(c.race_id),
		class_data.display_name if class_data != null else String(c.class_id),
	]


# --- Spieler (Netzwerk, #30) -------------------------------------------------

func _on_player_entered_world(peer_id: int) -> void:
	if Network.is_host():
		_spawn_player(peer_id)
	var info := Network.get_player(peer_id)
	if peer_id != multiplayer.get_unique_id() and info != null:
		_hud.add_log_message("%s hat die Welt betreten." % info.display_name)


func _on_player_left_world(peer_id: int, display_name: String) -> void:
	if Network.is_host():
		var player := get_player(peer_id)
		if player != null:
			# Der Spawner entfernt die Figur auch bei allen Mitspielern.
			player.queue_free()
	if peer_id != multiplayer.get_unique_id():
		_hud.add_log_message("%s hat die Welt verlassen." % display_name)


## Nur auf dem Host: Figur für einen Spieler anlegen. Der PlayerSpawner
## überträgt sie an alle, die die Welt geladen haben.
func _spawn_player(peer_id: int) -> void:
	var info := Network.get_player(peer_id)
	if info == null or get_player(peer_id) != null:
		return
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	player.name = str(peer_id)  # bestimmt peer_id und Authority der Figur
	player.setup_from_info(info)
	player.transform = _free_start_transform()
	_players.add_child(player, true)


## Erster Startplatz, auf dem gerade niemand steht (sonst der erste).
func _free_start_transform() -> Transform3D:
	for index in NETWORK_SETTINGS.max_players:
		var t := get_start_transform(index)
		var taken := false
		for other in _players.get_children():
			var p := (other as Node3D).global_position
			if Vector2(p.x - t.origin.x, p.z - t.origin.z).length() < START_SPACING * 0.5:
				taken = true
				break
		if not taken:
			return t
	return get_start_transform(0)


func _on_players_changed() -> void:
	for node in _players.get_children():
		var player := node as PlayerCharacter
		if player == null or player.is_queued_for_deletion():
			continue
		# Neue Mitspieler in der Welt bekommen die Figuren jetzt zugeschickt.
		player.refresh_visibility()
		if Network.is_host():
			var info := Network.get_player(player.peer_id)
			if info != null:
				player.setup_from_info(info)
	_show_character_info()


## Eine Figur ist unter Players aufgetaucht (selbst erzeugt oder vom Spawner).
func _on_player_node_added(node: Node) -> void:
	var player := node as PlayerCharacter
	if player != null:
		player.ready.connect(_on_player_ready.bind(player), CONNECT_ONE_SHOT)


func _on_player_ready(player: PlayerCharacter) -> void:
	if _map_view == null:
		return
	if player.is_local():
		_map_view.set_tracked_node(player)
	else:
		var class_data := player.get_class_data()
		_map_view.add_mate_marker(player, player.display_name,
				class_data.color if class_data != null else Color.WHITE)


## Speichert den eigenen Charakter regelmäßig (NetworkSettings).
func _start_autosave() -> void:
	var timer := Timer.new()
	timer.name = "AutosaveTimer"
	timer.wait_time = NETWORK_SETTINGS.autosave_interval_s
	timer.autostart = true
	timer.timeout.connect(Network.save_local_character)
	add_child(timer)


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
	_map_view = map_view
	map_window.set_content(map_view)
	var half := world_data.map_half_extent
	map_view.world_rect = Rect2(-half, -half, 2.0 * half, 2.0 * half)
	for zone in _zones:
		map_view.add_zone_label(zone.get_display_name(), zone.get_map_label_position())
	for point in get_respawn_points():
		var p := point.global_position
		map_view.add_respawn_marker(point.display_name, Vector2(p.x, p.z))
	# Die eigene Figur und Mitspieler kommen über _on_player_ready dazu.
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

	# Netzwerk (#30): künstliche Verzögerung der eigenen Bewegungsdaten.
	var network := panel.add_section("Netzwerk")
	var delay_label := panel.add_info(network)
	var on_delay := func(value: float) -> void:
		Network.artificial_delay_ms = int(value)
		delay_label.text = "Künstliche Verzögerung: %d ms" % Network.artificial_delay_ms
	panel.add_slider(network, 0.0, NETWORK_SETTINGS.max_artificial_delay_ms, 10.0,
			Network.artificial_delay_ms, on_delay)
	on_delay.call(Network.artificial_delay_ms)

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
