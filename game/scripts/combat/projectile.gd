class_name Projectile
extends Node3D
## Projektil aus dem Effekt „Projektil“ (Ticket #32). Graubox: kleine Kugel.
##
## Netzwerk: Der Host erzeugt es unter „Effects“ der Welt (EffectSpawner
## überträgt Startpunkt, Ziel und Geschwindigkeit). Alle Instanzen bewegen
## die Kugel selbst mit derselben Geschwindigkeit zum Ziel; nur der Host
## entscheidet den Aufprall, führt die Effekte aus und entfernt das
## Projektil (der Spawner entfernt es dann bei allen).

## Abstand zur Brust des Ziels, ab dem das Projektil trifft (Meter).
const HIT_DISTANCE := 0.3
## Sicherheitsgrenze: so lange fliegt ein Projektil höchstens (Sekunden).
const MAX_LIFETIME := 15.0

@export var target_path := NodePath()
@export var speed := 20.0
## Schadensschule für die Farbe (#33, CombatColors). Übertragen.
@export var school: StringName = &"physisch"

# --- nur Host ---
var _effect: ProjectileEffect = null
var _ctx: EffectContext = null
var _age := 0.0


## Host, vor add_child.
func setup(effect: ProjectileEffect, ctx: EffectContext, start: Vector3, target: Unit) -> void:
	_effect = effect
	_ctx = ctx
	position = start
	speed = maxf(0.1, effect.get_speed(ctx))
	school = effect.get_school(ctx)
	target_path = target.get_path()


func _ready() -> void:
	$Sync.add_visibility_filter(Network.is_peer_in_world)
	# Graubox (#33): kleine leuchtende Kugel in der Farbe der Schadensschule.
	var ball := get_node_or_null(^"Ball") as MeshInstance3D
	if ball != null:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = CombatColors.school_color(school)
		material.emission_enabled = true
		material.emission = material.albedo_color
		ball.material_override = material


func _process(delta: float) -> void:
	_age += delta
	var target := Unit.from_path(get_tree(), target_path)
	if target == null or not is_instance_valid(target):
		if multiplayer.is_server():
			queue_free()
		return
	var aim := target.global_position + Vector3.UP * target.get_body_height() * 0.6
	var to := aim - global_position
	var step := speed * delta
	if to.length() <= maxf(step, HIT_DISTANCE):
		global_position = aim
		visible = false
		if multiplayer.is_server():
			_impact(target)
		return
	global_position += to.normalized() * step
	if multiplayer.is_server() and _age > MAX_LIFETIME:
		queue_free()


func _impact(target: Unit) -> void:
	if _effect != null and _ctx != null and not target.is_dead():
		var ctx := _ctx.with_target(target)
		ctx.consumed = {}
		Combat.execute(_effect.effects, ctx)
	queue_free()
