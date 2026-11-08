class_name HitFormulas
extends RefCounted
## Formeln der Trefferberechnung (Ticket #34) als reine Funktionen: Alles,
## was sie brauchen, kommt als Parameter herein (Chancen, Werte, Konstanten,
## Würfelzahl). Sie lesen weder Tabellen noch Einheiten und ändern nichts.
## So lassen sie sich ohne Spiel automatisch prüfen (scripts/tests/, Start mit
## „godot --headless --path game -- --tests“).
##
## Die Werte holt Combat aus dem Wertesystem (#19) und den Tabellen
## (spielkonstanten.csv, umrechnung.csv, schadensschulen.csv) und reicht sie
## hier hinein. Alle Prozentangaben sind 0–100.
##
## Trefferwürfel: Pro Angriff wird einmal gewürfelt (0 ≤ Wurf < 100). Die
## Ergebnisse liegen in fester Reihenfolge hintereinander auf dieser Skala;
## jede Chance belegt höchstens den Rest bis 100 (was danach keinen Platz
## mehr hat, fällt weg, zuerst „Kritisch“). Der Rest ist ein normaler Treffer.

## Art des Angriffs: bestimmt, welche Ergebnisse möglich sind.
## MELEE    – Nahkampf (körperlich): Verfehlt → Ausgewichen → Pariert → Geblockt → Kritisch → Treffer
## RANGED   – Fernkampf (körperlich): Verfehlt → Ausgewichen → Geblockt → Kritisch → Treffer
## SPELL    – Zauber: Verfehlt → Kritisch → Treffer
## HEAL     – Heilung: Kritisch → Heilung
## PERIODIC – Schaden über Zeit (Tick): Kritisch → Treffer (Annahme #34: Ticks
##            verfehlen nicht und werden nicht abgewehrt; das tat schon das
##            Anwenden der Aura)
enum AttackKind { MELEE, RANGED, SPELL, HEAL, PERIODIC }

## Ergebnis eines Wurfs (und Sonderfall IMMUNE, der vor dem Wurf feststeht).
enum Outcome { HIT, CRIT, MISS, DODGE, PARRY, BLOCK, IMMUNE }

## Reihenfolge der Ergebnisse je Angriffsart (ohne HIT, der den Rest füllt).
const ORDER := {
	AttackKind.MELEE: [Outcome.MISS, Outcome.DODGE, Outcome.PARRY, Outcome.BLOCK, Outcome.CRIT],
	AttackKind.RANGED: [Outcome.MISS, Outcome.DODGE, Outcome.BLOCK, Outcome.CRIT],
	AttackKind.SPELL: [Outcome.MISS, Outcome.CRIT],
	AttackKind.HEAL: [Outcome.CRIT],
	AttackKind.PERIODIC: [Outcome.CRIT],
}

const OUTCOME_NAMES := {
	Outcome.HIT: "Treffer",
	Outcome.CRIT: "Kritisch",
	Outcome.MISS: "Verfehlt",
	Outcome.DODGE: "Ausgewichen",
	Outcome.PARRY: "Pariert",
	Outcome.BLOCK: "Geblockt",
	Outcome.IMMUNE: "Immun",
}


# --- Trefferwürfel -----------------------------------------------------------

## Chancen eines Angriffs in Prozent je Ergebnis, mit den Positions- und
## Ausrüstungsregeln:
## - Von hinten kann nicht pariert oder geblockt werden.
## - Parieren nur mit Nahkampfwaffe, Blocken nur mit Schild: das liefert schon
##   das Wertesystem (parry/block sind ohne Waffe bzw. Schild 0); hier zählt
##   nur, was hereinkommt.
## raw: {Outcome.MISS: …, Outcome.DODGE: …, Outcome.PARRY: …, Outcome.BLOCK: …,
## Outcome.CRIT: …}; fehlende Einträge zählen als 0.
## Ergebnis: Chance je Ergebnis (alle Ergebnisse außer IMMUNE; für kind
## unmögliche mit 0), begrenzt auf 0–100 und auf den Rest bis 100, dazu HIT
## als Rest.
static func chance_table(kind: AttackKind, raw: Dictionary, from_behind: bool) -> Dictionary:
	var table := {Outcome.MISS: 0.0, Outcome.DODGE: 0.0, Outcome.PARRY: 0.0, Outcome.BLOCK: 0.0,
			Outcome.CRIT: 0.0}
	var used := 0.0
	for outcome: Outcome in ORDER[kind]:
		var chance := clampf(float(raw.get(outcome, 0.0)), 0.0, 100.0)
		if from_behind and (outcome == Outcome.PARRY or outcome == Outcome.BLOCK):
			chance = 0.0
		chance = minf(chance, 100.0 - used)
		table[outcome] = chance
		used += chance
	table[Outcome.HIT] = maxf(0.0, 100.0 - used)
	return table


## Ergebnis für einen Wurf roll (0 ≤ roll < 100) auf der Tabelle aus
## chance_table (Reihenfolge wie dort).
static func resolve(kind: AttackKind, table: Dictionary, roll: float) -> Outcome:
	var upper := 0.0
	for outcome: Outcome in ORDER[kind]:
		upper += float(table.get(outcome, 0.0))
		if roll < upper:
			return outcome
	return Outcome.HIT


