class_name InputLabels
extends RefCounted
## Kurze Tastenbeschriftung für eine Aktion der Input Map (Ticket #17), z. B.
## „1“, „ß“, „C“ oder „Esc“. Die Beschriftung wird immer aus der Input Map
## gelesen, damit sie nach einer späteren Neubelegung automatisch stimmt.
## Tasten sind als physische Tasten hinterlegt; angezeigt wird, was auf der
## Taste des aktuellen Tastaturlayouts steht (deutsche Tastatur: ß, ´).

## Tottasten meldet das Betriebssystem nicht als Beschriftung; Godot liefert
## dann das Zeichen der US-Tastatur. Für diese Fälle steht hier die richtige
## Beschriftung je Layout-Sprache (physische Taste → Zeichen).
const DEAD_KEY_LABELS := {
	"de": {KEY_EQUAL: "´", KEY_QUOTELEFT: "^"},
}


## Beschriftung der ersten Tastaturtaste einer Aktion ("" = keine Taste).
static func for_action(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return for_key_event(event)
	return ""


static func for_key_event(event: InputEventKey) -> String:
	var keycode := event.keycode
	# Ohne Fenster (headless) gibt es kein Tastaturlayout.
	if event.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
		var language := DisplayServer.keyboard_get_layout_language(
				DisplayServer.keyboard_get_current_layout())
		var dead_keys: Dictionary = DEAD_KEY_LABELS.get(language, {})
		if dead_keys.has(event.physical_keycode):
			return dead_keys[event.physical_keycode]
		var label := DisplayServer.keyboard_get_label_from_physical(event.physical_keycode)
		keycode = label if label != KEY_NONE else event.physical_keycode
	elif event.physical_keycode != KEY_NONE:
		keycode = event.physical_keycode
	if keycode == KEY_ESCAPE:
		return "Esc"
	# Druckbare Zeichen direkt anzeigen (Ziffern, Buchstaben, ß, ´ ...).
	if keycode > KEY_SPACE and keycode < KEY_SPECIAL:
		var text := String.chr(keycode)
		return text.to_upper() if text >= "a" and text <= "z" else text
	return OS.get_keycode_string(keycode)
