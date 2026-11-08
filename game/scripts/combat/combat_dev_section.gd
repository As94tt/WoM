class_name CombatDevSection
extends Node
## Abschnitt „Auren“ im Entwickler-Panel (Ticket #32). Kindknoten
## „CombatDev“ der Welt (nur Debug-Builds). Testeffekte und Testauren aus
## res://data/combat/dev_tools.tres wirken mit der eigenen Figur als Wirker
## auf das aktuelle Ziel oder (Schalter) auf sich selbst. Dazu Ereignisse für
## Auslöser (kritischer Treffer, Ausweichen, Parieren, Blocken, Fähigkeit
## gewirkt) und „Alle Auren entfernen“.
##
## Netzwerk: Auf einem Client geht jeder Button als Wunsch an den Host
## (_rpc_use, _rpc_event, _rpc_clear), der wie bei echten Fähigkeiten über
## Combat entscheidet. Die Infozeilen lesen nur übertragene Daten; Restzeit
## des Kampfzustands und Bedrohung kennt nur der Host.

const TOOLS: CombatDevTools = preload("res://data/combat/dev_tools.tres")
const NAME := "CombatDev"
const EVENTS: Array[Combat.Event] = [Combat.Event.CRIT, Combat.Event.DODGE, Combat.Event.PARRY,
		Combat.Event.BLOCK, Combat.Event.ABILITY_CAST]

var _world: GameWorld = null
var _on_self := false
var _info: Label = null


func _init() -> void:
	name = NAME


## Abschnitt im Panel anlegen.
func setup(panel: DevPanel, world: GameWorld) -> void:
	_world = world
	var section := panel.add_section("Auren")
	_info = panel.add_info(section, "Kein Ziel")
	panel.add_toggle(section, "Auf mich selbst statt aufs Ziel", false, func(on: bool) -> void: _on_self = on)
	var group := ""
	for index in TOOLS.entries.size():
		var entry := TOOLS.entries[index]
		if entry == null:
			continue
		if entry.group != group:
			group = entry.group
			panel.add_info(section, "%s:" % group)
		panel.add_button(section, entry.label, _use.bind(index))
	panel.add_info(section, "Ereignisse (ich → Ziel, für Auslöser):")
	for event in EVENTS:
		var text: String = Combat.EVENT_NAMES[event]
		if event == Combat.Event.ABILITY_CAST:
			var ability := GameData.get_ability(TOOLS.event_ability_id)
			text += " (%s)" % (ability.display_name if ability != null else String(TOOLS.event_ability_id))
		panel.add_button(section, "Ereignis: %s" % text, _event.bind(event))
	panel.add_button(section, "Alle Auren entfernen (Ziel bzw. ich)", _clear)
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(_update_info)
	panel.add_child(timer)


# --- Buttons -----------------------------------------------------------------

func _use(index: int) -> void:
	var target := _chosen_target()
	if target == null:
		return
	if Network.is_host():
		_do_use(index, _world.get_local_player(), target)
	else:
		_rpc_use.rpc_id(1, index, target.get_path())


func _event(event: Combat.Event) -> void:
	var player := _world.get_local_player()
	if player == null:
		return
	var target := _local_target()
	if Network.is_host():
		_do_event(event, player, target)
	else:
		_rpc_event.rpc_id(1, event, target.get_path() if target != null else NodePath())


func _clear() -> void:
	var target := _chosen_target()
	if target == null:
		return
	if Network.is_host():
		_do_clear(target)
	else:
		_rpc_clear.rpc_id(1, target.get_path())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_use(index: int, target_path: NodePath) -> void:
	var source := _remote_source()
	var target := Unit.from_path(get_tree(), target_path)
	if source != null and target != null:
		_do_use(index, source, target)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_event(event: int, target_path: NodePath) -> void:
	var source := _remote_source()
	if source != null:
		_do_event(event, source, Unit.from_path(get_tree(), target_path))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_clear(target_path: NodePath) -> void:
	var target := Unit.from_path(get_tree(), target_path)
	if _remote_source() != null and target != null:
		_do_clear(target)


# --- Host --------------------------------------------------------------------

func _do_use(index: int, source: Unit, target: Unit) -> void:
	if index < 0 or index >= TOOLS.entries.size() or TOOLS.entries[index] == null:
		return
	var entry := TOOLS.entries[index]
	var ctx := EffectContext.create(source, target, &"dev:aura", "Entwickler-Panel")
	Combat.execute(entry.effects, ctx)


