class_name UnitColors
extends RefCounted
## Farben für Einheiten (Ticket #31): Gesinnung und Stufenunterschied. Die
## Werte stehen im Theme (game/assets/ui/theme.tres) unter dem eigenen
## Theme-Typ „UnitColors“ (wie MapMarker), damit auch 3D-Elemente (Bodenkreis
## unter dem Ziel) dieselben Farben nutzen. Alles Graubox-Platzhalter, die
## endgültigen Farben sind im UI-Styleguide OFFEN.
##
## Farbe ist nie der einzige Bedeutungsträger: Die Stufe steht als Zahl da,
## die Gesinnung zusätzlich über den Inhalt der Plakette (Feinde mit
## Lebensbalken, Freunde nur Name) und den Tooltip des Zielrahmens.

enum Difficulty { TRIVIAL, EASY, EVEN, HARD, IMPOSSIBLE }

const THEME_TYPE := &"UnitColors"
const REACTION_KEYS := {
	Unit.Reaction.HOSTILE: &"hostile",
	Unit.Reaction.NEUTRAL: &"neutral",
	Unit.Reaction.FRIENDLY: &"friendly",
}
const DIFFICULTY_KEYS := {
	Difficulty.TRIVIAL: &"level_trivial",
	Difficulty.EASY: &"level_easy",
	Difficulty.EVEN: &"level_even",
	Difficulty.HARD: &"level_hard",
	Difficulty.IMPOSSIBLE: &"level_impossible",
}
const REACTION_NAMES := {
	Unit.Reaction.HOSTILE: "feindlich",
	Unit.Reaction.NEUTRAL: "neutral",
	Unit.Reaction.FRIENDLY: "freundlich",
}
const DIFFICULTY_NAMES := {
	Difficulty.TRIVIAL: "trivial",
	Difficulty.EASY: "leicht",
	Difficulty.EVEN: "ebenbürtig",
	Difficulty.HARD: "schwer",
	Difficulty.IMPOSSIBLE: "sehr schwer",
}


static func reaction_color(reaction: Unit.Reaction) -> Color:
	return _color(REACTION_KEYS.get(reaction, &"hostile"))


## Schwierigkeit nach Stufenunterschied (Stufe des Ziels − eigene Stufe),
## Schwellen aus spielkonstanten.csv.
static func difficulty(target_level: int, own_level: int) -> Difficulty:
	var diff := target_level - own_level
	if diff >= int(Data.konstante(&"stufe_rot_ab", 5.0)):
		return Difficulty.IMPOSSIBLE
	if diff >= int(Data.konstante(&"stufe_orange_ab", 3.0)):
		return Difficulty.HARD
	if diff > int(Data.konstante(&"stufe_gruen_bis", -3.0)):
		return Difficulty.EVEN
	if diff > int(Data.konstante(&"stufe_grau_bis", -8.0)):
		return Difficulty.EASY
	return Difficulty.TRIVIAL


static func difficulty_color(value: Difficulty) -> Color:
	return _color(DIFFICULTY_KEYS.get(value, &"level_even"))


static func _color(key: StringName) -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_color(key, THEME_TYPE):
		return theme.get_color(key, THEME_TYPE)
	return ThemeDB.get_default_theme().get_color(&"font_color", &"Label")
