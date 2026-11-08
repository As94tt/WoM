class_name DevPanel
extends Control
## Entwickler-Panel (Ticket #15), umschaltbar mit F10 (Aktion
## „toggle_dev_panel“). Nur in Debug-Builds (Editor, Debug-Export); in
## Release-Builds entfernt es sich selbst.
##
## Erweiterbar: Andere Systeme fügen eigene Abschnitte hinzu, statt ein
## eigenes Panel zu bauen (z. B. #19):
##     var panel := DevPanel.find_in(get_tree())
##     if panel != null:
##         var section := panel.add_section("Kampf")
##         panel.add_button(section, "Ziel töten", _kill_target)
## Alles im Panel wirkt nur lokal bzw. auf die eigene Figur.

const GROUP := &"dev_panel"
const TOGGLE_ACTION := &"toggle_dev_panel"


## Das Panel der aktuellen Szene oder null (Release-Build, kein Panel).
static func find_in(tree: SceneTree) -> DevPanel:
	return tree.get_first_node_in_group(GROUP) as DevPanel


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	%Panel.visible = false
	%TitleLabel.text = "Entwickler (%s)" % InputLabels.for_action(TOGGLE_ACTION)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo():
		%Panel.visible = not %Panel.visible
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return %Panel.visible


## Neuer Abschnitt mit Überschrift. Gibt den Container für die Einträge zurück.
func add_section(title: String) -> VBoxContainer:
	var heading := Label.new()
	heading.theme_type_variation = &"Subtitle"
	heading.text = title
	%Sections.add_child(heading)
	var box := VBoxContainer.new()
	box.theme_type_variation = &"ButtonList"
	%Sections.add_child(box)
	return box


## Button, der callback ohne Argumente aufruft.
func add_button(section: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	section.add_child(button)
	return button


## Schalter, der callback(bool) beim Umschalten aufruft.
func add_toggle(section: Container, text: String, pressed: bool, callback: Callable) -> CheckBox:
	var toggle := CheckBox.new()
	toggle.text = text
	toggle.button_pressed = pressed
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(callback)
	section.add_child(toggle)
	return toggle


## Textzeile, z. B. für laufend aktualisierte Werte.
func add_info(section: Container, text := "") -> Label:
	var label := Label.new()
	label.theme_type_variation = &"SmallLabel"
	label.text = text
	section.add_child(label)
	return label
