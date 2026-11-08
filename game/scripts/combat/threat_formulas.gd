class_name ThreatFormulas
extends RefCounted
## Formeln der Bedrohung (Ticket #35) als reine Funktionen: keine Einheiten,
## keine Tabellen, kein Zufall. Combat bzw. UnitCombat holen die Werte aus
## spielkonstanten.csv und den Auren und geben sie hier hinein; die Tests
## („--tests“, test_threat_formulas.gd) prüfen sie ohne Spielwelt.
##
## Begriffe:
## - Schwelle: Prozent der Bedrohung des aktuellen Ziels, die ein anderer
##   Spieler erreichen muss, damit der Gegner wechselt (bedrohung_schwelle_*
##   in spielkonstanten.csv: 110 im Nahkampf, 130 auf Abstand).
## - Eintrag der Bedrohungsliste für choose_target: {"key": beliebig (z. B.
##   Knotenpfad), "threat": float, "melee": bool (in Nahkampfreichweite)}.

## Stufen der Bedrohungsanzeige am Zielrahmen.
enum Level { SAFE, WARNING, AGGRO }


## Schwelle als Faktor: 110 % → 1,1 (im Nahkampf), 130 % → 1,3 (auf Abstand).
static func switch_factor(in_melee: bool, melee_percent: float, ranged_percent: float) -> float:
	return maxf(0.0, (melee_percent if in_melee else ranged_percent) / 100.0)


## Bedrohung, die ein anderer Spieler braucht, um das Ziel zu übernehmen.
static func needed_to_pull(current_threat: float, in_melee: bool, melee_percent: float,
		ranged_percent: float) -> float:
	return maxf(0.0, current_threat) * switch_factor(in_melee, melee_percent, ranged_percent)


## Faktor auf erzeugte Bedrohung aus der Summe der prozentualen Modifikatoren
## (Auren): +200 → 3,0 (Tankhaltung), −50 → 0,5; nie unter 0.
static func modifier_factor(percent_sum: float) -> float:
	return maxf(0.0, 1.0 + percent_sum / 100.0)


## Bedrohung durch Schaden: Schaden × Bedrohung je Schaden × Faktor.
static func damage_threat(damage: float, per_damage: float, factor: float) -> float:
	return maxf(0.0, damage) * per_damage * factor


## Bedrohung je Gegner durch Heilung: wirksame Heilung (ohne Überheilung) ×
## Heilfaktor × Faktor, aufgeteilt auf alle Gegner, die mit dem Geheilten im
## Kampf sind (0 Gegner = keine Bedrohung).
static func heal_threat_per_enemy(effective_heal: float, heal_factor: float, factor: float,
		enemy_count: int) -> float:
	if enemy_count <= 0:
		return 0.0
	return maxf(0.0, effective_heal) * heal_factor * factor / float(enemy_count)


## Spott: Die Bedrohung des Spottenden wird die höchste der Liste (sinkt nie).
static func taunt_threat(own: float, highest: float) -> float:
	return maxf(own, highest)


## Neues Ziel eines Gegners. entries: Einträge der Liste (siehe oben),
## current_key: bisheriges Ziel (null = keins), forced_key: Spottender mit
## laufendem Spott (null = keiner).
## Regeln: Spott geht vor. Ohne (gültiges) bisheriges Ziel nimmt der Gegner
## den mit der höchsten Bedrohung. Sonst wechselt er erst, wenn ein anderer
## die Schwelle erreicht (im Nahkampf 110 %, sonst 130 % der Bedrohung des
## bisherigen Ziels); erreichen sie mehrere, nimmt er den mit der höchsten
## Bedrohung. Gibt den Schlüssel zurück (null bei leerer Liste).
static func choose_target(entries: Array, current_key: Variant, melee_percent: float,
		ranged_percent: float, forced_key: Variant = null) -> Variant:
	if entries.is_empty():
		return null
	if forced_key != null:
		for entry: Dictionary in entries:
			if entry["key"] == forced_key:
				return forced_key
	var current: Dictionary = {}
	if current_key != null:
		for entry: Dictionary in entries:
			if entry["key"] == current_key:
				current = entry
				break
	if current.is_empty():
		var best: Dictionary = entries[0]
		for entry: Dictionary in entries:
			if float(entry["threat"]) > float(best["threat"]):
				best = entry
		return best["key"]
	var current_threat := float(current["threat"])
	var result: Variant = current_key
	var result_threat := -1.0
	for entry: Dictionary in entries:
		if entry["key"] == current_key:
			continue
		var threat := float(entry["threat"])
		if threat <= 0.0:
			continue
		var needed := needed_to_pull(current_threat, bool(entry["melee"]), melee_percent, ranged_percent)
		if threat >= needed and threat > result_threat:
			result = entry["key"]
			result_threat = threat
	return result


## Anzeige am Zielrahmen: eigene Bedrohung in Prozent der Bedrohung, die zum
## Zielwechsel nötig wäre. Hat man selbst die Aufmerksamkeit, 100.
static func display_percent(own: float, target_threat: float, is_target: bool, in_melee: bool,
		melee_percent: float, ranged_percent: float) -> float:
	if is_target:
		return 100.0
	var needed := needed_to_pull(target_threat, in_melee, melee_percent, ranged_percent)
	if needed <= 0.0:
		return 0.0
	return clampf(maxf(0.0, own) / needed * 100.0, 0.0, 999.0)


## Stufe der Anzeige: rot, wenn man die Aufmerksamkeit hat, gelb ab
## warn_percent, sonst grün.
static func display_level(percent: float, is_target: bool, warn_percent: float) -> Level:
	if is_target:
		return Level.AGGRO
	if percent >= warn_percent:
		return Level.WARNING
	return Level.SAFE
