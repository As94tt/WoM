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
##   Entwickler-Panel aktiv ist. Testfähigkeiten (#33, AbilityData.dev_only)
##   stehen im Reiter „Allgemein“ nur nach „Testfähigkeiten erlernen“.
## - use_ability() ist die zentrale Funktion „Fähigkeit benutzen“. Seit #33
##   geht sie an UnitCaster (Kindknoten „Caster“): sofortige Prüfung und
##   Vorhersage beim Besitzer, Wunsch an den Host, der prüft und ausführt.
##   Bodenziel-Fähigkeiten öffnen erst den Kreis am Mauszeiger
##   (GroundTargeting); „Automatischer Angriff“ schaltet über die Zielauswahl.
##
## Spezialisierung und Talente (#20, Kindknoten „Talents“ der Figur):
## - Ein zusätzlicher Reiter mit dem Namen der wirksamen Spezialisierung zeigt
##   die Fähigkeiten aus Talenten (nur der Reiter der gewählten).
## - Fähigkeiten aus Talenten gelten als erlernt, solange das Talent gelernt
##   und wirksam ist; neue melden abilities_learned (→ erster freier Slot),
##   weggefallene abilities_unlearned (→ verschwinden von den Leisten).
## - resolve() liefert die aufgelöste Fähigkeit (Grundfähigkeit → Variante der
##   Spezialisierung → Ersatz durch Talente), die Zauberbuch, Leisten und
##   Tooltips anzeigen. Gespeichert wird weiter die Grundfähigkeit.
##
## Netzwerk: Der Knoten existiert auf jeder Instanz für jede Figur. Die Stufe
## kommt über StatsSync (Host-Autorität) aus CharacterStats; die Schalter des
## Entwickler-Panels (learn_flags) setzt der Host und ServerSync überträgt
## sie, damit der Host weiß, was die Figur kann (Prüfung 1). Zauberbuch und
## Aktionsleisten (ActionBarLayout) gibt es nur für die eigene Figur.

## Die Menge der erlernten Fähigkeiten hat sich geändert (Stufe, Entwickler-
## Panel). Anzeigen (Zauberbuch, Leisten) aktualisieren sich daraufhin.
signal learned_changed
## Fähigkeiten wurden neu erlernt (Stufe gestiegen oder „Alle erlernen“).
## abilities ist nach benötigter Stufe sortiert.
signal abilities_learned(abilities: Array[AbilityData])
## Fähigkeiten aus Talenten sind weggefallen (#20: zurückgesetzt, gewechselt).
signal abilities_unlearned(abilities: Array[AbilityData])
## Ein Wunsch wurde an den Host geschickt (bzw. auf dem Host ausgeführt).
signal ability_used(ability: AbilityData)
## Eine Fähigkeit ging nicht (Prüfung beim Besitzer oder Ablehnung des
## Hosts); reason ist die Meldung (AbilityError). ability kann null sein
## (z. B. automatischer Angriff außer Reichweite).
signal ability_failed(ability: AbilityData, reason: String)

## Schalter aus dem Entwickler-Panel (nur diese Sitzung), Bits in learn_flags.
const LEARN_ALL := 1
const LEARN_TEST := 2
## Angeborene Fähigkeit „Aufhelfen“ (#35, Taste F, Aktion „interact“).
const HELP_ABILITY := &"aufhelfen"

## Vom Host gesetzt, über ServerSync übertragen (siehe oben).
var learn_flags := 0:
	set(value):
		if value == learn_flags:
			return
		var before := get_learned_abilities()
		learn_flags = value
		_announce_learned(before)
