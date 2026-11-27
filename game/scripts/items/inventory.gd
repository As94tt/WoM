class_name Inventory
extends RefCounted
## Inventar eines Charakters (Ticket #18): Rucksack, vier Taschenplätze,
## Gegenstände mit Stapeln und Geld. Reine Logik ohne Oberfläche; das
## Taschenfenster (InventoryPanel) und die Taschenleiste zeigen nur an und
## rufen die Funktionen hier auf. Jede Änderung meldet changed.
##
## Aufbau: Behälter 0 ist der Rucksack (rucksack_plaetze aus
## spielkonstanten.csv, immer vorhanden), Behälter 1–4 sind die Taschenplätze
## der Taschenleiste. Eine angelegte Tasche bringt so viele Plätze mit, wie in
## gegenstaende.csv (taschenplaetze) steht. Ein Platz ist leer ({}) oder
## {"id": StringName, "count": int}; mehr wird nicht gespeichert, alle
## Angaben zum Gegenstand kommen aus den Daten (ItemInfo).
##
## Regeln:
## - Neue Gegenstände füllen zuerst vorhandene, nicht volle Stapel, dann den
##   ersten freien Platz (Rucksack zuerst). Passt nicht alles hinein, kommt
##   nichts hinein und add_item meldet FULL („Inventar ist voll.“); der
##   Gegenstand geht also nicht verloren (wichtig für Beute, #38).
## - Verschieben: auf leeren Platz = verschieben, auf gleichen Gegenstand =
##   zusammenlegen (Rest bleibt liegen), sonst tauschen.
## - Eine Tasche lässt sich nur entfernen oder tauschen, wenn sie leer ist.
## - Sortieren: alle Taschen als eine Liste (Rucksack zuerst), Stapel
##   zusammengelegt, nach Typ (gegenstandstypen.csv), Seltenheit absteigend,
##   Name A–Z.
## - Geld ist eine Ganzzahl in Kupfer; Gold/Silber/Kupfer ist nur Anzeige.
##
## - „Einzigartig“ (#29): add_item meldet UNIQUE („Ihr besitzt diesen
##   Gegenstand bereits.“), wenn der Gegenstand schon in den Taschen liegt
##   oder angelegt ist (owned_elsewhere, gesetzt von der Ausrüstung).
## - Anlegen (#29): replace_item nimmt einen Gegenstand von seinem Platz und
##   legt die verdrängten Gegenstände in einem Schritt hinein (der erste auf
##   den frei gewordenen Platz).
##
## Multiplayer: Noch keine Synchronisierung. Das Inventar gehört dem Charakter
## und liegt beim Spieler (gespeichert mit CharacterData). Später vergibt der
## Host Beute; add_item meldet dafür Erfolg oder „voll“.

## Nach jeder Änderung an Plätzen, Taschen oder Geld.
signal changed

enum AddResult { ADDED, FULL, UNKNOWN, UNIQUE }

const BACKPACK := 0
## Taschenplätze in der Taschenleiste (fest wie die Leiste im HUD, #17).
const BAG_SLOT_COUNT := 4
## Ersatz, falls rucksack_plaetze in den Daten fehlt.
const DEFAULT_BACKPACK_SIZE := 16
const SAVE_VERSION := 1

const MSG_FULL := "Inventar ist voll."
const MSG_BAG_NOT_EMPTY := "Die Tasche ist nicht leer."
const MSG_NOT_A_BAG := "Das ist keine Tasche."
const MSG_NO_BAG := "Dort liegt keine Tasche."
const MSG_INVALID := "Das geht nicht."
const MSG_UNIQUE := "Ihr besitzt diesen Gegenstand bereits."

## Wie oft ein Gegenstand außerhalb der Taschen besessen wird (#29: angelegt),
## Callable(id: StringName) -> int; leer = nirgends.
var owned_elsewhere: Callable

## Geld in Kupfer.
var money := 0:
	set(value):
		value = maxi(0, value)
		if value == money:
			return
		money = value
		changed.emit()

