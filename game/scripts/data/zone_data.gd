class_name ZoneData
extends Resource
## Ein Gebiet der Spielwelt als Daten (Ticket #15). Die Datensätze liegen in
## res://data/zones/ und werden von der Unterszene des Gebiets (WorldZone)
## verwendet. Ob und wie Gebiete später in Tabellen wandern, klärt #39.

## Feste ID (z. B. &"banditenlager"), z. B. für Gebietsbeute oder Quests.
@export var id: StringName
## Anzeigename (z. B. „Banditenlager“), für Gebietsnamen-Einblendung und Karte.
@export var display_name: String
## Niedrigste Gegnerstufe im Gebiet. 0 = Gebiet ohne Stufenbereich (Dorf).
@export var level_min: int = 0
## Höchste Gegnerstufe im Gebiet.
@export var level_max: int = 0
## Graubox-Bodenfarbe, damit man sich ohne echte Grafik orientieren kann.
## Spielwelt-Farbe, keine UI-Farbe (siehe GAME-STYLEGUIDE).
@export var ground_color: Color = Color(0.5, 0.5, 0.5)
## Reihenfolge in Listen (z. B. Teleport im Entwickler-Panel).
@export var order: int = 0


## Stufenbereich als Text, z. B. „Stufe 4–6“ oder „Stufe 10“; leer, wenn das
## Gebiet keinen Stufenbereich hat.
func get_level_text() -> String:
	if level_min <= 0:
		return ""
	if level_max <= level_min:
		return "Stufe %d" % level_min
	return "Stufe %d–%d" % [level_min, level_max]
