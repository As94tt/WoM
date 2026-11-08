class_name CombatColors
extends RefCounted
## Farben des Kampfes (Ticket #33) aus dem Theme (game/assets/ui/theme.tres),
## damit auch 3D-Elemente (Leuchten beim Zaubern, Projektile, Kreis des
## Bodenziels) und die Aktionsleiste keine Farben im Code haben:
## - Theme-Typ „SchoolColors“: je Schadensschule (ID aus schadensschulen.csv)
##   eine Farbe, z. B. „feuer“; fehlt sie, gilt „physisch“.
## - Theme-Typ „AbilityColors“: Tönung der Aktionsslots (out_of_range,
##   no_resource), Bodenziel (ground_valid, ground_invalid), Deckkraft des
##   Leuchtens (Konstante glow_alpha_percent).
## - Theme-Typ „CombatTextSchool“ (#34): Färbung des Kampftexts für eigenen
##   Schaden je Schule; fehlt eine Schule, bleibt die Farbe von
##   CombatTextDamage (weiß).
## Alles Graubox-Platzhalter, die endgültigen Werte sind im UI-Styleguide OFFEN.

const SCHOOL_TYPE := &"SchoolColors"
const ABILITY_TYPE := &"AbilityColors"
const COMBAT_TEXT_TYPE := &"CombatTextSchool"


static func school_color(school: StringName) -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme != null:
		if theme.has_color(school, SCHOOL_TYPE):
			return theme.get_color(school, SCHOOL_TYPE)
		if theme.has_color(&"physisch", SCHOOL_TYPE):
			return theme.get_color(&"physisch", SCHOOL_TYPE)
	return ThemeDB.get_default_theme().get_color(&"font_color", &"Label")


## Farbe des Leuchtens um eine zaubernde Einheit (Schulfarbe, halb durchsichtig).
static func cast_glow_color(school: StringName) -> Color:
	var color := school_color(school)
	var theme := ThemeDB.get_project_theme()
	var alpha := 35
	if theme != null and theme.has_constant(&"glow_alpha_percent", ABILITY_TYPE):
		alpha = theme.get_constant(&"glow_alpha_percent", ABILITY_TYPE)
	color.a = clampf(alpha / 100.0, 0.0, 1.0)
	return color


## Färbung des Kampftexts für eigenen Schaden einer Schule (#34, Theme-Typ
## „CombatTextSchool“) oder null (keine Färbung, z. B. physisch: dann gilt
## die Farbe von CombatTextDamage).
static func combat_text_school_color(school: StringName) -> Variant:
	var theme := ThemeDB.get_project_theme()
	if school != &"" and theme != null and theme.has_color(school, COMBAT_TEXT_TYPE):
		return theme.get_color(school, COMBAT_TEXT_TYPE)
	return null


static func ability_color(key: StringName) -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_color(key, ABILITY_TYPE):
		return theme.get_color(key, ABILITY_TYPE)
	return Color.WHITE
