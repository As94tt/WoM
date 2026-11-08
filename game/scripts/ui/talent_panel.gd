class_name TalentPanel
extends VBoxContainer
## Inhalt des Talentfensters (Taste N, Ticket #20), eingesetzt über
## Hud.get_hud_window(&"talents").set_content() (GameWorld).
##
## Oben je Spezialisierung der Klasse ein Reiter (gesperrte ausgegraut, mit
## Name, Kurzbeschreibung und „Noch nicht entdeckt“), darunter Punkte bzw.
## Hinweise, die Seite der Spezialisierung (Beschreibung, bevorzugte Werte,
## Verwandlungen, Baum, optionale Erweiterung der Klasse) und die Buttons.
##
## - Unter Stufe 10: Hinweis „Spezialisierung ab Stufe 10“, Bäume zur Ansicht.
## - Ohne Spezialisierung: Bäume zur Ansicht, Button „Spezialisierung wählen“
##   (mit Bestätigung).
## - Mit Spezialisierung: Klick vergibt einen Punkt, Rechtsklick nimmt ihn
##   zurück – vorläufig, bis „Übernehmen“; „Verwerfen“ macht es rückgängig.
##   „Talente zurücksetzen“ und „Spezialisierung wechseln“ (mit Bestätigung).
##   Alle Änderungen nur außerhalb des Kampfes („Im Kampf nicht möglich“).
##
## Rein lokal: zeigt den Stand der eigenen Figur (PlayerTalents) und schickt
## Wünsche an den Host (request_*), der prüft und den neuen Stand überträgt.
## Bestätigungen laufen über confirm_handler (Hud.ask); ohne ihn (Tests)
## wird sofort ausgeführt.

## Fehlermeldung für oben in der Mitte (GameWorld → Hud.show_error).
signal error(text: String)

## Callable(title, message, confirm_text, cancel_text, on_confirm) für
## Rückfragen; leer = ohne Rückfrage ausführen.
var confirm_handler: Callable

var _player: PlayerCharacter = null
var _talents: PlayerTalents = null
var _specs: Array[SpecializationData] = []
var _tab_index := 0
var _tab_group := ButtonGroup.new()
## Vorläufige Ränge (Talent-ID → Rang) für die gewählte Spezialisierung.
var _pending: Dictionary = {}
var _pending_spec: StringName = &""
## Talent-ID → TalentNodeButton der aktuellen Seite.
var _nodes: Dictionary = {}
var _arrows: TalentArrows = null

@onready var _tab_row: HBoxContainer = %TabRow
@onready var _points_label: Label = %PointsLabel
@onready var _status_label: Label = %StatusLabel
@onready var _page: VBoxContainer = %Page
@onready var _choose_button: Button = %ChooseButton
@onready var _apply_button: Button = %ApplyButton
@onready var _discard_button: Button = %DiscardButton
@onready var _reset_button: Button = %ResetButton
@onready var _switch_button: Button = %SwitchButton


func _ready() -> void:
	_choose_button.pressed.connect(press_choose)
	_apply_button.pressed.connect(press_apply)
	_discard_button.pressed.connect(press_discard)
	_reset_button.pressed.connect(press_reset)
	_switch_button.pressed.connect(press_switch)
	_rebuild()


## Zeigt die Talente der eigenen Figur (GameWorld, sobald sie bereit ist).
func setup(player: PlayerCharacter) -> void:
	if _talents != null and _talents.talents_changed.is_connected(_on_talents_changed):
		_talents.talents_changed.disconnect(_on_talents_changed)
	_player = player
	_talents = player.get_talents() if player != null else null
	if _talents != null:
		_talents.talents_changed.connect(_on_talents_changed)
	var stats := player.get_stats() if player != null else null
	if stats != null and not stats.stats_changed.is_connected(_refresh_state):
		stats.stats_changed.connect(_refresh_state)
	_specs = _talents.get_specializations() if _talents != null else []
	_reset_pending()
	_tab_index = _default_tab()
	_rebuild()


# --- Lesen (auch für Tests) --------------------------------------------------

func get_specs() -> Array[SpecializationData]:
	return _specs


func get_shown_spec() -> SpecializationData:
	return _specs[_tab_index] if _tab_index >= 0 and _tab_index < _specs.size() else null


func get_pending() -> Dictionary:
	return _pending.duplicate()


func has_pending_changes() -> bool:
	return _talents != null and _pending != _talents.get_ranks()


