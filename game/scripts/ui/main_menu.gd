extends Control
## Hauptmenü beim Spielstart (Ticket #3).
## Hosten und Beitreten merken den Modus in GameSession und öffnen die
## Charakterauswahl (Ticket #6); verbunden wird dort nach „Welt betreten“ (#30).
##
## Netzwerk (#30):
## - Meldungen aus der letzten Sitzung (z. B. „Der Host hat die Sitzung
##   beendet“) zeigt ein Hinweisdialog beim Öffnen.
## - Startparameter --host / --join <IP> [--port <Port>] [--character <Name>]
##   überspringen die Menüs einmal beim Programmstart (siehe QuickStart).

const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const WORLD_SCENE := "res://scenes/world/world.tscn"

@onready var _message_dialog: MessageDialog = %MessageDialog
@onready var _connect_dialog: ConnectDialog = %ConnectDialog


func _ready() -> void:
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	_message_dialog.confirmed.connect(_on_dialog_closed)
	_connect_dialog.succeeded.connect(_on_quick_start_succeeded)
	_connect_dialog.cancelled.connect(_on_quick_start_cancelled)
	%HostButton.grab_focus()
	if Network.menu_message != "":
		_show_message("Sitzung beendet", Network.menu_message)
		Network.menu_message = ""
	elif not GameSession.quick_start_done:
		GameSession.quick_start_done = true
		_run_quick_start.call_deferred()


func _on_host_pressed() -> void:
	_open_character_select(GameSession.Mode.HOST)


func _on_join_pressed() -> void:
	_open_character_select(GameSession.Mode.JOIN)


func _open_character_select(mode: GameSession.Mode) -> void:
	GameSession.reset()
	GameSession.mode = mode
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_message(title: String, message: String) -> void:
	%MarginContainer.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_message_dialog.open(title, message)


func _on_dialog_closed() -> void:
	%MarginContainer.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	%HostButton.grab_focus()


# --- Startparameter ----------------------------------------------------------

func _run_quick_start() -> void:
	var qs := QuickStart.from_command_line()
	if qs.mode == QuickStart.Mode.NONE:
		return
	var character := qs.get_character()
	var port := qs.port if qs.port > 0 else Network.SETTINGS.default_port
	GameSession.reset()
	GameSession.selected_character = character
	%MarginContainer.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	print("Schnellstart: %s als %s" % ["Host" if qs.mode == QuickStart.Mode.HOST else "Beitritt", character.character_name])
	if qs.mode == QuickStart.Mode.HOST:
		GameSession.mode = GameSession.Mode.HOST
		_connect_dialog.start_host(character, port)
	else:
		GameSession.mode = GameSession.Mode.JOIN
		_connect_dialog.start_join(character, qs.address, port, Network.SETTINGS.quick_join_attempts)


func _on_quick_start_succeeded() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_quick_start_cancelled() -> void:
	GameSession.reset()
	_on_dialog_closed()
