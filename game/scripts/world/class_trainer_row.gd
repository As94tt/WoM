class_name ClassTrainerRow
extends Node3D
## Setzt für jede Klasse aus res://data/classes/ einen Platzhalter-Pfahl
## „NPC: Lehrer <Klasse>“ in eine Reihe entlang +X (Ticket #15). Eine neue
## Klasse bekommt so ohne Code-Änderung ihren Lehrer-Platzhalter. Das
## Lehrer-System ersetzt diese Reihe später.

const POST_SCENE := preload("res://scenes/world/props/placeholder_post.tscn")

## Art der Pfähle (NPC).
@export var kind: PlaceholderKind
## Abstand zwischen den Pfählen in Metern.
@export var spacing: float = 4.0


func _ready() -> void:
	var classes := GameData.get_classes()
	for i in classes.size():
		var post: PlaceholderPost = POST_SCENE.instantiate()
		post.name = "Lehrer_%s" % classes[i].id
		post.kind = kind
		post.text = "Lehrer %s" % classes[i].display_name
		post.position = Vector3(i * spacing, 0.0, 0.0)
		add_child(post)
