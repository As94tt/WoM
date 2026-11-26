class_name InventorySaver
extends RefCounted
## Schreibt das Inventar bei jeder Änderung in den Charakter und speichert
## ihn (Ticket #18). Mehrere Änderungen im selben Frame (z. B. Sortieren,
## mehrere Gegenstände auf einmal) werden gebündelt: gespeichert wird
## höchstens einmal pro Frame, am Ende des Frames (call_deferred).
##
## save_callable speichert den Charakter (im Spiel Network.save_local_character,
## das Testcharaktere überspringt).

## Wie oft bisher gespeichert wurde (für Tests und das Entwickler-Panel).
var save_count := 0

var _inventory: Inventory
var _character: CharacterData
var _save: Callable
var _pending := false


func _init(inventory: Inventory, character: CharacterData, save_callable: Callable) -> void:
	_inventory = inventory
	_character = character
	_save = save_callable
	_inventory.changed.connect(request_save)


## Charakter in diesem Frame noch speichern (mehrfacher Aufruf = einmal).
func request_save() -> void:
	if _pending:
		return
	_pending = true
	flush.call_deferred()


func is_pending() -> bool:
	return _pending


## Speichert sofort, falls etwas aussteht.
func flush() -> void:
	if not _pending:
		return
	_pending = false
	write_to_character()
	if _save.is_valid():
		_save.call()
	save_count += 1


## Überträgt Inventar und Geld in den Charakter (ohne Datei zu schreiben).
func write_to_character() -> void:
	if _character == null:
		return
	_character.inventory = _inventory.to_save()
	_character.money_copper = _inventory.money


## Inventar und Geld aus dem Charakter laden. Gibt Warnungen zurück.
static func load_into(inventory: Inventory, character: CharacterData) -> PackedStringArray:
	var warnings := inventory.load_save(character.inventory if character != null else {})
	inventory.money = character.money_copper if character != null else 0
	return warnings
