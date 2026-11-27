class_name UiScreenshots
extends Node
## Entwickler-Hilfsmittel (nur Debug-Builds, keine Spielmechanik): macht
## Bildschirmfotos der Oberfläche und beendet das Spiel.
##
##   --ui-screenshots=<Ordner>            Hauptmenü, Dialog, Charakterauswahl
##                                        und -erstellung
##   --host --ui-screenshots=<Ordner>     HUD mit Ziel, Zauber, Auren und die
##                                        Fenster (Taschen, Charakter, …)
## Optional --ui-screenshots-prefix=<Text> vor jedem Dateinamen (z. B. „1080p_“).
## Fenstergröße über Godots --resolution (z. B. --resolution 2560x1440).
## Gestartet vom Hauptmenü (MainMenu._ready); die Szene bleibt bei
## Szenenwechseln erhalten (hängt an der Wurzel).

const ARG_DIR := "--ui-screenshots"
const ARG_PREFIX := "--ui-screenshots-prefix"
const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const CHARACTER_CREATION_SCENE := "res://scenes/ui/character_creation.tscn"

var _dir := ""
var _prefix := ""
var _hud_tour := false


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
	for arg in args:
		if arg.begins_with(ARG_PREFIX + "="):
			prefix = arg.get_slice("=", 1)
		elif arg.begins_with(ARG_DIR + "="):
			dir = arg.get_slice("=", 1)
		elif arg == "--host":
			hud = true
	if dir == "":
		return
	var node := UiScreenshots.new()
	node.name = "UiScreenshots"
	node._dir = dir
	node._prefix = prefix
	node._hud_tour = hud
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(node)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	if _hud_tour:
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
