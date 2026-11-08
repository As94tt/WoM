class_name CooldownSweep
extends Control
## Uhrzeiger-Abdunklung über einem Aktionsslot (Ticket #33): Der noch
## abklingende Anteil (fraction, 1 = ganz) ist abgedunkelt, beginnend oben
## und im Uhrzeigersinn schrumpfend. Farbe aus dem Theme (Theme-Typ
## „CooldownSweep“, Farbe „sweep“, Platzhalter OFFEN). Fängt keine Klicks ab.

const SEGMENTS := 48

## Abklingender Anteil von 0 bis 1.
var fraction := 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if is_equal_approx(value, fraction):
			return
		fraction = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Der Fächer ist größer als der Slot; abgeschnitten wird am Rand.
	clip_contents = true


func _draw() -> void:
	if fraction <= 0.0:
		return
	var color := get_theme_color(&"sweep", &"CooldownSweep")
	var center := size / 2.0
	var radius := size.length()
	# Abgedunkelt bleibt der Teil vom Zeiger bis 12 Uhr im Uhrzeigersinn.
	var start := -PI / 2.0 + TAU * (1.0 - fraction)
	var end := -PI / 2.0 + TAU
	var points := PackedVector2Array([center])
	var steps := maxi(2, int(SEGMENTS * fraction) + 1)
	for i in steps + 1:
		var angle := lerpf(start, end, float(i) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)
