extends Control
## Charaktererstellung (Ticket #8). Volk, Geschlecht und Klasse wählen, Namen
## eingeben, Charakter in user://characters/ speichern. Völker und Klassen
## kommen aus GameData (res://data/), die Buttons dafür werden zur Laufzeit
## gebaut; ein neues .tres erscheint ohne Code-Änderung.
## Rein lokal: läuft vor dem Hosten oder Beitreten, nichts wird synchronisiert.

const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

const MSG_RULES := "2 bis 12 Buchstaben von A bis Z, ein Wort."
const MSG_FULL := "Du hast bereits die Höchstzahl an Charakteren."
const MSG_SAVE_FAILED := "Der Charakter konnte nicht gespeichert werden."

var _races: Array[RaceData] = []
var _classes: Array[ClassData] = []
var _race_buttons: Array[Button] = []
var _class_buttons: Array[Button] = []
var _race_group := ButtonGroup.new()
var _gender_group := ButtonGroup.new()
var _class_group := ButtonGroup.new()

var _race: RaceData = null
var _gender: CharacterData.Gender = CharacterData.Gender.MALE
var _class: ClassData = null
## Namen der eigenen Charaktere beim Öffnen (für die Prüfung auf doppelt).
var _existing_names: Array[String] = []

@onready var _preview: CharacterPreview = %Preview
@onready var _name_input: LineEdit = %NameInput
@onready var _message: Label = %MessageLabel


func _ready() -> void:
	_races = GameData.get_races()
	_classes = GameData.get_classes()
	for c in CharacterStore.list_all():
		_existing_names.append(c.character_name)

	_build_race_buttons()
	_build_class_buttons()
	%MaleButton.button_group = _gender_group
	%FemaleButton.button_group = _gender_group
	%MaleButton.toggled.connect(func(on: bool) -> void:
		if on: _set_gender(CharacterData.Gender.MALE))
	%FemaleButton.toggled.connect(func(on: bool) -> void:
		if on: _set_gender(CharacterData.Gender.FEMALE))

	_name_input.text_changed.connect(_on_name_changed)
	_name_input.text_submitted.connect(func(_t: String) -> void: _on_create_pressed())
	%RandomButton.pressed.connect(_on_random_pressed)
	%CreateButton.pressed.connect(_on_create_pressed)
	%BackButton.pressed.connect(_on_back_pressed)

	# Startzustand: erstes Volk, männlich, erste Klasse (GDD-Reihenfolge),
	# Name leer, „Erstellen“ deaktiviert.
	_select(0, CharacterData.Gender.MALE, 0)
	_validate_name()
	_name_input.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _build_race_buttons() -> void:
	for i in _races.size():
		var race := _races[i]
		var button := _make_choice_button(race.display_name, _race_group)
		button.toggled.connect(func(on: bool) -> void:
			if on: _set_race(race))
		%RaceGrid.add_child(button)
		_race_buttons.append(button)
	if _races.is_empty():
		push_warning("CharacterCreation: Keine Völker in %s gefunden." % GameData.RACES_DIR)


func _build_class_buttons() -> void:
	for i in _classes.size():
		var class_data := _classes[i]
		var label := "%s (%s)" % [class_data.display_name, class_data.role_name]
		var button := _make_choice_button(label, _class_group)
		button.toggled.connect(func(on: bool) -> void:
			if on: _set_class(class_data))
		%ClassList.add_child(button)
		_class_buttons.append(button)
	if _classes.is_empty():
		push_warning("CharacterCreation: Keine Klassen in %s gefunden." % GameData.CLASSES_DIR)


