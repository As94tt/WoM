class_name ResurrectEffect
extends EffectData
## Effekt „Wiederbeleben“ (Ticket #35): wirkt nur auf tote Mitspieler. Er
## belebt nicht sofort, sondern schickt dem Gefallenen die Anfrage „X möchte
## Euch aufhelfen – Annehmen / Ablehnen“ (RevivalService.host_offer). Nimmt
## er an, steht er an Ort und Stelle mit health_percent Prozent Leben auf
## (Mana und Energie ebenso), ohne „Geschwächt“.
## Genutzt von „Aufhelfen“ (Taste F) und Wiederbelebungsfähigkeiten (z. B.
## später Wiedergeburt des Druiden; zum Testen test_wiederbelebung).

## Leben in Prozent. 0 = Wert „werte.leben“ der Fähigkeit aus
## faehigkeitswerte.csv (Aufhelfen: 30).
@export var health_percent := 0.0


## Anders als andere Effekte nur auf tote Spielfiguren.
func apply_checked(ctx: EffectContext, target: Unit) -> void:
	if target == null or not is_instance_valid(target) or not target.is_dead() or not target.is_player_unit():
		return
	if conditions_met(ctx, target):
		_apply(ctx, target)


func _apply(ctx: EffectContext, target: Unit) -> void:
	var service := RevivalService.get_instance(target.get_tree())
	if service != null:
		service.host_offer(target, ctx.get_caster(), get_percent(ctx))


func get_percent(ctx: EffectContext) -> float:
	if health_percent > 0.0:
		return health_percent
	if ctx != null and ctx.ability != null:
		var value := ctx.ability.get_number_for(ctx.get_caster(), "werte.leben")
		if value > 0.0:
			return value
	# Ohne Fähigkeit (Entwickler-Panel): wie Aufhelfen.
	return float(Data.faehigkeitswert(&"aufhelfen", "werte.leben", 30.0))


func describe() -> String:
	return "Wiederbeleben (Anfrage)"
