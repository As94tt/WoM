class_name CombatTextLayer
extends Control
## Einfacher Kampftext (Ticket #32, wird in #34 erweitert). Liegt im HUD über
## den Namensplaketten und unter den Fenstern. Zahlen erscheinen über der
## Einheit (auf Augenhöhe, unter der Namensplakette), steigen auf und blenden aus
## (kampftext_dauer, kampftext_steigen in spielkonstanten.csv):
## - Schaden, den ich verursache: über dem Ziel (CombatTextDamage, weiß)
## - eigene Heilung: über dem Geheilten, mit „+“ (CombatTextHeal, grün)
## - erlittener Schaden: an der eigenen Figur, mit „−“ (CombatTextTaken, rot)
## - „Immun“ und „Absorbiert (…)“: CombatTextInfo
## Farben und Größen aus dem Theme; Vorzeichen und Wörter sind das zweite
## Signal neben der Farbe.
##
## Netzwerk: Der Host schickt jedem Spieler nur seine eigenen Zahlen
## (UnitCombat.send_combat_text); diese Ebene empfängt sie über die Gruppe
## „combat_text“.

const GROUP := &"combat_text"
const VARIATIONS := {
	Combat.TextKind.DAMAGE: &"CombatTextDamage",
	Combat.TextKind.HEAL: &"CombatTextHeal",
	Combat.TextKind.TAKEN: &"CombatTextTaken",
	Combat.TextKind.IMMUNE: &"CombatTextInfo",
	Combat.TextKind.ABSORB: &"CombatTextInfo",
}
## Zufälliger seitlicher Versatz in Pixeln, damit Zahlen sich nicht decken.
const SPREAD := 40.0

## Je Eintrag: [Label, Unit, Alter in s, Versatz].
var _entries: Array[Array] = []


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Neue Zahl über unit (gerufen von UnitCombat._show_text).
func show_combat_text(unit: Unit, kind: int, amount: float) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var label := Label.new()
	label.theme_type_variation = VARIATIONS.get(kind, &"CombatTextInfo")
	label.text = text_for(kind, amount)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	add_child(label)
	_entries.append([label, unit, 0.0, Vector2(randf_range(-SPREAD, SPREAD), 0.0)])


static func text_for(kind: int, amount: float) -> String:
	match kind:
		Combat.TextKind.HEAL:
			return "+" + StatFormat.grouped(amount)
		Combat.TextKind.TAKEN:
			return "−" + StatFormat.grouped(amount)
		Combat.TextKind.IMMUNE:
			return "Immun"
		Combat.TextKind.ABSORB:
			return "Absorbiert (%s)" % StatFormat.grouped(amount)
	return StatFormat.grouped(amount)


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var duration := maxf(0.1, Data.konstante(&"kampftext_dauer", 1.5))
	var rise := Data.konstante(&"kampftext_steigen", 60.0)
	for entry in _entries.duplicate():
		var label: Label = entry[0]
		var unit: Unit = entry[1]
		entry[2] = float(entry[2]) + delta
		var t := float(entry[2]) / duration
		if t >= 1.0 or not is_instance_valid(unit) or not unit.is_inside_tree() or camera == null:
			_entries.erase(entry)
			label.queue_free()
			continue
		var anchor := unit.get_eye_position()
		if camera.is_position_behind(anchor):
			label.visible = false
			continue
		label.visible = true
		label.reset_size()
		var point: Vector2 = camera.unproject_position(anchor) + entry[3] + Vector2(0.0, -rise * t)
		label.position = point - label.size / 2.0
		label.modulate.a = 1.0 - t * t
