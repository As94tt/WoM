extends Control
## Vorschauszene für das zentrale UI-Theme (Ticket #10, erweitert in #6).
## Zeigt alle Button-Zustände gleichzeitig. Hover lässt sich nicht statisch
## erzwingen, deshalb bekommen die Hover-Beispiele die Hover-Werte aus dem
## Theme als Normalzustand. Es werden keine eigenen Farben gesetzt, nur Werte
## aus theme.tres übernommen. Rein lokal, keine Netzwerkfunktion.


func _ready() -> void:
	var hover_button: Button = %HoverButton
	hover_button.add_theme_stylebox_override("normal", hover_button.get_theme_stylebox("hover"))
	hover_button.add_theme_color_override("font_color", hover_button.get_theme_color("font_hover_color"))

	# Listeneinträge der Charakterauswahl (#6) mit einem Beispielcharakter.
	# Volk und Klasse kommen aus den Daten, die Klassenfarbe aus ClassData.
	var sample := CharacterData.new()
	sample.character_name = "Durgin"
	sample.level = 12
	var races := GameData.get_races()
	var classes := GameData.get_classes()
	if not races.is_empty():
		sample.race_id = races[0].id
	if not classes.is_empty():
		sample.class_id = classes[0].id
	for entry: CharacterEntry in [%EntryNormal, %EntryHover, %EntrySelected, %EntryDisabled]:
		entry.setup(sample)
	%EntryHover.add_theme_stylebox_override("normal", %EntryHover.get_theme_stylebox("hover"))

	%FocusButton.grab_focus()
