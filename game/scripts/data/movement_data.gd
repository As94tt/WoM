class_name MovementData
extends Resource
## Bewegungswerte einer Spielfigur als Daten (Ticket #16). Der Standardsatz
## liegt in res://data/movement/player_movement.tres. Auren wie Verlangsamung
## oder Sprint (#32) ändern nicht diese Daten, sondern den Faktor
## PlayerCharacter.speed_multiplier der einzelnen Figur.

## Vorwärts laufen und seitwärts gehen, in m/s.
@export var run_speed: float = 7.0
## Rückwärts laufen (auch schräg rückwärts), in m/s.
@export var backward_speed: float = 4.5
## Gehen: Obergrenze für alle Richtungen, solange Gehen eingeschaltet ist, in m/s.
@export var walk_speed: float = 2.5
## Feste Sprunghöhe in Metern. Die Absprunggeschwindigkeit wird daraus und
## aus der Schwerkraft berechnet.
@export var jump_height: float = 1.2
## Schwerkraft in m/s².
@export var gravity: float = 20.0
## Drehgeschwindigkeit mit A/D in Grad pro Sekunde.
@export var turn_speed_deg: float = 180.0
## Steilster Hang in Grad, den man hochlaufen kann; steilere rutscht man ab.
@export var max_slope_deg: float = 50.0
## Höchste Stufe in Metern, die automatisch überstiegen wird.
@export var step_height: float = 0.4
