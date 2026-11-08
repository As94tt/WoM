class_name AbilityData
extends Resource
## Eine Fähigkeit als Daten (Ticket #21). Die Datensätze liegen in
## res://data/abilities/ und werden über GameData geladen (get_ability).
##
## Aufteilung (Entscheidung zu #21, siehe docs/DATENTABELLEN.md):
## - Die .tres beschreibt die Fähigkeit: Name, Beschreibung, Icon, Klasse,
##   benötigte Stufe, aktiv/passiv. Später kommt hier der Aufbau dazu.
## - Die Zahlen (Kosten, Zauberzeit, Abklingzeit, Reichweite, Grundwert …)
##   stehen in faehigkeitswerte.csv (Zeile mit derselben id) und werden über
##   Data.faehigkeitswert() gelesen. Zu jeder .tres muss es dort eine Zeile
##   geben; die Datenprüfung meldet sonst einen Fehler.
##
## Erweiterung ohne Umbau (#32/#33): Effekte (Liste von Effekt-Ressourcen),
## Zielbestimmung, Bedingungen usw. kommen als zusätzliche @export-Felder in
## eigenen Gruppen dazu; bestehende .tres bleiben gültig, weil fehlende Felder
## ihren Standardwert bekommen. Zauberart, Abklingzeit, Aufladungen, Dauer und
## Tick liefern die Funktionen unten bereits aus der Tabelle. Ausgelöst wird
## eine Fähigkeit nur über PlayerAbilities.use_ability() (später über den Host).

## Ressourcen der Tabelle (Spalte „ressource“) → Ressourcen-ID des
## Wertesystems (CharacterStats.RESOURCE_IDS).
const RESOURCE_IDS := {
	"mana": &"mana",
	"wut": &"rage",
	"energie": &"energy",
	"chi": &"chi",
}

enum CastType { INSTANT, CAST, CHANNELED }

## Feste ID (z. B. &"feuerball"); gleich der id in faehigkeitswerte.csv. Wird
## in gespeicherten Aktionsleisten verwendet und nie geändert.
@export var id: StringName
## Anzeigename (Platzhalter nach GDD).
@export var display_name: String
## Beschreibung im Tooltip.
@export_multiline var description: String
## Icon; leer = Platzhalter (Kürzel aus dem Namen, siehe get_short_name).
@export var icon: Texture2D
## Klasse (ClassData.id); leer = „Allgemein“ (für alle Klassen).
@export var class_id: StringName = &""
## Stufe, ab der die Fähigkeit erlernt ist.
@export_range(1, 100) var required_level: int = 1
## Passive Fähigkeiten stehen im Zauberbuch, lassen sich aber nicht auf die
## Aktionsleisten ziehen und nicht auslösen (später: dauerhafte Aura, #32).
@export var passive := false


## true für „Allgemein“ (keine Klasse).
func is_general() -> bool:
	return class_id == &""


## Kürzel für das Platzhalter-Icon: Anfangsbuchstaben der ersten zwei Wörter
## („Heilende Berührung“ → „HB“) bzw. die ersten zwei Buchstaben eines
## einzelnen Worts („Feuerball“ → „Fe“).
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


# --- Zahlen aus faehigkeitswerte.csv -----------------------------------------

## Ein Wert aus faehigkeitswerte.csv (Spaltenname oder „werte.<schlüssel>“).
func get_value(key: String, fallback: Variant = null) -> Variant:
	return Data.faehigkeitswert(id, key, fallback)


## Kosten in Einheiten der Ressource (0 = keine Kosten).
func get_cost() -> float:
	return _number("kosten")


## Ressourcen-ID der Kosten (&"mana", &"rage", …) oder &"" ohne Kosten.
func get_cost_resource() -> StringName:
	return RESOURCE_IDS.get(str(get_value("ressource", "keine")), &"")


## Zauberzeit in Sekunden (0 = sofort).
func get_cast_time() -> float:
	return _number("zauberzeit")


## Kanalisierzeit in Sekunden (0 = nicht kanalisiert).
func get_channel_time() -> float:
	return _number("kanalisierzeit")


func get_cast_type() -> CastType:
	if get_channel_time() > 0.0:
		return CastType.CHANNELED
	if get_cast_time() > 0.0:
		return CastType.CAST
	return CastType.INSTANT


## Abklingzeit in Sekunden (0 = keine).
func get_cooldown() -> float:
	return _number("abklingzeit")


## Reichweite in Metern (0 = Nahkampf bzw. selbst).
func get_range() -> float:
	return _number("reichweite")


func _number(key: String) -> float:
	var value: Variant = get_value(key, 0.0)
	return float(value) if value is float or value is int else 0.0
