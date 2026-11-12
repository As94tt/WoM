class_name MageTrailEffect
extends EffectData
## Spur entlang eines Sprungs (Ticket #22, Feuriger Pfad): legt vor dem
## Sprung werte.spur_anzahl Flächen gleichmäßig auf die Strecke, die der
## Wirker gleich springt (werte.distanz nach vorn, vor Wänden endend). Steht
## deshalb in der Effektliste vor dem Sprung (MageBlinkEffect).
##
## Zielbestimmung „Wirker selbst“. area ist eine Fläche mit „am Bodenpunkt“
## (at_point), meist MageAreaEffect mit eigenen Schlüsseln.

const WALL_MARGIN := 0.5

## Zeile der Zahlen (leer = Fähigkeit im Kontext).
@export var values_ability: AbilityData
@export var distance_key := "werte.distanz"
@export var count_key := "werte.spur_anzahl"
@export var area: AreaEffect


func _apply(ctx: EffectContext, target: Unit) -> void:
	if area == null:
		return
	var count := int(MageValues.number(ctx, values_ability, count_key, 1.0))
	var distance := MageValues.number(ctx, values_ability, distance_key)
	if count <= 0 or distance <= 0.0:
		return
	var from := target.global_position
	var to := _stop_at_walls(target, from, from + target.get_facing() * distance)
	for index in count:
		var point_ctx := ctx.copy()
		point_ctx.point = from.lerp(to, (index + 0.5) / count)
		point_ctx.has_point = true
		area.apply_checked(point_ctx, target)


## Strahl auf Hüfthöhe gegen die Ebene „Welt“; endet vor einer Wand.
static func _stop_at_walls(unit: Unit, from: Vector3, to: Vector3) -> Vector3:
	if not unit.is_inside_tree():
		return to
	var lift := Vector3.UP * unit.get_body_height() * 0.5
	var query := PhysicsRayQueryParameters3D.create(from + lift, to + lift, Unit.LINE_OF_SIGHT_MASK, [unit.get_rid()])
	var hit := unit.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var direction := to - from
	direction.y = 0.0
	var stop: Vector3 = hit["position"] - lift - direction.normalized() * WALL_MARGIN
	return Vector3(stop.x, to.y, stop.z)


func describe() -> String:
	return "Spur"
