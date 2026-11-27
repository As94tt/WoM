class_name ExperienceBar
extends ProgressBar
## Erfahrungsbalken (Ticket #27) über den Aktionsleisten, so breit wie die
## Leisten. Füllstand = Erfahrung innerhalb der Stufe; aktuelle und benötigte
## Erfahrung stehen im Tooltip („1.250 / 4.000 (31 %)“). Auf der Höchststufe
## ausgeblendet. Rein lokal; die Werte kommen vom Host (PlayerExperience über
## ServerSync).

var _experience: PlayerExperience = null


func _ready() -> void:
	show_percentage = false
	visible = false


## Mit der Erfahrung der eigenen Figur verbinden.
func setup(experience: PlayerExperience) -> void:
	if _experience != null and _experience.experience_changed.is_connected(refresh):
		_experience.experience_changed.disconnect(refresh)
	_experience = experience
	if _experience != null:
		_experience.experience_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _experience == null or not is_instance_valid(_experience):
		visible = false
		return
	var needed := _experience.get_needed()
	visible = needed > 0
	if not visible:
		return
	max_value = needed
	value = _experience.experience
	tooltip_text = "Erfahrung (Stufe %d): %s" % [_experience.get_level(), _experience.get_progress_text()]
