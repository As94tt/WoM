class_name InventoryDevSection
extends Node
## Abschnitt „Inventar“ im Entwickler-Panel (Ticket #18). Wirkt nur auf das
## Inventar des eigenen Charakters (rein lokal, es gibt noch keine
## Synchronisierung):
##
## - Testgegenstand ins Inventar legen: Auswahlliste (alle Zeilen aus
##   gegenstaende.csv) und Anzahl; „Inventar ist voll.“ erscheint oben in der
##   Mitte wie im Spiel.
## - „Alle Testgegenstände hinzufügen“ (je einer bzw. ein halber Stapel).
## - Geld hinzufügen (+1 Gold, +1 Silber, +10 Kupfer), Geld auf 0.
## - Inventar leeren (Gegenstände und Taschen; Geld bleibt).
## - Infozeile: freie Plätze, Geld, wie oft gespeichert wurde.

var _world: GameWorld = null
var _items: OptionButton = null
var _amount: SpinBox = null
var _info: Label = null
var _ids: Array[StringName] = []


func setup(panel: DevPanel, world: GameWorld) -> void:
	_world = world
	var section := panel.add_section("Inventar")
	_info = panel.add_info(section, "Kein Inventar")
	panel.add_info(section, "Testgegenstand ins Inventar legen:")
	_items = OptionButton.new()
	_items.focus_mode = Control.FOCUS_NONE
	_items.fit_to_longest_item = false
	section.add_child(_items)
	_fill_items()
	var row := HBoxContainer.new()
	row.theme_type_variation = &"InlineRow"
	section.add_child(row)
	_amount = SpinBox.new()
	_amount.min_value = 1
	_amount.max_value = 200
	_amount.value = 1
	_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_amount)
	var add := Button.new()
	add.text = "Hinzufügen"
	add.focus_mode = Control.FOCUS_NONE
	add.pressed.connect(_add_selected)
	row.add_child(add)
	panel.add_button(section, "Alle Testgegenstände hinzufügen", _add_all)
	panel.add_button(section, "Geld: +1 Gold", _add_money.bind(ItemInfo.COPPER_PER_GOLD))
	panel.add_button(section, "Geld: +1 Silber", _add_money.bind(ItemInfo.COPPER_PER_SILVER))
	panel.add_button(section, "Geld: +10 Kupfer", _add_money.bind(10))
	panel.add_button(section, "Geld auf 0 setzen", func() -> void:
		var inv := _inventory()
		if inv != null:
			inv.money = 0)
	panel.add_button(section, "Inventar leeren", func() -> void:
		var inv := _inventory()
		if inv != null:
			inv.clear())
	Data.reloaded.connect(func(_ok: bool, _lines: PackedStringArray) -> void: _fill_items())
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_info)
	add_child(timer)


## Legt die gewählte Anzahl des gewählten Gegenstands hinein.
func add_item(id: StringName, count: int) -> Inventory.AddResult:
	var inv := _inventory()
	if inv == null:
		return Inventory.AddResult.UNKNOWN
	var result := inv.add_item(id, count)
	if result == Inventory.AddResult.FULL:
		_world.show_inventory_error(Inventory.MSG_FULL)
	return result


func _fill_items() -> void:
	if _items == null:
		return
	_items.clear()
	_ids.clear()
	for row in Data.gegenstaende():
		var id := StringName(row.id())
		_ids.append(id)
		_items.add_item("%s (%s)" % [ItemInfo.display_name(id), id])


func _add_selected() -> void:
	if _items.selected < 0 or _items.selected >= _ids.size():
		return
	add_item(_ids[_items.selected], int(_amount.value))


func _add_all() -> void:
	for id in _ids:
		@warning_ignore("integer_division")
		var count := maxi(1, ItemInfo.stack_size(id) / 2)
		if add_item(id, count) == Inventory.AddResult.FULL:
			return


func _add_money(copper: int) -> void:
	var inv := _inventory()
	if inv != null:
		inv.add_money(copper)


func _inventory() -> Inventory:
	return _world.get_local_inventory() if _world != null else null


func _update_info() -> void:
	if _info == null or not _info.is_visible_in_tree():
		return
	var inv := _inventory()
	if inv == null:
		_info.text = "Kein Inventar"
		return
	var saver := _world.get_inventory_saver()
	_info.text = "\n".join([
		"Freie Plätze: %d / %d" % [inv.get_free_slots(), inv.get_total_slots()],
		"Geld: %s" % ItemInfo.money_text(inv.money),
		"Gespeichert: %d× (Testcharaktere nie in eine Datei)" % (saver.save_count if saver != null else 0),
	])
