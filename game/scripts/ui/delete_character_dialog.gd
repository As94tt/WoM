class_name DeleteCharacterDialog
extends Control
## Bestätigung zum Löschen eines Charakters (Ticket #6). „Löschen“ ist erst
## aktiv, wenn der Name genau eingetippt wurde. Liegt als Overlay über dem
## Bildschirm; die Abdunklung fängt alle Mausklicks ab.
## Rein lokal, keine Netzwerkfunktion.

signal confirmed
signal cancelled

var _expected_name := ""


func _ready() -> void:
	hide()
	%NameInput.text_changed.connect(_on_text_changed)
	%NameInput.text_submitted.connect(_on_text_submitted)
	%DeleteButton.pressed.connect(_on_delete_pressed)
	%CancelButton.pressed.connect(_on_cancel_pressed)


## Öffnet den Dialog für den angegebenen Charakternamen.
func open(character_name: String) -> void:
	_expected_name = character_name
	%MessageLabel.text = "Gib zum Bestätigen den Namen „%s“ ein. Der Charakter wird endgültig gelöscht." % character_name
	%NameInput.text = ""
	%DeleteButton.disabled = true
	show()
	%NameInput.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func _matches() -> bool:
	return not _expected_name.is_empty() and %NameInput.text == _expected_name


func _on_text_changed(_text: String) -> void:
	%DeleteButton.disabled = not _matches()


func _on_text_submitted(_text: String) -> void:
	if _matches():
		_on_delete_pressed()


func _on_delete_pressed() -> void:
	if not _matches():
		return
	hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	hide()
	cancelled.emit()
