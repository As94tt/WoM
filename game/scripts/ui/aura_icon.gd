class_name AuraIcon
extends VBoxContainer
## Ein Aura-Symbol (Ticket #32): quadratischer Rahmen mit Icon (bis es Icons
## gibt: Kürzel aus dem Namen), Stapelzahl unten rechts, darunter die
## Restzeit. Buffs haben einen schmalen hellen Rahmen (AuraBuff), Debuffs
## einen breiteren Rahmen in der Farbe ihrer Kategorie (AuraDebuff*). Die
## Kategorie steht zusätzlich als Text im Tooltip (Farbe ist nie das einzige
## Signal).
##
## Tooltip: Name, Art („Debuff · Magie“), Beschreibung, Restzeit, Stapel,
## Schild. Rechtsklick auf einen eigenen Buff beendet ihn (wenn erlaubt).
## Rein lokal; alle Werte kommen vom Host (UnitCombat.aura_state).

## Rechtsklick auf einen eigenen, beendbaren Buff.
signal cancel_requested(instance_id: int)

const DEBUFF_VARIATIONS := {
	AuraData.Category.NONE: &"AuraDebuff",
	AuraData.Category.MAGIC: &"AuraDebuffMagic",
	AuraData.Category.POISON: &"AuraDebuffPoison",
	AuraData.Category.DISEASE: &"AuraDebuffDisease",
	AuraData.Category.CURSE: &"AuraDebuffCurse",
	AuraData.Category.PHYSICAL: &"AuraDebuffPhysical",
}

var instance: AuraInstance = null
var _combat: UnitCombat = null
var _show_time := true
var _last_text := ""


## Inhalt setzen. icon_size in Pixeln; show_time = Restzeit darunter;
## interactive = Tooltip und Rechtsklick (auf Namensplaketten aus).
func setup(inst: AuraInstance, combat: UnitCombat, icon_size: int, show_time := true,
		interactive := true) -> void:
	instance = inst
	_combat = combat
	_show_time = show_time
	var data := inst.data
	var frame: PanelContainer = %Frame
	frame.custom_minimum_size = Vector2(icon_size, icon_size)
	frame.theme_type_variation = DEBUFF_VARIATIONS.get(data.category, &"AuraDebuff") if data.is_debuff \
			else &"AuraBuff"
	%Icon.texture = data.icon
	%Icon.visible = data.icon != null
	%Short.visible = data.icon == null
	%Short.text = data.get_short_name()
	%Stacks.text = str(inst.stacks) if inst.stacks > 1 else ""
	%Time.visible = show_time and not inst.is_permanent()
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_update()


func _process(_delta: float) -> void:
	if instance != null:
		_update()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
			and _combat != null and _combat.can_cancel(instance):
		cancel_requested.emit(instance.id)
		accept_event()


## Restzeit kurz: „45 s“, „3 min“, „2 h“.
static func format_time(seconds: float) -> String:
	if seconds >= 3600.0:
		return "%d h" % ceili(seconds / 3600.0)
	if seconds >= 60.0:
		return "%d min" % ceili(seconds / 60.0)
	return "%d s" % ceili(seconds)


func _update() -> void:
	var remaining := instance.remaining()
	var time_text := "" if instance.is_permanent() else format_time(remaining)
	if _show_time and %Time.text != time_text:
		%Time.text = time_text
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	var lines: PackedStringArray = [instance.data.display_name, instance.data.get_kind_text()]
	if instance.data.description != "":
		lines.append(instance.data.description)
	lines.append("Dauerhaft" if instance.is_permanent() else "Noch %s s" % StatFormat.number(remaining, 0))
	if instance.stacks > 1:
		lines.append("Stapel: %d" % instance.stacks)
	if instance.absorb_max > 0.0:
		lines.append("Schild: %s / %s" % [StatFormat.grouped(instance.absorb_left), StatFormat.grouped(instance.absorb_max)])
	if instance.delayed_total > 0.0:
		lines.append("Verzögerter Schaden: %s" % StatFormat.grouped(instance.delayed_total))
	if _combat != null and _combat.can_cancel(instance):
		lines.append("Rechtsklick: beenden")
	var text := "\n".join(lines)
	if text != _last_text:
		_last_text = text
		tooltip_text = text
