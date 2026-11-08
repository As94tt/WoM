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
## - Units: Einheiten außer Spielern (#31), z. B. Übungspuppen. Der Host
##   erzeugt sie an den Aufstellpunkten (UnitSpawnPoint) der Gebiete, der
##   UnitSpawner (MultiplayerSpawner) überträgt sie an alle.
## - Hud: Interface (#17) mit Spieler- und Zielrahmen, Namensplaketten (#31)
##   und Entwickler-Panel (F10, nur Debug).
##   Inhalt des Charakterfensters (C) ist CharacterPanel (#19) mit der eigenen
##   Figur; das Entwickler-Panel hat dafür den Abschnitt „Werte“.
##   Inhalt des Zauberbuchs (P) ist SpellbookPanel (#21). Die Belegung der
##   Aktionsleisten (ActionBarLayout) gehört dem eigenen Charakter und wird
##   mit ihm gespeichert (CharacterData.action_bars); das Entwickler-Panel
##   hat dafür den Abschnitt „Fähigkeiten“.
## - Abschnitt „Einheiten“ im Entwickler-Panel (#31): Leben, Stufe und Rang des
##   aktuellen Ziels ändern. Wünsche eines Clients gehen per RPC an den Host
##   (_rpc_unit_dev_action), der seit #32 wie bei echtem Schaden
##   Combat.deal_damage bzw. Combat.heal nutzt.
## - Effects/EffectSpawner (#32): Flächen und Projektile, erzeugt vom Host.
## - Fähigkeiten wirken (#33): Fehlermeldungen oben in der Mitte; im
##   Entwickler-Panel „Testfähigkeiten erlernen“, „Abklingzeiten
##   zurücksetzen“, Waffenschalter (Nebenhand, Fernkampf) und „Ziel zaubert“.
## - Abschnitt „Auren“ im Entwickler-Panel (#32): CombatDevSection (Kindknoten
##   „CombatDev“). Den Schalter „Im Kampf“ aus #19/#31 gibt es nicht mehr;
##   den Kampfzustand bestimmt UnitCombat.
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
const CHARACTER_PANEL_SCENE := preload("res://scenes/ui/hud/character_panel.tscn")
const SPELLBOOK_PANEL_SCENE := preload("res://scenes/ui/hud/spellbook_panel.tscn")
const STAT_DEV_TOOLS: StatDevTools = preload("res://data/stats/dev_tools.tres")
const DUMMY_SCENE := preload("res://scenes/units/training_dummy.tscn")
const UNIT_DEV_TOOLS: UnitDevTools = preload("res://data/units/dev_tools.tres")
## Flächen und Projektile (#32), erzeugt vom Host unter „Effects“.
const EFFECT_SCENES: Array[String] = [AreaEffect.AREA_SCENE, ProjectileEffect.PROJECTILE_SCENE]

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
var _character_panel: CharacterPanel = null
var _spellbook_panel: SpellbookPanel = null
## Belegung der Aktionsleisten des eigenen Charakters (#21).
var _bar_layout: ActionBarLayout = null
## Entwickler-Panel, Abschnitt „Werte“ (#19): Infozeilen und Bedienelemente,
## die dem Stand der eigenen Figur folgen.
var _stat_dev_info: Label = null
var _stat_dev_level_label: Label = null
var _stat_dev_level_slider: HSlider = null
var _stat_dev_toggles: Dictionary[String, CheckBox] = {}
## Entwickler-Panel, Abschnitt „Einheiten“ (#31).
var _unit_dev_info: Label = null
var _unit_dev_level_label: Label = null
var _unit_dev_level_slider: HSlider = null
var _unit_dev_dot_timer: Timer = null

