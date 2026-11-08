class_name ProjectileEffect
extends EffectData
## Effekt „Projektil“ (Ticket #32): fliegt mit speed m/s vom Wirker zu jedem
## Ziel des Effekts und führt beim Aufprall effects aus (mit dem getroffenen
## Ziel als Hauptziel; deren Zielbestimmung gilt, z. B. „Umkreis um Ziel“
## für Splitterschaden).
##
## Netzwerk: Der Host erzeugt das Projektil unter dem EffectSpawner und
## entscheidet den Aufprall; Clients bewegen die Graubox-Kugel selbst
## zum Ziel (gleiche Geschwindigkeit) und sehen sie verschwinden.

const PROJECTILE_SCENE := "res://scenes/combat/projectile.tscn"

@export var speed := 20.0
@export var effects: Array[EffectData] = []


func _apply(ctx: EffectContext, target: Unit) -> void:
	var caster := ctx.get_caster()
	var container := GroundArea.find_container(target.get_tree())
	if container == null:
		return
	var start := caster.get_eye_position() if caster != null else target.get_eye_position()
	var projectile: Projectile = (load(PROJECTILE_SCENE) as PackedScene).instantiate()
	projectile.setup(self, ctx.with_target(target), start, target)
	container.add_child(projectile, true)


func describe() -> String:
	return "Projektil %s m/s" % StatFormat.number(speed, 0)
