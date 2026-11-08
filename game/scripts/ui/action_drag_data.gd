class_name ActionDragData
extends RefCounted
## Was beim Ziehen am Mauszeiger hängt (Ticket #21): Inhalt eines
## Aktionsleisten-Slots, dazu der Ursprungsslot (oder keiner, wenn die
## Fähigkeit aus dem Zauberbuch kommt bzw. nach dem Ersetzen am Zeiger hängt).
##
## Ablauf (Godot-Drag-and-Drop, siehe ActionSlot und Hud):
## - Ablegen auf einem Slot: ActionBar.drop_on_slot().
## - Ins Leere loslassen: Der Ursprungsslot wird geleert.
## - Abbruch mit Rechtsklick oder Esc (cancelled): Alles bleibt, wie es war;
##   ohne Ursprungsslot wird die Fähigkeit verworfen.

## Größe der Vorschau am Mauszeiger (wie ein Aktionsslot).
const PREVIEW_SIZE := Vector2(48, 48)

var content: ActionSlotContent
## Ursprung: Leiste und Slot (null/-1 = Zauberbuch oder ersetzt).
var source_bar: ActionBar = null
var source_index := -1
## Mit Rechtsklick oder Esc abgebrochen (gesetzt vom HUD).
var cancelled := false


static func create(slot_content: ActionSlotContent, bar: ActionBar = null, index := -1) -> ActionDragData:
	var data := ActionDragData.new()
	data.content = slot_content
	data.source_bar = bar
	data.source_index = index
	return data


func has_source() -> bool:
	return source_bar != null and source_index >= 0


## Vorschau am Mauszeiger: ein Slot mit Icon bzw. Kürzel.
func make_preview() -> Control:
	var preview := Button.new()
	preview.theme_type_variation = &"SlotButton"
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.size = PREVIEW_SIZE
	preview.focus_mode = Control.FOCUS_NONE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AbilityIcon.apply(preview, content.get_ability() if content != null else null)
	# Mittig unter dem Zeiger.
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	preview.position = -PREVIEW_SIZE / 2.0
	return holder
