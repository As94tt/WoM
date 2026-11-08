class_name Combat
extends RefCounted
## Kampfkern (Ticket #32, Trefferberechnung seit #34): zentrale Funktionen des
## Effekt- und Aura-Systems. Alles hier läuft nur auf dem Host
## (Network.is_host()); Clients schicken Wünsche und zeigen an, was der Host
## überträgt.
##
## Aufbau:
## - EffectData (scripts/combat/effect_data.gd) ist ein Baustein mit Art,
##   Zielbestimmung, Bedingungen und Skalierung. Die Arten sind Unterklassen in
##   scripts/combat/effects/ (Schaden, Heilung, Aura anwenden/entfernen,
##   Ressource, Bedrohung, Bewegung, Fläche, Projektil, Fähigkeit verändern).
## - AuraData (scripts/combat/aura_data.gd) beschreibt eine Aura: Dauer,
##   Stapel, periodische Effekte, Wert-Modifikatoren, prozentuale Schadens- und
##   Heilmodifikatoren (#34), Zustände, Auslöser, Absorption, Umleitung,
##   Immunitäten. Datensätze in res://data/auras/.
## - UnitCombat (Kindknoten „Combat“ jeder Einheit) verwaltet die Auren, den
##   Kampfzustand und Veränderungen von Fähigkeiten und überträgt sie.
## - HitFormulas (#34) enthält die Formeln als reine Funktionen (Würfel,
##   Minderung, Krit, Blocken, Heilung, Waffenschaden); sie werden mit
##   „--tests“ automatisch geprüft. Combat holt die Werte dafür aus dem
##   Wertesystem und den Tabellen.
## - Combat (diese Datei) führt Effektlisten aus und rechnet Schaden und
##   Heilung (roll_damage, roll_heal; Reihenfolge siehe dort), danach
##   Kampfzustand, Auren, die durch Schaden enden, Auslöser (Procs) und
##   Kampftext/Kampflog (HitResult an die beteiligten Spieler).
##
## Einstiegspunkte:
##   Combat.execute(ability.get_effects_for(caster), ctx)   – #33 Fähigkeiten
##   Combat.roll_damage(...) / Combat.roll_heal(...)         – #34 Treffer mit Würfel
##   Combat.deal_damage(...) / Combat.heal(...)              – ohne Würfel (Panel, Umleitung)
##   Combat.notify_event(unit, Combat.Event.CRIT, other)     – Auslöser
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

## Ereignisse für Auslöser (ProcData.event). Seit #34 löst sie der echte
## Würfel aus: HIT/CRIT beim Angreifer, DODGE/PARRY/BLOCK beim Verteidiger
## (other = Angreifer), CRIT auch bei kritischer Heilung.
enum Event { HIT, CRIT, DAMAGE_TAKEN, DODGE, PARRY, BLOCK, ABILITY_CAST, KILL, AURA_EXPIRED }

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

## Flags für roll_damage/deal_damage/roll_heal/heal.
const FLAG_PERIODIC := 1      ## Tick einer Aura oder Fläche (kein „Treffer“-Auslöser)
const FLAG_NO_REDIRECT := 2   ## Schaden wird nicht umgeleitet (verhindert Schleifen)
const FLAG_NO_PROCS := 4      ## löst keine Auslöser aus
const FLAG_DUAL_WIELD := 8    ## automatischer Angriff mit zwei Waffen (verfehlt häufiger, #34)

## Größte Verschachtelung von Effekten (Auslöser, die Auslöser auslösen).
const MAX_DEPTH := 8

static var _depth := 0
## Zufall für alle Würfe des Hosts.
static var _random: RandomNumberGenerator = null


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