## Nur diese Sitzung (Entwickler-Panel): alle Fähigkeiten der Klasse gelten
## als erlernt.
var learn_all: bool:
	get:
		return learn_flags & LEARN_ALL != 0

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
	# Talente (#20): Reiter, „erlernt“ und Varianten ändern sich.
	var talents := get_talents()
	if talents != null:
		talents.talents_changed.connect(learned_changed.emit)
		talents.granted_changed.connect(_on_granted_changed)
	var combat := _player.get_node_or_null(^"Combat") as UnitCombat if _player != null else null
	if combat != null:
		combat.ability_modifiers_changed.connect(learned_changed.emit)
	var caster := get_caster()
	if caster != null:
		caster.failed.connect(func(code: int, param: String, ability: AbilityData) -> void:
			ability_failed.emit(ability, AbilityError.text(code, param)))
		caster.requested.connect(ability_used.emit)


## Stufe, mit der „erlernt“ geprüft wird.
func get_level() -> int:
	return _player.get_level() if _player != null else 1


func get_class_data() -> ClassData:
	return _player.get_class_data() if _player != null else null


## Spezialisierung und Talente (#20) oder null.
func get_talents() -> PlayerTalents:
	return _player.get_node_or_null(^"Talents") as PlayerTalents if _player != null else null


## Aufgelöste Fähigkeit (#20): Variante der Spezialisierung bzw. Ersatz durch
## Talente; ohne Veränderung die Fähigkeit selbst.
func resolve(ability: AbilityData) -> AbilityData:
	if ability == null or _player == null:
		return ability
	return ability.get_replacement_for(_player)


## Wirken (#33) oder null.
func get_caster() -> UnitCaster:
	return _player.get_node_or_null(^"Caster") as UnitCaster if _player != null else null


## Reiter des Zauberbuchs in Anzeigereihenfolge: „Allgemein“, die Klasse
## und (#20) die wirksame Spezialisierung mit den Fähigkeiten aus Talenten.
## Testfähigkeiten (dev_only) nur nach „Testfähigkeiten erlernen“.
func get_spellbook_tabs() -> Array[SpellbookTabData]:
	var tabs: Array[SpellbookTabData] = []
	var general := GameData.get_general_tab()
	if general != null:
		if learn_flags & LEARN_TEST == 0:
			var filtered := general.duplicate() as SpellbookTabData
			var visible: Array[AbilityData] = []
			for ability in general.abilities:
				if ability != null and not ability.dev_only:
					visible.append(ability)
			filtered.abilities = visible
			general = filtered
		tabs.append(general)
	var class_data := get_class_data()
	if class_data != null:
		tabs.append(SpellbookTabData.from_class(class_data, 1))
	var talents := get_talents()
	if talents != null and talents.is_spec_active():
		var spec := talents.get_spec()
		var tab := SpellbookTabData.new()
		tab.id = spec.id
		tab.title = spec.display_name
		tab.order = 2
		tab.abilities = talents.get_granted_abilities()
		tabs.append(tab)
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
## Fähigkeiten aus Talenten (#20): nur, solange das Talent sie gibt.
func is_learned(ability: AbilityData) -> bool:
	if ability == null:
		return false
	var talents := get_talents()
	if talents != null and talents.is_talent_ability(ability):
		return talents.has_granted(ability)
	if ability.dev_only:
		return learn_flags & LEARN_TEST != 0
	return learn_all or get_level() >= ability.required_level


## Prüfung 1 beim Wirken (#33): Die Fähigkeit gehört zur Figur (Zauberbuch
## oder Ersatz durch Talente) und ist erlernt.
func knows(ability: AbilityData) -> bool:
	if ability == null:
		return false
	var all := get_all_abilities()
	if all.has(ability):
		return is_learned(ability)
	# Ersatz durch Talente/Auren: erlaubt, wenn eine bekannte Fähigkeit dazu wird.
	for known in all:
		if known.get_replacement_for(_player) == ability:
			return is_learned(known)
	return false


