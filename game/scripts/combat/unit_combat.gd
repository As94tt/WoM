class_name UnitCombat
extends Node
## Auren, Zustände, Kampfzustand und Veränderungen von Fähigkeiten einer
## Einheit (Ticket #32). Kindknoten „Combat“ jeder Unit (Spielfiguren,
## Übungspuppen, später Gegner).
##
## Netzwerk: Effekte und Auren berechnet und verwaltet ausschließlich der
## Host. Er überträgt je Einheit:
## - aura_state: je Aura ID, Aura-ID, Wirker (Pfad), Stapel, Ablaufzeit in
##   Host-Zeit, Dauer, Restschild, verzögerter Schaden;
## - ability_mod_state: Veränderungen von Fähigkeiten (ohne Effekte).
## Beides läuft über „StatsSync“ der Einheit (Authority Host, bei Änderung).
## Clients bauen daraus die Anzeige und die Zustände (betäubt usw.) mit
## denselben Daten (AuraData). Restzeiten rechnen alle aus der Ablaufzeit
## und Network.host_time(), deshalb sehen alle dieselbe Restzeit.
## Wünsche eines Clients (Rechtsklick auf eigenen Buff) gehen per RPC an den
## Host. Kampftext schickt der Host per RPC nur an die beteiligten Spieler.
##
## Kampfzustand (Host): Schaden zufügen oder erleiden und feindliche Auren
## erhalten bringen die Einheit in den Kampf (enter_combat); sie verlässt ihn
## kampf_dauer Sekunden (spielkonstanten.csv) nach dem letzten solchen
## Ereignis. Gespeichert in CharacterStats (stat_state „combat“), dort lesen
## Regeneration und Wut-Verfall ihn; Ausrüstung (#29) und Spezialisierung
## nutzen später CharacterStats.is_in_combat().

## Auren haben sich geändert (neu, entfernt, Stapel, Dauer, Schild).
signal auras_changed
## Zustände (Combat.STATE_*) haben sich geändert.
signal states_changed(states: int)
## Veränderungen von Fähigkeiten haben sich geändert.
signal ability_modifiers_changed

## Warum eine Aura endet (AuraLogic.on_removed).
enum RemoveReason { EXPIRED, CANCELLED, REMOVED, ABSORB_DEPLETED, BROKEN, CLEARED }

## Quelle des Verlangsamungs-Modifikators (stärkste Verlangsamung).
const SLOW_SOURCE := &"aura:verlangsamung"

## Übertragen: Auren (AuraInstance.to_array je Aura).
var aura_state: Array = []:
	set(value):
		aura_state = value
		if not Network.is_host():
			_rebuild_from_state()
		auras_changed.emit()
## Übertragen: [Quelle, Fähigkeit, Ersatz, Wert, add, percent] je Veränderung.
var ability_mod_state: Array = []:
	set(value):
		ability_mod_state = value
		ability_modifiers_changed.emit()

var _auras: Array[AuraInstance] = []
var _states := 0
var _unit: Unit = null

# --- nur Host ---
var _next_id := 1
var _dirty := false
var _combat_until := -1.0
var _applied_slow := 0.0
## Quelle → Array[AbilityModifierData].
var _ability_mods: Dictionary = {}
## Pfad des Verursachers → Bedrohung (Platzhalter bis #35).
var _threat: Dictionary = {}


func _enter_tree() -> void:
	_unit = get_parent() as Unit


func _ready() -> void:
	_update_states()


func _process(_delta: float) -> void:
	if not Network.is_host() or _unit == null:
		return
	var now := Network.host_time()
	for inst in _auras.duplicate():
		if _auras.has(inst):
			_process_ticks(inst, now)
		if _auras.has(inst):
			_process_delayed(inst, now)
		if _auras.has(inst) and not inst.is_permanent() and now >= inst.expires_at:
			remove_instance(inst, RemoveReason.EXPIRED)
	if _combat_until >= 0.0 and now >= _combat_until:
		_combat_until = -1.0
		var stats := _unit.get_stats()
		if stats != null:
			stats.set_in_combat(false)
	if _dirty:
		_publish()


# --- Lesen (überall) ---------------------------------------------------------

func get_unit() -> Unit:
	return _unit


