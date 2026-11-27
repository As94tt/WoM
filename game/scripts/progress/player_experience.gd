class_name PlayerExperience
extends Node
## Erfahrung und Stufenaufstieg einer Spielfigur (Ticket #27). Kindknoten
## „Experience“ der Spielfigur (player.tscn), funktioniert ohne Interface.
##
## Zustand: Die Stufe ist PlayerCharacter.level (wie bisher über ServerSync),
## die gesammelte Erfahrung innerhalb der Stufe ist experience (ebenfalls über
## ServerSync, Authority Host). Kurve und Höchststufe: LevelRules.
##
## Zentrale Schnittstelle „Erfahrung gewähren (Quelle, Menge)“, nur auf dem
## Host: host_grant(amount, source, source_name). Quellen: SOURCE_KILL
## (ExperienceService, später Gegner aus #38), SOURCE_QUEST (Questsystem M5),
## SOURCE_DEV (Entwickler-Panel). Überschuss geht in die nächste Stufe,
## mehrere Aufstiege auf einmal funktionieren, auf der Höchststufe wird nichts
## mehr gesammelt. Tod kostet keine Erfahrung.
##
## Aufstieg (Host): Stufe setzen (Werte steigen nach klassenwachstum.csv,
## Volksboni bleiben), Spielerliste aktualisieren (Network.host_set_player_level,
## damit Namensplakette, Spielerliste und Gruppenrahmen die Stufe zeigen),
## Leben und Ressourcen auffüllen (nicht bei Toten) und allen Instanzen den
## Aufstieg melden (leveled_up: Effekt an der Figur bei allen, Meldung und
## Zusammenfassung nur beim Besitzer). Fähigkeiten, Spezialisierung und
## Talentpunkte folgen wie bisher der Stufe (PlayerAbilities, PlayerTalents).
##
## Netzwerk: Clients schreiben sich nie selbst Erfahrung gut. Wünsche aus dem
## Entwickler-Panel gehen per RPC an den Host (request_dev), der nur als
## Debug-Build zustimmt. Der Host schickt dem Besitzer, wofür er Erfahrung
## bekam (experience_gained: „+120 EP“ und Log), und allen in der Welt den
## Aufstieg. Gespeichert wird beim Besitzer: Ändern sich Stufe oder Erfahrung,
## schreibt er sie in den eigenen Charakter (CharacterData) und speichert.

## Erfahrung oder Stufe haben sich geändert (überall, z. B. Erfahrungsbalken).
signal experience_changed
## Nur beim Besitzer: Erfahrung erhalten. source_name z. B. Name des Gegners.
signal experience_gained(amount: int, source: StringName, source_name: String)
## Auf allen Instanzen in der Welt: Die Figur ist von previous auf level
## aufgestiegen (auch mehrere Stufen auf einmal).
signal leveled_up(previous: int, level: int)

const SOURCE_KILL := &"kill"
const SOURCE_QUEST := &"quest"
const SOURCE_DEV := &"dev"

## Erfahrung innerhalb der aktuellen Stufe. Vom Host gesetzt, über ServerSync
## übertragen.
var experience := 0:
	set(value):
		if value == experience:
			return
		experience = value
		_on_changed()

var _player: PlayerCharacter = null
## Host: Erfahrung des mitgebrachten Charakters (vor dem Erzeugen).
var _initial := 0
var _last_level := 0


func _enter_tree() -> void:
	_player = get_parent() as PlayerCharacter


func _ready() -> void:
	if _player == null:
		return
	_last_level = _player.level
	_player.unit_changed.connect(_on_unit_changed)
	if Network.is_host():
		var state := LevelRules.sanitize(_player.level, _initial)
		experience = int(state["experience"])


## Host (vor dem Erzeugen): Erfahrung des mitgebrachten Charakters.
func set_initial_experience(value: int) -> void:
	_initial = maxi(0, value)


# --- Lesen (überall) ---------------------------------------------------------

## Stufe des Charakters (ohne Entwickler-Übersteuerung der Werte).
func get_level() -> int:
	return _player.level if _player != null else 1


func is_max_level() -> bool:
	return get_level() >= LevelRules.max_level()


## Benötigte Erfahrung der aktuellen Stufe (0 auf der Höchststufe).
func get_needed() -> int:
	return LevelRules.needed_for(get_level())


## Text für den Erfahrungsbalken, z. B. „1.250 / 4.000 (31 %)“.
func get_progress_text() -> String:
	return progress_text(experience, get_needed())


static func progress_text(xp: int, needed: int) -> String:
	if needed <= 0:
		return "Höchststufe erreicht"
	return "%s / %s (%d %%)" % [StatFormat.grouped(xp), StatFormat.grouped(needed),
			floori(100.0 * xp / needed)]


# --- Host --------------------------------------------------------------------

## Host: Erfahrung gewähren (zentrale Schnittstelle, z. B. Kills, später
## Quests). Gibt die angerechnete Menge zurück (0 auf der Höchststufe).
func host_grant(amount: int, source: StringName, source_name := "") -> int:
	if not _require_host("host_grant") or amount <= 0:
		return 0
	var previous := get_level()
	var result := LevelRules.add_experience(previous, experience, amount)
	var added := int(result["added"])
	if added <= 0:
		return 0
	# Erst die Erfahrung melden, dann den Aufstieg (Reihenfolge im Log).
	_send_gained(added, source, source_name)
	_host_apply(int(result["level"]), int(result["experience"]), previous)
	return added


