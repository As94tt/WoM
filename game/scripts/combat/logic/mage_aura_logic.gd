class_name MageAuraLogic
extends AuraLogic
## Aura-Logik der Magier-Mechaniken (Ticket #22, Erweiterungspunkt AuraLogic
## aus #32). Jede Gruppe ist optional; eine Aura nutzt nur, was sie braucht.
## Alle Haken laufen auf dem Host. Zahlen kommen aus faehigkeitswerte.csv:
## aus values_ability bzw. der Fähigkeit, mit der die Aura angewendet wurde,
## jeweils mit den Veränderungen des Wirkers durch Talente.
##
## - Schild aus der Tabelle (Magischer Schild und Varianten): Absorption =
##   werte.schild + werte.schild_faktor × Zaubermacht des Wirkers.
## - Schulbonus (Ladung): Schaden der Schule bonus_school gegen den Träger
##   steigt je Stapel um werte.bonus_je_stapel Prozent.
## - Volle Stapel (Überspannung, Inferno): Erreicht die Aura ihre
##   Höchstzahl an Stapeln und hat der Wirker die Aura full_required_aura_id,
##   bekommt der Wirker full_caster_aura bzw. laufen full_effects (Wirker der
##   Aura → Träger).
## - Springen (Entladung, Frostbiss): Stirbt der Träger bzw. läuft die Aura
##   aus, springt sie mit jump_chance_per_rank × Rang (Stapel der Talent-Aura
##   des Wirkers) Prozent auf die nächste feindliche Einheit im Umkreis
##   werte.<jump_radius_key> – entweder mit denselben Stapeln oder (jump_recast)
##   indem die Fähigkeit dort erneut wirkt.
## - Zerbrechen (Splitterpanzer): Wird ein Schild leer gefangen, laufen
##   on_break_effects (Wirker = Träger; Bedingungen z. B. „Wirker hat Talent“).

@export var values_ability: AbilityData

@export_group("Schild aus der Tabelle")
@export var absorb_key := ""
@export var absorb_factor_key := ""

@export_group("Schulbonus")
@export var bonus_school: StringName
@export var bonus_key := "werte.bonus_je_stapel"

@export_group("Volle Stapel")
## Nur, wenn der Wirker diese Aura hat (leer = immer).
@export var full_required_aura_id: StringName
@export var full_caster_aura: AuraData
## Dauer von full_caster_aura (Schlüssel, leer = Dauer der Aura).
@export var full_duration_key := ""
@export var full_effects: Array[EffectData] = []

@export_group("Springen")
@export var jump_on_expire := false
@export var jump_on_death := false
## Talent-Aura des Wirkers (Stapel = Rang).
@export var jump_talent_aura_id: StringName
@export var jump_chance_per_rank := 0.0
@export var jump_radius_key := "werte.sprung_radius"
## true: Die Fähigkeit, mit der die Aura angewendet wurde, wirkt am neuen Ziel
## erneut (Frostbiss); false: dieselbe Aura mit denselben Stapeln (Entladung).
@export var jump_recast := false

@export_group("Zerbrechen")
@export var on_break_effects: Array[EffectData] = []


func on_applied(instance: AuraInstance, combat: UnitCombat) -> void:
	_set_absorb(instance)
	_check_full(instance, combat)


func on_refreshed(instance: AuraInstance, combat: UnitCombat) -> void:
	_set_absorb(instance)
	_check_full(instance, combat)


func on_removed(instance: AuraInstance, combat: UnitCombat, reason: int) -> void:
	var carrier := combat.get_unit()
	if carrier == null or not carrier.is_inside_tree():
		return
	if reason == UnitCombat.RemoveReason.ABSORB_DEPLETED and not on_break_effects.is_empty():
		var ctx := _context(instance, carrier, carrier)
		if ctx != null:
			Combat.execute(on_break_effects, ctx)
	var expired := jump_on_expire and reason == UnitCombat.RemoveReason.EXPIRED
	var died := jump_on_death and carrier.is_dead()
	if expired or died:
		_jump(instance, carrier)


