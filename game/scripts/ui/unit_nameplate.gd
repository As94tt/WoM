class_name UnitNameplate
extends VBoxContainer
## Namensplakette über einer Einheit (Ticket #31), gezeichnet im HUD und von
## NameplateLayer über den Kopf der Einheit gesetzt.
##
## - Feindliche und neutrale Einheiten: Name (Farbe der Gesinnung), darunter
##   Stufe (Farbe des Stufenunterschieds) und Lebensbalken.
## - Freundliche Einheiten und Mitspieler: nur der Name (Mitspieler in
##   Klassenfarbe, andere in der Farbe der Gesinnung).
## - Das aktuelle Ziel bekommt einen hervorgehobenen Rahmen
##   (NameplateTargetPanel) und wird etwas größer gezeichnet.
## - Tank-Hinweis (#35): Ist die eigene Figur ein Tank (dreifache Bedrohung),
##   bekommen Gegner, die gerade jemand anderen angreifen, einen roten,
##   breiteren Rand (NameplateWarningPanel bzw. NameplateTargetWarningPanel).
## - Über Feinden: eigene Debuffs als kleine Symbole (#32, AuraBar).
## - Darunter die Zauberleiste der Einheit (#33, CastBar ohne Restzeit).
## - Darunter optional eine Anzeige (Übungspuppen: Schaden pro Sekunde),
##   die auch bei ausgeblendeten Plaketten sichtbar bleibt.
##
## Klick: links wählt die Einheit, rechts wählt sie und greift an.

signal clicked(unit: Unit, right_button: bool)

## Faktor, um den die Plakette des Ziels größer ist.
const TARGET_SCALE := 1.15

var unit: Unit = null


func _ready() -> void:
	%Plate.gui_input.connect(_on_gui_input)


## Inhalt und Hervorhebung setzen. show_plate = Name/Leben zeigen (V bzw.
## Shift + V), sonst nur die Anzeige der Puppe.
func update_from(p_unit: Unit, viewer: Unit, is_target: bool, show_plate: bool) -> void:
	unit = p_unit
	var reaction := unit.get_reaction_to(viewer)
	var hostile := reaction != Unit.Reaction.FRIENDLY
	%Plate.visible = show_plate
	# Tank-Hinweis (#35): roter Rand, wenn der Gegner jemand anderen angreift.
	var warn := hostile and _attacks_someone_else(unit, viewer)
	if warn:
		%Plate.theme_type_variation = &"NameplateTargetWarningPanel" if is_target else &"NameplateWarningPanel"
	else:
		%Plate.theme_type_variation = &"NameplateTargetPanel" if is_target else &"NameplatePanel"
	%NameLabel.text = unit.get_unit_name()
	var class_data := unit.get_class_data()
	var name_color := class_data.color if unit.is_player_unit() and class_data != null \
			else UnitColors.reaction_color(reaction)
	%NameLabel.add_theme_color_override("font_color", name_color)
	%HealthRow.visible = hostile
	# Eigene Debuffs auf Feinden als kleine Symbole darüber (#32).
	%Auras.set_unit(unit, viewer)
	%Auras.enabled = show_plate and hostile
	if hostile:
		var level := unit.get_level()
		%LevelLabel.text = str(level)
		%LevelLabel.add_theme_color_override("font_color", UnitColors.difficulty_color(
				UnitColors.difficulty(level, viewer.get_level() if viewer != null else 1)))
		var stats := unit.get_stats()
		var bar: ProgressBar = %HealthBar
		bar.max_value = maxf(1.0, stats.max_health if stats != null else 1.0)
		bar.value = stats.health if stats != null else 0.0
	# Zauberleiste (#33) unter Name und Leben.
	%CastBar.set_unit(unit if show_plate else null)
	var meter := unit.get_overhead_text()
	%MeterLabel.visible = meter != ""
	%MeterLabel.text = meter
	var factor := TARGET_SCALE if is_target else 1.0
	scale = Vector2(factor, factor)


## Tank-Hinweis (#35): viewer ist Tank (Combat.is_tank, z. B. Tankhaltung)
## und unit greift gerade einen anderen Spieler an (Ziel nach Bedrohung).
static func _attacks_someone_else(p_unit: Unit, viewer: Unit) -> bool:
	if viewer == null or p_unit.is_dead() or not Combat.is_tank(viewer):
		return false
	var combat := p_unit.get_combat()
	var target := combat.get_threat_target() if combat != null else null
	return target != null and target != viewer


## Setzt die Plakette so, dass ihre Unterkante mittig über screen_point liegt.
func place_at(screen_point: Vector2) -> void:
	reset_size()
	pivot_offset = Vector2(size.x / 2.0, size.y)
	position = screen_point - pivot_offset


func _on_gui_input(event: InputEvent) -> void:
	if unit == null or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
		clicked.emit(unit, event.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()
