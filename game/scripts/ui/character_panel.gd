class_name CharacterPanel
extends HBoxContainer
## Inhalt des Charakterfensters (Taste C, Ticket #19), eingesetzt über
## Hud.get_hud_window(&"character").set_content() (GameWorld).
##
## Links: Name, Stufe, Volk, Klasse (Klasse in Klassenfarbe), Platzhaltermodell
## und die leeren Ausrüstungsplätze (Tooltip = Name des Platzes; Gegenstände
## kommen in M4). Rechts: der ausklappbare Wertebereich (standardmäßig
## eingeklappt). Ausgeklappt wird das Fenster breiter; das Zauberbuch rückt im
## HUD automatisch weiter nach rechts (LeftWindows ist ein HBoxContainer).
##
## Der Wertebereich zeigt nur Werte, die für Klasse und Zustände gelten
## (CharacterStats/StatBlock), in den Abschnitten aus StatRules. Jede Zeile hat
## einen Tooltip mit Erklärung und Aufschlüsselung „Grundwert + Bonus“. Ist ein
## Wert durch Modifikatoren erhöht, steht er in StatBonus, verringert in
## StatMalus (Theme); zweites Signal ist „+“ bzw. „−“ im Tooltip.
##
## Nur Anzeige, rein lokal: Die Werte rechnet CharacterStats (Host-Autorität,
## übertragen per StatsSync). Änderungen erscheinen sofort (Signale
## stats_changed und resources_changed).

## Ausrüstungsplätze (GDD, Abschnitt Ausrüstung) in Anzeigereihenfolge.
const LEFT_SLOTS: PackedStringArray = ["Helm", "Kette", "Schulter", "Umhang", "Brust", "Armschienen"]
const RIGHT_SLOTS: PackedStringArray = ["Handschuhe", "Gürtel", "Beine", "Schuhe", "Ring 1", "Ring 2"]
const WEAPON_SLOTS: PackedStringArray = ["Haupthand", "Nebenhand", "Fernkampf"]
const SPECIAL_SLOTS: PackedStringArray = ["Siegel", "Talisman 1", "Talisman 2", "Talisman 3"]
## Größe eines Ausrüstungsplatzes (wie Menüleiste und Schließen-Button).
const SLOT_SIZE := Vector2(40, 40)
const RULES: StatRules = preload("res://data/stats/stat_rules.tres")

var _player: PlayerCharacter = null
var _stats: CharacterStats = null
## Zeilen der Ressourcen: Wert-ID (max_*) → Label des Werts, für schnelle
## Aktualisierung ohne Neuaufbau.
var _resource_value_labels: Dictionary[StringName, Label] = {}

@onready var _name_label: Label = %NameLabel
@onready var _info_label: Label = %InfoLabel
@onready var _class_label: Label = %ClassLabel
@onready var _preview: CharacterPreview = %Preview
@onready var _stats_toggle: Button = %StatsToggle
@onready var _stats_area: Control = %StatsArea
@onready var _stats_list: VBoxContainer = %StatsList
@onready var _combat_label: Label = %CombatLabel


func _ready() -> void:
	_add_slots(%LeftSlots, LEFT_SLOTS)
	_add_slots(%RightSlots, RIGHT_SLOTS)
	_add_slots(%WeaponSlots, WEAPON_SLOTS)
	_add_slots(%SpecialSlots, SPECIAL_SLOTS)
	_stats_toggle.toggled.connect(_set_stats_visible)
	_set_stats_visible(false)
	_refresh_header()


## Zeigt die Figur des eigenen Spielers (GameWorld, sobald sie bereit ist).
func setup(player: PlayerCharacter) -> void:
	if _stats != null:
		_stats.stats_changed.disconnect(_on_stats_changed)
		_stats.resources_changed.disconnect(_update_resources)
		_stats.combat_changed.disconnect(_on_combat_changed)
	_player = player
	_stats = player.get_stats() if player != null else null
	if _stats != null:
		_stats.stats_changed.connect(_on_stats_changed)
		_stats.resources_changed.connect(_update_resources)
		_stats.combat_changed.connect(_on_combat_changed)
	_on_stats_changed()


