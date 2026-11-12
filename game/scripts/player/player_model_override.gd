class_name PlayerModelOverride
extends RefCounted
## Lokale Modellwahl für Tests (Ticket #59): Startparameter
##   --spielfigur <Pfad>   alle Spielfiguren dieser Instanz tragen das Modell
##                         aus <Pfad> (CharacterModelData-.tres, z. B.
##                         res://lokal/troll/troll.tres)
##   --spielfigur kapsel   erzwingt die Graubox-Kapsel
## Wie bei QuickStart dürfen die Parameter vor oder nach „--“ stehen (im
## Editor unter Debug → Ausführungsinstanzen anpassen → Startargumente).
##
## Die Wahl gilt nur für die eigene Instanz und wird nicht übertragen. Ohne
## Parameter bestimmt das Volk das Modell (CharacterModelData.for_race).
## Fehlt die Datei (z. B. auf einem anderen PC), bleibt mit einer Warnung die
## Kapsel.

const ARG := "--spielfigur"
const CAPSULE := "kapsel"

static var _parsed := false
static var _active := false
static var _model: CharacterModelData = null


## true, wenn ein Startparameter die Modellwahl vorgibt.
static func is_active() -> bool:
	_ensure_parsed()
	return _active


## Vorgegebenes Modell oder null (= Kapsel), nur gültig, wenn is_active().
static func get_model() -> CharacterModelData:
	_ensure_parsed()
	return _model


## Liest den Pfad aus den Startparametern; leer = kein Parameter.
static func parse(args: PackedStringArray) -> String:
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg.begins_with(ARG + "="):
			return arg.get_slice("=", 1)
		if arg == ARG and i + 1 < args.size() and not args[i + 1].begins_with("--"):
			return args[i + 1]
		i += 1
	return ""


## Lädt das Modell zu einem Pfad. null bei „kapsel“, fehlender oder falscher
## Datei (mit Warnung).
static func load_model(path: String) -> CharacterModelData:
	if path == "" or path.to_lower() == CAPSULE:
		return null
	if not ResourceLoader.exists(path):
		push_warning("Spielfigur: Modell „%s“ nicht gefunden, nehme die Kapsel." % path)
		return null
	var model := load(path) as CharacterModelData
	if model == null:
		push_warning("Spielfigur: „%s“ ist kein CharacterModelData, nehme die Kapsel." % path)
	return model


static func _ensure_parsed() -> void:
	if _parsed:
		return
	_parsed = true
	var args := PackedStringArray()
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	var path := parse(args)
	if path == "":
		return
	_active = true
	_model = load_model(path)
