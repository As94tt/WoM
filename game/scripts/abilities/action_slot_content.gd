class_name ActionSlotContent
extends RefCounted
## Inhalt eines Aktionsleisten-Slots (Ticket #21): eine Fähigkeit oder später
## ein Gegenstand (z. B. Trank). Gespeichert wird nur Art und ID als Text
## „ability:feuerball“ bzw. „item:heiltrank“ (CharacterData.action_bars).
## Vorerst werden nur Fähigkeiten verwendet; Gegenstände folgen mit dem
## Taschen-/Gegenstands-Ticket.

enum Kind { ABILITY, ITEM }

const KIND_KEYS := {Kind.ABILITY: "ability", Kind.ITEM: "item"}
const SEPARATOR := ":"

var kind: Kind = Kind.ABILITY
var id: StringName = &""


static func ability(ability_id: StringName) -> ActionSlotContent:
	var content := ActionSlotContent.new()
	content.kind = Kind.ABILITY
	content.id = ability_id
	return content


static func item(item_id: StringName) -> ActionSlotContent:
	var content := ActionSlotContent.new()
	content.kind = Kind.ITEM
	content.id = item_id
	return content


## Text zum Speichern, z. B. „ability:feuerball“.
func to_key() -> String:
	return "%s%s%s" % [KIND_KEYS[kind], SEPARATOR, id]


## Gegenstück zu to_key(); null bei leerem oder unlesbarem Text.
static func from_key(key: String) -> ActionSlotContent:
	var parts := key.split(SEPARATOR, true, 1)
	if parts.size() != 2 or parts[1].is_empty():
		return null
	for k: Kind in KIND_KEYS:
		if KIND_KEYS[k] == parts[0]:
			var content := ActionSlotContent.new()
			content.kind = k
			content.id = StringName(parts[1])
			return content
	return null


func is_ability() -> bool:
	return kind == Kind.ABILITY


## Die Fähigkeit oder null (Gegenstand oder unbekannte ID).
func get_ability() -> AbilityData:
	return GameData.get_ability(id) if kind == Kind.ABILITY else null


func equals(other: ActionSlotContent) -> bool:
	return other != null and other.kind == kind and other.id == id


func duplicate_content() -> ActionSlotContent:
	var copy := ActionSlotContent.new()
	copy.kind = kind
	copy.id = id
	return copy
