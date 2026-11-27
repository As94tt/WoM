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
##   --join <IP> --class warrior --ui-screenshots=<Ordner> --ui-screenshots-equipment
##                                        Zwei-Instanzen-Probe (#29) als Client:
##                                        Anlegen, Tauschen, verbotenes Anlegen und
##                                        Ablegen über den Host; gibt den Stand
##                                        aller Figuren im Log aus („Probe:“)
##   --host --ui-screenshots=<Ordner> --ui-screenshots-enemies
##                                        Gegner (#36): Testgelände mit Gegnern,
##                                        Zielrahmen (Elite, Selten, Boss), Leiche
##                                        nach dem Tod, Spawnbereiche und
##                                        Entwickler-Panel-Abschnitt „Gegner“
##   --host --ui-screenshots=<Ordner> --ui-screenshots-enemies-probe
##   --join <IP> --ui-screenshots=<Ordner> --ui-screenshots-enemies-probe
##                                        Zwei-Instanzen-Probe (#36): Der Host tötet
##                                        Gegner (schneller Respawn), der Client
##                                        steht zuerst bei den Wölfen (Respawn wird
##                                        verschoben) und geht dann weg; beide
##                                        geben ihren Stand im Log aus („Probe:“)
## Optional --ui-screenshots-prefix=<Text> vor jedem Dateinamen (z. B. „1080p_“).
## Fenstergröße über Godots --resolution (z. B. --resolution 2560x1440).
## Gestartet vom Hauptmenü (MainMenu._ready); die Szene bleibt bei
## Szenenwechseln erhalten (hängt an der Wurzel).

const ARG_DIR := "--ui-screenshots"
const ARG_PREFIX := "--ui-screenshots-prefix"
const ARG_ICONS := "--ui-screenshots-icons"
const ARG_EQUIPMENT := "--ui-screenshots-equipment"
const ARG_ENEMIES := "--ui-screenshots-enemies"
const ARG_ENEMIES_PROBE := "--ui-screenshots-enemies-probe"
## Zwei-Instanzen-Probe (#36): So lange steht der Client bei den Wölfen, so
## lange läuft die Probe insgesamt (länger als leiche_dauer).
const PROBE_STAY_NEAR := 35.0
const PROBE_DURATION := 135.0
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const CHARACTER_CREATION_SCENE := "res://scenes/ui/character_creation.tscn"

var _dir := ""
var _prefix := ""
var _hud_tour := false
var _icon_tour := false
var _equipment_tour := false
var _client_tour := false
var _enemy_tour := false
var _enemy_probe := false
var _is_client := false


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
	var enemies := false
	var enemy_probe := false
	var join := false
	for arg in args:
		if arg.begins_with(ARG_PREFIX + "="):
			prefix = arg.get_slice("=", 1)
		elif arg.begins_with(ARG_DIR + "="):
			dir = arg.get_slice("=", 1)
		elif arg == "--host":
			hud = true
		elif arg == "--join":
			join = true
		elif arg == ARG_ICONS:
			icons = true
		elif arg == ARG_EQUIPMENT:
			equipment = true
		elif arg == ARG_ENEMIES:
			enemies = true
		elif arg == ARG_ENEMIES_PROBE:
			enemy_probe = true
	if dir == "":
		return
	var node := UiScreenshots.new()
	node.name = "UiScreenshots"
	node._dir = dir
	node._prefix = prefix
	node._hud_tour = hud
	node._icon_tour = hud and icons
	node._equipment_tour = hud and equipment
	node._client_tour = join and equipment
	node._enemy_tour = hud and enemies
	node._enemy_probe = enemy_probe and (hud or join)
	node._is_client = join
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(node)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	if _enemy_probe:
		if _is_client:
			_run_enemy_probe_client()
		else:
			_run_enemy_probe_host()
	elif _enemy_tour:
		_run_enemy_tour()
	elif _client_tour:
		_run_equipment_client_tour()
	elif _equipment_tour:
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


