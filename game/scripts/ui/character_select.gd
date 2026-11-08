extends Control
## Charakterauswahl (Ticket #6). Zeigt die lokal gespeicherten Charaktere,
## das Platzhaltermodell des gewählten Charakters und führt in die Startwelt (#15).
## Rein lokal: Charaktere liegen in user://characters/ auf dem eigenen PC.
## „Welt betreten“ öffnet je nach Hauptmenü-Wahl den Port-Dialog (Hosten)
## oder den IP/Port-Dialog (Beitreten, #30); erst wenn die Verbindung steht,
## wird die Welt geladen. Beim Beitreten überträgt der Autoload „Network“ nur
## den gewählten Charakter (CharacterData.to_dict()) an den Host.

const CHARACTER_ENTRY := preload("res://scenes/ui/character_entry.tscn")
const WORLD_SCENE := "res://scenes/world/world.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const CHARACTER_CREATION_SCENE := "res://scenes/ui/character_creation.tscn"

var _group := ButtonGroup.new()
var _entries: Array[CharacterEntry] = []
var _selected: CharacterEntry = null

@onready var _preview: CharacterPreview = %Preview
@onready var _dialog: DeleteCharacterDialog = %DeleteDialog
@onready var _connect_dialog: ConnectDialog = %ConnectDialog


func _ready() -> void:
	%BackButton.pressed.connect(_on_back_pressed)
	%SampleButton.pressed.connect(_on_sample_pressed)
	%EnterWorldButton.pressed.connect(_enter_world)
	%NewButton.pressed.connect(_on_new_pressed)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	_dialog.confirmed.connect(_on_delete_confirmed)
	_dialog.cancelled.connect(_on_dialog_closed)
	_connect_dialog.succeeded.connect(_load_world)
	_connect_dialog.cancelled.connect(_on_dialog_closed)
	# Entwicklerhilfe nur in Debug-Builds (Editor und Debug-Export).
	%SampleButton.visible = OS.is_debug_build()
	_reload()
	# Ohne Charaktere direkt zur Erstellung (#8). Nur beim Öffnen, nicht nach
	# dem Löschen des letzten Charakters.
	if _entries.is_empty():
		_open_creation.call_deferred()


## Baut die Liste neu auf und wählt einen Eintrag aus: den mit dem Namen
## select_name, sonst den Eintrag an Position fallback_index, sonst den
## zuletzt gespielten Charakter.
func _reload(select_name: String = "", fallback_index: int = -1) -> void:
	for entry in _entries:
		entry.get_parent().remove_child(entry)
		entry.queue_free()
	_entries.clear()
	_selected = null

	for c in CharacterStore.list_all():
		var entry: CharacterEntry = CHARACTER_ENTRY.instantiate()
		entry.button_group = _group
		%EntryList.add_child(entry)
		entry.setup(c)
		entry.selected.connect(_on_entry_selected)
		entry.activated.connect(_on_entry_activated)
		_entries.append(entry)

	var target: CharacterEntry = null
	if not select_name.is_empty():
		for entry in _entries:
			if entry.character.character_name == select_name:
				target = entry
	if target == null and fallback_index >= 0 and not _entries.is_empty():
		target = _entries[mini(fallback_index, _entries.size() - 1)]
	if target == null:
		target = _most_recent_entry()

	if target != null:
		_select(target)
		target.grab_focus()
	else:
		_preview.clear()
		%BackButton.grab_focus()
	_update_state()


## Eintrag mit dem größten last_played; haben alle 0, der erste.
func _most_recent_entry() -> CharacterEntry:
	var best: CharacterEntry = null
	for entry in _entries:
		if best == null or entry.character.last_played > best.character.last_played:
			best = entry
	return best


func _select(entry: CharacterEntry) -> void:
	if not entry.button_pressed:
		entry.button_pressed = true  # löst toggled -> _on_entry_selected aus
	_on_entry_selected(entry)


func _on_entry_selected(entry: CharacterEntry) -> void:
	if _selected == entry:
		return
	_selected = entry
	_preview.show_character(entry.character)
	_update_state()


func _on_entry_activated(entry: CharacterEntry) -> void:
	_select(entry)
	_enter_world()


func _update_state() -> void:
	var has_characters := not _entries.is_empty()
	%EmptyHint.visible = not has_characters
	_preview.visible = has_characters
	%EnterWorldButton.disabled = _selected == null
	%DeleteButton.disabled = _selected == null
	%NewButton.disabled = _entries.size() >= CharacterStore.MAX_CHARACTERS
	%SampleButton.disabled = _entries.size() >= CharacterStore.MAX_CHARACTERS
	%CountLabel.text = "%d / %d" % [_entries.size(), CharacterStore.MAX_CHARACTERS]


func _enter_world() -> void:
	if _selected == null:
		return
	var c := _selected.character
	c.last_played = int(Time.get_unix_time_from_system())
	CharacterStore.save(c)
	GameSession.selected_character = c
	match GameSession.mode:
		GameSession.Mode.HOST:
			%Layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
			_connect_dialog.open_host(c)
		GameSession.Mode.JOIN:
			%Layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
			_connect_dialog.open_join(c)
		_:
			# Ohne Hauptmenü gestartet (z. B. Szene direkt im Editor): offline.
			_load_world()


func _load_world() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_back_pressed() -> void:
	GameSession.reset()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_new_pressed() -> void:
	if _entries.size() >= CharacterStore.MAX_CHARACTERS:
		return
	_open_creation()


func _open_creation() -> void:
	get_tree().change_scene_to_file(CHARACTER_CREATION_SCENE)


func _on_sample_pressed() -> void:
	var keep := _selected.character.character_name if _selected != null else ""
	SampleCharacters.add_samples(3)
	_reload(keep)


func _on_delete_pressed() -> void:
	if _selected == null:
		return
	%Layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_dialog.open(_selected.character.character_name)


func _on_delete_confirmed() -> void:
	var index := _entries.find(_selected)
	CharacterStore.delete(_selected.character)
	%Layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_reload("", index)


func _on_dialog_closed() -> void:
	%Layout.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	if _selected != null:
		_selected.grab_focus()
