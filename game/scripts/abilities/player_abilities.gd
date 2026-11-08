class_name PlayerAbilities
extends Node
## Fähigkeiten einer Spielfigur (Ticket #21). Kindknoten „Abilities“ der
## Spielfigur (player.tscn), funktioniert ohne Interface.
##
## - Welche Fähigkeiten es gibt: Reiter „Allgemein“ und der Klasse
##   (get_spellbook_tabs). Später kommen Reiter für Unterklassen dazu.
## - Erlernt ist eine Fähigkeit, wenn die Stufe der Werte (CharacterStats,
##   inklusive „Stufe ändern“ im Entwickler-Panel) ihre benötigte Stufe
##   erreicht – oder für diese Sitzung „Alle Fähigkeiten erlernen“ im
##   Entwickler-Panel aktiv ist.
## - use_ability() ist die zentrale Funktion „Fähigkeit benutzen“. Vorerst
##   meldet sie nur „Würde X wirken“ (Signal ability_used, Konsole). Mit dem
##   Kampfsystem (#33) schickt sie den Wunsch an den Host, der Kosten,
##   Abklingzeit, Ziel und Reichweite prüft und die Effekte ausführt.
##
## Netzwerk: Der Knoten existiert auf jeder Instanz für jede Figur, wird aber
## nicht synchronisiert. Die Stufe kommt über StatsSync (Host-Autorität) aus
## CharacterStats. Zauberbuch und Aktionsleisten (ActionBarLayout) gibt es nur
## für die eigene Figur (GameWorld).

## Die Menge der erlernten Fähigkeiten hat sich geändert (Stufe, Entwickler-
## Panel). Anzeigen (Zauberbuch, Leisten) aktualisieren sich daraufhin.
signal learned_changed
## Fähigkeiten wurden neu erlernt (Stufe gestiegen oder „Alle erlernen“).
## abilities ist nach benötigter Stufe sortiert.
signal abilities_learned(abilities: Array[AbilityData])
## use_ability() wurde aufgerufen (vorerst nur Meldung, #33: Wunsch an Host).
signal ability_used(ability: AbilityData)
## use_ability() ging nicht (Zustand aus einer Aura, #32); reason ist ein Satz.
signal ability_failed(ability: AbilityData, reason: String)

## Meldung, solange Fähigkeiten noch keine Wirkung haben (bis #33).
const USE_MESSAGE := "Würde %s wirken"

## Nur diese Sitzung (Entwickler-Panel): alle Fähigkeiten gelten als erlernt.
var learn_all := false:
	set(value):
		if value == learn_all:
			return
		var before := get_learned_abilities()
		learn_all = value
		_announce_learned(before)

@onready var _player: PlayerCharacter = get_parent() as PlayerCharacter

var _stats: CharacterStats = null


func _ready() -> void:
	# Direkt über den Knoten: die @onready-Variablen der Figur sind hier noch
	# nicht gesetzt (Kindknoten sind vor der Figur bereit).
	if _player != null:
		_stats = _player.get_node_or_null("Stats") as CharacterStats
	if _stats != null:
		_stats.level_changed.connect(_on_level_changed)
		# Erster Stand eines Clients kommt erst nach _ready per StatsSync.
		_stats.stats_changed.connect(learned_changed.emit)


## Stufe, mit der „erlernt“ geprüft wird.
func get_level() -> int:
	return _player.get_level() if _player != null else 1


func get_class_data() -> ClassData:
	return _player.get_class_data() if _player != null else null


## Reiter des Zauberbuchs in Anzeigereihenfolge: „Allgemein“ und die Klasse.
func get_spellbook_tabs() -> Array[SpellbookTabData]:
	var tabs: Array[SpellbookTabData] = []
	var general := GameData.get_general_tab()
	if general != null:
		tabs.append(general)
	var class_data := get_class_data()
	if class_data != null:
		tabs.append(SpellbookTabData.from_class(class_data, 1))
	tabs.sort_custom(func(a: SpellbookTabData, b: SpellbookTabData) -> bool: return a.order < b.order)
	return tabs


