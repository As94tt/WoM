class_name RaceData
extends RefCounted
## Ein spielbares Volk (Ticket #6). Seit #39 stehen die Völker in der Tabelle
## res://data/tables/voelker.csv; der Autoload „Data“ erzeugt daraus diese
## Objekte. Zugriff über GameData.get_races() / GameData.get_race(id).

## Körperfamilien laut GDD. Für Rig, Animationen und Ausrüstung zählt die
## Körperfamilie, nicht das Volk.
enum BodyFamily { NORMAL, COMPACT, MASSIVE, HUNCHED }

## Werte der Spalte „koerperfamilie“ (Auswahl im Schema voelker.tres).
const BODY_FAMILY_IDS: Dictionary[String, BodyFamily] = {
	"normal": BodyFamily.NORMAL,
	"kompakt": BodyFamily.COMPACT,
	"massiv": BodyFamily.MASSIVE,
	"gross_gebeugt": BodyFamily.HUNCHED,
}

## Feste ID, unter der Charaktere das Volk speichern (z. B. &"human").
var id: StringName
## Anzeigename (z. B. „Mensch“).
var display_name: String
## Kurzbeschreibung für die Charaktererstellung (#8). Platzhaltertext nach GDD.
var description: String
var body_family: BodyFamily = BodyFamily.NORMAL
## Größenfaktor des Platzhaltermodells (Mensch = 1,0). Gilt für beide Geschlechter.
var height_factor: float = 1.0
## Reihenfolge in Listen (GDD-Reihenfolge der Völker).
var order: int = 0
## Volksboni auf die Attribute (Platzhalter); StatBlock (#19) liest sie aus voelker.csv.
var strength: int = 0
var agility: int = 0
var intellect: int = 0
var stamina: int = 0
var willpower: int = 0
## ID der Volksfähigkeit (dauerhafte Aura, #32); leer = keine.
var racial_aura: StringName = &""


## Erzeugt das Volk aus einer geprüften Zeile von voelker.csv.
static func from_row(row: TableRow) -> RaceData:
	var race := RaceData.new()
	race.id = StringName(row.get_value("id", ""))
	race.display_name = row.get_value("name", "")
	race.description = row.get_value("beschreibung", "")
	race.body_family = BODY_FAMILY_IDS.get(row.get_value("koerperfamilie", ""), BodyFamily.NORMAL)
	race.height_factor = row.get_value("groessenfaktor", 1.0)
	race.order = row.get_value("reihenfolge", 0)
	race.strength = row.get_value("staerke", 0)
	race.agility = row.get_value("gewandtheit", 0)
	race.intellect = row.get_value("intellekt", 0)
	race.stamina = row.get_value("ausdauer", 0)
	race.willpower = row.get_value("willenskraft", 0)
	race.racial_aura = StringName(row.get_value("volksfaehigkeit", ""))
	return race
