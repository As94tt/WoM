class_name MageMechanicEffect
extends EffectData
## Mechanik mit eigener Zeile in faehigkeitswerte.csv (Ticket #22, Klassen-
## Erweiterung nach #32), z. B. die Brand-Explosion: Am Ziel werden die
## eigenen Stapel einer Aura verbraucht, dann laufen effects mit dem Ziel
## als Hauptziel und den Zahlen aus values_ability (ctx.ability). Schaden
## und Heilung der inneren Effekte werden mit der Zahl der verbrauchten
## Stapel multipliziert (scale_with_consumed), die Zahl steht außerdem in
## ctx.consumed["aura:<id>"].
##
## Ohne consume_aura_id laufen die Effekte immer (z. B. „Zahlen aus einer
## anderen Zeile“). Mit consume_aura_id und ohne Stapel passiert nichts.

## ctx.ability für die inneren Effekte (Zahlen der Mechanik).
@export var values_ability: AbilityData
## Name im Kampflog und Kampftext (leer = Herkunft des Kontexts).
@export var source_name := ""
## Aura, deren eigene Stapel am Ziel verbraucht werden (leer = keine).
@export var consume_aura_id: StringName
## Schaden und Heilung × verbrauchte Stapel.
@export var scale_with_consumed := true
@export var effects: Array[EffectData] = []


func _apply(ctx: EffectContext, target: Unit) -> void:
	var inner := ctx.with_target(target)
	inner.consumed = {}
	inner.snapshot = {}
	inner.aura = null
	inner.periodic = false
	if values_ability != null:
		inner.ability = values_ability
	if source_name != "":
		inner.source_name = source_name
		inner.source_id = StringName("mechanic:%s" % (values_ability.id if values_ability != null else &""))
	if consume_aura_id != &"":
		if target.get_combat() == null:
			return
		var count := target.get_combat().remove_aura(consume_aura_id, ctx.get_caster())
		if count <= 0:
			return
		inner.consumed["aura:%s" % consume_aura_id] = float(count)
		if scale_with_consumed:
			inner.amount_factor *= float(count)
	Combat.execute(effects, inner)


func describe() -> String:
	return source_name if source_name != "" else "Mechanik"
