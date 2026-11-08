class_name SpellbookEntry
extends HBoxContainer
## Eine Fähigkeit im Zauberbuch (Ticket #21): Icon links (SlotButton mit
## Icon bzw. Kürzel), daneben der Name und darunter klein „Passiv“, die Stufe
## oder „Erfordert Stufe X“. Nicht erlernte Fähigkeiten sind ausgegraut
## (Icon deaktiviert, Texte gedämpft). Tooltip wie auf den Aktionsleisten.
##
## Spezialisierung und Talente (#20): Angezeigt werden Name, Icon und Tooltip
## der aufgelösten Variante (PlayerAbilities.resolve), gezogen wird die
## Grundfähigkeit (die Leisten speichern sie).
##
## Erlernte, aktive Fähigkeiten lassen sich auf die Aktionsleisten ziehen
## (immer, auch bei gesperrten Leisten); passive und nicht erlernte nicht.
## Rein lokal.

var _ability: AbilityData = null
var _abilities: PlayerAbilities = null
var _learned := false
var _learned_without_player := true

@onready var _icon: Button = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _info_label: Label = %InfoLabel


## Zeigt ability; abilities entscheidet über „erlernt“. Ohne Figur (null,
## z. B. Stilvorschau) gilt learned_without_player.
func setup(ability: AbilityData, abilities: PlayerAbilities, learned_without_player := true) -> void:
	_ability = ability
	_abilities = abilities
	_learned_without_player = learned_without_player
	refresh()


func get_ability() -> AbilityData:
	return _ability


## Angezeigte Fähigkeit (#20: Variante der Spezialisierung).
func get_shown_ability() -> AbilityData:
	return _abilities.resolve(_ability) if _abilities != null else _ability


func _caster() -> Unit:
	return _abilities.get_parent() as Unit if _abilities != null else null


func is_learned() -> bool:
	return _learned


## Ob sich die Fähigkeit auf eine Leiste ziehen lässt.
func can_drag() -> bool:
	return _ability != null and _learned and not _ability.passive


func refresh() -> void:
	if not is_node_ready() or _ability == null:
		return
	_learned = _abilities.is_learned(_ability) if _abilities != null else _learned_without_player
	var shown := get_shown_ability()
	AbilityIcon.apply(_icon, shown)
	_icon.disabled = not _learned
	_name_label.text = shown.display_name
	_name_label.theme_type_variation = &"BodyText" if _learned else &"HintText"
	var info: String
	if not _learned:
		info = AbilityTooltip.required_level_text(_ability)
		if _ability.passive:
			info = "Passiv · " + info
	elif _ability.passive:
		info = "Passiv"
	else:
		info = "Stufe %d" % _ability.required_level
	_info_label.text = info
	_info_label.theme_type_variation = &"SmallLabel" if _learned else &"SmallHintText"
	tooltip_text = AbilityTooltip.text(shown, _learned, _caster())


func _make_custom_tooltip(_for_text: String) -> Object:
	if _ability == null:
		return null
	return AbilityTooltip.create(get_shown_ability(), _learned, _caster())


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not can_drag():
		return null
	var data := ActionDragData.create(ActionSlotContent.ability(_ability.id))
	set_drag_preview(data.make_preview())
	return data
