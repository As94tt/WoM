class_name SpellAnimation
extends RefCounted
## Ablauf der Zauber-Animationen einer Spielfigur (Ticket #63), ohne Knoten
## (testbar). CharacterAnimator meldet Beginn und Ende von Zaubern, fragt je
## Frame den Abschnitt (Stage) und das Gewicht für den Oberkörper ab und
## schaltet damit den AnimationTree.
##
## Abläufe (Clips aus CharacterAnimationSet, Gruppe „Zauber“):
##   Zauberzeit, fremdes Ziel:  Heben → Halten (Schleife) → Erfolg: Loslassen
##                              → Ende; sonst Senken
##   Kanalisieren:              Heben → Halten (Schleife) → Senken
##   Zauberzeit ohne fremdes Ziel (Selbst-/Hilfszauber):
##                              Heben → Halten → Senken (kein Loslassen)
##   Sofortzauber:              Loslassen, danach ausblenden
##   Sofortzauber ohne fremdes Ziel: Heben → Senken, schneller abgespielt
##   Unterbrochen, abgebrochen, fehlgeschlagen, vom Host abgelehnt:
##                              sofort Senken (nie Loslassen)
##
## Welche Fähigkeit animiert wird, entscheiden ihre Daten (animates):
## Zauber (is_spell) ohne Waffenbedingung. Nahkampf, nächster Schlag und
## automatischer Angriff bleiben ohne Animation.

enum Stage { NONE, ENTER, IDLE, SHOOT, EXIT }

## Namen der Eingänge im AnimationTree, Reihenfolge wie Stage (ohne NONE).
const STAGE_INPUTS: Array[StringName] = [&"", &"heben", &"halten", &"loslassen", &"senken"]

var stage: Stage = Stage.NONE
var time_in_stage := 0.0
## Abspielfaktor des laufenden Ablaufs (Selbstzauber schneller).
var speed := 1.0
## Gewicht über den Beinen (0 = nur Grundanimation, 1 = Zauber im Oberkörper).
var weight := 0.0
## Zählt jeden Eintritt in einen Abschnitt (auch denselben noch einmal),
## damit der AnimationTree den Clip neu startet.
var serial := 0

## Abschnitt nach dem Heben (Halten bzw. bei Selbst-Sofortzaubern Senken).
var _after_enter: Stage = Stage.IDLE
## Abschnitt nach dem Loslassen (Sofortzauber: keiner, Zauberzeit: Ende).
var _after_shoot: Stage = Stage.NONE


## Zauber mit Zauberzeit oder Kanalisieren beginnt: Heben, dann Halten.
func begin_cast() -> void:
	speed = 1.0
	_after_enter = Stage.IDLE
	_enter(Stage.ENTER)


## Zauber mit Zauberzeit bzw. Kanalisieren ist zu Ende. shoot = mit
## Loslassen (erfolgreiche Zauberzeit auf ein fremdes Ziel), sonst Senken.
func end_cast(shoot: bool) -> void:
	if stage != Stage.ENTER and stage != Stage.IDLE:
		return
	speed = 1.0
	if shoot:
		_after_shoot = Stage.NONE
		_enter(Stage.SHOOT)
	else:
		_enter(Stage.EXIT)


## Sofortzauber: auf ein fremdes Ziel Loslassen, sonst kurz Heben → Senken.
func instant(self_cast: bool, self_speed: float) -> void:
	if self_cast:
		speed = maxf(0.1, self_speed)
		_after_enter = Stage.EXIT
		_enter(Stage.ENTER)
	else:
		speed = 1.0
		_after_shoot = Stage.NONE
		_enter(Stage.SHOOT)


## Abbruch, Unterbrechung, Fehlschlag, Ablehnung: sofort Senken.
func abort() -> void:
	if stage == Stage.NONE or stage == Stage.EXIT:
		return
	speed = 1.0
	_enter(Stage.EXIT)


## Läuft gerade ein Ablauf?
func is_active() -> bool:
	return stage != Stage.NONE


## Schreitet um delta Sekunden fort und gibt den Abschnitt zurück.
func update(delta: float, anims: CharacterAnimationSet) -> Stage:
	time_in_stage += delta * speed
	match stage:
		Stage.ENTER:
			if time_in_stage >= anims.spell_enter_time:
				_enter(_after_enter)
		Stage.SHOOT:
			if time_in_stage >= anims.spell_shoot_time:
				_enter(_after_shoot)
		Stage.EXIT:
			if time_in_stage >= anims.spell_exit_time:
				_enter(Stage.NONE)
	# Einblenden beim Start, Ausblenden zum Ende des letzten Abschnitts.
	var target := 1.0 if stage != Stage.NONE and _remaining_in_last(anims) > anims.spell_blend_time * 0.5 else 0.0
	var rate := delta / maxf(anims.spell_blend_time, 0.001)
	weight = move_toward(weight, target, rate)
	return stage


## Restzeit (Sekunden, mit Abspielfaktor), wenn der aktuelle Abschnitt der
## letzte ist; sonst unendlich.
func _remaining_in_last(anims: CharacterAnimationSet) -> float:
	match stage:
		Stage.EXIT:
			return (anims.spell_exit_time - time_in_stage) / speed
		Stage.SHOOT:
			if _after_shoot == Stage.NONE:
				return (anims.spell_shoot_time - time_in_stage) / speed
	return INF


func _enter(new_stage: Stage) -> void:
	stage = new_stage
	time_in_stage = 0.0
	serial += 1


## Bekommt diese Fähigkeit eine Zauber-Animation? Zauber ohne
## Waffenbedingung; keine Nahkampf-, Nächster-Schlag- oder
## Angriffsfähigkeiten.
static func animates(ability: AbilityData) -> bool:
	return ability != null and ability.is_spell \
			and ability.required_weapon == AbilityData.WeaponRequirement.NONE \
			and not ability.on_next_swing and not ability.toggles_auto_attack \
			and not ability.starts_auto_attack


## Wirkt der Zauber ohne fremdes Ziel (auf bzw. um den Wirker)? Bodenziele
## zählen als fremdes Ziel (es wird auf den Punkt gezielt).
static func is_self_cast(ability: AbilityData, caster: Node, target: Node) -> bool:
	match ability.target_kind:
		AbilityData.TargetKind.NONE:
			return true
		AbilityData.TargetKind.GROUND, AbilityData.TargetKind.ENEMY:
			return false
		AbilityData.TargetKind.FRIENDLY:
			# Ohne passendes Ziel wirkt ein Hilfszauber auf den Wirker.
			return target == null or target == caster
	return target != null and target == caster
