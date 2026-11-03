class_name CharacterPreview
extends SubViewportContainer
## Platzhaltermodell eines Charakters (Ticket #6, erweitert in #8).
## Graubox: Kapsel, gleichmäßig mit RaceData.height_factor skaliert, in der
## Klassenfarbe (ClassData.color), Name darüber. Linke Maustaste ziehen dreht
## das Modell um die Hochachse.
## Rein lokal, eigene 3D-Welt in der SubViewport, nichts wird synchronisiert.

## Grundhöhe der Kapsel bei height_factor 1,0 (muss zur CapsuleMesh passen).
const BASE_HEIGHT := 1.8
## Abstand des Namens über dem Kopf in Metern.
const NAME_OFFSET := 0.25
## Drehung pro Pixel Mausbewegung (Bogenmaß).
const ROTATE_SPEED := 0.01

@onready var _model: Node3D = %Model
@onready var _body: MeshInstance3D = %Body
@onready var _name_label: Label3D = %NameLabel

var _dragging := false
## Eigene Kopie des Körpermaterials, damit die Klassenfarbe nur diese
## Vorschau färbt und nicht die gemeinsame Ressource der Szene.
var _body_material: StandardMaterial3D
## Grau aus der Szene, falls keine Klasse bekannt ist.
var _neutral_color: Color


func _ready() -> void:
	_body_material = (_body.mesh as PrimitiveMesh).material.duplicate()
	_neutral_color = _body_material.albedo_color
	_body.material_override = _body_material
	clear()


## Zeigt einen gespeicherten Charakter, von vorn. Unbekanntes Volk: Größe 1,0;
## unbekannte Klasse: graue Kapsel.
func show_character(c: CharacterData) -> void:
	if c == null:
		clear()
		return
	_model.rotation = Vector3.ZERO
	show_appearance(c.get_race(), c.gender, c.character_name, c.get_class_data())


## Zeigt ein Modell aus Volk, Geschlecht, Name und Klasse (z. B. während der
## Charaktererstellung, bevor gespeichert wird). Die Drehung bleibt erhalten.
## Das Geschlecht ändert am Platzhalter nichts; es ist für echte Modelle
## vorgesehen. Ohne Klasse bleibt die Kapsel grau.
func show_appearance(race: RaceData, _gender: CharacterData.Gender, display_name: String,
		class_data: ClassData = null) -> void:
	var factor := race.height_factor if race != null else 1.0
	_model.scale = Vector3.ONE * factor
	# Klassenfarbe kommt aus den Daten (ClassData.color), siehe UI-Styleguide.
	_body_material.albedo_color = class_data.color if class_data != null else _neutral_color
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