## Zwei-Instanzen-Probe (#29) als Client: Jeder Schritt ist ein Wunsch an den
## Host; danach steht der vom Host übertragene Stand im Log.
func _run_equipment_client_tour() -> void:
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
	var errors: PackedStringArray = []
	equipment.request_failed.connect(func(reason: String) -> void: errors.append(reason))
	_probe("Start", world, player)
	for id: StringName in [&"eisen_helm", &"eisen_brust", &"schwert_eisen", &"schild_holz", &"zweihandschwert_eisen",
			&"stab_runen", &"talisman_wolfszahn"]:
		inventory.add_item(id)
	for id: StringName in [&"eisen_helm", &"eisen_brust", &"schwert_eisen", &"schild_holz", &"talisman_wolfszahn"]:
		var at := inventory.find_item(id)
		equipment.request_equip_from_bag(at.x, at.y)
		await _wait(0.4)
	_probe("Nach Anlegen", world, player)
	var at := inventory.find_item(&"zweihandschwert_eisen")
	equipment.request_equip_from_bag(at.x, at.y)
	await _wait(0.6)
	_probe("Nach Zweihand", world, player)
	at = inventory.find_item(&"stab_runen")
	equipment.request_equip_from_bag(at.x, at.y)
	await _wait(0.6)
	print("Probe: Meldungen: %s" % ", ".join(errors))
	hud.open_window(&"character")
	hud.open_window(&"bags")
	await _wait(0.6)
	await _shot("ausruestung_client")
	equipment.request_unequip(&"talisman_1")
	await _wait(0.6)
	_probe("Nach Ablegen Talisman", world, player)
	# Etwas warten, damit eine zweite Probe-Instanz diese Figur sieht.
	await _wait(8.0)
	_probe("Ende", world, player)
	get_tree().quit()


func _probe(label: String, world: Node, player: PlayerCharacter) -> void:
	var inventory: Inventory = world.get_local_inventory()
	var bag: PackedStringArray = []
	for container in inventory.get_container_count():
		for index in inventory.get_container_size(container):
			var slot := inventory.get_slot(container, index)
			if not slot.is_empty():
				bag.append(String(slot["id"]))
	var auras: PackedStringArray = []
	for inst in player.get_combat().get_auras():
		auras.append(String(inst.data.id))
	print("Probe: %s – eigene Ausrüstung %s, Tasche %s, Rüstung %d, Waffen-Zustände %s, Auren %s" % [label,
			player.get_equipment().equipment_state, bag, int(player.get_stats().get_value(&"armor")),
			_flags_text(player.get_stats()), auras])
	for other: PlayerCharacter in world.get_all_players():
		if other != player:
			print("Probe: %s – Figur %s sieht Ausrüstung %s" % [label, other.display_name,
					other.get_equipment().equipment_state])


func _flags_text(stats: CharacterStats) -> String:
	var parts: PackedStringArray = []
	for entry: Array in [[StatBlock.FLAG_MELEE_WEAPON, "Nahkampfwaffe"], [StatBlock.FLAG_SHIELD, "Schild"],
			[StatBlock.FLAG_OFFHAND_WEAPON, "Nebenhandwaffe"], [StatBlock.FLAG_RANGED_WEAPON, "Fernkampfwaffe"]]:
		if stats.has_flag(entry[0]):
			parts.append(entry[1])
	return ", ".join(parts) if not parts.is_empty() else "keine"


# --- Gegner (#36) --------------------------------------------------------------

## Wartet, bis der Host die Spawnbereiche gefüllt hat (NavMesh gebacken).
func _await_enemies() -> EnemySpawnManager:
	for i in 160:
		var manager := EnemySpawnManager.get_instance(get_tree())
		if manager != null and not manager.get_enemies().is_empty():
			return manager
		await _wait(0.25)
	return EnemySpawnManager.get_instance(get_tree())


func _training_zone() -> Node3D:
	for node in get_tree().get_nodes_in_group(WorldZone.GROUP):
		var zone := node as WorldZone
		if zone != null and zone.data != null and zone.data.id == &"trainingsgelaende":
			return zone
	return null


func _spawn_area(area_name: String) -> EnemySpawnArea:
	for node in get_tree().get_nodes_in_group(EnemySpawnArea.GROUP):
		if node.name == area_name:
			return node as EnemySpawnArea
	return null


## Erster lebender Gegner des Typs (oder null).
func _enemy_of(manager: EnemySpawnManager, enemy_id: StringName) -> Enemy:
	for enemy in manager.get_enemies():
		if enemy.enemy_id == enemy_id and not enemy.is_dead():
			return enemy
	return null


## Eigene Figur an eine Stelle im Testgelände (lokal), Blick nach Osten (+X).
func _place_in_training(world: Node, local: Vector3) -> void:
	var zone := _training_zone()
	var origin := (zone.global_position if zone != null else Vector3.ZERO) + local
	world.teleport_local_player(Transform3D(Basis(Vector3.UP, -PI / 2.0), origin + Vector3.UP * 0.3))