## Gehört die Fähigkeit überhaupt zu dieser Figur (#22, unabhängig von Stufe
## und Entwickler-Schaltern)? Reiter „Allgemein“ (auch Testfähigkeiten), die
## Liste der Klasse oder eine Fähigkeit aus Talenten der Klasse. Varianten
## und Ersatz durch Talente gehören nicht dazu (gespeichert wird immer die
## Grundfähigkeit).
func belongs_to_character(ability: AbilityData) -> bool:
	if ability == null:
		return false
	var general := GameData.get_general_tab()
	if general != null and general.abilities.has(ability):
		return true
	var class_data := get_class_data()
	if class_data != null and class_data.abilities.has(ability):
		return true
	var talents := get_talents()
	return talents != null and talents.is_talent_ability(ability)


## Leisten bereinigen (#22): Slots mit Fähigkeiten, die es nicht mehr gibt
## oder die nicht zu dieser Figur gehören (z. B. gespeicherte Charaktere mit
## alten Fähigkeits-IDs), werden geleert. Gibt die Zahl der geleerten Slots
## zurück.
func clean_bar_layout(layout: ActionBarLayout) -> int:
	if layout == null:
		return 0
	var removed := 0
	for bar in ActionBarLayout.BAR_COUNT:
		for index in ActionBarLayout.SLOT_COUNT:
			var content := layout.get_content(bar, index)
			if content == null or not content.is_ability():
				continue
			if not belongs_to_character(content.get_ability()):
				push_warning("PlayerAbilities: Slot %d/%d „%s“ gehört nicht (mehr) zur Figur und wird geleert." % [
						bar + 1, index + 1, content.id])
				layout.clear(bar, index)
				removed += 1
	return removed


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
## Nicht erlernte und passive Fähigkeiten lösen nichts aus. Seit #33:
## - „Automatischer Angriff“ schaltet über die Zielauswahl (an/aus),
## - Bodenziel öffnet den Kreis am Mauszeiger (GroundTargeting),
## - alles andere geht an UnitCaster.request_use (Prüfung, Vorhersage,
##   Wunsch an den Host).
func use_ability(ability: AbilityData) -> void:
	if not can_place(ability) or _player == null:
		return
	var caster := get_caster()
	if caster == null:
		return
	ability = ability.get_replacement_for(_player)
	var targeting := _player.get_targeting()
	var target: Unit = targeting.target if targeting != null else null
	if ability.toggles_auto_attack:
		if targeting != null:
			targeting.toggle_auto_attack()
		return
	if ability.target_kind == AbilityData.TargetKind.GROUND:
		var ground := _player.get_node_or_null(^"GroundTargeting") as GroundTargeting
		if ground == null:
			return
		if ground.is_active() and ground.get_ability() == ability:
			ground.cancel()
			return
		# Erst prüfen, was ohne Ort schon feststeht (Abklingzeit, Ressource …).
		var result := caster.check(ability, target)
		var code: int = result[0]
		if code != AbilityError.Code.OK and code != AbilityError.Code.INVALID_POINT \
				and not AbilityError.is_queueable(code):
			ability_failed.emit(ability, AbilityError.text(code, result[1]))
			return
		ground.begin(ability)
		return
	caster.request_use(ability, target)


## Aufhelfen (#35): Taste F gedrückt. Ziel ist das aktuelle Ziel, wenn es
## ein toter Mitspieler in Reichweite ist, sonst der nächste tote Mitspieler
## in Reichweite (Fähigkeit „aufhelfen“, Reichweite aus faehigkeitswerte.csv).
## Danach wie jede Fähigkeit mit Zauberzeit (Prüfung, Vorhersage, Host).
func start_help_up() -> void:
	var caster := get_caster()
	var ability := GameData.get_ability(HELP_ABILITY)
	if caster == null or ability == null or _player == null:
		return
	var target := _find_help_target(caster, ability)
	if target == null:
		ability_failed.emit(ability, AbilityError.text(AbilityError.Code.NOBODY_TO_HELP))
		return
	caster.request_use(ability, target)


## Taste F losgelassen: laufendes Aufhelfen abbrechen.
func stop_help_up() -> void:
	var caster := get_caster()
	if caster == null:
		return
	var info := caster.get_cast_info()
	if not info.is_empty() and (info["ability"] as AbilityData).id == HELP_ABILITY:
		caster.request_cancel()


