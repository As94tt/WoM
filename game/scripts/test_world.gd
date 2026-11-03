extends Node3D
## Leere Testszene (Ticket #6): Boden, Licht, feste Kamera und eine Anzeige
## des gewählten Charakters aus GameSession. Rein lokal. In M1 startet hier
## je nach GameSession.mode der Host (create_server) oder der Client
## (create_client), und die Spielfiguren werden gespawnt.

const CHARACTER_SELECT_SCENE := "res://scenes/ui/character_select.tscn"


func _ready() -> void:
	%BackButton.pressed.connect(_on_back_pressed)
	var c := GameSession.selected_character
	if c == null:
		%NameLabel.text = "Kein Charakter gewählt"
		%InfoLabel.text = ""
		return
	var race := c.get_race()
	var class_data := c.get_class_data()
	%NameLabel.text = c.character_name
	%InfoLabel.text = "Stufe %d · %s · %s" % [
		c.level,
		race.display_name if race != null else String(c.race_id),
		class_data.display_name if class_data != null else String(c.class_id),
	]


func _on_back_pressed() -> void:
	GameSession.selected_character = null
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
