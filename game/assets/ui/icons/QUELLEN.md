# Icons – Herkunft und Lizenz

Pflichtangaben laut `docs/UI-STYLEGUIDE.md` (Abschnitt „Icons“). Neue Icons hier eintragen.

| Gruppe | Dateien | Quelle (Arbeitsfassung) | Urheber / Werkzeug | Nutzungsbedingungen |
|---|---|---|---|---|
| Klassen | `classes/*.png` (5) | `art-source/Icons/` (1254 px) | Projektverantwortlicher; Werkzeug **OFFEN – bitte ergänzen** | **OFFEN – bitte ergänzen** |
| Magier-Spezialisierungen | `specializations/mage_*.png` (6) | `art-source/Icons/` (1254 px) | Projektverantwortlicher; Werkzeug **OFFEN – bitte ergänzen** | **OFFEN – bitte ergänzen** |
| Magier-Zauber | `abilities/*.png` (28) | `art-source/Icons/` (1024 px) | Projektverantwortlicher; Werkzeug **OFFEN – bitte ergänzen** | **OFFEN – bitte ergänzen** |
| Magier-Auren | `auras/*.png` (7) | gleiches Bild wie der gleichnamige Zauber | wie Magier-Zauber | wie Magier-Zauber |
| UI-Paket „Stone & Brass“ (v3, 27.11.2026): Bediensymbole, leere Ausrüstungsplätze, Münzen | `interface/*.png` (51) | Quellbögen `art-source/UI/png-icon-sheets/` (Zuordnung `SOURCE_SHEET_MAP.csv`) | für WoM erzeugt (Paket des Projektverantwortlichen); nicht aus WoW oder anderen Spielen kopiert | Paket: „Check the project-specific content and license policy before commercial redistribution“ – Lizenz/Werkzeug **OFFEN – bitte ergänzen** |
| UI-Paket: Testgegenstände | `items/*.png` (10) | wie oben | wie oben | wie oben |
| UI-Paket: allgemeine Fähigkeiten | `abilities/auto_attack.png`, `help_up.png`, `revive.png` | wie oben | wie oben | wie oben |
| UI-Paket: Schadensschulen | `schools/*.png` (9) | wie oben | wie oben | wie oben |
| UI-Paket: Karte und Quest-Zustände | `map/*.png` (6) | wie oben | wie oben | wie oben |
| UI-Paket: Völker-Embleme (**Konzept, OFFEN**, nicht eingebunden) | `races/*.png` (6) | wie oben | wie oben | wie oben |

Die übrigen Grafiken des Pakets (Rahmen, Balken, Mauszeiger, Branding, Overlays, Welt-Markierungen, Porträt-Silhouetten unter `game/assets/ui/`) sind laut Paket prozedural erzeugt; ihre SVG-Quellen liegen in `art-source/UI/svg/`. Schriften enthält das Paket nicht. Die freigegebenen Stil-Referenzbilder liegen nur als Referenz in `art-source/UI/style_references/` (keine Spielgrafik).

## Zuordnung deutsche ID → englische Datei (UI-Paket)

Dateien aus dem UI-Paket behalten ihre englischen Namen; die deutschen Spiel-IDs bleiben unverändert. Die vollständige Liste steht in `docs/ui-assets/german_to_english_icon_ids.csv`. Eingebunden wird datengetrieben: Gegenstände über die Spalte `icon` in `gegenstaende.csv`, Ausrüstungsplätze über `ausruestungsplaetze.csv`, Schadensschulen über die Spalte `icon` in `schadensschulen.csv`, Fähigkeiten über das Feld `icon` in `game/data/abilities/*.tres` (`automatischer_angriff` → `abilities/auto_attack.png`, `aufhelfen` → `abilities/help_up.png`).

## Zuordnung Arbeitsfassung → Spiel (#55)

Die Arbeitsfassungen tragen englische Namen; im Spiel heißen die Icons wie die IDs.

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
