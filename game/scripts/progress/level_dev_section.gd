class_name LevelDevSection
extends Node
## Abschnitt „Stufe und Erfahrung“ im Entwickler-Panel (Ticket #27). Wirkt auf
## die eigene Figur; jede Aktion geht als Wunsch an den Host
## (PlayerExperience.request_dev), der nur als Debug-Build zustimmt.
##
## - Stufe setzen (Regler, ersetzt „Stufe ändern“ aus #19): echte Stufe des
##   Charakters (wird gespeichert). Höher = dieselben Freischaltungen wie ein
##   echter Aufstieg (Werte, Auffüllen, Fähigkeiten, Spezialisierung,
##   Talentpunkte, Meldung, Effekt). Erst nach kurzem Loslassen gesendet, damit
##   beim Ziehen nicht jede Zwischenstufe einen Aufstieg auslöst.
## - Erfahrung hinzufügen (Betrag per Regler), zur nächsten Stufe aufsteigen,
##   Erfahrung auf 0.
## - „Ziel: Erfahrung wie für einen Kill“: rechnet die Erfahrung für das
##   aktuelle Ziel wie bei einem echten Kill (Stufe, Rang, Stufenunterschied,
##   Gruppe), auch für Übungspuppen. Mit „Stufe des Ziels“ im Abschnitt
##   „Einheiten“ lassen sich graue, grüne, … Gegner und der Totenkopf testen.
## - Infozeile: Stufe, Erfahrung, fehlende Erfahrung, Erfahrung für das Ziel.

## Wartezeit nach der letzten Reglerbewegung, bevor die Stufe gesendet wird.
const LEVEL_DEBOUNCE := 0.4
## Regler „Betrag“: kleinster und größter Wert, Schrittweite, Start.
const AMOUNT_MIN := 10.0
const AMOUNT_MAX := 50000.0
const AMOUNT_STEP := 10.0
const AMOUNT_START := 500.0

var _world: GameWorld = null
var _info: Label = null
var _level_label: Label = null
var _level_slider: HSlider = null
var _level_timer: Timer = null
var _amount_label: Label = null
var _amount := int(AMOUNT_START)


func setup(panel: DevPanel, world: GameWorld) -> void:
	_world = world
	var section := panel.add_section("Stufe und Erfahrung")
	_info = panel.add_info(section, "Keine Figur")
	_level_label = panel.add_info(section, "Stufe setzen: 1")
	_level_slider = panel.add_slider(section, 1.0, LevelRules.max_level(), 1.0, 1.0, _on_level_slider)
	_level_timer = Timer.new()
	_level_timer.one_shot = true
	_level_timer.wait_time = LEVEL_DEBOUNCE
	_level_timer.timeout.connect(func() -> void: _dev("set_level", int(_level_slider.value)))
	add_child(_level_timer)
	_amount_label = panel.add_info(section)
	panel.add_slider(section, AMOUNT_MIN, AMOUNT_MAX, AMOUNT_STEP, AMOUNT_START, func(value: float) -> void:
		_amount = int(value)
		_amount_label.text = "Betrag: %s EP" % StatFormat.grouped(_amount))
	_amount_label.text = "Betrag: %s EP" % StatFormat.grouped(_amount)
	panel.add_button(section, "Erfahrung hinzufügen (Betrag)", func() -> void: _dev("add", _amount))
	panel.add_button(section, "Zur nächsten Stufe aufsteigen", _dev.bind("level_up", null))
	panel.add_button(section, "Erfahrung auf 0 setzen", _dev.bind("reset", null))
	panel.add_button(section, "Ziel: Erfahrung wie für einen Kill", _kill_target)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_info)
	add_child(timer)


func _on_level_slider(value: float) -> void:
	_level_label.text = "Stufe setzen: %d" % int(value)
	_level_timer.start()


func _experience() -> PlayerExperience:
	var player := _world.get_local_player() if _world != null else null
	return player.get_experience() if player != null else null


func _dev(action: String, value: Variant) -> void:
	var experience := _experience()
	if experience != null:
		experience.request_dev(action, value)


func _kill_target() -> void:
	var player := _world.get_local_player() if _world != null else null
	var targeting := player.get_targeting() if player != null else null
	var target := targeting.target if targeting != null else null
	if target == null or target == player:
		_world.show_error("Kein Ziel für den Kill gewählt.")
		return
	_dev("kill", str(target.get_path()))


func _update_info() -> void:
	if _info == null or not _info.is_visible_in_tree():
		return
	var experience := _experience()
	if experience == null:
		_info.text = "Keine Figur"
		return
	var level := experience.get_level()
	if not _level_timer.time_left > 0.0 and int(_level_slider.value) != level:
		_level_slider.set_value_no_signal(level)
		_level_label.text = "Stufe setzen: %d" % level
	var lines: PackedStringArray = ["Stufe %d von %d" % [level, LevelRules.max_level()]]
	if experience.is_max_level():
		lines.append("Höchststufe: keine Erfahrung mehr")
	else:
		lines.append("Erfahrung: %s" % experience.get_progress_text())
		lines.append("Bis zur nächsten Stufe: %s" % StatFormat.grouped(
				LevelRules.missing_to_next(level, experience.experience)))
	var player := _world.get_local_player()
	var target := player.get_targeting().target if player != null and player.get_targeting() != null else null
	if target != null and target != player:
		lines.append("Ziel (Stufe %d, %s): %s EP solo%s" % [target.get_level(), target.get_rank_id(),
				StatFormat.grouped(LevelRules.kill_experience(target.get_level(), target.get_rank_id(), level)),
				"" if target.gives_experience() else ", gibt sonst keine"])
	_info.text = "\n".join(lines)
