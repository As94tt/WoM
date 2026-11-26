class_name BagBarSlot
extends Button
## Ein Taschenplatz der Taschenleiste (Ticket #17, Inhalt seit #18). Zeigt
## die angelegte Tasche (Icon bzw. Kürzel, Tooltip) oder ist leer.
##
## - Tasche aus dem Taschenfenster hierher ziehen: anlegen
##   (Inventory.equip_bag; liegt hier schon eine, wird getauscht, wenn sie
##   leer ist).
## - Angelegte Tasche ziehen: auf einen Platz im Taschenfenster = abnehmen
##   (nur leer), auf einen anderen Taschenplatz = Plätze tauschen.
## - Klick öffnet bzw. schließt das Taschenfenster (das HUD verbindet pressed).
## Rein lokal; Fehlermeldungen gehen über error an das HUD.

signal error(message: String)

## Taschenplatz im Inventar (1–4; 1 liegt direkt neben dem Rucksack).
@export_range(1, 4) var bag_slot := 1

var inventory: Inventory = null


func setup(inv: Inventory) -> void:
	inventory = inv
	refresh()


func refresh() -> void:
	var bag := inventory.get_bag(bag_slot) if inventory != null else &""
	ItemSlot.apply_icon(self, bag)
	if bag == &"":
		tooltip_text = "Taschenplatz (leer)"
	else:
		tooltip_text = ItemTooltip.text(bag) + "\n" + _hint()


func _make_custom_tooltip(_for_text: String) -> Object:
	var bag := inventory.get_bag(bag_slot) if inventory != null else &""
	if bag == &"":
		return null
	var box := ItemTooltip.create(bag)
	var hint := Label.new()
	hint.theme_type_variation = &"HintText"
	hint.text = _hint()
	box.add_child(hint)
	return box


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory == null or inventory.get_bag(bag_slot) == &"":
		return null
	var data := ItemDragData.from_bag_slot(inventory, bag_slot)
	set_drag_preview(data.make_preview())
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var drag := data as ItemDragData
	if drag == null or inventory == null or drag.inventory != inventory:
		return false
	if drag.is_bag_slot():
		return true
	return ItemInfo.is_bag(drag.item_id)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var drag := data as ItemDragData
	var message := ""
	if drag.is_bag_slot():
		message = inventory.swap_bag_slots(drag.bag_slot, bag_slot)
	else:
		message = inventory.equip_bag(drag.container, drag.index, bag_slot)
	if message != "":
		error.emit(message)


static func _hint() -> String:
	return "Ziehen: abnehmen (nur wenn leer)"