@onready var _players: Node3D = %Players
@onready var _navigation: NavigationRegion3D = %Navigation
@onready var _zone_tracker: ZoneTracker = %ZoneTracker
@onready var _map_renderer: MapRenderer = %MapRenderer
@onready var _hud: Hud = %GameHud
@onready var _spawner: MultiplayerSpawner = %PlayerSpawner
@onready var _units: Node3D = %Units
@onready var _unit_spawner: MultiplayerSpawner = %UnitSpawner
@onready var _effect_spawner: MultiplayerSpawner = %EffectSpawner


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(WorldZone.GROUP):
		var zone := node as WorldZone
		_zones.append(zone)
		_zone_tracker.register_zone(zone)
	_zones.sort_custom(func(a: WorldZone, b: WorldZone) -> bool: return a.data.order < b.data.order)
	_zone_tracker.zone_changed.connect(_on_zone_changed)
	_spawner.add_spawnable_scene(PLAYER_SCENE.resource_path)
	_unit_spawner.add_spawnable_scene(DUMMY_SCENE.resource_path)
	for scene_path in EFFECT_SCENES:
		_effect_spawner.add_spawnable_scene(scene_path)
	_players.child_entered_tree.connect(_on_player_node_added)
	Network.player_entered_world.connect(_on_player_entered_world)
	Network.player_left_world.connect(_on_player_left_world)
	Network.players_changed.connect(_on_players_changed)
	Data.reloaded.connect(_on_data_reloaded)
	_setup_character_window()
	_setup_spellbook_window()
	_setup_map()
	_start_autosave()
	if OS.is_debug_build():
		_setup_dev_panel()
	_bake_navigation.call_deferred()
	if multiplayer.is_server():
		_spawn_units()
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
	# Ebenso die Einheiten (Übungspuppen).
	for node in _units.get_children():
		if node.has_method(&"refresh_visibility") and not node.is_queued_for_deletion():
			node.refresh_visibility()


## Eine Figur ist unter Players aufgetaucht (selbst erzeugt oder vom Spawner).
func _on_player_node_added(node: Node) -> void:
	var player := node as PlayerCharacter
	if player != null:
		player.ready.connect(_on_player_ready.bind(player), CONNECT_ONE_SHOT)


func _on_player_ready(player: PlayerCharacter) -> void:
	if player.is_local():
		if _character_panel != null:
			_character_panel.setup(player)
		_connect_stat_dev(player)
		_setup_abilities(player)
		# Spieler- und Zielrahmen, Namensplaketten, Esc hebt das Ziel auf (#31).
		_hud.setup_local_player(player)
		_connect_unit_dev(player)
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


# --- Charakterfenster (#19) ---------------------------------------------------

func _setup_character_window() -> void:
	var window := _hud.get_hud_window(&"character")
	if window == null:
		return
	_character_panel = CHARACTER_PANEL_SCENE.instantiate()
	window.set_content(_character_panel)


# --- Zauberbuch und Aktionsleisten (#21) -------------------------------------

func _setup_spellbook_window() -> void:
	var window := _hud.get_hud_window(&"spellbook")
	if window == null:
		return
	_spellbook_panel = SPELLBOOK_PANEL_SCENE.instantiate()
	window.set_content(_spellbook_panel)


## Eigene Figur ist da: Belegung laden (oder beim ersten Mal die
## Standardbelegung mit der gespeicherten Stufe anlegen), Leisten und
## Zauberbuch verbinden.
func _setup_abilities(player: PlayerCharacter) -> void:
	var abilities := player.get_abilities()
	var c := Network.get_local_character()
	_bar_layout = ActionBarLayout.new()
	if c != null and not c.action_bars.is_empty():
		_bar_layout.load_save(c.action_bars)
	else:
		_bar_layout.reset(abilities.get_default_bar_abilities(c.level if c != null else 1))
	_bar_layout.changed.connect(_save_bar_layout)
	_save_bar_layout()
	_hud.setup_abilities(_bar_layout, abilities)
	if _spellbook_panel != null:
		_spellbook_panel.setup(abilities)
	abilities.abilities_learned.connect(_on_abilities_learned.bind(abilities))
	# Fehlermeldungen oben in der Mitte (#33).
	abilities.ability_failed.connect(func(_ability: AbilityData, reason: String) -> void:
		_hud.show_error(reason))


## Belegung in den Charakter schreiben und speichern (Testcharaktere nie).
func _save_bar_layout() -> void:
	var c := Network.get_local_character()
	if c == null or _bar_layout == null:
		return
	c.action_bars = _bar_layout.to_save()
	Network.save_local_character()


## Neu erlernte, aktive Fähigkeiten in den ersten freien Slot (Leiste 1,
## sonst Leiste 2), sofern sie nicht schon auf einer Leiste liegen.
func _on_abilities_learned(learned: Array[AbilityData], abilities: PlayerAbilities) -> void:
	if _bar_layout == null:
		return
	for ability in learned:
		if not abilities.can_place(ability) or _bar_layout.has_ability(ability.id):
			continue
		_bar_layout.place_ability(ability.id)
		_hud.add_log_message("Neue Fähigkeit erlernt: %s" % ability.display_name)


