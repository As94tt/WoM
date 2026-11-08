class_name PlayerTalents
extends Node
## Spezialisierung und Talente einer Spielfigur (Ticket #20). Kindknoten
## „Talents“ der Spielfigur (player.tscn), funktioniert ohne Interface.
##
## Zustand (talent_state, nur einfache Typen):
##   {"spec": ID der Spezialisierung ("" = keine), "ranks": {Talent-ID: Rang},
##    "unlocked": [IDs freigeschalteter gesperrter Spezialisierungen],
##    "bonus": Bonuspunkte aus dem Entwickler-Panel}
## Talentpunkte werden nicht gespeichert, sondern berechnet
## (TalentRules.total_points aus der Stufe, ab Stufe 11 einer je Stufe).
##
## Wirksam ist die Spezialisierung ab Stufe 10 (spezialisierung_ab_stufe),
## die Talente, solange die ausgegebenen Punkte nicht mehr sind als die
## vorhandenen. Sinkt die Stufe (nur über das Entwickler-Panel möglich, die
## Stufe dort gilt nur für die Sitzung), bleibt die Wahl gespeichert und
## „ruht“, bis die Stufe wieder reicht.
##
## Netzwerk (Host entscheidet):
## - Der Host bekommt den Stand beim Beitreten mit dem Charakter
##   (CharacterData.to_dict → NetPlayerInfo.talents → host_load) und prüft
##   ihn (unbekannte Talente oder ungültige Stände werden verworfen).
## - talent_state überträgt „ServerSync“ der Figur (Authority Host) an alle;
##   jede Instanz rechnet daraus Zauberbuch, Aktionsleisten und Fenster.
## - Änderungen (wählen, übernehmen, zurücksetzen, wechseln, Entwickler-Panel)
##   schickt der Besitzer als Wunsch an den Host (request_*). Der Host prüft
##   mit TalentRules, setzt den Stand und meldet Ablehnungen an den Besitzer
##   zurück (request_failed).
## - Wirkung (nur Host): Verwandlungen als Veränderungen von Fähigkeiten
##   (Quelle „spec:<id>“), Talent-Effekte (z. B. „Fähigkeit verändern“, Quelle
##   „talent:<id>:<rang>:<n>“) und passive Talent-Auren über UnitCombat (#32).
##   Die Veränderungen überträgt UnitCombat wie gewohnt (ability_mod_state),
##   deshalb lösen alle Instanzen Fähigkeiten gleich auf.
## - Gespeichert wird beim Besitzer: Kommt ein neuer Stand vom Host an, schreibt
##   er ihn in den eigenen Charakter (CharacterData) und speichert.

## Stand oder Wirksamkeit (Stufe, Tod) haben sich geändert (überall).
signal talents_changed
## Fähigkeiten aus Talenten sind dazugekommen bzw. weggefallen (überall; nicht
## beim ersten Stand).
signal granted_changed(added: Array[AbilityData], removed: Array[AbilityData])
## Der Host hat einen Wunsch abgelehnt (nur beim Besitzer), reason ist ein Satz.
signal request_failed(reason: String)

const COMBAT_REASON := "Im Kampf nicht möglich."

## Übertragen über ServerSync (Authority Host), siehe oben.
var talent_state: Dictionary = {}:
	set(value):
		talent_state = value
		_on_state_changed()

var _player: PlayerCharacter = null
var _granted: Array[AbilityData] = []
var _granted_known := false
var _active_key := ""
## Alle Fähigkeiten, die irgendein Talent der Klasse geben kann (Cache).
var _talent_abilities: Array[AbilityData] = []
var _talent_abilities_class: StringName = &"-"

# --- nur Host ---
## Stand vom Beitreten, gesetzt von PlayerCharacter.setup_from_info.
var _initial: Dictionary = {}
var _applied_key := ""
var _applied_sources: Array[StringName] = []
var _applied_auras: Array[AuraData] = []
var _applied_extension: SpecializationExtension = null


func _enter_tree() -> void:
	_player = get_parent() as PlayerCharacter


