extends Control
## Hauptmenü beim Spielstart (Ticket #3).
## Hosten und Beitreten merken den Modus in GameSession und öffnen die
## Charakterauswahl (Ticket #6). Noch keine Netzwerkfunktion; in M1 wird
## der Modus beim Betreten der Welt ausgewertet (create_server / create_client).

const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"


func _ready() -> void:
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%HostButton.grab_focus()


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
