class_name ProcData
extends Resource
## Auslöser einer Aura (Ticket #32): reagiert auf ein Ereignis und führt
## Effekte aus, mit Chance und optionaler interner Abklingzeit.
##
## Kontext der Effekte:
## - AURA_EXPIRED: Wirker = Wirker der Aura, Hauptziel = Träger.
## - alle anderen: Wirker = Träger der Aura, Hauptziel = die andere
##   beteiligte Einheit (getroffenes Ziel, Angreifer, getötetes Ziel); ohne
##   andere Einheit der Träger selbst. ctx.event_amount = Betrag.

@export var event: Combat.Event = Combat.Event.HIT
## Nur ABILITY_CAST: diese Fähigkeit (leer = jede).
@export var ability_id: StringName
@export_range(0.0, 100.0) var chance := 100.0
## Interne Abklingzeit in Sekunden (0 = keine).
@export var internal_cooldown := 0.0
@export var effects: Array[EffectData] = []
## Beim Auslösen einen Stapel der Aura verbrauchen.
@export var consume_stack := false
## Beim Auslösen die Aura beenden.
@export var remove_aura := false
