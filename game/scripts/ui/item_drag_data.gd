class_name ItemDragData
extends RefCounted
## Was beim Ziehen im Taschenfenster am Mauszeiger hängt (Ticket #18):
## entweder ein Gegenstand von einem Platz (container, index) oder eine
## angelegte Tasche aus der Taschenleiste (bag_slot > 0).
##
## Ablauf (Godot-Drag-and-Drop, siehe ItemSlot, BagBarSlot und Hud):
## - Ablegen auf einem Platz bzw. Taschenplatz: Inventory.move, equip_bag,
##   unequip_bag oder swap_bag_slots.
## - Gegenstand außerhalb des Taschenfensters loslassen: Rückfrage
##   „X wirklich zerstören?“ (InventoryPanel).
## - Abbruch mit Rechtsklick oder Esc (cancelled, gesetzt vom HUD): Alles
##   bleibt, wie es war.

const PREVIEW_SIZE := Vector2(48, 48)

var inventory: Inventory
var item_id: StringName = &""
var container := -1
var index := -1
## Taschenplatz 1–4, wenn eine angelegte Tasche gezogen wird (sonst 0).
var bag_slot := 0
var cancelled := false


static func from_slot(inv: Inventory, from_container: int, from_index: int) -> ItemDragData:
	var data := ItemDragData.new()
	data.inventory = inv
	data.container = from_container
	data.index = from_index
	data.item_id = inv.get_slot(from_container, from_index).get("id", &"")
	return data


static func from_bag_slot(inv: Inventory, slot: int) -> ItemDragData:
	var data := ItemDragData.new()
	data.inventory = inv
	data.bag_slot = slot
	data.item_id = inv.get_bag(slot)
	return data


func is_bag_slot() -> bool:
	return bag_slot > 0


## Vorschau am Mauszeiger: ein Platz mit Icon bzw. Kürzel, mittig.
func make_preview() -> Control:
	var preview := Button.new()
	preview.theme_type_variation = &"SlotButton"
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.size = PREVIEW_SIZE
	preview.focus_mode = Control.FOCUS_NONE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ItemSlot.apply_icon(preview, item_id)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	preview.position = -PREVIEW_SIZE / 2.0
	return holder