## Alle Fähigkeiten aller Reiter, ohne doppelte.
func get_all_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for tab in get_spellbook_tabs():
		for ability in tab.abilities:
			if ability != null and not result.has(ability):
				result.append(ability)
	return result


## Ob die Fähigkeit erlernt ist (Stufe erreicht oder „Alle erlernen“).
func is_learned(ability: AbilityData) -> bool:
	return ability != null and (learn_all or get_level() >= ability.required_level)


## Ob die Fähigkeit auf eine Aktionsleiste darf: erlernt und aktiv.
func can_place(ability: AbilityData) -> bool:
	return is_learned(ability) and not ability.passive


func get_learned_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	result.assign(get_all_abilities().filter(is_learned))
	return result


## Standardbelegung der Aktionsleisten: alle erlernten, aktiven Fähigkeiten,
## nach benötigter Stufe; bei gleicher Stufe zuerst die Klasse, dann
## „Allgemein“ (Stufe 1: Klassenfähigkeit auf Slot 1, Automatischer Angriff
## auf Slot 2). level > 0 prüft „erlernt“ mit dieser Stufe statt der
## aktuellen (z. B. gespeicherte Stufe beim ersten Laden, bevor der Client
## die Werte vom Host hat).
func get_default_bar_abilities(level := 0) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ability in get_all_abilities():
		if ability.passive:
			continue
		if (level > 0 and ability.required_level <= level) or (level <= 0 and is_learned(ability)):
			result.append(ability)
	return _sorted_for_bar(result)


## Zentrale Funktion „Fähigkeit benutzen“ (Klick oder Taste auf einem Slot).
## Nicht erlernte und passive Fähigkeiten lösen nichts aus.
## Vorerst nur Meldung; ab #33 Wunsch an den Host (RPC), der entscheidet.
func use_ability(ability: AbilityData) -> void:
	if not can_place(ability):
		return
	var reason := get_block_reason(ability)
	if reason != "":
		ability_failed.emit(ability, reason)
		return
	print(USE_MESSAGE % ability.display_name)
	ability_used.emit(ability)


## Warum die Fähigkeit gerade nicht geht (leer = geht): Zustände aus Auren
## (#32). Betäubt oder umgeworfen: keine Aktionen; still: keine Zauber.
## Der Host prüft dasselbe beim Wirken (#33).
func get_block_reason(ability: AbilityData) -> String:
	var combat := _player.get_combat() if _player != null else null
	if combat == null or ability == null:
		return ""
	if not combat.can_act():
		return "Du kannst gerade nicht handeln (%s)." % Combat.state_names(
				combat.get_states() & (Combat.STATE_STUNNED | Combat.STATE_KNOCKED_DOWN))
	if ability.is_spell and not combat.can_cast_spells():
		return "Du kannst gerade nicht zaubern (Still)."
	return ""


func _on_level_changed(level: int, previous: int) -> void:
	if learn_all:
		return
	var newly: Array[AbilityData] = []
	for ability in get_all_abilities():
		if ability.required_level > previous and ability.required_level <= level:
			newly.append(ability)
	learned_changed.emit()
	if not newly.is_empty():
		abilities_learned.emit(_sorted_for_bar(newly))


func _announce_learned(before: Array[AbilityData]) -> void:
	var newly: Array[AbilityData] = []
	for ability in get_learned_abilities():
		if not before.has(ability):
			newly.append(ability)
	learned_changed.emit()
	if not newly.is_empty():
		abilities_learned.emit(_sorted_for_bar(newly))


func _sorted_for_bar(abilities: Array[AbilityData]) -> Array[AbilityData]:
	var order := get_all_abilities()
	var sorted := abilities.duplicate()
	sorted.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
		if a.required_level != b.required_level:
			return a.required_level < b.required_level
		if a.is_general() != b.is_general():
			return not a.is_general()
		return order.find(a) < order.find(b))
	var result: Array[AbilityData] = []
	result.assign(sorted)
	return result
