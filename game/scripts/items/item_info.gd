class_name ItemInfo
extends RefCounted
## Angaben zu einem Gegenstand (Ticket #18), gelesen aus gegenstaende.csv über
## den Autoload „Data“. Das Inventar speichert nur ID und Anzahl; alles andere
## (Name, Typ, Seltenheit, Stapelgröße, Verkaufswert, Taschenplätze) kommt von
## hier, damit sich Daten ändern können, ohne gespeicherte Charaktere
## umzubauen.
##
## Seltenheit und Typ verweisen auf seltenheiten.csv bzw. gegenstandstypen.csv
## (Name, Reihenfolge). Die Farbe einer Seltenheit steht nur im Theme
## (Theme-Typ „RarityColors“, Farbname aus der Spalte „farbe“, Token
## rarity/<farbe>); vorläufige Platzhalter, siehe UI-Styleguide.

## Typ-ID, an der das Inventar Taschen erkennt.
const BAG_TYPE := &"tasche"
const RARITY_THEME_TYPE := &"RarityColors"
const COPPER_PER_SILVER := 100
const COPPER_PER_GOLD := 10000


static func row(id: StringName) -> TableRow:
	if id == &"":
		return null
	return Data.gegenstand(id)


static func exists(id: StringName) -> bool:
	return row(id) != null


static func display_name(id: StringName) -> String:
	var r := row(id)
	return str(r.get_value("name", id)) if r != null else String(id)


static func description(id: StringName) -> String:
	var r := row(id)
	return str(r.get_value("beschreibung", "")) if r != null else ""


## Größte Anzahl auf einem Platz (mindestens 1).
static func stack_size(id: StringName) -> int:
	var r := row(id)
	return maxi(1, int(r.get_value("stapelgroesse", 1))) if r != null else 1


static func type_id(id: StringName) -> StringName:
	var r := row(id)
	return StringName(str(r.get_value("typ", ""))) if r != null else &""


static func is_bag(id: StringName) -> bool:
	return type_id(id) == BAG_TYPE


## Plätze einer Tasche (0 bei anderen Gegenständen).
static func bag_slots(id: StringName) -> int:
	var r := row(id)
	if r == null or not is_bag(id):
		return 0
	return maxi(0, int(r.get_value("taschenplaetze", 0)))


## Verkaufswert eines Stücks in Kupfer.
static func sell_value(id: StringName) -> int:
	var r := row(id)
	return maxi(0, int(r.get_value("verkaufswert", 0))) if r != null else 0


static func type_name(id: StringName) -> String:
	var t := Data.gegenstandstyp(type_id(id))
	return str(t.get_value("name", type_id(id))) if t != null else String(type_id(id))


## Reihenfolge des Typs beim Sortieren (kleiner = weiter vorn).
static func type_order(id: StringName) -> int:
	var t := Data.gegenstandstyp(type_id(id))
	return int(t.get_value("reihenfolge", 0)) if t != null else 0


static func rarity_id(id: StringName) -> StringName:
	var r := row(id)
	return StringName(str(r.get_value("seltenheit", ""))) if r != null else &""


static func rarity_name(id: StringName) -> String:
	var s := Data.seltenheit(rarity_id(id))
	return str(s.get_value("name", rarity_id(id))) if s != null else String(rarity_id(id))


## Rang der Seltenheit (größer = seltener).
static func rarity_order(id: StringName) -> int:
	var s := Data.seltenheit(rarity_id(id))
	return int(s.get_value("reihenfolge", 0)) if s != null else 0


## true, wenn der Platz einen Rahmen in der Seltenheitsfarbe bekommt
## (laut Ticket ab Ungewöhnlich; Spalte „rahmen“ in seltenheiten.csv).
static func has_rarity_frame(id: StringName) -> bool:
	var s := Data.seltenheit(rarity_id(id))
	return s != null and bool(s.get_value("rahmen", false))


