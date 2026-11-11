class_name TalentNodeButton
extends Button
## Ein Talent im Talentfenster (Ticket #20): SlotButton mit dem Kürzel bzw.
## Icon des Talents. Linksklick vergibt einen Punkt (add_requested),
## Rechtsklick nimmt ihn zurück (remove_requested). Darüber liegen zwei
## Rahmen: „gelernt“ (SlotActive) und „vorläufig geändert“ (TalentPending);
## das zweite Signal steht als Text unter dem Talent („1/3 (+1)“).
## Den Tooltip baut das Talentfenster (tooltip_builder). Rein lokal.

signal add_requested
signal remove_requested

var talent: TalentData = null
## Callable(TalentData) -> Control für den Tooltip.
var tooltip_builder: Callable

var _learned_frame: Panel = null
var _pending_frame: Panel = null


func _init() -> void:
	theme_type_variation = &"SlotButton"
	custom_minimum_size = Vector2(48, 48)
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_learned_frame = _make_frame(&"SlotActive")
	_pending_frame = _make_frame(&"TalentPending")


func setup(p_talent: TalentData, builder: Callable) -> void:
	talent = p_talent
	tooltip_builder = builder
	icon = talent.icon
	text = talent.get_short_name() if talent.icon == null else ""
	tooltip_text = talent.display_name


## Rahmen setzen: learned = bestätigt gelernt, pending = vorläufig geändert.
func set_marks(learned: bool, pending: bool) -> void:
	_learned_frame.visible = learned
	_pending_frame.visible = pending


func is_marked_learned() -> bool:
	return _learned_frame.visible


func is_marked_pending() -> bool:
	return _pending_frame.visible


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_LEFT:
		add_requested.emit()
		accept_event()
	elif mouse.button_index == MOUSE_BUTTON_RIGHT:
		remove_requested.emit()
		accept_event()


func _make_custom_tooltip(_for_text: String) -> Object:
	if talent == null or not tooltip_builder.is_valid():
		return null
	return tooltip_builder.call(talent)


func _make_frame(variation: StringName) -> Panel:
	var frame := Panel.new()
	frame.theme_type_variation = variation
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.visible = false
	add_child(frame)
	return frame
