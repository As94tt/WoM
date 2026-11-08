class_name ThreatEffect
extends EffectData
## Effekt „Bedrohung ändern“ (Ticket #32, wirksam seit #35). Drei Arten:
## - ADD: Bedrohung des Wirkers beim Ziel um amount ändern (negativ senkt),
##   mit dem Bedrohungsfaktor des Wirkers (Auren) und der Skalierung des
##   Effekts. Mit amount_key kommt die Zahl aus faehigkeitswerte.csv (z. B.
##   „werte.bedrohung“ beim Schildschlag).
## - TAUNT: Spott – die Bedrohung des Wirkers wird die höchste der Liste und
##   das Ziel greift ihn duration Sekunden an (mit duration_from_ability die
##   Spalte „dauer“ der Fähigkeit). Flächenspott = derselbe Effekt mit
##   Zielbestimmung „Umkreis um den Wirker“ und Filter „feindlich“.
## - RESET: Bedrohung des Wirkers beim Ziel zurücksetzen (z. B. Totstellen):
##   Er verschwindet von der Liste, das Ziel wählt neu.
## Nur Einheiten mit Bedrohungsliste (keine Spielfiguren) reagieren.

enum Mode { ADD, TAUNT, RESET }

@export var mode: Mode = Mode.ADD
## ADD: Bedrohung in Punkten (negativ = senken).
@export var amount := 0.0
## ADD: Zahl aus faehigkeitswerte.csv statt amount (Spalte oder
## „werte.<schlüssel>“), leer = amount.
@export var amount_key := ""
## TAUNT: Dauer des Zwangs in Sekunden.
@export var duration := 0.0
## TAUNT: Dauer aus der Spalte „dauer“ der Fähigkeit statt duration.
@export var duration_from_ability := false


func _apply(ctx: EffectContext, target: Unit) -> void:
	var caster := ctx.get_caster()
	if caster == null:
		return
	match mode:
		Mode.ADD:
			Combat.add_threat(caster, target, scale_amount(get_amount(ctx), ctx, target))
		Mode.TAUNT:
			Combat.taunt(caster, target, get_duration(ctx))
		Mode.RESET:
			Combat.reset_threat(caster, target)


## Bedrohung für ADD (aus der Fähigkeit, falls amount_key gesetzt ist).
func get_amount(ctx: EffectContext) -> float:
	if amount_key != "" and ctx != null and ctx.ability != null:
		return ctx.ability.get_number_for(ctx.get_caster(), amount_key)
	return amount


## Dauer des Spotts.
func get_duration(ctx: EffectContext) -> float:
	if duration_from_ability and ctx != null and ctx.ability != null:
		var value := ctx.ability.get_number_for(ctx.get_caster(), "dauer")
		if value > 0.0:
			return value
	return duration


func describe() -> String:
	match mode:
		Mode.TAUNT:
			return "Spott"
		Mode.RESET:
			return "Bedrohung zurücksetzen"
	if amount_key != "":
		return "Bedrohung (%s)" % amount_key
	return "Bedrohung %+d" % int(amount)