func _ready() -> void:
	if _player == null:
		return
	var stats := _player.get_node_or_null(^"Stats") as CharacterStats
	if stats != null:
		stats.stats_changed.connect(_on_level_or_life_changed)
	var combat := _player.get_node_or_null(^"Combat") as UnitCombat
	if combat != null:
		combat.death_changed.connect(func(_dead: bool) -> void: _on_level_or_life_changed())
	if Network.is_host():
		host_load(_initial)
	else:
		_on_state_changed()


## Host (vor dem Erzeugen): Stand des mitgebrachten Charakters.
func set_initial_state(data: Dictionary) -> void:
	_initial = data.duplicate(true)


# --- Lesen (überall) ---------------------------------------------------------

func get_class_data() -> ClassData:
	return _player.get_class_data() if _player != null else null


## Spezialisierungen der Klasse in Reiterreihenfolge.
func get_specializations() -> Array[SpecializationData]:
	var class_data := get_class_data()
	return class_data.get_specializations() if class_data != null else []


func get_spec_id() -> StringName:
	return StringName(str(talent_state.get("spec", "")))


## Gewählte Spezialisierung (auch wenn sie gerade ruht) oder null.
func get_spec() -> SpecializationData:
	var class_data := get_class_data()
	var spec_id := get_spec_id()
	return class_data.get_specialization(spec_id) if class_data != null and spec_id != &"" else null


func has_spec() -> bool:
	return get_spec() != null


func get_tree_data() -> TalentTreeData:
	var spec := get_spec()
	return spec.talent_tree if spec != null else null


## Bestätigte Ränge (Kopie).
func get_ranks() -> Dictionary:
	return TalentRules.clean_ranks(talent_state.get("ranks", {}))


func get_rank(talent_id: StringName) -> int:
	return TalentRules.rank_of(get_ranks(), talent_id)


func get_bonus_points() -> int:
	return maxi(0, int(talent_state.get("bonus", 0)))


func get_unlocked_ids() -> PackedStringArray:
	var result := PackedStringArray()
	var list: Variant = talent_state.get("unlocked", [])
	if list is Array or list is PackedStringArray:
		for entry: Variant in list:
			result.append(str(entry))
	return result


## Gesperrte Spezialisierungen sind wählbar, sobald sie freigeschaltet sind.
func is_spec_unlocked(spec: SpecializationData) -> bool:
	return spec != null and (not spec.locked or get_unlocked_ids().has(String(spec.id)))


func get_level() -> int:
	return _player.get_level() if _player != null else 1


## Stufe reicht für die Wahl einer Spezialisierung.
func has_spec_level() -> bool:
	return get_level() >= TalentRules.spec_level()


## Spezialisierung gewählt und Stufe reicht: Verwandlungen gelten.
func is_spec_active() -> bool:
	return has_spec() and has_spec_level()


## Alle Talentpunkte (Stufe und Bonus).
func get_total_points() -> int:
	return TalentRules.total_points(get_level(), get_bonus_points())


func get_spent_points() -> int:
	return TalentRules.spent(get_ranks())


## Freie Punkte (kann negativ sein, wenn die Stufe gesunken ist).
func get_free_points() -> int:
	return get_total_points() - get_spent_points()


## Talente wirken: Spezialisierung wirksam und genug Punkte.
func are_talents_active() -> bool:
	return is_spec_active() and get_spent_points() <= get_total_points()


## Fähigkeiten, die die Figur gerade durch Talente (und die Erweiterung der
## Spezialisierung) hat, in Reihenfolge des Baums.
func get_granted_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	var spec := get_spec()
	if spec == null or not is_spec_active():
		return result
	if spec.extension != null:
		for ability in spec.extension.get_extra_abilities(_player):
			if ability != null and not result.has(ability):
				result.append(ability)
	if spec.talent_tree == null or not are_talents_active():
		return result
	var ranks := get_ranks()
	for talent in spec.talent_tree.get_all_talents():
		if TalentRules.rank_of(ranks, talent.id) > 0:
			for ability in talent.grants_abilities:
				if ability != null and not result.has(ability):
					result.append(ability)
	return result


func has_granted(ability: AbilityData) -> bool:
	return ability != null and _current_granted().has(ability)


