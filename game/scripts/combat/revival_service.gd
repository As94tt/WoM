class_name RevivalService
extends Node
## Rückkehr nach dem Tod (Ticket #35). Kindknoten „Revival“ der Welt
## (GameWorld legt ihn an, deshalb ist der Pfad auf allen Instanzen gleich).
##
## Zwei Wege zurück:
## - „Am Wiedereinstiegspunkt erscheinen“ (Knopf im Fenster „Ihr seid
##   gestorben“, DeathWindow): Der Host setzt die Figur an den nächsten
##   Wiedereinstiegspunkt (GameWorld, Punkte aus #15) mit wiedereinstieg_leben
##   und wiedereinstieg_ressourcen Prozent (spielkonstanten.csv) und der Aura
##   „Geschwächt“ (data/auras/geschwaecht.tres).
## - Hilfe eines Mitspielers: Aufhelfen (Taste F, Fähigkeit „aufhelfen“) oder
##   eine Wiederbelebungsfähigkeit wirken am Ende den Effekt
##   ResurrectEffect; der ruft host_offer. Der Gefallene bekommt die Anfrage
##   „X möchte Euch aufhelfen – Annehmen / Ablehnen“; nimmt er an, steht er an
##   Ort und Stelle mit dem Prozentwert der Fähigkeit (werte.leben) auf, ohne
##   „Geschwächt“.
## Sind alle Spieler der Sitzung tot, erscheinen alle nach alle_tot_wartezeit
## Sekunden am Wiedereinstiegspunkt (wie mit dem Knopf). Kein Verlust an
## Erfahrung oder Gegenständen.
##
## Netzwerk: Alles entscheidet der Host. Clients schicken Wünsche (_rpc_release,
## _rpc_answer); der Host schickt Anfragen (_rpc_offer) und den Zeitpunkt der
## gemeinsamen Rückkehr (_rpc_all_dead) nur an die Betroffenen bzw. an alle
## in der Welt. Leben und Position kommen über die üblichen Wege (StatsSync,
## server_teleport). Ohne Sitzung ist die eigene Instanz der Host.

## Eigene Figur: Anfrage zum Aufhelfen (helper_name leer = keine mehr).
signal offer_changed(helper_name: String)
## Alle tot: gemeinsame Rückkehr um release_at (Host-Zeit), −1 = nicht (mehr).
signal all_dead_changed(release_at: float)

const NODE_NAME := "Revival"
const GROUP := &"revival_service"
const WEAKENED_AURA := &"geschwaecht"

## Lokal: offene Anfrage an die eigene Figur (Name des Helfers, leer = keine).
var local_offer := ""
## Lokal: Zeitpunkt der gemeinsamen Rückkehr (Host-Zeit), −1 = keiner.
var local_release_at := -1.0

## Welt (GameWorld; als Node, damit keine zyklische Abhängigkeit entsteht).
var _world: Node = null
## Host: Peer des Gefallenen → {"helper": Name, "percent": Leben in Prozent}.
var _offers: Dictionary = {}
var _release_at := -1.0


func _init() -> void:
	name = NODE_NAME
	add_to_group(GROUP)


## Der Dienst der laufenden Welt oder null.
static func get_instance(tree: SceneTree) -> RevivalService:
	return tree.get_first_node_in_group(GROUP) as RevivalService if tree != null else null


func setup(world: Node) -> void:
	_world = world


func _process(_delta: float) -> void:
	if not Network.is_host() or _world == null:
		return
	_clean_offers()
	_check_all_dead()


# --- Wünsche der eigenen Figur ---------------------------------------------------

## Knopf „Am Wiedereinstiegspunkt erscheinen“.
func request_release() -> void:
	if Network.is_host():
		_host_release_peer(multiplayer.get_unique_id())
	else:
		_rpc_release.rpc_id(1)


## Antwort auf eine Anfrage zum Aufhelfen.
func answer_offer(accept: bool) -> void:
	_set_local_offer("")
	if Network.is_host():
		_host_answer(multiplayer.get_unique_id(), accept)
	else:
		_rpc_answer.rpc_id(1, accept)


## Kann gerade ein lebender Mitspieler helfen? (überall, für das Fenster)
func can_anyone_help(dead_player: Unit) -> bool:
	if _world == null:
		return false
	for player in _world.get_all_players():
		if player != dead_player and not player.is_dead():
			return true
	return false


# --- Host ------------------------------------------------------------------------

