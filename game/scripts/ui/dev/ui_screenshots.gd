class_name UiScreenshots
extends Node
## Entwickler-Hilfsmittel (nur Debug-Builds, keine Spielmechanik): macht
## Bildschirmfotos der Oberfläche und beendet das Spiel.
##
##   --ui-screenshots=<Ordner>            Hauptmenü, Dialog, Charakterauswahl
##                                        und -erstellung
##   --host --ui-screenshots=<Ordner>     HUD mit Ziel, Zauber, Auren und die
##                                        Fenster (Taschen, Charakter, …)
##   --host --ui-screenshots=<Ordner> --ui-screenshots-icons [--class warrior]
##                                        Zauber-Icons der Klasse: Stufe 30,
##                                        Aktionsleiste, Zauberbuch, Talentfenster
##                                        ohne und mit jeder Spezialisierung, HUD
##                                        mit den Auren der Klasse
##   --host --class warrior --ui-screenshots=<Ordner> --ui-screenshots-equipment
##                                        Ausrüstung (#29): Charakterfenster mit
##                                        angelegter Ausrüstung, Tooltip mit
##                                        Vergleich, roter Schleier, Aufleuchten
##                                        beim Ziehen, Fehlermeldung beim
##                                        verbotenen Anlegen
## Optional --ui-screenshots-prefix=<Text> vor jedem Dateinamen (z. B. „1080p_“).
## Fenstergröße über Godots --resolution (z. B. --resolution 2560x1440).
## Gestartet vom Hauptmenü (MainMenu._ready); die Szene bleibt bei
## Szenenwechseln erhalten (hängt an der Wurzel).

const ARG_DIR := "--ui-screenshots"
const ARG_PREFIX := "--ui-screenshots-prefix"
const ARG_ICONS := "--ui-screenshots-icons"
const ARG_EQUIPMENT := "--ui-screenshots-equipment"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const CHARACTER_CREATION_SCENE := "res://scenes/ui/character_creation.tscn"

var _dir := ""
var _prefix := ""
var _hud_tour := false
var _icon_tour := false
var _equipment_tour := false


## Startet die Tour, wenn der Startparameter gesetzt ist.
static func start_if_requested(tree: SceneTree) -> void:
	if not OS.is_debug_build() or tree.root.has_node(^"UiScreenshots"):
		return
	var args := PackedStringArray()
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	var dir := ""
	var prefix := ""
	var hud := false
	var icons := false
	var equipment := false
	for arg in args:
		if arg.begins_with(ARG_PREFIX + "="):
			prefix = arg.get_slice("=", 1)
		elif arg.begins_with(ARG_DIR + "="):
			dir = arg.get_slice("=", 1)
		elif arg == "--host":
			hud = true
		elif arg == ARG_ICONS:
			icons = true
		elif arg == ARG_EQUIPMENT:
			equipment = true
	if dir == "":
		return
	var node := UiScreenshots.new()
	node.name = "UiScreenshots"
	node._dir = dir
	node._prefix = prefix
	node._hud_tour = hud
	node._icon_tour = hud and icons
	node._equipment_tour = hud and equipment
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(node)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	if _equipment_tour:
		_run_equipment_tour()
	elif _icon_tour:
		_run_icon_tour()
	elif _hud_tour:
		_run_hud_tour()
	else:
		_run_menu_tour()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(_prefix + file_name + ".png")
	image.save_png(path)
	print("UiScreenshots: %s (%d × %d)" % [path, image.get_width(), image.get_height()])


func _run_menu_tour() -> void:
	await _wait(1.5)
	await _shot("hauptmenue")
	var menu := get_tree().current_scene
	var dialog := menu.get_node_or_null(^"%MessageDialog") as MessageDialog
	if dialog != null:
		dialog.open("Sitzung beendet", "Der Host hat die Sitzung beendet. Ihr seid zurück im Hauptmenü.")
		await _wait(0.5)
		await _shot("dialog")
		dialog.visible = false
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
	await _wait(2.0)
	await _shot("charakterauswahl")
	get_tree().change_scene_to_file(CHARACTER_CREATION_SCENE)
	await _wait(2.0)
	await _shot("charaktererstellung")
	get_tree().quit()


