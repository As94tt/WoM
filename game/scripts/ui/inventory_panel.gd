class_name InventoryPanel
extends VBoxContainer
## Inhalt des Taschenfensters (Ticket #18, Taste B): ein gemeinsames Fenster
## für alle Taschen. Die Plätze sind nach Tasche gruppiert, der Rucksack
## zuerst; jede Gruppe zeigt den Namen der Tasche und ihre freien Plätze.
## Unten Geld (Gold, Silber, Kupfer mit Münzsymbol) und „Sortieren“.
##
## Das Fenster zeigt nur an: Alle Änderungen laufen über Inventory, das
## changed meldet; danach wird neu gezeichnet. Shift + Klick öffnet
## „Stapel teilen“ (SplitStackDialog), Loslassen außerhalb des Fensters fragt
## „X wirklich zerstören?“ (über confirm_handler, im Spiel Hud.ask).
## Fehlermeldungen („Inventar ist voll.“) gehen über error an das HUD.
## Rein lokal, nichts wird synchronisiert. Seit #29 kennt das Fenster die
## Ausrüstung des eigenen Charakters (setup_equipment): Rechtsklick legt an,
## nicht nutzbare Gegenstände tragen einen roten Schleier, Tooltips vergleichen
## mit der angelegten Ausrüstung. Loslassen über dem Charakterfenster zerstört
## nichts.

signal error(message: String)

const ITEM_SLOT_SCENE := preload("res://scenes/ui/hud/item_slot.tscn")
## Plätze je Reihe (6 × 48 px + Abstände passen in das 360 px breite Fenster).
const COLUMNS := 6
## Höchste Höhe der Platzliste, darüber mit Bildlaufleiste.
const MAX_LIST_HEIGHT := 540.0
const COIN_SIZE := Vector2(18, 18)

## Rückfrage (title, message, confirm_text, cancel_text, on_confirm), im
## Spiel Hud.ask. Ohne Handler wird ohne Rückfrage nichts zerstört.
var confirm_handler: Callable
## Knoten, unter den der Dialog „Stapel teilen“ gehängt wird (im Spiel das
## HUD); null = dieses Panel.
var dialog_parent: Node = null

var _inventory: Inventory = null
var _equipment: PlayerEquipment = null
var _slots: Array[ItemSlot] = []
var _group_labels: Dictionary[int, Label] = {}
var _layout_key := ""
var _scroll: ScrollContainer = null
var _groups: VBoxContainer = null
var _money_row: HBoxContainer = null
var _money_labels: Array[Label] = []
var _money_coins: Array[Panel] = []
var _sort_button: Button = null
var _split_dialog: SplitStackDialog = null


func _ready() -> void:
	theme_type_variation = &"ButtonList"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_groups = VBoxContainer.new()
	_groups.theme_type_variation = &"ButtonList"
	_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_groups)
	var bottom := HBoxContainer.new()
	bottom.theme_type_variation = &"InlineRow"
	add_child(bottom)
	_money_row = HBoxContainer.new()
	_money_row.name = "Money"
	_money_row.theme_type_variation = &"InlineRow"
	_money_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_money_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_money_row.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom.add_child(_money_row)
	for coin: Array in [[&"CoinGold", "G"], [&"CoinSilver", "S"], [&"CoinCopper", "K"]]:
		var amount := Label.new()
		amount.theme_type_variation = &"SmallLabel"
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_money_row.add_child(amount)
		_money_labels.append(amount)
		var symbol := make_coin(coin[0], coin[1])
		_money_row.add_child(symbol)
		_money_coins.append(symbol)
	_sort_button = Button.new()
	_sort_button.name = "SortButton"
	_sort_button.text = "Sortieren"
	_sort_button.focus_mode = Control.FOCUS_NONE
	_sort_button.tooltip_text = "Nach Typ, Seltenheit und Name ordnen und Stapel zusammenlegen"
	_sort_button.pressed.connect(func() -> void:
		if _inventory != null:
			_inventory.sort())
	bottom.add_child(_sort_button)
	if _inventory != null:
		_rebuild()