## Host: Stufe direkt setzen (Entwickler-Panel „Stufe setzen“, später z. B.
## Werkzeuge). Erfahrung beginnt bei 0. Höher = dieselben Freischaltungen wie
## ein echter Aufstieg; niedriger = nur die Stufe.
func host_set_level(level: int) -> void:
	if not _require_host("host_set_level"):
		return
	_host_apply(clampi(level, 1, LevelRules.max_level()), 0, get_level())


## Host: direkt zur nächsten Stufe aufsteigen (Entwickler-Panel).
func host_level_up() -> void:
	if _require_host("host_level_up") and not is_max_level():
		host_grant(LevelRules.missing_to_next(get_level(), experience), SOURCE_DEV, "Entwickler-Panel")


func _host_apply(level: int, xp: int, previous: int) -> void:
	experience = xp
	if level == previous:
		return
	# Meldung vor der neuen Stufe, damit „Stufe N erreicht!“ im Log vor den
	# neu erlernten Fähigkeiten steht (die Zusammenfassung rechnet nur mit
	# previous und level).
	if level > previous:
		_send_level_up(previous, level)
	_player.level = level
	Network.host_set_player_level(_player.peer_id, level)
	if level > previous:
		var stats := _player.get_stats()
		if stats != null and not _player.is_dead():
			stats.refill()


## Host: dem Besitzer melden, wofür er Erfahrung bekam.
func _send_gained(amount: int, source: StringName, source_name: String) -> void:
	if _player.peer_id == multiplayer.get_unique_id():
		experience_gained.emit(amount, source, source_name)
	elif Network.is_peer_in_world(_player.peer_id):
		_rpc_gained.rpc_id(_player.peer_id, amount, String(source), source_name)


## Host: allen in der Welt den Aufstieg melden (Effekt bei allen).
func _send_level_up(previous: int, level: int) -> void:
	leveled_up.emit(previous, level)
	for info in Network.get_players():
		if info.peer_id != multiplayer.get_unique_id() and info.in_world:
			_rpc_leveled_up.rpc_id(info.peer_id, previous, level)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_gained(amount: int, source: String, source_name: String) -> void:
	if multiplayer.get_remote_sender_id() == 1 and _player != null and _player.is_local():
		experience_gained.emit(amount, StringName(source), source_name)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_leveled_up(previous: int, level: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		leveled_up.emit(previous, level)


# --- Entwickler-Panel --------------------------------------------------------

## Wunsch aus dem Entwickler-Panel: „add“ (value = Menge), „level_up“,
## „set_level“ (value = Stufe), „reset“ (Erfahrung 0), „kill“ (value = Pfad
## des Ziels als Text: Erfahrung wie für einen Kill). Auf dem Host sofort,
## sonst als Wunsch an ihn (nur für die eigene Figur).
func request_dev(action: String, value: Variant = null) -> void:
	if Network.is_host():
		host_dev(action, value)
	else:
		_rpc_dev.rpc_id(1, action, value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_dev(action: String, value: Variant) -> void:
	if not Network.is_host() or not OS.is_debug_build() or _player == null:
		return
	if multiplayer.get_remote_sender_id() != _player.get_controlling_peer():
		return
	host_dev(action, value)


## Host: Aktion des Entwickler-Panels ausführen.
func host_dev(action: String, value: Variant) -> void:
	if not _require_host("host_dev"):
		return
	match action:
		"add":
			host_grant(maxi(0, int(value)) if value is int or value is float else 0, SOURCE_DEV,
					"Entwickler-Panel")
		"level_up":
			host_level_up()
		"set_level":
			host_set_level(int(value) if value is int or value is float else get_level())
		"reset":
			experience = 0
		"kill":
			# value = Pfad des Ziels: Erfahrung wie für einen Kill durch diese
			# Figur (auch Übungspuppen), über denselben Weg wie echte Kills.
			var target := Unit.from_path(get_tree(), NodePath(str(value)))
			var service := ExperienceService.get_instance(get_tree())
			if target != null and service != null and target != _player:
				service.host_award_kill(target, _player, true)
		_:
			push_warning("PlayerExperience: unbekannte Entwickler-Aktion %s." % action)


# --- Intern ------------------------------------------------------------------

func _on_unit_changed() -> void:
	if _player != null and _player.level != _last_level:
		_last_level = _player.level
		_on_changed()


func _on_changed() -> void:
	if not is_inside_tree():
		return
	experience_changed.emit()
	_save_to_character()


## Besitzer: Stufe und Erfahrung in den eigenen Charakter schreiben und
## speichern (Testcharaktere nie, siehe Network.save_local_character).
func _save_to_character() -> void:
	if _player == null or not _player.is_local():
		return
	var c := Network.get_local_character()
	if c == null or (c.level == _player.level and c.experience == experience):
		return
	c.level = _player.level
	c.experience = experience
	Network.save_local_character()


func _require_host(what: String) -> bool:
	if Network.is_host():
		return true
	push_warning("PlayerExperience.%s: nur der Host vergibt Erfahrung." % what)
	return false