## Farbe der Seltenheit aus dem Theme (RarityColors); ohne Eintrag die
## normale Schriftfarbe.
static func rarity_color(id: StringName) -> Color:
	var s := Data.seltenheit(rarity_id(id))
	var key := StringName(str(s.get_value("farbe", ""))) if s != null else &""
	var theme := ThemeDB.get_project_theme()
	if theme != null and key != &"" and theme.has_color(key, RARITY_THEME_TYPE):
		return theme.get_color(key, RARITY_THEME_TYPE)
	if theme != null and theme.has_color(&"font_color", &"Label"):
		return theme.get_color(&"font_color", &"Label")
	return ThemeDB.get_default_theme().get_color(&"font_color", &"Label")


## Icon aus der Spalte „icon“ oder game/assets/ui/icons/items/<id>.png;
## null = Kürzel als Platzhalter.
static func icon(id: StringName) -> Texture2D:
	var r := row(id)
	if r == null:
		return null
	var path := str(r.get_value("icon", ""))
	if path == "":
		path = "res://assets/ui/icons/items/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Kürzel für Platzhalter-Icons: Anfangsbuchstaben der ersten beiden Wörter
## bzw. die ersten beiden Buchstaben („Lederbeutel“ → „Le“, „Hartes Brot“ → „HB“).
static func short_name(id: StringName) -> String:
	var words := display_name(id).split(" ", false)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].left(2)
	return (words[0].left(1) + words[1].left(1)).to_upper()


# --- Ausrüstung (#29) --------------------------------------------------------

const EQUIPMENT_TYPE := &"ausruestung"
const BINDING_TEXTS := {
	"beim_aufheben": "Wird beim Aufheben gebunden",
	"beim_anlegen": "Wird beim Anlegen gebunden",
}


static func is_equipment(id: StringName) -> bool:
	return type_id(id) == EQUIPMENT_TYPE


static func _text(id: StringName, column: String) -> String:
	var r := row(id)
	return str(r.get_value(column, "")) if r != null else ""


## Gegenstandsart (Spalte slot, z. B. &"einhand", &"ring").
static func slot(id: StringName) -> StringName:
	return StringName(_text(id, "slot"))


## Handhabung (haupthand, nebenhand, einhand, zweihand, fernkampf) oder &"".
static func handling(id: StringName) -> StringName:
	return StringName(_text(id, "handhabung"))


static func weapon_type(id: StringName) -> StringName:
	return StringName(_text(id, "waffentyp"))


static func armor_class(id: StringName) -> StringName:
	return StringName(_text(id, "ruestungsklasse"))


static func item_level(id: StringName) -> int:
	var r := row(id)
	return maxi(1, int(r.get_value("gegenstandsstufe", 1))) if r != null else 1


static func required_level(id: StringName) -> int:
	var r := row(id)
	return maxi(1, int(r.get_value("mindeststufe", 1))) if r != null else 1