## Münzsymbol (18 × 18 px, Variation CoinGold/CoinSilver/CoinCopper) mit
## Buchstabe als zweitem Signal neben der Farbe.
static func make_coin(variation: StringName, letter_text: String) -> Panel:
	var symbol := Panel.new()
	symbol.theme_type_variation = variation
	symbol.custom_minimum_size = COIN_SIZE
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var letter := Label.new()
	letter.theme_type_variation = &"CoinText"
	letter.text = letter_text
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	symbol.add_child(letter)
	return symbol


## Verbindet das Fenster mit dem Inventar des eigenen Charakters.
func setup(inventory: Inventory) -> void:
	if _inventory != null and _inventory.changed.is_connected(_on_changed):
		_inventory.changed.disconnect(_on_changed)
	_inventory = inventory
	_inventory.changed.connect(_on_changed)
	_layout_key = ""
	if is_node_ready():
		_rebuild()


func get_inventory() -> Inventory:
	return _inventory


## Ausrüstung des eigenen Charakters (#29): Anlegen, Schleier, Vergleich.
func setup_equipment(equipment: PlayerEquipment) -> void:
	if _equipment != null:
		_equipment.equipment_changed.disconnect(_on_changed)
		_equipment.usability_changed.disconnect(_on_changed)
	_equipment = equipment
	if _equipment != null:
		_equipment.equipment_changed.connect(_on_changed)
		_equipment.usability_changed.connect(_on_changed)
	for slot in _slots:
		slot.equipment = _equipment
	if _inventory != null and is_node_ready():
		_refresh()


## Platz im Fenster oder null (für Tests).
func get_item_slot(container: int, index: int) -> ItemSlot:
	for slot in _slots:
		if slot.container == container and slot.index == index:
			return slot
	return null


func get_sort_button() -> Button:
	return _sort_button


func get_money_text() -> String:
	return _money_row.tooltip_text


## Überschrift einer Gruppe (für Tests).
func get_group_title(container: int) -> String:
	var label: Label = _group_labels.get(container)
	return label.text if label != null else ""


## Offener Dialog „Stapel teilen“ oder null.
func get_split_dialog() -> SplitStackDialog:
	return _split_dialog if is_instance_valid(_split_dialog) and _split_dialog.visible else null


## Shift + Klick: Dialog mit Anzahl öffnen.
func request_split(container: int, index: int) -> void:
	var slot := _inventory.get_slot(container, index)
	var count := int(slot.get("count", 0))
	if count < 2:
		return
	var item_id: StringName = slot["id"]
	if is_instance_valid(_split_dialog):
		_split_dialog.queue_free()
	_split_dialog = SplitStackDialog.new()
	(dialog_parent if dialog_parent != null else self).add_child(_split_dialog)
	_split_dialog.open(ItemInfo.display_name(item_id), count)
	_split_dialog.confirmed.connect(func(amount: int) -> void:
		_split_dialog.queue_free()
		# Inzwischen verändert? Dann nichts tun.
		var now := _inventory.get_slot(container, index)
		if now.get("id", &"") != item_id or int(now.get("count", 0)) != count:
			return
		var message := _inventory.split(container, index, amount)
		if message != "":
			error.emit(message))
	_split_dialog.cancelled.connect(_split_dialog.queue_free)


## Gegenstand außerhalb des Fensters losgelassen: nach Rückfrage zerstören.
## mouse_position = Bildschirmposition beim Loslassen.
func request_destroy(container: int, index: int, item_id: StringName, mouse_position: Vector2) -> void:
	if _is_over_inventory(mouse_position) or not confirm_handler.is_valid():
		return
	var count := int(_inventory.get_slot(container, index).get("count", 0))
	var label := ItemInfo.display_name(item_id) + (" (%d)" % count if count > 1 else "")
	confirm_handler.call("Gegenstand zerstören", "%s wirklich zerstören?" % label, "Zerstören", "Abbrechen",
			func() -> void:
				if _inventory.get_slot(container, index).get("id", &"") == item_id:
					_inventory.destroy(container, index))