func is_stats_visible() -> bool:
	return _stats_area.visible


func _set_stats_visible(on: bool) -> void:
	_stats_area.visible = on
	%StatsSeparator.visible = on
	_stats_toggle.set_pressed_no_signal(on)
	_stats_toggle.text = "«" if on else "»"
	_stats_toggle.tooltip_text = "Werte ausblenden" if on else "Werte anzeigen"


func _add_slots(container: Container, names: PackedStringArray) -> void:
	for slot_name in names:
		var slot := Button.new()
		slot.theme_type_variation = &"SlotButton"
		slot.custom_minimum_size = SLOT_SIZE
		slot.focus_mode = Control.FOCUS_NONE
		slot.tooltip_text = "%s (leer)" % slot_name
		container.add_child(slot)


func _on_stats_changed() -> void:
	_refresh_header()
	_rebuild_stats()


func _on_combat_changed(_in_combat: bool) -> void:
	_refresh_combat_label()


func _refresh_header() -> void:
	if not is_node_ready():
		return
	if _player == null:
		_name_label.text = "–"
		_info_label.text = ""
		_class_label.text = ""
		_preview.clear()
		return
	var race := GameData.get_race(_player.race_id)
	var class_data := _player.get_class_data()
	_name_label.text = _player.display_name
	_info_label.text = "Stufe %d · %s ·" % [_player.get_level(),
			race.display_name if race != null else String(_player.race_id)]
	_class_label.text = class_data.display_name if class_data != null else String(_player.class_id)
	if class_data != null:
		# Klassenfarbe kommt aus den Daten (ClassData.color), siehe UI-Styleguide.
		_class_label.add_theme_color_override("font_color", class_data.color)
	_preview.show_appearance(race, _player.gender as CharacterData.Gender, "", class_data)


func _refresh_combat_label() -> void:
	var in_combat := _stats != null and _stats.is_in_combat()
	_combat_label.text = "Im Kampf" if in_combat else "Außerhalb des Kampfes"


# --- Wertebereich ------------------------------------------------------------

func _rebuild_stats() -> void:
	if not is_node_ready():
		return
	for child in _stats_list.get_children():
		_stats_list.remove_child(child)
		child.queue_free()
	_resource_value_labels.clear()
	_refresh_combat_label()
	if _stats == null:
		return
	var block := _stats.block
	for category: StatDefinition.Category in StatRules.SECTION_TITLES:
		var definitions: Array[StatDefinition] = []
		for definition in RULES.stats:
			if definition.category == category and block.is_relevant(definition.id):
				definitions.append(definition)
		if definitions.is_empty():
			continue
		# Stabil nach display_order sortieren (sort_custom ist nicht stabil).
		var indexed := range(definitions.size())
		indexed.sort_custom(func(a: int, b: int) -> bool:
			var da := definitions[a].display_order
			var db := definitions[b].display_order
			return da < db if da != db else a < b)
		var heading := Label.new()
		heading.theme_type_variation = &"Subtitle"
		heading.text = StatRules.SECTION_TITLES[category]
		_stats_list.add_child(heading)
		for i: int in indexed:
			_add_stat_row(definitions[i])
	_update_resources()


func _add_stat_row(definition: StatDefinition) -> void:
	var row := HBoxContainer.new()
	row.theme_type_variation = &"InlineRow"
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.tooltip_text = _tooltip(definition)
	var name_label := Label.new()
	name_label.theme_type_variation = &"SmallLabel"
	name_label.text = definition.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.theme_type_variation = _variation_for(definition.id)
	value_label.text = StatFormat.value(definition, _stats.get_value(definition.id))
	row.add_child(value_label)
	_stats_list.add_child(row)
	if definition.id == &"max_health" or _resource_of(definition.id) != &"":
		_resource_value_labels[definition.id] = value_label


