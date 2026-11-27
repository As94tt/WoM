class_name PlayerEquipment
extends Node
## Ausrüstung einer Spielfigur (Ticket #29). Kindknoten „Equipment“ der
## Spielfigur (player.tscn), aufgebaut nach dem Muster von PlayerTalents.
## Die Regeln stehen in EquipmentRules (reine Logik), die Inhalte in den
## Tabellen.
##
## Zustand (equipment_state, nur einfache Typen): {Platz-ID: Gegenstands-ID}
## als Strings, nur belegte Plätze. Eine Zweihandwaffe steht in der Haupthand,
## die Nebenhand bleibt leer.
##
## Netzwerk (Host entscheidet):
## - Der Host bekommt den Stand beim Beitreten mit dem Charakter
##   (CharacterData.to_dict → NetPlayerInfo.equipment → host_load) und prüft
##   ihn mit EquipmentRules.sanitize (unbekannte Gegenstände, falsche Plätze,
##   Klasse, Mindeststufe, Einzigartig angelegt). Ungültiges fällt heraus.
## - equipment_state überträgt „ServerSync“ der Figur (Authority Host) an alle.
##   #72 zeigt daraus später die Ausrüstung am Charakter.
## - Anlegen und Ablegen schickt der Besitzer als Wunsch an den Host
##   (request_equip_from_bag, request_unequip → _rpc_request). Der Host prüft
##   Regeln, Kampf (nur Waffen, ohne laufenden globalen Cooldown oder Zauber;
##   der Wechsel startet den globalen Cooldown) und Tod, setzt den Stand und
##   antwortet dem Besitzer mit Ergebnis oder Grund (_rpc_result).
## - Das Inventar liegt nur beim Besitzer (#18). Erst nach der Bestätigung des
##   Hosts verschiebt der Besitzer den Gegenstand zwischen Tasche und Platz
##   (Inventory.replace_item bzw. put_item). Vorher prüft er selbst, ob in der
##   Tasche Platz für die verdrängten Gegenstände ist. Ob der Spieler den
##   Gegenstand wirklich besitzt, prüft der Host noch nicht (kommt mit Beute
##   und Handel, #38).
## - Wirkung (nur Host): Werte als Modifikatoren (Quelle „item:ID:PLATZ“,
##   Quellname = Gegenstandsname), Effekte als versteckte, dauerhafte Auren
##   über UnitCombat, Waffen-Zustände (Nahkampfwaffe, Schild, Nebenhandwaffe,
##   Fernkampfwaffe) für Werte und automatischen Angriff.
## - Gespeichert wird beim Besitzer: Kommt ein neuer Stand vom Host an, schreibt
##   er ihn in den eigenen Charakter (CharacterData.equipment) und speichert.
##   Was der Host beim Beitreten verworfen hat, legt der Besitzer zurück in die
##   Tasche (attach_inventory); ist dort kein Platz, geht es verloren (Meldung).
## - Mindeststufe gilt nur beim Anlegen und Beitreten: Sinkt die Stufe
##   (Entwickler-Panel), bleibt der Gegenstand angelegt und wirkt.

## Stand geändert (überall).
signal equipment_changed
## Der Host hat einen Wunsch abgelehnt bzw. eine lokale Vorprüfung schlug fehl
## (nur beim Besitzer), reason ist ein Satz.
signal request_failed(reason: String)
## Hinweis für das Log (nur beim Besitzer), z. B. verworfene Ausrüstung.
signal notice(message: String)
## Stufe oder Klasse geändert: Nutzbarkeit in der Tasche neu zeigen.
signal usability_changed

## Übertragen über ServerSync (Authority Host), siehe oben.
var equipment_state: Dictionary = {}:
	set(value):
		equipment_state = value
		_on_state_changed()

var _player: PlayerCharacter = null
## Nur beim Besitzer: Inventar des Charakters (GameWorld.attach_inventory).
var _inventory: Inventory = null
## Besitzer: Stand mit dem Charakter abgeglichen (erst danach speichern).
var _reconciled := false
## Besitzer: offene Wünsche, Nummer → {action, item, place, from, to}.
var _pending: Dictionary = {}
var _next_request := 1

# --- nur Host ---
var _initial: Dictionary = {}
## Platz → [Gegenstand, Array[AuraData]] der angewendeten Wirkung.
var _applied: Dictionary = {}


func _enter_tree() -> void:
	_player = get_parent() as PlayerCharacter