func get_node_button(talent_id: StringName) -> TalentNodeButton:
	return _nodes.get(talent_id)


## Text unter einem Talent („0/3“, „1/3 (+1)“) oder "".
func get_rank_text(talent_id: StringName) -> String:
	var button := get_node_button(talent_id)
	if button == null:
		return ""
	var label := button.get_parent().get_node_or_null(^"Rank") as Label
	return label.text if label != null else ""


func get_points_text() -> String:
	return _points_label.text


func get_status_text() -> String:
	return _status_label.text


func get_tab_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in _tab_row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			result.append(child)
	return result


func get_buttons() -> Dictionary:
	return {"choose": _choose_button, "apply": _apply_button, "discard": _discard_button,
			"reset": _reset_button, "switch": _switch_button}


# --- Bedienung ---------------------------------------------------------------

func show_tab(index: int) -> void:
	if index < 0 or index >= _specs.size():
		return
	_tab_index = index
	_rebuild()


## Linksklick auf ein Talent: einen Punkt vorläufig vergeben.
func click_talent(talent_id: StringName) -> void:
	var reason := _edit_block_reason()
	if reason == "":
		reason = TalentRules.add_reason(_talents.get_tree_data(), _pending, talent_id,
				_talents.get_total_points())
	if reason != "":
		error.emit(reason)
		return
	_pending = TalentRules.with_added(_pending, talent_id)
	_refresh_state()


## Rechtsklick: einen Punkt vorläufig zurücknehmen.
func right_click_talent(talent_id: StringName) -> void:
	var reason := _edit_block_reason()
	if reason == "":
		reason = TalentRules.remove_reason(_talents.get_tree_data(), _pending, talent_id)
	if reason != "":
		error.emit(reason)
		return
	_pending = TalentRules.with_removed(_pending, talent_id)
	_refresh_state()


func press_choose() -> void:
	var spec := get_shown_spec()
	if spec == null or _talents == null:
		return
	var reason := _choose_block_reason(spec)
	if reason != "":
		error.emit(reason)
		return
	_confirm("Spezialisierung wählen",
			"„%s“ wählen? Die Grundfähigkeiten verwandeln sich sofort. Wechseln ist später außerhalb des Kampfes kostenlos möglich." % spec.display_name,
			"Wählen", func() -> void: _talents.request_choose_spec(spec.id))


func press_apply() -> void:
	if _talents == null or not has_pending_changes():
		return
	var reason := _talents.get_change_block_reason()
	if reason != "":
		error.emit(reason)
		return
	_talents.request_apply(_pending)


func press_discard() -> void:
	_reset_pending()
	_refresh_state()


func press_reset() -> void:
	if _talents == null:
		return
	var reason := _talents.get_change_block_reason()
	if reason != "":
		error.emit(reason)
		return
	_confirm("Talente zurücksetzen", "Alle Talente werden zurückgesetzt. Das ist kostenlos.",
			"Zurücksetzen", func() -> void: _talents.request_reset())


func press_switch() -> void:
	if _talents == null:
		return
	var reason := _talents.get_change_block_reason()
	if reason != "":
		error.emit(reason)
		return
	_confirm("Spezialisierung wechseln",
			"Die Spezialisierung wird aufgehoben und alle Talente werden zurückgesetzt. Danach kannst du neu wählen. Das ist kostenlos.",
			"Wechseln", func() -> void: _talents.request_clear_spec())


# --- Aufbau ------------------------------------------------------------------

func _default_tab() -> int:
	if _talents != null and _talents.has_spec():
		var index := _specs.find(_talents.get_spec())
		if index >= 0:
			return index
	return clampi(_tab_index, 0, maxi(0, _specs.size() - 1))


func _reset_pending() -> void:
	_pending = _talents.get_ranks() if _talents != null else {}
	_pending_spec = _talents.get_spec_id() if _talents != null else &""


func _on_talents_changed() -> void:
	var spec_changed := _talents.get_spec_id() != _pending_spec
	var tree := _talents.get_tree_data()
	if spec_changed or tree == null or TalentRules.validate(tree, _pending, _talents.get_total_points()) != "":
		_reset_pending()
	if spec_changed:
		_tab_index = _default_tab()
	_rebuild()


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child in _tab_row.get_children():
		_tab_row.remove_child(child)
		child.queue_free()
	for i in _specs.size():
		var spec := _specs[i]
		var button := Button.new()
		var unlocked := _talents == null or _talents.is_spec_unlocked(spec)
		button.theme_type_variation = &"ChoiceButton" if unlocked else &"LockedChoiceButton"
		button.toggle_mode = true
		button.button_group = _tab_group
		button.focus_mode = Control.FOCUS_NONE
		var chosen := _talents != null and _talents.get_spec() == spec
		button.text = spec.display_name + (" (gewählt)" if chosen else "")
		button.tooltip_text = spec.display_name + "\n" + spec.get_short_description() \
				+ ("" if unlocked else "\nNoch nicht entdeckt")
		button.button_pressed = i == _tab_index
		button.pressed.connect(show_tab.bind(i))
		_tab_row.add_child(button)
	_build_page()
	_refresh_state()