## Theme-Variation des Werts: StatBonus (erhöht), StatMalus (verringert),
## sonst SmallLabel.
func _variation_for(stat: StringName) -> StringName:
	var bonus := _stats.block.get_bonus(stat)
	if bonus > 0.0001:
		return &"StatBonus"
	if bonus < -0.0001:
		return &"StatMalus"
	return &"SmallLabel"


## Ressource zu einem Maximalwert (&"max_mana" → &"mana"), sonst &"".
func _resource_of(stat: StringName) -> StringName:
	for resource_id in CharacterStats.RESOURCE_IDS:
		if StatRules.max_stat_of(resource_id) == stat:
			return resource_id
	return &""


## Leben und Ressourcen: „aktuell / maximal“, laufend aktualisiert.
func _update_resources() -> void:
	if _stats == null:
		return
	for stat: StringName in _resource_value_labels:
		var label := _resource_value_labels[stat]
		var current := _stats.health
		var maximum := _stats.max_health
		var resource_id := _resource_of(stat)
		if resource_id != &"":
			current = _stats.get_resource(resource_id)
			maximum = _stats.get_resource_max(resource_id)
		var text := "%s / %s" % [StatFormat.number(current, 0), StatFormat.number(maximum, 0)]
		if resource_id == &"chi" and _stats.chi_draining:
			text = "Chi voll, sinkt: " + text
		label.text = text


func _tooltip(definition: StatDefinition) -> String:
	var block := _stats.block
	var stat := definition.id
	var lines: PackedStringArray = [definition.display_name, definition.description]
	var source := definition.source
	if source == StatDefinition.PRIMARY_SOURCE:
		var class_data := GameData.get_class_data(block.class_id)
		source = class_data.primary_attribute if class_data != null else &""
	var source_definition := RULES.get_stat(source) if source != &"" else null
	if source_definition != null:
		lines.append("Grundlage: %s %s" % [source_definition.display_name,
				StatFormat.value(source_definition, block.get_value(source))])
	var base := block.get_base(stat)
	var bonus := block.get_bonus(stat)
	if absf(bonus) > 0.0001:
		lines.append("Grundwert %s %s %s = %s" % [StatFormat.value(definition, base),
				"+" if bonus > 0.0 else StatFormat.MINUS, StatFormat.value(definition, absf(bonus)),
				StatFormat.value(definition, block.get_value(stat))])
		lines.append("%s: %s" % ["Bonus" if bonus > 0.0 else "Malus",
				StatFormat.signed_value(definition, bonus)])
	else:
		lines.append("Grundwert %s, kein Bonus" % StatFormat.value(definition, base))
	for m in block.get_modifiers(stat):
		lines.append("  %s (%s)" % [StatFormat.modifier(definition.display_name, definition, m.kind, m.value),
				m.source_name])
	var cap := block.get_cap(stat)
	if cap < INF:
		lines.append("Obergrenze %s%s" % [StatFormat.value(definition, cap),
				" (erreicht)" if block.is_capped(stat) else ""])
	match stat:
		&"max_health":
			lines.append("Regeneration: %s im Kampf, %s außerhalb des Kampfes" % [
					_percent_per_second(&"leben_regen_im_kampf"), _percent_per_second(&"leben_regen_ausser_kampf")])
		&"mana_regen":
			lines.append("Außerhalb des Kampfes × %s" % StatFormat.number(
					Data.konstante(&"mana_regen_faktor_ausser_kampf", 1.0), 1))
		&"max_rage":
			lines.append("Verfall außerhalb des Kampfes: %s je s" % StatFormat.number(
					Data.konstante(&"wut_verfall_pro_s"), 1))
		&"max_chi":
			lines.append("Nach „Chi voll“ sinkt Chi um %s je s; dabei entsteht kein neues Chi." % StatFormat.number(
					Data.konstante(&"chi_verfall_pro_s"), 1))
	return "\n".join(lines)


func _percent_per_second(key: StringName) -> String:
	return StatFormat.number(Data.konstante(key), 1) + " % je s"