# --- Einheiten (#31) ---------------------------------------------------------

## Nur auf dem Host: an jedem Aufstellpunkt die Einheit erzeugen. Der
## UnitSpawner überträgt sie an alle, die die Welt geladen haben (auch an
## später Beitretende). Knotenname = Name des Aufstellpunkts, damit der Pfad
## auf allen Instanzen gleich ist.
func _spawn_units() -> void:
	for node in get_tree().get_nodes_in_group(UnitSpawnPoint.GROUP):
		var point := node as UnitSpawnPoint
		if point == null or _units.has_node(NodePath(String(point.name))):
			continue
		match point.kind:
			UnitSpawnPoint.Kind.TRAINING_DUMMY:
				if Data.uebungspuppe(point.unit_id) == null:
					push_warning("Aufstellpunkt %s: Übungspuppe „%s“ fehlt in uebungspuppen.csv." % [
							point.name, point.unit_id])
					continue
				var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
				dummy.name = point.name
				dummy.dummy_id = point.unit_id
				dummy.transform = point.get_spawn_transform()
				_units.add_child(dummy, true)


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
	# Spielfiguren und Einheiten gehören nicht ins Kartenbild.
	_players.visible = false
	_units.visible = false
	var on_rendered := func(texture: Texture2D) -> void:
		_players.visible = true
		_units.visible = true
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

	# Datentabellen (#39): neu laden wie mit F6; gesperrt mit Mitspielern.
	var data := panel.add_section("Daten")
	panel.add_button(data, "Tabellen neu laden (%s)" % InputLabels.for_action(Data.RELOAD_ACTION),
			func() -> void: Data.reload_tables())

	_setup_stat_dev_section(panel)

	# Fähigkeiten (#21): nur diese Sitzung bzw. die eigene Belegung.
	var ability_section := panel.add_section("Fähigkeiten")
	panel.add_button(ability_section, "Alle Fähigkeiten der Klasse erlernen", func() -> void:
		var player := get_local_player()
		if player != null:
			player.get_abilities().request_learn(PlayerAbilities.LEARN_ALL, true))
	# Testfähigkeiten (#33): Reiter „Allgemein“, wirken auf die Übungspuppen.
	panel.add_button(ability_section, "Testfähigkeiten erlernen", func() -> void:
		var player := get_local_player()
		if player != null:
			player.get_abilities().request_learn(PlayerAbilities.LEARN_TEST, true))
	panel.add_button(ability_section, "Abklingzeiten zurücksetzen", func() -> void:
		var player := get_local_player()
		if player != null and player.get_caster_node() != null:
			player.get_caster_node().request_reset_cooldowns())
	panel.add_button(ability_section, "Aktionsleisten zurücksetzen", func() -> void:
		var player := get_local_player()
		if player != null and _bar_layout != null:
			_bar_layout.reset(player.get_abilities().get_default_bar_abilities()))

	_setup_unit_dev_section(panel)

	# Auren (#32): Testeffekte und Testauren auf Ziel oder sich selbst.
	var combat_dev := CombatDevSection.new()
	add_child(combat_dev)
	combat_dev.setup(panel, self)

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


## Ergebnis von „Tabellen neu laden“ (F6 oder Entwickler-Panel) im Log.
## Bei Fehlern stehen die ersten Fehler im Log, alle in der Konsole.
func _on_data_reloaded(_ok: bool, lines: PackedStringArray) -> void:
	const MAX_LOG_LINES := 8
	for i in mini(lines.size(), MAX_LOG_LINES):
		_hud.add_log_message(lines[i])
	if lines.size() > MAX_LOG_LINES:
		_hud.add_log_message("… und %d weitere Fehler (siehe Konsole)." % (lines.size() - MAX_LOG_LINES))


