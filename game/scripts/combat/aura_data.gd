class_name AuraData
extends Resource
## Eine Aura als Daten (Ticket #32). Datensätze in res://data/auras/,
## geladen über GameData.get_aura(id). Buffs, Debuffs, Kontrolleffekte,
## Volksfähigkeiten, Talente, Siegel und Talismane sind Auren.
##
## Verwaltet von UnitCombat (Host); Clients bekommen ID, Wirker, Stapel,
## Ablaufzeit und Restschild übertragen und lesen alles andere aus dieser
## Datei (gleiche Daten auf allen Instanzen).

## Kategorie für späteres Bannen.
enum Category { NONE, MAGIC, POISON, DISEASE, CURSE, PHYSICAL }
## Erneutes Anwenden:
## REFRESH    – Dauer erneuern (eine Instanz je Ziel, neuester Wirker)
## ADD_STACK  – Stapel hinzufügen und Dauer erneuern (eine Instanz je Ziel)
## PER_CASTER – getrennte Instanz je Wirker; innerhalb einer Instanz
##              Stapel hinzufügen (max_stacks > 1) bzw. Dauer erneuern
enum StackMode { REFRESH, ADD_STACK, PER_CASTER }
## Schadensumleitung:
## DELAY     – Anteil wird verzögert über redirect_delay Sekunden als Schaden
##             genommen (z. B. Last)
## TO_CASTER – Anteil nimmt der Wirker der Aura (z. B. Treuer Gefährte,
##             Beschützer der Herde)
enum RedirectMode { NONE, DELAY, TO_CASTER }

const CATEGORY_NAMES := {
	Category.NONE: "",
	Category.MAGIC: "Magie",
	Category.POISON: "Gift",
	Category.DISEASE: "Krankheit",
	Category.CURSE: "Fluch",
	Category.PHYSICAL: "Körperlich",
}

## Feste ID (z. B. &"test_dot"), wird übertragen und nie geändert.
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Icon; leer = Platzhalter (Kürzel aus dem Namen).
@export var icon: Texture2D
@export var is_debuff := false
@export var category: Category = Category.NONE
## Dauer in Sekunden (0 = dauerhaft). Mit ability_id kommt sie aus der Tabelle.
@export var duration := 0.0
## Zahlen (Spalten dauer, tick) aus faehigkeitswerte.csv dieser Fähigkeit,
## sofern dort > 0. Leer = Felder dieser Datei.
@export var ability_id: StringName
## Nicht anzeigen (z. B. passive Volks- und Klassenauren).
@export var hidden := false
## Eigene Buffs dürfen per Rechtsklick beendet werden.
@export var cancelable := true

@export_group("Stapel")
@export_range(1, 99) var max_stacks := 1
@export var stack_mode: StackMode = StackMode.REFRESH

@export_group("Periodisch")
## Sekunden zwischen zwei Ticks (0 = keine Ticks).
@export var tick_interval := 0.0
## Effekte je Tick; Hauptziel ist der Träger der Aura, Wirker der Wirker der
## Aura. Schaden und Heilung werden beim Anwenden berechnet und bleiben fest.
@export var tick_effects: Array[EffectData] = []
## Ticks wirken je Stapel (Betrag × Stapel).
@export var ticks_scale_with_stacks := true

@export_group("Beim Anwenden")
## Einmal beim ersten Anwenden (Hauptziel = Träger). „Fähigkeit verändern“
## hier gilt, solange die Aura besteht.
@export var apply_effects: Array[EffectData] = []

@export_group("Werte")
## Modifikatoren über das Wertesystem, Quelle ist die Aura-Instanz.
@export var stat_modifiers: Array[StatModifierData] = []
@export var modifiers_scale_with_stacks := true

@export_group("Zustände")
@export_flags("Betäubt", "Festgehalten", "Verlangsamt", "Still", "Umgeworfen", "Getarnt", "Unverwundbar") var states := 0
## Verlangsamung in Prozent (Zustand „Verlangsamt“). Es gilt die stärkste
## aller Auren, sie stapelt nicht.
@export_range(0.0, 100.0) var slow_percent := 0.0
## Endet, sobald der Träger Schaden nimmt (außer durch die Aura selbst).
@export var breaks_on_damage := false
## Immunität gegen Zustände oder Schadensschulen (IDs, z. B. betaeubung, feuer).
@export var grants_immunities: PackedStringArray = []

@export_group("Auslöser")
@export var procs: Array[ProcData] = []

@export_group("Absorption")
## Schild: fängt Schaden bis zu dieser Menge ab (+ Faktor × Zaubermacht des
## Wirkers, beim Anwenden berechnet). Leer gefangen endet die Aura.
@export var absorb_amount := 0.0
@export var absorb_factor := 0.0
## Nur diese Schulen (leer = alle).
@export var absorb_schools: PackedStringArray = []

@export_group("Umleitung")
@export var redirect_mode: RedirectMode = RedirectMode.NONE
@export_range(0.0, 100.0) var redirect_percent := 0.0
## DELAY: über so viele Sekunden verteilt.
@export var redirect_delay := 6.0

@export_group("Erweiterung")
## Eigene Logik einer Klasse (Unterklasse von AuraLogic), optional.
@export var logic: AuraLogic


func is_permanent() -> bool:
	return get_duration() <= 0.0


## Dauer in Sekunden (Tabelle der Fähigkeit oder Feld).
func get_duration() -> float:
	return _table_number("dauer", duration)


func get_tick_interval() -> float:
	return _table_number("tick", tick_interval)


func get_category_name() -> String:
	return CATEGORY_NAMES.get(category, "")


## „Buff“ bzw. „Debuff · Magie“.
func get_kind_text() -> String:
	var text := "Debuff" if is_debuff else "Buff"
	if category != Category.NONE:
		text += " · " + get_category_name()
	return text


## Kürzel für das Platzhalter-Icon (wie AbilityData.get_short_name).
func get_short_name() -> String:
	var words: PackedStringArray = []
	for word in display_name.split(" ", false):
		var letters := ""
		for character in word:
			if character.to_upper() != character.to_lower():
				letters += character
		if letters != "":
			words.append(letters)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].left(2)
	return (words[0].left(1) + words[1].left(1)).to_upper()


func _table_number(key: String, fallback: float) -> float:
	if ability_id == &"":
		return fallback
	var value: Variant = Data.faehigkeitswert(ability_id, key, 0.0)
	return float(value) if (value is float or value is int) and float(value) > 0.0 else fallback
