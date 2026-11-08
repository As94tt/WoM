class_name PlayerList
extends PanelContainer
## Spielerliste (Ticket #30), sichtbar solange die Taste der Aktion
## „player_list“ (O) gehalten wird. Zeigt alle Spieler der Sitzung mit Name,
## Stufe, Klasse (in Klassenfarbe aus den Daten), Ping und Kennzeichnung des
## Hosts. Die Daten kommen aus dem Autoload „Network“; der Ping wird vom Host
## gemessen und etwa einmal pro Sekunde an alle verteilt.

## Spaltenüberschriften (gehören zum Raster, erste Zeile).
const HEADER_COUNT := 5


func _ready() -> void:
	visible = false
	Network.players_changed.connect(_on_players_changed)


func set_shown(shown: bool) -> void:
	if shown == visible:
		return
	visible = shown
	if shown:
		refresh()


func refresh() -> void:
	var grid: GridContainer = %Grid
	while grid.get_child_count() > HEADER_COUNT:
		var child := grid.get_child(grid.get_child_count() - 1)
		grid.remove_child(child)
		child.queue_free()
	var players := Network.get_players()
	%TitleLabel.text = "Spieler (%d / %d)" % [players.size(), Network.SETTINGS.max_players]
	var local_id := Network.get_local_peer_id()
	for info in players:
		var class_data := info.get_class_data()
		var ping := Network.get_local_ping_ms() if info.peer_id == local_id and not info.is_host() \
				else info.ping_ms
		_add_cell(info.display_name)
		_add_cell(str(info.level))
		var class_label := _add_cell(class_data.display_name if class_data != null else String(info.class_id))
		if class_data != null:
			# Klassenfarbe kommt aus den Daten (ClassData.color), siehe UI-Styleguide.
			class_label.add_theme_color_override("font_color", class_data.color)
		_add_cell("–" if info.is_host() else "%d ms" % ping)
		_add_cell("Host" if info.is_host() else "")


func _add_cell(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"BodyText"
	label.text = text
	%Grid.add_child(label)
	return label


func _on_players_changed() -> void:
	if visible:
		refresh()
