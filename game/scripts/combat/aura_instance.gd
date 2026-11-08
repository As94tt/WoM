class_name AuraInstance
extends RefCounted
## Eine Aura auf einer Einheit (Ticket #32). Der Host führt die vollständige
## Instanz (UnitCombat); Clients bauen aus den übertragenen Feldern eine
## schlanke Kopie für Anzeige und Zustände.
##
## Übertragen (to_array): ID, Aura-ID, Pfad des Wirkers, Stapel, Ablaufzeit
## (Host-Zeit, −1 = dauerhaft), Dauer, Restschild, ausstehender verzögerter
## Schaden.

## Eindeutig je Einheit (vom Host vergeben).
var id := 0
var data: AuraData = null
## Pfad des Wirkers (überall gültig, siehe Unit.from_path); leer = keiner.
var caster_path := NodePath()
var stacks := 1
## Ablaufzeitpunkt in Host-Zeit (Network.host_time), −1 = dauerhaft.
var expires_at := -1.0
var duration := 0.0
var absorb_left := 0.0
var absorb_max := 0.0
## Ausstehender verzögerter Schaden (Umleitung DELAY), zur Anzeige.
var delayed_total := 0.0

# --- nur Host ---
var caster: Unit = null
var ctx: EffectContext = null
var next_tick := -1.0
var snapshot: Dictionary = {}
## Index des Auslösers → frühester nächster Auslösezeitpunkt (Host-Zeit).
var proc_ready_at: Dictionary = {}
## Verzögerter Schaden: Einträge [Schaden je Sekunde, Restsekunden, Schule].
var delayed: Array = []
var next_delay_tick := -1.0
## Frei für AuraLogic.
var custom: Dictionary = {}


## Quelle für Modifikatoren und Fähigkeitsveränderungen dieser Instanz.
func source_key() -> StringName:
	return StringName("aura:%d" % id)


func is_permanent() -> bool:
	return expires_at < 0.0


## Restzeit in Sekunden (INF bei dauerhaften Auren).
func remaining() -> float:
	if is_permanent():
		return INF
	return maxf(0.0, expires_at - Network.host_time())


## Wirker (falls noch da), auf jeder Instanz.
func get_caster(tree: SceneTree) -> Unit:
	if caster != null and is_instance_valid(caster):
		return caster
	return Unit.from_path(tree, caster_path)


func to_array() -> Array:
	return [id, String(data.id), String(caster_path), stacks, expires_at, duration,
			absorb_left, absorb_max, delayed_total]


## Client: Instanz aus übertragenen Feldern (null bei unbekannter Aura).
static func from_array(entry: Array) -> AuraInstance:
	if entry.size() < 9:
		return null
	var aura := GameData.get_aura(StringName(str(entry[1])))
	if aura == null:
		return null
	var inst := AuraInstance.new()
	inst.id = int(entry[0])
	inst.data = aura
	inst.caster_path = NodePath(str(entry[2]))
	inst.stacks = int(entry[3])
	inst.expires_at = float(entry[4])
	inst.duration = float(entry[5])
	inst.absorb_left = float(entry[6])
	inst.absorb_max = float(entry[7])
	inst.delayed_total = float(entry[8])
	return inst
