class_name AuraLogic
extends Resource
## Eigene Aura-Logik einer Klasse (Ticket #32), für Mechaniken, die sich nicht
## aus den Bausteinen der Aura zusammensetzen lassen (z. B. Mondphasen,
## Meridiane, Fluss). Eine Klasse legt eine Unterklasse an (z. B.
## scripts/combat/logic/mondphasen_logic.gd), überschreibt die benötigten
## Haken und trägt sie als Unterressource im Feld „logic“ der Aura ein.
## Das gemeinsame System bleibt unverändert.
##
## Alle Haken laufen nur auf dem Host. Zustand je Instanz gehört in
## instance.custom (Dictionary); er wird nicht übertragen.


## Die Aura wurde neu angewendet.
func on_applied(_instance: AuraInstance, _combat: UnitCombat) -> void:
	pass


## Die Aura wurde erneut angewendet (Dauer erneuert bzw. Stapel dazu).
func on_refreshed(_instance: AuraInstance, _combat: UnitCombat) -> void:
	pass


## Die Aura endet; reason siehe UnitCombat.RemoveReason.
func on_removed(_instance: AuraInstance, _combat: UnitCombat, _reason: int) -> void:
	pass


## Nach jedem Tick.
func on_tick(_instance: AuraInstance, _combat: UnitCombat) -> void:
	pass


## Ereignis beim Träger (wie Auslöser), vor den Auslösern der Aura.
func on_event(_instance: AuraInstance, _combat: UnitCombat, _event: Combat.Event,
		_other: Unit, _amount: float) -> void:
	pass


## Schaden, den der Träger nimmt, vor Umleitung und Absorption.
func modify_incoming_damage(_instance: AuraInstance, _combat: UnitCombat, amount: float,
		_school: StringName, _attacker: Unit) -> float:
	return amount


## Schaden, den der Träger austeilt.
func modify_outgoing_damage(_instance: AuraInstance, _combat: UnitCombat, amount: float,
		_school: StringName, _target: Unit) -> float:
	return amount
