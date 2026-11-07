class_name Hud
extends Control
## Interface-Grundgerüst im Spiel (Ticket #17): zwei Aktionsleisten, Menüleiste,
## Taschenleiste, die Hauptfenster (vorerst leer) und das Spielmenü.
##
## Jeder Spieler hat sein eigenes HUD; nichts davon wird synchronisiert.
##
## Fensterverwaltung: Fenster (HudWindow) werden nur über open_window(),
## close_window() und toggle_window() geöffnet und geschlossen. Die Anordnung
## übernehmen Container in hud.tscn:
## - links nebeneinander in fester Reihenfolge Charakter, dann Zauberbuch
##   (ein allein offenes Zauberbuch rückt an den linken Rand),
## - Talente mittig im Platz rechts davon,
## - Karte mittig, ca. 70 % des Bildschirms, exklusiv (siehe HudWindow.exclusive),
## - Taschen unten rechts über Menü- und Taschenleiste.
## Inhalte setzen spätere Tickets über get_hud_window(id).set_content() ein
## (z. B. die Karte aus #15).
##
## Gebietsnamen-Einblendung (#15): show_zone_banner() zeigt den Namen eines
## neu betretenen Gebiets oben in der Mitte (ZoneBanner).
##
## Eingabe: Tastenkürzel laufen über _unhandled_input, damit ein Textfeld mit
## Fokus (später der Chat) sie zuerst bekommt; zusätzlich sind sie gesperrt,
## solange ein Textfeld den Fokus hat oder hotkeys_enabled false ist. Solange
## die Kamera mit gedrückter Maustaste gedreht wird (Zeiger gefangen),
## reagiert das HUD nicht auf die Maus.

## Wird ausgelöst, wenn ein Fenster geöffnet (true) oder geschlossen wird.
signal window_toggled(window_id: StringName, is_open: bool)

## Menüleisten-Buttons (Knotenname in hud.tscn) und das Fenster, das sie umschalten.
const MICRO_MENU_WINDOWS := {
	&"CharacterButton": &"character",
	&"SpellbookButton": &"spellbook",
	&"TalentsButton": &"talents",
	&"MapButton": &"map",
}
const GAME_MENU_ACTION := &"game_menu"

## Tastenkürzel des HUD an- oder abschalten (z. B. später für den Chat).
var hotkeys_enabled := true

var _windows: Dictionary[StringName, HudWindow] = {}

@onready var _game_menu: GameMenu = %GameMenu
@onready var _action_bar_1: ActionBar = %ActionBar1


func _ready() -> void:
	for window: HudWindow in [%CharacterWindow, %SpellbookWindow, %TalentWindow,
			%MapWindow, %BagWindow]:
		_windows[window.window_id] = window
		window.visible = false
		window.close_requested.connect(close_window.bind(window.window_id))
	for button_name: StringName in MICRO_MENU_WINDOWS:
		var window := _windows[MICRO_MENU_WINDOWS[button_name]]
		var button: Button = %MicroMenu.get_node(NodePath(button_name))
		button.tooltip_text = _tooltip(window.title, window.toggle_action)
		button.pressed.connect(toggle_window.bind(window.window_id))
	%GameMenuButton.tooltip_text = _tooltip("Spielmenü", GAME_MENU_ACTION)
	%GameMenuButton.pressed.connect(handle_cancel)
	var bags := _windows[&"bags"]
	%BackpackButton.tooltip_text = _tooltip("Rucksack", bags.toggle_action)
	%BackpackButton.pressed.connect(toggle_window.bind(&"bags"))
	_update_layout()


func _process(_delta: float) -> void:
	# Kamera drehen (Zeiger gefangen): Interface ignoriert die Maus, damit z. B.
	# die zweite Maustaste nicht von einem Fenster abgefangen wird.
	var dragging := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var behavior := MOUSE_BEHAVIOR_DISABLED if dragging else MOUSE_BEHAVIOR_INHERITED
	if mouse_behavior_recursive != behavior:
		mouse_behavior_recursive = behavior


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	if event.is_action_pressed(GAME_MENU_ACTION):
		var focus := get_viewport().gui_get_focus_owner()
		if _is_text_field(focus):
			focus.release_focus()
		else:
			handle_cancel()
		get_viewport().set_input_as_handled()
		return
	if not _hotkeys_active():
		return
	var handled := _action_bar_1.handle_key_event(event)
	if not handled:
		for window: HudWindow in _windows.values():
			if window.toggle_action != &"" and event.is_action_pressed(window.toggle_action):
				toggle_window(window.window_id)
				handled = true
				break
	if handled:
		get_viewport().set_input_as_handled()


## Esc und Menüleisten-Button „Spielmenü“. Die Reihenfolge steht bewusst nur
## hier, damit spätere Tickets einen Schritt einfügen können (#31: nach dem
## Schließen der Fenster zuerst das Ziel aufheben):
## 1. offenes Spielmenü schließen, 2. offene Fenster schließen,
## 3. Spielmenü öffnen.
func handle_cancel() -> void:
	if _game_menu.visible:
		_game_menu.close()
		return
	if close_all_windows():
		return
	_game_menu.open()


## Blendet den Namen eines neu betretenen Gebiets kurz groß ein, darunter
## klein subtitle (z. B. „Stufe 4–6“; leer = keine zweite Zeile).
func show_zone_banner(title: String, subtitle: String) -> void:
	%ZoneBanner.show_zone(title, subtitle)


func get_hud_window(window_id: StringName) -> HudWindow:
	return _windows.get(window_id)


func is_window_open(window_id: StringName) -> bool:
	var window := get_hud_window(window_id)
	return window != null and window.visible


func toggle_window(window_id: StringName) -> void:
	if is_window_open(window_id):
		close_window(window_id)
	else:
		open_window(window_id)


func open_window(window_id: StringName) -> void:
	var window := get_hud_window(window_id)
	if window == null or window.visible:
		return
	# Exklusive Fenster (Karte) teilen sich den Bildschirm mit keinem anderen.
	for other: HudWindow in _windows.values():
		if other.visible and (window.exclusive or other.exclusive):
			_set_window_open(other, false)
	_set_window_open(window, true)
	_update_layout()


func close_window(window_id: StringName) -> void:
	var window := get_hud_window(window_id)
	if window == null or not window.visible:
		return
	_set_window_open(window, false)
	_update_layout()


## Schließt alle Fenster. Gibt true zurück, wenn mindestens eins offen war.
func close_all_windows() -> bool:
	var any_open := false
	for window: HudWindow in _windows.values():
		if window.visible:
			_set_window_open(window, false)
			any_open = true
	_update_layout()
	return any_open


func _set_window_open(window: HudWindow, is_open: bool) -> void:
	window.visible = is_open
	window_toggled.emit(window.window_id, is_open)


func _update_layout() -> void:
	# Leere linke Spalte ausblenden, damit die Mitte wirklich mittig ist.
	var left: Control = %LeftWindows
	left.visible = left.get_children().any(func(c: Node) -> bool: return c.visible)


func _hotkeys_active() -> bool:
	if not hotkeys_enabled or _game_menu.visible:
		return false
	return not _is_text_field(get_viewport().gui_get_focus_owner())


static func _is_text_field(control: Control) -> bool:
	return control is LineEdit or control is TextEdit


static func _tooltip(title: String, action: StringName) -> String:
	var key := InputLabels.for_action(action)
	return "%s (%s)" % [title, key] if key != "" else title