## Abschnitt „Werte“ (#19): Testmodifikatoren, Stufe, Nahkampfwaffe/Schild,
## Schaden und Ressourcen. Alles wirkt auf die eigene Figur; auf einem Client
## geht es als Wunsch an den Host (CharacterStats.request_dev_action), der
## die Werte bestimmt. Der Kampfzustand steht seit #32 nur noch als Infozeile
## da (er entsteht durch Schaden und feindliche Auren, UnitCombat).
func _setup_stat_dev_section(panel: DevPanel) -> void:
	var section := panel.add_section("Werte")
	_stat_dev_info = panel.add_info(section)
	_stat_dev_toggles["melee"] = panel.add_toggle(section, "Nahkampfwaffe getragen", false,
			func(on: bool) -> void: _stat_dev_action("melee", on))
	_stat_dev_toggles["shield"] = panel.add_toggle(section, "Schild getragen", false,
			func(on: bool) -> void: _stat_dev_action("shield", on))
	# Waffen für den automatischen Angriff (#33): Platzhalter-Waffen aus
	# platzhalterwaffen.csv; Nebenhand und Schild schließen sich aus.
	_stat_dev_toggles["offhand"] = panel.add_toggle(section, "Nebenhandwaffe (beidhändig)", false,
			func(on: bool) -> void: _stat_dev_action("offhand", on))
	_stat_dev_toggles["ranged"] = panel.add_toggle(section, "Fernkampfwaffe getragen", false,
			func(on: bool) -> void: _stat_dev_action("ranged", on))
	_stat_dev_level_label = panel.add_info(section)
	_stat_dev_level_slider = panel.add_slider(section, 1.0, Data.hoechste_stufe(), 1.0, 1.0,
			func(value: float) -> void:
				_stat_dev_level_label.text = "Stufe (nur diese Sitzung): %d" % int(value)
				_stat_dev_action("level", int(value)))
	_stat_dev_level_label.text = "Stufe (nur diese Sitzung): 1"
	panel.add_button(section, "Schaden nehmen (%s %% Leben)" % StatFormat.number(
			STAT_DEV_TOOLS.damage_taken_percent, 0), _stat_dev_action.bind("take_damage", null))
	panel.add_button(section, "Schaden austeilen (%s, nur Wut)" % StatFormat.number(
			STAT_DEV_TOOLS.damage_dealt, 0), _stat_dev_action.bind("deal_damage", null))
	panel.add_button(section, "Mana/Energie verbrauchen (%s)" % StatFormat.number(
			STAT_DEV_TOOLS.resource_spent, 0), _stat_dev_action.bind("spend", null))
	panel.add_button(section, "Chi aufbauen (+%s)" % StatFormat.number(
			STAT_DEV_TOOLS.chi_built, 0), _stat_dev_action.bind("build_chi", null))
	panel.add_button(section, "Leben und Ressourcen auffüllen", _stat_dev_action.bind("refill", null))
	panel.add_info(section, "Testmodifikatoren:")
	for index in STAT_DEV_TOOLS.test_modifiers.size():
		_stat_dev_toggles["modifier_%d" % index] = panel.add_toggle(section,
				CharacterStats.dev_modifier_label(index), false,
				func(on: bool) -> void: _stat_dev_action("modifier", [index, on]))


func _stat_dev_action(action: String, value: Variant) -> void:
	var player := get_local_player()
	if player != null:
		player.get_stats().request_dev_action(action, value)


## Eigene Figur ist da: Abschnitt „Werte“ folgt ihrem Stand (auch wenn der
## Host etwas ändert).
func _connect_stat_dev(player: PlayerCharacter) -> void:
	if _stat_dev_info == null:
		return
	var stats := player.get_stats()
	stats.stats_changed.connect(_sync_stat_dev.bind(stats))
	stats.resources_changed.connect(_update_stat_dev_info.bind(stats))
	_sync_stat_dev(stats)


## Schalter und Regler auf den Stand der Figur setzen, ohne Aktionen auszulösen.
func _sync_stat_dev(stats: CharacterStats) -> void:
	_stat_dev_toggles["melee"].set_pressed_no_signal(stats.has_flag(StatBlock.FLAG_MELEE_WEAPON))
	_stat_dev_toggles["shield"].set_pressed_no_signal(stats.has_flag(StatBlock.FLAG_SHIELD))
	_stat_dev_toggles["offhand"].set_pressed_no_signal(stats.has_flag(StatBlock.FLAG_OFFHAND_WEAPON))
	_stat_dev_toggles["ranged"].set_pressed_no_signal(stats.has_flag(StatBlock.FLAG_RANGED_WEAPON))
	for index in STAT_DEV_TOOLS.test_modifiers.size():
		_stat_dev_toggles["modifier_%d" % index].set_pressed_no_signal(
				stats.block.has_source(CharacterStats.dev_source(index)))
	_stat_dev_level_slider.set_value_no_signal(stats.get_level())
	_stat_dev_level_label.text = "Stufe (nur diese Sitzung): %d" % stats.get_level()
	_update_stat_dev_info(stats)


