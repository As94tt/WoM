class_name ActionBarLayout
extends RefCounted
## Belegung der Aktionsleisten eines Charakters (Ticket #21): BAR_COUNT
## Leisten mit je SLOT_COUNT Slots, jeder leer (null) oder mit einem
## ActionSlotContent. Rein lokal, gehört dem Charakter und wird mit ihm
## gespeichert (CharacterData.action_bars). Funktioniert ohne Interface.
##
## Leiste 0 ist „Leiste 1“ (unten, mit Tasten 1–=), Leiste 1 ist „Leiste 2“.

## Ein Slot hat sich geändert (Leiste und Slot ab 0).
signal slot_changed(bar: int, index: int)
## Die Belegung hat sich geändert (nach jeder Aktion genau einmal, z. B. zum
## Speichern).
signal changed

const BAR_COUNT := 2
const SLOT_COUNT := 12

var _slots: Array = []


func _init() -> void:
	for bar in BAR_COUNT:
		var row: Array = []
		row.resize(SLOT_COUNT)
		_slots.append(row)


func get_content(bar: int, index: int) -> ActionSlotContent:
	if not _is_valid(bar, index):
		return null
	return _slots[bar][index]


func set_content(bar: int, index: int, content: ActionSlotContent) -> void:
	if not _is_valid(bar, index):
		return
	_put(bar, index, content)
	changed.emit()


func clear(bar: int, index: int) -> void:
	set_content(bar, index, null)


## Verschiebt bzw. tauscht zwei Slots (der Zielslot darf leer sein).
func swap(bar_a: int, index_a: int, bar_b: int, index_b: int) -> void:
	if not _is_valid(bar_a, index_a) or not _is_valid(bar_b, index_b):
		return
	if bar_a == bar_b and index_a == index_b:
		return
	var a: ActionSlotContent = _slots[bar_a][index_a]
	_put(bar_a, index_a, _slots[bar_b][index_b])
	_put(bar_b, index_b, a)
	changed.emit()


## Erster freier Slot einer Leiste oder -1.
func first_free(bar: int) -> int:
	for index in SLOT_COUNT:
		if _slots[bar][index] == null:
			return index
	return -1


## true, wenn die Fähigkeit auf irgendeinem Slot liegt.
func has_ability(ability_id: StringName) -> bool:
	for row: Array in _slots:
		for content: ActionSlotContent in row:
			if content != null and content.is_ability() and content.id == ability_id:
				return true
	return false


## Entfernt eine Fähigkeit von allen Slots (#20: Talent-Fähigkeiten beim
## Zurücksetzen). Gibt die Zahl der geleerten Slots zurück.
func remove_ability(ability_id: StringName) -> int:
	var count := 0
	for bar in BAR_COUNT:
		for index in SLOT_COUNT:
			var content: ActionSlotContent = _slots[bar][index]
			if content != null and content.is_ability() and content.id == ability_id:
				_put(bar, index, null)
				count += 1
	if count > 0:
		changed.emit()
	return count


## Legt eine Fähigkeit in den ersten freien Slot von Leiste 1, sonst Leiste 2
## (Entscheidung zu #21). Gibt false zurück, wenn beide voll sind.
func place_ability(ability_id: StringName) -> bool:
	for bar in BAR_COUNT:
		var index := first_free(bar)
		if index >= 0:
			set_content(bar, index, ActionSlotContent.ability(ability_id))
			return true
	return false


## Leert alle Slots und legt die Fähigkeiten der Reihe nach ab (Standard-
## belegung, siehe PlayerAbilities.get_default_bar_abilities).
func reset(abilities: Array[AbilityData]) -> void:
	for bar in BAR_COUNT:
		for index in SLOT_COUNT:
			_put(bar, index, null)
	for ability in abilities:
		for bar in BAR_COUNT:
			var index := first_free(bar)
			if index >= 0:
				_put(bar, index, ActionSlotContent.ability(ability.id))
				break
	changed.emit()


## Zum Speichern: je Leiste ein PackedStringArray mit SLOT_COUNT Einträgen
## („ability:feuerball“ oder „“ für leer).
func to_save() -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	for row: Array in _slots:
		var keys := PackedStringArray()
		for content: ActionSlotContent in row:
			keys.append(content.to_key() if content != null else "")
		result.append(keys)
	return result


## Gegenstück zu to_save(). Unbekannte Fähigkeiten (z. B. umbenannte IDs)
## werden mit Warnung verworfen; fehlende Leisten/Slots bleiben leer.
func load_save(data: Array[PackedStringArray]) -> void:
	for bar in BAR_COUNT:
		for index in SLOT_COUNT:
			var content: ActionSlotContent = null
			if bar < data.size() and index < data[bar].size() and data[bar][index] != "":
				content = ActionSlotContent.from_key(data[bar][index])
				if content == null or (content.is_ability() and content.get_ability() == null):
					push_warning("ActionBarLayout: Slot %d/%d „%s“ ist unbekannt und wird geleert." % [
							bar + 1, index + 1, data[bar][index]])
					content = null
			_put(bar, index, content)
	changed.emit()


func _put(bar: int, index: int, content: ActionSlotContent) -> void:
	var old: ActionSlotContent = _slots[bar][index]
	if old == content or (old != null and old.equals(content)):
		return
	_slots[bar][index] = content
	slot_changed.emit(bar, index)


func _is_valid(bar: int, index: int) -> bool:
	return bar >= 0 and bar < BAR_COUNT and index >= 0 and index < SLOT_COUNT
