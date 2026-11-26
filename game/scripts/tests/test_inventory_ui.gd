extends TestSuite
## Tests für die Oberfläche des Inventars (Ticket #18) mit dem echten HUD:
## Taschenfenster (Gruppen, Plätze, Anzahl, Seltenheitsrahmen, Tooltip, Geld,
## Sortieren, Teilen, Zerstören mit Rückfrage), Taschenleiste (Tasche anlegen,
## Meldung bei voller Tasche, Taschenplätze tauschen) und die Zahl freier
## Plätze am Rucksack-Symbol.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const INVENTORY_PANEL_SCENE := preload("res://scenes/ui/hud/inventory_panel.tscn")

var _hud: Hud = null
var _panel: InventoryPanel = null
var _inv: Inventory = null
var _errors: PackedStringArray = []
var _asked: Array = []


func before_all() -> void:
	_hud = HUD_SCENE.instantiate()
	tree.root.add_child(_hud)
	_panel = INVENTORY_PANEL_SCENE.instantiate()
	_hud.get_hud_window(&"bags").set_content(_panel)
	_panel.dialog_parent = _hud
	_panel.confirm_handler = func(title: String, message: String, confirm_text: String,
			_cancel_text: String, on_confirm: Callable) -> void:
		_asked.append([title, message, confirm_text, on_confirm])
	_panel.error.connect(func(message: String) -> void: _errors.append(message))
	for slot in _hud.get_bag_bar_slots():
		slot.error.connect(func(message: String) -> void: _errors.append(message))


func after_all() -> void:
	if _hud != null:
		_hud.free()


func _reset() -> void:
	_inv = Inventory.new(16)
	_hud.setup_inventory(_inv)
	_panel.setup(_inv)
	_errors.clear()
	_asked.clear()


func _bag_bar_slot(bag_slot: int) -> BagBarSlot:
	for slot in _hud.get_bag_bar_slots():
		if slot.bag_slot == bag_slot:
			return slot
	return null


func test_rucksack_und_freie_plaetze() -> void:
	_reset()
	check_equal(_hud.get_free_slot_text(), "16", "16 freie Plätze am Rucksack-Symbol")
	check(_panel.get_item_slot(0, 15) != null, "16 Plätze im Fenster")
	check(_panel.get_item_slot(0, 16) == null, "Nicht mehr")
	check_equal(_panel.get_group_title(0), "Rucksack (16 / 16 frei)", "Gruppenname")
	_inv.add_item(&"wolfsfell", 7)
	check_equal(_hud.get_free_slot_text(), "15", "Zahl aktualisiert sich sofort")
	check_equal(_panel.get_group_title(0), "Rucksack (15 / 16 frei)", "Gruppe aktualisiert")
	check_equal(_bag_bar_slot(1).bag_slot, 1, "Taschenplatz 1 vorhanden")
	check_equal(_hud.get_bag_bar_slots().size(), 4, "Vier Taschenplätze")


func test_platz_zeigt_gegenstand() -> void:
	_reset()
	_inv.add_item(&"wolfsfell", 7)
	_inv.add_item(&"lederkappe")
	var fell := _panel.get_item_slot(0, 0)
	check_equal(fell.text, "Wo", "Kürzel als Platzhalter-Icon")
	var count: Label = fell.get_node("%Count")
	check(count.visible and count.text == "7", "Anzahl unten rechts")
	check(not (fell.get_node("%RarityFrame") as Panel).visible, "Kein Rahmen bei Gewöhnlich")
	var kappe := _panel.get_item_slot(0, 1)
	var frame: Panel = kappe.get_node("%RarityFrame")
	check(frame.visible, "Rahmen ab Ungewöhnlich")
	check_equal(frame.self_modulate, ItemInfo.rarity_color(&"lederkappe"), "Rahmen in Seltenheitsfarbe")
	check(not (kappe.get_node("%Count") as Label).visible, "Keine Anzahl bei 1")
	check_equal(_panel.get_item_slot(0, 2).text, "", "Leerer Platz ohne Text")


func test_tooltip() -> void:
	var text := ItemTooltip.text(&"wolfsfell", 7)
	for part in ["Wolfsfell", "Gewöhnlich · Material", "Ein struppiges Fell.", "Stapel: 7 / 20",
			"Verkaufswert: 5 Kupfer (Stapel: 35 Kupfer)"]:
		check(text.contains(part), "Tooltip enthält „%s“: %s" % [part, text])
	check(ItemTooltip.text(&"tasche_gross").contains("Tasche mit 10 Plätzen"), "Taschen nennen ihre Plätze")
	check(ItemTooltip.text(&"brief_versiegelt").contains("Kein Verkaufswert"), "Ohne Verkaufswert")
	var box := ItemTooltip.create(&"leuchtkristall", 3)
	var title := box.get_child(0) as Label
	check_equal(title.text, "Leuchtkristall", "Name oben")
	check_equal(title.get_theme_color(&"font_color"), ItemInfo.rarity_color(&"leuchtkristall"), "Name in Seltenheitsfarbe")
	check((box.get_child(1) as Label).text.begins_with("Episch"), "Seltenheit als Text")
	box.free()


