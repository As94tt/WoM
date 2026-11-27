# UI-STYLEGUIDE – High-Fantasy-Koop-RPG

> **Status:** Stilrichtung „Stone & Brass“ vom Projektverantwortlichen freigegeben (27.11.2026, über das UI-Asset-Paket); Farb-Tokens (Abschnitt 3) und Schriften (Abschnitt 4) weiter **OFFEN**.  
> **Geltungsbereich:** Alle Ingame- und Menüoberflächen des Godot-Spiels.  
> **Abhängigkeiten:** Vor verbindlicher Festlegung `docs/GDD.md`, `CLAUDE.md` und `docs/GAME-STYLEGUIDE.md` lesen. Bei Widersprüchen Entscheidungen mit dem Projektverantwortlichen klären.

## 1. Zielbild

Das Spiel ist ein WoW-artiges Koop-RPG mit einem eigenständigen, gut lesbaren Comic-Fantasy-Look. Die UI soll Abenteuer, Charakterentwicklung und Gruppenspiel unterstützen, **ohne WoW-Grafiken, Rahmen, Icons oder identifizierbare Assets zu kopieren**. Stil und Farbsystem werden erst nach der gemeinsamen Stilentscheidung finalisiert.

### Designprinzipien (maximal fünf)
1. **Kampflesbarkeit zuerst:** Informationen und Interaktionen sind wichtiger als Dekoration.
2. **Ein konsistentes System:** Eine Quelle für Farben, Schrift, Abstände und Zustände.
3. **Erkennbare Hierarchie:** Gesundheitszustand, Ziel, Fähigkeiten und Warnungen sind auf einen Blick lesbar.
4. **Eigenständige Fantasy-Identität:** Neue Motive statt Nachbildungen bekannter MMORPG-UI.
5. **Skalierbarkeit:** Gute Lesbarkeit bei 1920×1080 und 2560×1440; UI-Skalierung und lange Texte berücksichtigen.

## 2. Stilentscheidungen

Freigegeben vom Projektverantwortlichen am 27.11.2026 über das UI-Asset-Paket „Stone & Brass“ (Grafiken unter `game/assets/ui/`, Quellen unter `art-source/UI/`, Freigabe-Referenzbilder in `art-source/UI/style_references/`):

| Entscheidung | Beispiele | Final |
|---|---|---|
| Stimmung | episch, warm-abenteuerlich, mystisch, düster | **dunkel, ruhig, ernsthaft** (dunkler Stein) |
| Rahmenmaterial | Metall, Holz, Stein, Pergament | **dunkler Stein mit mattem Messing/Gold** |
| Detailgrad | schlicht, mittel, stark verziert | **schlicht** (keine Runen, keine klassenspezifischen Motive auf gemeinsamer UI) |
| Formen | kantig, weich, ornamental | **kantig**, dezente Eckbeschläge |
| Referenzen | 1–3 Spiele/Illustrationsstile | eigene Konzeptbilder in `art-source/UI/style_references/` (keine Spielvorlage) |
| Informationsdichte | minimal, mittel, klassisches MMORPG | **kompakt** (Aktionsleiste ohne Abstände, sehr schmale Menüleiste) |

Höchstens zwei tragende Strukturfarben (Stein, Messing). Die Farbwerte der Paket-Palette sind **keine** Tokens; die Tokens in Abschnitt 3 bleiben TBD.

## 3. Design-Tokens und Farben

**Regel:** Hex-Werte sind erst nach Freigabe der Stilrichtung verbindlich. Keine frei erfundenen endgültigen Farbwerte in Code oder Szenen.

### Grundpalette

| Token | Zweck | Hex |
|---|---|---|
| `color/bg/base` | primärer Hintergrund | TBD |
| `color/bg/panel` | Panel-Hintergrund | TBD |
| `color/surface/raised` | erhöhte Fläche | TBD |
| `color/border/default` | Rahmen | TBD |
| `color/accent/primary` | Primärinteraktion | TBD |
| `color/accent/secondary` | sekundäre Hervorhebung | TBD |
| `color/text/primary` | Haupttext | TBD |
| `color/text/secondary` | ergänzender Text | TBD |
| `color/text/disabled` | deaktivierte Texte | TBD |
| `color/focus` | Tastatur-/Gamepad-Fokus | TBD |

### Semantische Spielfarben – feste Bedeutung

Alle Spielfarben müssen in sämtlichen Szenen **dieselbe Bedeutung** haben. Werte erst nach Freigabe einsetzen; Kontrast und Farbenblindheit berücksichtigen.