## Taschen je Behälter (Index 0 = Rucksack, bleibt leer).
var _bags: Array[StringName] = []
## Plätze je Behälter: Array von Dictionaries ({} = leer).
var _slots: Array = []
var _backpack_size := DEFAULT_BACKPACK_SIZE


## backpack_size < 0: Größe aus spielkonstanten.csv (rucksack_plaetze).
func _init(backpack_size := -1) -> void:
	if backpack_size < 0:
		backpack_size = int(Data.konstante(&"rucksack_plaetze", DEFAULT_BACKPACK_SIZE))
	_backpack_size = maxi(1, backpack_size)
	_reset_containers()


# --- Abfragen ----------------------------------------------------------------

## Behälter insgesamt (Rucksack + Taschenplätze), auch ohne Tasche.
func get_container_count() -> int:
	return 1 + BAG_SLOT_COUNT


## true für den Rucksack und belegte Taschenplätze.
func has_container(container: int) -> bool:
	if container == BACKPACK:
		return true
	return container > 0 and container <= BAG_SLOT_COUNT and _bags[container] != &""


func get_container_size(container: int) -> int:
	if container < 0 or container >= _slots.size():
		return 0
	return (_slots[container] as Array).size()


## Tasche in einem Taschenplatz (1–4) oder &"".
func get_bag(container: int) -> StringName:
	if container <= 0 or container > BAG_SLOT_COUNT:
		return &""
	return _bags[container]


## Name für die Gruppe im Taschenfenster.
func get_container_name(container: int) -> String:
	if container == BACKPACK:
		return "Rucksack"
	return ItemInfo.display_name(get_bag(container))


## Inhalt eines Platzes ({} = leer) als Kopie.
func get_slot(container: int, index: int) -> Dictionary:
	if not _valid(container, index):
		return {}
	return (_slots[container][index] as Dictionary).duplicate()


func is_slot_empty(container: int, index: int) -> bool:
	return _valid(container, index) and (_slots[container][index] as Dictionary).is_empty()


func get_total_slots() -> int:
	var total := 0
	for container in get_container_count():
		total += get_container_size(container)
	return total


func get_free_slots() -> int:
	var free := 0
	for container in get_container_count():
		for slot: Dictionary in _slots[container]:
			if slot.is_empty():
				free += 1
	return free


## Wie viele Stück dieses Gegenstands im Inventar liegen.
func count_item(id: StringName) -> int:
	var total := 0
	for container in get_container_count():
		for slot: Dictionary in _slots[container]:
			if not slot.is_empty() and slot["id"] == id:
				total += int(slot["count"])
	return total


## Wie oft der Gegenstand besessen wird: Taschen und angelegt (#29).
func count_owned(id: StringName) -> int:
	var elsewhere := int(owned_elsewhere.call(id)) if owned_elsewhere.is_valid() else 0
	return count_item(id) + elsewhere


## Erster Platz mit diesem Gegenstand als Vector2i(Behälter, Platz) oder
## (-1, -1).
func find_item(id: StringName) -> Vector2i:
	for container in get_container_count():
		var slots: Array = _slots[container]
		for index in slots.size():
			var slot: Dictionary = slots[index]
			if not slot.is_empty() and slot["id"] == id:
				return Vector2i(container, index)
	return Vector2i(-1, -1)


