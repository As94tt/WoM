class_name GameSettings
extends RefCounted
## Einstellungen der Spielinstallation (Ticket #21), gespeichert in
## user://settings.cfg. Gelten für alle Charaktere dieser Installation und
## sind rein lokal (jede Spielinstanz hat ihre eigene Datei bzw. liest
## dieselbe Datei, wenn zwei Fenster auf einem PC laufen).
##
## Vorerst nur „Aktionsleisten sperren“ (Spielmenü). Spätere Optionen
## (Optionen-Menü) kommen als weitere Schlüssel dazu.

const PATH := "user://settings.cfg"
const SECTION_INTERFACE := "interface"
const KEY_ACTION_BARS_LOCKED := "action_bars_locked"

static var _config: ConfigFile = null


## Aktionsleisten gesperrt: Fähigkeiten lassen sich nur mit gedrückter
## Umschalttaste (Shift) aus den Slots ziehen. Standard: an.
static func is_action_bars_locked() -> bool:
	return bool(_read(SECTION_INTERFACE, KEY_ACTION_BARS_LOCKED, true))


static func set_action_bars_locked(locked: bool) -> void:
	_write(SECTION_INTERFACE, KEY_ACTION_BARS_LOCKED, locked)


static func _read(section: String, key: String, fallback: Variant) -> Variant:
	_ensure_loaded()
	return _config.get_value(section, key, fallback)


static func _write(section: String, key: String, value: Variant) -> void:
	_ensure_loaded()
	_config.set_value(section, key, value)
	var err := _config.save(PATH)
	if err != OK:
		push_warning("GameSettings: %s konnte nicht gespeichert werden (%s)." % [PATH, error_string(err)])


static func _ensure_loaded() -> void:
	if _config != null:
		return
	_config = ConfigFile.new()
	var err := _config.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("GameSettings: %s konnte nicht gelesen werden (%s)." % [PATH, error_string(err)])
