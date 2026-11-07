class_name ZoneTracker
extends Node
## Merkt sich für jede Spielfigur, in welchem Gebiet sie steht (Ticket #15).
## Grundlage sind die Gebietsgrenzen (Area3D „Bounds“ jeder WorldZone), die
## Figuren auf der Ebene „Spielfiguren“ erkennen. Steht eine Figur in mehreren
## Gebieten zugleich (Überschneidung), gilt das kleinere.
##
## Läuft auf jeder Instanz für alle Figuren, die sie kennt. Für Anzeigen
## (Gebietsname, Karte) zählt nur die eigene Figur; für Spiellogik wie
## Gebietsbeute (später) zählt das Ergebnis auf dem Host.

## Eine Figur hat das Gebiet gewechselt (zone ist null außerhalb aller Gebiete).
signal zone_changed(body: Node3D, zone: WorldZone)

## Figur → Gebiete, deren Grenze sie gerade berührt.
var _inside: Dictionary[Node3D, Array] = {}
## Figur → aktuelles Gebiet.
var _current: Dictionary[Node3D, WorldZone] = {}


## Meldet ein Gebiet an. Wird von GameWorld für alle Gebiete aufgerufen.
func register_zone(zone: WorldZone) -> void:
	var area := zone.get_bounds()
	area.body_entered.connect(_on_body_entered.bind(zone))
	area.body_exited.connect(_on_body_exited.bind(zone))


## Aktuelles Gebiet der Figur oder null.
func get_zone(body: Node3D) -> WorldZone:
	return _current.get(body)


func _on_body_entered(body: Node3D, zone: WorldZone) -> void:
	if not body is PlayerCharacter:
		return
	if not _inside.has(body):
		body.tree_exited.connect(_forget.bind(body), CONNECT_ONE_SHOT)
	var zones: Array = _inside.get_or_add(body, [])
	if not zones.has(zone):
		zones.append(zone)
	_update(body)


func _on_body_exited(body: Node3D, zone: WorldZone) -> void:
	if not _inside.has(body):
		return
	_inside[body].erase(zone)
	_update(body)


## Figur hat die Welt verlassen (z. B. Spieler getrennt).
func _forget(body: Node3D) -> void:
	_inside.erase(body)
	_current.erase(body)


func _update(body: Node3D) -> void:
	var best: WorldZone = null
	var best_area := INF
	for zone: WorldZone in _inside.get(body, []):
		var area := zone.get_rect().get_area()
		if area < best_area:
			best = zone
			best_area = area
	if _current.get(body) == best:
		return
	# Zwischen zwei angrenzenden Gebieten kann die Figur für einen Moment in
	# keinem stehen (Austritt vor Eintritt); dann bleibt das alte Gebiet.
	if best == null:
		return
	_current[body] = best
	zone_changed.emit(body, best)