## Für das Anlegen (#29): Nimmt ein Stück id vom Platz (container, index) –
## liegt es dort nicht mehr, vom ersten Platz mit id – und legt die
## Gegenstände incoming hinein, den ersten auf den frei gewordenen Platz.
## Prüft vorher, ob alles Platz hat; dann ändert sich nichts (MSG_FULL).
## Gibt "" oder eine Fehlermeldung zurück.
func replace_item(container: int, index: int, id: StringName, incoming: Array[StringName]) -> String:
	var at := Vector2i(container, index)
	var slot := get_slot(container, index)
	if slot.get("id", &"") != id:
		at = find_item(id)
	var freed := at.x >= 0 and int(get_slot(at.x, at.y).get("count", 0)) <= 1
	var needed := incoming.size() - (1 if freed else 0)
	if needed > get_free_slots():
		return MSG_FULL
	if at.x >= 0:
		var source: Dictionary = _slots[at.x][at.y]
		if int(source["count"]) > 1:
			source["count"] = int(source["count"]) - 1
		else:
			_slots[at.x][at.y] = {}
	var rest: Array[StringName] = incoming.duplicate()
	if freed and not rest.is_empty():
		_slots[at.x][at.y] = _stack(rest.pop_front(), 1)
	for item in rest:
		var free := _first_free_slot()
		if free.x >= 0:
			_slots[free.x][free.y] = _stack(item, 1)
	changed.emit()
	return ""


## Für das Ablegen (#29): legt ein Stück auf den Platz (container, index),
## wenn er leer ist, sonst in den ersten freien Platz (ohne Prüfung auf
## „Einzigartig“, es ist der eigene Gegenstand). "" oder MSG_FULL.
func put_item(id: StringName, container := -1, index := -1) -> String:
	if not ItemInfo.exists(id):
		return MSG_INVALID
	var target := Vector2i(container, index)
	if not is_slot_empty(container, index):
		target = _first_free_slot()
	if target.x < 0:
		return MSG_FULL
	_slots[target.x][target.y] = _stack(id, 1)
	changed.emit()
	return ""


## true, wenn alle count Stück hineinpassen.
func can_add(id: StringName, count := 1) -> bool:
	if count <= 0 or not ItemInfo.exists(id):
		return false
	var stack := ItemInfo.stack_size(id)
	var room := 0
	for container in get_container_count():
		for slot: Dictionary in _slots[container]:
			if slot.is_empty():
				room += stack
			elif slot["id"] == id:
				room += maxi(0, stack - int(slot["count"]))
			if room >= count:
				return true
	return false


# --- Gegenstände -------------------------------------------------------------

## Legt count Stück hinein: erst auf nicht volle Stapel, dann in freie Plätze.
## Passt nicht alles, ändert sich nichts (FULL). „Einzigartig“ (#29) nur,
## wenn er danach höchstens einmal besessen wird (sonst UNIQUE);
## check_unique = false beim Zurücklegen eigener Gegenstände (Ablegen).
func add_item(id: StringName, count := 1, check_unique := true) -> AddResult:
	if count <= 0 or not ItemInfo.exists(id):
		return AddResult.UNKNOWN
	if check_unique and ItemInfo.is_unique(id) and count_owned(id) + count > 1:
		return AddResult.UNIQUE
	if not can_add(id, count):
		return AddResult.FULL
	var stack := ItemInfo.stack_size(id)
	var left := count
	for container in get_container_count():
		for slot: Dictionary in _slots[container]:
			if left > 0 and not slot.is_empty() and slot["id"] == id and int(slot["count"]) < stack:
				var moved := mini(left, stack - int(slot["count"]))
				slot["count"] = int(slot["count"]) + moved
				left -= moved
	for container in get_container_count():
		var slots: Array = _slots[container]
		for index in slots.size():
			if left > 0 and (slots[index] as Dictionary).is_empty():
				var moved := mini(left, stack)
				slots[index] = _stack(id, moved)
				left -= moved
	changed.emit()
	return AddResult.ADDED


## Nimmt count Stück von einem Platz (-1 = alle). Gibt die Anzahl zurück.
func remove_at(container: int, index: int, count := -1) -> int:
	if not _valid(container, index):
		return 0
	var slot: Dictionary = _slots[container][index]
	if slot.is_empty():
		return 0
	var have := int(slot["count"])
	var removed := have if count < 0 else mini(count, have)
	if removed <= 0:
		return 0
	if removed >= have:
		_slots[container][index] = {}
	else:
		slot["count"] = have - removed
	changed.emit()
	return removed


