class_name CharacterAnimationSet
extends Resource
## Grundanimationen einer Spielfigur als Daten (Ticket #59): welche Clips aus
## welcher AnimationLibrary für Stehen, Gehen, Laufen, Springen, Fallen und
## Landen gelten und wie schnell sie abgespielt werden.
##
## Die Library ist beim Import per BoneMap auf SkeletonProfileHumanoid
## abgebildet (Spuren „%GeneralSkeleton:Hips“ usw.). Sie passt deshalb auf
## jedes Modell, dessen Skelett ebenfalls mit einer Profil-BoneMap importiert
## ist – ohne Neuanimieren pro Volk. Der Standardsatz liegt in
## res://data/animations/grundanimationen.tres.
##
## Geschwindigkeiten stehen in Hüfthöhen pro Sekunde, damit sie für große und
## kleine Modelle gleichermaßen stimmen: Ein Modell mit doppelter Hüfthöhe
## macht doppelt so lange Schritte. Die Hüfthöhe misst CharacterAnimator an
## der Ruhepose des Modells.

@export var library: AnimationLibrary

@export_group("Clips")
@export var idle: StringName = &"Idle"
@export var walk: StringName = &"Walk"
@export var run: StringName = &"Jog_Fwd"
@export var sprint: StringName = &"Sprint"
@export var jump_start: StringName = &"Jump_Start"
## Schleife in der Luft (Fallen und zweite Sprunghälfte).
@export var jump_air: StringName = &"Jump"
@export var land: StringName = &"Jump_Land"

@export_group("Tempo")
## Geschwindigkeit, zu der der Gehen-Clip ohne Beschleunigung passt, in
## Hüfthöhen pro Sekunde (gemessen an der Root-Motion-Fassung der Library).
@export var walk_reference_speed: float = 1.06
## Wie walk_reference_speed, für den Laufen-Clip.
@export var run_reference_speed: float = 5.85
## Wie walk_reference_speed, für den Sprint-Clip.
@export var sprint_reference_speed: float = 9.0
## Ab dieser Geschwindigkeit (Hüfthöhen pro Sekunde) sprintet die Figur statt
## zu laufen, z. B. mit Eile.
@export var sprint_threshold: float = 8.0
## Kleinster und größter Abspielfaktor; außerhalb rutschen die Füße lieber
## etwas, statt dass die Bewegung in Zeitlupe oder Zeitraffer läuft.
@export var min_time_scale: float = 0.5
@export var max_time_scale: float = 2.5
## Unter dieser Geschwindigkeit (m/s) gilt die Figur als stehend.
@export var standing_speed: float = 0.2

@export_group("Übergänge")
## Überblendzeit zwischen zwei Animationen in Sekunden.
@export var blend_time: float = 0.18
## Kürzere Luftzeiten (z. B. Stufe hinunter) spielen keine Landung.
@export var min_air_time: float = 0.25
## So lange (Sekunden) muss die Figur ohne Sprung in der Luft sein, bevor die
## Fall-Animation beginnt.
@export var fall_delay: float = 0.12
## So lange läuft die Landung, wenn die Figur danach steht (Sekunden).
@export var land_time_standing: float = 0.7
## So lange läuft die Landung, wenn die Figur gleich weiterläuft (Sekunden).
@export var land_time_moving: float = 0.2
## Nach dieser Zeit im Absprung wechselt die Figur in die Luftschleife.
@export var jump_start_time: float = 0.9

@export_group("Richtung")
## Wie schnell sich das Modell zur Laufrichtung dreht (seitwärts/schräg),
## in Bogenmaß pro Sekunde (Annäherung, kein festes Tempo).
@export var facing_turn_rate: float = 12.0
