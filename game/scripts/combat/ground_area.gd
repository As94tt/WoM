class_name GroundArea
extends Node3D
## Bodeneffekt aus „Fläche erzeugen“ (Ticket #32). Graubox: halbdurchsichtige
## flache Scheibe in der Größe des Radius.
##
## Netzwerk: Der Host erzeugt die Fläche unter „Effects“ der Welt; der
## EffectSpawner überträgt sie (Position, Radius, Ablaufzeit beim Erzeugen).
## Nur der Host wendet die Effekte an und entfernt die Fläche nach Ablauf;
## der Spawner entfernt sie dann auch bei allen Clients.

## Gruppe des Behälters für Flächen und Projektile (Knoten „Effects“ der Welt).
const CONTAINER_GROUP := &"combat_effects"

## Übertragen beim Erzeugen.
@export var radius := 1.0:
	set(value):
		radius = value
		if is_node_ready():
			_apply_radius()
## Ablaufzeit in Host-Zeit (für Anzeigen).
@export var expires_at := 0.0

# --- nur Host ---
var _effect: AreaEffect = null
var _ctx: EffectContext = null
var _next_tick := 0.0


## Behälter der Welt oder null.
static func find_container(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(CONTAINER_GROUP) if tree != null else null


## Host, vor add_child.
func setup(effect: AreaEffect, ctx: EffectContext, at: Vector3) -> void:
	_effect = effect
	_ctx = ctx
	_ctx.point = at
	_ctx.has_point = true
	_ctx.periodic = true
	position = at
	radius = effect.area_radius
	var now := Network.host_time()
	expires_at = now + effect.duration
	_next_tick = now if effect.tick_on_create else now + effect.interval


func _ready() -> void:
	$Sync.add_visibility_filter(Network.is_peer_in_world)
	_apply_radius()


func _process(_delta: float) -> void:
	if not multiplayer.is_server() or _effect == null:
		return
	var now := Network.host_time()
	while now >= _next_tick and _next_tick <= expires_at + 0.001:
		_tick()
		_next_tick += maxf(0.1, _effect.interval)
	if now >= expires_at:
		queue_free()


func _tick() -> void:
	var units: Array[Unit] = []
	var caster := _ctx.get_caster()
	for unit in Unit.all_units(get_tree()):
		if unit.is_dead():
			continue
		var offset := unit.global_position - global_position
		if Vector2(offset.x, offset.z).length() - unit.get_body_radius() > radius:
			continue
		if absf(offset.y) > maxf(2.0, unit.get_body_height()):
			continue
		if _effect.area_filter == EffectData.Filter.HOSTILE and not Combat.is_hostile(caster, unit):
			continue
		if _effect.area_filter == EffectData.Filter.FRIENDLY and caster != null \
				and caster.get_reaction_to(unit) != Unit.Reaction.FRIENDLY:
			continue
		units.append(unit)
	if _effect.max_targets > 0 and units.size() > _effect.max_targets:
		units.resize(_effect.max_targets)
	for unit in units:
		var ctx := _ctx.with_target(unit)
		ctx.consumed = {}
		for effect in _effect.effects:
			if effect != null:
				effect.apply_checked(ctx, unit)


func _apply_radius() -> void:
	$Disc.scale = Vector3(radius, 1.0, radius)
