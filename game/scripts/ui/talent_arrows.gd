class_name TalentArrows
extends Control
## Pfeile für Voraussetzungen zwischen Talenten (Ticket #20). Liegt über dem
## Baum im Talentfenster und zeichnet von jedem vorausgesetzten Talent einen
## Pfeil zum abhängigen. Farben aus dem Theme (Theme-Typ „TalentArrows“:
## „active“ = Voraussetzung erfüllt, „inactive“ = nicht erfüllt; Platzhalter,
## OFFEN). Fängt keine Klicks ab. Rein lokal.

## Einträge [von: Control, nach: Control, erfüllt: bool].
var links: Array = []:
	set(value):
		links = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var width := float(get_theme_constant(&"width", &"TalentArrows"))
	for link: Array in links:
		var from := link[0] as Control
		var to := link[1] as Control
		if from == null or to == null or not is_instance_valid(from) or not is_instance_valid(to):
			continue
		var color := get_theme_color(&"active" if bool(link[2]) else &"inactive", &"TalentArrows")
		var a := _local_rect(from)
		var b := _local_rect(to)
		# Tiefere Reihe: von unten nach oben; gleiche Reihe: von der Seite.
		var start := Vector2(a.get_center().x, a.end.y)
		var end := Vector2(b.get_center().x, b.position.y)
		if b.position.y < a.end.y:
			var left_to_right := b.position.x >= a.end.x
			start = Vector2(a.end.x if left_to_right else a.position.x, a.get_center().y)
			end = Vector2(b.position.x if left_to_right else b.end.x, b.get_center().y)
		draw_line(start, end, color, width)
		var direction := (end - start).normalized()
		if direction == Vector2.ZERO:
			continue
		var side := Vector2(-direction.y, direction.x)
		var head := 8.0
		draw_colored_polygon(PackedVector2Array([end, end - direction * head + side * head * 0.5,
				end - direction * head - side * head * 0.5]), color)


func _local_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	rect.position -= get_global_position()
	return rect
