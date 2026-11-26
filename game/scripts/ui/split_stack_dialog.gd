class_name SplitStackDialog
extends Control
## Kleines Fenster „Stapel teilen“ (Ticket #18, Shift + Klick auf einen
## Stapel im Taschenfenster): Anzahl wählen (1 bis Stapel − 1), dann
## „Teilen“. Aufbau wie MessageDialog (DimOverlay + DialogPanel), aber im Code
## erzeugt; Aussehen nur über Theme-Variationen. Esc bricht ab.

## Bestätigt mit der gewählten Anzahl.
signal confirmed(amount: int)
signal cancelled

const PANEL_WIDTH := 360.0

var _spin: SpinBox = null


## Baut den Dialog und zeigt ihn. count = Größe des Stapels (mindestens 2).
func open(item_name: String, count: int) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := Panel.new()
	dim.theme_type_variation = &"DimOverlay"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.theme_type_variation = &"ButtonList"
	panel.add_child(content)
	var title := Label.new()
	title.theme_type_variation = &"WindowTitle"
	title.text = "Stapel teilen"
	content.add_child(title)
	var message := Label.new()
	message.theme_type_variation = &"BodyText"
	message.text = "Wie viele „%s“ abteilen? (1–%d)" % [item_name, count - 1]
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)
	_spin = SpinBox.new()
	_spin.min_value = 1
	_spin.max_value = maxi(1, count - 1)
	_spin.step = 1
	@warning_ignore("integer_division")
	_spin.value = maxi(1, count / 2)
	_spin.name = "Amount"
	content.add_child(_spin)
	var buttons := HBoxContainer.new()
	buttons.theme_type_variation = &"ButtonRow"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(buttons)
	var cancel := Button.new()
	cancel.name = "CancelButton"
	cancel.text = "Abbrechen"
	cancel.pressed.connect(_on_cancel)
	buttons.add_child(cancel)
	var ok := Button.new()
	ok.name = "ConfirmButton"
	ok.text = "Teilen"
	ok.pressed.connect(_on_confirm)
	buttons.add_child(ok)
	_spin.get_line_edit().text_submitted.connect(func(_text: String) -> void: _on_confirm())
	_spin.get_line_edit().grab_focus.call_deferred()


func get_amount() -> int:
	return int(_spin.value) if _spin != null else 0


func set_amount(amount: int) -> void:
	if _spin != null:
		_spin.value = amount


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu"):
		get_viewport().set_input_as_handled()
		_on_cancel()


func _on_confirm() -> void:
	if _spin != null:
		_spin.apply()
	var amount := get_amount()
	hide()
	confirmed.emit(amount)


func _on_cancel() -> void:
	hide()
	cancelled.emit()
