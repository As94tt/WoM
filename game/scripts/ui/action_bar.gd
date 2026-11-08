class_name ActionBar
extends HBoxContainer
## Eine Aktionsleiste mit Slots (Ticket #17). Die Slots entstehen beim Start
## aus action_slot.tscn. Ist action_prefix gesetzt, gehört zu Slot n die
## Aktion „<action_prefix><n>“ der Input Map (z. B. action_bar_1_slot_1);
## Leisten ohne Präfix haben keine Tasten. Rein lokal.

## Wird ausgelöst, wenn ein Slot per Klick oder Taste ausgelöst wurde
## (Index ab 0). Das Kampf-Ticket hängt hier die Fähigkeiten an.
signal slot_activated(index: int)

const SLOT_SCENE := preload("res://scenes/ui/hud/action_slot.tscn")

## Anzahl der Slots.
@export var slot_count := 12
## Präfix der Input-Map-Aktionen (leer = Leiste ohne Tasten).
@export var action_prefix := ""

var _slots: Array[ActionSlot] = []


func _ready() -> void:
	for i in slot_count:
		var slot: ActionSlot = SLOT_SCENE.instantiate()
		slot.name = "Slot%d" % (i + 1)
		if action_prefix != "":
			slot.input_action = StringName("%s%d" % [action_prefix, i + 1])
		slot.activated.connect(slot_activated.emit.bind(i))
		add_child(slot)
		_slots.append(slot)


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
