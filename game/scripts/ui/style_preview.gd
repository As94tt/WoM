extends Control
## Vorschauszene für das zentrale UI-Theme (Ticket #10, erweitert in #6, #8, #17, #15 und #30).
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

	# Auswahlbutton der Charaktererstellung (#8), Hover dauerhaft dargestellt.
	var choice_hover: Button = %ChoiceHover
	choice_hover.add_theme_stylebox_override("normal", choice_hover.get_theme_stylebox("hover"))
	choice_hover.add_theme_color_override("font_color", choice_hover.get_theme_color("font_hover_color"))

	# Interface im Spiel (#17): Aktionsslots mit Hover, Aufleuchten und Taste.
	%SlotHover.add_theme_stylebox_override("normal", %SlotHover.get_theme_stylebox("hover"))
	%SlotFlashing.get_node("%Flash").visible = true
	%SlotKey.input_action = &"action_bar_1_slot_1"

	# Mitspieler auf der Karte (#30): Klassenfarbe aus den Daten.
	if not classes.is_empty():
		%MateMarker.fill_color = classes[0].color

	%FocusButton.grab_focus()