func _run_enemy_tour() -> void:
	var world := await _await_world()
	if world == null or not world.has_method(&"get_hud"):
		push_error("UiScreenshots: Spielwelt nicht gefunden")
		get_tree().quit(1)
		return
	var manager := await _await_enemies()
	if manager == null or manager.get_enemies().is_empty():
		push_error("UiScreenshots: keine Gegner erschienen")
		get_tree().quit(1)
		return
	var player: PlayerCharacter = world.get_local_player()
	var targeting := player.get_targeting()
	var zone := _training_zone()
	# Grauschnauze für das Bild sicher dabei (wie „am Mauszeiger“ im Panel).
	if _enemy_of(manager, &"grauschnauze") == null:
		manager.spawn_free(&"grauschnauze", 6, Transform3D(Basis(Vector3.UP, PI / 2.0),
				zone.global_position + Vector3(44, 0, -13)))
	_place_in_training(world, Vector3(37, 0, 0))
	# Namensplaketten der Gegner zeigen (nur für die Bilder, nicht gespeichert).
	for node in world.get_hud().find_children("*", "NameplateLayer", true, false):
		(node as NameplateLayer).show_enemies = true
	var cameras := player.find_children("*", "PlayerCamera", true, false)
	var camera := cameras[0] as PlayerCamera if not cameras.is_empty() else null
	if camera != null:
		camera.zoom(1.0)
		camera.add_pitch(deg_to_rad(-8.0))
	await _wait(2.5)
	var lines: PackedStringArray = []
	for enemy in manager.get_enemies():
		lines.append("%s (%s, Stufe %d, %s)" % [enemy.get_unit_name(), enemy.enemy_id, enemy.level,
				enemy.get_rank_id()])
	print("UiScreenshots: Gegner: %s" % ", ".join(lines))
	await _shot("gegner_trainingsgelaende")
	for entry: Array in [[&"grizzly_alt", "gegner_zielrahmen_elite"], [&"grauschnauze", "gegner_zielrahmen_selten"],
			[&"banditenhauptmann", "gegner_zielrahmen_boss"], [&"banditenhexer", "gegner_zielrahmen_normal"]]:
		var enemy := _enemy_of(manager, entry[0])
		if enemy == null:
			continue
		targeting.select(enemy)
		await _wait(0.6)
		await _shot(entry[1])
	# Tod: Bandit durch die eigene Figur (Erfahrung), Leiche kippt.
	var bandit := _enemy_of(manager, &"bandit")
	if bandit != null:
		targeting.select(bandit)
		await _wait(0.3)
		Combat.deal_damage(player, bandit, bandit.get_stats().health + 1.0, &"physisch")
		await _wait(0.8)
		await _shot("gegner_leiche")
	targeting.clear()
	# Spawnbereiche mit Respawnzeiten und Entwickler-Panel (ohne Plaketten,
	# damit die Beschriftungen lesbar sind).
	for node in world.get_hud().find_children("*", "NameplateLayer", true, false):
		(node as NameplateLayer).show_enemies = false
	manager.set_debug_visible(true)
	await _wait(1.0)
	await _shot("gegner_spawnbereiche")
	var panel := DevPanel.find_in(get_tree())
	if panel != null:
		panel.get_node(^"%Panel").visible = true
		await _wait(0.3)
		var scroll := panel.get_node(^"%Panel/Rows/Scroll") as ScrollContainer
		for child in panel.find_children("*", "Label", true, false):
			var label := child as Label
			if label.text == "Gegner" and label.theme_type_variation == &"Subtitle":
				scroll.scroll_vertical = int(label.position.y)
				break
		await _wait(0.6)
		await _shot("gegner_entwickler_panel")
	get_tree().quit()


## Stand der Gegner im Log (beide Instanzen gleich formatiert).
func _log_enemy_state(label: String) -> void:
	var manager := EnemySpawnManager.get_instance(get_tree())
	if manager == null:
		return
	var alive: PackedStringArray = []
	var dead: PackedStringArray = []
	for enemy in manager.get_enemies():
		var text := "%s/%s/St%d" % [enemy.name, enemy.enemy_id, enemy.level]
		if enemy.is_dead():
			dead.append(text)
		else:
			alive.append(text)
	alive.sort()
	dead.sort()
	print("Probe: %s – %d lebend, Leichen %s" % [label, alive.size(), dead])
	print("Probe: %s – lebend %s" % [label, alive])


