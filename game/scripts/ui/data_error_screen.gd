class_name DataErrorScreen
extends Control
## Fehlerliste der Datentabellen (Ticket #39). Das Hauptmenü zeigt sie statt
## des Spiels, wenn die Tabellen beim Start Fehler enthalten. Jede Zeile
## nennt Datei, Zeile, Spalte und Grund. „Neu laden“ liest die Tabellen erneut
## (z. B. nach dem Korrigieren in Excel); sind sie fehlerfrei, schließt sich
## die Anzeige und das Hauptmenü ist bedienbar. Rein lokal.

## Die Tabellen sind jetzt fehlerfrei.
signal resolved

## Mehr Zeilen werden nicht angezeigt (der Rest steht in der Konsole).
const MAX_SHOWN := 200


func _ready() -> void:
	hide()
	%ReloadButton.pressed.connect(_on_reload_pressed)
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
	Data.reloaded.connect(_on_reloaded)


## Zeigt die Fehler des letzten Ladeversuchs.
func open() -> void:
	var lines: PackedStringArray = []
	for e in Data.get_errors():
		lines.append(e.to_text())
	_fill(lines)
	show()
	%ReloadButton.grab_focus()


func _on_reload_pressed() -> void:
	Data.reload_tables()


func _on_reloaded(ok: bool, lines: PackedStringArray) -> void:
	if not visible:
		return
	if ok and Data.is_valid():
		hide()
		resolved.emit()
		return
	# Erste Zeile ist die Zusammenfassung, danach die Fehler.
	_fill(lines.slice(1) if lines.size() > 1 else lines)


func _fill(lines: PackedStringArray) -> void:
	for child in %ErrorList.get_children():
		child.queue_free()
	%CountLabel.text = "%d Fehler gefunden. Das Spiel startet erst, wenn die Tabellen fehlerfrei sind: Tabelle korrigieren, speichern und „Neu laden“ drücken." % lines.size()
	for i in mini(lines.size(), MAX_SHOWN):
		var label := Label.new()
		label.theme_type_variation = &"BodyText"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = lines[i]
		%ErrorList.add_child(label)
	if lines.size() > MAX_SHOWN:
		var more := Label.new()
		more.theme_type_variation = &"HintText"
		more.text = "… und %d weitere (siehe Konsole)." % (lines.size() - MAX_SHOWN)
		%ErrorList.add_child(more)
