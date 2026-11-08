class_name ZoneBanner
extends VBoxContainer
## Gebietsnamen-Einblendung (Ticket #15): Betritt die eigene Figur ein neues
## Gebiet, erscheint der Name groß oben in der Bildschirmmitte, darunter klein
## der Stufenbereich (z. B. „Stufe 4–6“), und blendet wieder aus.
## Rein lokal; ausgelöst von GameWorld über Hud.show_zone_banner().

## Dauer des Einblendens in Sekunden.
@export var fade_in_time: float = 0.5
## Wie lange der Name voll sichtbar bleibt, in Sekunden.
@export var hold_time: float = 2.5
## Dauer des Ausblendens in Sekunden.
@export var fade_out_time: float = 1.5

var _tween: Tween = null


func _ready() -> void:
	visible = false
	modulate.a = 0.0


## Zeigt title groß und subtitle klein darunter (subtitle leer = keine Zeile).
func show_zone(title: String, subtitle: String) -> void:
	%TitleLabel.text = title
	%SubtitleLabel.text = subtitle
	%SubtitleLabel.visible = subtitle != ""
	if _tween != null:
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, ^"modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(hide)
