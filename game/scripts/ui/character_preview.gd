class_name CharacterPreview
extends SubViewportContainer
## Platzhaltermodell eines Charakters (Ticket #6, wiederverwendbar für #8).
## Graubox: Kapsel, gleichmäßig mit RaceData.height_factor skaliert, Name
## darüber. Linke Maustaste ziehen dreht das Modell um die Hochachse.
## Rein lokal, eigene 3D-Welt in der SubViewport, nichts wird synchronisiert.

## Grundhöhe der Kapsel bei height_factor 1,0 (muss zur CapsuleMesh passen).
const BASE_HEIGHT := 1.8
## Abstand des Namens über dem Kopf in Metern.
const NAME_OFFSET := 0.25
## Drehung pro Pixel Mausbewegung (Bogenmaß).
const ROTATE_SPEED := 0.01

@onready var _model: Node3D = %Model
@onready var _name_label: Label3D = %NameLabel

var _dragging := false


func _ready() -> void:
	clear()


## Zeigt einen gespeicherten Charakter. Unbekanntes Volk: Größe 1,0.
func show_character(c: CharacterData) -> void:
	if c == null:
		clear()
		return
	show_appearance(c.get_race(), c.gender, c.character_name)


## Zeigt ein Modell aus Volk, Geschlecht und Name (z. B. während der
## Charaktererstellung, bevor gespeichert wird). Das Geschlecht ändert am
## Platzhalter nichts; es ist für echte Modelle vorgesehen.
func show_appearance(race: RaceData, _gender: CharacterData.Gender, display_name: String) -> void:
	var factor := race.height_factor if race != null else 1.0
	_model.scale = Vector3.ONE * factor
	_model.rotation = Vector3.ZERO
	_model.visible = true
	_name_label.text = display_name
	_name_label.position.y = BASE_HEIGHT * factor + NAME_OFFSET
	_name_label.visible = not display_name.is_empty()


## Blendet Modell und Namen aus.
func clear() -> void:
	_model.visible = false
	_name_label.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_model.rotate_y(event.relative.x * ROTATE_SPEED)
		accept_event()
