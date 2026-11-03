extends Control
## Hauptmenü beim Spielstart (Ticket #3).
## Rein lokal, keine Netzwerkfunktion. Die Handler für Hosten und Beitreten
## sind die Einstiegspunkte für M1 (create_server / create_client).


func _ready() -> void:
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	%HostButton.grab_focus()


func _on_host_pressed() -> void:
	# M1: Hier wird das Spiel als Host gestartet (create_server).
	pass


func _on_join_pressed() -> void:
	# M1: Hier tritt der Spieler einem Spiel bei (create_client).
	pass


func _on_quit_pressed() -> void:
	get_tree().quit()
