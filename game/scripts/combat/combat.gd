class_name Combat
extends RefCounted
## Kampfkern (Ticket #32): zentrale Funktionen des Effekt- und Aura-Systems.
## Alles hier läuft nur auf dem Host (Network.is_host()); Clients schicken
## Wünsche und zeigen an, was der Host überträgt.
##
## Aufbau:
## - EffectData (scripts/combat/effect_data.gd) ist ein Baustein mit Art,
##   Zielbestimmung, Bedingungen und Skalierung. Die Arten sind Unterklassen in
##   scripts/combat/effects/ (Schaden, Heilung, Aura anwenden/entfernen,
##   Ressource, Bedrohung, Bewegung, Fläche, Projektil, Fähigkeit verändern).
## - AuraData (scripts/combat/aura_data.gd) beschreibt eine Aura: Dauer,
##   Stapel, periodische Effekte, Wert-Modifikatoren, Zustände, Auslöser,
##   Absorption, Umleitung, Immunitäten. Datensätze in res://data/auras/.
## - UnitCombat (Kindknoten „Combat“ jeder Einheit) verwaltet die Auren, den
##   Kampfzustand und Veränderungen von Fähigkeiten und überträgt sie.
## - Combat (diese Datei) führt Effektlisten aus und rechnet Schaden und
##   Heilung: Immunität → Umleitung → Absorption → Leben, danach Kampfzustand,
##   Auren, die durch Schaden enden, Auslöser (Procs) und Kampftext.
##
## Einstiegspunkte für spätere Tickets:
##   Combat.execute(ability.get_effects_for(caster), ctx)   – #33 Fähigkeiten
##   Combat.deal_damage(...) / Combat.heal(...)              – #34 Treffer
##   Combat.notify_event(unit, Combat.Event.CRIT, other)     – #34 Würfel
##   Combat.notify_ability_cast(caster, ability_id, target)  – #33
##
## Erweiterung durch Klassen (ohne Änderung an diesen Dateien):
## - Neue Effektart: Skript, das EffectData erweitert und _apply() (bei Bedarf
##   resolve_targets()) überschreibt, z. B. scripts/combat/effects/class/.
## - Eigene Aura-Logik: Skript, das AuraLogic erweitert, im Feld „logic“ der
##   Aura eintragen (Haken für Anwenden, Entfernen, Tick, Ereignis, ein- und
##   ausgehenden Schaden).
## - Eigene Bedingung oder Skalierung: EffectCondition bzw. EffectScaling
##   erweitern und _evaluate() bzw. _count() überschreiben.

## Ereignisse für Auslöser (ProcData.event).
enum Event { HIT, CRIT, DAMAGE_TAKEN, DODGE, PARRY, BLOCK, ABILITY_CAST, KILL, AURA_EXPIRED }

## Arten von Kampftext (UnitCombat.send_combat_text).
enum TextKind { DAMAGE, HEAL, TAKEN, IMMUNE, ABSORB }

## Zustände als Bits (AuraData.states).
const STATE_STUNNED := 1
const STATE_ROOTED := 2
const STATE_SLOWED := 4
const STATE_SILENCED := 8
const STATE_KNOCKED_DOWN := 16
const STATE_STEALTHED := 32
const STATE_INVULNERABLE := 64

## Zustand → ID in Daten (Immunitäten, z. B. „betaeubung|feuer“).
const STATE_IDS := {
	STATE_STUNNED: &"betaeubung",
	STATE_ROOTED: &"festhalten",
	STATE_SLOWED: &"verlangsamung",
	STATE_SILENCED: &"stille",
	STATE_KNOCKED_DOWN: &"umwerfen",
	STATE_STEALTHED: &"tarnung",
	STATE_INVULNERABLE: &"unverwundbarkeit",
}
## Zustand → Anzeigename.
const STATE_NAMES := {
	STATE_STUNNED: "Betäubt",
	STATE_ROOTED: "Festgehalten",
	STATE_SLOWED: "Verlangsamt",
	STATE_SILENCED: "Still",
	STATE_KNOCKED_DOWN: "Umgeworfen",
	STATE_STEALTHED: "Getarnt",
	STATE_INVULNERABLE: "Unverwundbar",
}
const EVENT_NAMES := {
	Event.HIT: "Treffer",
	Event.CRIT: "Kritischer Treffer",
	Event.DAMAGE_TAKEN: "Schaden erlitten",
	Event.DODGE: "Ausgewichen",
	Event.PARRY: "Pariert",
	Event.BLOCK: "Geblockt",
	Event.ABILITY_CAST: "Fähigkeit gewirkt",
	Event.KILL: "Tod des Ziels",
	Event.AURA_EXPIRED: "Ablauf der Aura",
}