## Host der Zwei-Instanzen-Probe: wartet auf den Client, schaltet schnellen
## Respawn ein, tötet einen Jungen Wolf und einen Banditen und gibt alle zwei
## Sekunden den Stand des Wolf-Platzes aus.
func _run_enemy_probe_host() -> void:
	var world := await _await_world()
	var manager := await _await_enemies()
	if world == null or manager == null:
		push_error("UiScreenshots: Spielwelt oder Gegner fehlen")
		get_tree().quit(1)
		return
	for i in 240:
		if world.get_all_players().size() >= 2:
			break
		await _wait(0.5)
	print("Probe: Client ist da")
	await _wait(3.0)
	manager.request_dev("fast", true)
	var wolves := _spawn_area("Woelfe")
	var slot: EnemySpawnManager.Slot = null
	for s in manager.get_slots():
		if s.area == wolves and s.get_enemy() != null and s.get_enemy().enemy_id == &"wolf_jung":
			slot = s
			break
	var wolf := slot.get_enemy()
	print("Probe: Host tötet %s (%s)" % [wolf.name, wolf.get_unit_name()])
	Combat.deal_damage(world.get_local_player(), wolf, wolf.get_stats().health + 1.0, &"physisch")
	var bandit := _enemy_of(manager, &"bandit")
	if bandit != null:
		print("Probe: Host tötet %s (Bandit)" % bandit.name)
		Combat.deal_damage(null, bandit, bandit.get_stats().health + 1.0, &"physisch")
	_log_enemy_state("Host nach dem Töten")
	manager.set_debug_visible(true)
	var start := Time.get_ticks_msec() / 1000.0
	var shot_taken := false
	while Time.get_ticks_msec() / 1000.0 - start < PROBE_DURATION:
		await _wait(2.0)
		var t := Time.get_ticks_msec() / 1000.0 - start
		var enemy := slot.get_enemy()
		print("Probe: Host t=%d s – Wolf-Platz: %s, verschoben ×%d, Leiche %s noch da: %s" % [t,
				("%s lebt" % enemy.name) if enemy != null else "leer", slot.delays, wolf.name if is_instance_valid(wolf) else "?",
				"ja" if is_instance_valid(wolf) and not wolf.is_queued_for_deletion() else "nein"])
		if not shot_taken and slot.delays >= 2:
			# Mehr als 15 m vom Bereich entfernt, damit nur der Client verschiebt.
			_place_in_training(world, Vector3(30, 0, -17))
			await _wait(1.0)
			await _shot("gegner_probe_host_verschoben")
			shot_taken = true
	_log_enemy_state("Host Ende")
	get_tree().quit()


## Client der Zwei-Instanzen-Probe: steht bei den Wölfen (verschiebt den
## Respawn), geht dann 40 m weg und gibt alle zwei Sekunden aus, was er sieht.
func _run_enemy_probe_client() -> void:
	var world := await _await_world()
	if world == null:
		push_error("UiScreenshots: Spielwelt nicht gefunden")
		get_tree().quit(1)
		return
	var wolves := _spawn_area("Woelfe")
	var zone := _training_zone()
	_place_in_training(world, wolves.position if wolves != null else Vector3(56, 0, -17))
	await _wait(2.0)
	_log_enemy_state("Client Start")
	var start := Time.get_ticks_msec() / 1000.0
	var moved := false
	var corpse_shot := false
	while Time.get_ticks_msec() / 1000.0 - start < PROBE_DURATION:
		await _wait(2.0)
		var t := Time.get_ticks_msec() / 1000.0 - start
		if not moved and t >= PROBE_STAY_NEAR:
			_place_in_training(world, Vector3(10, 0, 20))
			moved = true
			print("Probe: Client geht weg (t=%d s)" % t)
		_log_enemy_state("Client t=%d s" % t)
		var manager := EnemySpawnManager.get_instance(get_tree())
		if not corpse_shot and manager != null:
			for enemy in manager.get_enemies():
				if enemy.is_dead():
					await _shot("gegner_probe_client_leiche")
					corpse_shot = true
					break
	print("Probe: Client Zone %s" % (zone.name if zone != null else "?"))
	get_tree().quit()
