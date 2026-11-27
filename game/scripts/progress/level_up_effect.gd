class_name LevelUpEffect
extends Node3D
## Aufstiegseffekt an der Figur (Ticket #27), Graubox-Platzhalter: ein
## aufsteigender, durchscheinender Lichtschein (offener Zylinder ohne Deckel)
## mit Punktlicht, der nach oben wandert und ausblendet. Rein lokal; jede
## Instanz spielt ihn ab, sobald ihr der Host den Aufstieg meldet
## (PlayerExperience.leveled_up), deshalb sehen ihn alle Spieler.
##
## Farbe aus dem Theme (Theme-Typ „LevelUpEffect“, Farbe „glow“, Platzhalter,
## OFFEN). Klang: Stelle zum Abspielen ist da (Kindknoten „Sound“), es gibt
## noch keine Audiodatei (OFFEN, wie beim Klang der Fehlermeldung).

const THEME_TYPE := &"LevelUpEffect"
const NODE_NAME := &"LevelUpEffect"
## Dauer in Sekunden, Höhe des Aufstiegs und Größe des Scheins in Metern.
const DURATION := 1.8
const RISE := 1.6
const RADIUS := 0.75
const HEIGHT := 2.2
## Deckkraft des Scheins zu Beginn und Lichtstärke.
const START_ALPHA := 0.55
const LIGHT_ENERGY := 2.5

var _material: StandardMaterial3D = null
var _light: OmniLight3D = null
var _age := 0.0


## Spielt den Effekt an unit ab (ein laufender wird ersetzt).
static func play_on(unit: Node3D) -> LevelUpEffect:
	if unit == null or not unit.is_inside_tree():
		return null
	var old := unit.get_node_or_null(NodePath(String(NODE_NAME)))
	if old != null:
		old.queue_free()
		old.name = &"LevelUpEffectOld"
	var effect := LevelUpEffect.new()
	effect.name = NODE_NAME
	unit.add_child(effect)
	return effect


## Farbe des Scheins aus dem Theme.
static func glow_color() -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_color(&"glow", THEME_TYPE):
		return theme.get_color(&"glow", THEME_TYPE)
	return ThemeDB.get_default_theme().get_color(&"font_color", &"Label")


func _ready() -> void:
	var color := glow_color()
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(color, START_ALPHA)
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS * 0.6
	mesh.bottom_radius = RADIUS
	mesh.height = HEIGHT
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.material = _material
	var shine := MeshInstance3D.new()
	shine.name = "Shine"
	shine.mesh = mesh
	shine.position.y = HEIGHT / 2.0
	shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shine)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = color
	_light.light_energy = LIGHT_ENERGY
	_light.omni_range = 4.0
	_light.position.y = 1.2
	add_child(_light)
	var sound := AudioStreamPlayer3D.new()
	sound.name = "Sound"
	add_child(sound)
	if sound.stream != null:
		sound.play()


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / DURATION, 0.0, 1.0)
	position.y = RISE * t
	scale = Vector3(1.0 - 0.4 * t, 1.0, 1.0 - 0.4 * t)
	var color := _material.albedo_color
	color.a = START_ALPHA * (1.0 - t)
	_material.albedo_color = color
	_light.light_energy = LIGHT_ENERGY * (1.0 - t)
	if t >= 1.0:
		queue_free()