## Flags für deal_damage/heal.
const FLAG_PERIODIC := 1      ## Tick einer Aura oder Fläche (kein „Treffer“-Auslöser)
const FLAG_NO_REDIRECT := 2   ## Schaden wird nicht umgeleitet (verhindert Schleifen)
const FLAG_NO_PROCS := 4      ## löst keine Auslöser aus

## Größte Verschachtelung von Effekten (Auslöser, die Auslöser auslösen).
const MAX_DEPTH := 8

static var _depth := 0


# --- Effekte ausführen -------------------------------------------------------

## Host: führt eine Effektliste der Reihe nach aus. Alle Effekte teilen sich
## ctx.consumed (z. B. „Stapel verbrauchen“, danach „Schaden je verbrauchtem
## Stapel“).
static func execute(effects: Array, ctx: EffectContext) -> void:
	if not Network.is_host() or ctx == null or effects.is_empty():
		return
	if _depth >= MAX_DEPTH:
		push_warning("Combat.execute: zu tief verschachtelt (%s), abgebrochen." % ctx.source_id)
		return
	_depth += 1
	for effect: EffectData in effects:
		if effect != null:
			effect.execute(ctx)
	_depth -= 1


# --- Schaden und Heilung -----------------------------------------------------

## Host: Schaden. Reihenfolge: Immunität (Zustand „unverwundbar“ oder Schule)
## → Auren des Wirkers und des Ziels ändern den Betrag (AuraLogic) →
## Umleitung → Absorption → Leben. Danach Kampfzustand, Auren mit „endet durch
## Schaden“, Auslöser (Treffer, erlittener Schaden, Tod des Ziels) und
## Kampftext. Gibt den tatsächlich abgezogenen Betrag zurück.
static func deal_damage(caster: Unit, target: Unit, amount: float, school: StringName,
		ctx: EffectContext = null, flags := 0) -> float:
	if not Network.is_host() or not _is_alive(target):
		return 0.0
	caster = caster if caster != null and is_instance_valid(caster) else null
	var target_combat := target.get_combat()
	var caster_combat := caster.get_combat() if caster != null else null
	amount = maxf(0.0, amount)
	enter_combat(target)
	if caster != null and caster != target:
		enter_combat(caster)
	if target_combat != null and (target_combat.has_state(STATE_INVULNERABLE) or target_combat.is_immune_to(school)):
		show_text(caster, target, TextKind.IMMUNE, 0.0)
		return 0.0
	if caster_combat != null:
		amount = caster_combat.modify_outgoing_damage(amount, school, target)
	if target_combat != null:
		amount = target_combat.modify_incoming_damage(amount, school, caster)
		if flags & FLAG_NO_REDIRECT == 0:
			amount = target_combat.redirect_damage(amount, caster, school)
	var absorbed := target_combat.absorb_damage(amount, school) if target_combat != null else 0.0
	var remaining := amount - absorbed
	var stats := target.get_stats()
	var before := stats.health if stats != null else 0.0
	var dealt := target.apply_damage(remaining, caster) if remaining > 0.0 else 0.0
	var killed := stats != null and before > 0.0 and dealt > 0.0 and dealt >= before - 0.001
	if caster != null and caster.get_stats() != null and dealt > 0.0:
		caster.get_stats().register_damage_dealt(dealt)
	if dealt > 0.0 or remaining > 0.0:
		show_text(caster, target, TextKind.DAMAGE, dealt)
	if absorbed > 0.0:
		show_text(caster, target, TextKind.ABSORB, absorbed)
	if target_combat != null and dealt + absorbed > 0.0:
		target_combat.break_on_damage(ctx.aura if ctx != null else null)
	if flags & FLAG_NO_PROCS == 0 and amount > 0.0:
		notify_event(target, Event.DAMAGE_TAKEN, caster, amount)
		if caster != null and caster != target and flags & FLAG_PERIODIC == 0:
			notify_event(caster, Event.HIT, target, amount)
	if killed and caster != null and caster != target:
		notify_event(caster, Event.KILL, target, dealt)
	return dealt


