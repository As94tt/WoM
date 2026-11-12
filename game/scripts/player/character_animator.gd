class_name CharacterAnimator
extends Node3D
## Modell und Grundanimationen einer Spielfigur (Ticket #59). Kindknoten von
## „Model“ in player.tscn. Ohne Modelldaten tut er nichts, und die Figur
## bleibt die Graubox-Kapsel.
##
## Mit Modelldaten (CharacterModelData) erzeugt er das Modell unter einem
## eigenen Drehpunkt („Pivot“) und einen AnimationTree, der aus
## Bodenkontakt, Tempo und Bewegungsrichtung die Animation wählt:
##
##   zustand (Transition): boden | absprung | luft | landen
##   boden = tempo (TimeScale) <- gang (Transition):
##           stehen | gehen | laufen | sprinten | gehen_rueck | laufen_rueck
##
## Netzwerk: Es wird nichts übertragen. Jede Instanz liest dieselben Werte der
## Spielfigur – Bewegungszustand (move_state, über MovementSync) und
## Geschwindigkeit (visual_velocity, beim Besitzer aus der Physik, bei
## fremden Figuren aus den interpolierten Schnappschüssen) – und wählt die
## Animation lokal.
##
## Rückwärts- und Seitwärts-Clips fehlen in der Standard-Library.
## Übergangslösung: rückwärts spielen Gehen/Laufen rückwärts ab, seitwärts
## und schräg dreht sich das Modell (nicht die Figur) in Laufrichtung, höchstens
## um 90 Grad.

enum Gait { STAND, WALK, RUN, SPRINT, WALK_BACK, RUN_BACK }
enum Phase { GROUND, JUMP_START, AIR, LAND }

## Namen der Eingänge im AnimationTree, Reihenfolge wie Gait bzw. Phase.
const GAIT_INPUTS: Array[StringName] = [&"stehen", &"gehen", &"laufen", &"sprinten", &"gehen_rueck", &"laufen_rueck"]
const PHASE_INPUTS: Array[StringName] = [&"boden", &"absprung", &"luft", &"landen"]
## Spielraum über der Gehgeschwindigkeit, bis zu dem noch „Gehen“ gilt.
const WALK_TOLERANCE := 1.15
## Hüfthöhe, falls das Skelett keinen Knochen „Hips“ hat (Meter).
const DEFAULT_HIP_HEIGHT := 1.0


## Ergebnis der Gangwahl (siehe choose_gait).
class GaitChoice:
	var gait: Gait = Gait.STAND
	## Abspielfaktor für den gewählten Clip.
	var time_scale := 1.0
	## Drehung des Modells zur Laufrichtung (Bogenmaß, positiv = nach links).
	var facing := 0.0


## Zustandsfolge Boden/Absprung/Luft/Landen, ohne Knoten (testbar).
class PhaseTracker:
	var phase: Phase = Phase.GROUND
	var time_in_phase := 0.0
	var air_time := 0.0

	## in_air: kein Bodenkontakt; rising: nach oben unterwegs (Sprung);
	## moving: die Figur läuft. Gibt die neue Phase zurück.
	func update(in_air: bool, rising: bool, moving: bool, delta: float, anims: CharacterAnimationSet) -> Phase:
		time_in_phase += delta
		if in_air:
			air_time += delta
		match phase:
			Phase.GROUND, Phase.LAND:
				if in_air:
					# Absprung sofort; Fallen erst nach kurzer Zeit, damit
					# kleine Stufen hinunter nicht flackern.
					if rising:
						air_time = 0.0
						_enter(Phase.JUMP_START)
					elif air_time >= anims.fall_delay:
						_enter(Phase.AIR)
				else:
					air_time = 0.0
					if phase == Phase.LAND and (time_in_phase >= anims.land_time_standing
							or (moving and time_in_phase >= anims.land_time_moving)):
						_enter(Phase.GROUND)
			Phase.JUMP_START, Phase.AIR:
				if not in_air:
					_enter(Phase.LAND if air_time >= anims.min_air_time else Phase.GROUND)
					air_time = 0.0
				elif phase == Phase.JUMP_START and time_in_phase >= anims.jump_start_time:
					_enter(Phase.AIR)
		return phase

	func _enter(new_phase: Phase) -> void:
		phase = new_phase
		time_in_phase = 0.0


