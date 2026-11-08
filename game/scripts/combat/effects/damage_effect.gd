class_name DamageEffect
extends AmountEffect
## Effekt „Schaden“ (Ticket #32): Menge (siehe AmountEffect) in einer
## Schadensschule (ID aus schadensschulen.csv). Seit #34 mit Trefferwürfel,
## Krit, Rüstung bzw. Zauberschutz und Blocken (Combat.roll_damage).

## Art des Angriffs für den Trefferwürfel (#34):
## AUTO     – aus dem Zusammenhang: Tick einer Aura oder Fläche → Schaden über
##            Zeit; Fähigkeit mit „Zauber“ → Zauber; Fähigkeit, die eine
##            Fernkampfwaffe braucht → Fernkampf; sonst körperliche Schule →
##            Nahkampf, magische Schule → Zauber
## MELEE    – Nahkampf (Verfehlt, Ausgewichen, Pariert, Geblockt, Kritisch)
## RANGED   – Fernkampf (Verfehlt, Ausgewichen, Geblockt, Kritisch)
## SPELL    – Zauber (Verfehlt, Kritisch)
## PERIODIC – wie Schaden über Zeit (nur Kritisch)
enum Attack { AUTO, MELEE, RANGED, SPELL, PERIODIC }

const ATTACK_KINDS := {
	Attack.MELEE: HitFormulas.AttackKind.MELEE,
	Attack.RANGED: HitFormulas.AttackKind.RANGED,
	Attack.SPELL: HitFormulas.AttackKind.SPELL,
	Attack.PERIODIC: HitFormulas.AttackKind.PERIODIC,
}

@export var school: StringName = &"physisch"
@export var attack: Attack = Attack.AUTO


func _apply(ctx: EffectContext, target: Unit) -> void:
	if Data.schadensschule(school) == null:
		push_warning("DamageEffect: unbekannte Schadensschule „%s“ (schadensschulen.csv)." % school)
	var flags := Combat.FLAG_PERIODIC if ctx.periodic else 0
	Combat.roll_damage(ctx.get_caster(), target, amount_for(ctx, target), school,
			attack_kind_for(ctx), ctx, flags)


## Art des Angriffs für den Würfel (siehe Attack).
func attack_kind_for(ctx: EffectContext) -> HitFormulas.AttackKind:
	if attack != Attack.AUTO:
		return ATTACK_KINDS[attack]
	if ctx.periodic:
		return HitFormulas.AttackKind.PERIODIC
	if ctx.ability != null:
		if ctx.ability.is_spell:
			return HitFormulas.AttackKind.SPELL
		if ctx.ability.required_weapon == AbilityData.WeaponRequirement.RANGED:
			return HitFormulas.AttackKind.RANGED
		return HitFormulas.AttackKind.MELEE
	return HitFormulas.AttackKind.MELEE if Combat.is_physical(school) else HitFormulas.AttackKind.SPELL


func describe() -> String:
	return "Schaden %s (%s)" % [StatFormat.grouped(base_amount), Data.schulname(school)]