func _find_help_target(caster: UnitCaster, ability: AbilityData) -> Unit:
	var targeting := _player.get_targeting()
	var current: Unit = targeting.target if targeting != null else null
	if _is_help_target(caster, ability, current):
		return current
	var best: Unit = null
	for unit in Unit.all_units(_player.get_tree()):
		if _is_help_target(caster, ability, unit) and (best == null
				or _player.distance_to_unit(unit) < _player.distance_to_unit(best)):
			best = unit
	return best


func _is_help_target(caster: UnitCaster, ability: AbilityData, unit: Unit) -> bool:
	return unit != null and is_instance_valid(unit) and unit != _player and unit.is_player_unit() \
			and unit.is_dead() and caster.is_in_range(ability, unit)


## Warum die Fähigkeit gerade nicht geht (leer = geht), mit dem aktuellen
## Ziel. Dieselbe Prüfung wie beim Wirken (UnitCaster.check, #33).
func get_block_reason(ability: AbilityData) -> String:
	var caster := get_caster()
	if caster == null or ability == null:
		return ""
	var targeting := _player.get_targeting()
	var result := caster.check(ability, targeting.target if targeting != null else null)
	return AbilityError.text(result[0], result[1])


## Zustand eines Aktionsslots (#33): {"cooldown": Vector2(Rest, Dauer),
## "gcd": Vector2, "out_of_range", "no_resource", "highlight", "active",
## "charges" (−1 = ohne Aufladungen)}.
func get_slot_state(ability: AbilityData) -> Dictionary:
	var caster := get_caster()
	if caster == null or ability == null or _player == null:
		return {}
	ability = ability.get_replacement_for(_player)
	var targeting := _player.get_targeting()
	var target: Unit = targeting.target if targeting != null else null
	var combat := _player.get_combat()
	var highlight := false
	if combat != null:
		for aura_id in ability.highlight_auras:
			if combat.get_stacks(StringName(aura_id), _player) > 0:
				highlight = true
				break
	var active := false
	if ability.toggle_aura != null and combat != null:
		active = combat.get_stacks(ability.toggle_aura.id, _player) > 0
	if ability.toggles_auto_attack and targeting != null:
		active = targeting.auto_attack
	if ability.on_next_swing and caster.get_next_swing_id() == ability.id:
		active = true
	var gcd := Vector2.ZERO if ability.ignores_gcd or ability.toggles_auto_attack else caster.get_gcd()
	return {
		"cooldown": caster.get_cooldown(ability),
		"gcd": gcd,
		"out_of_range": not caster.is_in_range(ability, target),
		"no_resource": not caster.has_resource_for(ability),
		"highlight": highlight,
		"active": active,
		"charges": caster.get_charges_left(ability) if ability.get_charges() > 1 else -1,
	}


## Entwickler-Panel: Schalter LEARN_ALL bzw. LEARN_TEST setzen. Auf dem Host
## sofort, sonst als Wunsch an ihn (nur wenn er ein Debug-Build ist).
func request_learn(flag: int, on: bool) -> void:
	if Network.is_host():
		_set_learn(flag, on)
	else:
		_rpc_request_learn.rpc_id(1, flag, on)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_learn(flag: int, on: bool) -> void:
	if not Network.is_host() or not OS.is_debug_build() or _player == null:
		return
	if multiplayer.get_remote_sender_id() != _player.get_controlling_peer():
		return
	_set_learn(flag, on)


func _set_learn(flag: int, on: bool) -> void:
	learn_flags = (learn_flags | flag) if on else (learn_flags & ~flag)


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


## Talente (#20): neue Fähigkeiten melden, weggefallene zum Entfernen.
func _on_granted_changed(added: Array[AbilityData], removed: Array[AbilityData]) -> void:
	learned_changed.emit()
	if not removed.is_empty():
		abilities_unlearned.emit(removed)
	if not added.is_empty():
		abilities_learned.emit(added)


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
