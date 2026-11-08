extends Node
## Autoload „GameSession“ (Ticket #6): hält, was zwischen den Bildschirmen
## weitergegeben wird. Rein lokal; jede Spielinstanz hat ihre eigene Sitzung.
## mode entscheidet, ob „Welt betreten“ eine Sitzung als Host öffnet oder
## einer beitritt (#30, Verbindung im Autoload „Network“).

enum Mode { NONE, HOST, JOIN }

## Wie das Spiel im Hauptmenü gestartet wurde.
var mode: Mode = Mode.NONE
## Der in der Charakterauswahl gewählte Charakter (null = keiner).
var selected_character: CharacterData = null
## Startparameter (--host/--join) wurden schon ausgewertet; sie gelten nur
## einmal beim Programmstart, nicht nach der Rückkehr ins Hauptmenü.
var quick_start_done := false


## Zurück auf den Zustand im Hauptmenü.
func reset() -> void:
	mode = Mode.NONE
	selected_character = null
