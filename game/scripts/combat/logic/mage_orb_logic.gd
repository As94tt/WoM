class_name MageOrbLogic
extends AuraLogic
## Langsame Kugel, die geradeaus fliegt (Ticket #22, Kugelblitz). Die Aura
## liegt (versteckt) auf dem Wirker; beim Anwenden merkt sich die Logik
## Startpunkt und Richtung (Blickrichtung des Wirkers). Bei jedem Tick der
## Aura (Spalte tick) rückt die Kugel mit werte.flug m/s vor; jede feindliche
## Einheit im Umkreis werte.radius wird einmal getroffen (hit_effects mit
## ihr als Hauptziel). Zur Anzeige legt die Kugel bei jedem Tick eine kurze
## Graubox-Fläche (visual_area, ohne eigene Effekte) an ihre Position, die
## der EffectSpawner an alle überträgt.
##
## Die Aura braucht mindestens einen Tick-Effekt, damit Ticks laufen (ein
## leerer Effekt genügt). Zustand in instance.custom (nicht übertragen).

@export var speed_key := "werte.flug"
@export var radius_key := "werte.radius"
@export var hit_effects: Array[EffectData] = []
@export var visual_area: AreaEffect


func on_applied(instance: AuraInstance, combat: UnitCombat) -> void:
	var unit := combat.get_unit()
	var facing := unit.get_facing()
	instance.custom["origin"] = unit.global_position + facing * (unit.get_body_radius() + 0.5)
	instance.custom["direction"] = facing
	instance.custom["start"] = Network.host_time()
	instance.custom["hit"] = {}


func on_tick(instance: AuraInstance, combat: UnitCombat) -> void:
	var caster := instance.get_caster(combat.get_tree())
	if caster == null or not instance.custom.has("origin"):
		return
	var ability: AbilityData = instance.ctx.ability if instance.ctx != null else null
	var position := get_position(instance, caster)
	var radius := MageValues.number_for(ability, caster, radius_key, 2.0)
	var hit: Dictionary = instance.custom["hit"]
	for unit in Unit.all_units(combat.get_tree()):
		if unit.is_dead() or unit == caster or not Combat.is_hostile(caster, unit):
			continue
		var key := String(unit.get_path())
		if hit.has(key):
			continue
		var offset := unit.global_position - position
		if Vector2(offset.x, offset.z).length() - unit.get_body_radius() > radius:
			continue
		hit[key] = true
		var ctx := _context(instance, caster, unit, ability)
		Combat.execute(hit_effects, ctx)
	if visual_area != null:
		var ctx := _context(instance, caster, caster, ability)
		ctx.point = position
		ctx.has_point = true
		visual_area.apply_checked(ctx, caster)


## Position der Kugel jetzt (Host-Zeit).
func get_position(instance: AuraInstance, caster: Unit) -> Vector3:
	var ability: AbilityData = instance.ctx.ability if instance.ctx != null else null
	var speed := MageValues.number_for(ability, caster, speed_key, 5.0)
	var elapsed := Network.host_time() - float(instance.custom.get("start", Network.host_time()))
	var origin: Vector3 = instance.custom["origin"]
	var direction: Vector3 = instance.custom["direction"]
	return origin + direction * speed * elapsed


func _context(instance: AuraInstance, caster: Unit, target: Unit, ability: AbilityData) -> EffectContext:
	var ctx := EffectContext.create(caster, target,
			StringName("ability:%s" % (ability.id if ability != null else instance.data.id)),
			ability.display_name if ability != null else instance.data.display_name)
	ctx.ability = ability
	return ctx
