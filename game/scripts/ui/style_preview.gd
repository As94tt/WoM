extends Control
## Vorschauszene für das zentrale UI-Theme (Ticket #10, erweitert in #6, #8, #17, #15, #30 und #21).
## Zeigt alle Button-Zustände gleichzeitig. Hover lässt sich nicht statisch
## erzwingen, deshalb bekommen die Hover-Beispiele die Hover-Werte aus dem
## Theme als Normalzustand. Es werden keine eigenen Farben gesetzt, nur Werte
## aus theme.tres übernommen. Rein lokal, keine Netzwerkfunktion.


func _ready() -> void:
	var hover_button: Button = %HoverButton
	hover_button.add_theme_stylebox_override("normal", hover_button.get_theme_stylebox("hover"))
	hover_button.add_theme_color_override("font_color", hover_button.get_theme_color("font_hover_color"))

	# Listeneinträge der Charakterauswahl (#6) mit einem Beispielcharakter.
	# Volk und Klasse kommen aus den Daten, die Klassenfarbe aus ClassData.
	var sample := CharacterData.new()
	sample.character_name = "Durgin"
	sample.level = 12
	var races := GameData.get_races()
	var classes := GameData.get_classes()
	if not races.is_empty():
		sample.race_id = races[0].id
	if not classes.is_empty():
		sample.class_id = classes[0].id
	for entry: CharacterEntry in [%EntryNormal, %EntryHover, %EntrySelected, %EntryDisabled]:
		entry.setup(sample)
	%EntryHover.add_theme_stylebox_override("normal", %EntryHover.get_theme_stylebox("hover"))

	# Auswahlbutton der Charaktererstellung (#8), Hover dauerhaft dargestellt.
	var choice_hover: Button = %ChoiceHover
	choice_hover.add_theme_stylebox_override("normal", choice_hover.get_theme_stylebox("hover"))
	choice_hover.add_theme_color_override("font_color", choice_hover.get_theme_color("font_hover_color"))

	# Interface im Spiel (#17): Aktionsslots mit Hover, Aufleuchten und Taste.
	%SlotHover.add_theme_stylebox_override("normal", %SlotHover.get_theme_stylebox("hover"))
	%SlotFlashing.get_node("%Flash").visible = true
	%SlotKey.input_action = &"action_bar_1_slot_1"

	# Mitspieler auf der Karte (#30): Klassenfarbe aus den Daten.
	if not classes.is_empty():
		%MateMarker.fill_color = classes[0].color

	_add_spellbook_samples()

	%FocusButton.grab_focus()


## Zauberbuch und Aktionsleisten (#21): Einträge (erlernt, passiv, nicht
## erlernt), Slots mit Fähigkeit (normal, ausgegraut) und der Tooltip.
func _add_spellbook_samples() -> void:
	var grid: GridContainer = $ScrollContainer/MarginContainer/Content/HudGrid
	var feuerball := GameData.get_ability(&"feuerball")
	var passive := GameData.get_ability(&"passiv_magier")
	var gegenzauber := GameData.get_ability(&"gegenzauber")
	if feuerball == null or passive == null or gegenzauber == null:
		return
	_add_row(grid, "Zauberbuch-Eintrag: erlernt, passiv, nicht erlernt (HintText, SmallHintText)")
	var entries := VBoxContainer.new()
	entries.theme_type_variation = &"SpellbookGrid"
	entries.custom_minimum_size.x = 218
	grid.add_child(entries)
	for ability in [feuerball, passive, gegenzauber]:
		var entry: SpellbookEntry = preload("res://scenes/ui/hud/spellbook_entry.tscn").instantiate()
		entries.add_child(entry)
		# Ohne Figur (null) gilt learned_without_player.
		entry.setup(ability, null, ability != gegenzauber)

	_add_row(grid, "Aktionsslot mit Fähigkeit: normal, ausgegraut (nicht erlernt)")
	var slots := HBoxContainer.new()
	slots.theme_type_variation = &"SlotRow"
	grid.add_child(slots)
	for learned in [true, false]:
		var slot: ActionSlot = preload("res://scenes/ui/hud/action_slot.tscn").instantiate()
		slots.add_child(slot)
		slot.show_content(ActionSlotContent.ability(feuerball.id), learned)

	_add_row(grid, "Tooltip einer Fähigkeit (Subtitle, SmallLabel, BodyText, HintText)")
	var tooltip := PanelContainer.new()
	tooltip.theme_type_variation = &"TooltipPanel"
	tooltip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tooltip.add_child(AbilityTooltip.create(gegenzauber, false))
	grid.add_child(tooltip)


func _add_row(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"SmallLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 240
	grid.add_child(label)
