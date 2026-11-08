class_name Unit
extends CharacterBody3D
## Gemeinsame Grundlage aller Einheiten (Ticket #31): Spielfiguren
## (PlayerCharacter), Übungspuppen (TrainingDummy), später NPCs und Gegner.
## Jede Einheit hat Name, Stufe, Leben und Ressourcen samt Werten (Kindknoten
## „Stats“, CharacterStats aus #19), eine Gesinnung und einen Rang. Seit #32
## dazu Auren, Zustände und Kampfzustand (Kindknoten „Combat“, UnitCombat);
## seit #35 auch Bedrohungsliste und Tod (ebenfalls UnitCombat).
##
## Schaden und Heilung im Spiel laufen über Combat.deal_damage/Combat.heal
## (Immunität, Umleitung, Absorption, Auslöser, Kampftext); apply_damage und
## apply_heal unten ändern nur das Leben und sind der letzte Schritt davon.
##
## Unterklassen überschreiben die Funktionen im Abschnitt „Für Unterklassen“.
## Alles andere (Entfernung, Sichtlinie, Blickrichtung, Gesinnung zueinander)
## ist für alle Einheiten gleich und wird von Zielauswahl, Fähigkeiten (#33),
## Trefferberechnung (#34) und KI benutzt.
##
## Netzwerk: Einheiten erzeugt der Host (MultiplayerSpawner). Leben und
## Ressourcen überträgt „StatsSync“ (Authority Host) an alle. Das aktuelle Ziel
## (current_target) und der automatische Angriff (auto_attacking) sind nur auf
## dem Host verlässlich: Spieler melden ihr Ziel per RPC (siehe
## PlayerCharacter.report_target), die KI setzt es später selbst.
##
## Einheiten werden über ihren Knotenpfad im Baum angesprochen (get_path()).
## Spawner legen Knoten auf allen Instanzen mit demselben Namen an, deshalb
## ist der Pfad überall gleich und kann per RPC verschickt werden
## (Unit.from_path).

## Name, Stufe, Gesinnung, Rang oder Sichtbarkeit haben sich geändert
## (Rahmen und Namensplaketten aktualisieren sich).
signal unit_changed
## Nur Host (#35): Die Einheit ist gestorben; killer = wer zuletzt Schaden
## gemacht hat (oder null). Ereignis für andere Systeme (später Erfahrung,
## Beute, Respawn, Quests). GameWorld meldet es zusätzlich als unit_died.
signal died(killer: Unit)

## Gesinnung gegenüber einer anderen Einheit. Farben im Theme (UnitColors).
enum Reaction { HOSTILE, NEUTRAL, FRIENDLY }
## Rang (gegner_raenge.csv, uebungspuppen.csv). Kennzeichnung am Zielrahmen.
enum Rank { NORMAL, ELITE, RARE, BOSS }

const GROUP := &"units"
## Ebene „Welt“: blockiert die Sichtlinie.
const LINE_OF_SIGHT_MASK := 1
## Augenhöhe als Anteil der Körpergröße (Start- und Endpunkt der Sichtlinie).
const EYE_HEIGHT := 0.85
## Abstand der Namensplakette über dem Kopf in Metern.
const NAMEPLATE_OFFSET := 0.4
## Rang-IDs in den Tabellen.
const RANK_IDS := {"normal": Rank.NORMAL, "elite": Rank.ELITE, "selten": Rank.RARE, "boss": Rank.BOSS}
const REACTION_IDS := {"feindlich": Reaction.HOSTILE, "neutral": Reaction.NEUTRAL,
		"freundlich": Reaction.FRIENDLY}

## Host: aktuelles Ziel dieser Einheit (null = keins, auch wenn das Ziel
## inzwischen entfernt wurde).
var current_target: Unit = null:
	get:
		return current_target if is_instance_valid(current_target) else null
