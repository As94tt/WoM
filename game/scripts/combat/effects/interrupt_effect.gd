class_name InterruptEffect
extends EffectData
## Effekt „Unterbrechen“ (Ticket #33): stoppt einen laufenden, unterbrechbaren
## Zauber des Ziels (Zauberzeit oder Kanalisieren) und sperrt dessen
## Schadensschule lock_duration Sekunden (UnitCaster.interrupt). Zauber, die
## als „nicht unterbrechbar“ markiert sind, laufen weiter.
##
## values_from_ability: Sperrdauer aus faehigkeitswerte.csv der Fähigkeit im
## Kontext (werte.sperre, sonst Spalte dauer).

@export var lock_duration := 4.0
@export var values_from_ability := false


func _apply(ctx: EffectContext, target: Unit) -> void:
	var caster_node := target.get_caster_node()
	if caster_node == null:
		return
	caster_node.interrupt(get_lock_duration(ctx))


func get_lock_duration(ctx: EffectContext) -> float:
	if values_from_ability and ctx != null and ctx.ability != null:
		var lock := ctx.ability.get_number_for(ctx.get_caster(), "werte.sperre")
		if lock <= 0.0:
			lock = ctx.ability.get_number_for(ctx.get_caster(), "dauer")
		if lock > 0.0:
			return lock
	return lock_duration


func describe() -> String:
	return "Unterbrechen (Sperre %s s)" % StatFormat.number(lock_duration, 0)