func _update_stat_dev_info(stats: CharacterStats) -> void:
	var lines: PackedStringArray = ["Leben: %s / %s" % [StatFormat.number(stats.health, 0),
			StatFormat.number(stats.max_health, 0)],
			"Kampfzustand: %s" % ("im Kampf" if stats.is_in_combat() else "außerhalb des Kampfes")]
	for resource_id in stats.get_resource_ids():
		lines.append("%s: %s / %s" % [CharacterStats.RULES.get_resource_name(resource_id),
				StatFormat.number(stats.get_resource(resource_id), 0),
				StatFormat.number(stats.get_resource_max(resource_id), 0)])
	_stat_dev_info.text = "\n".join(lines)


## Abschnitt „Einheiten“ (#31): wirkt auf das aktuelle Ziel der eigenen Figur.
## Auf einem Client geht jede Aktion als Wunsch an den Host.
func _setup_unit_dev_section(panel: DevPanel) -> void:
	var section := panel.add_section("Einheiten")
	_unit_dev_info = panel.add_info(section, "Kein Ziel (Tab, Klick oder F1)")
	panel.add_button(section, "Ziel: Schaden (%s %% Leben)" % StatFormat.number(
			UNIT_DEV_TOOLS.damage_percent, 0),
			_unit_dev_action.bind("damage_percent", UNIT_DEV_TOOLS.damage_percent))
	panel.add_button(section, "Ziel: Treffer (%s Schaden)" % StatFormat.grouped(UNIT_DEV_TOOLS.damage_flat),
			_unit_dev_action.bind("damage", UNIT_DEV_TOOLS.damage_flat))
	panel.add_button(section, "Ziel: Heilung (%s %% Leben)" % StatFormat.number(
			UNIT_DEV_TOOLS.heal_percent, 0), _unit_dev_action.bind("heal_percent", UNIT_DEV_TOOLS.heal_percent))
	panel.add_button(section, "Ziel: Leben und Ressourcen auffüllen", _unit_dev_action.bind("refill", null))
	panel.add_toggle(section, "Ziel: Dauerschaden (%s je Sekunde)" % StatFormat.grouped(
			UNIT_DEV_TOOLS.damage_per_second), false, _set_unit_dev_dot)
	_unit_dev_level_label = panel.add_info(section, "Stufe des Ziels: –")
	_unit_dev_level_slider = panel.add_slider(section, 1.0, Data.hoechste_stufe(), 1.0, 1.0,
			func(value: float) -> void:
				_unit_dev_level_label.text = "Stufe des Ziels: %d" % int(value)
				_unit_dev_action("level", int(value)))
	# Zauber der Puppe (#33): zum Testen von Unterbrechen und Zauberleisten.
	panel.add_info(section, "Ziel zaubert immer wieder (nur Übungspuppen):")
	panel.add_button(section, "Ziel zaubert: unterbrechbar",
			_unit_dev_action.bind("dev_cast", "test_puppenzauber"))
	panel.add_button(section, "Ziel zaubert: nicht unterbrechbar",
			_unit_dev_action.bind("dev_cast", "test_puppenzauber_schild"))
	panel.add_button(section, "Ziel zaubert nicht mehr", _unit_dev_action.bind("dev_cast", ""))
	panel.add_info(section, "Rang des Ziels (nur Übungspuppen):")
	for rank: String in Unit.RANK_IDS:
		panel.add_button(section, "Rang: %s" % rank.capitalize(),
				_unit_dev_action.bind("rank", Unit.RANK_IDS[rank]))
	_unit_dev_dot_timer = Timer.new()
	_unit_dev_dot_timer.wait_time = 1.0
	_unit_dev_dot_timer.timeout.connect(func() -> void:
		_unit_dev_action("damage", UNIT_DEV_TOOLS.damage_per_second))
	panel.add_child(_unit_dev_dot_timer)
	var info_timer := Timer.new()
	info_timer.wait_time = 0.25
	info_timer.autostart = true
	info_timer.timeout.connect(_update_unit_dev_info)
	panel.add_child(info_timer)