func _ready() -> void:
	if _player == null:
		return
	var stats := _player.get_node_or_null(^"Stats") as CharacterStats
	if stats != null:
		stats.level_changed.connect(func(_level: int, _previous: int) -> void: usability_changed.emit())
	if Network.is_host():
		host_load(_initial)
	else:
		_on_state_changed()


## Host (vor dem Erzeugen): Stand des mitgebrachten Charakters.
func set_initial_state(data: Dictionary) -> void:
	_initial = data.duplicate(true)


# --- Lesen (überall) ---------------------------------------------------------

## Gegenstand in einem Platz oder &"".
func get_item(place: StringName) -> StringName:
	return StringName(str(equipment_state.get(String(place), "")))


func has_item(place: StringName) -> bool:
	return get_item(place) != &""


## Waffentyp in einer Hand (&"haupthand", &"nebenhand", &"fernkampf") oder &""
## (für spätere Systeme, z. B. Waffenvorlieben).
func get_weapon_type(hand: StringName) -> StringName:
	return ItemInfo.weapon_type(get_item(hand))


## Waffenwerte des Gegenstands im Platz (Felder wie platzhalterwaffen.csv)
## oder null, wenn dort keine Waffe mit Schaden liegt.
func get_weapon_row(place: StringName) -> TableRow:
	return EquipmentRules.weapon_row(get_item(place))


## Wie oft der Gegenstand angelegt ist (für „Einzigartig“ im Inventar).
func count_equipped(item_id: StringName) -> int:
	var count := 0
	for place: String in equipment_state:
		if StringName(str(equipment_state[place])) == item_id:
			count += 1
	return count


func get_average_item_level() -> float:
	return EquipmentRules.average_item_level(equipment_state)


## Die Nebenhand ist durch eine Zweihandwaffe belegt.
func is_off_hand_blocked() -> bool:
	var main := get_item(EquipmentRules.MAIN_HAND)
	return main != &"" and EquipmentRules.occupies_both_hands(main)


func get_class_id() -> StringName:
	return _player.class_id if _player != null else &""


func get_level() -> int:
	return _player.get_level() if _player != null else 1


## Warum der Charakter den Gegenstand nicht nutzen kann ("" = nutzbar).
func get_usable_reason(item_id: StringName) -> String:
	return EquipmentRules.usable_reason(item_id, get_class_id(), get_level())


func can_use(item_id: StringName) -> bool:
	return get_usable_reason(item_id) == ""


## Platz, den ein Rechtsklick auf den Gegenstand wählt.
func choose_place(item_id: StringName) -> StringName:
	return EquipmentRules.choose_place(item_id, equipment_state, get_class_id())


## Gegenstände, die beim Anlegen von item_id in place verdrängt würden
## (Platz → Gegenstand; für den Vergleich im Tooltip).
func get_replaced(item_id: StringName, place: StringName) -> Dictionary:
	var check := EquipmentRules.check_equip(item_id, place, equipment_state, get_class_id(), 999)
	if bool(check["ok"]):
		return check["displaced"]
	var result := {}
	if has_item(place):
		result[String(place)] = String(get_item(place))
	return result


func is_in_combat() -> bool:
	var stats := _get_stats()
	return stats != null and stats.is_in_combat()


## Werte der Figur (auch vor ihrem _ready, deshalb über den Knotennamen).
func _get_stats() -> CharacterStats:
	return _player.get_node_or_null(^"Stats") as CharacterStats if _player != null else null


## Globaler Cooldown läuft oder ein Zauber wird gewirkt.
func is_busy() -> bool:
	var caster := _player.get_caster_node() if _player != null else null
	return caster != null and caster.is_busy()


## Kurzer Text für Entwickler-Panel und Tests.
func describe() -> PackedStringArray:
	var lines: PackedStringArray = []
	for place in EquipmentRules.all_places():
		if has_item(place):
			lines.append("%s: %s" % [EquipmentRules.place_name(place), ItemInfo.display_name(get_item(place))])
	lines.append("Durchschnittliche Gegenstandsstufe: %s" % StatFormat.number(get_average_item_level(), 1))
	return lines


# --- Inventar (nur Besitzer) -------------------------------------------------

## Verbindet das Inventar des eigenen Charakters (GameWorld, einmal je Welt).
## Gleicht danach den gespeicherten Stand mit dem des Hosts ab: Was der Host
## verworfen hat, kommt zurück in die Tasche (oder geht verloren, wenn dort
## kein Platz ist).
func attach_inventory(inventory: Inventory) -> void:
	_inventory = inventory
	if _inventory != null:
		_inventory.owned_elsewhere = count_equipped
	_reconcile_with_character()


func get_inventory() -> Inventory:
	return _inventory


