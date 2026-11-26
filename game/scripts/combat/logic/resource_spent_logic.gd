class_name ResourceSpentLogic
extends AuraLogic
## Ausgegebene Ressource sammeln und dafür eine Aura geben (seit #53,
## Berserker: Jede ausgegebene 30 Wut gibt 1 Raserei). Liegt auf einer
## (meist versteckten) Aura des Trägers, z. B. der passiven Aura der
## Spezialisierung. Je volle werte.<threshold_key> ausgegebene Punkte von
## resource bekommt der Träger aura mit werte.<stacks_key> Stapeln (abgerundet,
## mindestens 1) und der Dauer werte.<duration_key>; Zahlen aus
## values_ability mit den Veränderungen des Trägers (Talente wie
## Unaufhaltsam, Auren wie Avatar der Wut). Der Rest bleibt gesammelt
## (instance.custom, nicht übertragen).

@export var resource: StringName = &"rage"
## Zeile der Zahlen.
@export var values_ability: AbilityData
@export var threshold_key := "werte.wut_je_stapel"
@export var aura: AuraData
## Stapel je erreichter Schwelle (leer = 1).
@export var stacks_key := ""
## Dauer der Aura (leer = Dauer der Aura).
@export var duration_key := ""


func on_resource_spent(instance: AuraInstance, combat: UnitCombat, spent_resource: StringName,
		amount: float) -> void:
	if spent_resource != resource or aura == null:
		return
	var unit := combat.get_unit()
	if unit == null or unit.is_dead():
		return
	var threshold := EffectValues.number_for(values_ability, unit, threshold_key)
	if threshold <= 0.0:
		return
	var total := float(instance.custom.get("spent", 0.0)) + amount
	var reached := int(floor((total + 0.001) / threshold))
	instance.custom["spent"] = maxf(0.0, total - reached * threshold)
	if reached <= 0:
		return
	var per := 1
	if stacks_key != "":
		per = maxi(1, int(EffectValues.number_for(values_ability, unit, stacks_key, 1.0)))
	var duration := EffectValues.number_for(values_ability, unit, duration_key) if duration_key != "" else 0.0
	combat.apply_aura(aura, unit, null, per * reached, maxf(0.0, duration))


## Gesammelte Menge seit der letzten Schwelle (für Anzeigen und Tests).
static func get_collected(instance: AuraInstance) -> float:
	return float(instance.custom.get("spent", 0.0)) if instance != null else 0.0