## Alle Auren (Kopie der Liste).
func get_auras() -> Array[AuraInstance]:
	return _auras.duplicate()


func get_aura_by_id(instance_id: int) -> AuraInstance:
	for inst in _auras:
		if inst.id == instance_id:
			return inst
	return null


## Stapel einer Aura (alle Instanzen; mit caster nur dessen).
func get_stacks(aura_id: StringName, caster: Unit = null) -> int:
	var path := caster.get_path() if caster != null and caster.is_inside_tree() else NodePath()
	var total := 0
	for inst in _auras:
		if inst.data.id == aura_id and (caster == null or inst.caster_path == path):
			total += inst.stacks
	return total


## Zustände als Bits (Combat.STATE_*), ohne die, gegen die die Einheit immun ist.
func get_states() -> int:
	return _states


func has_state(state: int) -> bool:
	return _states & state != 0


## Bewegen (laufen, springen): nicht betäubt, festgehalten oder umgeworfen.
func can_move() -> bool:
	return _states & (Combat.STATE_STUNNED | Combat.STATE_ROOTED | Combat.STATE_KNOCKED_DOWN) == 0


## Drehen: nicht betäubt oder umgeworfen.
func can_turn() -> bool:
	return _states & (Combat.STATE_STUNNED | Combat.STATE_KNOCKED_DOWN) == 0


## Aktionen (Fähigkeiten, automatischer Angriff): nicht betäubt oder umgeworfen.
func can_act() -> bool:
	return can_turn()


## Zauber: handeln können und nicht still.
func can_cast_spells() -> bool:
	return can_act() and not has_state(Combat.STATE_SILENCED)


## Stärkste Verlangsamung in Prozent (0 = keine).
func get_slow_percent() -> float:
	var slow := 0.0
	if has_state(Combat.STATE_SLOWED):
		for inst in _auras:
			if inst.data.states & Combat.STATE_SLOWED:
				slow = maxf(slow, inst.data.slow_percent)
	return slow


## Immun gegen einen Zustand oder eine Schule (ID, z. B. &"betaeubung",
## &"feuer"): aus den Daten der Einheit (Bosse) oder durch eine Aura.
func is_immune_to(id: StringName) -> bool:
	if id == &"":
		return false
	if _unit != null and _unit.get_base_immunities().has(String(id)):
		return true
	for inst in _auras:
		if inst.data.grants_immunities.has(String(id)):
			return true
	return false


## Alle Immunitäten (IDs) für Anzeigen.
func get_immunities() -> PackedStringArray:
	var result := PackedStringArray()
	if _unit != null:
		result.append_array(_unit.get_base_immunities())
	for inst in _auras:
		for id in inst.data.grants_immunities:
			if not result.has(id):
				result.append(id)
	return result


## Summe der prozentualen Modifikatoren einer Art (#34) aus allen Auren,
## z. B. get_amount_percent(AmountModifierData.Kind.DAMAGE_DONE, &"feuer").
## Überall gleich (Clients kennen Aura-Daten und Stapel).
func get_amount_percent(kind: AmountModifierData.Kind, school: StringName = &"") -> float:
	var total := 0.0
	for inst in _auras:
		for modifier in inst.data.amount_modifiers:
			if modifier != null and modifier.applies_to(kind, school):
				total += modifier.percent * (float(inst.stacks) if modifier.scales_with_stacks else 1.0)
	return total


## Summe aller Schilde.
func get_absorb_total() -> float:
	var total := 0.0
	for inst in _auras:
		total += inst.absorb_left
	return total


## Darf der lokale Spieler diese Aura per Rechtsklick beenden?
func can_cancel(inst: AuraInstance) -> bool:
	return inst != null and not inst.data.is_debuff and inst.data.cancelable and _unit != null \
			and _unit.get_controlling_peer() == multiplayer.get_unique_id() and _unit.is_player_unit()


# --- Fähigkeiten verändern ---------------------------------------------------

## Wert einer Fähigkeit mit allen Veränderungen (überall gleich, aus
## ability_mod_state): (base + Summe add) × (1 + Summe percent / 100).
func get_ability_value(ability_id: StringName, key: String, base: float) -> float:
	var add := 0.0
	var percent := 0.0
	for entry: Array in ability_mod_state:
		if StringName(str(entry[1])) == ability_id and str(entry[3]) == key:
			add += float(entry[4])
			percent += float(entry[5])
	return (base + add) * (1.0 + percent / 100.0)


