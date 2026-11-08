class_name TalentDevSection
extends Node
## Abschnitt „Talente“ im Entwickler-Panel (Ticket #20). Wirkt auf die
## eigene Figur; jede Aktion geht als Wunsch an den Host
## (PlayerTalents.request_dev), der nur als Debug-Build zustimmt.
##
## - „Gesperrte Spezialisierungen entsperren“ (gespeichert mit dem Charakter),
## - „Talentpunkte geben (+1)“ / „(+5)“ (Bonuspunkte, gespeichert),
## - „Spezialisierung zurücksetzen“ (auch im Kampf),
## - Infozeilen: Spezialisierung, Punkte, Ränge, aktive Wirkung (Quellen der
##   Veränderungen und Talent-Auren, auf dem Host).

var _world: GameWorld = null
var _info: Label = null


func setup(panel: DevPanel, world: GameWorld) -> void:
	_world = world
	var section := panel.add_section("Talente")
	_info = panel.add_info(section, "Keine Figur")
	panel.add_button(section, "Gesperrte Spezialisierungen entsperren", _dev.bind("unlock", ""))
	panel.add_button(section, "Talentpunkte geben (+1)", _dev.bind("points", 1))
	panel.add_button(section, "Talentpunkte geben (+5)", _dev.bind("points", 5))
	panel.add_button(section, "Spezialisierung zurücksetzen", _dev.bind("reset_spec", null))
	panel.add_info(section, "Stufe ändern: Abschnitt „Werte“ (Spezialisierung ab Stufe %d, Punkte ab Stufe %d)."
			% [TalentRules.spec_level(), TalentRules.first_point_level()])
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_info)
	add_child(timer)


func _dev(action: String, value: Variant) -> void:
	var player := _world.get_local_player() if _world != null else null
	if player != null and player.get_talents() != null:
		player.get_talents().request_dev(action, value)


func _update_info() -> void:
	if _info == null or not _info.is_visible_in_tree():
		return
	var player := _world.get_local_player() if _world != null else null
	if player == null or player.get_talents() == null:
		_info.text = "Keine Figur"
		return
	_info.text = "\n".join(player.get_talents().describe())
