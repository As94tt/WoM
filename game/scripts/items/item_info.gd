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