func modify_incoming_damage(instance: AuraInstance, combat: UnitCombat, amount: float,
		school: StringName, _attacker: Unit) -> float:
	if bonus_school == &"" or school != bonus_school:
		return amount
	var caster := instance.get_caster(combat.get_tree())
	var percent := MageValues.number_for(_values(instance), caster, bonus_key)
	return amount * (1.0 + instance.stacks * percent / 100.0)


# --- Intern ------------------------------------------------------------------

func _values(instance: AuraInstance) -> AbilityData:
	if values_ability != null:
		return values_ability
	return instance.ctx.ability if instance.ctx != null else null


## Kontext für Effekte der Logik: Wirker der Aura, Hauptziel target, Zahlen
## aus der Fähigkeit, mit der die Aura angewendet wurde.
func _context(instance: AuraInstance, caster: Unit, target: Unit) -> EffectContext:
	if caster == null or not is_instance_valid(caster):
		return null
	var ctx := EffectContext.create(caster, target, StringName("aura:%s" % instance.data.id),
			instance.data.display_name)
	ctx.ability = instance.ctx.ability if instance.ctx != null else values_ability
	return ctx


func _set_absorb(instance: AuraInstance) -> void:
	if absorb_key == "" and absorb_factor_key == "":
		return
	var ability: AbilityData = instance.ctx.ability if instance.ctx != null and instance.ctx.ability != null \
			else values_ability
	var caster := instance.caster if instance.caster != null and is_instance_valid(instance.caster) else null
	var amount := MageValues.number_for(ability, caster, absorb_key)
	var power := caster.get_stats().get_value(&"spell_power") if caster != null and caster.get_stats() != null else 0.0
	amount += MageValues.number_for(ability, caster, absorb_factor_key) * power
	if amount > 0.0:
		instance.absorb_max = amount
		instance.absorb_left = amount


func _check_full(instance: AuraInstance, combat: UnitCombat) -> void:
	if full_caster_aura == null and full_effects.is_empty():
		return
	if instance.stacks < instance.data.max_stacks:
		return
	var caster := instance.get_caster(combat.get_tree())
	if caster == null or caster.is_dead() or caster.get_combat() == null:
		return
	if full_required_aura_id != &"" and caster.get_combat().get_stacks(full_required_aura_id, caster) <= 0:
		return
	if full_caster_aura != null:
		var duration := MageValues.number_for(_values(instance), caster, full_duration_key)
		caster.get_combat().apply_aura(full_caster_aura, caster, null, 1, maxf(0.0, duration))
	if not full_effects.is_empty():
		var ctx := _context(instance, caster, combat.get_unit())
		if ctx != null:
			Combat.execute(full_effects, ctx)


func _jump(instance: AuraInstance, carrier: Unit) -> void:
	var caster := instance.get_caster(carrier.get_tree())
	if caster == null or caster.is_dead():
		return
	var chance := jump_chance_per_rank * MageValues.own_stacks(caster, jump_talent_aura_id)
	if chance <= 0.0 or randf() * 100.0 >= chance:
		return
	var radius := MageValues.number_for(_values(instance), caster, jump_radius_key)
	var best: Unit = null
	var best_distance := INF
	for unit in Unit.all_units(carrier.get_tree()):
		if unit == carrier or unit == caster or unit.is_dead() or not Combat.is_hostile(caster, unit):
			continue
		var distance := carrier.distance_to_unit(unit)
		if distance <= radius and distance < best_distance:
			best = unit
			best_distance = distance
	if best == null or best.get_combat() == null:
		return
	var ctx := _context(instance, caster, best)
	if jump_recast and ctx != null and ctx.ability != null:
		ctx.source_id = StringName("ability:%s" % ctx.ability.id)
		ctx.source_name = ctx.ability.display_name
		Combat.execute(ctx.ability.get_effects_for(caster), ctx)
	else:
		best.get_combat().apply_aura(instance.data, caster, ctx, instance.stacks, instance.duration)