## Ersatz einer Fähigkeit (leer = keiner; bei mehreren der zuletzt angelegte).
func get_ability_replacement(ability_id: StringName) -> StringName:
	var result := &""
	for entry: Array in ability_mod_state:
		if StringName(str(entry[1])) == ability_id and str(entry[2]) != "":
			result = StringName(str(entry[2]))
	return result


## Host: zusätzliche Effekte einer Fähigkeit durch Veränderungen.
func get_added_effects(ability_id: StringName) -> Array[EffectData]:
	var result: Array[EffectData] = []
	for source: StringName in _ability_mods:
		for modifier: AbilityModifierData in _ability_mods[source]:
			if modifier != null and modifier.ability_id == ability_id:
				result.append_array(modifier.added_effects)
	return result


## Host: Veränderungen mit einer Quelle setzen (ersetzt frühere derselben Quelle).
func add_ability_modifiers(source: StringName, modifiers: Array[AbilityModifierData], _source_name := "") -> void:
	if not _require_host("add_ability_modifiers"):
		return
	_ability_mods[source] = modifiers.duplicate()
	_publish_ability_mods()


## Host: alle Veränderungen einer Quelle entfernen.
func remove_ability_modifiers(source: StringName) -> void:
	if Network.is_host() and _ability_mods.erase(source):
		_publish_ability_mods()


# --- Auren ändern (nur Host) -------------------------------------------------

## Host: Aura anwenden bzw. erneuern. Gibt die Instanz zurück (null bei
## Immunität oder totem Träger).
func apply_aura(data: AuraData, caster: Unit, ctx: EffectContext = null, stacks := 1,
		duration_override := 0.0) -> AuraInstance:
	if not _require_host("apply_aura") or data == null or _unit == null or _unit.is_dead():
		return null
	caster = caster if caster != null and is_instance_valid(caster) and caster.is_inside_tree() else null
	var hostile := Combat.is_hostile(caster, _unit)
	if _blocked_by_immunity(data, hostile):
		var immune := Combat.make_result(caster, _unit, ctx, &"", HitFormulas.Outcome.IMMUNE)
		if immune.ability_name == "":
			immune.ability_name = data.display_name
		Combat.report(immune)
		return null
	var now := Network.host_time()
	var duration := duration_override if duration_override > 0.0 else data.get_duration()
	var inst := _find_existing(data, caster)
	if inst != null:
		if data.stack_mode != AuraData.StackMode.PER_CASTER:
			inst.caster = caster
			inst.caster_path = caster.get_path() if caster != null else NodePath()
		if data.stack_mode != AuraData.StackMode.REFRESH:
			inst.stacks = mini(data.max_stacks, inst.stacks + maxi(1, stacks))
		_set_duration(inst, duration, now)
		inst.ctx = _make_ctx(inst, ctx)
		_prepare(inst)
		_apply_stat_modifiers(inst)
		if data.logic != null:
			data.logic.on_refreshed(inst, self)
	else:
		inst = AuraInstance.new()
		inst.id = _next_id
		_next_id += 1
		inst.data = data
		inst.caster = caster
		inst.caster_path = caster.get_path() if caster != null else NodePath()
		inst.stacks = clampi(stacks, 1, data.max_stacks)
		_set_duration(inst, duration, now)
		inst.ctx = _make_ctx(inst, ctx)
		_prepare(inst)
		var interval := data.get_tick_interval()
		inst.next_tick = now + interval if interval > 0.0 and not data.tick_effects.is_empty() else -1.0
		_auras.append(inst)
		_apply_stat_modifiers(inst)
		var apply_ctx := inst.ctx.copy()
		apply_ctx.consumed = {}
		Combat.execute(data.apply_effects, apply_ctx)
		if data.logic != null:
			data.logic.on_applied(inst, self)
	if hostile:
		Combat.enter_combat(_unit)
		Combat.enter_combat(caster)
	_update_states()
	_dirty = true
	return inst


