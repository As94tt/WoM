class_name AbilityData
extends Resource
## Eine Fähigkeit als Daten (Ticket #21). Die Datensätze liegen in
## res://data/abilities/ und werden über GameData geladen (get_ability).
##
## Aufteilung (Entscheidung zu #21, siehe docs/DATENTABELLEN.md):
## - Die .tres beschreibt die Fähigkeit: Name, Beschreibung, Icon, Klasse,
##   benötigte Stufe, aktiv/passiv. Später kommt hier der Aufbau dazu.
## - Die Zahlen (Kosten, Zauberzeit, Abklingzeit, Reichweite, Grundwert …)
##   stehen in faehigkeitswerte.csv (Zeile mit derselben id) und werden über
##   Data.faehigkeitswert() gelesen. Zu jeder .tres muss es dort eine Zeile
##   geben; die Datenprüfung meldet sonst einen Fehler.
##
## Erweiterung ohne Umbau (#32/#33): Seit #32 gibt es die Gruppe „Wirkung“
## mit der Effektliste (EffectData, inkl. Zielbestimmung, Bedingungen,
## Skalierung) und is_spell; bestehende .tres bleiben gültig, weil fehlende
## Felder ihren Standardwert bekommen. Zahlen mit Veränderungen durch Talente
## liefert get_number_for(), angehängte Effekte get_effects_for().
##
## Wirken (#33): Die Gruppe „Wirken“ beschreibt, wie die Fähigkeit eingesetzt
## wird (Ziel, Blickrichtung, globaler Cooldown, geteilte Abklingzeit,
## Bewegung, Unterbrechbarkeit, Bedingungen, Umschalter, nächster Schlag,
## automatischer Angriff). Die Art ergibt sich aus den Zahlen der Tabelle:
## kanalisierzeit > 0 = kanalisiert, zauberzeit > 0 = Zauberzeit, sonst
## sofort; aufladungen > 1 = Aufladungen (je abklingzeit Sekunden eine). Wann
## die Effekte wirken: sofort beim Einsetzen, bei Zauberzeit am Ende, beim
## Kanalisieren je Tick (Spalte tick). Ausgelöst wird eine Fähigkeit nur über
## PlayerAbilities.use_ability() → UnitCaster (Host prüft und führt aus).

## Ressourcen der Tabelle (Spalte „ressource“) → Ressourcen-ID des
## Wertesystems (CharacterStats.RESOURCE_IDS).
const RESOURCE_IDS := {
	"mana": &"mana",
	"wut": &"rage",
	"energie": &"energy",
	"chi": &"chi",
}

enum CastType { INSTANT, CAST, CHANNELED }
## Ziel der Fähigkeit (Prüfung 5 beim Einsetzen):
## NONE     – kein Ziel nötig (wirkt auf bzw. um den Wirker)
## ENEMY    – ein Feind (angreifbar: feindlich oder neutral), lebend
## FRIENDLY – ein Freund, lebend; ohne passendes Ziel auf sich selbst
## ANY      – Freund oder Feind
## GROUND   – Bodenziel: Kreis am Mauszeiger, Klick setzt den Punkt
enum TargetKind { NONE, ENEMY, FRIENDLY, ANY, GROUND }
## Benötigte Waffe (Prüfung 8).
enum WeaponRequirement { NONE, MELEE, SHIELD, OFFHAND, RANGED }

## Feste ID (z. B. &"feuerball"); gleich der id in faehigkeitswerte.csv. Wird
## in gespeicherten Aktionsleisten verwendet und nie geändert.
@export var id: StringName
## Anzeigename (Platzhalter nach GDD).
@export var display_name: String
## Beschreibung im Tooltip.
@export_multiline var description: String
## Icon; leer = Platzhalter (Kürzel aus dem Namen, siehe get_short_name).
@export var icon: Texture2D
## Klasse (ClassData.id); leer = „Allgemein“ (für alle Klassen).
@export var class_id: StringName = &""
## Stufe, ab der die Fähigkeit erlernt ist.
@export_range(1, 100) var required_level: int = 1
## Passive Fähigkeiten stehen im Zauberbuch, lassen sich aber nicht auf die
## Aktionsleisten ziehen und nicht auslösen (später: dauerhafte Aura, #32).
@export var passive := false

