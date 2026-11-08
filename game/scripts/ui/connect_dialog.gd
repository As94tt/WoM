class_name ConnectDialog
extends Control
## Dialog vor dem Betreten der Welt im Mehrspielermodus (Ticket #30).
## - Hosten: Port (Standard 7777, zuletzt verwendeter vorausgefüllt), Hinweis
##   zur Portfreigabe im Router, „Starten“ und „Abbrechen“.
## - Beitreten: IP-Adresse und Port (zuletzt verwendete Werte vorausgefüllt),
##   „Verbinden“ und „Abbrechen“. Während des Verbindens „Verbinde …“ mit
##   Abbrechen-Button.
## Schlägt etwas fehl, steht die Meldung im Dialog und man kann es erneut
## versuchen oder abbrechen; man bleibt in der Charakterauswahl.
## Die Verbindung selbst baut der Autoload „Network“ auf. Ist sie bereit,
## sendet der Dialog succeeded; der Aufrufer lädt dann die Welt.

signal succeeded
signal cancelled

enum Mode { HOST, JOIN }

const MIN_PORT := 1024
const MAX_PORT := 65535
const HOST_HINT := "Mitspieler im selben Netzwerk (LAN) treten über deine IP-Adresse bei. Für das Spielen über das Internet musst du diesen Port (UDP) in deinem Router freigeben."
const JOIN_HINT := "Gib die IP-Adresse und den Port des Hosts ein. Im selben Netzwerk (LAN) ist das die lokale IP-Adresse des Host-PCs."
## Pause zwischen zwei Versuchen beim Schnellstart (--join), in Sekunden.
const RETRY_DELAY := 1.0

var _mode: Mode = Mode.JOIN
var _character: CharacterData = null
var _busy := false
var _attempts_left := 0
var _address := ""
var _port := 0


func _ready() -> void:
	hide()
	%ConfirmButton.pressed.connect(_submit)
	%CancelButton.pressed.connect(_on_cancel_pressed)
	%AddressInput.text_submitted.connect(func(_t: String) -> void: _submit())
	%PortInput.text_submitted.connect(func(_t: String) -> void: _submit())
	Network.join_succeeded.connect(_on_join_succeeded)
	Network.join_failed.connect(_on_join_failed)


## Port-Dialog des Hosts.
func open_host(character: CharacterData) -> void:
	_open(Mode.HOST, character)
	%PortInput.grab_focus()


## IP/Port-Dialog zum Beitreten.
func open_join(character: CharacterData) -> void:
	_open(Mode.JOIN, character)
	%AddressInput.grab_focus()


## Schnellstart (--host): ohne Eingabe sofort hosten.
func start_host(character: CharacterData, port: int) -> void:
	_open(Mode.HOST, character)
	%PortInput.text = str(port)
	_submit()


## Schnellstart (--join): ohne Eingabe verbinden, bis zu attempts Versuche
## (der Host startet evtl. gerade erst).
func start_join(character: CharacterData, address: String, port: int, attempts: int) -> void:
	_open(Mode.JOIN, character)
	%AddressInput.text = address
	%PortInput.text = str(port)
	_submit(attempts)


func _open(mode: Mode, character: CharacterData) -> void:
	_mode = mode
	_character = character
	var last := Network.load_last_connection()
	var hosting := mode == Mode.HOST
	%TitleLabel.text = "Spiel hosten" if hosting else "Spiel beitreten"
	%HintLabel.text = HOST_HINT if hosting else JOIN_HINT
	%ConfirmButton.text = "Starten" if hosting else "Verbinden"
	%AddressLabel.visible = not hosting
	%AddressInput.visible = not hosting
	%AddressInput.text = last["address"]
	%PortInput.text = str(last["host_port"] if hosting else last["join_port"])
	_set_busy(false)
	_set_status("", false)
	show()


func _submit(attempts := 1) -> void:
	if _busy or not visible:
		return
	var port_text: String = %PortInput.text.strip_edges()
	var port := port_text.to_int()
	if not port_text.is_valid_int() or port < MIN_PORT or port > MAX_PORT:
		_set_status("Der Port muss eine Zahl von %d bis %d sein." % [MIN_PORT, MAX_PORT], true)
		return
	if _mode == Mode.HOST:
		var error := Network.host_game(port, _character)
		if error != "":
			_set_status(error, true)
			return
		Network.save_last_host_port(port)
		hide()
		succeeded.emit()
		return
	var address: String = %AddressInput.text.strip_edges()
	if address.is_empty():
		_set_status("Bitte eine IP-Adresse eingeben.", true)
		return
	_address = address
	_port = port
	_attempts_left = attempts
	Network.save_last_join(address, port)
	_try_join()


func _try_join() -> void:
	var error := Network.join_game(_address, _port, _character)
	if error != "":
		_set_busy(false)
		_set_status(error, true)
		return
	_set_busy(true)
	_set_status("Verbinde mit %s:%d …" % [_address, _port], false)


func _on_join_succeeded() -> void:
	if not _busy:
		return
	_set_busy(false)
	hide()
	succeeded.emit()


func _on_join_failed(message: String, can_retry: bool) -> void:
	if not _busy:
		return
	_attempts_left -= 1
	if _attempts_left > 0 and can_retry:
		_set_status("%s\nNeuer Versuch …" % message, false)
		get_tree().create_timer(RETRY_DELAY).timeout.connect(func() -> void:
			if _busy and visible:
				_try_join())
		return
	_set_busy(false)
	_set_status(message, true)


func _on_cancel_pressed() -> void:
	if _busy:
		Network.cancel_join()
		_set_busy(false)
	hide()
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func _set_busy(busy: bool) -> void:
	_busy = busy
	%AddressInput.editable = not busy
	%PortInput.editable = not busy
	%ConfirmButton.visible = not busy
	if busy:
		%CancelButton.grab_focus()


## Meldungszeile: Fehler (ErrorText) oder Status wie „Verbinde …“ (BodyText).
func _set_status(text: String, is_error: bool) -> void:
	%StatusLabel.text = text
	%StatusLabel.theme_type_variation = &"ErrorText" if is_error else &"BodyText"
