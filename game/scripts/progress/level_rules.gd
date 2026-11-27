class_name LevelRules
extends RefCounted
## Regeln des Stufensystems (Ticket #27) als reine Funktionen: Erfahrungs-
## kurve, Aufstieg mit Übertrag, Höchststufe, Erfahrung für Kills (Stufe,
## Stufenunterschied, Rang) und Aufteilung in der Gruppe. Alle Zahlen kommen
## aus den Tabellen (Autoload „Data“):
##   erfahrung.csv           – benötigte Erfahrung je Stufe
##   gegner_stufenwerte.csv  – Grunderfahrung eines Gegners je Stufe (Spalte
##                             „erfahrung“)
##   gegner_raenge.csv       – Faktor je Rang (Spalte „erfahrung_faktor“)
##   spielkonstanten.csv     – hoechststufe, erfahrung_bonus_pro_stufe,
##                             erfahrung_bonus_max, erfahrung_malus_pro_stufe,
##                             stufe_grau_bis, stufe_totenkopf_ab,
##                             gruppe_erfahrung_radius,
##                             gruppe_erfahrung_bonus_pro_mitglied
## Ohne Zustand, deshalb überall nutzbar (Host, Anzeige, Tests). Entscheiden
## tut nur der Host (PlayerExperience, ExperienceService).


## Höchste erreichbare Stufe (spielkonstanten.csv „hoechststufe“).
static func max_level() -> int:
	return Data.hoechste_stufe()


## Erfahrung, die auf level bis zur nächsten Stufe nötig ist; 0 auf der
## Höchststufe oder wenn die Stufe in erfahrung.csv fehlt (dann geht es dort
## nicht weiter, statt mit einer erfundenen Zahl).
static func needed_for(level: int) -> int:
	if level >= max_level():
		return 0
	return maxi(0, Data.erfahrung(level))


## Bereinigter Stand: Stufe 1 bis Höchststufe, Erfahrung 0 bis unter dem
## Bedarf der Stufe (auf der Höchststufe immer 0).
static func sanitize(level: int, experience: int) -> Dictionary:
	var clean_level := clampi(level, 1, max_level())
	var needed := needed_for(clean_level)
	var clean_xp := clampi(experience, 0, maxi(0, needed - 1)) if needed > 0 else 0
	return {"level": clean_level, "experience": clean_xp}


## Erfahrung hinzufügen: Überschuss geht in die nächste Stufe, mehrere
## Aufstiege auf einmal sind möglich. Auf der Höchststufe wird nichts mehr
## gesammelt (Rest verfällt, Erfahrung 0).
## Ergebnis: {"level", "experience", "added" (tatsächlich angerechnet),
##            "levels" (Zahl der Aufstiege)}.
static func add_experience(level: int, experience: int, amount: int) -> Dictionary:
	var state := sanitize(level, experience)
	var new_level: int = state["level"]
	var xp: int = state["experience"]
	var top := max_level()
	if amount <= 0 or new_level >= top:
		return {"level": new_level, "experience": xp, "added": 0, "levels": 0}
	var rest := amount
	var added := 0
	while rest > 0 and new_level < top:
		var needed := needed_for(new_level)
		if needed <= 0:
			break
		var step := mini(rest, needed - xp)
		xp += step
		rest -= step
		added += step
		if xp >= needed:
			xp = 0
			new_level += 1
	if new_level >= top:
		xp = 0
	return {"level": new_level, "experience": xp, "added": added,
			"levels": new_level - int(state["level"])}


## Erfahrung, die bis zur nächsten Stufe fehlt (0 auf der Höchststufe).
static func missing_to_next(level: int, experience: int) -> int:
	var needed := needed_for(level)
	return maxi(0, needed - experience) if needed > 0 else 0


# --- Stufenunterschied -------------------------------------------------------

## Unterschied = Stufe des Gegners − eigene Stufe.
## Grau („trivial“): gibt keine Erfahrung (stufe_grau_bis, wie die Farbe).
static func is_trivial(target_level: int, own_level: int) -> bool:
	return target_level - own_level <= int(Data.konstante(&"stufe_grau_bis", -8.0))


## Totenkopf statt Zahl: Gegner ist stufe_totenkopf_ab oder mehr Stufen höher.
static func shows_skull(target_level: int, own_level: int) -> bool:
	return target_level - own_level >= int(Data.konstante(&"stufe_totenkopf_ab", 10.0))