## true, wenn ability nur über Talente (irgendeiner Spezialisierung der
## Klasse) zu bekommen ist.
func is_talent_ability(ability: AbilityData) -> bool:
	if ability == null:
		return false
	var class_data := get_class_data()
	var class_id := class_data.id if class_data != null else &""
	if class_id != _talent_abilities_class:
		_talent_abilities_class = class_id
		_talent_abilities.clear()
		for spec in get_specializations():
			if spec.talent_tree != null:
				for granted in spec.talent_tree.get_all_granted_abilities():
					if not _talent_abilities.has(granted):
						_talent_abilities.append(granted)
			if spec.extension != null:
				for granted in spec.extension.get_extra_abilities(_player):
					if granted != null and not _talent_abilities.has(granted):
						_talent_abilities.append(granted)
	return _talent_abilities.has(ability)


func is_in_combat() -> bool:
	var stats := _player.get_stats() if _player != null else null
	return stats != null and stats.is_in_combat()


## Warum gerade nichts geändert werden darf (leer = geht): im Kampf.
func get_change_block_reason() -> String:
	return COMBAT_REASON if is_in_combat() else ""


## Kurzer Text für Entwickler-Panel und Tests: Spezialisierung, Ränge, Punkte,
## Quellen der Wirkung.
func describe() -> PackedStringArray:
	var spec := get_spec()
	var lines: PackedStringArray = []
	lines.append("Spezialisierung: %s%s" % [spec.display_name if spec != null else "keine",
			"" if spec == null or is_spec_active() else " (ruht, Stufe zu niedrig)"])
	lines.append("Punkte: %d frei von %d (Bonus %d)" % [get_free_points(), get_total_points(), get_bonus_points()])
	var tree := get_tree_data()
	var ranks := get_ranks()
	if tree != null:
		for talent in tree.get_all_talents():
			var rank := TalentRules.rank_of(ranks, talent.id)
			if rank > 0:
				lines.append("  %s %d/%d" % [talent.display_name, rank, tree.get_row_of(talent.id).max_rank_of(talent)])
	if not get_unlocked_ids().is_empty():
		lines.append("Freigeschaltet: %s" % ", ".join(get_unlocked_ids()))
	if Network.is_host() and not _applied_sources.is_empty():
		lines.append("Wirkung: %s" % ", ".join(_applied_sources))
	if Network.is_host() and not _applied_auras.is_empty():
		var names: PackedStringArray = []
		for aura in _applied_auras:
			names.append(aura.display_name)
		lines.append("Talent-Auren: %s" % ", ".join(names))
	return lines


# --- Wünsche (Besitzer → Host) -----------------------------------------------

## Spezialisierung wählen (ab Stufe 10, außerhalb des Kampfes).
func request_choose_spec(spec_id: StringName) -> void:
	_send("choose", String(spec_id))


## Vorläufige Ränge übernehmen (der ganze gewünschte Stand).
func request_apply(ranks: Dictionary) -> void:
	_send("apply", TalentRules.clean_ranks(ranks))


## Alle Talente zurücksetzen (Spezialisierung bleibt).
func request_reset() -> void:
	_send("reset", null)


## „Spezialisierung wechseln“: Wahl aufheben, alle Talente zurück.
func request_clear_spec() -> void:
	_send("clear", null)


## Entwickler-Panel: „unlock“ (value = Spezialisierungs-ID, leer = alle),
## „points“ (value = Anzahl Bonuspunkte dazu), „reset_spec“ (auch im Kampf).
func request_dev(action: String, value: Variant = null) -> void:
	_send("dev_" + action, value)


