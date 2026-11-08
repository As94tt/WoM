class_name SpecializationExtension
extends Resource
## Klassenspezifische Erweiterung einer Spezialisierung (Ticket #20,
## „Erweiterbarkeit“). Eine Klasse, die Spezialisierungen anders nutzt als der
## Magier, legt ein Skript an, das diese Klasse erweitert (z. B.
## scripts/talents/class/warrior_stance_extension.gd), und trägt eine Instanz
## im Feld „extension“ ihrer SpecializationData ein. Das gemeinsame System
## (PlayerTalents, TalentPanel) ändert sich dafür nicht, und andere Klassen
## bemerken nichts davon.
##
## Alle Haken sind optional:
## - on_activated / on_deactivated laufen auf dem Host, wenn die
##   Spezialisierung wirksam wird bzw. endet (Wahl, Wechsel, Stufe), z. B. um
##   eine eigene Ressource oder Haltung freizuschalten.
## - make_panel liefert eine zusätzliche Anzeige im Talentfenster (unter dem
##   Baum), z. B. eine Leiste für eine Klassenmechanik; null = keine.
## - get_extra_abilities gibt weitere Fähigkeiten für den Reiter der
##   Spezialisierung im Zauberbuch (zusätzlich zu den Talent-Fähigkeiten).


## Host: Die Spezialisierung ist für player wirksam geworden.
func on_activated(_player: PlayerCharacter) -> void:
	pass


## Host: Die Spezialisierung ist für player nicht mehr wirksam.
func on_deactivated(_player: PlayerCharacter) -> void:
	pass


## Zusätzliche Anzeige im Talentfenster (nur lokal) oder null.
func make_panel(_player: PlayerCharacter) -> Control:
	return null


## Weitere Fähigkeiten im Reiter der Spezialisierung (überall gleich, weil
## der Host damit prüft, ob die Figur sie kennt).
func get_extra_abilities(_player: PlayerCharacter) -> Array[AbilityData]:
	return []
