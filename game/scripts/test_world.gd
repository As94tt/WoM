extends Node3D
## Testszene (Ticket #6, erweitert in #16): Boden, Licht, Graubox-Testgelände
## für die Bewegung (Rampe, steiler Hang, Treppe, Kisten, Wände, Tunnel) und
## eine Anzeige des gewählten Charakters aus GameSession.
## Die eigene Spielfigur erscheint am SpawnPoint unter dem Knoten Players.
## Das Interface (HUD, #17) ist als eigene Szene unter dem Knoten Hud
## eingebunden; „Zurück zur Charakterauswahl“ liegt jetzt im Spielmenü (Esc).
## Rein lokal. In M1 startet hier je nach GameSession.mode der Host
## (create_server) oder der Client (create_client); dann spawnt ein
## MultiplayerSpawner (spawn_path = Players) eine Figur pro Spieler.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_spawn_local_player()
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


## Setzt die Figur des lokalen Spielers an den Startpunkt. Der Knotenname ist
## die Peer-ID, wie später beim MultiplayerSpawner üblich.
func _spawn_local_player() -> void:
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	var peer_id := multiplayer.get_unique_id()
	player.name = str(peer_id)
	player.peer_id = peer_id
	%Players.add_child(player)
	player.global_transform = %SpawnPoint.global_transform
