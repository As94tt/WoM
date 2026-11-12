class_name CharacterPreview
extends SubViewportContainer
## Platzhaltermodell eines Charakters (Ticket #6, erweitert in #8).
## Graubox: Kapsel, gleichmäßig mit RaceData.height_factor skaliert, in der
## Klassenfarbe (ClassData.color), Name darüber. Linke Maustaste ziehen dreht
## das Modell um die Hochachse.
## Gibt es ein Modell für das Volk (CharacterModelData.for_race), steht statt
## der Kapsel dieses Modell in der Stehen-Animation; die Klassenfarbe gilt
## dann nicht (echte Modelle haben eigene Materialien).
## Rein lokal, eigene 3D-Welt in der SubViewport, nichts wird synchronisiert.

## Grundhöhe der Kapsel bei height_factor 1,0 (muss zur CapsuleMesh passen).
const BASE_HEIGHT := 1.8
## Abstand des Namens über dem Kopf in Metern.
const NAME_OFFSET := 0.25
## Drehung pro Pixel Mausbewegung (Bogenmaß).
const ROTATE_SPEED := 0.01

@onready var _model: Node3D = %Model
@onready var _body: MeshInstance3D = %Body
@onready var _facing: MeshInstance3D = %Model.get_node(^"Facing")
@onready var _name_label: Label3D = %NameLabel

## Echtes Volksmodell (oder null = Kapsel) und das Volk, für das es gilt.
var _race_model: Node3D = null
var _race_model_data: CharacterModelData = null
var _race_model_id: StringName = &"-"

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
	_show_race_model(race.id if race != null else &"", factor)
	_model.visible = true
	_name_label.text = display_name
	_name_label.position.y = BASE_HEIGHT * factor + NAME_OFFSET
	_name_label.visible = not display_name.is_empty()


## Setzt das Modell des Volks ein (nur bei Volkswechsel neu) oder zeigt die
## Kapsel. Das Modell bekommt seine eigene Größe: „Model“ trägt den
## Platzhalter-Größenfaktor, der hier wieder herausgerechnet wird.
func _show_race_model(race_id: StringName, factor: float) -> void:
	if race_id != _race_model_id:
		_race_model_id = race_id
		if _race_model != null:
			_race_model.queue_free()
			_race_model = null
		_race_model_data = CharacterModelData.for_race(race_id)
		if _race_model_data != null and _race_model_data.scene != null:
			_race_model = _build_race_model(_race_model_data)
	if _race_model != null:
		_race_model.scale = Vector3.ONE * (_race_model_data.model_scale / maxf(factor, 0.01))
	_body.visible = _race_model == null
	_facing.visible = _race_model == null


## Erzeugt das Modell unter „Model“ und spielt die Stehen-Animation in Schleife.
func _build_race_model(data: CharacterModelData) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "RaceModel"
	# Die Vorschau blickt zur Kamera (+Z), die Spielfigur nach -Z; yaw_offset_deg
	# ist für die Spielfigur angegeben.
	pivot.rotation.y = deg_to_rad(data.yaw_offset_deg - 180.0)
	var instance := data.scene.instantiate() as Node3D
	pivot.add_child(instance)
	_model.add_child(pivot)
	var anims := data.animations
	if anims != null and anims.library != null and anims.library.has_animation(anims.idle):
		var player := AnimationPlayer.new()
		pivot.add_child(player)
		player.root_node = player.get_path_to(instance)
		player.add_animation_library(&"", anims.library)
		var idle := anims.idle
		player.animation_finished.connect(func(_name: StringName) -> void: player.play(idle))
		player.play(idle)
	return pivot


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