## Host: Ein Helfer möchte target wiederbeleben (ResurrectEffect). Schickt die
## Anfrage an den Besitzer von target; eine ältere Anfrage wird ersetzt.
func host_offer(target: Unit, helper: Unit, health_percent: float) -> void:
	if not Network.is_host() or target == null or not target.is_player_unit() or not target.is_dead():
		return
	var peer := target.get_controlling_peer()
	var helper_name := helper.get_unit_name() if helper != null and is_instance_valid(helper) else "Jemand"
	_offers[peer] = {"helper": helper_name, "percent": health_percent}
	_send_offer(peer, helper_name)


## Host: Figur am nächsten Wiedereinstiegspunkt zurückholen (50 %, Geschwächt).
func host_release(player: PlayerCharacter) -> void:
	if not Network.is_host() or player == null or not player.is_dead():
		return
	_offers.erase(player.peer_id)
	if _world != null:
		player.server_teleport(_world.get_respawn_transform(player.global_position))
	host_revive(player, Data.konstante(&"wiedereinstieg_leben", 50.0),
			Data.konstante(&"wiedereinstieg_ressourcen", 50.0), true)


## Host: unit lebt wieder mit health_percent Leben und resource_percent Mana
## bzw. Energie (Wut und Chi 0); weakened = Aura „Geschwächt“.
func host_revive(unit: Unit, health_percent: float, resource_percent: float, weakened: bool) -> void:
	if not Network.is_host() or unit == null or not unit.is_dead() or unit.get_stats() == null:
		return
	unit.get_stats().revive(health_percent, resource_percent)
	if unit.get_combat() != null:
		unit.get_combat().check_death()
		if weakened:
			var aura := GameData.get_aura(WEAKENED_AURA)
			if aura != null:
				unit.get_combat().apply_aura(aura, null)
	if unit.is_player_unit():
		_offers.erase(unit.get_controlling_peer())


func _host_release_peer(peer: int) -> void:
	if _world != null:
		host_release(_world.get_player(peer))


func _host_answer(peer: int, accept: bool) -> void:
	var offer: Dictionary = _offers.get(peer, {})
	_offers.erase(peer)
	if not accept or offer.is_empty() or _world == null:
		return
	var player: PlayerCharacter = _world.get_player(peer)
	if player != null and player.is_dead():
		var percent := float(offer["percent"])
		host_revive(player, percent, percent, false)


## Host: Anfragen an Figuren, die nicht mehr tot (oder weg) sind, zurückziehen.
func _clean_offers() -> void:
	for peer: int in _offers.keys():
		var player: PlayerCharacter = _world.get_player(peer)
		if player == null or not player.is_dead():
			_offers.erase(peer)
			_send_offer(peer, "")


## Host: Sind alle Spieler tot, nach alle_tot_wartezeit alle zurückholen.
func _check_all_dead() -> void:
	var players: Array[PlayerCharacter] = _world.get_all_players()
	var all_dead := not players.is_empty()
	for player in players:
		if not player.is_dead():
			all_dead = false
			break
	var now := Network.host_time()
	if not all_dead:
		if _release_at >= 0.0:
			_release_at = -1.0
			_broadcast_all_dead(-1.0)
		return
	if _release_at < 0.0:
		_release_at = now + Data.konstante(&"alle_tot_wartezeit", 5.0)
		_broadcast_all_dead(_release_at)
	elif now >= _release_at:
		_release_at = -1.0
		_broadcast_all_dead(-1.0)
		for player in players:
			host_release(player)


func _send_offer(peer: int, helper_name: String) -> void:
	if peer == multiplayer.get_unique_id():
		_set_local_offer(helper_name)
	elif multiplayer.get_peers().has(peer) and Network.is_peer_in_world(peer):
		_rpc_offer.rpc_id(peer, helper_name)


func _broadcast_all_dead(release_at: float) -> void:
	_set_local_release(release_at)
	for peer in multiplayer.get_peers():
		if Network.is_peer_in_world(peer):
			_rpc_all_dead.rpc_id(peer, release_at)


func _set_local_offer(helper_name: String) -> void:
	if local_offer == helper_name:
		return
	local_offer = helper_name
	offer_changed.emit(helper_name)


func _set_local_release(release_at: float) -> void:
	local_release_at = release_at
	all_dead_changed.emit(release_at)


# --- Netzwerk --------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_release() -> void:
	if Network.is_host():
		_host_release_peer(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_answer(accept: bool) -> void:
	if Network.is_host():
		_host_answer(multiplayer.get_remote_sender_id(), accept)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_offer(helper_name: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_set_local_offer(helper_name)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_all_dead(release_at: float) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_set_local_release(release_at)
