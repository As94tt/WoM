extends Node
## Autoload „GameSession“ (Ticket #6): hält, was zwischen den Bildschirmen
## weitergegeben wird. Rein lokal; jede Spielinstanz hat ihre eigene Sitzung.
## In M1 entscheidet mode, ob die Welt als Host (create_server) oder als Client
## (create_client) betreten wird.

enum Mode { NONE, HOST, JOIN }

## Wie das Spiel im Hauptmenü gestartet wurde.
var mode: Mode = Mode.NONE
## Der in der Charakterauswahl gewählte Charakter (null = keiner).
var selected_character: CharacterData = null


## Zurück auf den Zustand im Hauptmenü.
func reset() -> void:
	mode = Mode.NONE
	selected_character = null