## Host: Schaden mit Trefferwürfel (#34), für Fähigkeiten, Effekte und den
## automatischen Angriff. Reihenfolge:
## Immunität (Zustand „unverwundbar“ oder Schule: „Immun“, kein Wurf) →
## Würfel (HitFormulas, Chancen aus dem Wertesystem); bei Verfehlt,
## Ausgewichen oder Pariert Ende → 1. Grundschaden (base_amount) →
## 2. × prozentuale Modifikatoren (Auren, Talente, Schule; danach AuraLogic) →
## 3. kritisch × kritischer Schaden → 4. Minderung durch Rüstung bzw.
## Zauberschutz (Durchschlag, Stufe des Angreifers) → 5. geblockt − Blockwert
## → mindestens 1 → 6. Umleitung, Absorption, Verzögerung → Leben. Danach
## Kampfzustand, Auslöser (Treffer, Kritisch, Ausgewichen, Pariert, Geblockt,
## erlittener Schaden, Tod) und Kampftext/Kampflog für die Beteiligten.
## flags: FLAG_PERIODIC (Tick), FLAG_DUAL_WIELD, FLAG_NO_REDIRECT, FLAG_NO_PROCS.
## Gibt das Ergebnis zurück (null, wenn nichts geschah, z. B. Ziel tot).
static func roll_damage(caster: Unit, target: Unit, base_amount: float, school: StringName,
		kind: HitFormulas.AttackKind, ctx: EffectContext = null, flags := 0) -> HitResult:
	if not Network.is_host() or not _is_alive(target):
		return null
	caster = caster if caster != null and is_instance_valid(caster) else null
	var result := make_result(caster, target, ctx, school, HitFormulas.Outcome.HIT, flags)
	enter_combat(target)
	if caster != null and caster != target:
		enter_combat(caster)
	if is_immune(target, school):
		result.outcome = HitFormulas.Outcome.IMMUNE
		report(result)
		return result
	result.outcome = HitFormulas.roll(kind, hit_table(caster, target, kind, flags), _rng())
	match result.outcome:
		HitFormulas.Outcome.MISS:
			report(result)
			return result
		HitFormulas.Outcome.DODGE, HitFormulas.Outcome.PARRY:
			report(result)
			if flags & FLAG_NO_PROCS == 0:
				var event := Event.DODGE if result.outcome == HitFormulas.Outcome.DODGE else Event.PARRY
				notify_event(target, event, caster, base_amount)
			return result
	var amount := maxf(0.0, base_amount) * damage_factor(caster, target, school)
	amount = _apply_aura_logic(caster, target, amount, school)
	var blocked := result.outcome == HitFormulas.Outcome.BLOCK
	var target_stats := target.get_stats()
	var block_value := target_stats.get_value(&"block_value") if blocked and target_stats != null else 0.0
	var calc := HitFormulas.damage(amount, 1.0, result.is_crit(), crit_multiplier(caster),
			mitigation_percent(caster, target, school), blocked, block_value)
	result.blocked = calc["blocked"]
	_finish_damage(caster, target, calc["amount"], school, ctx, flags, result)
	if flags & FLAG_NO_PROCS == 0:
		if result.is_crit() and caster != null:
			notify_event(caster, Event.CRIT, target, result.amount)
		if blocked:
			notify_event(target, Event.BLOCK, caster, result.blocked)
	return result


## Host: Schaden ohne Würfel und ohne Rüstung (Entwickler-Panel, verzögerter
## Schaden, umgeleiteter Schaden – der war schon gemindert). Immunität,
## AuraLogic, Umleitung, Absorption, Auslöser und Kampftext wie bei
## roll_damage. Gibt den tatsächlich abgezogenen Betrag zurück.
static func deal_damage(caster: Unit, target: Unit, amount: float, school: StringName,
		ctx: EffectContext = null, flags := 0) -> float:
	if not Network.is_host() or not _is_alive(target):
		return 0.0
	caster = caster if caster != null and is_instance_valid(caster) else null
	var result := make_result(caster, target, ctx, school, HitFormulas.Outcome.HIT, flags)
	enter_combat(target)
	if caster != null and caster != target:
		enter_combat(caster)
	if is_immune(target, school):
		result.outcome = HitFormulas.Outcome.IMMUNE
		report(result)
		return 0.0
	amount = _apply_aura_logic(caster, target, maxf(0.0, amount), school)
	return _finish_damage(caster, target, amount, school, ctx, flags, result)


## Host: Heilung mit Würfel (#34): Grundheilung (base_amount, bereits mit
## Zaubermacht) × Modifikatoren (gewirkte Heilung des Wirkers, erhaltene
## Heilung des Ziels), kritisch × kritischer Heilwert (Wert „Kritischer
## Schaden“). Überheilung steht im Ergebnis. Heilen bringt nicht in den Kampf.
static func roll_heal(caster: Unit, target: Unit, base_amount: float, ctx: EffectContext = null,
		flags := 0) -> HitResult:
	if not Network.is_host() or not _is_alive(target) or base_amount <= 0.0:
		return null
	caster = caster if caster != null and is_instance_valid(caster) else null
	var result := make_result(caster, target, ctx, &"", HitFormulas.Outcome.HIT, flags, true)
	result.outcome = HitFormulas.roll(HitFormulas.AttackKind.HEAL,
			hit_table(caster, target, HitFormulas.AttackKind.HEAL, flags), _rng())
	var stats := target.get_stats()
	var missing := maxf(0.0, stats.max_health - stats.health) if stats != null else 0.0
	var calc := HitFormulas.heal(base_amount, heal_factor(caster, target), result.is_crit(),
			crit_multiplier(caster), missing)
	_finish_heal(caster, target, calc["amount"], result)
	if result.is_crit() and caster != null and flags & FLAG_NO_PROCS == 0:
		notify_event(caster, Event.CRIT, target, result.amount)
	return result