| Gruppe | Token | Farbe |
|---|---|---|
| Ressourcen | `resource/health` | TBD |
| Ressourcen | `resource/mana` | TBD |
| Ressourcen | `resource/rage` | TBD |
| Ressourcen | `resource/energy` | TBD |
| Ressourcen | `resource/chi` | TBD |
| Klasse | `class/warrior` | TBD |
| Klasse | `class/mage` | TBD |
| Klasse | `class/rogue` | TBD |
| Klasse | `class/monk` | TBD |
| Klasse | `class/druid` | TBD |
| Seltenheit (#18) | `rarity/poor` (Minderwertig) | vorläufig grau (Platzhalter im Theme, **Freigabe OFFEN**) |
| Seltenheit (#18) | `rarity/common` (Gewöhnlich) | vorläufig weiß (Platzhalter im Theme, **Freigabe OFFEN**) |
| Seltenheit (#18) | `rarity/uncommon` (Ungewöhnlich) | vorläufig grün (Platzhalter im Theme, **Freigabe OFFEN**) |
| Seltenheit (#18) | `rarity/rare` (Selten) | vorläufig blau (Platzhalter im Theme, **Freigabe OFFEN**) |
| Seltenheit (#18) | `rarity/epic` (Episch) | vorläufig lila (Platzhalter im Theme, **Freigabe OFFEN**) |
| Seltenheit | `rarity/legendary` (Reserve, noch keine Stufe in den Daten) | TBD |
| Geld (#18) | `coin/gold`, `coin/silver`, `coin/copper` (Münzsymbole) | TBD (Platzhalter im Theme, **OFFEN**) |
| Kampftext | `combat/damage` | TBD |
| Kampftext | `combat/critical` | TBD |
| Kampftext | `combat/heal` | TBD |
| Kampftext | `combat/miss` | TBD |
| Kampftext (#32) | `combat/taken` (erlittener Schaden) | TBD (Platzhalter im Theme, **OFFEN**) |
| Kampftext (#32) | `combat/info` (Immun, Absorbiert) | TBD (Platzhalter im Theme, **OFFEN**) |
| Kampftext (#34) | `combat/critical` (eigener kritischer Treffer), `combat/heal_critical`, `combat/periodic`, `combat/heal_periodic` | TBD (Platzhalter im Theme, **OFFEN**) |
| Kampftext (#34) | `combat/school/arkan`, `combat/school/feuer`, `combat/school/frost`, `combat/school/blitz`, `combat/school/natur`, `combat/school/chi` (Färbung eigenen Schadens) | TBD (Platzhalter im Theme, **OFFEN**) |
| Auren (#32) | `aura/buff` (Rahmen Buff) | TBD (Platzhalter im Theme, **OFFEN**) |
| Debuff-Kategorie (#32) | `debuff/none` | TBD (Platzhalter im Theme, **OFFEN**) |
| Debuff-Kategorie (#32) | `debuff/magic` | TBD (Platzhalter im Theme, **OFFEN**) |
| Debuff-Kategorie (#32) | `debuff/poison` | TBD (Platzhalter im Theme, **OFFEN**) |
| Debuff-Kategorie (#32) | `debuff/disease` | TBD (Platzhalter im Theme, **OFFEN**) |
| Debuff-Kategorie (#32) | `debuff/curse` | TBD (Platzhalter im Theme, **OFFEN**) |
| Debuff-Kategorie (#32) | `debuff/physical` | TBD (Platzhalter im Theme, **OFFEN**) |
| Gesinnung (#31) | `reaction/hostile` | TBD (Platzhalter im Theme, **OFFEN**) |
| Gesinnung (#31) | `reaction/neutral` | TBD (Platzhalter im Theme, **OFFEN**) |
| Gesinnung (#31) | `reaction/friendly` | TBD (Platzhalter im Theme, **OFFEN**) |
| Stufenunterschied (#31) | `level/trivial` | TBD (Platzhalter im Theme, **OFFEN**) |
| Stufenunterschied (#31) | `level/easy` | TBD (Platzhalter im Theme, **OFFEN**) |
| Stufenunterschied (#31) | `level/even` | TBD (Platzhalter im Theme, **OFFEN**) |
| Stufenunterschied (#31) | `level/hard` | TBD (Platzhalter im Theme, **OFFEN**) |
| Stufenunterschied (#31) | `level/impossible` | TBD (Platzhalter im Theme, **OFFEN**) |
| Fehlermeldung (#33) | `feedback/error` | TBD (Platzhalter im Theme, **OFFEN**) |
| Zauberleiste (#33) | `cast/cast`, `cast/channel`, `cast/done`, `cast/failed` | TBD (Platzhalter im Theme, **OFFEN**) |
| Aktionsslot (#33) | `slot/out_of_range`, `slot/no_resource`, `slot/proc`, `slot/cooldown` | TBD (Platzhalter im Theme, **OFFEN**) |
| Schadensschule (#33) | `school/physisch`, `school/arkan`, `school/feuer`, `school/frost`, `school/blitz`, `school/natur`, `school/chi`, `school/schatten`, `school/heilig` | TBD (Platzhalter im Theme, **OFFEN**) |
| Bodenziel (#33) | `ground/valid`, `ground/invalid` | TBD (Platzhalter im Theme, **OFFEN**) |
| Bedrohung (#35) | `threat/safe`, `threat/warning`, `threat/aggro` (Bedrohungsanzeige am Zielrahmen) | TBD (Platzhalter im Theme, **OFFEN**) |
| Tank-Hinweis (#35) | `nameplate/warning` (roter Rand an Namensplaketten von Gegnern, die jemand anderen angreifen) | TBD (Platzhalter im Theme, **OFFEN**) |
| Talente (#20) | `talent/pending` (Rahmen um vorläufig geänderte Talente), `talent/arrow_active`, `talent/arrow_inactive` (Pfeile für Voraussetzungen) | TBD (Platzhalter im Theme, **OFFEN**) |
| Menüleiste (#20) | `menu/hint` (Hinweis-Punkt am Menüleisten-Button, z. B. „Spezialisierung wählbar“) | TBD (Platzhalter im Theme, **OFFEN**) |
| Erfahrung (#27) | `progress/experience` (Füllung des Erfahrungsbalkens), `combat/experience` („+120 EP“) | TBD (Platzhalter im Theme, **OFFEN**) |
| Aufstieg (#27) | `levelup/title`, `levelup/link` (Aufstiegsmeldung), `levelup/glow` (Lichtschein an der Figur) | TBD (Platzhalter im Theme, **OFFEN**) |

**Vorläufige Spielfarben (#31):** Für Lebens- und Ressourcenbalken, Gesinnung und Stufenunterschied stehen im Theme gedämpfte **Platzhalterwerte** (Grün für Leben und „freundlich“, Blau für Mana, Rot für Wut und „feindlich“, Gelb für Energie und „neutral“, Türkis für Chi; Stufen grau → grün → gelb → orange → rot). Sie sind keine Tokens; die endgültigen Werte der Tabelle oben sind **OFFEN** und werden nach der Stilentscheidung im Theme ersetzt, ohne Code zu ändern.

**Vorläufige Spielfarben (#32):** Kampftext weiß (Schaden), grün (Heilung), rot (erlittener Schaden), grau (Immun, Absorbiert); Aura-Rahmen: Buff schmal hellgrau, Debuff breit in gedämpften Platzhaltertönen je Kategorie (ohne Kategorie grau, Magie blau, Gift grün, Krankheit ocker, Fluch violett, körperlich rötlich). Auch das sind nur **Platzhalter**, die endgültigen Werte sind **OFFEN** und sollen bei der Stilentscheidung bewusst eigenständig gewählt werden (keine Übernahme des Farbschemas eines anderen Spiels).

**Vorläufige Spielfarben (#33):** Fehlermeldung gedämpftes Rot; Zauberleiste gelblich (Zauberzeit), grünlich (Kanalisieren), grün (fertig), rot (unterbrochen/abgebrochen/fehlgeschlagen); Aktionsslot rot getönt außer Reichweite, bläulich ohne genug Ressource, goldener Rand bei einem Proc, halbtransparentes Schwarz als Uhrzeiger-Abdunklung; je Schadensschule ein Platzhalterton (physisch hellgrau, arkan violett, Feuer orange, Frost hellblau, Blitz blau, Natur grün, Chi türkis, Schatten dunkelviolett, Heilig hellgelb) für Projektile und das Leuchten beim Zaubern; Kreis des Bodenziels hellgrau bzw. rot außer Reichweite. Alles **Platzhalter, OFFEN**. Der **Klang der Fehlermeldung ist OFFEN** (es gibt noch keine Audio-Dateien; die Stelle zum Abspielen ist vorhanden).

**Vorläufige Spielfarben (#34):** Kampftext für eigenen Schaden nach Schule eingefärbt, wie im Ticket beschrieben: physisch weiß (ohne Färbung), Feuer orange, Frost hellblau, Blitz violett, Natur grün, Arkan rosa, Chi türkis; Schatten und Heilig haben noch keine eigene Kampftextfarbe (weiß). Eigener kritischer Treffer gelb und größer, kritische Heilung grün und größer, Schaden und Heilung über Zeit kleiner. Die Kampftextfarben je Schule stehen bewusst getrennt von `SchoolColors` (Projektile, Leuchten), weil das Ticket für Arkan und Blitz andere Töne nennt. Alles **Platzhalter, OFFEN**.

**Vorläufige Spielfarben (#35):** Bedrohungsanzeige grün (sicher), gelb (ab 80 % der für den Zielwechsel nötigen Bedrohung), rot (man hat die Aufmerksamkeit des Gegners), wie im Ticket beschrieben; Tank-Hinweis an Namensplaketten als roter, 3 px breiter Rand. Alles **Platzhalter, OFFEN**. Zweites Signal: Die Anzeige nennt den Prozentwert als Zahl, gelb mit „!“, rot mit „· greift Euch an“; der Warnrand ist breiter als der normale Zielrahmen (3 statt 2 px).

**Vorläufige Spielfarben (#20):** Rahmen um vorläufig geänderte Talente hellgrün (3 px), gelernte Talente mit dem hellen Rahmen von `SlotActive`, Pfeile für Voraussetzungen hellgrau (erfüllt) bzw. dunkelgrau (nicht erfüllt), Hinweis-Punkt am Menüleisten-Button gold mit dunkler Kontur, Schrift gesperrter Reiter im Grau deaktivierter Buttons. Alles **Platzhalter, OFFEN**. Zweites Signal: Unter jedem Talent steht der Rang als Text („1/3“), vorläufige Änderungen mit Differenz („1/3 (+1)“) und oben „Vorläufige Änderungen (+1 Punkte) …“; gesperrte Reihen „Erfordert 3 Punkte“; gesperrte Reiter nennen im Tooltip und auf ihrer Seite „Noch nicht entdeckt“; der Hinweis-Punkt ergänzt den Tooltip des Buttons („Talente (N) – Spezialisierung wählbar“).

**Vorläufige Spielfarben (#18):** Seltenheiten wie im Ticket festgelegt: Minderwertig grau, Gewöhnlich weiß, Ungewöhnlich grün, Selten blau, Episch lila (Theme-Typ `RarityColors`, Farbnamen `poor`, `common`, `uncommon`, `rare`, `epic` = Tokens `rarity/*`). Die Namen der Stufen sind ebenfalls vorläufig und stehen in `game/data/tables/seltenheiten.csv` (Spalte `farbe` verweist auf die Theme-Farbe, Spalte `rahmen` legt fest, ab welcher Stufe der Platz einen farbigen Rahmen bekommt: ab Ungewöhnlich). Münzsymbole gold, silbern und kupferfarben (`CoinGold`, `CoinSilver`, `CoinCopper`). Alles **vorläufige Platzhalter, Freigabe OFFEN**; bei der Stilentscheidung bewusst eigenständig wählen. Zweites Signal: Im Tooltip steht die Seltenheit als Text („Episch · Material“), auf den Münzen ein Buchstabe (G, S, K) und der Tooltip der Geldanzeige nennt den Betrag ausgeschrieben („Geld: 1 Gold 23 Silber 45 Kupfer“).

**Vorläufige Spielfarben (#27):** Erfahrungsbalken und „+120 EP“ in einem gedämpften Violett, Aufstiegsmeldung und Lichtschein an der Figur in einem hellen Gold. Alles **Platzhalter, OFFEN** (bei der Stilentscheidung bewusst eigenständig wählen). Der **Klang des Aufstiegs ist OFFEN** (keine Audiodatei; die Stelle zum Abspielen ist im Effekt vorhanden). Der **Totenkopf** statt der Stufe ist vorläufig das Textzeichen „☠“ (Schrift-Ersatz des Systems) in der Farbe `level/impossible`; ein eigenes Symbol ist **OFFEN**. Zweites Signal: Balken mit Zahlen im Tooltip, „EP“ hinter der Zahl, Aufstiegsmeldung als Text, Totenkopf im Tooltip des Zielrahmens als „Stufe ??“.

**Vorläufige Spielfarben (#29):** Theme-Typ `ItemColors` mit `stat` (Grün für Wertungen und Effekte im Tooltip: „Anlegen: +8 Präzision“), `origin` (Gold für den Herkunftstext) und `requirement_missing` (Rot für eine fehlende Voraussetzung: „Benötigt Stufe 25“, „Klassen: Magier“, Typ rechts, wenn die Klasse ihn nicht tragen darf). Roter Schleier über nicht nutzbaren Gegenständen in der Tasche (`SlotUnusable`, halbtransparentes Rot) und grünes Aufleuchten passender Ausrüstungsplätze beim Ziehen (`SlotDropAllowed`, halbtransparente grüne Fläche mit hellgrünem 2-px-Rahmen). Alles **Platzhalter, OFFEN** (bei der Stilentscheidung bewusst eigenständig wählen). Zweites Signal: Text statt nur Farbe („Benötigt Stufe 25“, „Anlegen:“, Vorzeichen „+5 Stärke“ / „−3 Ausdauer“ im Vergleich, „Angelegt“ über dem verglichenen Gegenstand); der Tooltip eines verschleierten Gegenstands nennt den Grund als Text, eine abgelehnte Aktion die Meldung oben in der Mitte („Eure Klasse kann das nicht tragen.“).

**Barrierefreiheit:** Farbe nie als einzigen Bedeutungsträger verwenden; Labels, Symbole, Formen und/oder Muster ergänzen. Kritische Warnungen brauchen ein klar unterscheidbares Signal.

## 4. Typografie

- **Titel-Font:** TBD; nur frei lizenzierte Schrift, bevorzugt SIL Open Font License 1.1.
- **Fließtext-/UI-Font:** TBD; nur frei lizenzierte Schrift, bevorzugt SIL Open Font License 1.1.
- **Lizenznachweis:** Dateiname, Urheber, genaue Lizenz und Lizenzdatei im Repository dokumentieren.
- **Größenhierarchie (Ausgangswerte, bei Tests anpassen):** Screen-Titel 30–36 px, Fenstertitel 22–26 px, Untertitel 18–20 px, Fließtext 16–18 px, kompakte Labels mindestens 14 px.
- **Hauptmenü-Titel:** 64 px (eigener Wert, bewusst größer als der Screen-Titel; nur für den Spieltitel im Hauptmenü).
- **Gebietsnamen-Einblendung:** 48 px mit Kontur, darunter Stufenbereich 20 px (eigene Werte; nur für die kurze Einblendung beim Betreten eines Gebiets, die über der 3D-Welt lesbar sein muss).
- Keine allein durch Versalien, geringe Größe oder verzierte Fonts schwer lesbaren Informationstexte.

## 5. Komponentenstandards

Jede Komponente erhält explizite Zustände und eine Vorschau in `game/scenes/ui/style_preview.tscn`.

| Komponente | Verbindliche Zustände / Anforderungen |
|---|---|
| Buttons | normal, Hover, gedrückt, deaktiviert, Tastatur-/Gamepad-Fokus |
| Fenster und Panels | Titel, Inhalt, optional Schließen, konsistente Innenabstände |
| Tooltips | Überschrift, Beschreibung, Werte, Seltenheit, Begrenzung am Bildschirmrand |
| Lebens-/Ressourcenbalken | Farbtoken, Textwert, deutlicher Füllstand, optional Schwellenmarkierungen |
| Zauberleiste | Fortschritt, Zaubername, Unterbrechbarkeit, abgeschlossene/abgebrochene Zustände |
| Aktionsleisten-Slot | Icon, Tastenkürzel, Cooldown, Kosten, verfügbar/nicht verfügbar, Fokus |
| Spieler-/Zielrahmen | Name, Leben, Ressource, Status, Buffs/Debuffs, eindeutige Zielmarkierung |
| Kampftext | Schaden, Krit, Heilung, Verfehlt; klare Priorisierung bei hoher Dichte |
| Gegenstandsqualität | fünf Seltenheitsfarben mit Text oder Symbol als zweitem Signal |
| Auswahlbutton (Toggle) | normal, Hover, ausgewählt (gedrückt, auch Hover+ausgewählt), deaktiviert, Fokus; genau eine Auswahl pro Gruppe (`ButtonGroup`); „ausgewählt“ ist heller und hat einen breiten linken Rand |
| Texteingabefeld mit Fehlermeldung | Feld (leer mit Platzhalter, mit Text, deaktiviert, Fokus) und darunter eine Meldungszeile: Hinweis (`HintText`) oder Fehler (`ErrorText`); die Meldung ist immer ein verständlicher Satz, nie nur eine Farbe; die Zeile hat eine feste Mindesthöhe, damit das Layout beim Wechsel nicht springt |

## 6. Raster, Abstände und Eingabegrößen

- **Basisraster:** 4 px; Standard-Abstandsfolge 4 / 8 / 12 / 16 / 24 / 32 / 48 px (48 px für große Abschnittsabstände, z. B. zwischen Menü-Titel und Buttons).
- **Interaktive Ziele:** nach Möglichkeit mindestens 40×40 logische Pixel; auf Gamepad-Navigation separat prüfen.
- **UI-Safe-Areas:** HUD nicht direkt an Bildschirmkanten platzieren; konfigurierbare Abstände vorsehen.
- **Responsive Verhalten:** Bei 1080p und 1440p testen; lange Namen, lokalisierte Texte und Skalierungsoptionen berücksichtigen.
- **Priorität:** Gesundheit, Zielstatus, Cast und Fähigkeitseinsatz vor dekorativen Elementen.

## 7. Godot-Umsetzung

- Zentrales Theme unter `game/assets/ui/theme.tres`.
- Schriftdateien und zugehörige Lizenzen unter `game/assets/ui/fonts/`.
- Rahmen, Flächen und Balken sind Grafiken aus dem UI-Paket „Stone & Brass“ als `StyleBoxTexture` im Theme (siehe „UI-Grafiken (Stone & Brass)“ unten). `StyleBoxFlat` bleibt nur, wo das Paket bewusst keine Grafik liefert (`DimOverlay`, Reserve-Variationen).
- Keine aus fremden Spielen übernommenen Rahmen. Icons: nur eigene bzw. ordnungsgemäß lizenzierte, siehe Abschnitt „Icons“ unten.
- Theme-Overrides nur, wenn sie als dokumentierte, wiederverwendbare Variation im Theme-System etabliert sind.
- **Keine Farben und Schriften direkt in Gameplay- oder UI-Code hardcoden.**
- Pflicht-Vorschauszene: `game/scenes/ui/style_preview.tscn` mit sämtlichen Komponenten und States.
- Godot-Projektversion und Font-Import vor Übergabe prüfen; Szene im Editor und im laufenden Projekt testen.

### Theme-Aufbau

`game/assets/ui/theme.tres` ist in `game/project.godot` unter `[gui] theme/custom` als projektweites Standard-Theme eingetragen. Szenen setzen kein eigenes Theme und keine `theme_override_*`-Werte, sondern wählen über `theme_type_variation` eine der folgenden Variationen.

**Rahmen und Flächen kommen seit dem UI-Paket aus Grafiken** (`StyleBoxTexture`, Abschnitt „UI-Grafiken (Stone & Brass)“). **Farbwerte im Theme sind weiter Platzhalter** (Schrift Grau/Weiß, Godot-Standardschrift; Lebens-, Ressourcen-, Zauber-, Seltenheits- und Debufffarben tönen jetzt die weißen Grafiken per `modulate_color`). Sie sind keine Tokens; die Tokens in Abschnitt 3 bleiben TBD. Wo die Tabelle unten noch `StyleBoxFlat` beschreibt, gilt für das Aussehen die Grafik laut Abschnitt „UI-Grafiken“; Bedeutung, Größen und Verwendung bleiben. Neue Variationen werden hier eingetragen und in `style_preview.tscn` gezeigt.

| Variation | Basistyp | Wert | Verwendung |
|---|---|---|---|
| `MenuTitle` | `Label` | Schriftgröße 64 px | Spieltitel im Hauptmenü |
| `ScreenTitle` | `Label` | Schriftgröße 36 px | Titel eines Bildschirms |
| `WindowTitle` | `Label` | Schriftgröße 24 px | Fenster- und Abschnittstitel |
| `Subtitle` | `Label` | Schriftgröße 18 px | Untertitel |
| `BodyText` | `Label` | Schriftgröße 16 px | Fließtext |
| `SmallLabel` | `Label` | Schriftgröße 14 px | kompakte Beschriftungen |
| `SmallHintText` | `Label` | Schriftgröße 14 px, gedämpfte Textfarbe (wie `HintText`) | kompakter sekundärer Text, z. B. „Erfordert Stufe 4“ unter einer nicht erlernten Fähigkeit im Zauberbuch (#21) |
| `ScreenMargin` | `MarginContainer` | Rand 32 px auf allen Seiten | Außenrand eines Bildschirms |
| `MenuLayout` | `VBoxContainer` | Abstand 48 px | große Abschnitte, z. B. Titel zu Buttons |
| `ButtonList` | `VBoxContainer` | Abstand 12 px | Button-Listen, Inhaltslisten |
| `ButtonRow` | `HBoxContainer` | Abstand 12 px | Buttons nebeneinander, Spalten eines Bildschirms |
| `InlineRow` | `HBoxContainer` | Abstand 8 px | Angaben in einer Zeile (z. B. Volk und Klasse) |
| `HintText` | `Label` | Schriftgröße 16 px, gedämpfte Textfarbe | sekundärer Text, Hinweise (z. B. „Noch keine Charaktere“) |
| `EnterWorldButton` | `Button` | Schriftgröße 24 px, sonst wie `Button` | großer Hauptbutton eines Bildschirms („Welt betreten“) |
| `ListEntryButton` | `Button` | eigene `StyleBoxFlat` für normal, Hover, ausgewählt (gedrückt, auch Hover+gedrückt), deaktiviert; Fokus wie `Button` | auswählbarer Listeneintrag (Charakterliste). „Ausgewählt“ ist heller und hat einen breiten linken Rand, damit es sich klar von Hover unterscheidet |
| `ListEntryMargin` | `MarginContainer` | Rand 20 px links, 16 px rechts, 12 px oben/unten | Inhalt eines `ListEntryButton` (links breiter wegen des Auswahlrands) |
| `DialogPanel` | `PanelContainer` | `StyleBoxFlat` mit 24 px Innenabstand und 2-px-Rahmen | modale Dialoge (z. B. Charakter löschen) |
| `DimOverlay` | `Panel` | halbtransparente dunkle Fläche ohne Rahmen | Abdunklung hinter modalen Dialogen; fängt Mausklicks ab |
| `ChoiceButton` | `Button` | wie `Button`; gedrückt und Hover+gedrückt nutzen die Ausgewählt-Fläche von `ListEntryButton`, Schrift im ausgewählten Zustand weiß; Icon höchstens 32 px breit (`icon_max_width`, #55) | Auswahlbutton mit `toggle_mode` in einer `ButtonGroup` (Volk, Geschlecht, Klasse in der Charaktererstellung, mit Klassen-Icon links) |
| `ChoiceGrid` | `GridContainer` | Abstand 12 px horizontal und vertikal | Raster aus Auswahlbuttons (z. B. Völker in zwei Spalten) |
| `ErrorText` | `Label` | Schriftgröße 16 px, hellste Textfarbe (Graubox-Platzhalter, bis ein Warn-Token freigegeben ist) | Fehlermeldung unter einem Eingabefeld; ersetzt in derselben Zeile den `HintText` |
| `SlotButton` | `Button` | quadratischer leerer Rahmen ohne Innenabstand: eigene `StyleBoxFlat` für normal, Hover, gedrückt (auch Hover+gedrückt), deaktiviert; Fokus wie `Button` | Aktionsleisten-Slot (48 × 48 px), Taschenplatz (48 × 48 px), Menüleisten-Button und Schließen-Button „X“ eines Fensters (40 × 40 px) |
| `SlotFlash` | `Panel` | halbtransparente helle Fläche ohne Rahmen | kurzes Aufleuchten eines Aktionsslots bei Klick oder Taste (blendet in 0,25 s aus); fängt keine Mausklicks ab |
| `SlotHotkey` | `Label` | Schriftgröße 14 px | Taste unten rechts im Aktionsslot (4 px Abstand zum Rand) |
| `SlotRow` | `HBoxContainer` | Abstand 4 px | Slots einer Aktionsleiste, Menüleiste, Taschenleiste |
| `SlotColumn` | `VBoxContainer` | Abstand 4 px | übereinanderliegende Aktionsleisten; Name und Zusatzzeile eines Zauberbuch-Eintrags; Zeilen eines Fähigkeiten-Tooltips |
| `SpellbookGrid` | `GridContainer` | Abstand 12 px horizontal, 4 px vertikal | Fähigkeiten einer Zauberbuchseite in zwei Spalten (#21) |
| `ZoneBannerTitle` | `Label` | Schriftgröße 48 px, helle Schrift mit 8-px-Kontur in dunkler Konturfarbe | Gebietsname der Einblendung beim Betreten eines Gebiets (#15) |
| `ZoneBannerSubtitle` | `Label` | Schriftgröße 20 px, gedämpft helle Schrift mit 6-px-Kontur | Stufenbereich unter dem Gebietsnamen („Stufe 4–6“); entfällt bei Gebieten ohne Stufenbereich |
| `MapZoneLabel` | `Label` | Schriftgröße 18 px, helle Schrift mit 6-px-Kontur | Gebietsnamen auf der Karte (über dem Kartenbild lesbar, egal welche Bodenfarbe darunter liegt) |
| `LogText` | `Label` | Schriftgröße 16 px, helle Schrift mit 4-px-Kontur in dunkler Konturfarbe | Zeilen im Log-Bereich des HUD (#30, z. B. „Arthas hat die Welt betreten.“), lesbar ohne Hintergrundfläche über der 3D-Welt |
| `StatBonus` | `Label` | Schriftgröße 14 px, **Platzhalter-Grün** (Farbe **OFFEN**, kein Token) | Wert im Charakterfenster, der durch Modifikatoren erhöht ist (#19). Zweites Signal: „Bonus: +…“ im Tooltip |
| `StatMalus` | `Label` | Schriftgröße 14 px, **Platzhalter-Rot** (Farbe **OFFEN**, kein Token) | Wert im Charakterfenster, der durch Modifikatoren verringert ist (#19). Zweites Signal: „Malus: −…“ im Tooltip |
| `UnitFramePanel` | `PanelContainer` | halbtransparente dunkle `StyleBoxFlat`, 1-px-Rahmen, 8 px Innenabstand | Spieler- und Zielrahmen (#31) |
| `UnitPortrait` | `PanelContainer` | mittelgraue Fläche mit 1-px-Rahmen | Platzhalter-Porträt (64 × 64 px) im Rahmen; darin der Anfangsbuchstabe des Namens (`WindowTitle`) |
| `UnitBadge` | `PanelContainer` | dunkle Fläche, heller 1-px-Rahmen, 6 px Innenabstand seitlich | Kennzeichen im Rahmen: „Elite“, „Selten“, „Boss“ (Zielrahmen), „Im Kampf“ (Spielerrahmen); Text `SmallLabel`. **Platzhalter, endgültige Gestaltung OFFEN** (kein Motiv aus anderen Spielen, z. B. kein Drache am Rahmen) |
| `HealthBar` | `ProgressBar` | Hintergrund dunkel mit 1-px-Rahmen, Füllung **Platzhalter-Grün** (**OFFEN**) | Lebensbalken in Rahmen und Namensplaketten |
| `ManaBar`, `RageBar`, `EnergyBar`, `ChiBar` | `ProgressBar` | wie `HealthBar`, Füllung **Platzhalter-Blau, -Rot, -Gelb, -Türkis** (**OFFEN**) | Ressourcenbalken in Ressourcenfarbe; die Variation wird aus der Ressourcen-ID gebildet (`mana` → `ManaBar`) |
| `BarText` | `Label` | Schriftgröße 14 px, helle Schrift mit 4-px-Kontur | Zahl oder Prozent mittig auf einem Balken |
| `NameplatePanel` | `PanelContainer` | ohne Fläche und Rahmen, 4 px / 2 px Innenabstand | Namensplakette (#31) |
| `NameplateTargetPanel` | `PanelContainer` | halbtransparente dunkle Fläche, heller 2-px-Rahmen | Namensplakette des aktuellen Ziels (zusätzlich 15 % größer) |
| `NameplateWarningPanel`, `NameplateTargetWarningPanel` | `PanelContainer` | wie `NameplatePanel` bzw. `NameplateTargetPanel`, aber 3-px-Rahmen in **Platzhalter-Rot** (**OFFEN**) | Tank-Hinweis (#35): Plakette eines Gegners, der gerade jemand anderen angreift; nur sichtbar, wenn die eigene Figur ein Tank ist (dreifache Bedrohung, `tank_bedrohung_faktor`) |
| `ThreatSafe`, `ThreatWarning`, `ThreatAggro` | `Label` | Schriftgröße 14 px mit 4-px-Kontur, **Platzhalter-Grün, -Gelb, -Rot** (**OFFEN**) | Bedrohungsanzeige im Zielrahmen (#35): „Bedrohung 45 %“, „Bedrohung 85 % !“, „Bedrohung 100 % · greift Euch an“ |
| `NameplateColumn` | `VBoxContainer` | Abstand 2 px | Zeilen einer Namensplakette |
| `NameplateText` | `Label` | Schriftgröße 14 px, helle Schrift mit 4-px-Kontur | Name, Stufe und Puppenanzeige auf Namensplaketten (über der 3D-Welt lesbar) |
| `AuraBuff` | `PanelContainer` | dunkle Fläche, heller 1-px-Rahmen, 2 px Innenabstand | Rahmen eines Buff-Symbols (#32) |
| `AuraDebuff` | `PanelContainer` | dunkle Fläche, grauer 2-px-Rahmen | Rahmen eines Debuffs ohne Kategorie (#32) |
| `AuraDebuffMagic`, `AuraDebuffPoison`, `AuraDebuffDisease`, `AuraDebuffCurse`, `AuraDebuffPhysical` | `PanelContainer` | wie `AuraDebuff`, Rahmen in **Platzhalter-Farbe je Kategorie** (**OFFEN**) | Rahmen eines Debuffs nach Kategorie (Magie, Gift, Krankheit, Fluch, körperlich; für späteres Bannen). Zweites Signal: Buff 1 px, Debuff 2 px Rahmen; Art und Kategorie stehen als Text im Tooltip („Debuff · Gift“) |
| `AuraFlow` | `HFlowContainer` | Abstand 4 px waagerecht und senkrecht | Reihe von Aura-Symbolen, bricht bei Bedarf um |
| `AuraText` | `Label` | Schriftgröße 14 px, helle Schrift mit 4-px-Kontur | Kürzel im Aura-Symbol (Platzhalter-Icon), Stapelzahl unten rechts, Restzeit darunter („12 s“, „3 min“) |
| `CombatTextDamage` | `Label` | Schriftgröße 22 px, **Platzhalter-Weiß** mit 5-px-Kontur (**OFFEN**) | Kampftext: Schaden, den ich verursache, über dem Ziel |
| `CombatTextHeal` | `Label` | wie `CombatTextDamage`, **Platzhalter-Grün** (**OFFEN**) | Kampftext: eigene Heilung, mit „+“ |
| `CombatTextTaken` | `Label` | wie `CombatTextDamage`, **Platzhalter-Rot** (**OFFEN**) | Kampftext: erlittener Schaden an der eigenen Figur, mit „−“ |
| `CombatTextInfo` | `Label` | Schriftgröße 18 px, **Platzhalter-Grau** mit 4-px-Kontur (**OFFEN**) | Kampftext: Wörter „Verfehlt“, „Ausgewichen“, „Pariert“, „Immun“ und mit Menge „Geblockt (45)“, „Absorbiert (1.234)“ (#34) |
| `CombatTextCrit` | `Label` | Schriftgröße 30 px, **Platzhalter-Gelb** mit 6-px-Kontur (**OFFEN**) | Kampftext (#34): eigener kritischer Treffer, mit „!“ („2.468!“), springt beim Erscheinen kurz auf (Größe 160 % → 100 % in 0,15 s). Zweites Signal: „!“ und Größe |
| `CombatTextHealCrit` | `Label` | wie `CombatTextCrit`, **Platzhalter-Grün** (**OFFEN**) | Kampftext (#34): eigene kritische Heilung („+1.600!“), springt kurz auf |
| `CombatTextDamagePeriodic` | `Label` | Schriftgröße 16 px, **Platzhalter-Weiß** mit 4-px-Kontur (**OFFEN**) | Kampftext (#34): eigener Schaden über Zeit, kleiner als Direktschaden; nach Schule eingefärbt wie `CombatTextDamage` |
| `CombatTextHealPeriodic` | `Label` | wie `CombatTextDamagePeriodic`, **Platzhalter-Grün** (**OFFEN**) | Kampftext (#34): eigene Heilung über Zeit, mit „+“ |
| `LogTab` | `Button` (über `ChoiceButton`) | wie `ChoiceButton` (gewählt = Fläche „ausgewählt“), Schriftgröße 14 px | Reiter „Allgemein“ und „Kampf“ unter den Zeilen des Log-Bereichs (#34) |
| `CastBarPanel` | `PanelContainer` | dunkle Fläche, 1-px-Rahmen, 4 px / 2 px Innenabstand | Reserve für eine gerahmte Zauberleiste (#33, vorerst ungenutzt) |
| `CastBar` | `ProgressBar` | Hintergrund wie `HealthBar`, Füllung **Platzhalter-Gelb** (**OFFEN**) | Zauberleiste bei Zauberzeit (füllt sich) |
| `CastBarChannel` | `ProgressBar` | wie `CastBar`, Füllung **Platzhalter-Grün** (**OFFEN**) | Zauberleiste beim Kanalisieren (leert sich) |
| `CastBarDone` | `ProgressBar` | wie `CastBar`, Füllung **Platzhalter-Hellgrün** (**OFFEN**) | Zauber fertig (kurz voll, blendet in 0,6 s aus) |
| `CastBarFailed` | `ProgressBar` | wie `CastBar`, Füllung **Platzhalter-Rot** (**OFFEN**) | Zauber unterbrochen, abgebrochen oder fehlgeschlagen; zweites Signal: Text „– Unterbrochen“, „– Abgebrochen“, „– Fehlgeschlagen“ |
| `CastBarText` | `Label` | Schriftgröße 14 px, helle Schrift mit 4-px-Kontur | Name und Restzeit auf der Zauberleiste („Testblitz  1,2 s“) |
| `ErrorMessage` | `Label` | Schriftgröße 20 px, **Platzhalter-Rot** mit 5-px-Kontur (**OFFEN**) | Fehlermeldung oben in der Mitte („Nicht genug Mana.“); die Meldung ist immer ein Satz |
| `SlotCooldownText` | `Label` | Schriftgröße 18 px, helle Schrift mit 5-px-Kontur | Restzeit der Abklingzeit mittig im Aktionsslot („7“, unter 2 s „1,4“) |
| `SlotProcGlow` | `Panel` | ohne Fläche, 3-px-Rahmen in **Platzhalter-Gold** (**OFFEN**) | leuchtender Rand eines Aktionsslots, solange ein Proc die Fähigkeit verfügbar macht oder verstärkt |
| `SlotActive` | `Panel` | leicht aufgehellte Fläche, heller 2-px-Rahmen | aktiver Umschalter, laufender automatischer Angriff, vorgemerkter nächster Schlag; seit #20 auch „gelernt“ an Talenten |
| `TalentPending` | `Panel` | ohne Fläche, 3-px-Rahmen in **Platzhalter-Hellgrün** (**OFFEN**) | Talent mit vorläufiger Änderung im Talentfenster (#20), bis „Übernehmen“ oder „Verwerfen“ |
| `LockedChoiceButton` | `Button` (über `ChoiceButton`) | wie `ChoiceButton`, Schrift und Icon (#55) im Grau deaktivierter Buttons (kein neuer Farbwert) | Reiter einer gesperrten Spezialisierung im Talentfenster (#20): ausgegraut, aber anklickbar, damit Name, Kurzbeschreibung und „Noch nicht entdeckt“ lesbar sind |
| `MenuHintDot` | `Panel` | runder Punkt 10 × 10 px in **Platzhalter-Gold** mit 1-px-Kontur (**OFFEN**) | Hinweis-Punkt oben rechts an einem Menüleisten-Button (#20: „Spezialisierung wählbar“); fängt keine Klicks ab |
| `ItemRarityFrame` | `Panel` | ohne Fläche, weißer 2-px-Rahmen, Ecken 4 px; zur Laufzeit per `self_modulate` in der Seltenheitsfarbe (`RarityColors`) getönt | Rahmen eines Platzes im Taschenfenster ab Ungewöhnlich (#18), seit #29 auch der Ausrüstungsplätze im Charakterfenster; fängt keine Klicks ab |
| `SlotUnusable` | `Panel` | halbtransparente Fläche in **Platzhalter-Rot**, Ecken 4 px, 3 px eingerückt (**OFFEN**) | roter Schleier über dem Icon eines Gegenstands in der Tasche, den der Charakter nicht nutzen kann (Klasse, Rüstungsklasse, Waffentyp, Mindeststufe, Nebenhandwaffe ohne Beidhändigkeit; #29); fängt keine Klicks ab |
| `SlotDropAllowed` | `Panel` | halbtransparente Fläche in **Platzhalter-Grün** mit hellgrünem 2-px-Rahmen, Ecken 4 px (**OFFEN**) | Aufleuchten der passenden Ausrüstungsplätze, solange ein nutzbarer Gegenstand gezogen wird (#29); liegt über dem Seltenheitsrahmen, fängt keine Klicks ab |
| `ItemCount` | `Label` | Schriftgröße 14 px, helle Schrift mit 4-px-Kontur | Stapelzahl unten rechts in einem Platz (ab 2) und Zahl freier Plätze am Rucksack-Symbol (#18) |
| `SlotGrid` | `GridContainer` | Abstand 4 px waagerecht und senkrecht | Plätze einer Tasche im Taschenfenster (6 je Reihe, #18) |
| `CoinGold`, `CoinSilver`, `CoinCopper` | `Panel` | runder Kreis 18 × 18 px in **Platzhalter-Gold, -Silber, -Kupfer** mit 1-px-Kontur (**OFFEN**) | Münzsymbol hinter dem Betrag in der Geldanzeige (#18) |
| `CoinText` | `Label` | Schriftgröße 14 px, dunkle Schrift | Buchstabe auf dem Münzsymbol (G, S, K) als zweites Signal |
| `ExperienceBar` | `ProgressBar` | Hintergrund wie `HealthBar`, Füllung **Platzhalter-Violett** (**OFFEN**), 10 px hoch, ohne Prozenttext | Erfahrungsbalken über den Aktionsleisten (#27); Tooltip „Erfahrung (Stufe 5): 1.250 / 4.000 (31 %)“ |
| `CombatTextExperience` | `Label` | Schriftgröße 22 px, **Platzhalter-Hellviolett** mit 5-px-Kontur (**OFFEN**) | „+120 EP“ über der eigenen Figur (#27), steigt auf wie Kampftext; erscheint auch bei abgeschaltetem Kampftext |
| `LevelUpTitle` | `Label` | Schriftgröße 48 px, **Platzhalter-Hellgold** mit 8-px-Kontur (**OFFEN**) | „Stufe 12 erreicht!“ in der Aufstiegsmeldung (#27) |
| `LevelUpText` | `Label` | Schriftgröße 20 px, helle Schrift mit 6-px-Kontur | Zeilen der Aufstiegsmeldung ohne Klick (gestiegene Werte, weitere Freischaltungen ohne Fenster) |
| `LevelUpLink` | `Button` | Schriftgröße 20 px, **Platzhalter-Hellgold** mit 6-px-Kontur, ohne Fläche; Hover/gedrückt weiße Schrift auf halbtransparent dunkler Fläche (**OFFEN**) | anklickbare Zeilen der Aufstiegsmeldung: „Neue Fähigkeit: …“ (öffnet das Zauberbuch), „Du hast einen Talentpunkt erhalten.“ und „Du kannst jetzt eine Spezialisierung wählen.“ (öffnen das Talentfenster); Tooltip nennt die Aktion („Zauberbuch öffnen“) |

**Basistypen ohne Variation:**

- `Label`: Schriftgröße 16 px (wie `BodyText`).
- `Button`: eigene `StyleBoxFlat` für normal, Hover, gedrückt (auch Hover+gedrückt), deaktiviert und Fokus. Fokus ist ein zusätzlicher heller Rahmen über dem jeweiligen Zustand. Innenabstand 16 px horizontal / 12 px vertikal; damit sind Buttons mit Standardschrift 47 px hoch und erfüllen die **Mindesthöhe von 40 px** aus Abschnitt 6.
- `Panel` und `PanelContainer`: eine `StyleBoxFlat` mit 16 px Innenabstand.
- `TooltipPanel` / `TooltipLabel`: Tooltip mit eigener `StyleBoxFlat` (8 px horizontal / 4 px vertikal Innenabstand, 1-px-Rahmen), Schriftgröße 16 px. Gilt für alle `tooltip_text` im Spiel (z. B. Menüleiste: „Charakter (C)“).
- `MapMarker` (eigener Theme-Typ ohne Basistyp, gelesen von `scripts/ui/map_marker.gd`, das die Symbole selbst zeichnet): Farben `player_color` (eigener Pfeil, hell), `respawn_color` (Wiedereinstiegspunkt, mittelgrau), `outline_color` (Kontur, dunkel); Konstanten `player_size` 28 px, `respawn_size` 22 px, `mate_size` 16 px (Mitspieler, #30), `outline_width` 2 px. Mitspieler sind gefüllte Punkte in ihrer Klassenfarbe (aus den Daten, siehe „Klassenfarben“) mit dunkler Kontur. Zweites Erkennungsmerkmal ist die Form (Pfeil, Kreis mit Kreuz, Punkt) und bei Wiedereinstiegspunkt und Mitspieler ein Tooltip (Ort bzw. Name).
- `UnitColors` (eigener Theme-Typ ohne Basistyp, gelesen von `scripts/ui/unit_colors.gd`, #31): Farben `hostile`, `neutral`, `friendly` (Gesinnung) und `level_trivial`, `level_easy`, `level_even`, `level_hard`, `level_impossible` (Stufenunterschied). Alles **Platzhalter, OFFEN**. Genutzt für Namen und Stufen in Zielrahmen und Namensplaketten (zur Laufzeit gesetzt wie die Klassenfarbe) und für den Bodenkreis unter dem Ziel in der 3D-Welt. Zweites Signal: Die Stufe steht als Zahl da, Feinde haben auf der Plakette einen Lebensbalken, Freunde nur den Namen, und der Tooltip des Zielrahmens nennt Gesinnung und Schwierigkeit als Text („Stufe 10 (sehr schwer) · feindlich“). Seit #27 steht bei Gegnern ab `stufe_totenkopf_ab` (10) Stufen über der eigenen statt der Zahl ein Totenkopf (`UnitColors.SKULL_TEXT`, vorläufig „☠“), im Tooltip „Stufe ??“; Spielfiguren zeigen immer die Zahl. Die Grenzen der Farben stehen in `spielkonstanten.csv` (`stufe_*`); „grau“ gibt keine Erfahrung.
- `LevelUpEffect` (eigener Theme-Typ, gelesen von `scripts/progress/level_up_effect.gd`, #27): Farbe `glow` für den aufsteigenden Lichtschein (durchscheinender Zylinder und Punktlicht) an einer Figur, die eine Stufe aufsteigt; alle Spieler sehen ihn. **Platzhalter, OFFEN**.
- `TalentArrows` (eigener Theme-Typ, gelesen von `scripts/ui/talent_arrows.gd`, #20): Farben `active` (Voraussetzung erfüllt) und `inactive` (nicht erfüllt), Konstante `width` (2 px). Pfeile von einem vorausgesetzten Talent zum abhängigen (tiefere Reihe: von unten nach oben, gleiche Reihe: seitlich). **Platzhalter, OFFEN**. Zweites Signal: Der Tooltip nennt „Erfordert: Name“ bzw. warum ein Punkt gerade nicht geht.
- `CooldownSweep` (eigener Theme-Typ, gelesen von `scripts/ui/cooldown_sweep.gd`, #33): Farbe `sweep` (halbtransparentes Schwarz, **Platzhalter, OFFEN**) für die Uhrzeiger-Abdunklung über einem Aktionsslot.
- `AbilityColors` (eigener Theme-Typ, gelesen von `scripts/ui/combat_colors.gd`, #33): Farben `out_of_range` (Tönung des Slots außer Reichweite, rötlich), `unusable` (#53: Tönung, wenn Waffe, Aura oder Leben des Ziels nicht passen, z. B. Schildschlag ohne Schild oder Hinrichten bei viel Leben; grau), `no_resource` (Tönung ohne genug Ressource, bläulich), `ground_valid`/`ground_invalid` (Kreis des Bodenziels), Konstante `glow_alpha_percent` (Deckkraft des Leuchtens beim Zaubern, 35). Alles **Platzhalter, OFFEN**. Zweites Signal zur Tönung: die Meldung beim Drücken („Außer Reichweite.“, „Nicht genug Mana.“).
- `SchoolColors` (eigener Theme-Typ, gelesen von `scripts/ui/combat_colors.gd`, #33): je Schadensschule (ID aus `schadensschulen.csv`) eine Farbe. Genutzt für Projektile (kleine leuchtende Kugel) und das Leuchten um eine zaubernde Kapsel. **Platzhalter, OFFEN**; fehlt eine Schule, gilt `physisch`.
- `CombatTextSchool` (eigener Theme-Typ, gelesen von `scripts/ui/combat_colors.gd`, #34): Färbung des Kampftexts für eigenen (nicht kritischen) Schaden je Schadensschule: `arkan`, `feuer`, `frost`, `blitz`, `natur`, `chi`. Fehlt eine Schule (physisch, schatten, heilig), bleibt die Farbe von `CombatTextDamage` bzw. `CombatTextDamagePeriodic`. Zur Laufzeit als Farbe des Labels gesetzt (wie die Klassenfarbe). **Platzhalter, OFFEN**. Zweites Signal: Die Schule steht im Kampflog als Text („1.240 Schaden (Feuer)“).
- `RarityColors` (eigener Theme-Typ, gelesen von `scripts/items/item_info.gd`, #18): Farben `poor`, `common`, `uncommon`, `rare`, `epic` (Tokens `rarity/*`). Welche Seltenheit welche Farbe nutzt, steht in `seltenheiten.csv` (Spalte `farbe`). Genutzt für den Namen im Tooltip (zur Laufzeit gesetzt wie die Klassenfarbe) und die Tönung von `ItemRarityFrame`. **Vorläufige Platzhalter, Freigabe OFFEN**. Zweites Signal: Seltenheit als Text im Tooltip.
- `ItemColors` (eigener Theme-Typ, gelesen von `scripts/ui/item_tooltip.gd`, #29): Farben `stat` (Wertungen und Effekte), `origin` (Herkunftstext) und `requirement_missing` (fehlende Voraussetzung). Zur Laufzeit gesetzt wie die Klassenfarbe. **Platzhalter, OFFEN**. Zweites Signal: Text (siehe „Vorläufige Spielfarben (#29)“).
- `LineEdit`: eigene `StyleBoxFlat` für normal und deaktiviert (`read_only`, bei `editable = false`), Fokus wie `Button`. Innenabstand 12 px horizontal / 8 px vertikal, Schriftgröße 16 px, gedämpfte Farbe für Platzhaltertext.

**Mindestbreiten** kann ein Theme nicht festlegen; sie stehen als `custom_minimum_size` in der Szene (Menü-Buttons: 240 px breit, „Welt betreten“ und „Erstellen“: 280 px, Dialog: 480 px, Dialog-Buttons: 160 px, Namensfeld: 320 px, Meldungszeile unter dem Namensfeld: 480 × 44 px für zwei Zeilen; Spielmenü-Buttons: 280 px; HUD siehe unten).

### Basisgröße und Skalierung

Die Basisgröße des Projekts ist **1920 × 1080** (`display/window/size/viewport_width/height`, Stretch-Modus `canvas_items`, Aspect `expand`). Alle Pixelangaben in diesem Dokument sind logische Pixel bei dieser Basisgröße; bei 1440p wird alles mit Faktor 1,33 skaliert. Das Testfenster startet mit 1280 × 720 (`window_width/height_override`), damit zwei Instanzen nebeneinander passen; dort wirkt alles entsprechend kleiner.

### Interface im Spiel (HUD, Ticket #17)

Szene `game/scenes/ui/hud.tscn` mit Teilen in `game/scenes/ui/hud/`. Außenrand `ScreenMargin` (32 px).

| Element | Aufbau | Position |
|---|---|---|
| Aktionsleisten | 2 × 12 `SlotButton`-Slots à 48 × 48 px **ohne Abstand** (`ActionBarRow`, 0 px), jede Leiste in einer festen Hülle `ActionBarShell` 600 × 56 px (Slots bei x = 12, y = 4); Leisten in `SlotColumn`; Leiste 1 unten, Leiste 2 darüber; Inhalt siehe „Zauberbuch und Aktionsleisten (#21)“ | unten mittig |
| Menüleiste | 5 `MenuBarButton` à **40 × 40 px** (Rahmen wie die Taschenplätze, `slot_40_*`) mit Bediensymbolen von 32 px (`interface/menu_character`, `menu_spellbook`, `menu_talents`, `menu_map`, `menu_game`), 2 px Abstand (`MenuBarRow`), **ohne Hülle**, rechtsbündig (208 px breit); Tooltip „Name (Taste)“ bleibt das zweite Signal. Entscheidung des Projektverantwortlichen bei der Designkontrolle zu #69 (ersetzt die 20 × 40-Knöpfe in der 236 × 44-Hülle aus dem Paket; `menu_bar_shell` und `menu_button_20x40_*` liegen ungenutzt bereit) | unten rechts, direkt über der Taschenleiste |
| Taschenleiste | 4 Taschenplätze + Rucksack (Symbol `interface/bag_backpack`) à 48 × 48 px, Rucksack ganz rechts; Taschenplatz 1 direkt neben dem Rucksack. Seit #18 zeigen die Taschenplätze die angelegte Tasche (Icon bzw. Kürzel, Tooltip wie im Taschenfenster mit Hinweis „Ziehen: abnehmen (nur wenn leer)“), leer mit dem Symbol `interface/bag_slot_empty` und Tooltip „Taschenplatz (leer)“; am Rucksack steht unten rechts die Zahl freier Plätze aller Taschen (`ItemCount`), der Tooltip nennt „N von M Plätzen frei“ | unten rechts |
| Fenster | `PanelContainer` mit `WindowTitle`, Schließen-Button „X“ (`SlotButton` 40 × 40 px) und Inhaltsbereich; leer mit `HintText` „Kommt bald“ | siehe unten |
| Spielmenü | `DimOverlay` + `DialogPanel` mit `WindowTitle` und `ButtonList`; nicht belegte Punkte deaktiviert | Bildschirmmitte |
| Spielerrahmen (#31) | `unit_frame.tscn`, feste Rahmengrafik 340 × 90 px (`UnitFramePlayer`, Porträt links), siehe „Spieler- und Zielrahmen“ | oben links |
| Zielrahmen (#31) | dieselbe Szene, nur mit Ziel sichtbar | oben, rechts neben dem Spielerrahmen (12 px Abstand) |
| Namensplaketten (#31) | `unit_nameplate.tscn` je Einheit, unter allen Fenstern | über dem Kopf jeder Einheit |
| Eigene Auren (#32) | `PlayerAuras` (`SlotColumn`) mit zwei `AuraBar` (`AuraFlow`, rechtsbündig): Buffs, darunter Debuffs; Symbole 36 × 36 px | oben rechts, 560 px breit |
| Kampftext (#32) | `CombatTextLayer` über den Namensplaketten, unter allen Fenstern | auf Augenhöhe der Einheit, steigt auf |
| Eigene Zauberleiste (#33) | `cast_bar.tscn` (`PlayerCastBar`), 360 × 22 px, erstes Element der `SlotColumn` der Aktionsleisten | unten mittig, direkt über den Aktionsleisten |
| Erfahrungsbalken (#27) | `ExperienceBar` (`ExperienceBar`), 10 px hoch, so breit wie die Aktionsleisten, zwischen Zauberleiste und Leiste 2 in der `SlotColumn`; Tooltip mit aktueller und benötigter Erfahrung und Prozent; auf der Höchststufe ausgeblendet | unten mittig, direkt über den Aktionsleisten |
| Aufstiegsmeldung (#27) | `level_up_banner.tscn` (`LevelUpBanner`): `LevelUpTitle` („Stufe 12 erreicht!“), darunter je Zeile `LevelUpText` bzw. `LevelUpLink` (gestiegene Werte, neue Fähigkeiten, Talentpunkt, Spezialisierung, weitere Freischaltungen); blendet in 0,3 s ein, bleibt `aufstieg_anzeige_dauer` Sekunden (spielkonstanten.csv, 6 s; länger, solange die Maus auf einem Hinweis steht) und blendet in 1,5 s aus. Nur die Hinweise fangen Mausklicks ab | Bildschirmmitte, Oberkante bei 30 % der Höhe |
| Fehlermeldungen (#33) | `ErrorMessages` (`SlotColumn`, 800 px breit, höchstens 3 Zeilen `ErrorMessage`) | oben mittig, 96 px vom oberen Rand (über der Gebietsnamen-Einblendung) |
| Fenster „Ihr seid gestorben“ (#35) | `death_window.tscn` (`DeathWindow`), siehe „Tod und Wiederbelebung“ | oben mittig, 260 px vom oberen Rand, 440 px breit |

Fenstergrößen und Plätze: Charakter 400 × 520 px und Zauberbuch 480 × 520 px (#21, breiter wegen zwei Spalten mit Namen) links nebeneinander (das Charakterfenster wird mit ausgeklapptem Wertebereich breiter, ca. 640 px; das Zauberbuch rückt dann nach rechts) (feste Reihenfolge, 12 px Abstand, 144 px vom oberen Rand, unter Spieler- und Zielrahmen); Talente 760 × 560 px (#20, vorher 640 × 520 px: breiter für die Buttonreihe und den Baum) mittig im Platz rechts davon; Karte ca. 70 % des Bildschirms mittig; Taschen 360 × 280 px unten rechts über Menü- und Taschenleiste. Bei 16:9 überlappen sich gleichzeitig offene Fenster nicht; die Karte schließt beim Öffnen alle anderen Fenster.

**Charakterfenster (#19):** Inhalt ist `game/scenes/ui/hud/character_panel.tscn` (`CharacterPanel`). Links oben Name (`Subtitle`), darunter „Stufe N · Volk ·“ und die Klasse (`SmallLabel`, Klasse in Klassenfarbe), rechts daneben der Umschalter für den Wertebereich (`SlotButton` 40 × 40 px, „»“ bzw. „«“, Tooltip „Werte anzeigen/ausblenden“). Darunter das Platzhaltermodell (`character_preview.tscn`, 200 × 260 px) zwischen zwei Spalten mit je sechs Ausrüstungsplätzen (`SlotButton` 40 × 40 px in `SlotColumn`; links Helm, Kette, Schulter, Umhang, Brust, Armschienen; rechts Handschuhe, Gürtel, Beine, Schuhe, Ring 1, Ring 2), darunter eine `SlotRow` mit Haupthand, Nebenhand, Fernkampf und eine mit Siegel und Talisman 1–3. Seit #29 sind die Plätze `EquipmentSlot` (`game/scenes/ui/hud/equipment_slot.tscn`, `SlotButton40`): leer das blasse Bild des Platzes mit Tooltip „Name (leer)“, belegt Icon bzw. Kürzel des Gegenstands, ab Ungewöhnlich mit `ItemRarityFrame` (`item_rarity_frame_40`), Tooltip des Gegenstands. Die Nebenhand neben einer Zweihandwaffe ist deaktiviert (Tooltip „Nebenhand (durch Zweihandwaffe belegt)“). Unter „Stufe N · Volk · Klasse“ steht „Gegenstandsstufe: 11,7“ (`SmallLabel`, Durchschnitt der angelegten Gegenstände, leere Plätze zählen nicht; Tooltip mit Erklärung und Liste der angelegten Gegenstände). Gegenstand aus der Tasche auf einen Platz ziehen legt ihn an, angelegten Gegenstand in die Tasche ziehen legt ihn ab; beim Ziehen leuchten passende Plätze auf (`SlotDropAllowed`). Der **Wertebereich** ist standardmäßig eingeklappt und erscheint ausgeklappt rechts im Fenster (280 px breit): Titel „Werte“ (`Subtitle`), Kampfzustand („Im Kampf“ / „Außerhalb des Kampfes“, `SmallLabel`), dann mit Bildlaufleiste die Abschnitte Attribute, Offensive, Defensive, Ressourcen (Überschriften `Subtitle`). Jede Zeile ist eine `InlineRow`: Name (`SmallLabel`) links, Wert rechtsbündig (`SmallLabel`, bei Bonus `StatBonus`, bei Malus `StatMalus`). Leben und Ressourcen stehen als „aktuell / maximal“. Gezeigt werden nur Werte, die für Klasse und Zustände gelten (z. B. Zaubermacht und Mana nur bei Magier und Druide, Blocken nur mit Schild). Der Tooltip jeder Zeile nennt Name, Erklärung, Grundlage (z. B. „Grundlage: Präzision 100“), „Grundwert … + … = …“ bzw. „kein Bonus“, „Bonus: +…“ oder „Malus: −…“, die einzelnen Modifikatoren mit Quelle und gegebenenfalls die Obergrenze. Farbe ist damit nie der einzige Bedeutungsträger.

**Zauberbuch und Aktionsleisten (#21):** Inhalt des Zauberbuchs ist `game/scenes/ui/hud/spellbook_panel.tscn` (`SpellbookPanel`, `ButtonList`). Oben die Reiter als `ChoiceButton` in einer `ButtonRow` („Allgemein“, dann die Klasse; später Unterklassen), darunter je Seite 12 Einträge in zwei Spalten (`SpellbookGrid`), unten bei mehr als 12 Fähigkeiten die Seitenleiste (`InlineRow`, mittig): „‹“ und „›“ als `SlotButton` 40 × 40 px, dazwischen „Seite 1 / 2“ (`BodyText`). Ein Eintrag (`spellbook_entry.tscn`, `InlineRow`) hat links das Icon als `SlotButton` 40 × 40 px und rechts in `SlotColumn` den Namen (`BodyText`, zu lange Namen mit „…“) und darunter klein „Stufe N“ bzw. „Passiv“ (`SmallLabel`). **Nicht erlernt** (Stufe zu niedrig): Icon im Zustand „deaktiviert“, Name `HintText`, darunter „Erfordert Stufe N“ (`SmallHintText`) – der Text ist das zweite Signal neben dem Ausgrauen. **Platzhalter-Icon:** Solange es keine Icons gibt, steht im Slot das Kürzel der Fähigkeit als Buttontext (Anfangsbuchstaben, z. B. „Fe“, „HB“); ein `Texture2D`-Icon aus den Daten ersetzt es später. Belegte **Aktionsslots** zeigen dasselbe Icon bzw. Kürzel, die Taste bleibt unten rechts (`SlotHotkey`); nicht erlernte Fähigkeiten auf der Leiste sind „deaktiviert“ (ausgegraut). Beim **Ziehen** hängt ein `SlotButton` 48 × 48 px mit Icon/Kürzel mittig am Mauszeiger. **Tooltip** einer Fähigkeit (gleich im Zauberbuch und auf der Leiste, im `TooltipPanel`): Name (`Subtitle`), Zeilen als `InlineRow` mit `SmallLabel` links/rechts (Kosten · Reichweite, Zauberart · Abklingzeit, bei Zaubern seit #22 „Schule: Feuer“ als Kennzeichnung der Schadensschule, nur Text ohne eigene Farbe), Beschreibung (`BodyText`, 320 px breit mit Zeilenumbruch), bei nicht erlernten Fähigkeiten „Erfordert Stufe N“ (`HintText`); bei passiven nur Name, „Passiv“ und Beschreibung. **Spielmenü:** Schalter „Aktionsleisten sperren“ als `CheckBox` (280 px, vorerst Godot-Standardaussehen wie im Entwickler-Panel), darunter seit #34 „Kampftext anzeigen“, dann „Zurück zum Spiel“.

**Spezialisierung und Talente (#20):** Inhalt des Talentfensters (N) ist `game/scenes/ui/hud/talent_panel.tscn` (`TalentPanel`, `ButtonList`). Oben je Spezialisierung der Klasse ein Reiter (`ChoiceButton` in `ButtonRow`, die gewählte mit „(gewählt)“; gesperrte als `LockedChoiceButton`, Tooltip mit Kurzbeschreibung und „Noch nicht entdeckt“). Darunter die Punkte (`Subtitle`: „Verfügbare Punkte: 3“ bzw. unter Stufe 10 „Spezialisierung ab Stufe 10“) und Hinweise (`HintText`, z. B. „Die Bäume sind bis dahin nur zur Ansicht.“, „Im Kampf nicht möglich.“, „Vorläufige Änderungen (+1 Punkte): „Übernehmen“ oder „Verwerfen“.“). In der Mitte mit Bildlaufleiste (mindestens 360 px hoch) die Seite der Spezialisierung: Name (`Subtitle`), Beschreibung (`BodyText`), „Bevorzugte Werte: …“ und „Verwandelt: Magisches Geschoss → Feuerball, …“ (`SmallLabel`), dann der Baum: je Reihe eine `ButtonRow` mit Kopf (120 px, „Reihe 1 · Wahl“ als `SmallLabel`, bei gesperrter Reihe darunter „Erfordert 3 Punkte“ als `SmallHintText`) und den Talenten (je 110 px breit: `SlotButton` 48 × 48 px mit Kürzel bzw. Icon, darunter Name und Rang „0/3“ als `SmallLabel`, gesperrt `SmallHintText`); in Wahl-Reihen steht „oder“ (`HintText`) zwischen den Talenten. Gelernte Talente tragen `SlotActive`, vorläufig geänderte zusätzlich `TalentPending`; Talente gesperrter Reihen und solche, die gerade nicht gehen, sind „deaktiviert“ (ein Klick nennt trotzdem den Grund oben in der Mitte). Pfeile für Voraussetzungen zeichnet `TalentArrows` über dem Baum. Darunter die optionale Anzeige einer Klassenerweiterung (`SpecializationExtension.make_panel`). Unten eine `ButtonRow`: „Spezialisierung wählen“ (nur ohne Wahl) bzw. „Übernehmen“, „Verwerfen“, „Talente zurücksetzen“, „Spezialisierung wechseln“ (Standard-`Button`, im Kampf deaktiviert mit Tooltip „Im Kampf nicht möglich.“). Wählen, Zurücksetzen und Wechseln fragen mit dem Hinweis- und Bestätigungsdialog nach. **Tooltip eines Talents** (`TooltipPanel`): Name (`Subtitle`), „Wahl (eins aus der Reihe) · Rang 0/1“ bzw. „Ränge · Rang 1/3“ (`SmallLabel`), Beschreibung (`BodyText`), gegebenenfalls „Erfordert: Name“, Hinweis (`HintText`: „Klick: Punkt vergeben“, „Rechtsklick: Punkt zurücknehmen“ oder der Grund, warum es nicht geht), bei neuen Fähigkeiten „Neue Fähigkeit:“ und deren vollständiger Tooltip. **Hinweis bei Stufe 10:** Steigt die eigene Stufe von unter 10 auf 10 oder mehr ohne Spezialisierung, erscheint der Bestätigungsdialog „Spezialisierung“ / „Du kannst jetzt eine Spezialisierung wählen.“ mit „Später“ und „Talente öffnen“; solange keine gewählt ist, trägt der Menüleisten-Button „T“ den `MenuHintDot`. **Zauberbuch und Leisten:** Seit #20 zeigen Zauberbuch-Einträge, Aktionsslots und Tooltips die Variante der Spezialisierung (Name, Kürzel, Tooltip) und die Zahlen mit Talenten (z. B. „25 Mana“); gespeichert und gezogen wird die Grundfähigkeit. Ein dritter Reiter mit dem Namen der gewählten Spezialisierung listet die Fähigkeiten aus Talenten.

**Taschenfenster (#18, Taste B):** Inhalt des Fensters „Taschen“ ist `game/scenes/ui/hud/inventory_panel.tscn` (`InventoryPanel`, `ButtonList`), ein gemeinsames Fenster für alle Taschen unten rechts über Menü- und Taschenleiste (mindestens 360 × 280 px, wächst nach oben mit dem Inhalt; die Platzliste ist höchstens 540 px hoch, darüber mit Bildlaufleiste). Die Plätze sind nach Tasche gruppiert, Rucksack zuerst, dann Taschenplatz 1–4; jede Gruppe (`SlotColumn`) hat eine Überschrift `SmallLabel` mit Namen und freien Plätzen („Rucksack (7 / 16 frei)“, „Reisetasche (10 / 10 frei)“) und darunter die Plätze in einem `SlotGrid` mit 6 Spalten. **Platz** (`game/scenes/ui/hud/item_slot.tscn`, `ItemSlot`): `SlotButton` 48 × 48 px; leer nur der Rahmen; belegt Icon bzw. Kürzel des Namens (Graubox, z. B. „Wo“ für Wolfsfell, „HB“ für Hartes Brot), Stapelzahl ab 2 unten rechts (`ItemCount`), ab Ungewöhnlich zusätzlich `ItemRarityFrame` in der Seltenheitsfarbe. Unten eine `InlineRow`: links die Geldanzeige (Betrag `SmallLabel` + Münzsymbol, Gold nur ab 1 Gold, Silber ab 1 Silber oder mit Gold, Kupfer immer; Tooltip „Geld: …“), rechts der Button „Sortieren“ (Standard-`Button`, Tooltip mit der Regel). **Tooltip eines Gegenstands** (`TooltipPanel`, `SlotColumn`): Name (`Subtitle`) in der Seltenheitsfarbe, darunter „Seltenheit · Typ“ (`SmallLabel`), bei Taschen „Tasche mit N Plätzen“, Beschreibung (`BodyText`, 280 px breit mit Umbruch), „Stapel: 7 / 20“ bei stapelbaren Gegenständen und „Verkaufswert: 5 Kupfer (Stapel: 35 Kupfer)“ bzw. „Kein Verkaufswert“. **Bedienung:** Ziehen wie bei den Aktionsleisten (Vorschau: `SlotButton` 48 × 48 px am Zeiger); Shift + Klick auf einen Stapel öffnet „Stapel teilen“ (siehe Dialoge); Loslassen außerhalb des Fensters fragt mit dem Bestätigungsdialog „Gegenstand zerstören“ / „X wirklich zerstören?“ („Abbrechen“, „Zerstören“); Rechtsklick legt seit #29 Ausrüstung an (Ringe und Talismane: erster freier Platz, sonst der erste; der bisherige Gegenstand kommt auf den frei gewordenen Platz), andere Gegenstände haben noch keine Funktion. Nicht nutzbare Gegenstände tragen `SlotUnusable`. **Tooltip einer Ausrüstung (#29)** von oben nach unten: Name (`Subtitle`, Seltenheitsfarbe), Seltenheit als Text, Bindung („Wird beim Anlegen gebunden“), „Einzigartig“ / „Einzigartig angelegt“ (alle `SmallLabel`), eine `InlineRow` mit Slot links und Rüstungsklasse bzw. Waffentyp rechts („Brust … Platte“), dann `BodyText`: „12 – 20 Schaden … Tempo 2,6“ und „(6,2 Schaden pro Sekunde)“ bzw. „45 Rüstung“, „35 Blockwert“, Attribute („+12 Stärke“), Wertungen („Anlegen: +8 Präzision“, `ItemColors/stat`), Effekte (Beschreibung der Aura, `ItemColors/stat`), Beschreibung; danach `SmallLabel`: „Benötigt Stufe X“ und „Klassen: …“ (rot über `ItemColors/requirement_missing`, wenn nicht erfüllt), „Gegenstandsstufe N“, Verkaufswert; zuletzt der Herkunftstext in Anführungszeichen (`BodyText`, 280 px mit Umbruch, `ItemColors/origin`). **Vergleich:** In der Tasche steht rechts daneben in einem eigenen `TooltipPanel` der angelegte Gegenstand, der ersetzt würde (bei Ringen und Talismanen alle angelegten), mit der Überschrift „Angelegt“ (`HintText`); am neuen Gegenstand folgt „Beim Anlegen:“ mit den Unterschieden je Wert und beim Schaden pro Sekunde („+5 Stärke“ in `StatBonus`, „−3 Ausdauer“ in `StatMalus`). Meldungen beim Anlegen („Eure Klasse kann das nicht tragen.“, „Benötigt Stufe 25.“, „Im Kampf nicht möglich.“, „Noch nicht bereit.“, „Inventar ist voll.“) erscheinen oben in der Mitte (`ErrorMessage`). Loslassen über dem Charakterfenster zerstört nichts. Meldungen („Inventar ist voll.“, „Die Tasche ist nicht leer.“) erscheinen oben in der Mitte (`ErrorMessage`).

**Fähigkeiten wirken (#33):**
- **Aktionsslot:** Abklingzeit und globaler Cooldown als Uhrzeiger-Abdunklung (`CooldownSweep`, der abgedunkelte Teil schrumpft im Uhrzeigersinn), dazu bei Abklingzeit die Restzeit mittig (`SlotCooldownText`; beim globalen Cooldown ohne Zahl). Außer Reichweite des Ziels ist der ganze Slot rötlich getönt, ohne genug Ressource bläulich (`AbilityColors`, `self_modulate`); Reichweite geht vor. Proc (z. B. „Meteor bereit“): leuchtender Rand (`SlotProcGlow`). Aktiver Umschalter, laufender automatischer Angriff oder vorgemerkter nächster Schlag: heller Rahmen (`SlotActive`). Aufladungen: Zahl unten links (`SlotHotkey`). Die Taste bleibt unten rechts.
- **Zauberleiste** (`game/scenes/ui/hud/cast_bar.tscn`, `CastBar`): `InlineRow` mit optionalem Kennzeichen „Schild“ (`UnitBadge` + `SmallLabel`) für nicht unterbrechbare Zauber und der Leiste (`CastBar`/`CastBarChannel`) mit Text (`CastBarText`, Name und Restzeit, zu lang mit „…“). Am Ende kurz voll in `CastBarDone` bzw. `CastBarFailed` mit Text „– Unterbrochen“ usw., dann 0,6 s ausblenden. Das Wort „Schild“ steht für das spätere Schild-Symbol, solange es keine Icons gibt. **Eigene Leiste:** unten mittig über den Aktionsleisten (360 × 22 px). **Ziel:** im Zielrahmen unter den Balken (18 px hoch, volle Breite). **Namensplakette:** unter Name und Leben (14 px hoch, ohne Restzeit).
- **Fehlermeldungen:** oben mittig, `ErrorMessage`, neueste unten, höchstens drei; jede bleibt 2 s und blendet in 0,5 s aus (`fehlermeldung_dauer`); dieselbe Meldung höchstens einmal je Sekunde (`fehlermeldung_abstand`). Klang **OFFEN** (`ErrorSound`, ohne Datei still).
- **3D-Platzhalter:** Projektil = kleine leuchtende Kugel in Schulfarbe; zaubernde Einheiten bekommen eine halbtransparente Hülle in Schulfarbe; Bodenziel = flacher Ring am Mauszeiger (Radius der Fähigkeit), außer Reichweite in `ground_invalid`. Farben aus dem Theme (`SchoolColors`, `AbilityColors`), nicht aus dem Code.

**Gebietsnamen-Einblendung (#15):** `game/scenes/ui/hud/zone_banner.tscn`, Teil von `hud.tscn`. Oben mittig, 160 px vom oberen Rand: Gebietsname (`ZoneBannerTitle`), darunter Stufenbereich (`ZoneBannerSubtitle`). Blendet in 0,5 s ein, bleibt 2,5 s und blendet in 1,5 s aus (Deckkraft, keine Farbänderung). Fängt keine Mausklicks ab.

**Karte (#15):** Inhalt des Kartenfensters ist `game/scenes/ui/hud/map_view.tscn`: quadratisches Kartenbild (von oben gerendert, Norden oben), mittig im Fenster, darüber Gebietsnamen (`MapZoneLabel`), Wiedereinstiegspunkte und eigene Position (`MapMarker`). Der Fenstertitel nennt das aktuelle Gebiet („Karte – Wolfswiese“). Ohne Grafikausgabe steht statt des Bilds der `HintText` „Kartenbild nicht verfügbar“. Mitspieler (#30) erscheinen als Punkte in Klassenfarbe (`MapMarker`, `mate_size`) mit ihrem Namen als Tooltip.

**Entwickler-Panel (#15, nur Debug-Builds):** `game/scenes/ui/dev/dev_panel.tscn`, F10. `PanelContainer` 360 px breit am rechten Rand (128 px von oben, 200 px Abstand unten), Titel `WindowTitle`, Abschnittsüberschriften `Subtitle`, Einträge in `ButtonList` (Standard-`Button`, `CheckBox` und `HSlider` mit Godot-Standardaussehen, Infozeilen `SmallLabel`), bei Bedarf mit Bildlaufleiste. Werkzeug für Entwickler, kein Teil des Spiel-Interfaces; spätere Tickets (#19) ergänzen eigene Abschnitte. Abschnitt „Netzwerk“ (#30): Infozeile „Künstliche Verzögerung: 150 ms“ und darunter ein Schieberegler 0–300 ms in 10-ms-Schritten. Abschnitt „Daten“ (#39): Button „Tabellen neu laden (F6)“; das Ergebnis bzw. die ersten Fehler erscheinen im Log-Bereich. Abschnitt „Werte“ (#19): Infozeilen mit Leben, Kampfzustand (seit #32 nur Anzeige, der Schalter „Im Kampf“ entfällt) und Ressourcen, Schalter „Nahkampfwaffe getragen“, „Schild getragen“, Stufenregler (nur diese Sitzung), Buttons für Schaden nehmen/austeilen, Ressource verbrauchen, Chi aufbauen und Auffüllen, darunter je Testmodifikator ein Schalter (z. B. „+50 Stärke“). Abschnitt „Fähigkeiten“ (#21): Buttons „Alle Fähigkeiten der Klasse erlernen“ und „Aktionsleisten zurücksetzen“, seit #33 „Testfähigkeiten erlernen“ und „Abklingzeiten zurücksetzen“. Abschnitt „Werte“ seit #33 zusätzlich mit den Schaltern „Nebenhandwaffe (beidhändig)“ und „Fernkampfwaffe getragen“; Abschnitt „Einheiten“ mit „Ziel zaubert: unterbrechbar“, „Ziel zaubert: nicht unterbrechbar“, „Ziel zaubert nicht mehr“. Abschnitt „Einheiten“ (#31): Infozeilen zum aktuellen Ziel (Name, Stufe, Gesinnung, Leben, Entfernung, Sichtlinie, „vor mir“/„hinter dem Ziel“), Buttons „Ziel: Schaden (10 % Leben)“, „Ziel: Treffer (1.000 Schaden)“, „Ziel: Heilung (10 % Leben)“, „Ziel: Leben und Ressourcen auffüllen“, Schalter „Ziel: Dauerschaden“ (der Schalter „Ziel: im Kampf“ entfällt mit #32), Regler „Stufe des Ziels“ und je Rang ein Button (nur Übungspuppen). Abschnitt „Auren“ (#32): Infozeilen zu Ziel und eigener Figur (Kampfzustand, Zustände, Immunitäten, jede Aura mit Stapeln, Restzeit, Wirker, Schild; veränderte Fähigkeiten; Bedrohung), Schalter „Auf mich selbst statt aufs Ziel“, darunter die Testeffekte und Testauren aus `game/data/combat/dev_tools.tres` als Buttons mit Zwischenüberschriften (`SmallLabel`: Effekte, Bewegung, Bedingungen und Skalierung, Auren), Buttons „Ereignis: …“ (kritischer Treffer, Ausgewichen, Pariert, Geblockt, Fähigkeit gewirkt) und „Alle Auren entfernen“. Seit #34 lösen echte Treffer diese Ereignisse selbst aus (die Buttons bleiben zum gezielten Testen von Auslösern); unter „Auren“ zusätzlich „Schadensmodifikator: Feuermacht (+25 % Feuer)“ und „Heilmodifikator: Heilempfang (+50 % erhaltene Heilung)“. Abschnitt „Talente“ (#20): Infozeilen (Spezialisierung, Punkte, gelernte Talente mit Rang, freigeschaltete Spezialisierungen, auf dem Host die Quellen der Wirkung und Talent-Auren), Buttons „Gesperrte Spezialisierungen entsperren“, „Talentpunkte geben (+1)“, „Talentpunkte geben (+5)“, „Spezialisierung zurücksetzen“ und ein Hinweis, dass die Stufe im Abschnitt „Werte“ geändert wird. Abschnitt „Inventar“ (#18): Infozeilen (freie Plätze, Geld, wie oft gespeichert wurde), Auswahlliste aller Gegenstände (`OptionButton`, „Name (id)“), darunter in einer `InlineRow` die Anzahl (`SpinBox`) und „Hinzufügen“, Buttons „Alle Testgegenstände hinzufügen“, „Geld: +1 Gold“, „Geld: +1 Silber“, „Geld: +10 Kupfer“, „Geld auf 0 setzen“, „Inventar leeren“ (Godot-Standardaussehen wie die übrigen Werkzeuge).

**Log-Bereich (#30):** `game/scenes/ui/hud/message_log.tscn`, Teil von `hud.tscn`. Unten links (32 px vom linken und unteren Rand), 480 px breit, ohne Hintergrundfläche; Zeilen `LogText`, neueste unten, höchstens 8 Zeilen. Jede Zeile bleibt 20 s sichtbar und blendet in 2 s aus (Deckkraft). Die Zeilen fangen keine Mausklicks ab. Später schreibt hier auch der Chat. **Reiter (#34):** Unter den Zeilen eine Reihe (`InlineRow`) mit den Reitern „Allgemein“ und „Kampf“ (`LogTab`, nur sie nehmen Klicks an); immer genau einer ist gewählt, Start „Allgemein“. Jeder Reiter hat eigene Zeilen (höchstens 8, gleiches Ausblenden). „Kampf“ ist der **Kampflog**: alle Kampfereignisse, an denen die eigene Figur beteiligt ist, je Zeile mit Uhrzeit, Quelle, Fähigkeit, Ziel, Ergebnis und Menge, z. B. „14:03:12 Arthas: Feuerball trifft Schadenspuppe kritisch: 1.240 Schaden (Feuer)“, „… – Bosspuppe pariert“, „…: 300 Schaden (Physisch), 45 geblockt“, „Arthas: Verjüngung (über Zeit) heilt Heilpuppe: 100, 30 Überheilung“. Der Kampflog läuft auch, wenn der Kampftext ausgeschaltet ist.

**Spielerliste (#30):** `game/scenes/ui/hud/player_list.tscn`, sichtbar solange O gehalten wird (Aktion `player_list`). `PanelContainer` 560 px breit, oben mittig 128 px vom oberen Rand. Titel `WindowTitle` („Spieler (2 / 5)“), darunter ein Raster mit fünf Spalten (`ChoiceGrid`-Abstände): Überschriften `HintText` (Name, Stufe, Klasse, Ping), Zeilen `BodyText`; die Klasse steht in Klassenfarbe, der Host ist mit dem Wort „Host“ gekennzeichnet (nicht nur über die Farbe), sein Ping als „–“. Fängt keine Mausklicks ab.

**Netzwerk-Overlay (#30):** `game/scenes/ui/hud/net_overlay.tscn`, F9 (Aktion `toggle_net_overlay`; bis #31 F3, F1–F5 gehören jetzt der Zielauswahl). `PanelContainer` 360 px breit oben rechts (32 px vom Rand), drei Zeilen `SmallLabel`: Peer-ID und Host ja/nein, Ping und Spielerzahl, gesendete und empfangene KB/s. Endet oberhalb des Entwickler-Panels (128 px), damit beide gleichzeitig offen sein können. Werkzeug, kein Teil des Spiel-Interfaces.

**Spieler- und Zielrahmen (#31):** `game/scenes/ui/hud/unit_frame.tscn` (`UnitFrame`), Teil von `hud.tscn`, in einer `ButtonRow` oben links. `UnitFramePanel`, 340 px breit; links das Porträt (`UnitPortrait` 64 × 64 px, Anfangsbuchstabe als `WindowTitle`), rechts in `SlotColumn`: Kopfzeile (`InlineRow`) mit Name (`BodyText`, zu lang mit „…“), Kennzeichen (`UnitBadge`) und Stufe (`SmallLabel`), darunter Lebensbalken (`HealthBar`, 22 px hoch), Ressourcenbalken (`ManaBar` usw., 18 px hoch; entfällt bei Einheiten ohne Ressource) und beim Spieler klein eine Zweitressource (8 px, ohne Text, Tooltip „Chi: 25 / 100“; Chi beim Mönch, später Mana beim Druiden in Gestalt). Texte auf den Balken `BarText`. **Spielerrahmen:** Leben als „1.250 / 2.000“, Ressource „415 / 415“, Kennzeichen „Im Kampf“ (Text statt Symbol, solange es keine Icons gibt); Klick auf den Rahmen wählt sich selbst. **Zielrahmen:** nur sichtbar, solange ein Ziel gewählt ist; Name in der Farbe der Gesinnung, Stufe in der Farbe des Stufenunterschieds (`UnitColors`), Leben in Prozent („63 %“), Kennzeichen „Elite“, „Selten“ oder „Boss“; Tooltip mit Name, Stufe, Schwierigkeit und Gesinnung als Text. Leere, unsichtbare Plätze sind angelegt für Last (Eisenmönch) bzw. Combopunkte; die Zauberleiste des Ziels steht seit #33 unter den Balken (siehe „Fähigkeiten wirken“). **Auren des Ziels (#32):** unter den Balken eine `AuraBar` (`AuraFlow`, höchstens 16 Symbole), nur sichtbar, wenn das Ziel Auren hat: zuerst die eigenen Debuffs (32 × 32 px), dann übrige Debuffs und Buffs (24 × 24 px), jeweils mit Restzeit darunter und Tooltip. Der Spielerrahmen zeigt keine Auren (die eigenen stehen oben rechts). **Bedrohung (#35):** Steht man auf der Bedrohungsliste des Ziels, steht rechts in der Kopfzeile des Zielrahmens die eigene Bedrohung in Prozent der Bedrohung, die zum Zielwechsel nötig wäre (`ThreatSafe`/`ThreatWarning`/`ThreatAggro`, Tooltip erklärt den Wert); sonst ist der Platz leer.

**Aura-Symbole (#32):** `game/scenes/ui/hud/aura_icon.tscn` (`AuraIcon`). Quadratischer Rahmen (`AuraBuff` bzw. `AuraDebuff*` nach Kategorie), darin das Icon der Aura bzw. bis es Icons gibt das Kürzel des Namens (`AuraText`, z. B. „Sc“, „OW“), unten rechts die Stapelzahl ab 2, darunter die Restzeit (`AuraText`; dauerhafte Auren ohne Zeit). Tooltip: Name, Art und Kategorie als Text („Debuff · Magie“), Beschreibung, „Noch 12 s“, Stapel, Schild, verzögerter Schaden und bei eigenen beendbaren Buffs „Rechtsklick: beenden“. **Eigene Auren oben rechts:** Buffs in einer Reihe, Debuffs darunter, rechtsbündig, je 36 × 36 px; Rechtsklick auf einen eigenen Buff beendet ihn (wenn die Aura es erlaubt). Liegt das Netzwerk-Overlay (F9) oder das Entwickler-Panel (F10) offen, überdecken diese Werkzeuge die Auren teilweise. Versteckte Auren (z. B. passive Volksfähigkeiten) erscheinen nirgends.

**Kampftext (#32, vollständig seit #34):** `CombatTextLayer` im HUD. Jede Zahl erscheint auf Augenhöhe der Einheit, leicht seitlich versetzt, steigt in 1,5 s um 60 px auf (`kampftext_dauer`, `kampftext_steigen` in `spielkonstanten.csv`) und blendet dabei aus (Deckkraft). Schaden, den ich verursache: über dem Ziel (`CombatTextDamage`, „1.234“), nach Schule eingefärbt (`CombatTextSchool`). Eigener kritischer Treffer: `CombatTextCrit` mit „!“, springt kurz auf. Schaden über Zeit: kleiner (`CombatTextDamagePeriodic`). Eigene Heilung: über dem Geheilten (`CombatTextHeal`, „+1.234“; kritisch `CombatTextHealCrit` „+2.468!“; über Zeit `CombatTextHealPeriodic`). Erlittener Schaden: an der eigenen Figur (`CombatTextTaken`, „−1.234“, kritisch mit „!“ und Aufspringen). Wörter (`CombatTextInfo`): „Verfehlt“, „Ausgewichen“, „Pariert“, „Immun“ sowie „Geblockt (45)“ und „Absorbiert (1.234)“ – über dem Ziel, wenn ich angreife, an der eigenen Figur, wenn ich angegriffen werde. Zahlen über 10.000 werden abgekürzt („12,3 Tsd.“, ab 100 Tsd. ohne Komma „123 Tsd.“, ab einer Million „1,2 Mio.“; Grenze `kampftext_abkuerzen_ab`). Vorzeichen, „!“ und Wörter sind das zweite Signal neben der Farbe. Jeder Spieler sieht nur seine eigenen Zahlen. **Spielmenü:** Schalter „Kampftext anzeigen“ (`CheckBox`, 280 px, direkt unter „Aktionsleisten sperren“, Standard an, gespeichert in `user://settings.cfg`).

**Namensplaketten (#31, ersetzt die `Label3D`-Plakette aus #30):** `game/scenes/ui/hud/unit_nameplate.tscn`, gezeichnet vom `NameplateLayer` im HUD (unter allen Fenstern) und je Bild über den Kopf der Einheit gesetzt (0,4 m über dem Kopf, projiziert). Sichtbar bis 40 m (`plaketten_reichweite`); die eigene Figur hat keine. **Feinde und Neutrale:** Name (`NameplateText`, Farbe der Gesinnung), darunter Stufe (Farbe des Stufenunterschieds) und Lebensbalken (`HealthBar`, 120 × 8 px). **Freunde und Mitspieler:** nur der Name, Mitspieler in Klassenfarbe. **Ziel:** `NameplateTargetPanel` und 15 % größer, liegt über den anderen. V blendet die Plaketten von Feinden und Neutralen aus und ein, Shift + V die von Freunden (gespeichert in den Einstellungen). Über Übungspuppen steht zusätzlich zweizeilig die Anzeige („Schaden pro Sekunde: 120“ / „Gesamt: 3.400“ bzw. Heilung pro Sekunde und Überheilung, `NameplateText`); sie bleibt auch bei ausgeblendeten Plaketten sichtbar. Klick auf eine Plakette wählt die Einheit (rechts: wählen und angreifen). **Eigene Debuffs (#32):** Über der Plakette feindlicher und neutraler Einheiten stehen die Debuffs, die ich angewendet habe, als kleine Aura-Symbole (20 × 20 px, ohne Restzeit und Tooltip, höchstens 8, mittig). Getarnte Feinde haben keine Plakette. **Tank-Hinweis (#35):** Ist die eigene Figur ein Tank, bekommen Plaketten von Gegnern, die gerade einen anderen Spieler angreifen, `NameplateWarningPanel` bzw. als Ziel `NameplateTargetWarningPanel`. Über Angriffspuppen steht in der Anzeige eine dritte Zeile „Greift an: Name“. **Tote Einheiten** kippen als Platzhalter nach hinten um (Modell um 90° gedreht).

**Bodenkreis unter dem Ziel (#31):** flacher Ring (`TorusMesh`, unbeleuchtet) etwas größer als der Körper des Ziels, in der Farbe der Gesinnung aus `UnitColors`. Erzeugt von `Targeting` (scripts/units/targeting.gd); die Farbe kommt aus dem Theme, nicht aus dem Code.

### Dialoge (#30, #39)

- **Verbindungsdialog** (`game/scenes/ui/connect_dialog.tscn`) nach „Welt betreten“: wie der Löschdialog `DimOverlay` + `DialogPanel` (480 px), Titel `WindowTitle` („Spiel hosten“ / „Spiel beitreten“), Hinweis `HintText` (beim Hosten zur Portfreigabe im Router), Felder IP-Adresse und Port als `LineEdit` mit Beschriftung `BodyText` in einem zweispaltigen Raster (`ChoiceGrid`), darunter eine Meldungszeile (432 × 44 px): Fehler als `ErrorText`, Status („Verbinde mit … “) als `BodyText`. Buttons rechts (`ButtonRow`, 160 px): „Abbrechen“, „Starten“ bzw. „Verbinden“. Während des Verbindens sind die Felder gesperrt und nur „Abbrechen“ ist zu sehen.
- **Fenster „Ihr seid gestorben“** (#35, `game/scenes/ui/hud/death_window.tscn`, Teil von `hud.tscn`): `DialogPanel` ohne `DimOverlay` (die Welt bleibt sichtbar), 440 px breit, oben mittig. Titel `WindowTitle`, darunter ein Hinweis `HintText` („Warten auf Hilfe: Ein Mitspieler kann Euch aufhelfen.“, „Niemand kann Euch gerade aufhelfen.“ bzw. bei „alle tot“ der Countdown), bei einer Anfrage `BodyText` „X möchte Euch aufhelfen.“ mit den Buttons „Annehmen“ und „Ablehnen“ in einer `ButtonRow`, unten der Button „Am Wiedereinstiegspunkt erscheinen“. Sichtbar, solange die eigene Figur tot ist; Esc schließt es nicht. Der Fortschritt beim Aufhelfen ist die normale Zauberleiste („Aufhelfen“) des Helfenden – eigene unten mittig, für alle anderen an seiner Namensplakette.
- **Hinweis- und Bestätigungsdialog** (`game/scenes/ui/message_dialog.tscn`): gleicher Aufbau mit Titel, Text `BodyText` und einem („OK“) oder zwei Buttons. Verwendet für „Der Host hat die Sitzung beendet“ im Hauptmenü und die Rückfrage des Hosts im Spielmenü; seit #20 auch im Spiel (`Hud.ask`) für „Spezialisierung wählen“, „Talente zurücksetzen“, „Spezialisierung wechseln“ und bis #27 den Hinweis bei Stufe 10 (seit #27 eine Zeile der Aufstiegsmeldung, damit sich Dialog und Meldung nicht überdecken).
- **Stapel teilen** (#18, `scripts/ui/split_stack_dialog.gd`, im Code erzeugt): gleicher Aufbau wie der Hinweisdialog (`DimOverlay` + `DialogPanel`), aber 360 px breit: Titel `WindowTitle` („Stapel teilen“), Frage `BodyText` („Wie viele „Wolfsfell“ abteilen? (1–19)“), `SpinBox` mit der Anzahl (Start: halber Stapel), Buttons rechts „Abbrechen“ und „Teilen“; Enter im Zahlenfeld bestätigt, Esc bricht ab. Der abgeteilte Stapel kommt in den ersten freien Platz.
- **Gegenstand zerstören** (#18): Bestätigungsdialog (`Hud.ask`) mit „Gegenstand zerstören“ / „Wolfsfell (7) wirklich zerstören?“ und den Buttons „Abbrechen“, „Zerstören“; gilt auch für Questgegenstände.
- **Fehlerliste der Datentabellen** (#39, `game/scenes/ui/data_error_screen.tscn`): erscheint im Hauptmenü statt des Spiels, wenn die Tabellen beim Start Fehler enthalten. Gleicher Aufbau wie die Dialoge (`DimOverlay` + `DialogPanel`), aber 960 × 640 px: Titel `WindowTitle` („Fehler in den Spieldaten“), darunter Anzahl und Anleitung als `HintText`, dann eine Liste mit Bildlaufleiste, ein Fehler pro Zeile als `BodyText` (Datei, Zeile, Spalte, Grund – immer als Text, nie nur über Farbe). Buttons rechts (`ButtonRow`, 160 px): „Beenden“, „Neu laden“. Esc schließt die Liste nicht; sie verschwindet erst, wenn die Tabellen fehlerfrei neu geladen sind. Werkzeug für die Datenpflege, keine neue Theme-Variation.

**Klassenfarben (vorläufig):** Solange die Tokens `class/*` in Abschnitt 3 TBD sind, steht die Klassenfarbe als vorläufiger Wert in den Klassendaten (`ClassData.color` in `game/data/classes/*.tres`) und wird zur Laufzeit auf den Klassennamen gesetzt. Das ist die einzige Farbe, die nicht aus dem Theme kommt, weil sie aus Daten stammt. Nach Freigabe der Tokens werden die Werte in den `.tres`-Dateien durch die Token-Werte ersetzt. Dieselbe Farbe färbt in der Charakterauswahl und -erstellung auch das Platzhaltermodell (Kapsel) in der 3D-Vorschau, im Spiel die Kapsel jeder Spielfigur, den Namen auf ihrer Namensplakette (#31: HUD-Plakette), die Klasse in der Spielerliste und den Mitspieler-Punkt auf der Karte (#30). Der Klassenname steht immer zusätzlich als Text da (Farbe nie als einziger Bedeutungsträger).

### UI-Grafiken (Stone & Brass)

Grafikpaket des Projektverantwortlichen (v3, 27.11.2026). Größen, 9-Slice-Ränder und Hotspots stehen in `docs/ui-assets/asset_manifest.json` (bzw. `.csv`), die Zuordnung deutsche ID → englische Datei in `docs/ui-assets/german_to_english_icon_ids.csv`.

**Ordner unter `game/assets/ui/`:** `frames/` (9-Slice-Rahmen, Slots, Hüllen, Einheitenrahmen, Aura-Rahmen, Zustände), `bars/` (Hintergrund + weiße Füllung je Balken), `icons/` (siehe „Icons“), `cursors/` (32 und 48 px), `branding/` (App-Symbol `.ico` + 512 px, Startbild, Hauptmenü-Hintergrund, vorläufige Wortmarke), `overlays/` (Banner für Aufstieg und seltene Beute, noch nicht eingebunden), `portraits/` (Silhouetten, **Konzept/OFFEN**, nicht eingebunden), `world/` (Zielkreis und Bodenziel 256 px, weiß, noch nicht eingebunden). Quellen: `art-source/UI/svg/` (Nicht-Icons), `art-source/UI/png-icon-sheets/` (Icon-Quellbögen); alte SVG-Icon-Entwürfe werden nicht verwendet.

**9-Slice-Regeln:** Jede Fläche ist eine `StyleBoxTexture` mit den Texturrändern aus dem Manifest (links, oben, rechts, unten); Ecken werden nie gestreckt. Innenabstand (Content Margins) ist davon getrennt. Feste Grafiken (`fixed`: Aktionsleisten- und Menüleisten-Hülle, Einheitenrahmen, Häkchen, Menüknöpfe) werden **nie** gedehnt; der Knoten hat genau ihre Größe. Weiße Grafiken (Balkenfüllungen, Debuff-Rahmen, Seltenheitsrahmen, `talent_pending`) werden zur Laufzeit bzw. im Theme getönt (`modulate_color` bzw. `self_modulate`), die Farbe kommt aus dem Theme. Fokus-Grafiken (`*_focus`) sind Rahmen über dem jeweiligen Zustand (`draw_center = false`), nie eine dauerhafte Fläche.

| Variation / Theme-Typ | Grafik | Texturränder | Innenabstand |
|---|---|---|---|
| `Panel`, `PanelContainer` (allgemein) | `frames/tooltip_panel` | 7 | 16 |
| `WindowPanel` (neu, HUD-Fenster) | `frames/window_panel` (Titelzone oben) | 18 / 35 / 18 / 18 | 16, oben 3 (Titel in der Titelzone) |
| `DialogPanel` | `frames/dialog_panel` (Titelzone oben) | 22 / 42 / 22 / 22 | 24, oben 6 |
| `TooltipPanel` | `frames/tooltip_panel` | 7 | 8 / 4 |
| `PanelTitle` (neu, `Label`) | – | – | Schriftgröße 18 px; Titel in der Titelzone von `WindowPanel` und `DialogPanel` (die Zone ist rund 20 px hoch, deshalb nicht `WindowTitle`) |
| `Button` | `frames/button_normal/hover/pressed/disabled`, Fokus `button_focus` | 8 | 16 / 12 |
| `EnterWorldButton` | `frames/enter_world_button_*` | 12 | 16 / 12 |
| `ListEntryButton` | `frames/list_entry_*` (gedrückt = `selected`) | 8 / 6 | 16 / 12 |
| `ChoiceButton`, `LockedChoiceButton` | `frames/choice_button_*`, `frames/locked_choice_button_*` | 8 / 7 | 16 / 12 |
| `LogTab` | `frames/log_tab_*` | 8 / 6 | 12 / 6 |
| `LineEdit` | `frames/input_field_normal/focus/disabled` | 7 | 12 / 8 |
| `CheckBox` | `frames/checkbox_on/off/disabled` (24 px, fest) | – | – |
| `VScrollBar` | `frames/scroll_track`, `scroll_thumb_normal/hover/dragged` | 5 / 8 bzw. 4 / 7 | 4 |
| `SlotButton` (48 px) | `frames/slot_48_*`, Fokus `slot_48_focus` | 5 | 2 |
| `SlotButton40` (neu, 40 px) | `frames/slot_40_*` | 5 | 2 |
| `MenuBarButton` (neu, 40 × 40 px) | `frames/slot_40_*`, Fokus `slot_40_focus` | 5 | 4 (Symbol 32 px) |
| `MenuBarRow` (neu) | – (keine Hülle) | – | Abstand 2 px |
| `ActionBarShell`, `ActionBarRow` (neu) | `frames/action_bar_shell` (600 × 56, fest) | – | 12 / 4; Abstand 0 px |
| `IconButton` (neu, `Button`) | keine Fläche; das Icon (mit eigenem Steinhintergrund) ist der Knopf; Hover über Icon-Tönung | – | – |
| `SlotFlash`, `SlotActive`, `SlotProcGlow` | `frames/slot_flash`, `slot_active`, `slot_proc_glow_00…07` (64 px, 8 Bilder à 0,1 s als `AnimatedTexture`, 8 px Überstand) | 0 / 5 / 0 | – |
| `TalentPending`, `ItemRarityFrame` | `frames/talent_pending`, `item_rarity_frame_40` (weiß, getönt) | 5 | – |
| `HealthBar`, `ManaBar`, `RageBar`, `EnergyBar`, `ChiBar` | `bars/health_*` (22 px), `bars/resource_*` (18 px), weiße Füllung getönt | 5 / 4 | – |
| `ManaSecondaryBar`, `RageSecondaryBar`, `EnergySecondaryBar`, `ChiSecondaryBar` (neu) | `bars/secondary_resource_*` (8 px) | 2 | Zweitressource im Spielerrahmen (`<Ressource>SecondaryBar`) |
| `NameplateHealthBar` (neu) | `bars/health_nameplate_*` (8 px) | 2 | Lebensbalken der Namensplaketten |
| `CastBar`, `CastBarChannel`, `CastBarDone`, `CastBarFailed` | `bars/cast_player_*` | 5 / 4 | – |
| `ExperienceBar` | `bars/experience_*` (10 px) | 3 | – |
| `UnitFramePanel` | keine Fläche (`StyleBoxEmpty`) | – | 0 |
| `UnitFramePlayer`, `UnitFrameTarget` (neu, `Panel`) | `frames/unit_frame_player`, `unit_frame_target` (340 × 90, fest, gespiegelt) | – | – |
| `UnitPortrait` | keine Fläche (der Kreis ist Teil der Rahmengrafik) | – | – |
| `UnitBadge` | `frames/unit_badge` | 6 / 4 | 6 / 0 |
| `UnitFrameIcons` (neu, Theme-Typ) | Icons `rank_elite`, `rank_rare`, `rank_boss` | – | – |
| `NameplatePanel`, `NameplateTargetPanel`, `NameplateWarningPanel`, `NameplateTargetWarningPanel` | `frames/nameplate_normal/target/warning/target_warning` (Warnung zusätzlich gestrichelt) | 6 | 6 / 3 |
| `AuraBuff`, `AuraDebuff*` | `frames/aura_buff_36`, `aura_debuff_36` (weiß, je Kategorie getönt) | 5 | 2 (Rahmen 1 bzw. 2 px nach außen) |
| `CoinGold`, `CoinSilver`, `CoinCopper` | `icons/interface/coin_*` | – | Buchstabe G/S/K bleibt als zweites Signal |
| `MenuHintDot` | `icons/interface/menu_hint` (10 px, bündig in der Ecke des 20-px-Knopfs) | – | – |
| `MapMarker` | Icons `player` (`map/map_player`, Spitze oben, wird gedreht), `respawn` (`map/map_respawn`), `mate` (`map/map_party`, weiß, in Klassenfarbe getönt) | – | – |
| `MouseCursor` (neu, Theme-Typ) | `cursors/<zeiger>_32` und `_48`, Konstanten `hotspot_32` (2), `hotspot_48` (3), `large_from_height` (1440) | – | gesetzt von `scripts/ui/mouse_cursors.gd`; nicht mit der UI skaliert |

**Spieler- und Zielrahmen:** Rahmengrafik 340 × 90 px; Porträtfläche 54 × 54 px bei x = 8, y = 18 (Spieler) bzw. x = 278 (Ziel, gespiegelt); Kopfzeile (Name, Kennzeichen, Stufe, Bedrohung) und Balken liegen im rechteckigen Teil (Spieler x = 84–332, Ziel x = 8–256): Leben 22 px (y = 35), Ressource 18 px (y = 59), Zweitressource 8 px (y = 82). Gespiegelt werden nur die Plätze, nie Texte, Zahlen oder Bilder. „Im Kampf“ ist das Symbol `interface/state_combat` (20 px, Tooltip „Im Kampf“), der Rang zeigt Symbol und Text („Elite“). Nicht unterbrechbare Zauber zeigen `interface/cast_uninterruptible` (20 px) statt des Worts „Schild“; der Tooltip „Nicht unterbrechbar“ bleibt.

**Fensterbedienung:** Schließen-Knopf `interface/window_close` (24 px, `IconButton`), Blättern im Zauberbuch `page_prev`/`page_next` (32 px), Wertebereich `stats_show`/`stats_hide` (32 px). Taschenfenster-Plätze und Ausrüstungsplätze sind 40 × 40 px (`SlotButton40`); leere Ausrüstungsplätze zeigen ihr Bild aus `ausruestungsplaetze.csv`.

**Bildschirme:** Hauptmenü mit Hintergrund `branding/main_menu_background_2560x1440` (füllt den Bildschirm, Seitenverhältnis bleibt); App-Symbol (`config/icon`, `config/windows_native_icon`) und Startbild (`application/boot_splash`) in `project.godot`. Die Wortmarke „WoM“ ist vorläufig und nicht eingebunden (Spieltitel weiter als Text).

**Texturfilter:** Projektweit „Linear Mipmap“ für Oberflächen (`rendering/textures/canvas_textures/default_texture_filter`); Icons werden mit Mipmaps importiert, Rahmen, Balken und Mauszeiger ohne.

### Icons (#55)

Eingebaut sind die Klassen- und Magier-Spezialisierungs-Icons (#55, unverändert), seit dem 27.11.2026 die Zauber-Icons von Magier und Krieger im neuen Design (ersetzen die alten Magier-Zauber-Icons aus #55) und seit dem UI-Paket die allgemeinen Icons im Stil „Stone & Brass“ (Bediensymbole, leere Ausrüstungsplätze, Münzen, Testgegenstände, allgemeine Fähigkeiten, Schadensschulen, Karte). Alte SVG-Icon-Entwürfe werden nicht verwendet.

**Format:** PNG, 128 × 128 px, quadratisch, RGBA (32 Bit), sRGB. Arbeitsfassungen (512–1254 px) legt der Projektverantwortliche in `art-source/` ab; Agenten verändern dort nichts. Verkleinert wird hochwertig (bikubisch) auf 128 px.

**Anzeigegrößen** (logische Pixel bei 1080p, bei 1440p × 1,33): Aktionsleiste, Taschen, Talente 48 px · Zauberbuch, Ausrüstung 40 px · Auren am Spielerrahmen 36 px · Klasse/Spezialisierung auf Auswahlbuttons 32 px (`ChoiceButton/icon_max_width`) · Auren auf Namensplaketten 20 px.

**Gestaltungsregeln:** Motiv füllt das Quadrat; kein eigener Rahmen (Rahmen, Zustände, Seltenheit und Abklingzeit kommen aus dem Theme); kein Text; Ecke unten rechts ruhig (Tastenkürzel, Stapelzahl); bei 20 px erkennbar; Bedeutung über Form und Motiv, nicht nur Farbe; keine Ähnlichkeit zu Icons aus WoW oder anderen Spielen.

**Naming Convention:** `game/assets/ui/icons/<kategorie>/<id>.png`. Der Ordner sagt, *was* es ist; der Dateiname ist *genau* die ID des Datensatzes. Nur `a–z`, `0–9`, `_`; Umlaute umschreiben (ä → `ae`, ö → `oe`, ü → `ue`, ß → `ss`); Endung `.png` klein.

| Ordner | Für | ID aus | Beispiel |
|---|---|---|---|
| `abilities/` | Fähigkeiten | Dateiname in `game/data/abilities/` | `abilities/auto_attack.png` (UI-Paket) |
| `abilities/<klasse>/<schule>/` | Zauber einer Klasse, je Schule bzw. Spezialisierung ein Ordner (englische Namen aus dem Paket) | Zuordnung über das Feld `icon` | `abilities/mage/fire/fireball.png`, `abilities/warrior/bulwark/shield_wall.png` |
| `auras/` | Buffs, Debuffs mit eigenem Bild (derzeit keine) | Dateiname in `game/data/auras/` | `auras/<id>.png` |
| `talents/` | einzelne Talente | ID des Talents im Talentbaum | `talents/eiskalte_praezision.png` |
| `specializations/` | Spezialisierungen | Dateiname in `game/data/specializations/` | `specializations/mage_frost.png` |
| `classes/` | Klassen | Dateiname in `game/data/classes/` | `classes/warrior.png` |
| `schools/` | Schadensschulen | ID in `schadensschulen.csv` | `schools/frost.png` |
| `items/` | Gegenstände | ID in `gegenstaende.csv` | `items/schwert_rostig.png` |
| `interface/` | Bediensymbole ohne Datensatz | `<bereich>_<bedeutung>` | `interface/window_close.png` |
| `map/` | Karten- und Quest-Markierungen | `<bedeutung>` | `map/map_player.png` |
| `races/` | Völker-Embleme (**Konzept, OFFEN**, nicht eingebunden) | englischer Name | `races/high_elf.png` |
| `_test/` | Graubox-Testicons (werden entfernt) | frei | `_test/kreis.png` |

**Ausnahme UI-Paket (englische Dateinamen):** Die Dateien aus dem UI-Paket behalten die englischen Namen des Pakets (`items/wolf_pelt.png`, `schools/fire.png`, `interface/slot_necklace.png`, `abilities/auto_attack.png`). Die deutschen Spiel-IDs bleiben unverändert; die Verbindung steht in den Daten: Spalte `icon` in `gegenstaende.csv` und `schadensschulen.csv`, Tabelle `ausruestungsplaetze.csv` (leere Ausrüstungsplätze), Feld `icon` der Fähigkeit (`.tres`). Die vollständige Zuordnung steht in `docs/ui-assets/german_to_english_icon_ids.csv`. Neue Icons mit Datensatz folgen weiter der ID-Regel oben.

**Klassen-Zauber (Magier, Krieger; neues Design 27.11.2026):** Ablage `icons/abilities/<klasse>/<schule>/<englischer_name>.png` wie im Paket: Magier `mage/arcane|fire|frost|lightning/`, Krieger `warrior/base|bulwark|berserker|battle_master/`. Die englischen Dateinamen sind keine Spiel-IDs; jede Fähigkeit (Grundzauber und Variante der Spezialisierung) nennt ihr Bild ausdrücklich im Feld `icon`. Die Variante einer Spezialisierung ersetzt das Bild im selben Aktionsleisten-Platz. Zuordnung: `docs/ui-assets/class_spell_icon_ids.csv`, Paket-Manifeste `docs/ui-assets/mage_spell_icon_manifest.*`, `warrior_ability_icon_manifest.*`. Die Icons sind **volle Quadrate mit dunklem Hintergrund** (deckend, ohne eigenen Rahmen); sie stehen direkt im vorhandenen Stein-Gold-Slot, **kein zweiter Rahmen** darum. Talent-Fähigkeiten ohne Bild im Paket zeigen weiter das Kürzel.

**Aura-Icons:** Eine Aura, die zu genau einem Zauber gehört (z. B. Eisschild, Erfrierung, Kampfschrei, Schildwall), nutzt im Feld `icon` dasselbe Bild wie der Zauber, der sie anwendet; es gibt dafür keine eigene Datei unter `auras/`. Auren ohne passenden Zauber (z. B. Brand, Ladung, Tiefe Wunde, Raserei) zeigen weiter das Kürzel.

Gleiche IDs in verschiedenen Kategorien sind erlaubt; braucht eine Aura ein eigenes Bild, liegt es unter `auras/<id>.png`. Ändert sich eine ID, wird das Icon im selben Pull Request umbenannt.

**Einbinden:** Das Icon steht im Datensatz im Feld `icon` (`AbilityData`, `AuraData`, `TalentData`, `SpecializationData`, `ClassData`; bei Gegenständen die Spalte `icon` in `gegenstaende.csv`, bei Schadensschulen die Spalte `icon` in `schadensschulen.csv`, bei Ausrüstungsplätzen `ausruestungsplaetze.csv`). Leer = Kürzel als Platzhalter wie bisher.

**Import:** In der `.import`-Datei jedes Icons `mipmaps/generate=true` (im Editor: Icon auswählen → Reiter „Import“ → „Mipmaps → Generate“ → „Reimport“). Alle Anzeige-Stellen nutzen den Texturfilter „Linear Mipmap“ (`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`): `AbilityIcon`, `TalentNodeButton`, `aura_icon.tscn`, Klassenwahl in der Charaktererstellung, Spezialisierungs-Reiter im Talentfenster. Ohne Mipmaps flimmern verkleinerte Icons.

**Herkunft und Lizenz:** `game/assets/ui/icons/QUELLEN.md` nennt für jede Gruppe Urheber bzw. Werkzeug und Nutzungsbedingungen; neue Icons werden dort eingetragen.

## 8. Qualitätssicherung und Abnahme

- [ ] UI wirkt eigenständig und ist keine WoW-Kopie.
- [ ] Theme, Dokumentation und Preview stimmen überein.
- [ ] Alle Buttonzustände und Fokuszustände sind sichtbar.
- [ ] Leben, Ressourcen, Klassen, Seltenheiten und Kampftext sind konsistent.
- [ ] Bei 1080p und 1440p getestet.
- [ ] Große Gruppen-/Kampfsituationen auf Lesbarkeit geprüft.
- [ ] Fonts sind frei lizenziert und korrekt dokumentiert.
- [ ] Maus, Tastatur und gegebenenfalls Gamepad berücksichtigt.

## 9. Verbindlicher Arbeitsablauf

**Phase 1 – Fragen:** Maximal sechs kurze Fragen mit je zwei bis vier Beispielantworten; danach auf Antwort warten.  
**Phase 2 – Stilrichtungen:** Drei deutlich unterschiedliche Vorschläge, jeweils Name, Stimmung in zwei Sätzen, Palette mit fünf bis sieben Hex-Farben, freier Font, Rahmen und Buttons; danach auf Auswahl/Kombination warten.  
**Phase 3 – Umsetzung:** Erst nach Freigabe auf Branch `feature/ui-styleguide` implementieren; dieses Dokument finalisieren, Theme und Vorschau erstellen, `CLAUDE.md` ergänzen und PR mit Testanleitung eröffnen.

**Pflichtregel für `CLAUDE.md`:** „Jedes UI-Element nutzt `game/assets/ui/theme.tres` und folgt `docs/UI-STYLEGUIDE.md`. Keine Farben oder Schriften direkt im Code festlegen.“
