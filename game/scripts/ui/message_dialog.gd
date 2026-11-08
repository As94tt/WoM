class_name MessageDialog
extends Control
## Einfacher Hinweis- oder Bestätigungsdialog (Ticket #30), z. B. „Der Host
## hat die Sitzung beendet“ im Hauptmenü oder die Rückfrage des Hosts beim
## Verlassen. Liegt als Overlay über dem Bildschirm; die Abdunklung fängt
## alle Mausklicks ab. Esc bricht ab (ohne Abbrechen-Button: wie OK).
## Rein lokal.

signal confirmed
signal cancelled


func _ready() -> void:
	hide()
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%CancelButton.pressed.connect(_on_cancel_pressed)


## Öffnet den Dialog. cancel_text leer = nur ein Button (Hinweis).
func open(title: String, message: String, confirm_text := "OK", cancel_text := "") -> void:
	%TitleLabel.text = title
	%MessageLabel.text = message
	%ConfirmButton.text = confirm_text
	%CancelButton.text = cancel_text
	%CancelButton.visible = cancel_text != ""
	show()
	(%CancelButton if cancel_text != "" else %ConfirmButton).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("game_menu")):
		get_viewport().set_input_as_handled()
		if %CancelButton.visible:
			_on_cancel_pressed()
		else:
			_on_confirm_pressed()


func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide()
	cancelled.emit()