func _run_hud_tour() -> void:
	var world: Node = null
	for i in 120:
		await _wait(0.25)
		world = get_tree().current_scene
		if world != null and world.has_method(&"get_local_player") and world.get_local_player() != null:
			break
	if world == null or not world.has_method(&"get_hud"):
		push_error("UiScreenshots: Spielwelt nicht gefunden")
		get_tree().quit(1)
		return
	await _wait(2.0)
	var hud: Hud = world.get_hud()
	var player: PlayerCharacter = world.get_local_player()
	var inventory: Inventory = world.get_local_inventory()
	if inventory != null:
		for id: StringName in [&"wolfsfell", &"schwert_rostig", &"lederkappe", &"tasche_mittel",
				&"tasche_gross", &"leuchtkristall", &"brot_hart", &"zahn_zerbrochen", &"brief_versiegelt"]:
			inventory.add_item(id, 7 if ItemInfo.stack_size(id) > 1 else 1)
		inventory.add_item(&"tasche_klein")
		inventory.add_money(12345)
	# Ziel: nächster Kandidat der Tab-Auswahl.
	var targeting := player.get_targeting()
	var target: Unit = null
	if targeting != null:
		var candidates := targeting.get_tab_candidates()
		if candidates.is_empty():
			# Nächsten Feind suchen und die eigene Figur davor stellen (nur für
			# das Bild, wie ein Teleport im Entwickler-Panel).
			var best: Unit = null
			for node in get_tree().get_nodes_in_group(Unit.GROUP):
				var unit := node as Unit
				if unit == null or unit == player or unit.is_dead() or not Combat.is_hostile(player, unit):
					continue
				if best == null or unit.global_position.distance_to(player.global_position) \
						< best.global_position.distance_to(player.global_position):
					best = unit
			if best != null:
				var away := (player.global_position - best.global_position)
				away.y = 0.0
				away = away.normalized() if away.length() > 0.01 else Vector3.BACK
				player.global_position = best.global_position + away * 12.0
				player.look_at(Vector3(best.global_position.x, player.global_position.y, best.global_position.z))
				await _wait(1.0)
				candidates = targeting.get_tab_candidates()
		if not candidates.is_empty():
			target = candidates[0]
			targeting.select(target)
	# Auren (nur zur Ansicht, wie die Testauren im Entwickler-Panel).
	for aura_id in ["magischer_schild", "kampfschrei"]:
		var data := load("res://data/auras/%s.tres" % aura_id) as AuraData
		if data != null:
			player.get_combat().apply_aura(data, player)
	if target != null:
		for aura_id in ["magische_fessel", "erfrierung", "geschwaecht"]:
			var data := load("res://data/auras/%s.tres" % aura_id) as AuraData
			if data != null and target.get_combat() != null:
				target.get_combat().apply_aura(data, player)
	await _wait(0.5)
	# Zauber mit Zauberzeit wirken, damit die Zauberleiste zu sehen ist.
	var abilities := player.get_abilities()
	for ability in abilities.get_learned_abilities():
		if ability.get_cast_time() > 0.5:
			abilities.use_ability(ability)
			break
	await _wait(0.6)
	await _shot("hud_ziel")
	await _wait(3.0)
	hud.open_window(&"bags")
	await _wait(0.5)
	await _shot("inventar")
	# Tooltip eines Gegenstands wie beim Überfahren mit der Maus.
	var tip := PanelContainer.new()
	tip.theme_type_variation = &"TooltipPanel"
	tip.add_child(ItemTooltip.create(&"leuchtkristall", 7))
	hud.add_child(tip)
	tip.position = Vector2(get_viewport().get_visible_rect().size.x - 760.0, 420.0)
	await _wait(0.3)
	await _shot("tooltip")
	tip.queue_free()
	hud.close_window(&"bags")
	hud.open_window(&"character")
	await _wait(0.5)
	await _shot("charakterfenster")
	hud.open_window(&"spellbook")
	await _wait(0.5)
	await _shot("zauberbuch")
	hud.close_window(&"character")
	hud.close_window(&"spellbook")
	hud.open_window(&"talents")
	await _wait(0.5)
	await _shot("talente")
	hud.close_window(&"talents")
	hud.open_window(&"map")
	await _wait(1.0)
	await _shot("karte")
	hud.close_window(&"map")
	# Esc schließt erst Ziel bzw. Fenster, dann öffnet es das Spielmenü.
	var game_menu: Control = hud.get_node(^"%GameMenu")
	for i in 4:
		if game_menu.visible:
			break
		hud.handle_cancel()
		await _wait(0.2)
	await _wait(0.5)
	await _shot("spielmenue")
	get_tree().quit()


