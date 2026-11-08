class_name AuraBar
extends HFlowContainer
## Reihe von Aura-Symbolen einer Einheit (Ticket #32), umbricht bei Bedarf.
##
## - BUFFS / DEBUFFS: eigene Auren oben rechts (Buffs in einer Reihe,
##   Debuffs darunter).
## - TARGET: Zielrahmen; erst die eigenen Debuffs (größer, own_icon_size),
##   dann übrige Debuffs, dann Buffs (other_icon_size).
## - OWN_DEBUFFS: Namensplaketten; nur Debuffs des Betrachters auf Feinden,
##   klein, ohne Restzeit und ohne Tooltip.
## Versteckte Auren (AuraData.hidden) erscheinen nie. Aktualisiert sich bei
## UnitCombat.auras_changed; rein lokal.

enum Filter { BUFFS, DEBUFFS, TARGET, OWN_DEBUFFS }

const ICON_SCENE := preload("res://scenes/ui/hud/aura_icon.tscn")

@export var filter: Filter = Filter.BUFFS
@export var icon_size := 36
## TARGET: Größe der eigenen Debuffs bzw. aller anderen Auren.
@export var own_icon_size := 32
@export var other_icon_size := 24
@export var show_time := true
@export var interactive := true
## Höchstzahl Symbole (0 = alle).
@export var max_icons := 0

## Anzeigen erlaubt (z. B. Namensplakette eingeblendet).
var enabled := true:
	set(value):
		if enabled == value:
			return
		enabled = value
		_update_visible()

var _unit: Unit = null
var _viewer: Unit = null
var _combat: UnitCombat = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_visible()


func get_unit() -> Unit:
	return _unit


## Einheit setzen (null = leer). viewer = eigene Figur (eigene Debuffs).
func set_unit(unit: Unit, viewer: Unit) -> void:
	if unit == _unit and viewer == _viewer:
		return
	if _combat != null and is_instance_valid(_combat) and _combat.auras_changed.is_connected(_rebuild):
		_combat.auras_changed.disconnect(_rebuild)
	_unit = unit if unit != null and is_instance_valid(unit) else null
	_viewer = viewer
	_combat = _unit.get_combat() if _unit != null else null
	if _combat != null:
		_combat.auras_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if _combat == null or not is_instance_valid(_combat):
		_update_visible()
		return
	var viewer_path := _viewer.get_path() if _viewer != null and _viewer.is_inside_tree() else NodePath()
	var own: Array[AuraInstance] = []
	var debuffs: Array[AuraInstance] = []
	var buffs: Array[AuraInstance] = []
	for inst in _combat.get_auras():
		if inst.data.hidden:
			continue
		var mine := not viewer_path.is_empty() and inst.caster_path == viewer_path
		if inst.data.is_debuff:
			if mine and filter in [Filter.TARGET, Filter.OWN_DEBUFFS]:
				own.append(inst)
			else:
				debuffs.append(inst)
		else:
			buffs.append(inst)
	var entries: Array[Array] = []
	match filter:
		Filter.BUFFS:
			for inst in buffs:
				entries.append([inst, icon_size])
		Filter.DEBUFFS:
			for inst in debuffs:
				entries.append([inst, icon_size])
		Filter.TARGET:
			for inst in own:
				entries.append([inst, own_icon_size])
			for inst in debuffs + buffs:
				entries.append([inst, other_icon_size])
		Filter.OWN_DEBUFFS:
			if _viewer != null and Combat.is_hostile(_viewer, _unit):
				for inst in own:
					entries.append([inst, icon_size])
	if max_icons > 0 and entries.size() > max_icons:
		entries.resize(max_icons)
	for entry in entries:
		var icon: AuraIcon = ICON_SCENE.instantiate()
		add_child(icon)
		icon.setup(entry[0], _combat, entry[1], show_time, interactive)
		icon.cancel_requested.connect(_combat.request_cancel)
	_update_visible()


func _update_visible() -> void:
	visible = enabled and get_child_count() > 0
