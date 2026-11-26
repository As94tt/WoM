class_name ItemSlot
extends Button
## Ein Platz im Taschenfenster (Ticket #18). Leer: nur der Rahmen
## (SlotButton). Belegt: Icon bzw. Kürzel, Anzahl unten rechts (ab 2,
## ItemCount) und ab Ungewöhnlich ein Rahmen in der Seltenheitsfarbe
## (ItemRarityFrame, Farbe aus RarityColors über self_modulate).
##
## Bedienung:
## - Ziehen und ablegen: Verschieben, Tauschen, Zusammenlegen
##   (Inventory.move); eine Tasche aus der Taschenleiste hierher ziehen nimmt
##   sie ab (Inventory.unequip_bag, nur wenn leer).
## - Shift + Klick auf einen Stapel: split_requested (Fenster mit Anzahl).
## - Außerhalb des Fensters loslassen: released_outside (Rückfrage zum
##   Zerstören, InventoryPanel).
## - Rechtsklick: vorerst keine Funktion (wird abgefangen, damit sich die
##   Kamera nicht dreht).
## Rein lokal; die Logik steckt in Inventory.

## Eine Aktion ging nicht (z. B. „Die Tasche ist nicht leer.“).
signal error(message: String)
signal split_requested(container: int, index: int)
signal released_outside(container: int, index: int, item_id: StringName)

var inventory: Inventory = null
var container := -1
var index := -1

var _item_id: StringName = &""
var _count := 0
var _outgoing: ItemDragData = null


## Zeigt einen Gegenstand (oder nichts) auf einem Button mit SlotButton-
## Aussehen: Icon oder Kürzel als Text.
static func apply_icon(button: Button, id: StringName) -> void:
	var texture := ItemInfo.icon(id) if id != &"" else null
	button.icon = texture
	button.expand_icon = texture != null
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = "" if texture != null or id == &"" else ItemInfo.short_name(id)


func setup(inv: Inventory, slot_container: int, slot_index: int) -> void:
	inventory = inv
	container = slot_container
	index = slot_index
	refresh()


## Inhalt neu aus dem Inventar lesen.
func refresh() -> void:
	var slot := inventory.get_slot(container, index) if inventory != null else {}
	_item_id = slot.get("id", &"")
	_count = int(slot.get("count", 0))
	apply_icon(self, _item_id)
	var count_label: Label = %Count
	count_label.visible = _count > 1
	count_label.text = str(_count)
	var frame: Panel = %RarityFrame
	frame.visible = _item_id != &"" and ItemInfo.has_rarity_frame(_item_id)
	if frame.visible:
		frame.self_modulate = ItemInfo.rarity_color(_item_id)
	tooltip_text = ItemTooltip.text(_item_id, _count) if _item_id != &"" else ""


func get_item_id() -> StringName:
	return _item_id


func get_count() -> int:
	return _count


func _make_custom_tooltip(_for_text: String) -> Object:
	if _item_id == &"":
		return null
	return ItemTooltip.create(_item_id, _count)


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		# Später: benutzen bzw. ausrüsten (#29).
		accept_event()
	elif mouse.button_index == MOUSE_BUTTON_LEFT and mouse.shift_pressed and _count > 1:
		accept_event()
		split_requested.emit(container, index)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory == null or _item_id == &"" or Input.is_key_pressed(KEY_SHIFT):
		return null
	var data := ItemDragData.from_slot(inventory, container, index)
	set_drag_preview(data.make_preview())
	_outgoing = data
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var drag := data as ItemDragData
	if drag == null or drag.inventory != inventory or inventory == null:
		return false
	# Eine angelegte Tasche kann nicht in sich selbst liegen.
	return not (drag.is_bag_slot() and drag.bag_slot == container)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var drag := data as ItemDragData
	var message := ""
	if drag.is_bag_slot():
		message = inventory.unequip_bag(drag.bag_slot, container, index)
	else:
		message = inventory.move(drag.container, drag.index, container, index)
	if message != "":
		error.emit(message)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _outgoing != null:
		var data := _outgoing
		_outgoing = null
		if not get_viewport().gui_is_drag_successful() and not data.cancelled:
			released_outside.emit(data.container, data.index, data.item_id)
