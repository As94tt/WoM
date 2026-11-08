class_name EffectContext
extends RefCounted
## Umgebung, in der Effekte ausgeführt werden (Ticket #32): wer wirkt, auf
## wen, woher (Fähigkeit, Aura, Entwickler-Panel) und was bisher verbraucht
## wurde. Nur auf dem Host.

## Wirker (kann null sein, z. B. verzögerter Schaden ohne Verursacher).
var caster: Unit = null
## Hauptziel (Zielbestimmung „Ziel“, Mittelpunkt von „Umkreis um Ziel“).
var target: Unit = null
## Punkt für „Umkreis um Punkt“, Flächen usw.
var point := Vector3.ZERO
var has_point := false
## Herkunft, z. B. &"ability:feuerball", &"aura:test_dot", &"dev:aura".
var source_id: StringName = &""
## Anzeigename der Herkunft.
var source_name := ""
## Fähigkeit, deren Werte Effekte mit „Werte aus der Fähigkeit“ lesen (#33).
var ability: AbilityData = null
## Aura-Instanz, aus der die Effekte kommen (Tick, Auslöser, Anwenden).
var aura: AuraInstance = null
## Verbrauchtes, z. B. {"rage": 40, "combo_points": 5, "aura:test_stapel": 3}.
## Geteilt von allen Kopien dieses Kontexts (eine Effektliste).
var consumed: Dictionary = {}
## Faktor auf Schaden und Heilung (Kette: Abschwächung je Sprung, Stapel).
var amount_factor := 1.0
## Betrag des auslösenden Ereignisses (Auslöser).
var event_amount := 0.0
## Periodischer Effekt (Tick einer Aura oder Fläche).
var periodic := false
## Feste Beträge (beim Anwenden einer Aura berechnet): Effekt → Betrag.
var snapshot: Dictionary = {}


static func create(p_caster: Unit, p_target: Unit, p_source_id: StringName,
		p_source_name := "") -> EffectContext:
	var ctx := EffectContext.new()
	ctx.caster = p_caster
	ctx.target = p_target
	ctx.source_id = p_source_id
	ctx.source_name = p_source_name
	return ctx


## Kopie mit anderem Hauptziel; consumed bleibt geteilt.
func with_target(p_target: Unit) -> EffectContext:
	var ctx := copy()
	ctx.target = p_target
	return ctx


func copy() -> EffectContext:
	var ctx := EffectContext.new()
	ctx.caster = caster
	ctx.target = target
	ctx.point = point
	ctx.has_point = has_point
	ctx.source_id = source_id
	ctx.source_name = source_name
	ctx.ability = ability
	ctx.aura = aura
	ctx.consumed = consumed
	ctx.amount_factor = amount_factor
	ctx.event_amount = event_amount
	ctx.periodic = periodic
	ctx.snapshot = snapshot
	return ctx


## Wirker, falls er noch existiert.
func get_caster() -> Unit:
	return caster if caster != null and is_instance_valid(caster) and caster.is_inside_tree() else null


## Mittelpunkt für „Umkreis um Punkt“: der Punkt, sonst das Ziel, sonst der Wirker.
func get_point() -> Vector3:
	if has_point:
		return point
	if target != null and is_instance_valid(target):
		return target.global_position
	var c := get_caster()
	return c.global_position if c != null else Vector3.ZERO
