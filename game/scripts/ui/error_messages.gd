class_name ErrorMessages
extends VBoxContainer
## Fehlermeldungen oben in der Bildschirmmitte (Ticket #33), z. B. „Nicht
## genug Mana“, „Außer Reichweite“, „Ihr müsst Euer Ziel ansehen“. Rot
## (ErrorMessage, Platzhalterfarbe OFFEN); die Meldung ist immer ein Satz,
## nie nur eine Farbe. Dieselbe Meldung erscheint höchstens einmal je
## fehlermeldung_abstand Sekunden, jede bleibt fehlermeldung_dauer Sekunden
## und blendet dann aus. Höchstens MAX_LINES Zeilen, neueste unten.
##
## Klang: Zu jeder Meldung wird ErrorSound abgespielt. Es gibt noch keine
## Audio-Dateien; der Klang ist OFFEN (Stream leer = still). Rein lokal.

const MAX_LINES := 3
const FADE_TIME := 0.5

## Meldung → Zeitpunkt (s), zu dem sie zuletzt erschien.
var _last_shown: Dictionary = {}

@onready var _sound: AudioStreamPlayer = %ErrorSound


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Meldung zeigen (leerer Text = nichts).
func show_error(text: String) -> void:
	if text == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_shown.get(text, -INF)) < Data.konstante(&"fehlermeldung_abstand", 1.0):
		return
	_last_shown[text] = now
	var label := Label.new()
	label.theme_type_variation = &"ErrorMessage"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	add_child(label)
	while get_child_count() > MAX_LINES + 1:
		var oldest := _labels()[0]
		remove_child(oldest)
		oldest.queue_free()
	var tween := label.create_tween()
	tween.tween_interval(maxf(0.1, Data.konstante(&"fehlermeldung_dauer", 2.0)))
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(label.queue_free)
	play_error_sound()


## Stelle zum Abspielen des Fehlerklangs (Klang OFFEN, bis es Audio gibt).
func play_error_sound() -> void:
	if _sound != null and _sound.stream != null:
		_sound.play()


func _labels() -> Array[Label]:
	var result: Array[Label] = []
	for child in get_children():
		if child is Label:
			result.append(child)
	return result