## Host: Heilung ohne Würfel und Modifikatoren (Entwickler-Panel). Gibt die
## wirksame Heilung (ohne Überheilung) zurück.
static func heal(caster: Unit, target: Unit, amount: float, ctx: EffectContext = null, flags := 0) -> float:
	if not Network.is_host() or not _is_alive(target) or amount <= 0.0:
		return 0.0
	caster = caster if caster != null and is_instance_valid(caster) else null
	var result := make_result(caster, target, ctx, &"", HitFormulas.Outcome.HIT, flags, true)
	_finish_heal(caster, target, amount, result)
	return result.amount - result.overheal


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


# --- Werte für die Formeln (aus Wertesystem und Tabellen) --------------------

## Chancentabelle eines Angriffs (HitFormulas.chance_table) mit den Werten
## von Angreifer und Ziel: Verfehlen aus dem Stufenunterschied
## (spielkonstanten.csv, bei FLAG_DUAL_WIELD + verfehlen_beidhaendig),
## Ausweichen, Parieren und Blocken des Ziels (ohne Nahkampfwaffe bzw. Schild
## sind sie im Wertesystem 0), kritische Trefferchance des Angreifers; von
## hinten kein Parieren und Blocken.
static func hit_table(caster: Unit, target: Unit, kind: HitFormulas.AttackKind, flags := 0) -> Dictionary:
	var raw := {}
	var caster_stats := caster.get_stats() if caster != null else null
	var target_stats := target.get_stats() if target != null else null
	if caster != null and target != null and kind != HitFormulas.AttackKind.HEAL \
			and kind != HitFormulas.AttackKind.PERIODIC:
		var extra := Data.konstante(&"verfehlen_beidhaendig") if flags & FLAG_DUAL_WIELD else 0.0
		raw[HitFormulas.Outcome.MISS] = HitFormulas.miss_chance(caster.get_level(), target.get_level(),
				Data.konstante(&"verfehlen_grund"), Data.konstante(&"verfehlen_pro_stufe"),
				Data.konstante(&"verfehlen_min"), Data.konstante(&"verfehlen_max", 100.0), extra)
	if target_stats != null:
		raw[HitFormulas.Outcome.DODGE] = target_stats.get_value(&"dodge")
		raw[HitFormulas.Outcome.PARRY] = target_stats.get_value(&"parry")
		raw[HitFormulas.Outcome.BLOCK] = target_stats.get_value(&"block")
	if caster_stats != null:
		raw[HitFormulas.Outcome.CRIT] = caster_stats.get_value(&"crit_chance")
	var from_behind := caster != null and target != null and caster != target and caster.is_behind(target)
	return HitFormulas.chance_table(kind, raw, from_behind)


## Faktor auf Schaden aus Modifikatoren (#34): verursachter Schaden des
## Angreifers × erlittener Schaden des Ziels, jeweils für die Schule.
static func damage_factor(caster: Unit, target: Unit, school: StringName) -> float:
	var factor := 1.0
	if caster != null and caster.get_combat() != null:
		factor *= HitFormulas.percent_factor(caster.get_combat().get_amount_percent(
				AmountModifierData.Kind.DAMAGE_DONE, school))
	if target != null and target.get_combat() != null:
		factor *= HitFormulas.percent_factor(target.get_combat().get_amount_percent(
				AmountModifierData.Kind.DAMAGE_TAKEN, school))
	return factor


## Faktor auf Heilung: gewirkte Heilung des Wirkers × erhaltene Heilung des Ziels.
static func heal_factor(caster: Unit, target: Unit) -> float:
	var factor := 1.0
	if caster != null and caster.get_combat() != null:
		factor *= HitFormulas.percent_factor(caster.get_combat().get_amount_percent(
				AmountModifierData.Kind.HEALING_DONE))
	if target != null and target.get_combat() != null:
		factor *= HitFormulas.percent_factor(target.get_combat().get_amount_percent(
				AmountModifierData.Kind.HEALING_TAKEN))
	return factor


