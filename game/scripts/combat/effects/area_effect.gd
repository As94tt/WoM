class_name AreaEffect
extends EffectData
## Effekt „Fläche erzeugen“ (Ticket #32): Bodeneffekt mit Dauer an jedem Ziel
## des Effekts (Zielbestimmung „Ziel“ = unter dem Ziel, „Wirker selbst“ =
## unter dem Wirker). Alle interval Sekunden wendet er effects auf jede
## Einheit in area_radius an, die zu area_filter passt. Die eigene
## Zielbestimmung der Effekte in der Fläche wird dabei nicht benutzt; ihre
## Bedingungen und Skalierungen schon.
##
## Netzwerk: Der Host erzeugt die Fläche (GroundArea) unter dem
## EffectSpawner der Welt; Clients sehen nur die Graubox-Scheibe.

const AREA_SCENE := "res://scenes/combat/ground_area.tscn"

@export var duration := 8.0
@export var interval := 1.0
@export var area_radius := 6.0
@export var area_filter: Filter = Filter.HOSTILE
## Ersten Tick sofort beim Erzeugen (sonst nach interval).
@export var tick_on_create := false
@export var effects: Array[EffectData] = []


func _apply(ctx: EffectContext, target: Unit) -> void:
	var container := GroundArea.find_container(target.get_tree())
	if container == null:
		push_warning("AreaEffect: kein Behälter für Flächen (Gruppe %s)." % GroundArea.CONTAINER_GROUP)
		return
	var area: GroundArea = (load(AREA_SCENE) as PackedScene).instantiate()
	area.setup(self, ctx.with_target(target), target.global_position)
	container.add_child(area, true)


func describe() -> String:
	return "Fläche %s m, %s s" % [StatFormat.number(area_radius, 0), StatFormat.number(duration, 0)]
