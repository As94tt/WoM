class_name TalentData
extends Resource
## Ein Talent als Daten (Ticket #20), Teil einer Reihe (TalentRowData) eines
## Talentbaums. Was das Talent tut, steht vollständig in den Daten:
##
## - grants_abilities: neue Fähigkeiten. Sie erscheinen im Zauberbuch im
##   Reiter der Spezialisierung, kommen automatisch auf die Aktionsleisten und
##   verschwinden beim Zurücksetzen wieder von ihnen.
## - effects: Effekte aus dem Effekt- und Aura-System (#32), die der Host je
##   Rang einmal auf die Figur anwendet. Für „Fähigkeit verändern oder
##   ersetzen“ ist das der Effekt ModifyAbilityEffect (Quelle
##   „talent:<id>:<rang>“, damit sich Ränge addieren). Andere Effektarten
##   (auch eigene einer Klasse) laufen über Combat.execute mit der Figur als
##   Wirker und Ziel.
## - auras: passive Auren (#32), dauerhaft auf der Figur, solange das Talent
##   gelernt ist. Stapel = Rang; mit „modifiers_scale_with_stacks“ wirkt jeder
##   Rang stärker. Talent-Auren sollten dauerhaft (Dauer 0) und versteckt sein.
##
## Wahl-Reihen (TalentRowData.Kind.CHOICE) haben immer genau einen Rang.

## Feste ID, unter der Charaktere ihre Ränge speichern; im ganzen Baum
## eindeutig, nie ändern.
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Icon; leer = Platzhalter (Kürzel aus dem Namen).
@export var icon: Texture2D
## Ränge 1–3 (bei Wahl-Talenten wird immer 1 verwendet).
@export_range(1, 3) var max_ranks := 1
## Voraussetzung: ID eines Talents im selben Baum, das voll gelernt sein muss
## (leer = keine). Im Fenster als Pfeil gezeichnet.
@export var requires: StringName = &""

@export_group("Wirkung")
@export var grants_abilities: Array[AbilityData] = []
@export var effects: Array[EffectData] = []
@export var auras: Array[AuraData] = []


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
