class_name CombatTextLayer
extends Control
## Kampftext (Ticket #32, vollständig seit #34). Liegt im HUD über den
## Namensplaketten und unter den Fenstern. Zahlen und Wörter erscheinen über
## der Einheit (auf Augenhöhe, unter der Namensplakette), steigen auf und
## blenden aus (kampftext_dauer, kampftext_steigen in spielkonstanten.csv).
## Nur Ereignisse, die den eigenen Spieler betreffen:
## - eigener Schaden am Ziel: CombatTextDamage, eingefärbt nach Schule
##   (Theme-Typ „CombatTextSchool“, physisch ohne Färbung)
## - eigener kritischer Treffer: CombatTextCrit, mit „!“, springt kurz auf
## - eigene Heilung: über dem Geheilten, mit „+“ (CombatTextHeal, kritisch
##   CombatTextHealCrit mit „!“)
## - Schaden bzw. Heilung über Zeit: kleiner (CombatTextDamagePeriodic,
##   CombatTextHealPeriodic)
## - erlittener Schaden: an der eigenen Figur, mit „−“ (CombatTextTaken)
## - Verfehlt, Ausgewichen, Pariert, Immun als Wort; Geblockt und Absorbiert
##   als Wort mit Menge, z. B. „Geblockt (45)“ (CombatTextInfo)
## Zahlen über kampftext_abkuerzen_ab werden abgekürzt („12,3 Tsd.“).
## Farben und Größen aus dem Theme; Vorzeichen, „!“ und Wörter sind das
## zweite Signal neben der Farbe. Abschaltbar im Spielmenü (GameSettings).
##
## Netzwerk: Der Host schickt jedem Spieler nur die Ereignisse, an denen er
## beteiligt ist (Combat.report → UnitCombat.send_hit); diese Ebene empfängt
## sie über die Gruppe „combat_text“.

const GROUP := &"combat_text"
## Zufälliger seitlicher Versatz in Pixeln, damit Zahlen sich nicht decken.
const SPREAD := 40.0
## Aufspringen kritischer Treffer: Anfangsgröße und Dauer in Sekunden.
const POP_SCALE := 1.6
const POP_TIME := 0.15

## Je Eintrag: [Label, Unit, Alter in s, Versatz, springt auf].
var _entries: Array[Array] = []


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Neues Kampfereignis (gerufen von UnitCombat über die Gruppe).
func show_hit(result: HitResult) -> void:
	if result == null or not GameSettings.is_combat_text_shown():
		return
	var viewer := Unit.local_player(get_tree())
	if viewer == null:
		return
	for item in describe(result, viewer.get_path()):
		var unit := Unit.from_path(get_tree(), result.target_path)
		if item["on_self"]:
			unit = viewer
		if unit != null:
			_add(unit, item)


## Was der Spieler viewer_path zu result sieht: Liste von
## {"text", "variation", "school" (Färbung, leer = keine), "pop", "on_self"}.
## Leer, wenn ihn das Ereignis nicht betrifft. Auch für die Style-Vorschau.
static func describe(result: HitResult, viewer_path: NodePath) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var mine_in := not viewer_path.is_empty() and result.target_path == viewer_path
	var mine_out := not viewer_path.is_empty() and result.source_path == viewer_path
	if result.is_heal():
		if not mine_out:
			return items
		var variation := &"CombatTextHeal"
		if result.is_crit():
			variation = &"CombatTextHealCrit"
		elif result.is_periodic():
			variation = &"CombatTextHealPeriodic"
		items.append(_item("+" + amount_text(result.amount) + ("!" if result.is_crit() else ""),
				variation, false, &"", result.is_crit()))
		return items
	if not mine_in and not mine_out:
		return items
	var on_self := mine_in
	if result.is_avoided():
		items.append(_item(HitFormulas.OUTCOME_NAMES[result.outcome], &"CombatTextInfo", on_self))
		return items
	if result.amount > 0.0:
		var crit := result.is_crit()
		if on_self:
			items.append(_item("−" + amount_text(result.amount) + ("!" if crit else ""),
					&"CombatTextTaken", true, &"", crit))
		elif crit:
			items.append(_item(amount_text(result.amount) + "!", &"CombatTextCrit", false, &"", true))
		else:
			var variation := &"CombatTextDamagePeriodic" if result.is_periodic() else &"CombatTextDamage"
			items.append(_item(amount_text(result.amount), variation, false, result.school))
	if result.blocked > 0.0 or result.outcome == HitFormulas.Outcome.BLOCK:
		items.append(_item("Geblockt (%s)" % amount_text(result.blocked), &"CombatTextInfo", on_self))
	if result.absorbed > 0.0:
		items.append(_item("Absorbiert (%s)" % amount_text(result.absorbed), &"CombatTextInfo", on_self))
	return items


## Zahl für den Kampftext: mit Tausenderpunkten bzw. abgekürzt über
## kampftext_abkuerzen_ab (spielkonstanten.csv).
static func amount_text(amount: float) -> String:
	return StatFormat.short_amount(amount, Data.konstante(&"kampftext_abkuerzen_ab", 10000.0))


static func _item(text: String, variation: StringName, on_self: bool, school: StringName = &"",
		pop := false) -> Dictionary:
	return {"text": text, "variation": variation, "school": school, "pop": pop, "on_self": on_self}


## Label nach describe() bauen (auch für die Style-Vorschau).
static func make_label(item: Dictionary) -> Label:
	var label := Label.new()
	label.theme_type_variation = item["variation"]
	label.text = item["text"]
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Variant = CombatColors.combat_text_school_color(item["school"])
	if color is Color:
		label.add_theme_color_override(&"font_color", color)
	return label


func _add(unit: Unit, item: Dictionary) -> void:
	var label := make_label(item)
	label.visible = false
	add_child(label)
	_entries.append([label, unit, 0.0, Vector2(randf_range(-SPREAD, SPREAD), 0.0), bool(item["pop"])])


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
		label.pivot_offset = label.size / 2.0
		if entry[4]:
			label.scale = Vector2.ONE * lerpf(POP_SCALE, 1.0, clampf(float(entry[2]) / POP_TIME, 0.0, 1.0))
		var point: Vector2 = camera.unproject_position(anchor) + entry[3] + Vector2(0.0, -rise * t)
		label.position = point - label.size / 2.0
		label.modulate.a = 1.0 - t * t