## Zerstört den Gegenstand auf dem Platz (nach Bestätigung im Fenster).
## Questgegenstände dürfen ebenfalls zerstört werden.
func destroy(container: int, index: int) -> int:
	return remove_at(container, index)


## Verschiebt von einem Platz auf einen anderen. Leer = verschieben, gleicher
## Gegenstand = zusammenlegen (Rest bleibt), sonst tauschen.
## Gibt "" oder eine Fehlermeldung zurück.
func move(from_container: int, from_index: int, to_container: int, to_index: int) -> String:
	if not _valid(from_container, from_index) or not _valid(to_container, to_index):
		return MSG_INVALID
	if from_container == to_container and from_index == to_index:
		return ""
	var source: Dictionary = _slots[from_container][from_index]
	var target: Dictionary = _slots[to_container][to_index]
	if source.is_empty():
		return ""
	if not target.is_empty() and target["id"] == source["id"]:
		var stack := ItemInfo.stack_size(source["id"])
		var moved := mini(int(source["count"]), stack - int(target["count"]))
		if moved > 0:
			target["count"] = int(target["count"]) + moved
			source["count"] = int(source["count"]) - moved
			if int(source["count"]) <= 0:
				_slots[from_container][from_index] = {}
			changed.emit()
			return ""
	_slots[from_container][from_index] = target
	_slots[to_container][to_index] = source
	changed.emit()
	return ""


## Teilt amount Stück von einem Stapel ab und legt sie in den ersten freien
## Platz. Gibt "" oder eine Fehlermeldung zurück.
func split(container: int, index: int, amount: int) -> String:
	if not _valid(container, index):
		return MSG_INVALID
	var slot: Dictionary = _slots[container][index]
	if slot.is_empty() or amount <= 0 or amount >= int(slot["count"]):
		return MSG_INVALID
	var free := _first_free_slot()
	if free.x < 0:
		return MSG_FULL
	slot["count"] = int(slot["count"]) - amount
	_slots[free.x][free.y] = _stack(slot["id"], amount)
	changed.emit()
	return ""


## Entfernt alle Gegenstände und Taschen (Geld bleibt).
func clear() -> void:
	_reset_containers()
	changed.emit()


# --- Taschen -----------------------------------------------------------------

## Legt die Tasche von einem Platz in einen Taschenplatz (1–4). Liegt dort
## schon eine, wird getauscht – nur wenn sie leer ist; die alte Tasche kommt
## auf den frei gewordenen Platz. Gibt "" oder eine Fehlermeldung zurück.
func equip_bag(from_container: int, from_index: int, bag_slot: int) -> String:
	if not _valid(from_container, from_index) or bag_slot <= 0 or bag_slot > BAG_SLOT_COUNT:
		return MSG_INVALID
	var source: Dictionary = _slots[from_container][from_index]
	if source.is_empty():
		return MSG_INVALID
	var bag_id: StringName = source["id"]
	if not ItemInfo.is_bag(bag_id):
		return MSG_NOT_A_BAG
	if from_container == bag_slot:
		return MSG_BAG_NOT_EMPTY
	var old_bag := _bags[bag_slot]
	if old_bag != &"" and not _is_container_empty(bag_slot):
		return MSG_BAG_NOT_EMPTY
	if int(source["count"]) > 1:
		# Mehrere Taschen auf einem Platz (nur wenn die Daten es erlauben):
		# eine anlegen, die alte braucht dann einen eigenen freien Platz.
		if old_bag != &"":
			var free := _first_free_slot(bag_slot)
			if free.x < 0:
				return MSG_FULL
			_slots[free.x][free.y] = _stack(old_bag, 1)
		source["count"] = int(source["count"]) - 1
	else:
		_slots[from_container][from_index] = _stack(old_bag, 1) if old_bag != &"" else {}
	_set_bag(bag_slot, bag_id)
	changed.emit()
	return ""