## Host: eine Instanz entfernen.
func remove_instance(inst: AuraInstance, reason: RemoveReason = RemoveReason.REMOVED) -> void:
	if not Network.is_host() or not _auras.has(inst):
		return
	_auras.erase(inst)
	var stats := _unit.get_stats() if _unit != null else null
	if stats != null:
		stats.remove_source(inst.source_key())
	remove_ability_modifiers(inst.source_key())
	if inst.data.logic != null:
		inst.data.logic.on_removed(inst, self, reason)
	if reason == RemoveReason.EXPIRED:
		_fire_expired(inst)
	# Kreis Instanz ↔ Kontext (ctx.aura) auflösen, sonst bleiben beide im
	# Speicher (gefunden mit den Tests aus #34).
	if inst.ctx != null:
		inst.ctx.aura = null
		inst.ctx = null
	_update_states()
	_dirty = true


## Host: Aura bzw. Stapel entfernen (stacks 0 = alle). caster = nur dessen
## Instanzen. Gibt die Zahl der entfernten Stapel zurück.
func remove_aura(aura_id: StringName, caster: Unit = null, stacks := 0) -> int:
	if not _require_host("remove_aura"):
		return 0
	var path := caster.get_path() if caster != null and caster.is_inside_tree() else NodePath()
	var removed := 0
	for inst in _auras.duplicate():
		if inst.data.id != aura_id or (caster != null and inst.caster_path != path):
			continue
		var take: int = inst.stacks if stacks <= 0 else mini(inst.stacks, stacks - removed)
		removed += _remove_stacks(inst, take)
		if stacks > 0 and removed >= stacks:
			break
	return removed


## Host: alle Auren entfernen (versteckte nur mit include_hidden).
func remove_all_auras(include_hidden := false) -> void:
	if not _require_host("remove_all_auras"):
		return
	for inst in _auras.duplicate():
		if include_hidden or not inst.data.hidden:
			remove_instance(inst, RemoveReason.CLEARED)


## Rechtsklick auf einen eigenen Buff: auf dem Host sofort, sonst als Wunsch.
func request_cancel(instance_id: int) -> void:
	if Network.is_host():
		_cancel(instance_id, multiplayer.get_unique_id())
	else:
		_rpc_cancel.rpc_id(1, instance_id)


# --- Kampf (nur Host) --------------------------------------------------------

## Host: Kampfzustand betreten bzw. verlängern.
func enter_combat() -> void:
	if not Network.is_host() or _unit == null:
		return
	_combat_until = Network.host_time() + Data.konstante(&"kampf_dauer", 5.0)
	var stats := _unit.get_stats()
	if stats != null and not stats.is_in_combat():
		stats.set_in_combat(true)


## Host: Sekunden, bis die Einheit den Kampf verlässt (0 = nicht im Kampf).
func get_combat_remaining() -> float:
	return maxf(0.0, _combat_until - Network.host_time()) if _combat_until >= 0.0 else 0.0


## Host: Schaden durch AuraLogic der eigenen Auren verändern.
func modify_incoming_damage(amount: float, school: StringName, attacker: Unit) -> float:
	for inst in _auras.duplicate():
		if inst.data.logic != null:
			amount = inst.data.logic.modify_incoming_damage(inst, self, amount, school, attacker)
	return maxf(0.0, amount)


func modify_outgoing_damage(amount: float, school: StringName, target: Unit) -> float:
	for inst in _auras.duplicate():
		if inst.data.logic != null:
			amount = inst.data.logic.modify_outgoing_damage(inst, self, amount, school, target)
	return maxf(0.0, amount)


## Host: Schadensumleitung. Gibt den Rest zurück, den der Träger selbst nimmt.
func redirect_damage(amount: float, attacker: Unit, school: StringName) -> float:
	var remaining := amount
	for inst in _auras.duplicate():
		if remaining <= 0.0:
			break
		var share := minf(remaining, amount * inst.data.redirect_percent / 100.0)
		if share <= 0.0:
			continue
		match inst.data.redirect_mode:
			AuraData.RedirectMode.DELAY:
				var delay := maxf(0.1, inst.data.redirect_delay)
				inst.delayed.append([share / delay, delay, school])
				inst.delayed_total += share
				if inst.next_delay_tick < 0.0:
					inst.next_delay_tick = Network.host_time() + Data.konstante(&"verzoegerung_tick", 0.5)
				remaining -= share
				_dirty = true
			AuraData.RedirectMode.TO_CASTER:
				var protector: Unit = inst.get_caster(get_tree())
				if protector == null or protector == _unit or protector.is_dead():
					continue
				remaining -= share
				Combat.deal_damage(attacker, protector, share, school, null, Combat.FLAG_NO_REDIRECT)
	return remaining


