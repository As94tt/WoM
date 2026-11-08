extends Node
## Autoload „Network“ (Ticket #30): die zentrale Netzwerk-Schicht. Bündelt
## alles rund um die Verbindung (ENet, Host-Client-Modell) und bietet anderen
## Systemen eine einfache Schnittstelle.
##
## Regel für alle Systeme: Spielentscheidungen (Schaden, Beute, Erfahrung,
## Gegner-KI, Teleports) trifft der Host. Clients senden Wünsche (RPC an den
## Host, Peer 1) und zeigen Ergebnisse an. Siehe CLAUDE.md, „Netzwerk“.
##
## Schnittstelle für andere Systeme:
##   Network.is_host()               – entscheidet dieser Rechner? (auch offline)
##   Network.get_local_peer_id()     – eigene Peer-ID (Host und offline: 1)
##   Network.get_players()           – alle Spieler der Sitzung (NetPlayerInfo)
##   Network.get_player(peer_id)     – ein Spieler oder null
##   Signale player_entered_world / player_left_world / players_changed
##
## Ablauf Beitreten:
##   1. Client verbindet (join_game) und schickt _rpc_hello mit Spielversion,
##      Daten-Hash und Charakterdaten.
##   2. Host prüft (Version, Daten-Hash, Platz, Charakter) und antwortet mit
##      _rpc_accepted (Spielerliste) oder _rpc_rejected (Meldung, danach Trennung).
##   3. Client lädt die Welt und meldet _rpc_world_ready. Erst dann erzeugt der
##      Host seine Figur (MultiplayerSpawner in der Welt) und schickt ihm die
##      Figuren der anderen.
##
## Ohne Sitzung (Welt direkt im Editor gestartet) läuft alles mit dem
## OfflineMultiplayerPeer: eigene Peer-ID 1, is_host() true.

## Die Spielerliste hat sich geändert (Beitritt, Verlassen, Stufe, Ping).
signal players_changed
## Ein Spieler hat die Welt betreten (seine Figur wird erzeugt).
signal player_entered_world(peer_id: int)
## Ein Spieler hat die Welt verlassen (getrennt oder Sitzung verlassen).
signal player_left_world(peer_id: int, display_name: String)
## Beitreten: Host hat angenommen, die Welt kann geladen werden.
signal join_succeeded
## Beitreten fehlgeschlagen, mit verständlicher Meldung. can_retry ist false,
## wenn der Host abgelehnt hat (Version, voll, Charakter); ein erneuter
## Versuch ändert dann nichts.
signal join_failed(message: String, can_retry: bool)

enum State { OFFLINE, HOSTING, CONNECTING, CONNECTED }

const SETTINGS: NetworkSettings = preload("res://data/network/network_settings.tres")
const CHARACTER_RULES: CharacterRules = preload("res://data/characters/character_rules.tres")
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
## Zuletzt verwendete Adresse und Ports (nur lokal).
const CONFIG_PATH := "user://network.cfg"
## Pause zwischen Ablehnungsmeldung und Trennung, damit die Meldung ankommt.
const REJECT_DISCONNECT_DELAY := 0.5
## Ebenso beim Beenden durch den Host: Ein Client verwirft beim Trennen alle
## noch nicht verarbeiteten Pakete, die Meldung muss also vorher ankommen.
const SESSION_END_CLOSE_DELAY := 0.5

var state: State = State.OFFLINE
## Künstliche Verzögerung der eigenen ausgehenden Bewegungsdaten in ms
## (Entwickler-Panel). Wirkt in PlayerCharacter.
var artificial_delay_ms: int = 0:
	set(value):
		artificial_delay_ms = clampi(value, 0, SETTINGS.max_artificial_delay_ms)
## Meldung, die das Hauptmenü beim nächsten Öffnen einmal anzeigt
## (z. B. „Der Host hat die Sitzung beendet“).
var menu_message := ""

## Peer-ID → Spieler. Beim Host die Wahrheit, bei Clients eine Kopie.
var _players: Dictionary[int, NetPlayerInfo] = {}
## Charakter, mit dem dieser Rechner spielt.
var _local_character: CharacterData = null
## Host: verbundene Peers ohne Anmeldung → Zeitpunkt der Verbindung (ms).
var _pending: Dictionary[int, int] = {}
## Client: bis wann Verbindung und Antwort des Hosts da sein müssen (ms).
var _connect_deadline := 0
var _ping_elapsed := 0.0
var _stats_elapsed := 0.0
var _bytes_sent_per_s := 0.0
var _bytes_received_per_s := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _notification(what: int) -> void:
	# Fenster schließen (X, Alt+F4): ohne Rückfrage speichern und trennen.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		leave_session()


