class_name HitResult
extends RefCounted
## Ergebnis eines Treffers oder einer Heilung (Ticket #34): wer, auf wen,
## womit, Würfelergebnis und Mengen. Der Host rechnet es (Combat) und schickt
## es per RPC nur an die beteiligten Spieler (Wirker und Ziel). Dort zeigen
## Kampftext (CombatTextLayer) und Kampflog (MessageLog, Reiter „Kampf“) es an.
##
## Mengen sind gerundet:
## - amount:   Schaden, der beim Leben ankam (bzw. Heilung inklusive Überheilung)
## - absorbed: von Schilden abgefangen
## - blocked:  durch Blocken abgezogen
## - overheal: Teil der Heilung über dem maximalen Leben

## Art des Treffers (Bits in flags).
const FLAG_HEAL := 1
const FLAG_PERIODIC := 2

var source_path := NodePath()
var target_path := NodePath()
## Namen beim Entstehen (der Kampflog bleibt lesbar, auch wenn eine Einheit fehlt).
var source_name := ""
var target_name := ""
## Fähigkeit bzw. Herkunft, z. B. „Feuerball“, „Automatischer Angriff“, „Brand“.
var ability_name := ""
var school: StringName = &"physisch"
var outcome: HitFormulas.Outcome = HitFormulas.Outcome.HIT
var amount := 0.0
var absorbed := 0.0
var blocked := 0.0
var overheal := 0.0
var flags := 0

## Nur Host, nicht übertragen: die beteiligten Einheiten (Verteilung an die
## Spieler in Combat.report).
var source: Unit = null
var target: Unit = null


func is_heal() -> bool:
	return flags & FLAG_HEAL != 0


func is_periodic() -> bool:
	return flags & FLAG_PERIODIC != 0


func is_crit() -> bool:
	return outcome == HitFormulas.Outcome.CRIT


## Angriff ging ins Leere (verfehlt, ausgewichen, pariert) bzw. immun.
func is_avoided() -> bool:
	return outcome in [HitFormulas.Outcome.MISS, HitFormulas.Outcome.DODGE,
			HitFormulas.Outcome.PARRY, HitFormulas.Outcome.IMMUNE]


func to_array() -> Array:
	return [source_path, target_path, source_name, target_name, ability_name, String(school),
			int(outcome), amount, absorbed, blocked, overheal, flags]


static func from_array(data: Array) -> HitResult:
	if data.size() < 12:
		return null
	var result := HitResult.new()
	result.source_path = data[0] if data[0] is NodePath else NodePath(str(data[0]))
	result.target_path = data[1] if data[1] is NodePath else NodePath(str(data[1]))
	result.source_name = str(data[2])
	result.target_name = str(data[3])
	result.ability_name = str(data[4])
	result.school = StringName(str(data[5]))
	result.outcome = clampi(int(data[6]), 0, HitFormulas.Outcome.size() - 1) as HitFormulas.Outcome
	result.amount = float(data[7])
	result.absorbed = float(data[8])
	result.blocked = float(data[9])
	result.overheal = float(data[10])
	result.flags = int(data[11])
	return result


## Zeile für den Kampflog ohne Uhrzeit, z. B.
## „Arthas: Feuerball trifft Schadenspuppe kritisch: 1.240 Schaden (Feuer)“.
## school_name = Anzeigename der Schule (Data.schulname).
func log_text(school_name: String) -> String:
	var who := "%s: %s" % [source_name if source_name != "" else "Unbekannt",
			ability_name if ability_name != "" else "Angriff"]
	if is_periodic():
		who += " (über Zeit)"
	match outcome:
		HitFormulas.Outcome.MISS:
			return "%s verfehlt %s" % [who, target_name]
		HitFormulas.Outcome.DODGE:
			return "%s – %s weicht aus" % [who, target_name]
		HitFormulas.Outcome.PARRY:
			return "%s – %s pariert" % [who, target_name]
		HitFormulas.Outcome.IMMUNE:
			return "%s – %s ist immun" % [who, target_name]
	var crit := " kritisch" if is_crit() else ""
	var extras: PackedStringArray = []
	var text: String
	if is_heal():
		text = "%s heilt %s%s: %s" % [who, target_name, crit, StatFormat.grouped(amount)]
		if overheal > 0.0:
			extras.append("%s Überheilung" % StatFormat.grouped(overheal))
	else:
		text = "%s trifft %s%s: %s Schaden (%s)" % [who, target_name, crit,
				StatFormat.grouped(amount), school_name]
		if blocked > 0.0 or outcome == HitFormulas.Outcome.BLOCK:
			extras.append("%s geblockt" % StatFormat.grouped(blocked))
	if absorbed > 0.0:
		extras.append("%s absorbiert" % StatFormat.grouped(absorbed))
	if not extras.is_empty():
		text += ", " + ", ".join(extras)
	return text