## Host: Schilde fangen Schaden ab (älteste zuerst). Gibt die abgefangene Menge zurück.
func absorb_damage(amount: float, school: StringName) -> float:
	var absorbed := 0.0
	for inst in _auras.duplicate():
		if amount - absorbed <= 0.0:
			break
		if inst.absorb_left <= 0.0:
			continue
		if not inst.data.absorb_schools.is_empty() and not inst.data.absorb_schools.has(String(school)):
			continue
		var take := minf(inst.absorb_left, amount - absorbed)
		inst.absorb_left -= take
		absorbed += take
		_dirty = true
		if inst.absorb_left <= 0.001:
			inst.absorb_left = 0.0
			remove_instance(inst, RemoveReason.ABSORB_DEPLETED)
	return absorbed


## Host: Auren mit „endet durch Schaden“ beenden (außer except, z. B. die
## Aura, deren Tick den Schaden verursacht hat).
func break_on_damage(except: AuraInstance = null) -> void:
	for inst in _auras.duplicate():
		if inst.data.breaks_on_damage and inst != except:
			remove_instance(inst, RemoveReason.BROKEN)


## Host: Ereignis an die Auren (Auslöser). Siehe Combat.notify_event.
func on_event(event: Combat.Event, other: Unit, amount: float, ability_id: StringName = &"") -> void:
	if not Network.is_host():
		return
	for inst in _auras.duplicate():
		if not _auras.has(inst):
			continue
		if inst.data.logic != null:
			inst.data.logic.on_event(inst, self, event, other, amount)
		for index in inst.data.procs.size():
			var proc: ProcData = inst.data.procs[index]
			if proc == null or proc.event != event or event == Combat.Event.AURA_EXPIRED:
				continue
			if event == Combat.Event.ABILITY_CAST and proc.ability_id != &"" and proc.ability_id != ability_id:
				continue
			if not _auras.has(inst):
				break
			var target := other if other != null and is_instance_valid(other) else _unit
			_trigger(inst, index, proc, _unit, target, amount)


## Host: Bedrohung mitzählen (Platzhalter bis #35).
func add_threat(source: Unit, amount: float) -> void:
	if not Network.is_host() or source == null:
		return
	var key := String(source.get_path())
	_threat[key] = float(_threat.get(key, 0.0)) + amount


## Host: Bedrohung je Verursacher (Pfad → Wert).
func get_threat() -> Dictionary:
	return _threat.duplicate()


# --- Kampftext und Kampflog --------------------------------------------------

## Gruppen, die ein Kampfereignis (HitResult) anzeigen: Kampftext
## (CombatTextLayer.show_hit) und Kampflog (MessageLog.add_hit).
const HIT_GROUPS := [&"combat_text", &"combat_log"]

## Host: Kampfereignis (#34) an einen Spieler (peer) schicken. Gerufen über
## die Einheit, die getroffen bzw. geheilt wurde.
func send_hit(peer: int, result: HitResult) -> void:
	if peer == multiplayer.get_unique_id():
		_show_hit(result)
	elif multiplayer.get_peers().has(peer) and Network.is_peer_in_world(peer):
		_rpc_hit.rpc_id(peer, result.to_array())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hit(data: Array) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var result := HitResult.from_array(data)
	if result != null:
		_show_hit(result)


func _show_hit(result: HitResult) -> void:
	if not is_inside_tree():
		return
	for group: StringName in HIT_GROUPS:
		get_tree().call_group(group, &"show_hit", result)


# --- Intern ------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_cancel(instance_id: int) -> void:
	if Network.is_host():
		_cancel(instance_id, multiplayer.get_remote_sender_id())