## Wartet auf die Spielwelt mit eigener Figur (null, wenn sie nicht kommt).
func _await_world() -> Node:
	for i in 120:
		await _wait(0.25)
		var world := get_tree().current_scene
		if world != null and world.has_method(&"get_local_player") and world.get_local_player() != null:
			return world
	return null


## Zauber-Icons einer Klasse (Magier bzw. Krieger über --class): Stufe 30,
## alle Fähigkeiten auf der Leiste, dann Talentfenster, Zauberbuch und
## Aktionsleiste ohne und mit jeder Spezialisierung, zuletzt die Auren.
func _run_icon_tour() -> void:
	var world := await _await_world()
	if world == null or not world.has_method(&"get_hud"):
		push_error("UiScreenshots: Spielwelt nicht gefunden")
		get_tree().quit(1)
		return
	await _wait(2.0)
	var hud: Hud = world.get_hud()
	var player: PlayerCharacter = world.get_local_player()
	var class_id := String(player.get_talents().get_class_data().id)
	player.get_experience().request_dev("set_level", 30)
	await _wait(1.0)
	player.get_talents().request_dev("unlock", "")
	await _wait(0.5)
	hud.get_level_up_banner().visible = false
	await _icon_shots(hud, "%s_basis" % class_id)
	for spec in player.get_talents().get_specializations():
		if spec.transformations.is_empty():
			continue
		player.get_talents().request_clear_spec()
		await _wait(0.3)
		player.get_talents().request_choose_spec(spec.id)
		await _wait(0.8)
		await _icon_shots(hud, String(spec.id))
	# Auren der Klasse an sich selbst (wie die Testauren im Entwickler-Panel).
	var count := 0
	for file in ResourceLoader.list_directory("res://data/auras/"):
		var data := load("res://data/auras/" + file) as AuraData
		if data == null or data.icon == null or data.hidden:
			continue
		if not data.icon.resource_path.contains("/abilities/%s/" % class_id):
			continue
		player.get_combat().apply_aura(data, player)
		count += 1
	print("UiScreenshots: %d Auren mit Icon angewendet" % count)
	await _wait(0.5)
	await _shot("icons_%s_hud_auren" % class_id)
	get_tree().quit()


func _icon_shots(hud: Hud, label: String) -> void:
	await _shot("icons_%s_aktionsleiste" % label)
	hud.open_window(&"spellbook")
	var books := hud.find_children("*", "SpellbookPanel", true, false)
	if not books.is_empty():
		(books[0] as SpellbookPanel).show_tab(1)  # Reiter der Klasse
	await _wait(0.5)
	await _shot("icons_%s_zauberbuch" % label)
	hud.close_window(&"spellbook")
	hud.open_window(&"talents")
	await _wait(0.5)
	await _shot("icons_%s_talente" % label)
	hud.close_window(&"talents")
	await _wait(0.2)


