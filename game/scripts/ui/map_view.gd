class_name MapView
extends Control
## Inhalt des Kartenfensters (Ticket #15): Bild der Welt von oben
## (MapRenderer), darüber Gebietsnamen, Wiedereinstiegspunkte und die eigene
## Position als Pfeil in Blickrichtung. Norden (-Z) ist oben.
##
## Rein lokal: jeder Spieler sieht seine eigene Karte. Mitspieler (#30)
## erscheinen als Punkte in Klassenfarbe mit Namen als Tooltip; ihr Punkt
## verschwindet, sobald ihre Figur die Welt verlässt.

const MARKER_SCENE := preload("res://scenes/ui/hud/map_marker.tscn")

## Kartenausschnitt in Welt-XZ.
var world_rect := Rect2(-300, -300, 600, 600)

## Figur, deren Position der Pfeil zeigt (die eigene).
var _tracked: Node3D = null
## [Control, Welt-XZ] für alles, was beim Größenwechsel neu gesetzt wird.
var _placed: Array[Array] = []
var _player_marker: MapMarker = null
## Figur eines Mitspielers → sein Punkt.
var _mates: Dictionary[Node3D, MapMarker] = {}

@onready var _image: TextureRect = %MapImage
@onready var _overlay: Control = %Overlay
@onready var _no_image: Label = %NoImageLabel


func _ready() -> void:
	_overlay.resized.connect(_layout)
	_player_marker = MARKER_SCENE.instantiate()
	_player_marker.kind = MapMarker.Kind.PLAYER
	_player_marker.visible = false
	_overlay.add_child(_player_marker)
	set_map_texture(null)


## Bild der Welt setzen (null = noch keins bzw. nicht verfügbar).
func set_map_texture(texture: Texture2D) -> void:
	_image.texture = texture
	_no_image.visible = texture == null


## Gebietsname an einer Stelle der Welt (Welt-XZ).
func add_zone_label(text: String, world_position: Vector2) -> void:
	var label := Label.new()
	label.theme_type_variation = &"MapZoneLabel"
	label.text = text
	label.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.add_child(label)
	_overlay.move_child(_player_marker, -1)
	_placed.append([label, world_position])
	_layout()


## Wiedereinstiegspunkt als Symbol mit Tooltip.
func add_respawn_marker(text: String, world_position: Vector2) -> void:
	var marker: MapMarker = MARKER_SCENE.instantiate()
	marker.kind = MapMarker.Kind.RESPAWN
	marker.tooltip_text = "Wiedereinstiegspunkt: %s" % text
	_overlay.add_child(marker)
	_overlay.move_child(_player_marker, -1)
	_placed.append([marker, world_position])
	_layout()


## Mitspieler als Punkt in color (Klassenfarbe), Name als Tooltip.
func add_mate_marker(node: Node3D, display_name: String, color: Color) -> void:
	if _mates.has(node):
		return
	var marker: MapMarker = MARKER_SCENE.instantiate()
	marker.kind = MapMarker.Kind.MATE
	marker.fill_color = color
	marker.tooltip_text = display_name
	marker.visible = false
	_overlay.add_child(marker)
	_overlay.move_child(_player_marker, -1)
	_mates[node] = marker
	node.tree_exiting.connect(_remove_mate.bind(node), CONNECT_ONE_SHOT)


func _remove_mate(node: Node3D) -> void:
	var marker: MapMarker = _mates.get(node)
	_mates.erase(node)
	if marker != null:
		marker.queue_free()


## Figur, die als Pfeil angezeigt wird (die eigene).
func set_tracked_node(node: Node3D) -> void:
	_tracked = node


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	for node: Node3D in _mates:
		var mate := node.global_position
		_mates[node].visible = true
		_mates[node].place_at(world_to_map(Vector2(mate.x, mate.z)))
	var has_player := is_instance_valid(_tracked) and _tracked.is_inside_tree()
	_player_marker.visible = has_player
	if not has_player:
		return
	var p := _tracked.global_position
	_player_marker.place_at(world_to_map(Vector2(p.x, p.z)))
	# Blickrichtung der Figur ist -Z; auf der Karte zeigt der Pfeil bei
	# Rotation 0 nach oben (Norden).
	var forward := -_tracked.global_basis.z
	_player_marker.rotation = Vector2(forward.x, forward.z).angle() + PI / 2.0


## Welt-XZ → Koordinaten im Overlay.
func world_to_map(world_xz: Vector2) -> Vector2:
	return (world_xz - world_rect.position) / world_rect.size * _overlay.size


func _layout() -> void:
	for entry in _placed:
		var control: Control = entry[0]
		var point := world_to_map(entry[1])
		if control is MapMarker:
			(control as MapMarker).place_at(point)
		else:
			control.reset_size()
			control.position = point - control.size / 2.0