# --- Schnittstelle -----------------------------------------------------------

## true, wenn dieser Rechner die Spielentscheidungen trifft (Host oder offline).
func is_host() -> bool:
	return multiplayer.is_server()


## true, solange eine Sitzung läuft (als Host oder verbundener Client).
func is_online() -> bool:
	return state == State.HOSTING or state == State.CONNECTED


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()


## Alle Spieler, Host zuerst, dann nach Peer-ID.
func get_players() -> Array[NetPlayerInfo]:
	var ids := _players.keys()
	ids.sort()
	var result: Array[NetPlayerInfo] = []
	for id: int in ids:
		result.append(_players[id])
	return result


func get_player(peer_id: int) -> NetPlayerInfo:
	return _players.get(peer_id)


func get_local_player_info() -> NetPlayerInfo:
	return get_player(get_local_peer_id())


func get_player_count() -> int:
	return _players.size()


## true, wenn peer_id die Welt geladen hat. Sichtbarkeitsfilter der
## MultiplayerSynchronizer: Figuren werden nur an solche Peers gesendet.
func is_peer_in_world(peer_id: int) -> bool:
	var info: NetPlayerInfo = _players.get(peer_id)
	return info != null and info.in_world


## true, wenn außer diesem Rechner noch jemand in der Sitzung ist.
func has_other_players() -> bool:
	return is_online() and _players.size() > 1


