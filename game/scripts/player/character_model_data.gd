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

## Ablage der Volksmodelle: <Ordner><Volks-ID>.tres, z. B. troll.tres.
## Lokale Testmodelle (nur auf diesem PC, über .git/info/exclude ignoriert,
## nie im Repo) gehen echten Modellen aus den Daten vor.
const LOCAL_RACE_FOLDER := "res://lokal/modelle/"
const RACE_FOLDER := "res://data/modelle/"


## Mögliche Dateien für das Modell eines Volks, in Prüfreihenfolge.
static func race_model_paths(race_id: StringName) -> PackedStringArray:
	if race_id == &"":
		return PackedStringArray()
	return PackedStringArray([LOCAL_RACE_FOLDER + race_id + ".tres", RACE_FOLDER + race_id + ".tres"])


## Modell eines Volks oder null (= Kapsel). Volksmodelle sind Daten mit
## fester Ablage statt einer Spalte in voelker.csv, weil lokale Testmodelle
## auf anderen Rechnern fehlen und die Datenprüfung dort sonst fehlschlüge.
static func for_race(race_id: StringName) -> CharacterModelData:
	for path in race_model_paths(race_id):
		if not ResourceLoader.exists(path):
			continue
		var model := load(path) as CharacterModelData
		if model != null:
			return model
		push_warning("Volksmodell: „%s“ ist kein CharacterModelData, wird übersprungen." % path)
	return null