func _send(action: String, value: Variant) -> void:
	if Network.is_host():
		var reason := host_request(action, value)
		if reason != "":
			request_failed.emit(reason)
	else:
		_rpc_request.rpc_id(1, action, value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(action: String, value: Variant) -> void:
	if not Network.is_host() or _player == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != _player.get_controlling_peer():
		return
	var reason := host_request(action, value)
	if reason != "":
		_rpc_failed.rpc_id(sender, reason)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_failed(reason: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		request_failed.emit(reason)


# --- Host --------------------------------------------------------------------

## Host: Wunsch prüfen und ausführen. Gibt den Grund einer Ablehnung zurück
## (leer = ausgeführt).
func host_request(action: String, value: Variant) -> String:
	if not Network.is_host() or _player == null:
		return "Nur der Host ändert Talente."
	if action.begins_with("dev_"):
		if not OS.is_debug_build():
			return "Nur im Entwicklungsmodus."
		return _host_dev(action.substr(4), value)
	if _player.is_dead() and action == "apply":
		return "Im Tod nicht möglich."
	if is_in_combat():
		return COMBAT_REASON
	var class_data := get_class_data()
	match action:
		"choose":
			var spec := class_data.get_specialization(StringName(str(value))) if class_data != null else null
			if spec == null:
				return "Unbekannte Spezialisierung."
			if not has_spec_level():
				return "Spezialisierung ab Stufe %d." % TalentRules.spec_level()
			if not is_spec_unlocked(spec):
				return "Noch nicht entdeckt."
			if has_spec():
				return "Erst die Spezialisierung wechseln."
			_host_set({"spec": String(spec.id), "ranks": {}})
		"apply":
			var tree := get_tree_data()
			if tree == null or not is_spec_active():
				return "Erst eine Spezialisierung wählen."
			var ranks := TalentRules.clean_ranks(value)
			var problem := TalentRules.validate(tree, ranks, get_total_points())
			if problem != "":
				return problem
			_host_set({"ranks": ranks})
		"reset":
			_host_set({"ranks": {}})
		"clear":
			_host_set({"spec": "", "ranks": {}})
		_:
			return "Unbekannter Wunsch."
	return ""


func _host_dev(action: String, value: Variant) -> String:
	match action:
		"unlock":
			var unlocked := get_unlocked_ids()
			for spec in get_specializations():
				if spec.locked and (str(value) == "" or str(value) == String(spec.id)) \
						and not unlocked.has(String(spec.id)):
					unlocked.append(String(spec.id))
			_host_set({"unlocked": Array(unlocked)})
		"points":
			var amount := int(value) if value is int or value is float else 0
			_host_set({"bonus": clampi(get_bonus_points() + amount, 0, 100)})
		"reset_spec":
			_host_set({"spec": "", "ranks": {}})
		_:
			return "Unbekannter Wunsch."
	return ""


## Host: Stand eines Charakters übernehmen (Beitreten). Unbekannte
## Spezialisierungen, nicht freigeschaltete gesperrte und ungültige Ränge
## werden verworfen; Stufe und Punkte prüft erst die Wirksamkeit.
func host_load(data: Dictionary) -> void:
	if not Network.is_host():
		return
	talent_state = sanitize(get_class_data(), data)


## Bereinigter Stand für class_data (reine Funktion, auch für Tests).
static func sanitize(class_data: ClassData, data: Dictionary) -> Dictionary:
	var result := {"spec": "", "ranks": {}, "unlocked": [], "bonus": 0}
	if class_data == null:
		return result
	var unlocked: Array = []
	var list: Variant = data.get("unlocked", [])
	if list is Array or list is PackedStringArray:
		for entry: Variant in list:
			var spec := class_data.get_specialization(StringName(str(entry)))
			if spec != null and spec.locked and not unlocked.has(String(spec.id)):
				unlocked.append(String(spec.id))
	result["unlocked"] = unlocked
	result["bonus"] = clampi(int(data.get("bonus", 0)), 0, 100)
	var spec := class_data.get_specialization(StringName(str(data.get("spec", ""))))
	if spec == null or (spec.locked and not unlocked.has(String(spec.id))):
		return result
	result["spec"] = String(spec.id)
	var ranks := TalentRules.clean_ranks(data.get("ranks", {}))
	if spec.talent_tree != null and TalentRules.validate(spec.talent_tree, ranks, -1) == "":
		result["ranks"] = ranks
	return result


## Host: Teile des Stands ändern (neues Dictionary, damit ServerSync es merkt).
func _host_set(changes: Dictionary) -> void:
	var state := sanitize(get_class_data(), talent_state)
	for key: String in changes:
		state[key] = changes[key]
	talent_state = state


## Host: Wirkung an den Stand anpassen (nur wenn sich etwas geändert hat).
func _host_refresh() -> void:
	if not Network.is_host() or _player == null or not is_inside_tree():
		return
	var key := _wanted_key()
	if key == _applied_key:
		return
	_host_remove_applied()
	_applied_key = key
	var combat := _player.get_combat()
	var spec := get_spec()
	if combat == null or spec == null or not is_spec_active():
		return
	var dead := _player.is_dead()
	var mods := spec.get_transform_modifiers()
	if not mods.is_empty():
		var source := StringName("spec:%s" % spec.id)
		combat.add_ability_modifiers(source, mods, spec.display_name)
		_applied_sources.append(source)
	if spec.extension != null:
		spec.extension.on_activated(_player)
		_applied_extension = spec.extension
	if spec.talent_tree == null or not are_talents_active():
		return
	var ranks := get_ranks()
	for talent in spec.talent_tree.get_all_talents():
		var rank := TalentRules.rank_of(ranks, talent.id)
		if rank <= 0:
			continue
		for step in range(1, rank + 1):
			for index in talent.effects.size():
				var effect := talent.effects[index]
				if effect == null:
					continue
				var source := StringName("talent:%s:%d:%d" % [talent.id, step, index])
				if effect is ModifyAbilityEffect:
					combat.add_ability_modifiers(source, (effect as ModifyAbilityEffect).modifiers, talent.display_name)
					_applied_sources.append(source)
				elif not dead:
					Combat.execute([effect], EffectContext.create(_player, _player, source, talent.display_name))
		if dead:
			continue
		for aura in talent.auras:
			if aura != null and combat.apply_aura(aura, _player,
					EffectContext.create(_player, _player, StringName("talent:%s" % talent.id), talent.display_name),
					rank) != null:
				_applied_auras.append(aura)


func _host_remove_applied() -> void:
	var combat := _player.get_combat() if _player != null else null
	if combat != null:
		for source in _applied_sources:
			combat.remove_ability_modifiers(source)
		for aura in _applied_auras:
			combat.remove_aura(aura.id, _player)
	_applied_sources.clear()
	_applied_auras.clear()
	if _applied_extension != null:
		_applied_extension.on_deactivated(_player)
		_applied_extension = null


## Schlüssel der gewünschten Wirkung: ändert sich, wenn Spezialisierung,
## Ränge, Wirksamkeit oder Tod (Auren wirken nur auf Lebende) sich ändern.
func _wanted_key() -> String:
	if not is_spec_active():
		return ""
	var parts: PackedStringArray = [String(get_spec_id())]
	if are_talents_active():
		var ranks := get_ranks()
		var keys := ranks.keys()
		keys.sort()
		for key: Variant in keys:
			parts.append("%s=%d" % [key, int(ranks[key])])
	if _player.is_dead():
		parts.append("tot")
	return "|".join(parts)


# --- Änderungen (überall) ----------------------------------------------------

func _on_state_changed() -> void:
	if not is_inside_tree() or _player == null:
		return
	_update_granted()
	_active_key = _activity_key()
	talents_changed.emit()
	_host_refresh()
	_save_to_character()


## Stufe oder Tod geändert: Wirksamkeit neu bestimmen.
func _on_level_or_life_changed() -> void:
	var key := _activity_key()
	if key != _active_key:
		_active_key = key
		_update_granted()
		talents_changed.emit()
	_host_refresh()


func _activity_key() -> String:
	return "%s|%s|%d" % [is_spec_active(), are_talents_active(), get_total_points()]


func _current_granted() -> Array[AbilityData]:
	return _granted if _granted_known else get_granted_abilities()


func _update_granted() -> void:
	var now := get_granted_abilities()
	if not _granted_known:
		_granted = now
		_granted_known = true
		return
	var added: Array[AbilityData] = []
	var removed: Array[AbilityData] = []
	for ability in now:
		if not _granted.has(ability):
			added.append(ability)
	for ability in _granted:
		if not now.has(ability):
			removed.append(ability)
	_granted = now
	if not added.is_empty() or not removed.is_empty():
		granted_changed.emit(added, removed)


## Besitzer: bestätigten Stand in den eigenen Charakter schreiben und speichern.
func _save_to_character() -> void:
	if _player == null or not _player.is_local():
		return
	var c := Network.get_local_character()
	if c == null:
		return
	if c.get_talent_dict() == CharacterData.from_dict({"talents": talent_state}).get_talent_dict():
		return
	c.set_talent_dict(talent_state)
	Network.save_local_character()