## Host: automatischer Angriff auf current_target ist eingeschaltet
## (Rechtsklick auf einen Feind, Nahkampffähigkeit). Die Schläge führt seit
## #33 UnitCaster aus; Würfel und Rüstung rechnet seit #34 Combat.roll_damage.
var auto_attacking := false


func _init() -> void:
	add_to_group(GROUP)


# --- Für Unterklassen ------------------------------------------------------

## Anzeigename.
func get_unit_name() -> String:
	return String(name)


## Stufe, mit der gerechnet wird.
func get_level() -> int:
	var stats := get_stats()
	return stats.get_level() if stats != null and stats.is_node_ready() else 1


## Werte, Leben und Ressourcen (Kindknoten „Stats“) oder null.
func get_stats() -> CharacterStats:
	return get_node_or_null(^"Stats") as CharacterStats


## true bei Spielfiguren.
func is_player_unit() -> bool:
	return false


## Klasse (nur Spieler) oder null.
func get_class_data() -> ClassData:
	return null


## Gesinnung gegenüber Spielern (bei Spielern selbst: freundlich).
func get_base_reaction() -> Reaction:
	return Reaction.HOSTILE


func get_rank() -> Rank:
	return Rank.NORMAL


## Text, der über der Einheit dauerhaft steht (Übungspuppen: Schaden pro
## Sekunde). Leer = keiner.
func get_overhead_text() -> String:
	return ""


## Eingaben für CharacterStats: Klasse, Volk und Stufe ohne Entwickler-Panel.
func get_stat_class_id() -> StringName:
	return &""


func get_stat_race_id() -> StringName:
	return &""


func get_base_level() -> int:
	return 1


## Feste Grundwerte statt Formeln (siehe StatBlock), z. B. Leben einer Puppe.
func get_stat_base_overrides() -> Dictionary:
	return {}


## Peer, der für diese Einheit Wünsche an CharacterStats schicken darf
## (Entwickler-Panel); 1 = nur der Host.
func get_controlling_peer() -> int:
	return 1


## Host: Schaden nehmen. Gibt den tatsächlich abgezogenen Betrag zurück.
## Einstiegspunkt für die Trefferberechnung (#34) und das Entwickler-Panel.
func apply_damage(amount: float, _source: Unit = null) -> float:
	var stats := get_stats()
	return stats.take_damage(amount) if stats != null else 0.0


## Host: geheilt werden. Gibt die Überheilung zurück.
func apply_heal(amount: float, _source: Unit = null) -> float:
	var stats := get_stats()
	return stats.heal(amount) if stats != null else 0.0


## Immunitäten aus den Daten (IDs von Zuständen oder Schadensschulen, #32),
## z. B. Bosse. Auren können weitere geben (UnitCombat.is_immune_to).
func get_base_immunities() -> PackedStringArray:
	return PackedStringArray()


## Lässt sich die Einheit durch Effekte bewegen (Rückstoß, Heranziehen …)?
func can_be_moved() -> bool:
	return true


## Host: Einheit an eine Stelle setzen (Effekt „Bewegung“). Spielfiguren
## überschreiben das (ihr Besitzer bewegt sie).
func host_move_to(target: Transform3D) -> void:
	global_transform = target


# --- Auren und Zustände (#32) -----------------------------------------------

## Auren, Zustände und Kampfzustand (Kindknoten „Combat“) oder null.
func get_combat() -> UnitCombat:
	return get_node_or_null(^"Combat") as UnitCombat


## Fähigkeiten wirken (Kindknoten „Caster“, UnitCaster, #33) oder null.
func get_caster_node() -> UnitCaster:
	return get_node_or_null(^"Caster") as UnitCaster


## Getarnt (Zustand aus einer Aura).
func is_stealthed() -> bool:
	var combat := get_combat()
	return combat != null and combat.has_state(Combat.STATE_STEALTHED)