## Nimmt die Tasche aus einem Taschenplatz und legt sie auf den Platz
## (to_container, to_index) bzw. – wenn der belegt ist oder keiner angegeben –
## in den ersten freien Platz außerhalb dieser Tasche. Nur leere Taschen.
func unequip_bag(bag_slot: int, to_container := -1, to_index := -1) -> String:
	if bag_slot <= 0 or bag_slot > BAG_SLOT_COUNT:
		return MSG_INVALID
	var bag_id := _bags[bag_slot]
	if bag_id == &"":
		return MSG_NO_BAG
	if not _is_container_empty(bag_slot):
		return MSG_BAG_NOT_EMPTY
	var target := Vector2i(to_container, to_index)
	if to_container == bag_slot or not _valid(to_container, to_index) \
			or not (_slots[to_container][to_index] as Dictionary).is_empty():
		target = _first_free_slot(bag_slot)
	if target.x < 0:
		return MSG_FULL
	_slots[target.x][target.y] = _stack(bag_id, 1)
	_set_bag(bag_slot, &"")
	changed.emit()
	return ""


## Tauscht zwei Taschenplätze samt Inhalt (Ziehen in der Taschenleiste).
func swap_bag_slots(a: int, b: int) -> String:
	if a <= 0 or b <= 0 or a > BAG_SLOT_COUNT or b > BAG_SLOT_COUNT:
		return MSG_INVALID
	if a == b:
		return ""
	var bag := _bags[a]
	_bags[a] = _bags[b]
	_bags[b] = bag
	var slots: Array = _slots[a]
	_slots[a] = _slots[b]
	_slots[b] = slots
	changed.emit()
	return ""


# --- Sortieren ---------------------------------------------------------------

## Legt gleiche Gegenstände zu vollen Stapeln zusammen und ordnet alles als
## eine Liste (Rucksack zuerst, dann Taschenplatz 1–4): Typ, Seltenheit
## absteigend, Name A–Z.
func sort() -> void:
	var totals := {}
	var order: Array[StringName] = []
	for container in get_container_count():
		for slot: Dictionary in _slots[container]:
			if slot.is_empty():
				continue
			if not totals.has(slot["id"]):
				totals[slot["id"]] = 0
				order.append(slot["id"])
			totals[slot["id"]] += int(slot["count"])
	order.sort_custom(is_sorted_before)
	var stacks: Array[Dictionary] = []
	for id in order:
		var left: int = totals[id]
		var stack := ItemInfo.stack_size(id)
		while left > 0:
			var amount := mini(left, stack)
			stacks.append(_stack(id, amount))
			left -= amount
	var next := 0
	for container in get_container_count():
		var slots: Array = _slots[container]
		for index in slots.size():
			slots[index] = stacks[next] if next < stacks.size() else {}
			next += 1
	changed.emit()


## Sortierreihenfolge zweier Gegenstände (true = a vor b).
static func is_sorted_before(a: StringName, b: StringName) -> bool:
	var type_a := ItemInfo.type_order(a)
	var type_b := ItemInfo.type_order(b)
	if type_a != type_b:
		return type_a < type_b
	var rarity_a := ItemInfo.rarity_order(a)
	var rarity_b := ItemInfo.rarity_order(b)
	if rarity_a != rarity_b:
		return rarity_a > rarity_b
	var by_name := ItemInfo.display_name(a).naturalnocasecmp_to(ItemInfo.display_name(b))
	if by_name != 0:
		return by_name < 0
	return String(a) < String(b)


# --- Geld --------------------------------------------------------------------

## Ändert das Geld um amount Kupfer. false (ohne Änderung), wenn es dadurch
## unter 0 fiele.
func add_money(amount: int) -> bool:
	if money + amount < 0:
		return false
	money += amount
	return true


# --- Speichern ---------------------------------------------------------------

