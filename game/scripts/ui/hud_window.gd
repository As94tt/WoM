class_name HudWindow
extends PanelContainer
## Rahmen für ein Fenster des Interfaces (Ticket #17): Titel, Schließen-Button
## (X) und Inhaltsbereich. Solange kein Inhalt eingesetzt ist, steht dort
## „Kommt bald“. Spätere Tickets setzen ihren Inhalt mit set_content() ein
## (z. B. die Karte aus #15), ohne den Rahmen zu ändern.
## Geöffnet und geschlossen wird über das HUD (hud.gd), nie direkt über
## visible, damit die Regeln für Überlappung an einer Stelle bleiben.

## Wird ausgelöst, wenn der Spieler auf X klickt.
signal close_requested

## Kennung, unter der das HUD das Fenster verwaltet (z. B. &"character").
@export var window_id: StringName
## Angezeigter Titel.
@export var title := "":
	set(value):
		title = value
		if is_node_ready():
			%TitleLabel.text = value
## Aktion der Input Map, die das Fenster umschaltet (für den Tooltip).
@export var toggle_action: StringName
## Exklusive Fenster (Karte) schließen beim Öffnen alle anderen; öffnet sich
## ein anderes Fenster, schließt sich das exklusive.
@export var exclusive := false


func _ready() -> void:
	%TitleLabel.text = title
	%CloseButton.pressed.connect(close_requested.emit)


## Ersetzt den Inhalt des Fensters (den Platzhalter „Kommt bald“).
func set_content(content: Control) -> void:
	var area: Control = %ContentArea
	for child in area.get_children():
		area.remove_child(child)
		child.queue_free()
	area.add_child(content)


## Der Inhaltsbereich, falls ein Ticket mehr als ein Element einsetzen will.
func get_content_area() -> Control:
	return %ContentArea
