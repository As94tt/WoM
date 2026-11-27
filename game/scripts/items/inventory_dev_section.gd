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
## - Ausrüstung (#29): „Testausrüstung der Klasse“ (Stufe 5 bzw. 15: der Satz
##   der eigenen Rüstungsklasse, eine passende Waffe, Schild bzw. Fokus,
##   Schmuck), „Reisetaschen anlegen“ (Platz zum Testen) und „Alles ablegen“.
##   Angelegt wird wie im Spiel (Rechtsklick oder Ziehen), der Host prüft.
##   Die Waffenschalter für Spielerfiguren aus #19/#33 ersetzt die Ausrüstung.

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
	panel.add_button(section, "Testausrüstung der Klasse (Stufe 5)", _give_class_set.bind(5))
	panel.add_button(section, "Testausrüstung der Klasse (Stufe 15)", _give_class_set.bind(15))
	panel.add_button(section, "Reisetaschen anlegen (4 ×)", _equip_big_bags)
	panel.add_button(section, "Ausrüstung: alles ablegen", _unequip_all)
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
	elif result == Inventory.AddResult.UNIQUE:
		_world.show_inventory_error(Inventory.MSG_UNIQUE)
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


## Testausrüstung (#29) der eigenen Klasse mit Gegenstandsstufe level: die
## Rüstungsteile der höchsten erlaubten Rüstungsklasse, Umhang und Schmuck,
## die erste nutzbare Waffe und der erste nutzbare Schild bzw. Fokus.
func _give_class_set(level: int) -> void:
	var equipment := _equipment()
	if equipment == null:
		return
	var class_id := equipment.get_class_id()
	var rules := Data.klassenausruestung(class_id)
	var armor := StringName(str(rules.get_value("ruestungsklasse", ""))) if rules != null else &""
	var weapon_taken := false
	var off_taken := false
	for row in Data.gegenstaende():
		var id := StringName(row.id())
		if not ItemInfo.is_equipment(id) or ItemInfo.item_level(id) != level 				or EquipmentRules.class_reason(id, class_id) != "":
			continue
		if ItemInfo.armor_class(id) != &"" and ItemInfo.armor_class(id) != armor:
			continue
		if ItemInfo.is_damage_weapon(id):
			if weapon_taken or ItemInfo.slot(id) in [&"zauberstab", &"fernkampfwaffe"]:
				continue
			weapon_taken = true
		elif ItemInfo.weapon_type(id) != &"":
			if off_taken or EquipmentRules.occupies_both_hands(id):
				continue
			off_taken = true
		if add_item(id, 1) == Inventory.AddResult.FULL:
			return


## Legt in jeden freien Taschenplatz eine Reisetasche (Platz zum Testen).
func _equip_big_bags() -> void:
	var inv := _inventory()
	if inv == null:
		return
	for bag_slot in range(1, Inventory.BAG_SLOT_COUNT + 1):
		if inv.get_bag(bag_slot) != &"":
			continue
		if inv.add_item(&"tasche_gross") != Inventory.AddResult.ADDED:
			_world.show_inventory_error(Inventory.MSG_FULL)
			return
		var at := inv.find_item(&"tasche_gross")
		inv.equip_bag(at.x, at.y, bag_slot)


## Alle angelegten Gegenstände ablegen (je ein Wunsch an den Host).
func _unequip_all() -> void:
	var equipment := _equipment()
	if equipment == null:
		return
	for place in EquipmentRules.all_places():
		if equipment.has_item(place):
			equipment.request_unequip(place)


func _equipment() -> PlayerEquipment:
	var player := _world.get_local_player() if _world != null else null
	return player.get_equipment() if player != null else null


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
