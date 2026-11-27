# Icons – Herkunft und Lizenz

Pflichtangaben laut `docs/UI-STYLEGUIDE.md` (Abschnitt „Icons“). Neue Icons hier eintragen.

| Gruppe | Dateien | Quelle (Arbeitsfassung) | Urheber / Werkzeug | Nutzungsbedingungen |
|---|---|---|---|---|
| Klassen | `classes/*.png` (5) | `art-source/Icons/` (1254 px) | Projektverantwortlicher; Werkzeug **OFFEN – bitte ergänzen** | **OFFEN – bitte ergänzen** |
| Magier-Spezialisierungen | `specializations/mage_*.png` (6) | `art-source/Icons/` (1254 px) | Projektverantwortlicher; Werkzeug **OFFEN – bitte ergänzen** | **OFFEN – bitte ergänzen** |
| Magier-Zauber (neues Design, 27.11.2026) | `abilities/mage/{arcane,fire,frost,lightning}/*.png` (28) | Paket „WoM – Mage Spell Icons (28)“, Vorschauen und Referenzbogen in `art-source/UI/class-spell-icons/mage/` | vom Projektverantwortlichen geliefert (27.11.2026); laut Paket aus neu erzeugter Bildgenerierung zugeschnitten, keine Motive aus WoW oder anderen Spielen | **OFFEN – bitte ergänzen** |
| Krieger-Fähigkeiten (neues Design, 27.11.2026) | `abilities/warrior/{base,bulwark,berserker,battle_master}/*.png` (32, davon 29 verschiedene Bilder) | Paket „WoM – Warrior Ability Icons (32)“, Vorschauen und Referenzbögen in `art-source/UI/class-spell-icons/warrior/` | wie Magier-Zauber | **OFFEN – bitte ergänzen** |
| Auren der Magier- und Krieger-Zauber | keine eigenen Dateien | nutzen das Icon des Zaubers, der sie anwendet (z. B. Aura `eisschild` → `abilities/mage/frost/ice_shield.png`) | wie oben | wie oben |
| UI-Paket „Stone & Brass“ (v3, 27.11.2026): Bediensymbole, leere Ausrüstungsplätze, Münzen | `interface/*.png` (51) | Quellbögen `art-source/UI/png-icon-sheets/` (Zuordnung `SOURCE_SHEET_MAP.csv`) | für WoM erzeugt (Paket des Projektverantwortlichen); nicht aus WoW oder anderen Spielen kopiert | Paket: „Check the project-specific content and license policy before commercial redistribution“ – Lizenz/Werkzeug **OFFEN – bitte ergänzen** |
| UI-Paket: Testgegenstände | `items/*.png` (10) | wie oben | wie oben | wie oben |
| UI-Paket: allgemeine Fähigkeiten | `abilities/auto_attack.png`, `help_up.png`, `revive.png` | wie oben | wie oben | wie oben |
| UI-Paket: Schadensschulen | `schools/*.png` (9) | wie oben | wie oben | wie oben |
| UI-Paket: Karte und Quest-Zustände | `map/*.png` (6) | wie oben | wie oben | wie oben |
| UI-Paket: Völker-Embleme (**Konzept, OFFEN**, nicht eingebunden) | `races/*.png` (6) | wie oben | wie oben | wie oben |

Die übrigen Grafiken des Pakets (Rahmen, Balken, Mauszeiger, Branding, Overlays, Welt-Markierungen, Porträt-Silhouetten unter `game/assets/ui/`) sind laut Paket prozedural erzeugt; ihre SVG-Quellen liegen in `art-source/UI/svg/`. Schriften enthält das Paket nicht. Die freigegebenen Stil-Referenzbilder liegen nur als Referenz in `art-source/UI/style_references/` (keine Spielgrafik).

## Zuordnung deutsche ID → englische Datei (UI-Paket)