## Testfähigkeit (#33): steht nur im Zauberbuch, wenn sie im Entwickler-Panel
## erlernt wurde („Testfähigkeiten erlernen“), und zählt nicht für „Alle
## Fähigkeiten der Klasse erlernen“.
@export var dev_only := false

@export_group("Wirkung")
## Zauber (Stille verhindert ihn, #32; Unterbrechen sperrt seine Schule, #33).
## Körperliche Fähigkeiten: false.
@export var is_spell := false
## Schadensschule (ID aus schadensschulen.csv) für Sperre nach Unterbrechung,
## Leuchten beim Zaubern und Projektilfarbe. Leer = Schule des ersten
## Schadenseffekts, sonst „physisch“.
@export var school: StringName = &""
## Was die Fähigkeit bewirkt (#32): eine Liste von Effekten, ausgeführt vom
## Host über Combat.execute (#33: UnitCaster). Leer = ohne Wirkung.
@export var effects: Array[EffectData] = []

@export_group("Wirken")
@export var target_kind: TargetKind = TargetKind.ENEMY
## Das Ziel muss vor dem Wirker stehen (nur bei Feinden geprüft).
@export var requires_facing := true
## Das Ziel bzw. der Bodenpunkt muss in Sichtlinie sein.
@export var requires_line_of_sight := true
## Außerhalb des globalen Cooldowns (löst ihn nicht aus und wartet nicht auf
## ihn), z. B. Unterbrechungen, Schutz-Cooldowns, automatischer Angriff.
@export var ignores_gcd := false
## Fähigkeiten mit derselben Gruppe teilen sich die Abklingzeit (leer = eigene).
@export var cooldown_group: StringName = &""
## Zauberzeit bzw. Kanalisieren in Bewegung möglich (sonst bricht Bewegung ab).
@export var castable_while_moving := false
## Unterbrechungen stoppen diesen Zauber (false = Schild-Symbol an der Leiste).
@export var interruptible := true
## Umschalter: Ist diese Aura auf dem Wirker, beendet erneutes Einsetzen sie
## (ohne Kosten, Abklingzeit und globalen Cooldown); sonst wirken die
## Effekte (die die Aura anwenden sollten).
@export var toggle_aura: AuraData
## Nächster Schlag: wird beim nächsten automatischen Angriff der Haupthand
## statt des normalen Schlags ausgelöst (Kosten dann).
@export var on_next_swing := false
## Startet den automatischen Angriff auf das Ziel (Nahkampffähigkeiten).
@export var starts_auto_attack := false
## Schaltet den automatischen Angriff an bzw. aus (Fähigkeit „Automatischer
## Angriff“); hat sonst keine Wirkung.
@export var toggles_auto_attack := false

@export_group("Bedingungen")
@export var required_weapon: WeaponRequirement = WeaponRequirement.NONE
## Nur getarnt einsetzbar.
@export var requires_stealth := false
## Nur hinter dem Ziel einsetzbar.
@export var requires_behind := false
## Nur mit dieser Aura auf dem Wirker (z. B. „Rache nach Abwehren“).
@export var required_aura: StringName = &""
## Leuchtender Rand auf der Aktionsleiste, solange der Wirker eine dieser
## Auren hat (Proc, z. B. „Meteor sofort wirkbar“).
@export var highlight_auras: PackedStringArray = []


## Effekte inklusive der durch Talente usw. angehängten (Host).
func get_effects_for(caster: Unit) -> Array[EffectData]:
	var result: Array[EffectData] = effects.duplicate()
	var combat := caster.get_combat() if caster != null else null
	if combat != null:
		result.append_array(combat.get_added_effects(id))
	return result


