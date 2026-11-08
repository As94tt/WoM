class_name MovementCheckData
extends Resource
## Grenzwerte der groben Bewegungsprüfung des Hosts (Ticket #30). Der
## Standardsatz liegt in res://data/network/movement_check.tres.
##
## Erlaubt ist die höchste Laufgeschwindigkeit der Figur (MovementData mal
## PlayerCharacter.speed_multiplier, damit später auch Auren wie Sprint
## zählen) mal speed_factor, dazu Sprung- und Fallbewegung. Was darüber
## hinausgeht, setzt der Host auf die letzte gültige Position zurück.

## Faktor auf die höchste erlaubte Geschwindigkeit (Spielraum für Ruckler).
@export var speed_factor: float = 1.5
## Weiter als so viele Meter darf sich eine Figur zwischen zwei Meldungen nie
## bewegen (Teleport), egal wie viel Zeit vergangen ist.
@export var teleport_threshold_m: float = 15.0
## Fester Spielraum je Meldung in Metern (Rundung, Stufen, Kollision).
@export var tolerance_m: float = 0.5
## Ein vom Host befohlener Teleport (Entwickler-Panel, Wiedereinstieg) gilt
## als ausgeführt, wenn die Figur höchstens so weit vom Ziel entfernt
## ankommt, in Metern.
@export var teleport_arrival_m: float = 3.0
