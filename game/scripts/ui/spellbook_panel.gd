class_name SpellbookPanel
extends VBoxContainer
## Inhalt des Zauberbuchs (Taste P, Ticket #21), eingesetzt über
## Hud.get_hud_window(&"spellbook").set_content() (GameWorld).
##
## Oben die Reiter („Allgemein“ und die Klasse; weitere, z. B. Unterklassen,
## kommen über PlayerAbilities.get_spellbook_tabs dazu), darunter je Seite
## PAGE_SIZE Fähigkeiten in zwei Spalten, sortiert nach benötigter Stufe.
## Bei mehr als PAGE_SIZE Fähigkeiten erscheinen Pfeil-Buttons und
## „Seite 1 / 2“. Nicht erlernte Fähigkeiten sind ausgegraut.
##
## Rein lokal: zeigt die Fähigkeiten der eigenen Figur und folgt ihrer Stufe
## (PlayerAbilities.learned_changed).

const ENTRY_SCENE := preload("res://scenes/ui/hud/spellbook_entry.tscn")
## Fähigkeiten pro Seite (zwei Spalten à sechs).
const PAGE_SIZE := 12

var _abilities: PlayerAbilities = null
var _tabs: Array[SpellbookTabData] = []
var _tab_index := 0
var _page := 0
var _tab_group := ButtonGroup.new()

@onready var _tab_row: HBoxContainer = %TabRow
@onready var _grid: GridContainer = %Grid
@onready var _paging: Control = %Paging
@onready var _page_label: Label = %PageLabel
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	_prev_button.pressed.connect(func() -> void: show_page(_page - 1))
	_next_button.pressed.connect(func() -> void: show_page(_page + 1))
	_rebuild()


## Zeigt die Fähigkeiten der eigenen Figur (GameWorld, sobald sie bereit ist).
func setup(abilities: PlayerAbilities) -> void:
	if _abilities != null:
		_abilities.learned_changed.disconnect(_refresh_entries)
	_abilities = abilities
	if _abilities != null:
		_abilities.learned_changed.connect(_refresh_entries)
	_tabs = _abilities.get_spellbook_tabs() if _abilities != null else []
	_tab_index = clampi(_tab_index, 0, maxi(0, _tabs.size() - 1))
	_page = 0
	_rebuild()


## Reiter anzeigen (Index in get_tabs()).
func show_tab(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	_tab_index = index
	_page = 0
	_rebuild()


func show_page(page: int) -> void:
	_page = clampi(page, 0, get_page_count() - 1)
	_rebuild_page()


func get_tabs() -> Array[SpellbookTabData]:
	return _tabs


func get_page() -> int:
	return _page


func get_page_count() -> int:
	return maxi(1, ceili(float(_current_abilities().size()) / PAGE_SIZE))


## Einträge der aktuellen Seite.
func get_entries() -> Array[SpellbookEntry]:
	var result: Array[SpellbookEntry] = []
	for child in _grid.get_children():
		if child is SpellbookEntry and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _current_abilities() -> Array[AbilityData]:
	if _tab_index < 0 or _tab_index >= _tabs.size():
		return []
	return _tabs[_tab_index].get_sorted_abilities()


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child in _tab_row.get_children():
		_tab_row.remove_child(child)
		child.queue_free()
	for i in _tabs.size():
		var button := Button.new()
		button.theme_type_variation = &"ChoiceButton"
		button.toggle_mode = true
		button.button_group = _tab_group
		button.focus_mode = Control.FOCUS_NONE
		button.text = _tabs[i].title
		button.button_pressed = i == _tab_index
		button.pressed.connect(show_tab.bind(i))
		_tab_row.add_child(button)
	_rebuild_page()


func _rebuild_page() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var abilities := _current_abilities()
	var first := _page * PAGE_SIZE
	for i in range(first, mini(first + PAGE_SIZE, abilities.size())):
		var entry: SpellbookEntry = ENTRY_SCENE.instantiate()
		_grid.add_child(entry)
		entry.setup(abilities[i], _abilities)
	var pages := get_page_count()
	_paging.visible = pages > 1
	_page_label.text = "Seite %d / %d" % [_page + 1, pages]
	_prev_button.disabled = _page <= 0
	_next_button.disabled = _page >= pages - 1


func _refresh_entries() -> void:
	for entry in get_entries():
		entry.refresh()
