class_name CastBar
extends HBoxContainer
## Zauberleiste einer Einheit (Ticket #33). Verwendet für die eigene Leiste
## (unten mittig über den Aktionsleisten), die Leiste des Ziels (im
## Zielrahmen) und an Namensplaketten.
##
## - Zauberzeit: Leiste füllt sich (CastBar), Kanalisieren: Leiste leert sich
##   (CastBarChannel). Text: Name und Restzeit („Testblitz  1,2 s“).
## - Nicht unterbrechbar: Kennzeichen „Schild“ links (UnitBadge) und der
##   Tooltip „Nicht unterbrechbar“ – Text statt Symbol, solange es keine
##   Icons gibt.
## - Ende: kurz voll in CastBarDone („fertig“) bzw. CastBarFailed mit
##   „Unterbrochen“, „Abgebrochen“ oder „Fehlgeschlagen“, dann ausblenden.
## Daten kommen aus UnitCaster (Vorhersage beim Besitzer, sonst vom Host).

const END_SHOW_TIME := 0.6
const RESULT_TEXTS := {
	UnitCaster.Result.INTERRUPTED: "Unterbrochen",
	UnitCaster.Result.CANCELLED: "Abgebrochen",
	UnitCaster.Result.FAILED: "Fehlgeschlagen",
}

## Höhe der Leiste in Pixeln.
@export var bar_height := 22.0
## Restzeit im Text zeigen (an Namensplaketten aus).
@export var show_time := true

var _caster: UnitCaster = null
var _end_left := 0.0

@onready var _bar: ProgressBar = %Bar
@onready var _text: Label = %Text
@onready var _shield: Control = %Shield


func _ready() -> void:
	_bar.custom_minimum_size.y = bar_height
	visible = false


## Einheit, deren Zauber gezeigt werden (null = keine).
func set_unit(unit: Unit) -> void:
	var caster := unit.get_caster_node() if unit != null and is_instance_valid(unit) else null
	if caster == _caster:
		return
	if _caster != null and is_instance_valid(_caster) and _caster.cast_ended.is_connected(_on_cast_ended):
		_caster.cast_ended.disconnect(_on_cast_ended)
	_caster = caster
	_end_left = 0.0
	if _caster != null:
		_caster.cast_ended.connect(_on_cast_ended)
	_update()


func _process(delta: float) -> void:
	if _end_left > 0.0:
		_end_left -= delta
		modulate.a = clampf(_end_left / END_SHOW_TIME, 0.0, 1.0)
	_update()


func _update() -> void:
	if _caster == null or not is_instance_valid(_caster):
		visible = false
		return
	var info := _caster.get_cast_info()
	if info.is_empty():
		visible = _end_left > 0.0
		return
	_end_left = 0.0
	modulate.a = 1.0
	visible = true
	var ability: AbilityData = info["ability"]
	var now := Network.host_time()
	var start := float(info["start"])
	var end := float(info["end"])
	var duration := maxf(0.01, end - start)
	var remaining := clampf(end - now, 0.0, duration)
	var channel := bool(info["channel"])
	_set_variation(&"CastBarChannel" if channel else &"CastBar")
	_bar.max_value = duration
	_bar.value = remaining if channel else duration - remaining
	_text.text = "%s  %s s" % [ability.display_name, StatFormat.number(remaining, 1)] if show_time \
			else ability.display_name
	_shield.visible = not bool(info["interruptible"])
	tooltip_text = "Nicht unterbrechbar" if _shield.visible else ""


func _on_cast_ended(result: int, ability_id: StringName) -> void:
	if not _caster.get_cast_info().is_empty():
		return
	var ability := GameData.get_ability(ability_id)
	var ability_name := ability.display_name if ability != null else String(ability_id)
	_set_variation(&"CastBarDone" if result == UnitCaster.Result.DONE else &"CastBarFailed")
	_bar.max_value = 1.0
	_bar.value = 1.0
	_text.text = ability_name if result == UnitCaster.Result.DONE else "%s – %s" % [ability_name, RESULT_TEXTS.get(result, "")]
	_end_left = END_SHOW_TIME
	modulate.a = 1.0
	visible = true


func _set_variation(variation: StringName) -> void:
	if _bar.theme_type_variation != variation:
		_bar.theme_type_variation = variation