## Auswahlbutton aus dem Theme (Variation ChoiceButton): umschaltbar, in einer
## ButtonGroup, die Auswahl ist der Zustand „gedrückt“.
func _make_choice_button(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"ChoiceButton"
	button.toggle_mode = true
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.button_group = group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


## Setzt Volk, Geschlecht und Klasse über die Buttons (Index in den Listen).
func _select(race_index: int, gender: CharacterData.Gender, class_index: int) -> void:
	if race_index >= 0 and race_index < _race_buttons.size():
		_race_buttons[race_index].button_pressed = true
	if gender == CharacterData.Gender.MALE:
		%MaleButton.button_pressed = true
	else:
		%FemaleButton.button_pressed = true
	if class_index >= 0 and class_index < _class_buttons.size():
		_class_buttons[class_index].button_pressed = true
	# button_pressed löst toggled nur bei einer Änderung aus; Anzeige daher
	# immer einmal aktualisieren.
	_update_info()
	_update_preview()


func _set_race(race: RaceData) -> void:
	_race = race
	_update_info()
	_update_preview()


func _set_gender(gender: CharacterData.Gender) -> void:
	_gender = gender
	_update_preview()


func _set_class(class_data: ClassData) -> void:
	_class = class_data
	_update_info()
	_update_preview()


func _update_info() -> void:
	%RaceNameLabel.text = _race.display_name if _race != null else ""
	%RaceDescription.text = _race.description if _race != null else ""
	if _class != null:
		%ClassNameLabel.text = _class.display_name
		# Klassenfarbe kommt aus den Daten (ClassData.color), nicht aus dem
		# Theme. Einzige Ausnahme von „keine Farben im Code“, siehe UI-Styleguide.
		%ClassNameLabel.add_theme_color_override("font_color", _class.color)
		%ClassRoleLabel.text = _class.role_name
		%ClassDescription.text = _class.description
	else:
		%ClassNameLabel.text = ""
		%ClassRoleLabel.text = ""
		%ClassDescription.text = ""


func _update_preview() -> void:
	var shown_name := ""
	if CharacterNameValidator.is_plain_letters(_name_input.text):
		shown_name = CharacterNameValidator.normalize(_name_input.text)
	_preview.show_appearance(_race, _gender, shown_name, _class)


## Normalisiert die Eingabe sofort (erster Buchstabe groß, Rest klein) und
## prüft sie. Die Schreibmarke bleibt an ihrer Stelle.
func _on_name_changed(text: String) -> void:
	var normalized := CharacterNameValidator.normalize(text)
	if normalized != text:
		var caret := _name_input.caret_column
		_name_input.text = normalized
		_name_input.caret_column = caret
	_validate_name()
	_update_preview()


## Prüft Name und Auswahl, zeigt Hinweis oder Fehlermeldung und schaltet
## „Erstellen“. Gibt true zurück, wenn erstellt werden darf.
func _validate_name() -> bool:
	var text := _name_input.text
	var error := ""
	if text.is_empty():
		_show_message(MSG_RULES, false)
	else:
		error = CharacterNameValidator.validate(text, _existing_names)
		if error.is_empty() and _existing_names.size() >= CharacterStore.MAX_CHARACTERS:
			error = MSG_FULL
		if error.is_empty():
			_show_message(MSG_RULES, false)
		else:
			_show_message(error, true)
	var ok := not text.is_empty() and error.is_empty() and _race != null and _class != null
	%CreateButton.disabled = not ok
	return ok


## Zeigt einen Hinweis (HintText) oder eine Fehlermeldung (ErrorText). Die
## Meldung steht immer als Text da, nicht nur als Farbe.
func _show_message(text: String, is_error: bool) -> void:
	_message.text = text
	_message.theme_type_variation = &"ErrorText" if is_error else &"HintText"


func _on_random_pressed() -> void:
	var gender := CharacterData.Gender.MALE if randi() % 2 == 0 else CharacterData.Gender.FEMALE
	var race_index := randi() % _races.size() if not _races.is_empty() else -1
	var class_index := randi() % _classes.size() if not _classes.is_empty() else -1
	_select(race_index, gender, class_index)


func _on_create_pressed() -> void:
	if not _validate_name():
		return
	var character_name := CharacterNameValidator.normalize(_name_input.text)
	# Ein zweites Spielfenster könnte inzwischen denselben Namen angelegt haben.
	if CharacterStore.name_exists(character_name):
		_existing_names.append(character_name)
		_validate_name()
		return
	var c := CharacterData.new()
	c.character_name = character_name
	c.race_id = _race.id
	c.gender = _gender
	c.class_id = _class.id
	c.level = 1
	# Als zuletzt gespielt markieren, damit die Charakterauswahl ihn auswählt.
	c.last_played = int(Time.get_unix_time_from_system())
	if CharacterStore.save(c) != OK:
		_show_message(MSG_SAVE_FAILED, true)
		return
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)


## Verwirft alles. Ohne gespeicherte Charaktere geht es zum Hauptmenü, sonst
## zurück zur Charakterauswahl.
func _on_back_pressed() -> void:
	if CharacterStore.count() == 0:
		GameSession.reset()
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