var _data: CharacterModelData = null
var _character: PlayerCharacter = null
var _pivot: Node3D = null
var _model: Node3D = null
var _tree: AnimationTree = null
var _phases := PhaseTracker.new()
var _gait: Gait = Gait.STAND
var _hip_height := DEFAULT_HIP_HEIGHT
var _facing := 0.0


func _ready() -> void:
	set_process(false)


## Erzeugt Modell und AnimationTree. false, wenn die Daten kein Modell
## enthalten (dann bleibt die Kapsel).
func setup(data: CharacterModelData, character: PlayerCharacter) -> bool:
	if data == null or data.scene == null:
		return false
	var instance := data.scene.instantiate() as Node3D
	if instance == null:
		push_warning("CharacterAnimator: Modellszene ist kein Node3D.")
		return false
	_data = data
	_character = character
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	_model = instance
	_pivot.add_child(_model)
	_hip_height = measure_hip_height(_model) * data.model_scale
	_update_pivot(0.0)

	var animations := data.animations
	if animations != null and animations.library != null:
		_tree = AnimationTree.new()
		_tree.name = "AnimationTree"
		add_child(_tree)
		_tree.add_animation_library(&"", animations.library)
		_tree.tree_root = build_tree(animations)
		_tree.root_node = _tree.get_path_to(_model)
		# Transitions haben anfangs keinen aktiven Eingang (= Ruhepose).
		_tree.set(&"parameters/zustand/transition_request", String(PHASE_INPUTS[_phases.phase]))
		_tree.set(&"parameters/gang/transition_request", String(GAIT_INPUTS[_gait]))
		_tree.active = true
	else:
		push_warning("CharacterAnimator: keine Animationen für das Modell.")
	set_process(true)
	return true


## Das erzeugte Modell (oder null bei Kapsel).
func get_model() -> Node3D:
	return _model


func get_tree_node() -> AnimationTree:
	return _tree


func get_phase() -> Phase:
	return _phases.phase


func get_gait() -> Gait:
	return _gait


func get_hip_height() -> float:
	return _hip_height


func _process(delta: float) -> void:
	if _character == null or _tree == null:
		return
	var anims := _data.animations
	var state := _character.move_state
	var in_air := state == PlayerCharacter.MoveState.JUMPING or state == PlayerCharacter.MoveState.FALLING
	var local_velocity := _character.global_basis.inverse() * _character.visual_velocity
	var choice := choose_gait(local_velocity, _hip_height, _character.get_walk_speed() * WALK_TOLERANCE, anims)
	var moving := choice.gait != Gait.STAND
	var old_phase := _phases.phase
	var phase := _phases.update(in_air, state == PlayerCharacter.MoveState.JUMPING, moving, delta, anims)
	if phase != old_phase:
		_tree.set(&"parameters/zustand/transition_request", String(PHASE_INPUTS[phase]))
	if phase == Phase.GROUND or phase == Phase.LAND:
		if choice.gait != _gait:
			_gait = choice.gait
			_tree.set(&"parameters/gang/transition_request", String(GAIT_INPUTS[_gait]))
		_tree.set(&"parameters/tempo/scale", choice.time_scale)
		_facing = lerp_angle(_facing, choice.facing, clampf(anims.facing_turn_rate * delta, 0.0, 1.0))
	_update_pivot(_facing)


func _update_pivot(facing: float) -> void:
	_pivot.rotation = Vector3(0.0, deg_to_rad(_data.yaw_offset_deg) + facing, 0.0)
	# „Model“ trägt den Platzhalter-Größenfaktor des Volks (für Reichweiten
	# und Körpergröße der Einheit); ein echtes Modell hat seine eigene Größe.
	var parent_scale := (get_parent() as Node3D).scale.y if get_parent() is Node3D else 1.0
	_pivot.scale = Vector3.ONE * (_data.model_scale / maxf(parent_scale, 0.01))


