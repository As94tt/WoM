class_name NetOverlay
extends PanelContainer
## Netzwerk-Overlay (Ticket #30), umschaltbar mit F9 (seit #31, vorher F3; Aktion
## „toggle_net_overlay“): eigene Peer-ID, Host ja/nein, Ping zum Host,
## gesendete und empfangene Daten pro Sekunde, Anzahl Spieler.
## Rein lokal; liest nur den Autoload „Network“.

const TOGGLE_ACTION := &"toggle_net_overlay"
## Aktualisierungen pro Sekunde.
const UPDATE_INTERVAL := 0.5

var _elapsed := 0.0


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo():
		visible = not visible
		_elapsed = UPDATE_INTERVAL
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	var online := Network.is_online()
	%InfoLabel.text = "\n".join([
		"Peer-ID: %d · Host: %s%s" % [Network.get_local_peer_id(),
				"ja" if Network.is_host() else "nein", "" if online else " (offline)"],
		"Ping: %d ms · Spieler: %d / %d" % [Network.get_local_ping_ms(),
				maxi(Network.get_player_count(), 1), Network.SETTINGS.max_players],
		"Gesendet: %s · Empfangen: %s" % [_format_rate(Network.get_bytes_sent_per_second()),
				_format_rate(Network.get_bytes_received_per_second())],
	])


static func _format_rate(bytes_per_second: float) -> String:
	return ("%.1f KB/s" % (bytes_per_second / 1024.0)).replace(".", ",")
