class_name MessageLog
extends VBoxContainer
## Log-Bereich im HUD (Ticket #30): kurze Meldungen wie „Arthas hat die Welt
## betreten“, unten links, neueste unten. Jede Zeile blendet nach einer Weile
## aus. Später schreibt hier auch der Chat hinein.
##
## Reiter (#34): „Allgemein“ (Meldungen) und „Kampf“ (Kampflog). Der Kampflog
## listet alle Kampfereignisse, an denen der eigene Spieler beteiligt ist,
## mit Uhrzeit, Quelle, Fähigkeit, Ziel, Ergebnis und Menge, z. B.
## „14:03:12 Arthas: Feuerball trifft Schadenspuppe kritisch: 1.240 Schaden
## (Feuer)“. Er empfängt sie über die Gruppe „combat_log“ (UnitCombat).
## Rein lokal; was gemeldet wird, entscheidet der Aufrufer bzw. der Host.

const GROUP := &"combat_log"

## Höchstens so viele Zeilen gleichzeitig je Reiter; ältere fallen weg.
@export var max_lines: int = 8
## So lange bleibt eine Zeile voll sichtbar, in Sekunden.
@export var line_lifetime: float = 20.0
## Dauer des Ausblendens, in Sekunden.
@export var fade_time: float = 2.0

@onready var _general: VBoxContainer = %GeneralLines
@onready var _combat: VBoxContainer = %CombatLines


func _ready() -> void:
	add_to_group(GROUP)
	var group := ButtonGroup.new()
	for tab: Button in [%GeneralTab, %CombatTab]:
		tab.button_group = group
	%GeneralTab.button_pressed = true
	%GeneralTab.toggled.connect(func(on: bool) -> void: _select(_general if on else _combat))


## Neue Zeile im Reiter „Allgemein“.
func add_message(text: String) -> void:
	_add_line(_general, text)


## Neue Zeile im Reiter „Kampf“ (mit Uhrzeit davor).
func add_combat_message(text: String) -> void:
	_add_line(_combat, "%s %s" % [Time.get_time_string_from_system(), text])


## Kampfereignis vom Host (Gruppe „combat_log“).
func show_hit(result: HitResult) -> void:
	if result != null:
		add_combat_message(result.log_text(Data.schulname(result.school)))


## true, wenn gerade der Kampflog sichtbar ist.
func is_combat_tab_shown() -> bool:
	return _combat.visible


func _select(lines: VBoxContainer) -> void:
	_general.visible = lines == _general
	_combat.visible = lines == _combat


func _add_line(lines: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"LogText"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(label)
	while lines.get_child_count() > max_lines:
		var oldest := lines.get_child(0)
		lines.remove_child(oldest)
		oldest.queue_free()
	var tween := label.create_tween()
	tween.tween_interval(line_lifetime)
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	tween.tween_callback(label.queue_free)
