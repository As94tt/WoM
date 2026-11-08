class_name MapMarker
extends Control
## Symbol auf der Karte (Ticket #15): eigene Position als Pfeil in
## Blickrichtung, Wiedereinstiegspunkt als Kreis mit Kreuz, Mitspieler (#30)
## als Punkt in Klassenfarbe.
## Farben und Größen kommen aus dem Theme (Typ „MapMarker“, siehe
## UI-STYLEGUIDE), nur die Klassenfarbe aus den Daten (ClassData.color); die
## Form ist zweites Erkennungsmerkmal neben der Farbe, dazu ein Tooltip.

enum Kind { PLAYER, RESPAWN, MATE }

const THEME_TYPE := &"MapMarker"

@export var kind: Kind = Kind.PLAYER
## Füllfarbe für Mitspieler (Klassenfarbe aus den Daten).
var fill_color := Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()


func _ready() -> void:
	var size_name: StringName = [&"player_size", &"respawn_size", &"mate_size"][kind]
	var marker_size := get_theme_constant(size_name, THEME_TYPE)
	custom_minimum_size = Vector2(marker_size, marker_size)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	# Nur Wiedereinstiegspunkte und Mitspieler zeigen einen Tooltip; der Pfeil
	# liegt oft darüber.
	mouse_filter = MOUSE_FILTER_IGNORE if kind == Kind.PLAYER else MOUSE_FILTER_STOP


## Setzt die Mitte des Symbols auf point (Koordinaten des Elternknotens).
func place_at(point: Vector2) -> void:
	position = point - size / 2.0


func _draw() -> void:
	var outline := get_theme_color(&"outline_color", THEME_TYPE)
	var line := float(get_theme_constant(&"outline_width", THEME_TYPE))
	var r := size.x / 2.0
	var c := size / 2.0
	match kind:
		Kind.PLAYER:
			# Pfeil nach oben; gedreht wird der ganze Knoten (rotation).
			var points := PackedVector2Array([
				c + Vector2(0.0, -r),
				c + Vector2(r * 0.75, r * 0.8),
				c + Vector2(0.0, r * 0.35),
				c + Vector2(-r * 0.75, r * 0.8),
			])
			draw_colored_polygon(points, get_theme_color(&"player_color", THEME_TYPE))
			points.append(points[0])
			draw_polyline(points, outline, line, true)
		Kind.RESPAWN:
			draw_circle(c, r - line / 2.0, get_theme_color(&"respawn_color", THEME_TYPE))
			draw_circle(c, r - line / 2.0, outline, false, line, true)
			var arm := r * 0.5
			draw_line(c + Vector2(-arm, 0.0), c + Vector2(arm, 0.0), outline, line)
			draw_line(c + Vector2(0.0, -arm), c + Vector2(0.0, arm), outline, line)
		Kind.MATE:
			draw_circle(c, r - line / 2.0, fill_color)
			draw_circle(c, r - line / 2.0, outline, false, line, true)