## Sichtbar für viewer: getarnte Einheiten sehen nur Freunde.
func is_visible_to(viewer: Unit) -> bool:
	if not is_unit_visible():
		return false
	if is_stealthed() and viewer != null and viewer != self and get_reaction_to(viewer) != Reaction.FRIENDLY:
		return false
	return true


## Von UnitCombat gerufen, wenn sich die Zustände geändert haben. Graubox der
## Tarnung: Für Feinde des lokalen Spielers verschwindet das Modell, für
## Freunde wird es halb durchsichtig.
func on_states_changed() -> void:
	var model := get_node_or_null(^"Model") as Node3D
	if model != null:
		var viewer := Unit.local_player(get_tree()) if is_inside_tree() else null
		model.visible = is_visible_to(viewer)
		var alpha := 0.5 if is_stealthed() else 0.0
		for node in model.find_children("*", "GeometryInstance3D", true, false):
			(node as GeometryInstance3D).transparency = alpha
	unit_changed.emit()


## Von UnitCombat gerufen, wenn die Einheit stirbt bzw. wieder lebt (#35,
## auf allen Instanzen). Graubox: Das Modell kippt nach hinten um.
func on_death_changed(dead: bool) -> void:
	var model := get_node_or_null(^"Model") as Node3D
	if model != null:
		model.rotation.x = -PI / 2.0 if dead else 0.0
	unit_changed.emit()


## Host (#35): Verschwindet die Einheit nach dem Tod nach leiche_dauer
## Sekunden? Gegner ja, Spielfiguren nie (sie kehren zurück).
func removes_corpse() -> bool:
	return not is_player_unit()


## Eigene Spielfigur dieser Instanz oder null.
static func local_player(tree: SceneTree) -> Unit:
	if tree == null:
		return null
	for unit in all_units(tree):
		if unit.is_player_unit() and unit.is_multiplayer_authority():
			return unit
	return null


# --- Zustand ----------------------------------------------------------------

## Tot (Leben 0, #35). Überall gleich, weil das Leben übertragen wird.
func is_dead() -> bool:
	var stats := get_stats()
	return stats != null and stats.max_health > 0.0 and stats.health <= 0.0


## Unsichtbare Einheiten können nicht per Tab gewählt werden. Tarnung (#32)
## prüft zusätzlich is_visible_to.
func is_unit_visible() -> bool:
	return is_visible_in_tree()


## Darf per Tab gewählt werden (lebt, sichtbar, noch im Baum).
func is_tab_targetable() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and not is_dead() and is_unit_visible()


## Gesinnung dieser Einheit gegenüber other. Spieler sind untereinander
## freundlich; andere Einheiten haben ihre Gesinnung gegenüber Spielern
## (Daten), gegenseitig gilt dieselbe. NPCs untereinander folgen später.
func get_reaction_to(other: Unit) -> Reaction:
	if other == null or other == self:
		return Reaction.FRIENDLY
	if is_player_unit() and other.is_player_unit():
		return Reaction.FRIENDLY
	if is_player_unit():
		return other.get_base_reaction()
	if other.is_player_unit():
		return get_base_reaction()
	return Reaction.FRIENDLY


## true, wenn other diese Einheit angreifen darf (feindlich oder neutral).
func can_be_attacked_by(other: Unit) -> bool:
	return other != null and other != self and get_reaction_to(other) != Reaction.FRIENDLY


# --- Raum: Entfernung, Sichtlinie, Blickrichtung ----------------------------

## Radius des Körpers in Metern (Kollisionskapsel „Collision“, mit Skalierung).
func get_body_radius() -> float:
	var shape := _body_shape()
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius * _body_scale()
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius * _body_scale()
	return 0.5


## Höhe des Körpers in Metern (Ursprung an den Füßen).
func get_body_height() -> float:
	var shape := _body_shape()
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).height * _body_scale()
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).height * _body_scale()
	return 1.8


## Augenpunkt (Start/Ende der Sichtlinie).
func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * get_body_height() * EYE_HEIGHT


