class_name MovementEffect
extends EffectData
## Effekt „Bewegung“ (Ticket #32). Entscheidet der Host; Spielfiguren setzt er
## über PlayerCharacter.server_teleport (ihr Besitzer bewegt sie, die
## Bewegungsprüfung erwartet die neue Position). Graubox: Die Figur springt
## an das Ziel, es gibt noch keine Flugbahn.
##
## Wer sich bewegt:
## JUMP_TO_TARGET – der Wirker, bis vor das Ziel des Effekts
## TELEPORT       – das Ziel des Effekts, distance Meter nach vorn (Zielbestimmung
##                  „Wirker selbst“ = Blinzeln)
## KNOCKBACK      – das Ziel, distance Meter vom Wirker weg
## PULL           – das Ziel, bis vor den Wirker
## Wände (Ebene „Welt“) halten die Bewegung auf. Einheiten, die sich nicht
## bewegen lassen (Unit.can_be_moved, z. B. Übungspuppen), bleiben stehen.

enum Kind { JUMP_TO_TARGET, TELEPORT, KNOCKBACK, PULL }

## Abstand zur Wand bzw. zur anderen Einheit in Metern.
const MARGIN := 0.5

@export var kind: Kind = Kind.TELEPORT
@export var distance := 10.0


func _apply(ctx: EffectContext, target: Unit) -> void:
	var caster := ctx.get_caster()
	var mover := caster if kind == Kind.JUMP_TO_TARGET else target
	if mover == null or not mover.can_be_moved():
		return
	var from := mover.global_position
	var destination := from
	var facing := mover.get_facing()
	match kind:
		Kind.JUMP_TO_TARGET:
			if target == mover:
				return
			var away := _flat(from - target.global_position, facing)
			destination = target.global_position + away * (target.get_body_radius() + mover.get_body_radius() + MARGIN)
			facing = -away
		Kind.TELEPORT:
			destination = from + facing * distance
		Kind.KNOCKBACK:
			if caster == null or caster == mover:
				return
			destination = from + _flat(from - caster.global_position, -mover.get_facing()) * distance
		Kind.PULL:
			if caster == null or caster == mover:
				return
			var toward := _flat(caster.global_position - from, mover.get_facing())
			destination = caster.global_position - toward * (caster.get_body_radius() + mover.get_body_radius() + MARGIN)
			facing = toward
	destination = _stop_at_walls(mover, from, destination)
	var terrain := WorldTerrain.find_in(mover.get_tree())
	if terrain != null:
		destination.y = maxf(destination.y, terrain.get_surface_height(destination.x, destination.z))
	mover.host_move_to(Transform3D(Basis.looking_at(facing, Vector3.UP), destination))


func describe() -> String:
	return ["Sprung zum Ziel", "Teleport", "Rückstoß", "Heranziehen"][kind]


## Waagerechte Richtung (Länge 1); fallback, wenn beide übereinander stehen.
static func _flat(v: Vector3, fallback: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length_squared() > 0.0001 else fallback


## Strahl auf Augenhöhe; trifft er eine Wand, endet die Bewegung davor.
static func _stop_at_walls(mover: Unit, from: Vector3, to: Vector3) -> Vector3:
	var lift := Vector3.UP * mover.get_body_height() * 0.5
	var query := PhysicsRayQueryParameters3D.create(from + lift, to + lift, Unit.LINE_OF_SIGHT_MASK, [mover.get_rid()])
	var hit := mover.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var direction := (to - from)
	direction.y = 0.0
	var stop: Vector3 = hit["position"] - lift - direction.normalized() * (mover.get_body_radius() + MARGIN)
	return Vector3(stop.x, to.y, stop.z)
