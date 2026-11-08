class_name MessageLog
extends VBoxContainer
## Log-Bereich im HUD (Ticket #30): kurze Meldungen wie „Arthas hat die Welt
## betreten“, unten links, neueste unten. Jede Zeile blendet nach einer Weile
## aus. Später schreibt hier auch der Chat bzw. Kampflog hinein.
## Rein lokal; was gemeldet wird, entscheidet der Aufrufer (GameWorld).

## Höchstens so viele Zeilen gleichzeitig; ältere fallen weg.
@export var max_lines: int = 8
## So lange bleibt eine Zeile voll sichtbar, in Sekunden.
@export var line_lifetime: float = 20.0
## Dauer des Ausblendens, in Sekunden.
@export var fade_time: float = 2.0


## Neue Zeile anhängen.
func add_message(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"LogText"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	while get_child_count() > max_lines:
		var oldest := get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var tween := label.create_tween()
	tween.tween_interval(line_lifetime)
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	tween.tween_callback(label.queue_free)