## Punkt für die Namensplakette über dem Kopf.
func get_nameplate_position() -> Vector3:
	return global_position + Vector3.UP * (get_body_height() + NAMEPLATE_OFFSET)


## Blickrichtung (waagerecht, Länge 1). Vorderseite ist -Z.
func get_facing() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


## Entfernung zu other von Rand zu Rand in Metern (0 bei Berührung).
func distance_to_unit(other: Unit) -> float:
	return Unit.edge_distance(self, other)


## Entfernung zweier Einheiten von Rand zu Rand: waagerechter Abstand minus
## beide Radien, dazu der senkrechte Abstand, falls eine über der anderen
## steht (Höhe des Körpers).
static func edge_distance(a: Unit, b: Unit) -> float:
	if a == null or b == null:
		return INF
	var pa := a.global_position
	var pb := b.global_position
	var horizontal := maxf(0.0, Vector2(pb.x - pa.x, pb.z - pa.z).length()
			- a.get_body_radius() - b.get_body_radius())
	var vertical := maxf(0.0, maxf(pa.y - (pb.y + b.get_body_height()), pb.y - (pa.y + a.get_body_height())))
	return Vector2(horizontal, vertical).length()


## Sichtlinie: keine Wand (Ebene „Welt“) zwischen den Augenpunkten.
func has_line_of_sight_to(other: Unit) -> bool:
	if other == null or not is_inside_tree() or not other.is_inside_tree():
		return false
	if other == self:
		return true
	var query := PhysicsRayQueryParameters3D.create(get_eye_position(), other.get_eye_position(),
			LINE_OF_SIGHT_MASK, [get_rid(), other.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## other steht vor dieser Einheit (Winkel blickwinkel_vorne, Standard 180°,
## also die vordere Hälfte). angle_deg > 0 ersetzt den Wert aus den Daten.
func is_in_front(other: Unit, angle_deg := -1.0) -> bool:
	if other == null or other == self:
		return true
	if angle_deg <= 0.0:
		angle_deg = Data.konstante(&"blickwinkel_vorne", 180.0)
	return _angle_to(other.global_position, get_facing()) <= deg_to_rad(angle_deg) / 2.0


## Diese Einheit steht hinter target (Winkel blickwinkel_hinten, Standard
## 180°, also die hintere Hälfte des Ziels).
func is_behind(target: Unit, angle_deg := -1.0) -> bool:
	if target == null or target == self:
		return false
	if angle_deg <= 0.0:
		angle_deg = Data.konstante(&"blickwinkel_hinten", 180.0)
	return target._angle_to(global_position, -target.get_facing()) <= deg_to_rad(angle_deg) / 2.0


## Einheit zu einem Knotenpfad (aus einem RPC) oder null.
static func from_path(tree: SceneTree, path: NodePath) -> Unit:
	if path.is_empty() or tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(path) as Unit


## Alle Einheiten im Baum.
static func all_units(tree: SceneTree) -> Array[Unit]:
	var result: Array[Unit] = []
	for node in tree.get_nodes_in_group(GROUP):
		var unit := node as Unit
		if unit != null and unit.is_inside_tree() and not unit.is_queued_for_deletion():
			result.append(unit)
	return result


static func rank_from_id(id: String) -> Rank:
	return RANK_IDS.get(id, Rank.NORMAL)


static func reaction_from_id(id: String) -> Reaction:
	return REACTION_IDS.get(id, Reaction.HOSTILE)


# --- Intern -----------------------------------------------------------------

## Waagerechter Winkel zwischen direction und der Richtung zu point.
func _angle_to(point: Vector3, direction: Vector3) -> float:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	return direction.angle_to(to.normalized())


func _body_shape() -> Shape3D:
	var collision := get_node_or_null(^"Collision") as CollisionShape3D
	return collision.shape if collision != null else null


func _body_scale() -> float:
	var model := get_node_or_null(^"Model") as Node3D
	return model.scale.y if model != null else 1.0