## Faktor kritischer Treffer und Heilungen (Wert „Kritischer Schaden“ des
## Wirkers; ohne Wirker der Grundwert krit_grundschaden).
static func crit_multiplier(caster: Unit) -> float:
	var stats := caster.get_stats() if caster != null else null
	var percent := stats.get_value(&"crit_damage") if stats != null \
			else Data.konstante(&"krit_grundschaden", 200.0)
	return HitFormulas.crit_factor(percent)


## true, wenn die Schule körperlich ist (Spalte „art“ in schadensschulen.csv):
## Rüstung mindert sie, sonst Zauberschutz.
static func is_physical(school: StringName) -> bool:
	var row := Data.schadensschule(school)
	if row == null:
		return school == &"physisch"
	return String(row.get_value("art", "magisch")) == "koerperlich"


## Minderung in Prozent für einen Treffer: körperlich durch Rüstung, magisch
## durch Zauberschutz des Ziels, verringert durch Durchschlag des Angreifers;
## Konstante k aus umrechnung.csv auf der Stufe des Angreifers, Obergrenze
## aus spielkonstanten.csv (HitFormulas.mitigation_percent).
static func mitigation_percent(caster: Unit, target: Unit, school: StringName) -> float:
	var target_stats := target.get_stats() if target != null else null
	if target_stats == null:
		return 0.0
	var physical := is_physical(school)
	var defense := target_stats.get_value(&"armor" if physical else &"spell_ward")
	if defense <= 0.0:
		return 0.0
	var caster_stats := caster.get_stats() if caster != null else null
	var penetration := caster_stats.get_value(&"penetration_pct") if caster_stats != null else 0.0
	var level := caster.get_level() if caster != null else target.get_level()
	var conversion := Data.umrechnung(level)
	var column := "ruestung_konstante" if physical else "zauberschutz_konstante"
	var k := float(conversion.get_value(column, 0.0)) if conversion != null else 0.0
	var cap := Data.konstante(&"obergrenze_ruestung" if physical else &"obergrenze_zauberschutz", 100.0)
	return HitFormulas.mitigation_percent(defense, penetration, k, cap)


## Immun gegen diesen Schaden: Zustand „unverwundbar“ oder Immunität gegen die Schule.
static func is_immune(target: Unit, school: StringName) -> bool:
	var combat := target.get_combat() if target != null else null
	return combat != null and (combat.has_state(STATE_INVULNERABLE) or combat.is_immune_to(school))


## Platzhalter-Waffe einer Einheit (#33, bis Ausrüstung kommt #29):
## Fernkampf, wenn ranged und der Schalter gesetzt ist, sonst Haupthand mit
## Nahkampfwaffe, sonst unbewaffnet. Zeile aus platzhalterwaffen.csv oder null.
static func weapon_row(unit: Unit, ranged := false) -> TableRow:
	var stats := unit.get_stats() if unit != null else null
	if ranged and stats != null and stats.has_flag(StatBlock.FLAG_RANGED_WEAPON):
		return Data.platzhalterwaffe(&"fernkampf")
	if stats != null and stats.has_flag(StatBlock.FLAG_MELEE_WEAPON):
		return Data.platzhalterwaffe(&"haupthand")
	return Data.platzhalterwaffe(&"unbewaffnet")


## Waffenschaden eines Schlags mit der Waffe row: Wurf zwischen min und max
## plus Kampfkraft (HitFormulas.weapon_damage).
static func weapon_damage(unit: Unit, row: TableRow) -> float:
	if row == null:
		return 0.0
	var low := float(row.get_value("schaden_min", 1.0))
	var stats := unit.get_stats() if unit != null else null
	return HitFormulas.weapon_damage(low, float(row.get_value("schaden_max", low)), _rng().randf(),
			stats.get_value(&"attack_power") if stats != null else 0.0,
			Data.konstante(&"kampfkraft_je_dps", 14.0), float(row.get_value("tempo", 2.0)))


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


# --- Kampftext und Kampflog --------------------------------------------------