func _build_page() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_nodes.clear()
	_arrows = null
	var spec := get_shown_spec()
	if spec == null:
		_page.add_child(_label("Diese Klasse hat keine Spezialisierungen.", &"HintText", true))
		return
	_page.add_child(_label(spec.display_name, &"Subtitle"))
	if _talents != null and not _talents.is_spec_unlocked(spec):
		_page.add_child(_label(spec.get_short_description(), &"HintText", true))
		_page.add_child(_label("Noch nicht entdeckt", &"BodyText"))
		if spec.unlock_hint != "":
			_page.add_child(_label(spec.unlock_hint, &"SmallHintText", true))
		return
	_page.add_child(_label(spec.description, &"BodyText", true))
	var stats_text := spec.get_preferred_stats_text()
	if stats_text != "":
		_page.add_child(_label("Bevorzugte Werte: " + stats_text, &"SmallLabel", true))
	var transforms: PackedStringArray = []
	for transform in spec.transformations:
		if transform != null and transform.base != null and transform.variant != null:
			transforms.append("%s → %s" % [transform.base.display_name, transform.variant.display_name])
	if transforms.is_empty():
		_page.add_child(_label("Verwandelt keine Grundfähigkeiten.", &"SmallHintText"))
	else:
		_page.add_child(_label("Verwandelt: " + ", ".join(transforms), &"SmallLabel", true))
	if spec.talent_tree != null:
		_page.add_child(_build_tree(spec))
	var chosen := _talents != null and _talents.get_spec() == spec
	if chosen and spec.extension != null and _player != null:
		var extra := spec.extension.make_panel(_player)
		if extra != null:
			_page.add_child(extra)


func _build_tree(spec: SpecializationData) -> Control:
	var stack := MarginContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows_box := VBoxContainer.new()
	rows_box.theme_type_variation = &"ButtonList"
	stack.add_child(rows_box)
	var tree := spec.talent_tree
	for row_index in tree.rows.size():
		var row := tree.rows[row_index]
		if row == null:
			continue
		var line := HBoxContainer.new()
		line.theme_type_variation = &"ButtonRow"
		line.name = "Row%d" % (row_index + 1)
		var head := VBoxContainer.new()
		head.theme_type_variation = &"SlotColumn"
		head.custom_minimum_size.x = 120.0
		head.add_child(_label("Reihe %d · %s" % [row_index + 1, "Wahl" if row.is_choice() else "Ränge"], &"SmallLabel"))
		var lock := _label("", &"SmallHintText")
		lock.name = "Lock"
		head.add_child(lock)
		line.add_child(head)
		for talent_index in row.talents.size():
			var talent := row.talents[talent_index]
			if talent == null:
				continue
			if row.is_choice() and talent_index > 0:
				var word := _label("oder", &"HintText")
				word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				line.add_child(word)
			line.add_child(_build_node(talent))
		rows_box.add_child(line)
	_arrows = TalentArrows.new()
	stack.add_child(_arrows)
	rows_box.sort_children.connect(_update_arrows)
	return stack


func _build_node(talent: TalentData) -> Control:
	var column := VBoxContainer.new()
	column.theme_type_variation = &"SlotColumn"
	column.custom_minimum_size.x = 110.0
	var button := TalentNodeButton.new()
	button.setup(talent, _make_tooltip)
	button.add_requested.connect(click_talent.bind(talent.id))
	button.remove_requested.connect(right_click_talent.bind(talent.id))
	column.add_child(button)
	var name_label := _label(talent.display_name, &"SmallLabel")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 110.0
	column.add_child(name_label)
	var rank := _label("", &"SmallLabel")
	rank.name = "Rank"
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rank)
	_nodes[talent.id] = button
	return column


