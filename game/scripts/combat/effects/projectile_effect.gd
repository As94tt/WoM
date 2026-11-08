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
## Fluggeschwindigkeit aus faehigkeitswerte.csv (werte.flug der Fähigkeit im
## Kontext, #33) statt speed.
@export var speed_from_ability := false
## Schule für die Farbe der Kugel (leer = Schule der Fähigkeit bzw. des
## ersten Schadenseffekts, #33).
@export var school: StringName = &""
@export var effects: Array[EffectData] = []


## Geschwindigkeit in m/s (Feld oder Tabelle).
func get_speed(ctx: EffectContext) -> float:
	if speed_from_ability and ctx != null and ctx.ability != null:
		var value := ctx.ability.get_number_for(ctx.get_caster(), "werte.flug")
		if value > 0.0:
			return value
	return speed


## Schule für die Farbe der Kugel.
func get_school(ctx: EffectContext) -> StringName:
	if school != &"":
		return school
	for effect in effects:
		if effect is DamageEffect:
			return (effect as DamageEffect).school
	if ctx != null and ctx.ability != null:
		return ctx.ability.get_school()
	return &"physisch"


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
