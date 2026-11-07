class_name GameMenu
extends Control
## Spielmenü (Ticket #17), geöffnet mit Esc oder über die Menüleiste. Das
## Spiel läuft dahinter weiter (kein Pausieren, wegen Multiplayer). Der
## abgedunkelte Hintergrund fängt alle Mausklicks ab; solange das Menü offen
## ist, sperrt die Gruppe „blocks_game_input“ Bewegungstasten (PlayerInput)
## und Tastenkürzel des HUD. Nur Esc oder „Zurück zum Spiel“ schließt es.
## Rein lokal, nichts wird synchronisiert.

const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"


func _ready() -> void:
	visible = false
	%ResumeButton.pressed.connect(close)
	%CharacterSelectButton.pressed.connect(_on_character_select_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)


func open() -> void:
	visible = true
	%ResumeButton.grab_focus()


func close() -> void:
	visible = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()


func _on_character_select_pressed() -> void:
	# Wie bisher der Button „Zur Charakterauswahl“ der Testszene (#6).
	# Ab M1 wird hier zusätzlich die Verbindung getrennt.
	GameSession.selected_character = null
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()