func _reconcile_with_character() -> void:
	var c := Network.get_local_character()
	if c != null and _inventory != null:
		for place: Variant in c.equipment.keys():
			var saved := StringName(str(c.equipment[place]))
			if saved == &"" or get_item(StringName(str(place))) == saved:
				continue
			var item_name := ItemInfo.display_name(saved) if ItemInfo.exists(saved) else String(saved)
			if not ItemInfo.exists(saved):
				notice.emit("Ausrüstung: Unbekannter Gegenstand „%s“ entfernt." % saved)
			elif _inventory.add_item(saved, 1, false) == Inventory.AddResult.ADDED:
				notice.emit("Ausrüstung: %s passt nicht (mehr) und liegt jetzt in der Tasche." % item_name)
			else:
				notice.emit("Ausrüstung: %s passt nicht (mehr) und ging verloren, die Tasche ist voll." % item_name)
	_reconciled = true
	_save_to_character()


# --- Wünsche (Besitzer → Host) -----------------------------------------------

## Gegenstand vom Taschenplatz (container, index) anlegen; place leer =
## Platz wie beim Rechtsklick. Prüft vorher selbst Regeln und Taschenplatz.
func request_equip_from_bag(container: int, index: int, place: StringName = &"") -> void:
	if _inventory == null:
		return
	var item_id: StringName = _inventory.get_slot(container, index).get("id", &"")
	if item_id == &"":
		return
	if place == &"":
		place = choose_place(item_id)
	var check := EquipmentRules.check_equip(item_id, place, equipment_state, get_class_id(), get_level(),
			is_in_combat(), is_busy())
	if not bool(check["ok"]):
		request_failed.emit(str(check["reason"]))
		return
	if _player != null and _player.is_dead():
		request_failed.emit(EquipmentRules.MSG_DEAD)
		return
	var displaced: Dictionary = check["displaced"]
	if displaced.size() - 1 > _inventory.get_free_slots():
		request_failed.emit(Inventory.MSG_FULL)
		return
	_send({"action": "equip", "item": String(item_id), "place": String(place),
			"from": Vector2i(container, index)})


## Gegenstand aus place ablegen, auf den Taschenplatz (container, index) bzw.
## (wenn der belegt ist oder keiner angegeben) in den ersten freien.
func request_unequip(place: StringName, container := -1, index := -1) -> void:
	if _inventory == null:
		return
	var check := EquipmentRules.check_unequip(place, equipment_state, is_in_combat(), is_busy())
	if not bool(check["ok"]):
		request_failed.emit(str(check["reason"]))
		return
	if _inventory.get_free_slots() < 1:
		request_failed.emit(Inventory.MSG_FULL)
		return
	_send({"action": "unequip", "item": str(check["item"]), "place": String(place),
			"to": Vector2i(container, index)})