## Ping des eigenen Rechners zum Host in ms (Host: 0).
func get_local_ping_ms() -> int:
	if state != State.CONNECTED:
		return 0
	var peer := _enet_peer()
	var host_peer := peer.get_peer(1) if peer != null else null
	return int(host_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if host_peer != null else 0


## Gesendete und empfangene Bytes pro Sekunde (Netzwerk-Overlay).
func get_bytes_sent_per_second() -> float:
	return _bytes_sent_per_s


func get_bytes_received_per_second() -> float:
	return _bytes_received_per_s


## Spielversion aus project.godot (application/config/version).
func get_game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Prüfsumme der Datentabellen (Ticket #39, Autoload „Data“), beim Beitreten
## mit dem Host verglichen. Weicht sie ab, lehnt der Host mit „Unterschiedliche
## Spieldaten“ ab. Neu laden ist gesperrt, solange Mitspieler verbunden sind,
## daher bleibt sie während einer Sitzung gleich.
func get_data_hash() -> String:
	return Data.get_checksum()


# --- Sitzung starten und beenden ---------------------------------------------

## Öffnet eine Sitzung als Host. Gibt eine Fehlermeldung zurück oder "".
func host_game(port: int, character: CharacterData) -> String:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	# Ein Platz mehr als erlaubt, damit ein Beitretender bei voller Sitzung
	# noch die Meldung „Die Sitzung ist voll“ bekommt statt nur keine Antwort.
	var err := peer.create_server(port, SETTINGS.max_players)
	if err != OK:
		return "Die Sitzung konnte nicht gestartet werden: Port %d ist belegt oder nicht verfügbar." % port
	multiplayer.multiplayer_peer = peer
	state = State.HOSTING
	_local_character = character
	var players: Dictionary[int, NetPlayerInfo] = {1: NetPlayerInfo.from_character(1, character)}
	_set_players(players)
	print("Netzwerk: Sitzung als Host auf Port %d geöffnet (Version %s)." % [port, get_game_version()])
	return ""


## Tritt einer Sitzung bei. Gibt sofort eine Fehlermeldung zurück oder "";
## das Ergebnis kommt danach über join_succeeded bzw. join_failed.
func join_game(address: String, port: int, character: CharacterData) -> String:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return "Host nicht erreichbar: Die Adresse „%s“ ist ungültig." % address
	multiplayer.multiplayer_peer = peer
	state = State.CONNECTING
	_local_character = character
	_connect_deadline = Time.get_ticks_msec() + int(SETTINGS.connect_timeout_s * 1000.0)
	print("Netzwerk: Verbinde mit %s:%d …" % [address, port])
	return ""


## Bricht ein laufendes Beitreten ab.
func cancel_join() -> void:
	if state == State.CONNECTING:
		_close_peer()


## Verlässt die Sitzung sauber: Charakter speichern, beim Host alle
## Mitspieler benachrichtigen, Verbindung trennen. Danach ist der Rechner
## offline; die Szene wechselt der Aufrufer.
func leave_session() -> void:
	save_local_character()
	var peer := _enet_peer()
	if state == State.HOSTING and peer != null and not _connected_peers().is_empty():
		for id in _connected_peers():
			_rpc_session_ended.rpc_id(id)
		peer.host.flush()
		# Verbindung erst kurz danach schließen (vorher würde sie beim
		# Austauschen des Peers sofort getrennt). Die Sitzung gilt schon jetzt
		# als beendet.
		state = State.OFFLINE
		_pending.clear()
		_local_character = null
		_players = {}
		players_changed.emit()
		get_tree().create_timer(SESSION_END_CLOSE_DELAY).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer == peer:
				_close_peer())
		return
	_close_peer()


## Der eigene Charakter dieser Sitzung (auch der Testcharakter der
## Startparameter) oder null.
func get_local_character() -> CharacterData:
	return _local_character if _local_character != null else GameSession.selected_character


## Speichert den eigenen Charakter lokal (regelmäßig, beim Verlassen und
## Beenden). Testcharaktere werden nie gespeichert.
func save_local_character() -> void:
	var c := get_local_character()
	if c == null or c.is_temporary:
		return
	c.last_played = int(Time.get_unix_time_from_system())
	CharacterStore.save(c)


## Wird von der Welt gerufen, sobald sie geladen ist. Host bzw. offline: die
## eigene Figur wird erzeugt. Client: dem Host melden, dass er bereit ist.
func notify_world_ready() -> void:
	if is_host():
		if not _players.has(1):
			# Offline (Welt ohne Sitzung gestartet): eigener Eintrag.
			var c := GameSession.selected_character
			if c == null:
				c = CharacterData.make_test_character()
			_local_character = c
			_players[1] = NetPlayerInfo.from_character(1, c)
		_mark_in_world(1)
	else:
		_rpc_world_ready.rpc_id(1)


## Zuletzt verwendete Werte für die Dialoge: {"address", "join_port", "host_port"}.
func load_last_connection() -> Dictionary:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	return {
		"address": str(config.get_value("join", "address", "127.0.0.1")),
		"join_port": int(config.get_value("join", "port", SETTINGS.default_port)),
		"host_port": int(config.get_value("host", "port", SETTINGS.default_port)),
	}


func save_last_join(address: String, port: int) -> void:
	_save_config_value("join", "address", address)
	_save_config_value("join", "port", port)


func save_last_host_port(port: int) -> void:
	_save_config_value("host", "port", port)


# --- Ablauf ------------------------------------------------------------------

func _process(delta: float) -> void:
	match state:
		State.CONNECTING:
			if Time.get_ticks_msec() > _connect_deadline:
				_fail_join("Zeitüberschreitung: Der Host antwortet nicht. Prüfe IP-Adresse und Port und ob die Sitzung läuft.")
		State.HOSTING:
			_kick_silent_peers()
			_ping_elapsed += delta
			if _ping_elapsed >= SETTINGS.ping_interval_s:
				_ping_elapsed = 0.0
				_broadcast_pings()
	_stats_elapsed += delta
	if _stats_elapsed >= 1.0:
		_update_traffic(_stats_elapsed)
		_stats_elapsed = 0.0


func _on_peer_connected(id: int) -> void:
	if state != State.HOSTING:
		return  # Clients erfahren hier nur von anderen Clients.
	_pending[id] = Time.get_ticks_msec()
	var peer := _enet_peer()
	if peer != null and peer.get_peer(id) != null:
		# Getrennte Mitspieler nach spätestens ca. 8 s erkennen statt 30 s.
		peer.get_peer(id).set_timeout(0, 3000, 8000)


func _on_peer_disconnected(id: int) -> void:
	if state != State.HOSTING:
		return
	_pending.erase(id)
	if _players.has(id):
		var players := _copy_players()
		players.erase(id)
		_set_players(players)
		_broadcast_players()


func _on_connected_to_server() -> void:
	if state != State.CONNECTING:
		return
	_connect_deadline = Time.get_ticks_msec() + int(SETTINGS.connect_timeout_s * 1000.0)
	var peer := _enet_peer()
	if peer != null and peer.get_peer(1) != null:
		peer.get_peer(1).set_timeout(0, 3000, 8000)
	_rpc_hello.rpc_id(1, get_game_version(), get_data_hash(), _local_character.to_dict())


func _on_connection_failed() -> void:
	if state == State.CONNECTING:
		_fail_join("Host nicht erreichbar. Prüfe IP-Adresse und Port und ob die Sitzung läuft.")


func _on_server_disconnected() -> void:
	if state == State.CONNECTING:
		_fail_join("Verbindung abgelehnt: Der Host hat die Verbindung getrennt.")
	elif state == State.CONNECTED:
		_end_session_for_client("Die Verbindung zum Host wurde unterbrochen.")


func _fail_join(message: String, can_retry := true) -> void:
	print("Netzwerk: Beitreten fehlgeschlagen: ", message)
	_close_peer()
	join_failed.emit(message, can_retry)


## Client: Sitzung ist vorbei (Host beendet oder Verbindung weg). Charakter
## speichern und zurück ins Hauptmenü, das die Meldung zeigt.
func _end_session_for_client(message: String) -> void:
	print("Netzwerk: ", message)
	save_local_character()
	_close_peer()
	menu_message = message
	GameSession.selected_character = null
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Host: Peers, die sich nach dem Verbinden nicht anmelden, trennen.
func _kick_silent_peers() -> void:
	var limit := int(SETTINGS.handshake_timeout_s * 1000.0)
	for id: int in _pending.keys():
		if Time.get_ticks_msec() - _pending[id] > limit:
			_pending.erase(id)
			multiplayer.multiplayer_peer.disconnect_peer(id)


func _mark_in_world(id: int) -> void:
	var info: NetPlayerInfo = _players.get(id)
	if info == null or info.in_world:
		return
	var players := _copy_players()
	players[id].in_world = true
	_set_players(players)
	_broadcast_players()


## Setzt die Spielerliste und meldet, wer die Welt betreten bzw. verlassen hat.
func _set_players(players: Dictionary[int, NetPlayerInfo]) -> void:
	var old := _players
	_players = players
	for id: int in players:
		if players[id].in_world and not (old.has(id) and old[id].in_world):
			player_entered_world.emit(id)
	for id: int in old:
		if old[id].in_world and not (players.has(id) and players[id].in_world):
			player_left_world.emit(id, old[id].display_name)
	players_changed.emit()


func _copy_players() -> Dictionary[int, NetPlayerInfo]:
	var copy: Dictionary[int, NetPlayerInfo] = {}
	for id: int in _players:
		copy[id] = NetPlayerInfo.from_dict(_players[id].to_dict())
	return copy


func _players_as_array() -> Array:
	var list := []
	for info in get_players():
		list.append(info.to_dict())
	return list


## Host: angenommene Mitspieler (ohne Host, ohne Peers in der Anmeldung).
func _connected_peers() -> Array[int]:
	var result: Array[int] = []
	for id: int in _players:
		if id != 1:
			result.append(id)
	return result


func _broadcast_players() -> void:
	if state != State.HOSTING:
		return
	var list := _players_as_array()
	for id in _connected_peers():
		_rpc_set_players.rpc_id(id, list)


func _broadcast_pings() -> void:
	var peer := _enet_peer()
	if peer == null:
		return
	var pings := {}
	for id in _connected_peers():
		var packet_peer := peer.get_peer(id)
		if packet_peer != null:
			pings[id] = int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	_apply_pings(pings)
	for id in _connected_peers():
		_rpc_set_pings.rpc_id(id, pings)


func _apply_pings(pings: Dictionary) -> void:
	for id in pings:
		var info: NetPlayerInfo = _players.get(int(id))
		if info != null:
			info.ping_ms = int(pings[id])
	players_changed.emit()


## Name im Spiel: bei gleichem Namen mit Zusatz „(2)“, „(3)“ …
func _unique_display_name(character_name: String) -> String:
	var taken: Array[String] = []
	for info: NetPlayerInfo in _players.values():
		taken.append(info.display_name.to_lower())
	if not taken.has(character_name.to_lower()):
		return character_name
	var n := 2
	while taken.has(("%s (%d)" % [character_name, n]).to_lower()):
		n += 1
	return "%s (%d)" % [character_name, n]


func _reject(id: int, message: String) -> void:
	print("Netzwerk: Peer %d abgelehnt: %s" % [id, message])
	_pending.erase(id)
	_rpc_rejected.rpc_id(id, message)
	get_tree().create_timer(REJECT_DISCONNECT_DELAY).timeout.connect(func() -> void:
		if state == State.HOSTING and multiplayer.get_peers().has(id):
			multiplayer.multiplayer_peer.disconnect_peer(id))


## Trennt die Verbindung und geht offline.
func _close_peer() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and not peer is OfflineMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	state = State.OFFLINE
	_pending.clear()
	_local_character = null
	if not _players.is_empty():
		_players = {}
		players_changed.emit()


func _enet_peer() -> ENetMultiplayerPeer:
	return multiplayer.multiplayer_peer as ENetMultiplayerPeer


func _update_traffic(elapsed: float) -> void:
	var peer := _enet_peer()
	if peer == null or peer.host == null:
		_bytes_sent_per_s = 0.0
		_bytes_received_per_s = 0.0
		return
	_bytes_sent_per_s = peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / elapsed
	_bytes_received_per_s = peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / elapsed


func _save_config_value(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(section, key, value)
	config.save(CONFIG_PATH)


# --- RPCs: Client → Host -----------------------------------------------------

## Anmeldung eines Beitretenden.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(version: String, data_hash: String, character: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if state != State.HOSTING or not _pending.has(id):
		return
	if version != get_game_version():
		_reject(id, "Unterschiedliche Spielversion: Host %s, du %s" % [get_game_version(), version])
	elif data_hash != get_data_hash():
		_reject(id, "Unterschiedliche Spieldaten: Host und du habt nicht denselben Stand der Tabellen (Prüfsumme Host %s, du %s)."
				% [get_data_hash().substr(0, 8), data_hash.substr(0, 8)])
	elif _players.size() >= SETTINGS.max_players:
		_reject(id, "Die Sitzung ist voll.")
	else:
		var problem := CHARACTER_RULES.validate(character)
		if problem != "":
			_reject(id, "Ungültiger Charakter: %s" % problem)
			return
		_pending.erase(id)
		var info := NetPlayerInfo.from_character(id, CharacterData.from_dict(character))
		info.display_name = _unique_display_name(info.character_name)
		var players := _copy_players()
		players[id] = info
		_set_players(players)
		print("Netzwerk: %s (Peer %d) angenommen." % [info.display_name, id])
		_rpc_accepted.rpc_id(id, _players_as_array())
		_broadcast_players()


## Der Beitretende hat die Welt geladen.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_world_ready() -> void:
	if state == State.HOSTING:
		_mark_in_world(multiplayer.get_remote_sender_id())


# --- RPCs: Host → Client -----------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _rpc_accepted(players: Array) -> void:
	if state != State.CONNECTING:
		return
	state = State.CONNECTED
	_rpc_set_players(players)
	print("Netzwerk: Vom Host angenommen als Peer %d." % get_local_peer_id())
	join_succeeded.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(message: String) -> void:
	if state == State.CONNECTING:
		_fail_join(message, false)


@rpc("authority", "call_remote", "reliable")
func _rpc_set_players(players: Array) -> void:
	if state != State.CONNECTED:
		return
	var result: Dictionary[int, NetPlayerInfo] = {}
	for data: Dictionary in players:
		var info := NetPlayerInfo.from_dict(data)
		var old: NetPlayerInfo = _players.get(info.peer_id)
		if old != null:
			info.ping_ms = old.ping_ms
		result[info.peer_id] = info
	_set_players(result)


@rpc("authority", "call_remote", "unreliable")
func _rpc_set_pings(pings: Dictionary) -> void:
	if state == State.CONNECTED:
		_apply_pings(pings)


@rpc("authority", "call_remote", "reliable")
func _rpc_session_ended() -> void:
	if state == State.CONNECTED:
		_end_session_for_client("Der Host hat die Sitzung beendet.")
	elif state == State.CONNECTING:
		_fail_join("Der Host hat die Sitzung beendet.", false)