Dateien aus dem UI-Paket behalten ihre englischen Namen; die deutschen Spiel-IDs bleiben unverändert. Die vollständige Liste steht in `docs/ui-assets/german_to_english_icon_ids.csv`. Eingebunden wird datengetrieben: Gegenstände über die Spalte `icon` in `gegenstaende.csv`, Ausrüstungsplätze über `ausruestungsplaetze.csv`, Schadensschulen über die Spalte `icon` in `schadensschulen.csv`, Fähigkeiten über das Feld `icon` in `game/data/abilities/*.tres` (`automatischer_angriff` → `abilities/auto_attack.png`, `aufhelfen` → `abilities/help_up.png`).

## Zuordnung Magier- und Krieger-Icons (neues Design)

Die alten Magier-Zauber-Icons aus #55 (`abilities/<id>.png`, `auras/<id>.png`) sind entfernt. Die neuen Dateien behalten die englischen Namen der Pakete; die deutschen Spiel-IDs bleiben unverändert. Eingebunden wird über das Feld `icon` in `game/data/abilities/*.tres` und `game/data/auras/*.tres`. Die vollständige Zuordnung Spiel-ID → Icon steht in `docs/ui-assets/class_spell_icon_ids.csv`, die Paket-Manifeste in `docs/ui-assets/mage_spell_icon_manifest.*` und `docs/ui-assets/warrior_ability_icon_manifest.*` (dazu `warrior_mechanics_reference.json`, nur Hinweise, keine Spieldaten).

## Zuordnung Arbeitsfassung → Spiel (#55)

Die Arbeitsfassungen tragen englische Namen; im Spiel hießen die Icons wie die IDs. **Seit dem neuen Design gilt diese Tabelle nur noch für Klassen und Spezialisierungen;** die Zauber-Zeilen beschreiben die entfernten alten Magier-Icons (Arbeitsfassungen bleiben unverändert in `art-source/Icons/`).

| Arbeitsfassung | Icon im Spiel |
|---|---|
| `mage`, `warrior`, `druid`, `monk` | `classes/` gleicher Name |
| `rouge` | `classes/rogue` |
| `firemage`, `frostmage`, `Lighningmage` | `specializations/mage_feuer`, `mage_frost`, `mage_blitz` |
| `bloodmage`, `Summoner`, `warlock` | `specializations/mage_blutmagier`, `mage_beschwoerer`, `mage_hexenmeister` |
| `Arcane_Missile`, `_Impact`, `_Nova`, `_Bind`, `_Shield`, `_Step`, `_Touch` | `abilities/magisches_geschoss`, `magischer_einschlag`, `magische_nova`, `magische_fessel`, `magischer_schild`, `magischer_schritt`, `magische_beruehrung` |
| `Fire_Ball`, `_Ignite`, `_Meteor`, `_Nova`, `_Bind`, `_Shield`, `_Step` | `abilities/feuerball`, `entzuenden`, `meteor`, `feuernova`, `flammenfessel`, `flammenschild`, `flammensprung` |
| `Frost_Bolt`, `_Bite`, `_Glacial_Shard`, `_Nova`, `_Bind`, `_Shield`, `_Step` | `abilities/frostblitz`, `erfrierung`, `gletschersplitter`, `frostnova`, `eisfessel`, `eisschild`, `frostschritt` |
| `Lightning_Bolt`, `_Electrify`, `_Thunderstrike`, `_Nova`, `_Bind`, `_Shield`, `_Step` | `abilities/blitzpfeil`, `elektrisieren`, `donnerschlag`, `gewitternova`, `statische_fessel`, `sturmschild`, `blitzsprung` |
| Shield-, Bind-, Touch-, Bite-Icons | zusätzlich `auras/` mit gleichem Namen wie der Zauber (`magischer_schild`, `magische_fessel`, `magische_beruehrung`, `flammenschild`, `eisschild`, `erfrierung`, `sturmschild`) |
| `hunter` | nicht eingebaut (keine Klasse „Jäger“ im Spiel) |
