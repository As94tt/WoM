class_name EquipmentSlot
extends Button
## Ein Ausrüstungsplatz im Charakterfenster (Ticket #29, ersetzt die leeren
## Buttons aus #19). SlotButton40, 40 × 40 px.
##
## - Leer: blasses Bild des Platzes aus ausruestungsplaetze.csv, Tooltip
##   „Name (leer)“. Die Nebenhand neben einer Zweihandwaffe ist deaktiviert
##   (Tooltip „Nebenhand (durch Zweihandwaffe belegt)“).
## - Belegt: Icon bzw. Kürzel des Gegenstands, ab Ungewöhnlich der
##   Seltenheitsrahmen (ItemRarityFrame, item_rarity_frame_40), Tooltip des
##   Gegenstands (ItemTooltip).
## - Gegenstand aus der Tasche hierher ziehen: anlegen (Wunsch an den Host,
##   abgelehnt mit Grund oben in der Mitte). Beim Ziehen eines Gegenstands
##   leuchten die passenden Plätze auf (SlotDropAllowed), sofern der Charakter
##   ihn nutzen kann.
## - Angelegten Gegenstand in die Tasche ziehen: ablegen (ItemSlot).
## Nur Anzeige und Wünsche; den Stand bestimmt PlayerEquipment.

const SLOT_SIZE := Vector2(40, 40)

var place: StringName = &""
var equipment: PlayerEquipment = null

var _item_id: StringName = &""


func _ready() -> void:
	refresh()


func setup(slot_place: StringName) -> void:
	place = slot_place
	refresh()


func set_equipment(value: PlayerEquipment) -> void:
	equipment = value
	refresh()


func get_item_id() -> StringName:
	return _item_id


## true, solange beim Ziehen die Hervorhebung sichtbar ist (für Tests).
func is_highlighted() -> bool:
	return is_node_ready() and (%DropHighlight as Panel).visible


func refresh() -> void:
	if not is_node_ready():
		return
	_item_id = equipment.get_item(place) if equipment != null else &""
	var frame: Panel = %RarityFrame
	disabled = false
	if _item_id != &"":
		ItemSlot.apply_icon(self, _item_id)
		frame.visible = ItemInfo.has_rarity_frame(_item_id)
		if frame.visible:
			frame.self_modulate = ItemInfo.rarity_color(_item_id)
		tooltip_text = ItemTooltip.text(_item_id, 0, equipment)
		return
	frame.visible = false
	text = ""
	var row := Data.ausruestungsplatz(place)
	var path := str(row.get_value("icon", "")) if row != null else ""
	icon = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	expand_icon = icon != null
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var place_name := EquipmentRules.place_name(place)
	if place == EquipmentRules.OFF_HAND and equipment != null and equipment.is_off_hand_blocked():
		disabled = true
		tooltip_text = "%s (durch Zweihandwaffe belegt)" % place_name
	else:
		tooltip_text = "%s (leer)" % place_name


func _make_custom_tooltip(_for_text: String) -> Object:
	if _item_id == &"":
		return null
	return ItemTooltip.create(_item_id, 0, equipment)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if equipment == null or _item_id == &"" or equipment.get_inventory() == null:
		return null
	var data := ItemDragData.from_equipment(equipment.get_inventory(), place, _item_id)
	set_drag_preview(data.make_preview())
	return data


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var drag := data as ItemDragData
	return drag != null and equipment != null and drag.is_bag_item() \
			and drag.inventory == equipment.get_inventory() and ItemInfo.is_equipment(drag.item_id)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var drag := data as ItemDragData
	equipment.request_equip_from_bag(drag.container, drag.index, place)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_update_highlight(get_viewport().gui_get_drag_data())
		NOTIFICATION_DRAG_END:
			_update_highlight(null)


## Passende Plätze leuchten beim Ziehen eines nutzbaren Gegenstands auf.
func _update_highlight(data: Variant) -> void:
	if not is_node_ready():
		return
	var drag := data as ItemDragData
	var on := drag != null and equipment != null and drag.is_bag_item() \
			and EquipmentRules.places_for(drag.item_id).has(place) and equipment.can_use(drag.item_id)
	if on and place == EquipmentRules.OFF_HAND:
		on = EquipmentRules.choose_place(drag.item_id, {}, equipment.get_class_id()) == place \
				or EquipmentRules.can_dual_wield(equipment.get_class_id()) \
				or EquipmentRules.places_for(drag.item_id).size() == 1
	(%DropHighlight as Panel).visible = on