func _send(request: Dictionary) -> void:
	var id := _next_request
	_next_request += 1
	_pending[id] = request
	if Network.is_host():
		var result := host_request(str(request["action"]), StringName(str(request["item"])),
				StringName(str(request["place"])))
		_on_result(id, bool(result["ok"]), str(result["reason"]), result.get("displaced", {}))
	else:
		_rpc_request.rpc_id(1, id, str(request["action"]), str(request["item"]), str(request["place"]))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(id: int, action: String, item_id: String, place: String) -> void:
	if not Network.is_host() or _player == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != _player.get_controlling_peer():
		return
	var result := host_request(action, StringName(item_id), StringName(place))
	_rpc_result.rpc_id(sender, id, bool(result["ok"]), str(result["reason"]), result.get("displaced", {}))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_result(id: int, ok: bool, reason: String, displaced: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_on_result(id, ok, reason, displaced)


## Besitzer: Antwort des Hosts. Erst jetzt wandern die Gegenstände zwischen
## Tasche und Platz.
func _on_result(id: int, ok: bool, reason: String, displaced: Dictionary) -> void:
	var request: Dictionary = _pending.get(id, {})
	_pending.erase(id)
	if not ok:
		request_failed.emit(reason)
		return
	if request.is_empty() or _inventory == null:
		return
	var item_id := StringName(str(request["item"]))
	if str(request["action"]) == "equip":
		var incoming: Array[StringName] = []
		for place: Variant in displaced.keys():
			incoming.append(StringName(str(displaced[place])))
		var from: Vector2i = request["from"]
		var message := _inventory.replace_item(from.x, from.y, item_id, incoming)
		if message != "":
			# Kann nur passieren, wenn sich die Tasche inzwischen gefüllt hat.
			for other in incoming:
				if _inventory.add_item(other, 1, false) != Inventory.AddResult.ADDED:
					notice.emit("Ausrüstung: %s ging verloren, die Tasche ist voll." % ItemInfo.display_name(other))
	else:
		var to: Vector2i = request.get("to", Vector2i(-1, -1))
		if _inventory.put_item(item_id, to.x, to.y) != "":
			notice.emit("Ausrüstung: %s ging verloren, die Tasche ist voll." % ItemInfo.display_name(item_id))


# --- Host --------------------------------------------------------------------

## Host: Wunsch prüfen und ausführen. Ergebnis {ok, reason, displaced}.
func host_request(action: String, item_id: StringName, place: StringName) -> Dictionary:
	if not Network.is_host() or _player == null:
		return {"ok": false, "reason": "Nur der Host ändert die Ausrüstung."}
	if _player.is_dead():
		return {"ok": false, "reason": EquipmentRules.MSG_DEAD}
	var in_combat := is_in_combat()
	var check: Dictionary
	match action:
		"equip":
			check = EquipmentRules.check_equip(item_id, place, equipment_state, get_class_id(), get_level(),
					in_combat, is_busy())
		"unequip":
			check = EquipmentRules.check_unequip(place, equipment_state, in_combat, is_busy())
		_:
			return {"ok": false, "reason": "Unbekannter Wunsch."}
	if not bool(check["ok"]):
		return {"ok": false, "reason": str(check["reason"])}
	equipment_state = check["state"]
	# Waffenwechsel im Kampf (nur Waffenplätze kommen durch die Prüfung):
	# ein globaler Cooldown, auch wenn zwei Plätze wechseln.
	if in_combat and _player.get_caster_node() != null:
		_player.get_caster_node().start_gcd()
	return {"ok": true, "reason": "", "displaced": check.get("displaced", {})}


## Host: Stand eines Charakters übernehmen (Beitreten), bereinigt.
func host_load(data: Dictionary) -> void:
	if not Network.is_host():
		return
	var result := EquipmentRules.sanitize(data, get_class_id(), get_level())
	for entry: Array in result["removed"]:
		push_warning("Ausrüstung von %s: %s (%s) verworfen: %s" % [
				_player.display_name if _player != null else "?", entry[1], entry[0], entry[2]])
	equipment_state = result["state"]


## Host: Wirkung an den Stand anpassen. Werte und Waffen-Zustände werden
## jedes Mal ganz neu gesetzt (eine Übertragung), Auren nur für geänderte
## Plätze (damit Abklingzeiten der Auslöser anderer Gegenstände bleiben).
func _host_refresh() -> void:
	if not Network.is_host() or _player == null or not is_inside_tree():
		return
	var stats := _get_stats()
	var combat := _player.get_combat()
	if stats == null:
		return
	var mods: Array[StatModifier] = []
	for place in EquipmentRules.all_places():
		var item_id := get_item(place)
		if item_id != &"":
			mods.append_array(EquipmentRules.modifiers_for(item_id, place))
	stats.replace_modifiers_with_prefix("item:", mods)
	stats.set_weapon_flags(EquipmentRules.weapon_flags(equipment_state))
	if combat == null:
		return
	for place: String in _applied.keys():
		var entry: Array = _applied[place]
		if str(equipment_state.get(place, "")) == String(entry[0]):
			continue
		for aura: AuraData in entry[1]:
			combat.remove_aura(aura.id, _player)
		_applied.erase(place)
	for place: String in equipment_state:
		if _applied.has(place):
			continue
		var item_id := StringName(str(equipment_state[place]))
		var auras: Array[AuraData] = []
		for aura in ItemInfo.effect_auras(item_id):
			var ctx := EffectContext.create(_player, _player, EquipmentRules.source_of(item_id, StringName(place)),
					ItemInfo.display_name(item_id))
			if combat.apply_aura(aura, _player, ctx) != null:
				auras.append(aura)
		_applied[place] = [String(item_id), auras]


# --- Änderungen (überall) ----------------------------------------------------

func _on_state_changed() -> void:
	if not is_inside_tree() or _player == null:
		return
	_host_refresh()
	equipment_changed.emit()
	_save_to_character()


## Besitzer: bestätigten Stand in den eigenen Charakter schreiben und speichern
## (erst nach dem Abgleich mit dem Inventar).
func _save_to_character() -> void:
	if _player == null or not _player.is_local() or not _reconciled:
		return
	var c := Network.get_local_character()
	if c == null or c.equipment == equipment_state:
		return
	c.equipment = equipment_state.duplicate()
	Network.save_local_character()
