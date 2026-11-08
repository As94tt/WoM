class_name ActionSlot
extends Button
## Ein Slot einer Aktionsleiste (Ticket #17). Zeigt vorerst nur einen leeren
## Rahmen und unten rechts die Taste. Klick oder Tastendruck lässt ihn kurz
## aufleuchten; was dabei ausgelöst wird, folgt mit dem Kampf-Ticket über das
## Signal activated. Rein lokal, nichts wird synchronisiert.

## Wird bei Klick oder Tastendruck ausgelöst.
signal activated

## Wie lange der Slot nach dem Auslösen aufleuchtet (Sekunden).
const FLASH_DURATION := 0.25

## Aktion der Input Map, die diesen Slot auslöst (leer = keine Taste).
var input_action: StringName = &"":
	set(value):
		input_action = value
		if is_node_ready():
			_update_hotkey()

var _flash_tween: Tween


func _ready() -> void:
	%Flash.visible = false
	pressed.connect(activate)
	_update_hotkey()


## Löst den Slot aus: kurz aufleuchten lassen und activated senden.
func activate() -> void:
	_flash()
	activated.emit()


func _update_hotkey() -> void:
	var label := InputLabels.for_action(input_action) if input_action != &"" else ""
	%Hotkey.text = label


func _flash() -> void:
	var flash: Control = %Flash
	if _flash_tween != null:
		_flash_tween.kill()
	flash.visible = true
	flash.modulate.a = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash, "modulate:a", 0.0, FLASH_DURATION)
	_flash_tween.tween_callback(flash.hide)