## Stand zum Speichern (nur einfache Typen): Taschen-IDs und je Behälter die
## Plätze als [id, anzahl] bzw. [] für leer. Geld speichert CharacterData
## getrennt (money_copper).
func to_save() -> Dictionary:
	var bags: Array = []
	var containers: Array = []
	for container in get_container_count():
		bags.append(String(_bags[container]))
		var slots: Array = []
		for slot: Dictionary in _slots[container]:
			slots.append([] if slot.is_empty() else [String(slot["id"]), int(slot["count"])])
		containers.append(slots)
	return {"version": SAVE_VERSION, "taschen": bags, "plaetze": containers}


## Lädt einen gespeicherten Stand. Unbekannte Gegenstände entfallen; was durch
## geänderte Daten nicht mehr an seinen Platz passt (kleinere Tasche, größere
## Stapel als erlaubt), kommt in freie Plätze. Gibt Warnungen zurück.
func load_save(data: Dictionary) -> PackedStringArray:
	var warnings: PackedStringArray = []
	_reset_containers()
	var overflow: Array[Dictionary] = []
	var bags: Variant = data.get("taschen", [])
	if bags is Array:
		for container in range(1, mini((bags as Array).size(), get_container_count())):
			var bag_id := StringName(str(bags[container]))
			if bag_id == &"":
				continue
			if ItemInfo.is_bag(bag_id):
				_set_bag(container, bag_id)
			elif ItemInfo.exists(bag_id):
				overflow.append(_stack(bag_id, 1))
			else:
				warnings.append("Unbekannte Tasche „%s“ entfernt." % bag_id)
	var containers: Variant = data.get("plaetze", [])
	if containers is Array:
		for container in mini((containers as Array).size(), get_container_count()):
			var saved: Variant = containers[container]
			if not saved is Array:
				continue
			for index in (saved as Array).size():
				var entry: Variant = saved[index]
				if not entry is Array or (entry as Array).size() < 2:
					continue
				var id := StringName(str(entry[0]))
				var count := int(entry[1])
				if count <= 0:
					continue
				if not ItemInfo.exists(id):
					warnings.append("Unbekannter Gegenstand „%s“ (%d) entfernt." % [id, count])
					continue
				var stack := ItemInfo.stack_size(id)
				if count > stack:
					overflow.append(_stack(id, count - stack))
					count = stack
				if index < get_container_size(container) and (_slots[container][index] as Dictionary).is_empty():
					_slots[container][index] = _stack(id, count)
				else:
					overflow.append(_stack(id, count))
	for item in overflow:
		if add_item(item["id"], item["count"], false) != AddResult.ADDED:
			warnings.append("Kein Platz für %s (%d), entfernt." % [ItemInfo.display_name(item["id"]), item["count"]])
	changed.emit()
	return warnings


# --- Intern ------------------------------------------------------------------

func _reset_containers() -> void:
	_bags.clear()
	_slots.clear()
	for container in get_container_count():
		_bags.append(&"")
		_slots.append([])
	_resize(BACKPACK, _backpack_size)


func _set_bag(container: int, bag_id: StringName) -> void:
	_bags[container] = bag_id
	_resize(container, ItemInfo.bag_slots(bag_id) if bag_id != &"" else 0)


func _resize(container: int, size: int) -> void:
	var slots: Array = []
	for i in size:
		slots.append({})
	_slots[container] = slots


func _is_container_empty(container: int) -> bool:
	for slot: Dictionary in _slots[container]:
		if not slot.is_empty():
			return false
	return true


## Erster freier Platz (Rucksack zuerst), ohne den Behälter skip; (-1, -1),
## wenn keiner frei ist.
func _first_free_slot(skip := -1) -> Vector2i:
	for container in get_container_count():
		if container == skip:
			continue
		var slots: Array = _slots[container]
		for index in slots.size():
			if (slots[index] as Dictionary).is_empty():
				return Vector2i(container, index)
	return Vector2i(-1, -1)


func _valid(container: int, index: int) -> bool:
	return container >= 0 and container < _slots.size() and index >= 0 \
			and index < (_slots[container] as Array).size()


static func _stack(id: StringName, count: int) -> Dictionary:
	return {"id": id, "count": count}
