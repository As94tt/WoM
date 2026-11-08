class_name ActionSlot
extends Button
## Ein Slot einer Aktionsleiste (Ticket #17, Inhalt seit #21). Zeigt das Icon
## (bzw. Kürzel) der Fähigkeit und unten rechts die Taste. Klick oder
## Tastendruck lässt ihn kurz aufleuchten und sendet activated; was dann
## passiert, entscheidet die Leiste (ActionBar → PlayerAbilities.use_ability).
## Nicht erlernte Fähigkeiten (Stufe zu niedrig) sind ausgegraut (disabled)
## und lösen nichts aus.
##
## Ziehen (#21, Godot-Drag-and-Drop): Ein belegter Slot lässt sich ziehen –
## sind die Leisten gesperrt (GameSettings), nur mit gedrückter Umschalttaste.
## Abgelegt wird über die Leiste (ActionBar.drop_on_slot). Wird ins Leere
## losgelassen, leert sich der Slot; bei Abbruch (Rechtsklick/Esc) bleibt er.
## Rein lokal, nichts wird synchronisiert.

## Wird bei Klick oder Tastendruck ausgelöst (nicht bei ausgegrautem Slot).
signal activated

## Wie lange der Slot nach dem Auslösen aufleuchtet (Sekunden).
const FLASH_DURATION := 0.25

## Aktion der Input Map, die diesen Slot auslöst (leer = keine Taste).
var input_action: StringName = &"":
	set(value):
		input_action = value
		if is_node_ready():
			_update_hotkey()

## Leiste und Nummer des Slots (ab 0), gesetzt von ActionBar.
var bar: ActionBar = null
var index := -1

var _flash_tween: Tween
var _content: ActionSlotContent = null
var _ability: AbilityData = null
var _learned := true
## Ziehen, das von diesem Slot ausging (für „ins Leere losgelassen“).
var _outgoing: ActionDragData = null


func _ready() -> void:
	%Flash.visible = false
	pressed.connect(activate)
	_update_hotkey()


## Löst den Slot aus: kurz aufleuchten lassen und activated senden.
## Ausgegraute Slots lösen nichts aus.
func activate() -> void:
	if disabled:
		return
	_flash()
	activated.emit()


## Zeigt einen Inhalt (null = leer). learned = false graut ihn aus.
func show_content(content: ActionSlotContent, learned: bool) -> void:
	_content = content
	_ability = content.get_ability() if content != null else null
	_learned = learned
	AbilityIcon.apply(self, _ability)
	disabled = _ability != null and not learned
	tooltip_text = AbilityTooltip.text(_ability, learned) if _ability != null else ""


func get_content() -> ActionSlotContent:
	return _content


func _make_custom_tooltip(_for_text: String) -> Object:
	if _ability == null:
		return null
	return AbilityTooltip.create(_ability, _learned)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _content == null or bar == null:
		return null
	if GameSettings.is_action_bars_locked() and not Input.is_key_pressed(KEY_SHIFT):
		return null
	var data := ActionDragData.create(_content, bar, index)
	set_drag_preview(data.make_preview())
	_outgoing = data
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return bar != null and bar.can_drop(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	bar.drop_on_slot(index, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _outgoing != null:
		var data := _outgoing
		_outgoing = null
		# Ins Leere losgelassen (auch auf ein Fenster, das nichts annimmt):
		# Slot leeren. Bei Abbruch (Rechtsklick/Esc) bleibt alles.
		if not get_viewport().gui_is_drag_successful() and not data.cancelled and bar != null:
			bar.clear_slot(index)


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
