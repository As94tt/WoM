class_name Enemy
extends Unit
## Gegner (Ticket #36). Vollständig aus Daten erzeugt: Typ aus gegner.csv
## (enemy_id), Stufe vom Spawn (level, in der Spawngruppe gewürfelt).
##
## Werte (values_for): Grundwerte der Stufe aus gegner_stufenwerte.csv
## (fehlt die Stufe, gilt die höchste darunter) × Faktoren des Rangs aus
## gegner_raenge.csv × Modifikatoren des Gegnertyps (leben_mod, schaden_mod,
## ruestung_mod, zauberschutz_mod). Ausweichen, Parieren und Blocken kommen
## direkt aus gegner.csv (leere Zelle = Wertesystem). Sie gehen als feste
## Grundwerte in CharacterStats (get_stat_base_overrides), wie bei den
## Übungspuppen. Der Schaden (get_damage_range) wird erst von der KI (#37)
## genutzt; ebenso kampfart, angriffstempo, schule, faehigkeiten und
## ki_profil, die hier nur gelesen werden.
##
## Gesinnung, Rang, Immunitäten, Name und Titel kommen aus gegner.csv. Der
## Gegner gibt beim Tod Erfahrung (#27, ExperienceService; Gruppe bis #74 wie
## dort beschrieben). Er steht still (keine KI in #36).
##
## Graubox: Kapsel mit kleiner „Nase“ in Blickrichtung, Farbe der Familie
## (familien.csv) bzw. Spalte „farbe“, Größe = Spalte „groesse“ (Modell und
## Kollision). Tod: Das Modell kippt um (Unit.on_death_changed); die Leiche
## entfernt UnitCombat nach leiche_dauer Sekunden.
##
## Netzwerk: Der Host erzeugt Gegner (EnemySpawnManager, Entwickler-Panel)
## unter %Units; der UnitSpawner überträgt sie. „ServerSync“ überträgt
## enemy_id, level, Position und Drehung, „StatsSync“ Leben, Werte, Auren
## und Bedrohung, „CastSync“ Zauber (alle Authority Host). Clients leiten
## Name, Farbe und Größe aus denselben Tabellen ab.

## Spalte in gegner.csv → Wert im Wertesystem (Prozentwerte, leer = Formel).
const AVOIDANCE_COLUMNS := {"ausweichen": &"dodge", "parieren": &"parry", "blocken": &"block"}
## Graubox: Maße der Kapsel bei groesse 1 (wie die Kollision in enemy.tscn).
const BODY_RADIUS := 0.4
const BODY_HEIGHT := 1.8

## Zeile in gegner.csv. Beim Erzeugen gesetzt (Host) und übertragen.
@export var enemy_id: StringName = &"":
	set(value):
		enemy_id = value
		if is_node_ready():
			_apply_data()

## Stufe (vom Spawn gewürfelt bzw. Entwickler-Panel). Übertragen.
@export var level: int = 1:
	set(value):
		level = maxi(1, value)
		if is_node_ready():
			_apply_data()

var _row: TableRow = null

@onready var _stats: CharacterStats = $Stats
@onready var _server_sync: MultiplayerSynchronizer = $ServerSync
@onready var _stats_sync: MultiplayerSynchronizer = $StatsSync


func _enter_tree() -> void:
	# Die Synchronizer gehören immer dem Host.
	$ServerSync.set_multiplayer_authority(1)
	$StatsSync.set_multiplayer_authority(1)
	$CastSync.set_multiplayer_authority(1)


func _ready() -> void:
	for sync in [_server_sync, _stats_sync, $CastSync]:
		sync.add_visibility_filter(Network.is_peer_in_world)
	_apply_data()


## Sendet den Gegner auch an Peers, die inzwischen die Welt geladen haben.
func refresh_visibility() -> void:
	for sync in [_server_sync, _stats_sync, $CastSync]:
		sync.update_visibility()


# --- Daten -------------------------------------------------------------------

## Zeile in gegner.csv oder null.
func get_row() -> TableRow:
	return _row


## Grundwerte einer Stufe aus gegner_stufenwerte.csv. Fehlt die Stufe, gilt
## die höchste vorhandene darunter (darüber: die kleinste vorhandene).
static func level_row(p_level: int) -> TableRow:
	var exact := Data.gegner_stufenwerte(p_level)
	if exact != null:
		return exact
	var below: TableRow = null
	var lowest: TableRow = null
	for candidate: TableRow in Data.rows("gegner_stufenwerte"):
		var s := int(candidate.get_value("stufe", 0))
		if s <= p_level and (below == null or s > int(below.get_value("stufe", 0))):
			below = candidate
		if lowest == null or s < int(lowest.get_value("stufe", 0)):
			lowest = candidate
	return below if below != null else lowest


