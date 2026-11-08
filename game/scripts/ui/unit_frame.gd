class_name UnitFrame
extends PanelContainer
## Spieler- bzw. Zielrahmen im HUD (Ticket #31). Zeigt eine Einheit:
## Platzhalter-Porträt (Anfangsbuchstabe), Name, Stufe, Lebensbalken,
## Ressourcenbalken in Ressourcenfarbe und Kennzeichen.
##
## - Spielerrahmen (mode PLAYER, oben links): Leben als „1.250 / 2.000“,
##   Hauptressource, darunter klein eine Zweitressource (Chi beim Mönch; Mana
##   beim Druiden, sobald seine Gestalten eine andere Hauptressource haben),
##   „Im Kampf“. Platz für Last (Eisenmönch) ist angelegt, aber leer.
##   Klick auf den Rahmen wählt sich selbst (wie F1).
## - Zielrahmen (mode TARGET, rechts daneben, nur mit Ziel sichtbar): Name in
##   der Farbe der Gesinnung, Stufe in der Farbe des Stufenunterschieds, Leben
##   in Prozent, Ressource, Rang („Elite“, „Selten“, „Boss“). Plätze für
##   Auren (#32), Zauberleiste (#33) und Combopunkte sind angelegt, aber leer.
##
## Alles aktualisiert sich sofort über die Signale der Einheit
## (unit_changed) und ihrer Werte (resources_changed, stats_changed,
## combat_changed). Leben und Ressourcen kommen vom Host (StatsSync). Rein
## lokal, nichts wird synchronisiert.

## Linksklick auf den Rahmen.
signal clicked(unit: Unit)

enum Mode { PLAYER, TARGET }

const RANK_TEXTS := {
	Unit.Rank.ELITE: "Elite",
	Unit.Rank.RARE: "Selten",
	Unit.Rank.BOSS: "Boss",
}

@export var mode: Mode = Mode.PLAYER

var _unit: Unit = null
var _stats: CharacterStats = null
## Aus dessen Sicht Gesinnung und Stufenunterschied gelten (eigene Figur).
var _viewer: Unit = null


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	visible = mode == Mode.PLAYER and _unit != null


func get_unit() -> Unit:
	return _unit


func set_viewer(viewer: Unit) -> void:
	_viewer = viewer
	refresh()


## Zeigt unit (null = Rahmen ausblenden).
func set_unit(unit: Unit) -> void:
	if unit == _unit:
		return
	_disconnect()
	_unit = unit if unit != null and is_instance_valid(unit) else null
	_stats = _unit.get_stats() if _unit != null else null
	if _unit != null:
		_unit.unit_changed.connect(refresh)
		_unit.tree_exiting.connect(_on_unit_exiting)
		if _viewer != null and _viewer != _unit:
			_viewer.unit_changed.connect(refresh)
	if _stats != null:
		_stats.resources_changed.connect(_refresh_bars)
		_stats.stats_changed.connect(refresh)
		_stats.combat_changed.connect(_on_combat_changed)
	visible = _unit != null
	refresh()


## Alles neu anzeigen.
func refresh() -> void:
	if _unit == null or not is_node_ready():
		return
	var unit_name := _unit.get_unit_name()
	%NameLabel.text = unit_name
	%PortraitLabel.text = unit_name.substr(0, 1).to_upper() if unit_name != "" else "?"
	%LevelLabel.text = str(_unit.get_level())
	var reaction := _unit.get_reaction_to(_viewer)
	if mode == Mode.TARGET:
		%NameLabel.add_theme_color_override("font_color", UnitColors.reaction_color(reaction))
		var difficulty := UnitColors.difficulty(_unit.get_level(), _viewer.get_level() if _viewer != null else 1)
		%LevelLabel.add_theme_color_override("font_color", UnitColors.difficulty_color(difficulty))
		tooltip_text = "%s · Stufe %d (%s) · %s" % [unit_name, _unit.get_level(),
				UnitColors.DIFFICULTY_NAMES[difficulty], UnitColors.REACTION_NAMES[reaction]]
	else:
		tooltip_text = "%s · Stufe %d" % [unit_name, _unit.get_level()]
	var rank_text: String = RANK_TEXTS.get(_unit.get_rank(), "")
	%RankBadge.visible = rank_text != ""
	%RankLabel.text = rank_text
	_on_combat_changed(_stats != null and _stats.is_in_combat())
	_refresh_bars()


func _refresh_bars() -> void:
	if _unit == null or _stats == null or not is_node_ready():
		return
	var health_bar: ProgressBar = %HealthBar
	health_bar.max_value = maxf(1.0, _stats.max_health)
	health_bar.value = _stats.health
	if mode == Mode.PLAYER:
		%HealthText.text = "%s / %s" % [StatFormat.grouped(_stats.health), StatFormat.grouped(_stats.max_health)]
	else:
		var percent := 100.0 * _stats.health / _stats.max_health if _stats.max_health > 0.0 else 0.0
		%HealthText.text = "%d %%" % ceili(percent) if percent < 100.0 else "100 %"
	var resources := _stats.get_resource_ids()
	var main: StringName = resources[0] if not resources.is_empty() else &""
	_show_resource(%ResourceBar, %ResourceText, main)
	# Zweitressource klein darunter: weitere Leiste der Klasse (Chi beim
	# Mönch) bzw. Mana, falls die Hauptressource nicht Mana ist (Druide in
	# Gestalt, sobald es Gestalten gibt).
	var secondary: StringName = &""
	if mode == Mode.PLAYER:
		if resources.size() > 1:
			secondary = resources[1]
		elif main != &"mana" and _stats.max_mana > 0.0:
			secondary = &"mana"
	_show_resource(%SecondaryBar, null, secondary)


func _show_resource(bar: ProgressBar, text: Label, resource_id: StringName) -> void:
	var maximum := _stats.get_resource_max(resource_id) if resource_id != &"" else 0.0
	bar.visible = maximum > 0.0
	if not bar.visible:
		return
	var current := _stats.get_resource(resource_id)
	var variation := StringName(String(resource_id).capitalize() + "Bar")
	if bar.theme_type_variation != variation:
		bar.theme_type_variation = variation
	bar.max_value = maximum
	bar.value = current
	var resource_name := CharacterStats.RULES.get_resource_name(resource_id)
	var amount := "%s / %s" % [StatFormat.grouped(current), StatFormat.grouped(maximum)]
	bar.tooltip_text = "%s: %s" % [resource_name, amount]
	if text != null:
		text.text = amount


func _on_combat_changed(in_combat: bool) -> void:
	%CombatBadge.visible = mode == Mode.PLAYER and in_combat


func _on_gui_input(event: InputEvent) -> void:
	if _unit != null and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(_unit)
		accept_event()


func _on_unit_exiting() -> void:
	set_unit(null)


func _disconnect() -> void:
	if _unit != null and is_instance_valid(_unit):
		if _unit.unit_changed.is_connected(refresh):
			_unit.unit_changed.disconnect(refresh)
		if _unit.tree_exiting.is_connected(_on_unit_exiting):
			_unit.tree_exiting.disconnect(_on_unit_exiting)
	if _viewer != null and is_instance_valid(_viewer) and _viewer.unit_changed.is_connected(refresh):
		_viewer.unit_changed.disconnect(refresh)
	if _stats != null and is_instance_valid(_stats):
		_stats.resources_changed.disconnect(_refresh_bars)
		_stats.stats_changed.disconnect(refresh)
		_stats.combat_changed.disconnect(_on_combat_changed)
