class_name CameraSettings
extends Resource
## Einstellungen der Verfolgerkamera als Daten (Ticket #16). Der Standardsatz
## liegt in res://data/camera/player_camera.tres. Mausempfindlichkeit und
## Zoom können später im Optionsmenü verändert werden.

## Drehung pro Pixel Mausbewegung, in Grad.
@export var mouse_sensitivity_deg: float = 0.25
## Höhe des Blickpunkts über den Füßen der Figur, in Metern.
@export var target_height: float = 1.6
## Kleinster Abstand zur Figur (Nahansicht), in Metern.
@export var min_distance: float = 1.5
## Größter Abstand zur Figur, in Metern.
@export var max_distance: float = 15.0
## Abstand beim Start, in Metern.
@export var start_distance: float = 6.0
## Änderung des Abstands pro Mausrad-Raste, in Metern.
@export var zoom_step: float = 1.0
## Wie schnell der Zoom dem Mausrad folgt (größer = schneller).
@export var zoom_smoothing: float = 10.0
## Kamerawinkel nach unten (negativ = Kamera über der Figur, Blick nach unten), in Grad.
@export var min_pitch_deg: float = -80.0
## Kamerawinkel nach oben (positiv = Kamera unter dem Blickpunkt, Blick nach oben), in Grad.
@export var max_pitch_deg: float = 60.0
## Kamerawinkel beim Start: leicht erhöht hinter der Figur, in Grad.
@export var start_pitch_deg: float = -20.0
## Wie schnell die Kamera hinter die Figur zurückschwenkt (größer = schneller).
@export var return_speed: float = 8.0