## Klassen, die den Gegenstand nutzen dürfen (leer = alle).
static func class_ids(id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var r := row(id)
	if r != null:
		for entry: Variant in r.get_value("klassen", []):
			result.append(StringName(str(entry)))
	return result


## „Einzigartig“: nur einmal im Besitz (Tasche und angelegt zusammen).
static func is_unique(id: StringName) -> bool:
	var r := row(id)
	return r != null and bool(r.get_value("einzigartig", false))


## „Einzigartig angelegt“: Spalte oder Slot (Siegel, Talisman: immer).
static func is_unique_equipped(id: StringName) -> bool:
	var r := row(id)
	if r == null:
		return false
	if bool(r.get_value("einzigartig_angelegt", false)):
		return true
	var mapping := slot_mapping(id)
	return mapping != null and bool(mapping.get_value("immer_einzigartig_angelegt", false))


## Zeile aus slotzuordnung.csv oder null.
static func slot_mapping(id: StringName) -> TableRow:
	if not is_equipment(id):
		return null
	return Data.slotzuordnung(slot(id), handling(id))


## Bindungstext für den Tooltip („Wird beim Anlegen gebunden“) oder "".
static func binding_text(id: StringName) -> String:
	return BINDING_TEXTS.get(_text(id, "bindung"), "")


## Herkunftstext (Goldschrift im Tooltip) oder "".
static func origin(id: StringName) -> String:
	return _text(id, "herkunft")


## Text links im Tooltip (z. B. „Brust“, „Zweihand“).
static func slot_text(id: StringName) -> String:
	var mapping := slot_mapping(id)
	return str(mapping.get_value("anzeige", "")) if mapping != null else ""


## Text rechts im Tooltip: Waffentyp bzw. Rüstungsklasse („Schwert“, „Platte“).
static func kind_text(id: StringName) -> String:
	var weapon := Data.waffentyp(weapon_type(id)) if weapon_type(id) != &"" else null
	if weapon != null:
		return str(weapon.get_value("name", weapon_type(id)))
	var armor := Data.ruestungsklasse(armor_class(id)) if armor_class(id) != &"" else null
	return str(armor.get_value("name", armor_class(id))) if armor != null else ""


## Zahl einer Wertespalte (z. B. „staerke“, „ruestung“); leer = 0.
static func number(id: StringName, column: String) -> int:
	var r := row(id)
	return int(r.get_value(column, 0)) if r != null else 0


## true für Waffen mit Waffenschaden (nicht Schild und Fokus).
static func is_damage_weapon(id: StringName) -> bool:
	var weapon := Data.waffentyp(weapon_type(id)) if weapon_type(id) != &"" else null
	return weapon != null and str(weapon.get_value("handhabung", "")) != "nebenhand"


## Sekunden je Schlag (Gegenstand, sonst standardtempo des Waffentyps).
static func weapon_speed(id: StringName) -> float:
	var r := row(id)
	if r != null and not r.is_blank("geschwindigkeit") and float(r.get_value("geschwindigkeit", 0.0)) > 0.0:
		return float(r.get_value("geschwindigkeit", 0.0))
	var weapon := Data.waffentyp(weapon_type(id)) if weapon_type(id) != &"" else null
	return maxf(0.1, float(weapon.get_value("standardtempo", 2.0))) if weapon != null else 2.0


## Reichweite für automatische Schüsse (0 = Nahkampf).
static func weapon_range(id: StringName) -> float:
	var weapon := Data.waffentyp(weapon_type(id)) if weapon_type(id) != &"" else null
	return float(weapon.get_value("reichweite", 0.0)) if weapon != null else 0.0


## Schaden pro Sekunde aus Schaden und Geschwindigkeit.
static func dps(id: StringName) -> float:
	if not is_damage_weapon(id):
		return 0.0
	return (number(id, "schaden_min") + number(id, "schaden_max")) / 2.0 / weapon_speed(id)


## Auren aus der Spalte „effekte“ (unbekannte entfallen).
static func effect_auras(id: StringName) -> Array[AuraData]:
	var result: Array[AuraData] = []
	var r := row(id)
	if r == null:
		return result
	for aura_id: Variant in r.get_value("effekte", []):
		var aura := GameData.get_aura(StringName(str(aura_id)))
		if aura != null:
			result.append(aura)
	return result


## Gold, Silber und Kupfer eines Betrags in Kupfer.
static func money_parts(copper: int) -> Vector3i:
	var value := maxi(0, copper)
	@warning_ignore("integer_division")
	var gold := value / COPPER_PER_GOLD
	@warning_ignore("integer_division")
	var silver := (value % COPPER_PER_GOLD) / COPPER_PER_SILVER
	return Vector3i(gold, silver, value % COPPER_PER_SILVER)


## Betrag als Text, z. B. „1 Gold 5 Silber 20 Kupfer“; Nullen entfallen
## (0 = „0 Kupfer“).
static func money_text(copper: int) -> String:
	var parts := money_parts(copper)
	var words: PackedStringArray = []
	if parts.x > 0:
		words.append("%s Gold" % StatFormat.grouped(parts.x))
	if parts.y > 0:
		words.append("%d Silber" % parts.y)
	if parts.z > 0 or words.is_empty():
		words.append("%d Kupfer" % parts.z)
	return " ".join(words)