## Ausrüstung (#29), gedacht für den Krieger (--class warrior): Stufe 15,
## Satz der Stufe 15 mit Schmuck, Siegel und Talismanen anlegen (wie mit
## Rechtsklick, der Host prüft), dann Bilder vom Charakterfenster, vom
## Tooltip mit Vergleich, vom roten Schleier, vom Aufleuchten beim Ziehen und
## von der Meldung beim verbotenen Anlegen.
func _run_equipment_tour() -> void:
	var world := await _await_world()
	if world == null or not world.has_method(&"get_hud"):
		push_error("UiScreenshots: Spielwelt nicht gefunden")
		get_tree().quit(1)
		return
	await _wait(2.0)
	var hud: Hud = world.get_hud()
	var player: PlayerCharacter = world.get_local_player()
	var inventory: Inventory = world.get_local_inventory()
	var equipment := player.get_equipment()
	player.get_experience().request_dev("set_level", 15)
	await _wait(1.0)
	hud.get_level_up_banner().visible = false
	for bag_slot in range(1, Inventory.BAG_SLOT_COUNT + 1):
		inventory.add_item(&"tasche_gross")
		var at := inventory.find_item(&"tasche_gross")
		inventory.equip_bag(at.x, at.y, bag_slot)
	var worn: Array[StringName] = [&"eisen_helm", &"stahl_schulter", &"stahl_brust", &"stahl_guertel", &"stahl_beine",
			&"stahl_schuhe", &"stahl_handschuhe", &"stahl_armschienen", &"umhang_faehrte", &"kette_perlen",
			&"ring_wachsamkeit", &"ring_kupfer", &"schwert_kriegs", &"schild_eisen", &"siegel_glut",
			&"talisman_wolfszahn", &"talisman_banditenmuenze", &"talisman_eberhauer"]
	for id in worn:
		inventory.add_item(id)
		var at := inventory.find_item(id)
		equipment.request_equip_from_bag(at.x, at.y)
		await _wait(0.05)
	for id: StringName in [&"stahl_helm", &"zweihandaxt_eisen", &"stab_runen", &"zauberstab_glut", &"klinge_veteran",
			&"bogen_jagd", &"wildleder_helm", &"leinen_brust", &"ring_kupfer", &"schild_holz"]:
		inventory.add_item(id)
	await _wait(0.5)
	hud.open_window(&"character")
	await _wait(0.6)
	await _shot("ausruestung_charakterfenster")
	hud.open_window(&"bags")
	await _wait(0.6)
	await _shot("ausruestung_schleier")
	# Tooltip mit Vergleich wie beim Überfahren (Inhalt aus dem echten Platz).
	var panel := hud.find_children("*", "InventoryPanel", true, false)[0] as InventoryPanel
	var at := inventory.find_item(&"stahl_helm")
	var slot := panel.get_item_slot(at.x, at.y)
	var tip := await _show_tooltip(hud, slot._make_custom_tooltip("") as Control, slot)
	await _wait(0.4)
	await _shot("ausruestung_tooltip_vergleich")
	tip.queue_free()
	at = inventory.find_item(&"klinge_veteran")
	slot = panel.get_item_slot(at.x, at.y)
	tip = await _show_tooltip(hud, slot._make_custom_tooltip("") as Control, slot)
	await _wait(0.4)
	await _shot("ausruestung_tooltip_nicht_nutzbar")
	tip.queue_free()
	# Aufleuchten passender Plätze beim Ziehen (wie NOTIFICATION_DRAG_BEGIN).
	at = inventory.find_item(&"ring_kupfer")
	var drag := ItemDragData.from_slot(inventory, at.x, at.y)
	var character := hud.find_children("*", "CharacterPanel", true, false)[0] as CharacterPanel
	for place in EquipmentRules.all_places():
		var eq_slot := character.get_equipment_slot(place)
		if eq_slot != null:
			eq_slot._update_highlight(drag)
	await _wait(0.3)
	await _shot("ausruestung_ziehen_ringe")
	for place in EquipmentRules.all_places():
		var eq_slot := character.get_equipment_slot(place)
		if eq_slot != null:
			eq_slot._update_highlight(null)
	# Verbotenes Anlegen: Runenstab (nur Magier) per Rechtsklick.
	at = inventory.find_item(&"stab_runen")
	equipment.request_equip_from_bag(at.x, at.y)
	await _wait(0.3)
	await _shot("ausruestung_fehlermeldung")
	get_tree().quit()


func _show_tooltip(hud: Hud, content: Control, near: Control) -> PanelContainer:
	var tip := PanelContainer.new()
	tip.theme_type_variation = &"TooltipPanel"
	tip.add_child(content)
	hud.add_child(tip)
	await get_tree().process_frame
	var rect := near.get_global_rect()
	var size := tip.get_combined_minimum_size()
	var view := get_viewport().get_visible_rect().size
	tip.position = Vector2(clampf(rect.position.x - size.x - 12.0, 8.0, view.x - size.x - 8.0),
			clampf(rect.position.y - size.y * 0.5, 8.0, view.y - size.y - 8.0))
	return tip
