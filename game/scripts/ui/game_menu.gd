class_name GameMenu
extends Control
## Spielmenü (Ticket #17), geöffnet mit Esc oder über die Menüleiste. Das
## Spiel läuft dahinter weiter (kein Pausieren, wegen Multiplayer). Der
## abgedunkelte Hintergrund fängt alle Mausklicks ab; solange das Menü offen
## ist, sperrt die Gruppe „blocks_game_input“ Bewegungstasten (PlayerInput)
## und Tastenkürzel des HUD. Nur Esc oder „Zurück zum Spiel“ schließt es.
##
## Netzwerk (#30): „Zurück zur Charakterauswahl“ und „Spiel beenden“ speichern
## den Charakter und trennen die Verbindung sauber (Network.leave_session).
## Beim Host, solange Mitspieler da sind, erst nach Rückfrage, weil die
## Sitzung dann für alle endet. Das Menü selbst ist rein lokal.
##
## „Aktionsleisten sperren“ (#21): Schalter direkt im Menü (über „Zurück zum
## Spiel“), gespeichert für die ganze Installation in user://settings.cfg
## (GameSettings). Standard: an. Darunter „Kampftext anzeigen“ (#34), ebenso
## gespeichert, Standard: an.

const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const HOST_LEAVE_MESSAGE := "Du bist der Host. Wenn du die Welt verlässt, endet die Sitzung für alle Mitspieler."

enum LeaveTarget { CHARACTER_SELECT, QUIT }

var _leave_target: LeaveTarget = LeaveTarget.CHARACTER_SELECT

@onready var _confirm_dialog: MessageDialog = %ConfirmDialog


func _ready() -> void:
	visible = false
	%ResumeButton.pressed.connect(close)
	%CharacterSelectButton.pressed.connect(_on_character_select_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%LockBarsCheck.button_pressed = GameSettings.is_action_bars_locked()
	%LockBarsCheck.toggled.connect(GameSettings.set_action_bars_locked)
	%CombatTextCheck.button_pressed = GameSettings.is_combat_text_shown()
	%CombatTextCheck.toggled.connect(GameSettings.set_combat_text_shown)
	_confirm_dialog.confirmed.connect(_leave)
	_confirm_dialog.cancelled.connect(func() -> void: %ResumeButton.grab_focus())


func open() -> void:
	visible = true
	# Stand aus GameSettings übernehmen (z. B. nach Änderung an anderer Stelle).
	%LockBarsCheck.set_pressed_no_signal(GameSettings.is_action_bars_locked())
	%CombatTextCheck.set_pressed_no_signal(GameSettings.is_combat_text_shown())
	%ResumeButton.grab_focus()


func close() -> void:
	if _confirm_dialog.visible:
		return  # Erst die Rückfrage beantworten (Esc bricht sie ab).
	visible = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()


func _on_character_select_pressed() -> void:
	_request_leave(LeaveTarget.CHARACTER_SELECT)


func _on_quit_pressed() -> void:
	_request_leave(LeaveTarget.QUIT)


func _request_leave(target: LeaveTarget) -> void:
	_leave_target = target
	if Network.is_host() and Network.has_other_players():
		var button := "Zur Charakterauswahl" if target == LeaveTarget.CHARACTER_SELECT else "Spiel beenden"
		_confirm_dialog.open("Sitzung beenden?", HOST_LEAVE_MESSAGE, button, "Abbrechen")
	else:
		_leave()


func _leave() -> void:
	Network.leave_session()
	if _leave_target == LeaveTarget.QUIT:
		get_tree().quit()
		return
	GameSession.selected_character = null
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
