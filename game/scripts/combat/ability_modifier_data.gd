class_name AbilityModifierData
extends Resource
## Veränderung einer Fähigkeit (Ticket #32), benutzt von
## ModifyAbilityEffect. Wirkt auf die Zahlen der Fähigkeit
## (AbilityData.get_number_for), kann sie ersetzen und Effekte anhängen.
##
## Rechnung je Wert: (Wert aus faehigkeitswerte.csv + Summe add) ×
## (1 + Summe percent / 100).

## Fähigkeit, die verändert wird (AbilityData.id).
@export var ability_id: StringName
## Ersetzt die Fähigkeit durch diese (leer = nicht ersetzen). Aktionsleisten
## und Wirken (#33) nutzen dann die neue.
@export var replacement_id: StringName
## Wert, der verändert wird: Spaltenname in faehigkeitswerte.csv (z. B.
## „kosten“, „abklingzeit“, „grundwert“, „reichweite“) oder „werte.<schlüssel>“.
@export var value_key := ""
@export var add := 0.0
@export var percent := 0.0
## Zusätzliche Effekte, die #33 beim Wirken nach den eigenen ausführt.
@export var added_effects: Array[EffectData] = []


## Für die Übertragung (ohne Effekte; die braucht nur der Host).
func to_array(source: StringName) -> Array:
	return [String(source), String(ability_id), String(replacement_id), value_key, add, percent]
