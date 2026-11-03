class_name CharacterEntry
extends Button
## Ein Eintrag in der Charakterliste (Ticket #6): Name, Stufe, Volk und Klasse.
## Auswahl über toggle_mode in einer ButtonGroup, Doppelklick = Welt betreten.
## Rein lokal, keine Netzwerkfunktion.

## Der Eintrag wurde ausgewählt (Klick oder Tastatur).
signal selected(entry: CharacterEntry)
## Doppelklick auf den Eintrag.
signal activated(entry: CharacterEntry)

var character: CharacterData

@onready var _margin: MarginContainer = %Margin


func _ready() -> void:
	toggled.connect(_on_toggled)
	_margin.minimum_size_changed.connect(_update_minimum_height)
	_update_minimum_height()


## Füllt den Eintrag mit den Angaben des Charakters. Unbekanntes Volk oder
## unbekannte Klasse: die ID steht als Text da, dazu eine Warnung im Log.
func setup(c: CharacterData) -> void:
	character = c
	%NameLabel.text = c.character_name
	%LevelLabel.text = "Stufe %d" % c.level
	var race := c.get_race()
	if race != null:
		%RaceLabel.text = race.display_name
	else:
		%RaceLabel.text = String(c.race_id)
		push_warning("CharacterEntry: Unbekanntes Volk „%s“ bei %s." % [c.race_id, c.character_name])
	var class_data := c.get_class_data()
	if class_data != null:
		%ClassLabel.text = class_data.display_name
		# Klassenfarbe kommt aus den Daten (ClassData.color), nicht aus dem
		# Theme. Einzige Ausnahme von „keine Farben im Code“, siehe UI-Styleguide.
		%ClassLabel.add_theme_color_override("font_color", class_data.color)
	else:
		%ClassLabel.text = String(c.class_id)
		push_warning("CharacterEntry: Unbekannte Klasse „%s“ bei %s." % [c.class_id, c.character_name])
	tooltip_text = "%s, Stufe %d, %s %s" % [c.character_name, c.level, %RaceLabel.text, %ClassLabel.text]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and event.double_click:
		activated.emit(self)
		accept_event()


func _on_toggled(on: bool) -> void:
	if on:
		selected.emit(self)


## Der Button selbst kann die Kinder-Container nicht messen, deshalb wird
## seine Mindesthöhe aus dem Inhalt übernommen.
func _update_minimum_height() -> void:
	custom_minimum_size.y = _margin.get_combined_minimum_size().y
