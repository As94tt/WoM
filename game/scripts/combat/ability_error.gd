class_name AbilityError
extends RefCounted
## Gründe, warum eine Fähigkeit nicht geht (Ticket #33), und ihre Meldungen.
## Host und Besitzer prüfen mit denselben Codes (UnitCaster.check); der Host
## schickt nur den Code und einen Zusatz (z. B. die Ressource), der Besitzer
## baut daraus die Meldung oben in der Bildschirmmitte.
##
## Reihenfolge der Prüfungen steht in UnitCaster.check (siehe Ticket #33).

enum Code {
	OK,
	NOT_LEARNED,      ## 1: nicht erlernt
	NOT_AVAILABLE,    ## 1: in der aktuellen Gestalt nicht verfügbar
	DEAD,             ## 2: der Wirker ist tot
	CANNOT_ACT,       ## 2: betäubt oder umgeworfen
	SILENCED,         ## 2: still (nur Zauber)
	SCHOOL_LOCKED,    ## 2: Schule nach Unterbrechung gesperrt (Zusatz: Schule)
	BUSY,             ## 2: zaubert bereits
	NOT_READY,        ## 3: Abklingzeit oder globaler Cooldown
	NO_RESOURCE,      ## 4: zu wenig Ressource (Zusatz: Ressourcen-ID)
	NO_TARGET,        ## 5: kein Ziel
	INVALID_TARGET,   ## 5: falsches Ziel (Freund statt Feind usw.)
	TARGET_DEAD,      ## 5: Ziel ist tot
	OUT_OF_RANGE,     ## 6: außer Reichweite
	NO_LINE_OF_SIGHT, ## 6: keine Sichtlinie
	NOT_FACING,       ## 7: Ziel nicht vor dem Wirker
	NEED_WEAPON,      ## 8: Waffe fehlt (Zusatz: AbilityData.WeaponRequirement)
	NEED_STEALTH,     ## 8: nicht getarnt
	NEED_BEHIND,      ## 8: nicht hinter dem Ziel
	NEED_AURA,        ## 8: Aura fehlt (Zusatz: Aura-ID)
	MOVING,           ## 8: in Bewegung (Zauberzeit, Kanalisieren)
	INVALID_POINT,    ## Bodenziel: kein gültiger Ort
	INTERRUPTED,      ## Zauber wurde unterbrochen
	IN_COMBAT,        ## 8: nur außerhalb des Kampfes (#35, Aufhelfen)
	TARGET_ALIVE,     ## 5: Ziel lebt (#35, Wiederbelebung)
	NOBODY_TO_HELP,   ## Aufhelfen (F): kein toter Mitspieler in Reichweite (#35)
}

const WEAPON_TEXTS := {
	AbilityData.WeaponRequirement.MELEE: "Dafür braucht Ihr eine Nahkampfwaffe.",
	AbilityData.WeaponRequirement.SHIELD: "Dafür braucht Ihr einen Schild.",
	AbilityData.WeaponRequirement.OFFHAND: "Dafür braucht Ihr eine Waffe in der Nebenhand.",
	AbilityData.WeaponRequirement.RANGED: "Dafür braucht Ihr eine Fernkampfwaffe.",
}


## Meldung zum Code (leer bei OK). param ist der Zusatz aus der Prüfung.
static func text(code: int, param: String = "") -> String:
	match code:
		Code.OK:
			return ""
		Code.NOT_LEARNED:
			return "Ihr habt diese Fähigkeit noch nicht erlernt."
		Code.NOT_AVAILABLE:
			return "Das könnt Ihr in dieser Gestalt nicht tun."
		Code.DEAD:
			return "Ihr seid tot."
		Code.CANNOT_ACT:
			return "Ihr könnt gerade nicht handeln."
		Code.SILENCED:
			return "Ihr könnt gerade nicht zaubern."
		Code.SCHOOL_LOCKED:
			return "Zauber der Schule %s sind noch gesperrt." % Data.schulname(StringName(param))
		Code.BUSY:
			return "Ihr wirkt bereits einen Zauber."
		Code.NOT_READY:
			return "Das ist noch nicht bereit."
		Code.NO_RESOURCE:
			return "Nicht genug %s." % CharacterStats.RULES.get_resource_name(StringName(param))
		Code.NO_TARGET:
			return "Ihr habt kein Ziel."
		Code.INVALID_TARGET:
			return "Ungültiges Ziel."
		Code.TARGET_DEAD:
			return "Euer Ziel ist tot."
		Code.OUT_OF_RANGE:
			return "Außer Reichweite."
		Code.NO_LINE_OF_SIGHT:
			return "Ziel nicht im Sichtfeld."
		Code.NOT_FACING:
			return "Ihr müsst Euer Ziel ansehen."
		Code.NEED_WEAPON:
			return WEAPON_TEXTS.get(int(param) if param.is_valid_int() else 0, "Dafür fehlt Euch die passende Waffe.")
		Code.NEED_STEALTH:
			return "Dafür müsst Ihr getarnt sein."
		Code.NEED_BEHIND:
			return "Ihr müsst hinter Eurem Ziel stehen."
		Code.NEED_AURA:
			var aura := GameData.get_aura(StringName(param))
			return "Das geht nur mit „%s“." % (aura.display_name if aura != null else param)
		Code.MOVING:
			return "Ihr könnt das in Bewegung nicht tun."
		Code.INVALID_POINT:
			return "Dort könnt Ihr das nicht wirken."
		Code.INTERRUPTED:
			return "Unterbrochen."
		Code.IN_COMBAT:
			return "Das geht im Kampf nicht."
		Code.TARGET_ALIVE:
			return "Euer Ziel lebt noch."
		Code.NOBODY_TO_HELP:
			return "Hier ist niemand, dem Ihr aufhelfen könnt."
	return "Das geht gerade nicht."


## true, wenn sich der Wunsch lohnt, in die Zauber-Warteschlange zu kommen
## (er wäre in Kürze möglich).
static func is_queueable(code: int) -> bool:
	return code == Code.NOT_READY or code == Code.BUSY