## Zustand ohne Neuaufbau: Punkte, Hinweise, Ränge, Rahmen, Buttons.
func _refresh_state() -> void:
	if not is_node_ready():
		return
	var spec := get_shown_spec()
	var chosen := _talents != null and spec != null and _talents.get_spec() == spec
	var editable := chosen and _talents.is_spec_active()
	# Punkte und Hinweise.
	var status: PackedStringArray = []
	if _talents == null:
		_points_label.text = ""
	elif not _talents.has_spec_level():
		_points_label.text = "Spezialisierung ab Stufe %d" % TalentRules.spec_level()
		if _talents.has_spec():
			status.append("Deine Spezialisierung ruht, bis du wieder Stufe %d erreichst." % TalentRules.spec_level())
		else:
			status.append("Die Bäume sind bis dahin nur zur Ansicht.")
	else:
		var free := _talents.get_total_points() - TalentRules.spent(_pending)
		_points_label.text = "Verfügbare Punkte: %d" % free
		if not _talents.has_spec():
			status.append("Wähle eine Spezialisierung. Die Bäume sind bis dahin nur zur Ansicht.")
		elif not chosen:
			status.append("Nur zur Ansicht – gewählt ist „%s“." % _talents.get_spec().display_name)
		if _talents.has_spec() and not _talents.are_talents_active():
			status.append("Mehr Punkte ausgegeben als vorhanden: Die Talente ruhen.")
	if _talents != null and _talents.is_in_combat():
		status.append(PlayerTalents.COMBAT_REASON)
	if has_pending_changes():
		var diff := TalentRules.spent(_pending) - _talents.get_spent_points()
		status.append("Vorläufige Änderungen (%+d Punkte): „Übernehmen“ oder „Verwerfen“." % diff)
	_status_label.text = "\n".join(status)
	_status_label.visible = not status.is_empty()
	# Talente.
	if spec != null and spec.talent_tree != null and not _nodes.is_empty():
		var tree := spec.talent_tree
		var ranks := _pending if chosen else {}
		var confirmed := _talents.get_ranks() if chosen else {}
		var total := _talents.get_total_points() if _talents != null else 0
		for row_index in tree.rows.size():
			var row := tree.rows[row_index]
			if row == null:
				continue
			var unlocked := TalentRules.is_row_unlocked(tree, ranks, row_index)
			var lock := _find_row_lock(row_index)
			if lock != null:
				lock.text = "" if unlocked else "Erfordert %d Punkte" % row.required_points
			for talent in row.talents:
				var button := get_node_button(talent.id) if talent != null else null
				if button == null:
					continue
				var rank := TalentRules.rank_of(ranks, talent.id)
				var before := TalentRules.rank_of(confirmed, talent.id)
				button.set_marks(before > 0, rank != before)
				button.disabled = not unlocked or (editable and rank == 0
						and TalentRules.add_reason(tree, ranks, talent.id, total) != "")
				var label := button.get_parent().get_node(^"Rank") as Label
				label.text = "%d/%d" % [rank, row.max_rank_of(talent)]
				if rank != before:
					label.text += " (%+d)" % (rank - before)
				label.theme_type_variation = &"SmallLabel" if unlocked else &"SmallHintText"
		_update_arrows()
	# Buttons.
	var in_combat := _talents != null and _talents.is_in_combat()
	var has_spec := _talents != null and _talents.has_spec()
	_choose_button.visible = not has_spec
	_choose_button.disabled = spec == null or _choose_block_reason(spec) != ""
	_choose_button.tooltip_text = _choose_block_reason(spec) if spec != null else ""
	for button: Button in [_apply_button, _discard_button, _reset_button, _switch_button]:
		button.visible = has_spec
	_apply_button.disabled = not has_pending_changes() or in_combat
	_discard_button.disabled = not has_pending_changes()
	_reset_button.disabled = in_combat or _talents == null or _talents.get_spent_points() == 0
	_switch_button.disabled = in_combat
	var combat_tip := PlayerTalents.COMBAT_REASON if in_combat else ""
	_apply_button.tooltip_text = combat_tip
	_reset_button.tooltip_text = combat_tip
	_switch_button.tooltip_text = combat_tip


func _find_row_lock(row_index: int) -> Label:
	for button: TalentNodeButton in _nodes.values():
		var line := button.get_parent().get_parent()
		if line != null and line.name == "Row%d" % (row_index + 1):
			return line.get_child(0).get_node_or_null(^"Lock") as Label
	return null


