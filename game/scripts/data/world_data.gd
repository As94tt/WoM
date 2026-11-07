class_name WorldData
extends Resource
## Grundwerte einer Spielwelt als Daten (Ticket #15): Größe, Ränder und die
## Graubox-Farben, die nicht zu einem Gebiet gehören (Berge, Wege).
## Datensatz der Startwelt: res://data/world/startwelt.tres.
## Alle Längen in Metern; die Welt liegt mittig um den Ursprung.

## Halbe Kantenlänge der Karte (300 = 600 × 600 m). Diesen Ausschnitt zeigt
## das Kartenfenster.
@export var map_half_extent: float = 300.0
## Ab diesem Abstand von der Mitte (größte Achse) steigt das Gelände zum Gebirge an.
@export var playable_half_extent: float = 280.0
## Halbe Kantenlänge des erzeugten Geländes (über den Kartenrand hinaus,
## damit man vom Rand aus keine Kante sieht).
@export var terrain_half_extent: float = 340.0
## Höhe, auf die das Gelände am Rand ansteigt.
@export var border_height: float = 35.0
## Breite des Anstiegs am Rand.
@export var border_width: float = 40.0
## Rasterweite des Geländes. Kleiner = feiner, aber mehr Dreiecke.
@export var terrain_cell_size: float = 4.0
## Breite des Übergangs, in dem ebene Gebiete (Dorf, Lager …) in Hügel übergehen.
@export var flatten_margin: float = 25.0
## Graubox-Farbe für Gelände außerhalb aller Gebiete.
@export var fallback_ground_color: Color = Color(0.5, 0.5, 0.5)
## Graubox-Farbe der Berghänge am Rand.
@export var mountain_ground_color: Color = Color(0.42, 0.42, 0.42)
## Graubox-Farbe der Wege.
@export var path_color: Color = Color(0.7, 0.66, 0.58)
