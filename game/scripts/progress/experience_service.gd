class_name ExperienceService
extends Node
## Erfahrung für Kills (Ticket #27). Kindknoten „Experience“ der Welt
## (GameWorld legt ihn an). Läuft nur auf dem Host: Er hört auf
## GameWorld.unit_died und verteilt die Erfahrung des Getöteten über
## PlayerExperience.host_grant.
##
## Wer bekommt etwas: Der Töter muss eine Spielfigur sein. Seine Gruppe sind
## vorerst alle Spieler der Sitzung (eine Sitzung hat höchstens 5 Spieler, also
## genau eine Gruppe; ein eigenes Gruppensystem kommt mit M5, dann ersetzt
## get_group_members die Sitzung durch die Gruppe). Davon zählen nur lebende
## Mitglieder im Umkreis gruppe_erfahrung_radius um den Getöteten; wer weiter
## weg ist, bekommt nichts.
##
## Wie viel: LevelRules.kill_shares – Grundwert nach Stufe des Gegners
## (gegner_stufenwerte.csv), Faktor des Rangs (gegner_raenge.csv),
## Stufenunterschied zur höchsten beteiligten Stufe (graue Gegner geben
## nichts), Gruppenbonus je weiterem Mitglied, Aufteilung nach Stufe gewichtet.
##
## Einheiten geben nur Erfahrung, wenn Unit.gives_experience() true ist
## (Gegner aus #38). Übungspuppen nicht; zum Testen gibt es im
## Entwickler-Panel „Ziel: Erfahrung wie für einen Kill“ (host_award_kill mit
## force), das denselben Weg geht.

const NODE_NAME := "Experience"
const GROUP := &"experience_service"

## Welt (GameWorld; als Node, damit keine zyklische Abhängigkeit entsteht).
var _world: Node = null


func _init() -> void:
	name = NODE_NAME
	add_to_group(GROUP)


## Der Dienst der laufenden Welt oder null.
static func get_instance(tree: SceneTree) -> ExperienceService:
	return tree.get_first_node_in_group(GROUP) as ExperienceService if tree != null else null


func setup(world: Node) -> void:
	_world = world
	if world.has_signal(&"unit_died"):
		world.unit_died.connect(_on_unit_died)


func _on_unit_died(unit: Unit, killer: Unit) -> void:
	if Network.is_host():
		host_award_kill(unit, killer)


## Host: Erfahrung für den Tod von victim verteilen. force = auch Einheiten,
## die sonst keine Erfahrung geben (Entwickler-Panel). Gibt Spielfigur →
## gutgeschriebene Erfahrung zurück.
func host_award_kill(victim: Unit, killer: Unit, force := false) -> Dictionary:
	var result := {}
	if not Network.is_host() or victim == null or (not force and not victim.gives_experience()):
		return result
	var player := killer as PlayerCharacter
	if player == null:
		return result
	var members := members_near(victim, get_group_members(player))
	if members.is_empty():
		return result
	var levels: Array[int] = []
	for member in members:
		levels.append(member.level)
	var shares := LevelRules.kill_shares(victim.get_level(), victim.get_rank_id(), levels)
	for i in members.size():
		var experience := members[i].get_experience()
		if experience == null or shares[i] <= 0:
			continue
		var added := experience.host_grant(shares[i], PlayerExperience.SOURCE_KILL, victim.get_unit_name())
		if added > 0:
			result[members[i]] = added
	return result


## Gruppe des Spielers: vorerst alle Spielfiguren der Sitzung (siehe oben).
func get_group_members(player: PlayerCharacter) -> Array[PlayerCharacter]:
	var result: Array[PlayerCharacter] = []
	if _world != null and _world.has_method(&"get_all_players"):
		result.assign(_world.get_all_players())
	if not result.has(player):
		result.append(player)
	return result


## Lebende Mitglieder im Umkreis gruppe_erfahrung_radius um victim.
static func members_near(victim: Unit, members: Array[PlayerCharacter]) -> Array[PlayerCharacter]:
	var radius := LevelRules.group_radius()
	var result: Array[PlayerCharacter] = []
	for member in members:
		if member == null or not is_instance_valid(member) or member.is_dead():
			continue
		if member.global_position.distance_to(victim.global_position) <= radius:
			result.append(member)
	return result