func _cancel(instance_id: int, peer: int) -> void:
	if _unit == null or _unit.get_controlling_peer() != peer:
		return
	var inst := get_aura_by_id(instance_id)
	if inst != null and not inst.data.is_debuff and inst.data.cancelable:
		remove_instance(inst, RemoveReason.CANCELLED)


func _blocked_by_immunity(data: AuraData, hostile: bool) -> bool:
	if hostile and has_state(Combat.STATE_INVULNERABLE):
		return true
	for state: int in Combat.STATE_IDS:
		if data.states & state and is_immune_to(Combat.state_id(state)):
			return true
	return false


func _find_existing(data: AuraData, caster: Unit) -> AuraInstance:
	var path := caster.get_path() if caster != null else NodePath()
	for inst in _auras:
		if inst.data != data:
			continue
		if data.stack_mode == AuraData.StackMode.PER_CASTER and inst.caster_path != path:
			continue
		return inst
	return null


func _set_duration(inst: AuraInstance, duration: float, now: float) -> void:
	inst.duration = maxf(0.0, duration)
	inst.expires_at = now + duration if duration > 0.0 else -1.0


func _make_ctx(inst: AuraInstance, origin: EffectContext) -> EffectContext:
	var ctx := origin.copy() if origin != null else EffectContext.new()
	ctx.caster = inst.caster
	ctx.target = _unit
	ctx.aura = inst
	ctx.source_id = StringName("aura:%s" % inst.data.id)
	ctx.source_name = inst.data.display_name
	ctx.consumed = {}
	ctx.amount_factor = 1.0
	ctx.periodic = false
	ctx.snapshot = {}
	return ctx


## Feste Beträge der Ticks und Schild berechnen (beim Anwenden und Erneuern).
func _prepare(inst: AuraInstance) -> void:
	inst.snapshot = {}
	for effect in inst.data.tick_effects:
		if effect == null:
			continue
		var value := effect.compute_snapshot(inst.ctx)
		if not is_nan(value):
			inst.snapshot[effect] = value
	inst.ctx.snapshot = inst.snapshot
	var absorb := inst.data.absorb_amount
	var caster := inst.ctx.get_caster()
	if inst.data.absorb_factor != 0.0 and caster != null and caster.get_stats() != null:
		absorb += inst.data.absorb_factor * caster.get_stats().get_value(&"spell_power")
	if absorb > 0.0:
		inst.absorb_max = absorb
		inst.absorb_left = absorb


func _apply_stat_modifiers(inst: AuraInstance) -> void:
	var stats := _unit.get_stats()
	if stats == null:
		return
	stats.remove_source(inst.source_key())
	var factor := float(inst.stacks) if inst.data.modifiers_scale_with_stacks else 1.0
	for data in inst.data.stat_modifiers:
		if data != null:
			var modifier := data.to_modifier(inst.source_key(), inst.data.display_name)
			modifier.value *= factor
			stats.add_modifier(modifier)


func _remove_stacks(inst: AuraInstance, count: int) -> int:
	if count <= 0:
		return 0
	if count >= inst.stacks:
		var all := inst.stacks
		remove_instance(inst, RemoveReason.REMOVED)
		return all
	inst.stacks -= count
	_apply_stat_modifiers(inst)
	_dirty = true
	return count


func _process_ticks(inst: AuraInstance, now: float) -> void:
	var interval := inst.data.get_tick_interval()
	if interval <= 0.0 or inst.next_tick < 0.0:
		return
	while now >= inst.next_tick and (inst.is_permanent() or inst.next_tick <= inst.expires_at + 0.001):
		var ctx := inst.ctx.copy()
		ctx.caster = inst.get_caster(get_tree())
		ctx.target = _unit
		ctx.periodic = true
		ctx.consumed = {}
		ctx.snapshot = inst.snapshot
		ctx.amount_factor = float(inst.stacks) if inst.data.ticks_scale_with_stacks else 1.0
		Combat.execute(inst.data.tick_effects, ctx)
		if not _auras.has(inst):
			return
		if inst.data.logic != null:
			inst.data.logic.on_tick(inst, self)
		inst.next_tick += interval