## Faktor auf die Erfahrung nach Stufenunterschied: höhere Gegner
## erfahrung_bonus_pro_stufe Prozent je Stufe mehr (höchstens
## erfahrung_bonus_max), niedrigere erfahrung_malus_pro_stufe Prozent je Stufe
## weniger (nie unter 0), graue 0.
static func level_difference_factor(target_level: int, own_level: int) -> float:
	if is_trivial(target_level, own_level):
		return 0.0
	var diff := target_level - own_level
	if diff > 0:
		var bonus := minf(diff * Data.konstante(&"erfahrung_bonus_pro_stufe", 5.0),
				Data.konstante(&"erfahrung_bonus_max", 20.0))
		return 1.0 + bonus / 100.0
	if diff < 0:
		return maxf(0.0, 1.0 + diff * Data.konstante(&"erfahrung_malus_pro_stufe", 10.0) / 100.0)
	return 1.0


## Grunderfahrung eines normalen Gegners der Stufe (gegner_stufenwerte.csv);
## fehlt die Stufe, gilt die höchste vorhandene darunter.
static func kill_base(target_level: int) -> int:
	var row := Data.gegner_stufenwerte(target_level)
	if row != null:
		return int(row.get_value("erfahrung", 0))
	var best: TableRow = null
	for candidate: TableRow in Data.rows("gegner_stufenwerte"):
		var s := int(candidate.get_value("stufe", 0))
		if s <= target_level and (best == null or s > int(best.get_value("stufe", 0))):
			best = candidate
	return int(best.get_value("erfahrung", 0)) if best != null else 0


## Faktor des Rangs (gegner_raenge.csv „erfahrung_faktor“; unbekannt = 1).
static func rank_factor(rank_id: String) -> float:
	var row := Data.gegner_rang(rank_id)
	return float(row.get_value("erfahrung_faktor", 1.0)) if row != null else 1.0


## Erfahrung für einen Kill (ohne Gruppe): Grundwert × Rang × Stufenunterschied,
## gerundet.
static func kill_experience(target_level: int, rank_id: String, own_level: int) -> int:
	return roundi(kill_base(target_level) * rank_factor(rank_id)
			* level_difference_factor(target_level, own_level))


# --- Gruppe ------------------------------------------------------------------

## Radius in Metern, in dem Gruppenmitglieder am Kill beteiligt werden.
static func group_radius() -> float:
	return Data.konstante(&"gruppe_erfahrung_radius", 50.0)


## Gesamterfahrung einer Gruppe mit members Mitgliedern in der Nähe:
## Grundwert plus gruppe_erfahrung_bonus_pro_mitglied Prozent je weiterem
## Mitglied.
static func group_total(base: int, members: int) -> int:
	if members <= 1:
		return base
	var bonus := Data.konstante(&"gruppe_erfahrung_bonus_pro_mitglied", 10.0) * (members - 1)
	return roundi(base * (1.0 + bonus / 100.0))


## Aufteilung von total nach Stufe gewichtet (höhere Stufe = größerer Anteil).
## Ergebnis in der Reihenfolge von levels.
static func group_shares(total: int, levels: Array[int]) -> Array[int]:
	var result: Array[int] = []
	var sum := 0
	for level in levels:
		sum += maxi(1, level)
	for level in levels:
		result.append(floori(float(total) * maxi(1, level) / float(sum)) if sum > 0 else 0)
	return result


## Erfahrung je Mitglied für einen Kill einer Gruppe (eine Person = solo):
## Gerechnet wird mit der höchsten Stufe der Beteiligten (ist der Gegner für
## sie grau, bekommt niemand etwas), dazu Gruppenbonus und Aufteilung nach
## Stufe. Ergebnis in der Reihenfolge von levels.
static func kill_shares(target_level: int, rank_id: String, levels: Array[int]) -> Array[int]:
	var highest := 1
	for level in levels:
		highest = maxi(highest, level)
	var base := kill_experience(target_level, rank_id, highest)
	if levels.size() <= 1:
		var single: Array[int] = []
		for _level in levels:
			single.append(base)
		return single
	return group_shares(group_total(base, levels.size()), levels)