## Eigene Figur ist da: Regler „Stufe des Ziels“ folgt dem gewählten Ziel.
func _connect_unit_dev(player: PlayerCharacter) -> void:
	var targeting := player.get_targeting()
	if targeting == null or _unit_dev_level_slider == null:
		return
	targeting.target_changed.connect(func(target: Unit) -> void:
		if target != null:
			_unit_dev_level_slider.set_value_no_signal(target.get_level())
			_unit_dev_level_label.text = "Stufe des Ziels: %d" % target.get_level()
		else:
			_unit_dev_level_label.text = "Stufe des Ziels: –")


func _set_unit_dev_dot(on: bool) -> void:
	if on:
		_unit_dev_dot_timer.start()
	else:
		_unit_dev_dot_timer.stop()


func _update_unit_dev_info() -> void:
	if _unit_dev_info == null or not _unit_dev_info.is_visible_in_tree():
		return
	var target := _local_target()
	if target == null:
		_unit_dev_info.text = "Kein Ziel (Tab, Klick oder F1)"
		return
	var stats := target.get_stats()
	var player := get_local_player()
	var lines: PackedStringArray = ["Ziel: %s (Stufe %d, %s)" % [target.get_unit_name(), target.get_level(),
			UnitColors.REACTION_NAMES[target.get_reaction_to(player)]]]
	if stats != null:
		lines.append("Leben: %s / %s" % [StatFormat.grouped(stats.health), StatFormat.grouped(stats.max_health)])
	if player != null and target != player:
		lines.append("Entfernung: %s m · Sichtlinie: %s" % [StatFormat.number(player.distance_to_unit(target), 1),
				"ja" if player.has_line_of_sight_to(target) else "nein"])
		lines.append("Ziel vor mir: %s · ich hinter dem Ziel: %s" % [
				"ja" if player.is_in_front(target) else "nein", "ja" if player.is_behind(target) else "nein"])
	_unit_dev_info.text = "\n".join(lines)


func _local_target() -> Unit:
	var player := get_local_player()
	if player == null or player.get_targeting() == null:
		return null
	return player.get_targeting().target


## Aktion auf das Ziel: auf dem Host sofort, sonst als Wunsch an ihn.
func _unit_dev_action(action: String, value: Variant) -> void:
	var target := _local_target()
	if target == null:
		return
	if Network.is_host():
		_do_unit_dev_action(target, get_local_player(), action, value)
	else:
		_rpc_unit_dev_action.rpc_id(1, target.get_path(), action, value)


## Wunsch eines Clients aus dem Entwickler-Panel (nur wenn der Host ein
## Debug-Build ist).
@rpc("any_peer", "call_remote", "reliable")
func _rpc_unit_dev_action(target_path: NodePath, action: String, value: Variant) -> void:
	if not Network.is_host() or not OS.is_debug_build():
		return
	var target := Unit.from_path(get_tree(), target_path)
	var source := get_player(multiplayer.get_remote_sender_id())
	if target != null and source != null:
		_do_unit_dev_action(target, source, action, value)


## Host: Aktion ausführen. Schaden und Heilung laufen seit #32 über
## Combat.deal_damage bzw. Combat.heal (physisch, ohne Rüstung und Würfel),
## wie später echte Treffer (#34): Kampfzustand, Schilde, Auslöser, Kampftext.
func _do_unit_dev_action(target: Unit, source: Unit, action: String, value: Variant) -> void:
	var stats := target.get_stats()
	if stats == null:
		return
	match action:
		"damage":
			Combat.deal_damage(source, target, float(value), &"physisch")
		"damage_percent":
			Combat.deal_damage(source, target, stats.max_health * float(value) / 100.0, &"physisch")
		"heal_percent":
			Combat.heal(source, target, stats.max_health * float(value) / 100.0)
		"refill":
			stats.refill()
		"level":
			stats.set_level_override(clampi(int(value), 1, Data.hoechste_stufe()))
		"rank":
			if target is TrainingDummy:
				(target as TrainingDummy).rank_override = int(value)
		"dev_cast":
			if target is TrainingDummy:
				(target as TrainingDummy).dev_cast_ability = StringName(str(value))
				if str(value) == "" and target.get_caster_node() != null:
					target.get_caster_node().host_cancel()
		_:
			push_warning("GameWorld: unbekannte Einheiten-Aktion %s." % action)


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