## Zahl aus faehigkeitswerte.csv mit allen Veränderungen des Wirkers
## („Fähigkeit verändern“, #32), z. B. get_number_for(spieler, "kosten").
func get_number_for(caster: Unit, key: String) -> float:
	var base := _number(key)
	var combat := caster.get_combat() if caster != null else null
	return combat.get_ability_value(id, key, base) if combat != null else base


## Ersatz durch Talente usw. (#32): die Fähigkeit, die statt dieser gilt.
func get_replacement_for(caster: Unit) -> AbilityData:
	var combat := caster.get_combat() if caster != null else null
	var replacement := combat.get_ability_replacement(id) if combat != null else &""
	return GameData.get_ability(replacement) if replacement != &"" else self


## true für „Allgemein“ (keine Klasse).
func is_general() -> bool:
	return class_id == &""


## Kürzel für das Platzhalter-Icon: Anfangsbuchstaben der ersten zwei Wörter
## („Heilende Berührung“ → „HB“) bzw. die ersten zwei Buchstaben eines
## einzelnen Worts („Feuerball“ → „Fe“).
func get_short_name() -> String:
	var words: PackedStringArray = []
	for word in display_name.split(" ", false):
		var letters := ""
		for character in word:
			if character.to_upper() != character.to_lower():
				letters += character
		if letters != "":
			words.append(letters)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].left(2)
	return (words[0].left(1) + words[1].left(1)).to_upper()


# --- Zahlen aus faehigkeitswerte.csv -----------------------------------------

## Ein Wert aus faehigkeitswerte.csv (Spaltenname oder „werte.<schlüssel>“).
func get_value(key: String, fallback: Variant = null) -> Variant:
	return Data.faehigkeitswert(id, key, fallback)


## Kosten in Einheiten der Ressource (0 = keine Kosten).
func get_cost() -> float:
	return _number("kosten")


## Ressourcen-ID der Kosten (&"mana", &"rage", …) oder &"" ohne Kosten.
func get_cost_resource() -> StringName:
	return RESOURCE_IDS.get(str(get_value("ressource", "keine")), &"")


## Zauberzeit in Sekunden (0 = sofort).
func get_cast_time() -> float:
	return _number("zauberzeit")


## Kanalisierzeit in Sekunden (0 = nicht kanalisiert).
func get_channel_time() -> float:
	return _number("kanalisierzeit")


func get_cast_type() -> CastType:
	if get_channel_time() > 0.0:
		return CastType.CHANNELED
	if get_cast_time() > 0.0:
		return CastType.CAST
	return CastType.INSTANT


## Abklingzeit in Sekunden (0 = keine).
func get_cooldown() -> float:
	return _number("abklingzeit")


## Reichweite in Metern (0 = Nahkampf bzw. selbst).
func get_range() -> float:
	return _number("reichweite")


## Aufladungen (1 = keine Aufladungen, nur Abklingzeit).
func get_charges() -> int:
	return maxi(1, int(_number("aufladungen")))


## Schlüssel der Abklingzeit (geteilte Gruppe oder eigene ID).
func get_cooldown_key() -> StringName:
	return cooldown_group if cooldown_group != &"" else id


## Schadensschule (siehe Feld school).
func get_school() -> StringName:
	if school != &"":
		return school
	for effect in effects:
		var found := _school_in(effect)
		if found != &"":
			return found
	return &"physisch"


## true für Hilfszauber, die ohne passendes Ziel auf den Wirker gehen.
func targets_friends() -> bool:
	return target_kind == TargetKind.FRIENDLY


static func _school_in(effect: EffectData) -> StringName:
	if effect is DamageEffect:
		return (effect as DamageEffect).school
	if effect is ProjectileEffect:
		for inner in (effect as ProjectileEffect).effects:
			var found := _school_in(inner)
			if found != &"":
				return found
	if effect is AreaEffect:
		for inner in (effect as AreaEffect).effects:
			var found := _school_in(inner)
			if found != &"":
				return found
	return &""


func _number(key: String) -> float:
	var value: Variant = get_value(key, 0.0)
	return float(value) if value is float or value is int else 0.0