## Wählt Gang, Abspielfaktor und Modelldrehung aus der Geschwindigkeit im
## Raum der Figur (x = rechts, -z = vorn). hip_height in Metern, walk_limit
## = höchste Geschwindigkeit, die noch als Gehen gilt (m/s).
static func choose_gait(local_velocity: Vector3, hip_height: float, walk_limit: float,
		anims: CharacterAnimationSet) -> GaitChoice:
	var choice := GaitChoice.new()
	var dir := Vector2(local_velocity.x, -local_velocity.z)  # x rechts, y vorn
	var speed := dir.length()
	if speed < anims.standing_speed:
		return choice
	var backward := dir.y < -0.1 * speed
	if backward:
		dir = -dir
	# Positiv = nach links drehen (wie rotation.y); nie mehr als 90 Grad.
	choice.facing = clampf(atan2(-dir.x, dir.y), -PI / 2.0, PI / 2.0)
	var relative := speed / maxf(hip_height, 0.01)
	var reference: float
	if speed <= walk_limit:
		choice.gait = Gait.WALK_BACK if backward else Gait.WALK
		reference = anims.walk_reference_speed
	elif not backward and relative >= anims.sprint_threshold:
		choice.gait = Gait.SPRINT
		reference = anims.sprint_reference_speed
	else:
		choice.gait = Gait.RUN_BACK if backward else Gait.RUN
		reference = anims.run_reference_speed
	choice.time_scale = clampf(relative / maxf(reference, 0.01), anims.min_time_scale, anims.max_time_scale)
	return choice


## Hüfthöhe des Modells in Metern (Ruhepose des Knochens „Hips“).
static func measure_hip_height(model: Node) -> float:
	var skeleton := find_skeleton(model)
	if skeleton == null:
		return DEFAULT_HIP_HEIGHT
	var hips := skeleton.find_bone("Hips")
	if hips < 0:
		return DEFAULT_HIP_HEIGHT
	var height := (skeleton.transform * skeleton.get_bone_global_rest(hips)).origin.y
	return height if height > 0.05 else DEFAULT_HIP_HEIGHT


static func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found != null:
			return found
	return null


## Baut den Animationsbaum für einen Animationssatz.
static func build_tree(anims: CharacterAnimationSet) -> AnimationNodeBlendTree:
	var root := AnimationNodeBlendTree.new()
	var gait_clips := [anims.idle, anims.walk, anims.run, anims.sprint, anims.walk, anims.run]
	var gang := AnimationNodeTransition.new()
	gang.xfade_time = anims.blend_time
	root.add_node(&"gang", gang)
	for i in GAIT_INPUTS.size():
		var clip := AnimationNodeAnimation.new()
		clip.animation = gait_clips[i]
		if GAIT_INPUTS[i].ends_with("_rueck"):
			clip.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
		root.add_node(GAIT_INPUTS[i], clip)
		gang.add_input(GAIT_INPUTS[i])
		root.connect_node(&"gang", i, GAIT_INPUTS[i])
	root.add_node(&"tempo", AnimationNodeTimeScale.new())
	root.connect_node(&"tempo", 0, &"gang")

	var zustand := AnimationNodeTransition.new()
	zustand.xfade_time = anims.blend_time
	root.add_node(&"zustand", zustand)
	var phase_sources := [&"tempo", &"absprung", &"luft", &"landen"]
	var phase_clips := {&"absprung": anims.jump_start, &"luft": anims.jump_air, &"landen": anims.land}
	for name: StringName in phase_clips:
		var clip := AnimationNodeAnimation.new()
		clip.animation = phase_clips[name]
		root.add_node(name, clip)
	for i in PHASE_INPUTS.size():
		zustand.add_input(PHASE_INPUTS[i])
		root.connect_node(&"zustand", i, phase_sources[i])
	root.connect_node(&"output", 0, &"zustand")
	return root
