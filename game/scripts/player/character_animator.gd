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
##
## Zauber (Ticket #63): Über der Grundanimation liegt ein Blend2
## „oberkoerper“, dessen Filter nur den Oberkörper (ab upper_body_root, z. B.
## Spine) durchlässt. Sein zweiter Eingang ist die Transition „zauber“
## (heben | halten | loslassen | senken) hinter „zauber_tempo“. Den Ablauf
## bestimmt SpellAnimation aus dem UnitCaster der Figur:
## - Zauberzeit/Kanalisieren: laufender Zauber aus get_cast_info() (beim
##   Besitzer die Vorhersage, sonst cast_state über CastSync), Ergebnis aus
##   cast_ended (cast_end über CastSync bzw. beim Besitzer Abbruch/Ablehnung).
## - Sofortzauber: Signal instant_used (beim Besitzer sofort als Vorhersage,
##   bei allen anderen aus instant_cast über CastSync), Ablehnung durch den
##   Host: instant_rejected (wie ein Abbruch).
## Auch hier wird nichts zusätzlich übertragen außer instant_cast.

## Ein Zauber, dessen Zustand verschwindet, ohne dass ein Ergebnis kommt,
## endet nach so vielen Sekunden wie ein Abbruch (Sicherheitsgrenze).
const SPELL_END_GRACE := 0.3

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

# --- Zauber (#63) ---
var _caster: UnitCaster = null
var _spell := SpellAnimation.new()
var _spell_serial := 0
## Laufender animierter Zauber: {key, ability, channel, self, gone}; leer = keiner.
var _spell_cast: Dictionary = {}
## Schlüssel des zuletzt beendeten Zaubers (nicht noch einmal beginnen, falls
## sein Zustand kurz nach dem Ergebnis noch zu sehen ist).
var _spell_done_key := ""
## Fähigkeit des laufenden Sofortzauber-Ablaufs (für eine Ablehnung).
var _spell_instant: AbilityData = null


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
		if animations.has_spell_clips():
			_connect_caster(character.get_caster_node())
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


## Ablauf der Zauber-Animation (für Tests und Fehlersuche).
func get_spell_animation() -> SpellAnimation:
	return _spell


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
	if _caster != null:
		_process_spell(delta)


# --- Zauber (#63) ------------------------------------------------------------

func _connect_caster(caster: UnitCaster) -> void:
	if caster == null:
		return
	_caster = caster
	caster.cast_ended.connect(_on_cast_ended)
	caster.instant_used.connect(_on_instant_used)
	caster.instant_rejected.connect(_on_instant_rejected)


func _process_spell(delta: float) -> void:
	var anims := _data.animations
	_follow_cast(delta)
	_spell.update(delta, anims)
	if _spell.serial != _spell_serial:
		_spell_serial = _spell.serial
		if _spell.stage != SpellAnimation.Stage.NONE:
			_tree.set(&"parameters/zauber/transition_request", String(SpellAnimation.STAGE_INPUTS[_spell.stage]))
		if _spell.stage != SpellAnimation.Stage.SHOOT and _spell.stage != SpellAnimation.Stage.ENTER:
			_spell_instant = null
	_tree.set(&"parameters/zauber_tempo/scale", _spell.speed)
	_tree.set(&"parameters/oberkoerper/blend_amount", _spell.weight)


## Laufenden Zauber (Zauberzeit, Kanalisieren) mit der Animation abgleichen.
func _follow_cast(delta: float) -> void:
	var info := _caster.get_cast_info()
	var key := cast_key(info)
	if key != "" and key != _spell_done_key and (_spell_cast.is_empty() or _spell_cast["key"] != key):
		var ability: AbilityData = info["ability"]
		if SpellAnimation.animates(ability):
			var target := Unit.from_path(get_tree(), info["target_path"]) if info["target_path"] is NodePath else null
			_spell_cast = {"key": key, "ability": ability.id, "channel": bool(info["channel"]),
					"self": SpellAnimation.is_self_cast(ability, _character, target), "gone": 0.0}
			_spell_instant = null
			_spell.begin_cast()
		elif not _spell_cast.is_empty():
			# Vorheriger Zauber ohne Ergebnis: nicht im Halten hängen bleiben.
			_finish_cast(false)
		return
	if _spell_cast.is_empty():
		return
	if key == "":
		# Zustand weg, Ergebnis (cast_ended) fehlt noch: kurz warten, dann Senken.
		_spell_cast["gone"] = float(_spell_cast["gone"]) + delta
		if float(_spell_cast["gone"]) >= SPELL_END_GRACE:
			_finish_cast(false)