func _do_event(event: int, source: Unit, target: Unit) -> void:
	var ability_id := TOOLS.event_ability_id if event == Combat.Event.ABILITY_CAST else &""
	Combat.notify_event(source, event as Combat.Event, target, TOOLS.event_amount, ability_id)


func _do_clear(target: Unit) -> void:
	if target.get_combat() != null:
		target.get_combat().remove_all_auras()


## Host: Absender eines Wunsches (nur in Debug-Builds des Hosts).
func _remote_source() -> Unit:
	if not Network.is_host() or not OS.is_debug_build() or _world == null:
		return null
	return _world.get_player(multiplayer.get_remote_sender_id())


# --- Anzeige -----------------------------------------------------------------

func _local_target() -> Unit:
	var player := _world.get_local_player() if _world != null else null
	if player == null or player.get_targeting() == null:
		return null
	return player.get_targeting().target


func _chosen_target() -> Unit:
	return _world.get_local_player() if _on_self else _local_target()


func _update_info() -> void:
	if _info == null or not _info.is_visible_in_tree() or _world == null:
		return
	var lines: PackedStringArray = []
	var player := _world.get_local_player()
	var target := _local_target()
	if target != null and target != player:
		lines.append_array(describe_unit(target, "Ziel"))
	if player != null:
		lines.append_array(describe_unit(player, "Ich"))
	_info.text = "\n".join(lines) if not lines.is_empty() else "Kein Ziel"


## Infozeilen zu einer Einheit (auch für Tests nutzbar).
static func describe_unit(unit: Unit, title: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var combat := unit.get_combat()
	var stats := unit.get_stats()
	if combat == null:
		return lines
	var combat_text := "nein"
	if stats != null and stats.is_in_combat():
		combat_text = "ja"
		if Network.is_host():
			combat_text += " (noch %s s)" % StatFormat.number(combat.get_combat_remaining(), 1)
	lines.append("%s: %s · Kampf: %s" % [title, unit.get_unit_name(), combat_text])
	var states := combat.get_states()
	if states != 0:
		var text := Combat.state_names(states)
		if combat.get_slow_percent() > 0.0:
			text += " (−%s %% Laufgeschwindigkeit)" % StatFormat.number(combat.get_slow_percent(), 0)
		lines.append("  Zustände: %s" % text)
	var immune := combat.get_immunities()
	if not immune.is_empty():
		lines.append("  Immun: %s" % ", ".join(immune))
	for inst in combat.get_auras():
		var parts: PackedStringArray = [inst.data.display_name]
		if inst.stacks > 1:
			parts[0] += " ×%d" % inst.stacks
		parts.append("dauerhaft" if inst.is_permanent() else "%s s" % StatFormat.number(inst.remaining(), 1))
		var caster := inst.get_caster(unit.get_tree())
		if caster != null and caster != unit:
			parts.append("von %s" % caster.get_unit_name())
		if inst.absorb_max > 0.0:
			parts.append("Schild %s / %s" % [StatFormat.grouped(inst.absorb_left), StatFormat.grouped(inst.absorb_max)])
		if inst.delayed_total > 0.0:
			parts.append("verzögert %s" % StatFormat.grouped(inst.delayed_total))
		lines.append("  · " + " · ".join(parts))
	for entry: Array in combat.ability_mod_state:
		var ability := GameData.get_ability(StringName(str(entry[1])))
		if ability == null:
			continue
		if str(entry[2]) != "":
			var replacement := GameData.get_ability(StringName(str(entry[2])))
			lines.append("  Fähigkeit: %s → %s" % [ability.display_name,
					replacement.display_name if replacement != null else str(entry[2])])
		if str(entry[3]) != "":
			var key := str(entry[3])
			lines.append("  Fähigkeit: %s %s %s → %s" % [ability.display_name, key,
					StatFormat.number(float(ability.get_value(key, 0.0)), 1),
					StatFormat.number(ability.get_number_for(unit, key), 1)])
	if Network.is_host():
		var threat := combat.get_threat()
		for path: String in threat:
			var source := Unit.from_path(unit.get_tree(), NodePath(path))
			lines.append("  Bedrohung von %s: %s" % [source.get_unit_name() if source != null else path,
					StatFormat.grouped(threat[path])])
	return lines