## Werte eines Gegnertyps auf einer Stufe: Stufe × Rang × Modifikatoren.
## Schlüssel: max_health, armor, spell_ward, damage_min, damage_max,
## experience (Grundwert × Rang, ohne Stufenunterschied) und die
## Ausweich-/Parier-/Blockchance, sofern in gegner.csv gesetzt. Leer, wenn
## Typ oder Stufenwerte fehlen.
static func values_for(id: StringName, p_level: int) -> Dictionary:
	var row := Data.gegner(id)
	var base := level_row(p_level)
	if row == null or base == null:
		return {}
	var rank := Data.gegner_rang(String(row.get_value("rang", "normal")))
	var health_factor := float(rank.get_value("leben_faktor", 1.0)) if rank != null else 1.0
	var damage_factor := float(rank.get_value("schaden_faktor", 1.0)) if rank != null else 1.0
	var xp_factor := float(rank.get_value("erfahrung_faktor", 1.0)) if rank != null else 1.0
	var damage_mod := float(row.get_value("schaden_mod", 1.0))
	var result := {
		&"max_health": roundf(float(base.get_value("leben", 1)) * health_factor
				* float(row.get_value("leben_mod", 1.0))),
		&"armor": roundf(float(base.get_value("ruestung", 0)) * float(row.get_value("ruestung_mod", 1.0))),
		&"spell_ward": roundf(float(base.get_value("zauberschutz", 0))
				* float(row.get_value("zauberschutz_mod", 1.0))),
		&"damage_min": float(base.get_value("schaden_min", 0)) * damage_factor * damage_mod,
		&"damage_max": float(base.get_value("schaden_max", 0)) * damage_factor * damage_mod,
		&"experience": roundi(float(base.get_value("erfahrung", 0)) * xp_factor),
	}
	result[&"max_health"] = maxf(1.0, result[&"max_health"])
	for column: String in AVOIDANCE_COLUMNS:
		if not row.is_blank(column):
			result[AVOIDANCE_COLUMNS[column]] = float(row.get_value(column, 0.0))
	return result


## Platzhalterfarbe: Spalte „farbe“ in gegner.csv, sonst die der Familie
## (familien.csv), sonst Weiß.
static func placeholder_color(id: StringName) -> Color:
	var row := Data.gegner(id)
	if row == null:
		return Color.WHITE
	if not row.is_blank("farbe"):
		return row.get_value("farbe", Color.WHITE)
	var family := Data.familie(StringName(str(row.get_value("familie", ""))))
	return family.get_value("farbe", Color.WHITE) if family != null else Color.WHITE


## Schaden eines Schlags vor Rüstung [min, max] (Stufe × Rang × schaden_mod),
## für den automatischen Angriff der KI (#37).
func get_damage_range() -> Vector2:
	var values := values_for(enemy_id, level)
	return Vector2(values.get(&"damage_min", 0.0), values.get(&"damage_max", 0.0))


## Familie (ID aus familien.csv), z. B. „tier“.
func get_family() -> StringName:
	return StringName(str(_row.get_value("familie", ""))) if _row != null else &""


# --- Einheit -----------------------------------------------------------------

func get_unit_name() -> String:
	return String(_row.get_value("name", enemy_id)) if _row != null else String(enemy_id)


func get_unit_title() -> String:
	return String(_row.get_value("titel", "")) if _row != null else ""


func get_stats() -> CharacterStats:
	return _stats


func get_base_level() -> int:
	return level


func get_base_reaction() -> Unit.Reaction:
	return Unit.reaction_from_id(String(_row.get_value("gesinnung", "feindlich"))) if _row != null \
			else Unit.Reaction.HOSTILE


func get_rank() -> Unit.Rank:
	return Unit.rank_from_id(String(_row.get_value("rang", "normal"))) if _row != null else Unit.Rank.NORMAL


## Gegner geben beim Tod Erfahrung (#27, ExperienceService).
func gives_experience() -> bool:
	return true


func get_stat_base_overrides() -> Dictionary:
	var values := values_for(enemy_id, level)
	var result := {}
	for stat: StringName in [&"max_health", &"armor", &"spell_ward", &"dodge", &"parry", &"block"]:
		if values.has(stat):
			result[stat] = values[stat]
	return result


func get_base_immunities() -> PackedStringArray:
	var result := PackedStringArray()
	if _row != null:
		for id: Variant in _row.get_value("immunitaeten", []):
			result.append(str(id))
	return result


# --- Intern ------------------------------------------------------------------

func _apply_data() -> void:
	_row = Data.gegner(enemy_id)
	if _row == null and enemy_id != &"":
		push_warning("Enemy: Gegner „%s“ fehlt in gegner.csv." % enemy_id)
	_apply_placeholder()
	if multiplayer.is_server() and _row != null:
		# Waffen-Zustände für die Platzhalter-Waffe (Combat.weapon_row, #37).
		var kind := String(_row.get_value("kampfart", "nahkampf"))
		_stats.set_flag(StatBlock.FLAG_MELEE_WEAPON, kind == "nahkampf")
		_stats.set_flag(StatBlock.FLAG_RANGED_WEAPON, kind == "fernkampf")
	_stats.refresh_from_unit()
	_stats.reapply()
	if multiplayer.is_server() and not is_dead():
		_stats.refill()
	unit_changed.emit()


## Graubox: Farbe und Größe aus den Daten.
func _apply_placeholder() -> void:
	var size := float(_row.get_value("groesse", 1.0)) if _row != null else 1.0
	var model := $Model as Node3D
	model.scale = Vector3.ONE * size
	var collision := $Collision as CollisionShape3D
	collision.scale = Vector3.ONE * size
	collision.position.y = BODY_HEIGHT / 2.0 * size
	var material := StandardMaterial3D.new()
	material.albedo_color = placeholder_color(enemy_id)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material