## Würfeln mit einem Zufallsgenerator (für Tests mit festem Startwert).
static func roll(kind: AttackKind, table: Dictionary, rng: RandomNumberGenerator) -> Outcome:
	return resolve(kind, table, rng.randf() * 100.0)


## Chance zu verfehlen in Prozent: nur Stufenunterschied (kein Trefferwert).
## base bei gleicher Stufe, per_level je Stufe, die das Ziel höher ist (bzw.
## weniger, wenn es niedriger ist), begrenzt auf low–high; dazu extra
## (z. B. automatische Angriffe bei Beidhändigkeit), danach auf 0–100.
static func miss_chance(attacker_level: int, target_level: int, base: float, per_level: float,
		low: float, high: float, extra := 0.0) -> float:
	var chance := clampf(base + float(target_level - attacker_level) * per_level, low, high)
	return clampf(chance + extra, 0.0, 100.0)


# --- Schaden -----------------------------------------------------------------

## Faktor aus prozentualen Modifikatoren (Summe in Prozent, additiv):
## +20 und +10 → × 1,3; −100 und weniger → 0.
static func percent_factor(percent_sum: float) -> float:
	return maxf(0.0, 1.0 + percent_sum / 100.0)


## Faktor eines kritischen Treffers bzw. einer kritischen Heilung aus dem Wert
## „Kritischer Schaden“ in Prozent (200 → × 2). Nie unter 1.
static func crit_factor(crit_damage_percent: float) -> float:
	return maxf(1.0, crit_damage_percent / 100.0)


## Minderung in Prozent durch Rüstung bzw. Zauberschutz (abnehmender Ertrag):
## wirksamer Wert = defense × (1 − Durchschlag / 100), Minderung =
## 100 × wirksam / (wirksam + k), höchstens cap. k ist die Konstante der
## Stufe des Angreifers (umrechnung.csv: ruestung_konstante bzw.
## zauberschutz_konstante) – so hängt die Minderung vom Stufenunterschied ab:
## Gegen einen niedrigeren Angreifer (kleines k) hilft dieselbe Rüstung mehr.
static func mitigation_percent(defense: float, penetration_percent: float, k: float, cap: float) -> float:
	var effective := maxf(0.0, defense) * (1.0 - clampf(penetration_percent, 0.0, 100.0) / 100.0)
	if effective <= 0.0 or k <= 0.0:
		return 0.0 if effective <= 0.0 else clampf(cap, 0.0, 100.0)
	return minf(100.0 * effective / (effective + k), clampf(cap, 0.0, 100.0))


## Schaden nach den Schritten 1–5 des Tickets (Absorption, Umleitung und
## Immunität folgen danach in Combat):
## 1. base (Grundschaden des Effekts bzw. Waffenschaden),
## 2. × modifier_factor (percent_factor der Auren, Talente und Schule),
## 3. kritisch: × crit_multiplier (crit_factor),
## 4. − mitigation_pct Prozent (mitigation_percent),
## 5. geblockt: − block_value.
## Ergebnis gerundet, mindestens 1. Gibt {"amount", "blocked", "mitigated"}
## zurück (blocked/mitigated: abgezogene Menge, für Kampftext und Kampflog).
static func damage(base: float, modifier_factor: float, crit: bool, crit_multiplier: float,
		mitigation_pct: float, blocked: bool, block_value: float) -> Dictionary:
	var amount := maxf(0.0, base) * maxf(0.0, modifier_factor)
	if crit:
		amount *= maxf(1.0, crit_multiplier)
	var mitigated := amount * clampf(mitigation_pct, 0.0, 100.0) / 100.0
	amount -= mitigated
	var block_part := 0.0
	if blocked:
		block_part = minf(amount, maxf(0.0, block_value))
		amount -= block_part
	var final := maxf(1.0, roundf(amount))
	return {"amount": final, "blocked": roundf(block_part), "mitigated": roundf(mitigated)}


## Heilung: base × modifier_factor (eigene Heilung und „erhaltene Heilung“
## des Ziels), kritisch × crit_multiplier, gerundet. missing = fehlendes Leben
## des Ziels. Gibt {"amount", "effective", "overheal"} zurück.
static func heal(base: float, modifier_factor: float, crit: bool, crit_multiplier: float,
		missing: float) -> Dictionary:
	var amount := maxf(0.0, base) * maxf(0.0, modifier_factor)
	if crit:
		amount *= maxf(1.0, crit_multiplier)
	amount = roundf(amount)
	var effective := minf(amount, maxf(0.0, missing))
	return {"amount": amount, "effective": effective, "overheal": amount - effective}


## Waffenschaden eines Schlags: Wurf zwischen low und high (roll01 = 0–1)
## plus Kampfkraft / ap_per_dps × Tempo der Waffe (Kampfkraft erhöht den
## Schaden pro Sekunde, langsame Waffen treffen dafür härter).
static func weapon_damage(low: float, high: float, roll01: float, attack_power: float,
		ap_per_dps: float, speed: float) -> float:
	var weapon := lerpf(low, maxf(low, high), clampf(roll01, 0.0, 1.0))
	return weapon + maxf(0.0, attack_power) / maxf(1.0, ap_per_dps) * maxf(0.0, speed)
