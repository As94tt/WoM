class_name MageSelfEffect
extends EffectData
## Wirkung auf den Wirker, abhängig vom Ziel (Ticket #22, Klassen-
## Erweiterung nach #32). Zielbestimmung und Bedingungen dieses Effekts
## gelten für das Ziel (z. B. „Ziel ist verlangsamt“); trifft das zu, laufen
## effects mit dem Wirker als Hauptziel (Zielbestimmung „Ziel“ = Wirker).
##
## Beispiele: Eiskalte Präzision (Frostblitz auf ein verlangsamtes Ziel →
## nächster Gletschersplitter sofort), Kalter Kreislauf (Treffer gegen
## verlangsamte Ziele → Mana), Hitzewelle (kritischer Feuerball → Meteor
## sofort).

@export var effects: Array[EffectData] = []


func _apply(ctx: EffectContext, _target: Unit) -> void:
	var caster := ctx.get_caster()
	if caster == null or caster.is_dead():
		return
	Combat.execute(effects, ctx.with_target(caster))


func describe() -> String:
	return "Auf den Wirker (%d)" % effects.size()
