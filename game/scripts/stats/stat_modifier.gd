class_name StatModifier
extends RefCounted
## Ein Modifikator auf einen Wert (Ticket #19), fest oder prozentual. Jeder
## Modifikator kennt seine Quelle, damit er gezielt wieder entfernt werden
## kann (StatBlock.remove_source). Gedacht für Ausrüstung (#29), Auren (#32),
## Talente und das Entwickler-Panel.
##
## Quelle: eine eindeutige ID nach dem Muster „art:id“, z. B.
## &"item:schwert_rostig", &"aura:segen_der_kraft", &"dev:staerke".
## Mehrere Modifikatoren dürfen dieselbe Quelle haben (ein Gegenstand gibt
## Stärke und Ausdauer); remove_source entfernt dann alle.
##
## Rechnung je Wert: (Grundwert + Summe FLAT) × (1 + Summe PERCENT / 100),
## danach die Obergrenze.

enum Kind { FLAT, PERCENT }

## Eindeutige Quelle, z. B. &"item:schwert_rostig".
var source: StringName
## Anzeigename der Quelle für den Tooltip, z. B. „Rostiges Schwert“.
var source_name: String
## ID des Werts (StatDefinition.id), z. B. &"strength".
var stat: StringName
var kind: Kind = Kind.FLAT
## Fest: Punkte (bzw. Prozentpunkte bei Prozentwerten); prozentual: Prozent
## des Werts. Negativ = Malus.
var value: float = 0.0


static func create(p_source: StringName, p_source_name: String, p_stat: StringName,
		p_value: float, p_kind := Kind.FLAT) -> StatModifier:
	var m := StatModifier.new()
	m.source = p_source
	m.source_name = p_source_name
	m.stat = p_stat
	m.value = p_value
	m.kind = p_kind
	return m


## Für die Übertragung im Netzwerk (nur einfache Typen).
func to_array() -> Array:
	return [String(source), source_name, String(stat), int(kind), value]


static func from_array(data: Array) -> StatModifier:
	if data.size() < 5:
		return null
	return create(StringName(str(data[0])), str(data[1]), StringName(str(data[2])),
			float(data[4]), clampi(int(data[3]), Kind.FLAT, Kind.PERCENT) as Kind)
