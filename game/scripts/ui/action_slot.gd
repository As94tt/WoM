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
##
## Zustand (#33, update_state, jedes Bild von der Leiste): Abklingzeit bzw.
## globaler Cooldown als Uhrzeiger-Abdunklung (CooldownSweep) mit Restzeit
## (ab 2 s ganze Sekunden, darunter eine Nachkommastelle; beim globalen
## Cooldown ohne Zahl), Tönung rot außer Reichweite bzw. bläulich ohne
## genug Ressource (Farben aus dem Theme, AbilityColors), leuchtender Rand
## bei einem Proc (SlotProcGlow), heller Rahmen bei aktivem Umschalter,
## automatischem Angriff oder vorgemerktem nächsten Schlag (SlotActive),
## Zahl der Aufladungen unten links.
##
## Spezialisierung und Talente (#20): Gespeichert ist die Grundfähigkeit,
## gezeigt (Icon, Tooltip) wird die aufgelöste Variante (show_content mit
## shown), Tooltip-Zahlen mit den Veränderungen der eigenen Figur (caster).

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
## Wirker für die Zahlen im Tooltip (#20), null = Werte der Tabelle.
var _caster: Unit = null
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


## Zeigt einen Inhalt (null = leer). learned = false graut ihn aus. shown =
## angezeigte Fähigkeit statt der gespeicherten (#20: Variante), caster =
## eigene Figur für die Zahlen im Tooltip.
func show_content(content: ActionSlotContent, learned: bool, shown: AbilityData = null,
		caster: Unit = null) -> void:
	_content = content
	_ability = content.get_ability() if content != null else null
	if _ability != null and shown != null:
		_ability = shown
	_caster = caster
	_learned = learned
	AbilityIcon.apply(self, _ability)
	disabled = _ability != null and not learned
	tooltip_text = AbilityTooltip.text(_ability, learned, caster) if _ability != null else ""


## Zustand aus PlayerAbilities.get_slot_state (leer = nichts anzeigen).
func update_state(state: Dictionary) -> void:
	var cooldown: Vector2 = state.get("cooldown", Vector2.ZERO)
	var gcd: Vector2 = state.get("gcd", Vector2.ZERO)
	var shown := cooldown if cooldown.x >= gcd.x else gcd
	var sweep: CooldownSweep = %Cooldown
	sweep.fraction = shown.x / shown.y if shown.x > 0.0 and shown.y > 0.0 else 0.0
	var text: Label = %CooldownText
	text.visible = cooldown.x > 0.0 and cooldown.x >= gcd.x
	if text.visible:
		text.text = str(ceili(cooldown.x)) if cooldown.x >= 2.0 else StatFormat.number(cooldown.x, 1)
	var tint := Color.WHITE
	if bool(state.get("out_of_range", false)):
		tint = CombatColors.ability_color(&"out_of_range")
	elif bool(state.get("no_resource", false)):
		tint = CombatColors.ability_color(&"no_resource")
	if self_modulate != tint:
		self_modulate = tint
	%ProcGlow.visible = bool(state.get("highlight", false))
	%Active.visible = bool(state.get("active", false))
	var charges := int(state.get("charges", -1))
	%Charges.visible = charges >= 0
	if charges >= 0:
		%Charges.text = str(charges)


func get_content() -> ActionSlotContent:
	return _content


## Angezeigte Fähigkeit (#20: aufgelöste Variante) oder null.
func get_shown_ability() -> AbilityData:
	return _ability


func _make_custom_tooltip(_for_text: String) -> Object:
	if _ability == null:
		return null
	return AbilityTooltip.create(_ability, _learned, _caster if is_instance_valid(_caster) else null)


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
