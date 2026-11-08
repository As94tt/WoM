class_name GameSettings
extends RefCounted
## Einstellungen der Spielinstallation (Ticket #21), gespeichert in
## user://settings.cfg. Gelten für alle Charaktere dieser Installation und
## sind rein lokal (jede Spielinstanz hat ihre eigene Datei bzw. liest
## dieselbe Datei, wenn zwei Fenster auf einem PC laufen).
##
## „Aktionsleisten sperren“ (Spielmenü, #21), die Namensplaketten für
## Feinde (V) und Freunde (Shift + V, #31) und „Kampftext anzeigen“
## (Spielmenü, #34). Spätere Optionen (Optionen-Menü)
## kommen als weitere Schlüssel dazu.

const PATH := "user://settings.cfg"
const SECTION_INTERFACE := "interface"
const KEY_ACTION_BARS_LOCKED := "action_bars_locked"
const KEY_NAMEPLATES_ENEMY := "nameplates_enemy"
const KEY_NAMEPLATES_FRIENDLY := "nameplates_friendly"
const KEY_COMBAT_TEXT := "combat_text"

static var _config: ConfigFile = null


## Aktionsleisten gesperrt: Fähigkeiten lassen sich nur mit gedrückter
## Umschalttaste (Shift) aus den Slots ziehen. Standard: an.
static func is_action_bars_locked() -> bool:
	return bool(_read(SECTION_INTERFACE, KEY_ACTION_BARS_LOCKED, true))


static func set_action_bars_locked(locked: bool) -> void:
	_write(SECTION_INTERFACE, KEY_ACTION_BARS_LOCKED, locked)


## Namensplaketten über feindlichen und neutralen Einheiten. Standard: an.
static func is_enemy_nameplates_shown() -> bool:
	return bool(_read(SECTION_INTERFACE, KEY_NAMEPLATES_ENEMY, true))


static func set_enemy_nameplates_shown(shown: bool) -> void:
	_write(SECTION_INTERFACE, KEY_NAMEPLATES_ENEMY, shown)


## Namensplaketten über freundlichen Einheiten und Mitspielern. Standard: an.
static func is_friendly_nameplates_shown() -> bool:
	return bool(_read(SECTION_INTERFACE, KEY_NAMEPLATES_FRIENDLY, true))


static func set_friendly_nameplates_shown(shown: bool) -> void:
	_write(SECTION_INTERFACE, KEY_NAMEPLATES_FRIENDLY, shown)


## Kampftext (schwebende Zahlen, #34) anzeigen. Der Kampflog läuft immer.
## Standard: an.
static func is_combat_text_shown() -> bool:
	return bool(_read(SECTION_INTERFACE, KEY_COMBAT_TEXT, true))


static func set_combat_text_shown(shown: bool) -> void:
	_write(SECTION_INTERFACE, KEY_COMBAT_TEXT, shown)


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
