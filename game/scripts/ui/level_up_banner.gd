class_name LevelUpBanner
extends VBoxContainer
## Aufstiegsmeldung (Ticket #27) groß in der Bildschirmmitte: „Stufe 12
## erreicht!“, darunter für einige Sekunden die Zusammenfassung
## (LevelUpSummary): gestiegene Werte, neue Fähigkeiten, Talentpunkte,
## Spezialisierung und weitere Freischaltungen. Klick auf eine neue Fähigkeit
## öffnet das Zauberbuch, Klick auf den Talenthinweis das Talentfenster
## (window_requested, verbunden vom HUD). Rein lokal, nur für die eigene Figur.
##
## Sichtbar bleibt sie aufstieg_anzeige_dauer Sekunden (spielkonstanten.csv),
## dann blendet sie aus. Solange die Maus über ihr steht, bleibt sie stehen.

## Ein Fenster soll geöffnet werden (z. B. &"spellbook", &"talents").
signal window_requested(window_id: StringName)

## Dauer des Einblendens und Ausblendens in Sekunden.
@export var fade_in_time: float = 0.3
@export var fade_out_time: float = 1.5

var _tween: Tween = null
var _summary: LevelUpSummary = null


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Zeigt die Meldung zu summary (eine laufende wird ersetzt). auto_hide false
## = bleibt stehen (Style-Vorschau).
func show_summary(summary: LevelUpSummary, auto_hide := true) -> void:
	_summary = summary
	%TitleLabel.text = summary.title()
	var lines: VBoxContainer = %Lines
	for child in lines.get_children():
		lines.remove_child(child)
		child.queue_free()
	if summary.stat_text() != "":
		_add_text(summary.stat_text())
	for ability in summary.abilities:
		_add_link("Neue Fähigkeit: %s" % ability.display_name, &"spellbook",
				"Zauberbuch öffnen")
	if summary.talent_text() != "":
		_add_link(summary.talent_text(), &"talents", "Talente öffnen")
	if summary.spec_unlocked:
		_add_link("Du kannst jetzt eine Spezialisierung wählen.", &"talents", "Talente öffnen")
	for extra in summary.extras:
		var window := StringName(str(extra.get("window", "")))
		if window != &"":
			_add_link(str(extra["text"]), window, "Öffnen")
		else:
			_add_text(str(extra["text"]))
	if _tween != null:
		_tween.kill()
	visible = true
	if not auto_hide:
		modulate.a = 1.0
		return
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 1.0, fade_in_time)
	_tween.tween_interval(maxf(0.5, Data.konstante(&"aufstieg_anzeige_dauer", 6.0)))
	_tween.tween_callback(_fade_out)


## Aktuelle Zusammenfassung (Tests, Style-Vorschau) oder null.
func get_summary() -> LevelUpSummary:
	return _summary


## Texte aller Zeilen (Tests).
func get_line_texts() -> PackedStringArray:
	var result: PackedStringArray = []
	for child in %Lines.get_children():
		if child is Label:
			result.append((child as Label).text)
		elif child is Button:
			result.append((child as Button).text)
	return result


func _fade_out() -> void:
	# Maus über einem Hinweis: noch etwas warten, damit der Klick gelingt.
	if _mouse_over_links():
		_tween = create_tween()
		_tween.tween_interval(1.0)
		_tween.tween_callback(_fade_out)
		return
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 0.0, fade_out_time)
	_tween.tween_callback(hide)


func _mouse_over_links() -> bool:
	var mouse := get_global_mouse_position()
	for child in %Lines.get_children():
		if child is Button and (child as Button).get_global_rect().has_point(mouse):
			return true
	return false


func _add_text(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"LevelUpText"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Lines.add_child(label)


func _add_link(text: String, window_id: StringName, hint: String) -> void:
	var button := Button.new()
	button.theme_type_variation = &"LevelUpLink"
	button.text = text
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: window_requested.emit(window_id))
	%Lines.add_child(button)