func _is_over_inventory(mouse_position: Vector2) -> bool:
	var window := _find_window()
	if window != null and window.get_global_rect().has_point(mouse_position):
		return true
	var hovered := get_viewport().gui_get_hovered_control() if get_viewport() != null else null
	if hovered is BagBarSlot or hovered is EquipmentSlot:
		return true
	# Über dem Charakterfenster (#29) wird nichts zerstört.
	var node: Node = hovered
	while node != null:
		if node is CharacterPanel:
			return true
		if node is HudWindow:
			return not node.find_children("*", "CharacterPanel", true, false).is_empty()
		node = node.get_parent()
	return false


func _find_window() -> Control:
	var node: Node = self
	while node != null:
		if node is HudWindow:
			return node as Control
		node = node.get_parent()
	return self


func _on_changed() -> void:
	if _key() != _layout_key:
		_rebuild()
	else:
		_refresh()


## Schlüssel des Aufbaus (Taschen und Größen); ändert er sich, wird neu gebaut.
func _key() -> String:
	var parts: PackedStringArray = []
	for container in _inventory.get_container_count():
		parts.append("%s:%d" % [_inventory.get_bag(container), _inventory.get_container_size(container)])
	return ",".join(parts)


func _rebuild() -> void:
	if _inventory == null or _groups == null:
		return
	_layout_key = _key()
	for child in _groups.get_children():
		_groups.remove_child(child)
		child.queue_free()
	_slots.clear()
	_group_labels.clear()
	for container in _inventory.get_container_count():
		if not _inventory.has_container(container) or _inventory.get_container_size(container) == 0:
			continue
		var group := VBoxContainer.new()
		group.theme_type_variation = &"SlotColumn"
		_groups.add_child(group)
		var title := Label.new()
		title.theme_type_variation = &"SmallLabel"
		group.add_child(title)
		_group_labels[container] = title
		var grid := GridContainer.new()
		grid.theme_type_variation = &"SlotGrid"
		grid.columns = COLUMNS
		group.add_child(grid)
		for index in _inventory.get_container_size(container):
			var slot: ItemSlot = ITEM_SLOT_SCENE.instantiate()
			grid.add_child(slot)
			slot.equipment = _equipment
			slot.setup(_inventory, container, index)
			slot.error.connect(error.emit)
			slot.split_requested.connect(request_split)
			slot.released_outside.connect(func(c: int, i: int, id: StringName) -> void:
				request_destroy(c, i, id, get_viewport().get_mouse_position()))
			_slots.append(slot)
	_refresh()
	_update_list_height.call_deferred()


func _refresh() -> void:
	for slot in _slots:
		slot.refresh()
	for container: int in _group_labels:
		var free := 0
		for index in _inventory.get_container_size(container):
			if _inventory.is_slot_empty(container, index):
				free += 1
		_group_labels[container].text = "%s (%d / %d frei)" % [_inventory.get_container_name(container),
				free, _inventory.get_container_size(container)]
	var parts := ItemInfo.money_parts(_inventory.money)
	var values := [parts.x, parts.y, parts.z]
	for i in 3:
		# Gold nur ab 1 Gold, Silber ab 1 Silber oder mit Gold; Kupfer immer.
		var shown: bool = i == 2 or values[i] > 0 or (i == 1 and parts.x > 0)
		_money_labels[i].visible = shown
		_money_coins[i].visible = shown
		_money_labels[i].text = StatFormat.grouped(values[i]) if i == 0 else str(values[i])
	_money_row.tooltip_text = "Geld: %s" % ItemInfo.money_text(_inventory.money)


## Liste so hoch wie ihr Inhalt, höchstens MAX_LIST_HEIGHT.
func _update_list_height() -> void:
	if _groups == null or _scroll == null:
		return
	_scroll.custom_minimum_size.y = minf(_groups.get_combined_minimum_size().y, MAX_LIST_HEIGHT)
