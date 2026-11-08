class_name AmountEffect
extends EffectData
## Gemeinsame Basis für Schaden und Heilung (Ticket #32): Menge = fester
## Grundwert + Faktor × Kampfkraft, Zaubermacht oder Waffenschaden des
## Wirkers. Ohne Rüstung und Würfel (kommt mit #34).
##
## values_from_ability: Grundwert, Faktor und Quelle kommen aus
## faehigkeitswerte.csv (Spalten grundwert, faktor, faktor_quelle) der
## Fähigkeit im Kontext, inklusive Veränderungen durch Talente („Fähigkeit
## verändern“). So bleiben die Zahlen von Fähigkeiten in der Tabelle (#33).

## WEAPON: Waffenschaden gibt es erst mit Ausrüstung (#29) und Treffern (#34);
## bis dahin zählt Kampfkraft.
enum PowerSource { NONE, ATTACK_POWER, SPELL_POWER, WEAPON }

const POWER_STATS := {
	PowerSource.ATTACK_POWER: &"attack_power",
	PowerSource.SPELL_POWER: &"spell_power",
	PowerSource.WEAPON: &"attack_power",
}
## faktor_quelle in faehigkeitswerte.csv → Quelle.
const TABLE_SOURCES := {
	"kampfkraft": PowerSource.ATTACK_POWER,
	"zaubermacht": PowerSource.SPELL_POWER,
	"waffe": PowerSource.WEAPON,
}

@export_group("Menge")
@export var base_amount := 0.0
@export var power_factor := 0.0
@export var power_source: PowerSource = PowerSource.NONE
## Zahlen aus faehigkeitswerte.csv statt aus den Feldern oben.
@export var values_from_ability := false
## Spalten bzw. „werte.<schlüssel>“ für Grundwert und Faktor (#33), damit eine
## Fähigkeit mehrere Beträge in der Tabelle haben kann (z. B. Treffer und
## Brand über Zeit).
@export var base_key := "grundwert"
@export var factor_key := "faktor"


## Menge ohne Skalierung, mit den Werten des Wirkers jetzt.
func compute_base(ctx: EffectContext) -> float:
	var base := base_amount
	var factor := power_factor
	var source := power_source
	var caster := ctx.get_caster()
	if values_from_ability and ctx.ability != null:
		base = ctx.ability.get_number_for(caster, base_key)
		factor = ctx.ability.get_number_for(caster, factor_key)
		source = TABLE_SOURCES.get(str(ctx.ability.get_value("faktor_quelle", "")), PowerSource.NONE)
	var power := 0.0
	if caster != null and caster.get_stats() != null and POWER_STATS.has(source):
		power = caster.get_stats().get_value(POWER_STATS[source])
	return base + factor * power


func compute_snapshot(ctx: EffectContext) -> float:
	return compute_base(ctx)


## Menge für ein Ziel: fester Betrag der Aura (falls vorhanden) bzw. jetzt
## berechnet, dann Faktoren und Skalierung.
func amount_for(ctx: EffectContext, target: Unit) -> float:
	var base: float = ctx.snapshot.get(self, NAN)
	if is_nan(base):
		base = compute_base(ctx)
	return maxf(0.0, scale_amount(base, ctx, target))