func _update_arrows() -> void:
	if _arrows == null or not is_instance_valid(_arrows):
		return
	var spec := get_shown_spec()
	var links: Array = []
	if spec != null and spec.talent_tree != null:
		var chosen := _talents != null and _talents.get_spec() == spec
		var ranks := _pending if chosen else {}
		for talent in spec.talent_tree.get_all_talents():
			if talent.requires == &"":
				continue
			var required := spec.talent_tree.get_talent(talent.requires)
			var from := get_node_button(talent.requires)
			var to := get_node_button(talent.id)
			if required != null and from != null and to != null:
				var met := TalentRules.rank_of(ranks, required.id) \
						>= spec.talent_tree.get_row_of(required.id).max_rank_of(required)
				links.append([from, to, met])
	_arrows.links = links


## Tooltip eines Talents: Name, Art, Rang, Beschreibung, Voraussetzung,
## warum es gerade nicht geht, bei neuen Fähigkeiten deren Tooltip.
func _make_tooltip(talent: TalentData) -> Control:
	var spec := get_shown_spec()
	var tree := spec.talent_tree if spec != null else null
	var row := tree.get_row_of(talent.id) if tree != null else null
	var box := VBoxContainer.new()
	box.theme_type_variation = &"SlotColumn"
	box.add_child(_label(talent.display_name, &"Subtitle"))
	var chosen := _talents != null and spec != null and _talents.get_spec() == spec
	var rank := TalentRules.rank_of(_pending, talent.id) if chosen else 0
	var max_rank := row.max_rank_of(talent) if row != null else talent.max_ranks
	var kind := "Wahl (eins aus der Reihe)" if row != null and row.is_choice() else "Ränge"
	box.add_child(_label("%s · Rang %d/%d" % [kind, rank, max_rank], &"SmallLabel"))
	if talent.description != "":
		box.add_child(_label(talent.description, &"BodyText", true))
	if talent.requires != &"" and tree != null and tree.get_talent(talent.requires) != null:
		box.add_child(_label("Erfordert: %s" % tree.get_talent(talent.requires).display_name, &"SmallLabel"))
	var hint := ""
	if chosen and tree != null:
		hint = _edit_block_reason()
		if hint == "":
			hint = TalentRules.add_reason(tree, _pending, talent.id, _talents.get_total_points())
			if rank > 0:
				var remove := TalentRules.remove_reason(tree, _pending, talent.id)
				hint = "Rechtsklick: Punkt zurücknehmen" if remove == "" else remove
			elif hint == "":
				hint = "Klick: Punkt vergeben"
	elif row != null and tree != null:
		var row_index := tree.row_index_of(talent.id)
		if not TalentRules.is_row_unlocked(tree, {}, row_index):
			hint = "Erfordert %d Punkte in den Reihen darüber." % row.required_points
	if hint != "":
		box.add_child(_label(hint, &"HintText", true))
	var caster: Unit = _player if _player != null and is_instance_valid(_player) else null
	for ability in talent.grants_abilities:
		if ability != null:
			box.add_child(_label("Neue Fähigkeit:", &"SmallLabel"))
			box.add_child(AbilityTooltip.create(ability, true, caster))
	return box


# --- Hilfen ------------------------------------------------------------------

## Warum Talentpunkte gerade nicht geändert werden können (leer = geht).
func _edit_block_reason() -> String:
	var spec := get_shown_spec()
	if _talents == null or spec == null:
		return "Keine Talente."
	if not _talents.has_spec_level():
		return "Spezialisierung ab Stufe %d." % TalentRules.spec_level()
	if not _talents.has_spec():
		return "Erst eine Spezialisierung wählen."
	if _talents.get_spec() != spec:
		return "Nur zur Ansicht – gewählt ist „%s“." % _talents.get_spec().display_name
	return _talents.get_change_block_reason()


func _choose_block_reason(spec: SpecializationData) -> String:
	if _talents == null or spec == null:
		return "Keine Spezialisierung."
	if not _talents.is_spec_unlocked(spec):
		return "Noch nicht entdeckt."
	if not _talents.has_spec_level():
		return "Spezialisierung ab Stufe %d." % TalentRules.spec_level()
	if _talents.has_spec():
		return "Erst die Spezialisierung wechseln."
	return _talents.get_change_block_reason()


func _confirm(title: String, message: String, confirm_text: String, action: Callable) -> void:
	if confirm_handler.is_valid():
		confirm_handler.call(title, message, confirm_text, "Abbrechen", action)
	else:
		action.call()


static func _label(text: String, variation: StringName, wrap := false) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 360.0
	return label
