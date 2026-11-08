class_name ActionBar
extends HBoxContainer
## Eine Aktionsleiste mit Slots (Ticket #17, Inhalt seit #21). Die Slots
## entstehen beim Start aus action_slot.tscn. Ist action_prefix gesetzt,
## gehört zu Slot n die Aktion „<action_prefix><n>“ der Input Map (z. B.
## action_bar_1_slot_1); Leisten ohne Präfix haben keine Tasten. Rein lokal.
##
## Inhalt (#21): Die Belegung steht in einem ActionBarLayout (beide Leisten
## teilen sich eins, bar_index wählt die Leiste); setup() verbindet die Leiste
## mit Belegung und Fähigkeiten der eigenen Figur. Klick oder Taste auf einem
## belegten Slot ruft PlayerAbilities.use_ability() (die zentrale Funktion
## „Fähigkeit benutzen“).
##
## Ablegen (drop_on_slot):
## - von einem anderen Slot: verschieben bzw. tauschen,
## - aus dem Zauberbuch (oder was nach dem Ersetzen am Zeiger hängt): Die
##   Fähigkeit kommt in den Slot; lag dort etwas anderes, hängt das danach am
##   Mauszeiger und kann woanders abgelegt werden.

## Wird ausgelöst, wenn ein Slot per Klick oder Taste ausgelöst wurde
## (Index ab 0), nach use_ability().
signal slot_activated(index: int)

const SLOT_SCENE := preload("res://scenes/ui/hud/action_slot.tscn")

## Anzahl der Slots (gleich ActionBarLayout.SLOT_COUNT).
@export var slot_count := 12
## Präfix der Input-Map-Aktionen (leer = Leiste ohne Tasten).
@export var action_prefix := ""
## Welche Leiste der Belegung diese Leiste zeigt (0 = Leiste 1).
@export var bar_index := 0

var _slots: Array[ActionSlot] = []
var _layout: ActionBarLayout = null
var _abilities: PlayerAbilities = null


## Zustand der Slots (#33): Abklingzeit, Reichweite, Ressource, Procs.
func _process(_delta: float) -> void:
	if _layout == null or _abilities == null or not is_visible_in_tree():
		return
	for i in _slots.size():
		var content := _layout.get_content(bar_index, i)
		var state := {}
		if content != null and content.is_ability() and _abilities.is_learned(content.get_ability()):
			state = _abilities.get_slot_state(content.get_ability())
		_slots[i].update_state(state)


func _ready() -> void:
	for i in slot_count:
		var slot: ActionSlot = SLOT_SCENE.instantiate()
		slot.name = "Slot%d" % (i + 1)
		slot.bar = self
		slot.index = i
		if action_prefix != "":
			slot.input_action = StringName("%s%d" % [action_prefix, i + 1])
		slot.activated.connect(_on_slot_activated.bind(i))
		add_child(slot)
		_slots.append(slot)


## Verbindet die Leiste mit der Belegung und den Fähigkeiten der eigenen
## Figur (GameWorld über Hud.setup_abilities).
func setup(layout: ActionBarLayout, abilities: PlayerAbilities) -> void:
	if _layout != null:
		_layout.slot_changed.disconnect(_on_layout_slot_changed)
	if _abilities != null:
		_abilities.learned_changed.disconnect(refresh)
	_layout = layout
	_abilities = abilities
	if _layout != null:
		_layout.slot_changed.connect(_on_layout_slot_changed)
	if _abilities != null:
		_abilities.learned_changed.connect(refresh)
	refresh()


## Alle Slots neu anzeigen (Inhalt, ausgegraut ja/nein).
func refresh() -> void:
	for i in _slots.size():
		_refresh_slot(i)


## Löst einen Slot aus, wenn das Ereignis eine seiner Tasten ist. Gibt true
## zurück, wenn das Ereignis verbraucht wurde.
func handle_key_event(event: InputEvent) -> bool:
	if action_prefix == "":
		return false
	for slot in _slots:
		if event.is_action_pressed(slot.input_action):
			slot.activate()
			return true
	return false


func get_slot(index: int) -> ActionSlot:
	return _slots[index]


## Ob data auf einem Slot dieser Leiste abgelegt werden darf.
func can_drop(data: Variant) -> bool:
	return _layout != null and data is ActionDragData and (data as ActionDragData).content != null


## Ablegen auf Slot index (siehe Klassenbeschreibung).
func drop_on_slot(index: int, data: ActionDragData) -> void:
	if not can_drop(data):
		return
	if data.has_source():
		_layout.swap(data.source_bar.bar_index, data.source_index, bar_index, index)
		return
	var old := _layout.get_content(bar_index, index)
	_layout.set_content(bar_index, index, data.content)
	if old != null and not old.equals(data.content):
		# Erst nach dem laufenden Ablegen neu ziehen lassen.
		_hang_on_cursor.call_deferred(old)


## Leert Slot index (ins Leere gezogen).
func clear_slot(index: int) -> void:
	if _layout != null:
		_layout.clear(bar_index, index)


## Inhalt hängt am Mauszeiger, ohne Ursprungsslot: Ablegen auf einem Slot
## legt ihn dort ab, ins Leere oder Abbruch verwirft ihn.
func _hang_on_cursor(content: ActionSlotContent) -> void:
	var data := ActionDragData.create(content)
	force_drag(data, data.make_preview())


func _refresh_slot(index: int) -> void:
	var content := _layout.get_content(bar_index, index) if _layout != null else null
	var learned := true
	var shown: AbilityData = null
	var caster: Unit = null
	if content != null and content.is_ability() and _abilities != null:
		learned = _abilities.is_learned(content.get_ability())
		# #20: gespeichert ist die Grundfähigkeit, gezeigt die Variante.
		shown = _abilities.resolve(content.get_ability())
		caster = _abilities.get_parent() as Unit
	_slots[index].show_content(content, learned, shown, caster)


func _on_layout_slot_changed(bar: int, index: int) -> void:
	if bar == bar_index and index < _slots.size():
		_refresh_slot(index)


func _on_slot_activated(index: int) -> void:
	var content := _layout.get_content(bar_index, index) if _layout != null else null
	if content != null and content.is_ability() and _abilities != null:
		_abilities.use_ability(content.get_ability())
	slot_activated.emit(index)
