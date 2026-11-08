class_name GroundTargeting
extends Node
## Bodenziel (Ticket #33): Kindknoten „GroundTargeting“ der Spielfigur, nur
## beim Besitzer (wie Targeting). PlayerAbilities.use_ability ruft begin()
## für Fähigkeiten mit AbilityData.TargetKind.GROUND. Danach folgt ein Kreis
## dem Mauszeiger auf dem Boden (Radius werte.radius der Fähigkeit); ein
## Linksklick in die Welt setzt den Zauber (UnitCaster.request_use mit Punkt),
## Rechtsklick oder Esc bricht ab (PlayerInput bzw. Hud.handle_cancel).
## Außerhalb der Reichweite wechselt der Kreis die Farbe (ground_invalid,
## CombatColors/Theme); die Meldung kommt erst beim Klick.

const RAY_LENGTH := 300.0
const RING_THICKNESS := 0.06
const RING_LIFT := 0.06

var _ability: AbilityData = null
var _ring: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _point := Vector3.ZERO
var _has_point := false

@onready var _player: PlayerCharacter = get_parent() as PlayerCharacter


func _ready() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.0 - RING_THICKNESS
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 6
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = _material
	_ring = MeshInstance3D.new()
	_ring.name = "GroundRing"
	_ring.mesh = mesh
	_ring.top_level = true
	_ring.visible = false
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _exit_tree() -> void:
	_ability = null


func is_active() -> bool:
	return _ability != null


func get_ability() -> AbilityData:
	return _ability


## Kreis für ability am Mauszeiger zeigen.
func begin(ability: AbilityData) -> void:
	_ability = ability
	_update()


## Abbrechen (Rechtsklick, Esc). Gibt true zurück, wenn etwas aktiv war.
func cancel() -> bool:
	if _ability == null:
		return false
	_ability = null
	_ring.visible = false
	return true


## Linksklick in die Welt: Zauber an dieser Stelle setzen.
func confirm(screen_position: Vector2) -> void:
	if _ability == null:
		return
	var hit := _ground_at(screen_position)
	var caster := _player.get_caster_node()
	var ability := _ability
	cancel()
	if caster == null:
		return
	if hit.is_empty():
		caster.failed.emit(AbilityError.Code.INVALID_POINT, "", ability)
		return
	caster.request_use(ability, null, hit["position"], true)


func _process(_delta: float) -> void:
	if _ability != null:
		_update()


func _update() -> void:
	var hit := _ground_at(get_viewport().get_mouse_position())
	_has_point = not hit.is_empty()
	_ring.visible = _has_point
	if not _has_point:
		return
	_point = hit["position"]
	var radius := maxf(0.5, _ability.get_number_for(_player, "werte.radius"))
	_ring.global_transform = Transform3D(Basis.from_scale(Vector3(radius, 0.3, radius)),
			_point + Vector3.UP * RING_LIFT)
	var caster := _player.get_caster_node()
	var reach := caster.get_range(_ability) if caster != null else 0.0
	var offset := _point - _player.global_position
	var inside := Vector2(offset.x, offset.z).length() <= reach
	_material.albedo_color = CombatColors.ability_color(&"ground_valid" if inside else &"ground_invalid")


## Bodenpunkt unter dem Mauszeiger (Ebene „Welt“) oder leer.
func _ground_at(screen_position: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _player == null:
		return {}
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, Unit.LINE_OF_SIGHT_MASK)
	return _player.get_world_3d().direct_space_state.intersect_ray(query)