func _process_delayed(inst: AuraInstance, now: float) -> void:
	if inst.delayed.is_empty() or now < inst.next_delay_tick:
		return
	var step := Data.konstante(&"verzoegerung_tick", 0.5)
	inst.next_delay_tick = now + step
	var by_school := {}
	var total_left := 0.0
	var still: Array = []
	for entry: Array in inst.delayed:
		var part := minf(step, float(entry[1]))
		by_school[entry[2]] = float(by_school.get(entry[2], 0.0)) + float(entry[0]) * part
		entry[1] = float(entry[1]) - part
		if float(entry[1]) > 0.001:
			still.append(entry)
			total_left += float(entry[0]) * float(entry[1])
	inst.delayed = still
	inst.delayed_total = total_left
	if still.is_empty():
		inst.next_delay_tick = -1.0
	_dirty = true
	for school: StringName in by_school:
		var ctx := EffectContext.create(null, _unit, StringName("aura:%s" % inst.data.id), inst.data.display_name)
		ctx.aura = inst
		Combat.deal_damage(null, _unit, by_school[school], school, ctx,
				Combat.FLAG_PERIODIC | Combat.FLAG_NO_REDIRECT)


func _trigger(inst: AuraInstance, index: int, proc: ProcData, caster: Unit, target: Unit, amount: float) -> void:
	var now := Network.host_time()
	if float(inst.proc_ready_at.get(index, -INF)) > now:
		return
	if proc.chance < 100.0 and randf() * 100.0 >= proc.chance:
		return
	if proc.internal_cooldown > 0.0:
		inst.proc_ready_at[index] = now + proc.internal_cooldown
	var ctx := EffectContext.create(caster, target, StringName("aura:%s" % inst.data.id), inst.data.display_name)
	ctx.aura = inst
	ctx.event_amount = amount
	Combat.execute(proc.effects, ctx)
	if not _auras.has(inst):
		return
	if proc.remove_aura:
		remove_instance(inst, RemoveReason.REMOVED)
	elif proc.consume_stack:
		_remove_stacks(inst, 1)


## Auslöser „beim Ablauf der Aura“: Wirker der Aura auf den Träger.
func _fire_expired(inst: AuraInstance) -> void:
	for index in inst.data.procs.size():
		var proc: ProcData = inst.data.procs[index]
		if proc != null and proc.event == Combat.Event.AURA_EXPIRED:
			_trigger(inst, index, proc, inst.get_caster(get_tree()), _unit, 0.0)


## Zustände aus allen Auren (ohne Immunitäten); Host setzt dazu die stärkste
## Verlangsamung als einzigen Modifikator auf die Laufgeschwindigkeit.
func _update_states() -> void:
	var flags := 0
	for inst in _auras:
		flags |= inst.data.states
	for state: int in Combat.STATE_IDS:
		if flags & state and is_immune_to(Combat.state_id(state)):
			flags &= ~state
	var changed := flags != _states
	_states = flags
	if Network.is_host():
		_apply_slow(get_slow_percent())
	if changed:
		states_changed.emit(_states)
		if _unit != null:
			_unit.on_states_changed()


func _apply_slow(slow: float) -> void:
	if is_equal_approx(slow, _applied_slow) or _unit == null or _unit.get_stats() == null:
		return
	_applied_slow = slow
	var stats := _unit.get_stats()
	stats.remove_source(SLOW_SOURCE)
	if slow > 0.0:
		stats.add_modifier(StatModifier.create(SLOW_SOURCE, "Verlangsamung", &"movement_speed",
				-slow, StatModifier.Kind.PERCENT))


func _publish() -> void:
	_dirty = false
	var state: Array = []
	for inst in _auras:
		state.append(inst.to_array())
	aura_state = state


func _publish_ability_mods() -> void:
	var state: Array = []
	for source: StringName in _ability_mods:
		for modifier: AbilityModifierData in _ability_mods[source]:
			if modifier != null:
				state.append(modifier.to_array(source))
	ability_mod_state = state


## Client: Auren aus dem übertragenen Stand.
func _rebuild_from_state() -> void:
	_auras.clear()
	for entry: Variant in aura_state:
		if entry is Array:
			var inst := AuraInstance.from_array(entry)
			if inst != null:
				_auras.append(inst)
	_update_states()


func _require_host(what: String) -> bool:
	if Network.is_host():
		return true
	push_warning("UnitCombat.%s: nur der Host ändert Auren." % what)
	return false
