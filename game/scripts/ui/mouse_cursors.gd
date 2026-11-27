class_name MouseCursors
extends RefCounted
## Mauszeiger aus dem UI-Paket „Stone & Brass“. Grafiken und Klickspitzen
## (Hotspots) stehen im Theme (Typ „MouseCursor“): je Zeiger <name>_32 und
## <name>_48, Konstanten hotspot_32/hotspot_48 und large_from_height. Zeiger
## werden nicht mit der UI skaliert: unter 1440 Bildschirmzeilen 32 px,
## ab 1440 Zeilen 48 px. Rein lokal.
##
## Vorerst wird nur der Standardzeiger gesetzt; Angreifen, Sprechen, Händler,
## Lehrer, Plündern, Interagieren und „nicht möglich“ liegen bereit und
## kommen mit den Tickets, die diese Ziele einführen (#28, #36, #38).

const THEME_TYPE := &"MouseCursor"

static var _installed := false


## Setzt den Standardzeiger passend zur Fenstergröße und folgt Änderungen.
static func install(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var root := tree.root
	if not _installed:
		_installed = true
		root.size_changed.connect(_apply_standard.bind(root))
	_apply_standard(root)


static func _apply_standard(root: Window) -> void:
	apply(&"standard", Input.CURSOR_ARROW, root)


## Zeiger shape (z. B. &"attack") für die Godot-Form cursor_shape setzen.
static func apply(shape: StringName, cursor_shape: Input.CursorShape, root: Window) -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var large := root.size.y >= theme.get_constant(&"large_from_height", THEME_TYPE)
	var suffix := "_48" if large else "_32"
	var icon_name := StringName(String(shape) + suffix)
	if not theme.has_icon(icon_name, THEME_TYPE):
		return
	var hotspot := float(theme.get_constant(StringName("hotspot" + suffix), THEME_TYPE))
	Input.set_custom_mouse_cursor(theme.get_icon(icon_name, THEME_TYPE), cursor_shape, Vector2(hotspot, hotspot))