## Host: Heilung. Gibt die wirksame Heilung (ohne Überheilung) zurück.
## Heilen bringt nicht in den Kampf.
static func heal(caster: Unit, target: Unit, amount: float, _ctx: EffectContext = null, _flags := 0) -> float:
	if not Network.is_host() or not _is_alive(target) or amount <= 0.0:
		return 0.0
	caster = caster if caster != null and is_instance_valid(caster) else null
	var overheal := target.apply_heal(amount, caster)
	show_text(caster, target, TextKind.HEAL, amount)
	return amount - overheal


## Host: Einheit ist (wieder) im Kampf; sie verlässt ihn kampf_dauer Sekunden
## nach dem letzten solchen Ereignis.
static func enter_combat(unit: Unit) -> void:
	if unit != null and is_instance_valid(unit) and unit.get_combat() != null:
		unit.get_combat().enter_combat()


## Bedrohung ändern (Platzhalter bis #35): wird bei target mitgezählt und im
## Entwickler-Panel angezeigt, hat aber noch keine Wirkung.
static func add_threat(caster: Unit, target: Unit, amount: float) -> void:
	if Network.is_host() and _is_alive(target) and caster != null and target.get_combat() != null:
		target.get_combat().add_threat(caster, amount)


# --- Ereignisse --------------------------------------------------------------

## Host: Ereignis an die Auren von unit melden (Auslöser). other = die andere
## beteiligte Einheit (getroffenes Ziel, Angreifer …), amount = Betrag.
static func notify_event(unit: Unit, event: Event, other: Unit = null, amount := 0.0,
		ability_id: StringName = &"") -> void:
	if not Network.is_host() or unit == null or not is_instance_valid(unit) or unit.get_combat() == null:
		return
	if _depth >= MAX_DEPTH:
		return
	_depth += 1
	unit.get_combat().on_event(event, other, amount, ability_id)
	_depth -= 1


## Host: caster hat eine Fähigkeit gewirkt (#33 ruft das nach dem Wirken).
static func notify_ability_cast(caster: Unit, ability_id: StringName, target: Unit = null) -> void:
	notify_event(caster, Event.ABILITY_CAST, target, 0.0, ability_id)


# --- Hilfen ------------------------------------------------------------------

## true, wenn a und b Feinde (oder neutral) zueinander sind.
static func is_hostile(a: Unit, b: Unit) -> bool:
	return a != null and b != null and a != b and a.get_reaction_to(b) != Unit.Reaction.FRIENDLY


## ID eines Zustands-Bits (z. B. &"betaeubung").
static func state_id(state: int) -> StringName:
	return STATE_IDS.get(state, &"")


## Lesbare Liste der Zustände in flags, z. B. „Betäubt, Verlangsamt“.
static func state_names(flags: int) -> String:
	var names: PackedStringArray = []
	for state: int in STATE_NAMES:
		if flags & state:
			names.append(STATE_NAMES[state])
	return ", ".join(names)


static func _is_alive(unit: Unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit.is_inside_tree() and not unit.is_dead()


## Kampftext verteilen: Schaden, Heilung, Immun und Absorbiert sieht der
## Wirker über dem Ziel; erlittenen Schaden und Absorbiert sieht das Ziel an
## sich selbst (nur Spieler, nur ihr eigener Bildschirm).
static func show_text(caster: Unit, target: Unit, kind: TextKind, amount: float) -> void:
	var combat := target.get_combat()
	if combat == null:
		return
	var caster_peer := caster.get_controlling_peer() if caster != null and caster.is_player_unit() else 0
	var target_peer := target.get_controlling_peer() if target.is_player_unit() else 0
	match kind:
		TextKind.DAMAGE:
			if caster_peer != 0 and caster_peer != target_peer:
				combat.send_combat_text(caster_peer, TextKind.DAMAGE, amount)
			if target_peer != 0:
				combat.send_combat_text(target_peer, TextKind.TAKEN, amount)
		TextKind.HEAL:
			if caster_peer != 0:
				combat.send_combat_text(caster_peer, TextKind.HEAL, amount)
		TextKind.IMMUNE, TextKind.ABSORB:
			if caster_peer != 0:
				combat.send_combat_text(caster_peer, kind, amount)
			if target_peer != 0 and target_peer != caster_peer:
				combat.send_combat_text(target_peer, kind, amount)