func _on_cast_ended(result: int, ability_id: StringName) -> void:
	if _spell_cast.is_empty() or _spell_cast["ability"] != ability_id:
		return
	var shoot := result == UnitCaster.Result.DONE and not bool(_spell_cast["channel"]) \
			and not bool(_spell_cast["self"])
	_finish_cast(shoot)


func _finish_cast(shoot: bool) -> void:
	_spell_done_key = _spell_cast["key"]
	_spell_cast = {}
	_spell.end_cast(shoot)


func _on_instant_used(ability: AbilityData, target: Unit) -> void:
	if not SpellAnimation.animates(ability):
		return
	_spell_cast = {}
	_spell_instant = ability
	_spell.instant(SpellAnimation.is_self_cast(ability, _character, target), _data.animations.spell_self_speed)


func _on_instant_rejected(ability: AbilityData) -> void:
	if _spell_instant != null and ability != null and _spell_instant.id == ability.id:
		_spell_instant = null
		_spell.abort()


## Eindeutiger Schlüssel eines laufenden Zaubers aus get_cast_info() (leer =
## keiner). Vorhersage und Stand des Hosts teilen die Wunsch-Nummer; ohne
## Wunsch (KI, Übungspuppen) zählt die Startzeit.
static func cast_key(info: Dictionary) -> String:
	if info.is_empty() or info.get("ability") == null:
		return ""
	var ability: AbilityData = info["ability"]
	var req := int(info.get("req", 0))
	if req != 0:
		return "%s#%d" % [ability.id, req]
	return "%s@%.3f" % [ability.id, float(info.get("start", 0.0))]


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
	if not anims.has_spell_clips():
		root.connect_node(&"output", 0, &"zustand")
		return root

	# Zauber (#63): Abschnitte als Transition, nur im Oberkörper überblendet.
	var zauber := AnimationNodeTransition.new()
	zauber.xfade_time = anims.spell_blend_time
	zauber.allow_transition_to_self = true
	root.add_node(&"zauber", zauber)
	var spell_clips := [anims.spell_enter, anims.spell_idle, anims.spell_shoot, anims.spell_exit]
	for i in spell_clips.size():
		var input := SpellAnimation.STAGE_INPUTS[i + 1]
		var clip := AnimationNodeAnimation.new()
		clip.animation = spell_clips[i]
		var node_name := StringName("z_" + String(input))
		root.add_node(node_name, clip)
		zauber.add_input(input)
		zauber.set_input_reset(i, true)
		root.connect_node(&"zauber", i, node_name)
	root.add_node(&"zauber_tempo", AnimationNodeTimeScale.new())
	root.connect_node(&"zauber_tempo", 0, &"zauber")
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	for path in upper_body_tracks(anims):
		upper.set_filter_path(path, true)
	root.add_node(&"oberkoerper", upper)
	root.connect_node(&"oberkoerper", 0, &"zustand")
	root.connect_node(&"oberkoerper", 1, &"zauber_tempo")
	root.connect_node(&"output", 0, &"oberkoerper")
	return root


## Spuren der Zauber-Clips, die zum Oberkörper gehören: Knochen
## upper_body_root und alles darunter laut SkeletonProfileHumanoid. Knochen,
## die das Profil nicht kennt (z. B. Fingerspitzen „…_leaf“), hängen an den
## Händen und gehören ebenfalls dazu; Hüfte und Beine nicht.
static func upper_body_tracks(anims: CharacterAnimationSet) -> Array[NodePath]:
	var profile := SkeletonProfileHumanoid.new()
	var upper := {}
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		var current := bone
		while current != &"":
			if current == anims.upper_body_root:
				upper[bone] = true
				break
			var index := profile.find_bone(current)
			current = profile.get_bone_parent(index) if index >= 0 else &""
	var result: Array[NodePath] = []
	var seen := {}
	for clip in [anims.spell_enter, anims.spell_idle, anims.spell_shoot, anims.spell_exit]:
		var anim := anims.library.get_animation(clip)
		for t in anim.get_track_count():
			var path := anim.track_get_path(t)
			var key := String(path)
			if seen.has(key) or path.get_subname_count() == 0:
				continue
			seen[key] = true
			var bone := StringName(path.get_subname(0))
			if upper.has(bone) or profile.find_bone(bone) < 0:
				result.append(path)
	return result
