class_name CharacterModelData
extends Resource
## Modell einer Spielfigur als Daten (Ticket #59): eine Modellszene (GLB mit
## Skeleton3D, beim Import per BoneMap auf SkeletonProfileHumanoid abgebildet)
## plus die Grundanimationen, die sie abspielt. Fehlt das Modell, zeigt die
## Spielfigur die Graubox-Kapsel.
##
## Ein Modell wird nie verzerrt, nur gleichmäßig skaliert. Die Kollision
## bleibt die Kapsel der Spielfigur (1,80 m); Volksgrößen sind ein eigenes
## Ticket.

## Modellszene mit Skeleton3D (Profil-Knochennamen, eindeutiger Name
## „GeneralSkeleton“ durch den Import).
@export var scene: PackedScene
## Grundanimationen (Stehen, Gehen, Laufen, Springen, Landen).
@export var animations: CharacterAnimationSet = preload("res://data/animations/grundanimationen.tres")
## Drehung des Modells um die Hochachse in Grad. glTF-Modelle blicken nach +Z,
## die Spielfigur nach -Z; daher standardmäßig 180.
@export var yaw_offset_deg: float = 180.0
## Gleichmäßiger Größenfaktor des Modells.
@export var model_scale: float = 1.0