## Neues Ergebnis mit Namen und Herkunft (Fähigkeit bzw. ctx.source_name).
static func make_result(caster: Unit, target: Unit, ctx: EffectContext, school: StringName,
		outcome: HitFormulas.Outcome, flags := 0, is_heal := false) -> HitResult:
	var result := HitResult.new()
	result.source = caster
	result.target = target
	if caster != null and is_instance_valid(caster) and caster.is_inside_tree():
		result.source_path = caster.get_path()
		result.source_name = caster.get_unit_name()
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		result.target_path = target.get_path()
		result.target_name = target.get_unit_name()
	if ctx != null:
		result.ability_name = ctx.source_name if ctx.source_name != "" \
				else (ctx.ability.display_name if ctx.ability != null else "")
	result.school = school if school != &"" else &"physisch"
	result.outcome = outcome
	if flags & FLAG_PERIODIC:
		result.flags |= HitResult.FLAG_PERIODIC
	if is_heal:
		result.flags |= HitResult.FLAG_HEAL
	return result


## Host: Ergebnis an die beteiligten Spieler schicken (Wirker und Ziel, jeder
## nur einmal). Nur sie sehen Kampftext und Kampflog dazu.
static func report(result: HitResult) -> void:
	if not Network.is_host() or result == null:
		return
	var target := result.target
	if target == null or not is_instance_valid(target) or target.get_combat() == null:
		return
	var source := result.source
	var source_peer := source.get_controlling_peer() \
			if source != null and is_instance_valid(source) and source.is_player_unit() else 0
	var target_peer := target.get_controlling_peer() if target.is_player_unit() else 0
	if source_peer != 0:
		target.get_combat().send_hit(source_peer, result)
	if target_peer != 0 and target_peer != source_peer:
		target.get_combat().send_hit(target_peer, result)


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


static func _rng() -> RandomNumberGenerator:
	if _random == null:
		_random = RandomNumberGenerator.new()
		_random.randomize()
	return _random


## AuraLogic des Wirkers (ausgehend) und des Ziels (eingehend), #32.
static func _apply_aura_logic(caster: Unit, target: Unit, amount: float, school: StringName) -> float:
	if caster != null and caster.get_combat() != null:
		amount = caster.get_combat().modify_outgoing_damage(amount, school, target)
	if target.get_combat() != null:
		amount = target.get_combat().modify_incoming_damage(amount, school, caster)
	return maxf(0.0, amount)


## Schritt 6 und Rest: Umleitung, Absorption, Leben, Wut, Auren mit „endet
## durch Schaden“, Zauberzeit verzögern, Auslöser, Kampftext. Füllt result
## (amount = nach Absorption, absorbed) und gibt den abgezogenen Betrag zurück.
static func _finish_damage(caster: Unit, target: Unit, amount: float, school: StringName,
		ctx: EffectContext, flags: int, result: HitResult) -> float:
	var target_combat := target.get_combat()
	var after_redirect := amount
	if target_combat != null and flags & FLAG_NO_REDIRECT == 0:
		after_redirect = target_combat.redirect_damage(amount, caster, school)
	var absorbed := target_combat.absorb_damage(after_redirect, school) if target_combat != null else 0.0
	var remaining := after_redirect - absorbed
	var stats := target.get_stats()
	var before := stats.health if stats != null else 0.0
	var dealt := target.apply_damage(remaining, caster) if remaining > 0.0 else 0.0
	var killed := stats != null and before > 0.0 and dealt > 0.0 and dealt >= before - 0.001
	if caster != null and caster.get_stats() != null and dealt > 0.0:
		caster.get_stats().register_damage_dealt(dealt)
	result.absorbed = absorbed
	result.amount = maxf(0.0, amount - absorbed)
	report(result)
	if target_combat != null and dealt + absorbed > 0.0:
		target_combat.break_on_damage(ctx.aura if ctx != null else null)
	# Zauberzeit verzögern (#33).
	var target_caster := target.get_caster_node()
	if target_caster != null and dealt > 0.0 and target != caster:
		target_caster.on_damage_taken()
	if flags & FLAG_NO_PROCS == 0 and amount > 0.0:
		notify_event(target, Event.DAMAGE_TAKEN, caster, amount)
		if caster != null and caster != target and flags & FLAG_PERIODIC == 0:
			notify_event(caster, Event.HIT, target, amount)
	if killed and caster != null and caster != target:
		notify_event(caster, Event.KILL, target, dealt)
	return dealt


## Heilung aufs Leben, Überheilung erfassen (Heilpuppe zählt sie selbst),
## Kampftext und Kampflog.
static func _finish_heal(caster: Unit, target: Unit, amount: float, result: HitResult) -> void:
	var overheal := target.apply_heal(amount, caster)
	result.amount = amount
	result.overheal = overheal
	report(result)