func test_tasche_anlegen_ueber_taschenleiste() -> void:
	_reset()
	_inv.add_item(&"tasche_klein")
	var drag := ItemDragData.from_slot(_inv, 0, 0)
	var bag_slot := _bag_bar_slot(1)
	check(bag_slot._can_drop_data(Vector2.ZERO, drag), "Tasche passt auf den Taschenplatz")
	bag_slot._drop_data(Vector2.ZERO, drag)
	check_equal(_inv.get_bag(1), &"tasche_klein", "Tasche angelegt")
	check_equal(bag_slot.text, "KB", "Taschenplatz zeigt die Tasche (Kürzel)")
	check_equal(_hud.get_free_slot_text(), "22", "16 + 6 frei")
	check(_panel.get_item_slot(1, 5) != null, "Neue Gruppe mit 6 Plätzen")
	check_equal(_panel.get_group_title(1), "Kleiner Beutel (6 / 6 frei)", "Gruppe heißt wie die Tasche")
	_inv.add_item(&"wolfsfell")
	check(not bag_slot._can_drop_data(Vector2.ZERO, ItemDragData.from_slot(_inv, 0, 0)), "Keine Tasche: nicht ablegbar")
	# Volle Tasche abnehmen: Meldung.
	_inv.move(0, 0, 1, 0)
	var item_slot := _panel.get_item_slot(0, 3)
	item_slot._drop_data(Vector2.ZERO, ItemDragData.from_bag_slot(_inv, 1))
	check_equal(_errors, PackedStringArray([Inventory.MSG_BAG_NOT_EMPTY]), "„Die Tasche ist nicht leer.“")
	check_equal(_inv.get_bag(1), &"tasche_klein", "Tasche bleibt")
	# Taschenplätze tauschen.
	_bag_bar_slot(3)._drop_data(Vector2.ZERO, ItemDragData.from_bag_slot(_inv, 1))
	check_equal(_inv.get_bag(3), &"tasche_klein", "Tasche auf Platz 3")
	check(not _panel.get_item_slot(3, 0)._can_drop_data(Vector2.ZERO, ItemDragData.from_bag_slot(_inv, 3)),
			"Tasche kann nicht in sich selbst liegen")


func test_verschieben_per_ablegen() -> void:
	_reset()
	_inv.add_item(&"wolfsfell", 5)
	_inv.add_item(&"brot_hart", 2)
	var target := _panel.get_item_slot(0, 0)
	target._drop_data(Vector2.ZERO, ItemDragData.from_slot(_inv, 0, 1))
	check_equal(_panel.get_item_slot(0, 0).get_item_id(), &"brot_hart", "Getauscht")
	check_equal(_panel.get_item_slot(0, 1).get_item_id(), &"wolfsfell", "Getauscht")


func test_sortieren_button() -> void:
	_reset()
	_inv.add_item(&"zahn_zerbrochen", 2)
	_inv.add_item(&"tasche_mittel")
	_panel.get_sort_button().pressed.emit()
	check_equal(_panel.get_item_slot(0, 0).get_item_id(), &"tasche_mittel", "Tasche zuerst")
	check_equal(_panel.get_item_slot(0, 1).get_item_id(), &"zahn_zerbrochen", "Plunder zuletzt")


func test_teilen_mit_fenster() -> void:
	_reset()
	_inv.add_item(&"wolfsfell", 9)
	_panel.request_split(0, 0)
	var dialog := _panel.get_split_dialog()
	check(dialog != null, "Fenster „Stapel teilen“ offen")
	if dialog == null:
		return
	dialog.set_amount(4)
	(dialog.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	check_equal(int(_inv.get_slot(0, 0)["count"]), 5, "5 bleiben")
	check_equal(int(_inv.get_slot(0, 1)["count"]), 4, "4 abgeteilt")
	_panel.request_split(0, 1)
	dialog = _panel.get_split_dialog()
	(dialog.find_child("CancelButton", true, false) as Button).pressed.emit()
	check_equal(int(_inv.get_slot(0, 1)["count"]), 4, "Abbrechen ändert nichts")


func test_zerstoeren_nur_nach_rueckfrage() -> void:
	_reset()
	_inv.add_item(&"brief_versiegelt")
	var window := _hud.get_hud_window(&"bags")
	_hud.open_window(&"bags")
	var inside := window.get_global_rect().get_center()
	_panel.request_destroy(0, 0, &"brief_versiegelt", inside)
	check(_asked.is_empty(), "Im Fenster losgelassen: keine Rückfrage")
	_panel.request_destroy(0, 0, &"brief_versiegelt", Vector2(-50, -50))
	check_equal(_asked.size(), 1, "Außerhalb: Rückfrage")
	if _asked.is_empty():
		return
	check_equal(_asked[0][1], "Versiegelter Brief wirklich zerstören?", "Text der Rückfrage")
	check_equal(_inv.count_item(&"brief_versiegelt"), 1, "Vor der Bestätigung noch da")
	(_asked[0][3] as Callable).call()
	check_equal(_inv.count_item(&"brief_versiegelt"), 0, "Nach Bestätigung zerstört (auch Questgegenstand)")
	_hud.close_window(&"bags")


func test_geldanzeige() -> void:
	_reset()
	_inv.money = 1234567
	check_equal(_panel.get_money_text(), "Geld: 123 Gold 45 Silber 67 Kupfer", "Tooltip der Geldanzeige")
	var labels: Array[Label] = []
	for child in _panel.find_child("Money", true, false).get_children():
		if child is Label:
			labels.append(child)
	check_equal(labels.size(), 3, "Drei Beträge")
	check_equal([labels[0].text, labels[1].text, labels[2].text], ["123", "45", "67"], "Gold, Silber, Kupfer")
	_inv.money = 5
	check(not labels[0].visible and not labels[1].visible and labels[2].visible, "Nur Kupfer bei kleinen Beträgen")
