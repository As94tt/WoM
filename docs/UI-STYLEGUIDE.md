# UI-STYLEGUIDE – High-Fantasy-Koop-RPG

> **Status:** Entwurf / Stil noch nicht freigegeben.  
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

## 2. Stilentscheidungen – Freigabe erforderlich

Folgende Angaben werden in Phase 1 abgefragt und in Phase 2 als drei Varianten vorgeschlagen:

| Entscheidung | Beispiele | Final |
|---|---|---|
| Stimmung | episch, warm-abenteuerlich, mystisch, düster | **OFFEN** |
| Rahmenmaterial | Metall, Holz, Stein, Pergament | **OFFEN** |
| Detailgrad | schlicht, mittel, stark verziert | **OFFEN** |
| Formen | kantig, weich, ornamental | **OFFEN** |
| Referenzen | 1–3 Spiele/Illustrationsstile | **OFFEN** |
| Informationsdichte | minimal, mittel, klassisches MMORPG | **OFFEN** |

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
| Seltenheit | `rarity/common` | TBD |
| Seltenheit | `rarity/uncommon` | TBD |
| Seltenheit | `rarity/rare` | TBD |
| Seltenheit | `rarity/epic` | TBD |
| Seltenheit | `rarity/legendary` | TBD |
| Kampftext | `combat/damage` | TBD |
| Kampftext | `combat/critical` | TBD |
| Kampftext | `combat/heal` | TBD |
| Kampftext | `combat/miss` | TBD |

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
- Vorläufige Rahmen ausschließlich mit Godot-`StyleBoxFlat`: Flächen, Rahmenbreite, Ecken, Schatten.
- Keine handgezeichneten oder aus fremden Spielen übernommenen Rahmen/Icons in der ersten Iteration.
- Theme-Overrides nur, wenn sie als dokumentierte, wiederverwendbare Variation im Theme-System etabliert sind.
- **Keine Farben und Schriften direkt in Gameplay- oder UI-Code hardcoden.**
- Pflicht-Vorschauszene: `game/scenes/ui/style_preview.tscn` mit sämtlichen Komponenten und States.
- Godot-Projektversion und Font-Import vor Übergabe prüfen; Szene im Editor und im laufenden Projekt testen.

### Theme-Aufbau

`game/assets/ui/theme.tres` ist in `game/project.godot` unter `[gui] theme/custom` als projektweites Standard-Theme eingetragen. Szenen setzen kein eigenes Theme und keine `theme_override_*`-Werte, sondern wählen über `theme_type_variation` eine der folgenden Variationen.

**Alle Werte im Theme sind Graubox-Platzhalter** (neutrale Grau-/Weißtöne, Godot-Standardschrift, nur `StyleBoxFlat`). Sie sind keine Tokens; die Tokens in Abschnitt 3 bleiben TBD, bis die Stilrichtung freigegeben ist. Neue Variationen werden hier eingetragen und in `style_preview.tscn` gezeigt.

| Variation | Basistyp | Wert | Verwendung |
|---|---|---|---|
| `MenuTitle` | `Label` | Schriftgröße 64 px | Spieltitel im Hauptmenü |
| `ScreenTitle` | `Label` | Schriftgröße 36 px | Titel eines Bildschirms |
| `WindowTitle` | `Label` | Schriftgröße 24 px | Fenster- und Abschnittstitel |
| `Subtitle` | `Label` | Schriftgröße 18 px | Untertitel |
| `BodyText` | `Label` | Schriftgröße 16 px | Fließtext |
| `SmallLabel` | `Label` | Schriftgröße 14 px | kompakte Beschriftungen |
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
| `ChoiceButton` | `Button` | wie `Button`; gedrückt und Hover+gedrückt nutzen die Ausgewählt-Fläche von `ListEntryButton`, Schrift im ausgewählten Zustand weiß | Auswahlbutton mit `toggle_mode` in einer `ButtonGroup` (Volk, Geschlecht, Klasse in der Charaktererstellung) |
| `ChoiceGrid` | `GridContainer` | Abstand 12 px horizontal und vertikal | Raster aus Auswahlbuttons (z. B. Völker in zwei Spalten) |
| `ErrorText` | `Label` | Schriftgröße 16 px, hellste Textfarbe (Graubox-Platzhalter, bis ein Warn-Token freigegeben ist) | Fehlermeldung unter einem Eingabefeld; ersetzt in derselben Zeile den `HintText` |
| `SlotButton` | `Button` | quadratischer leerer Rahmen ohne Innenabstand: eigene `StyleBoxFlat` für normal, Hover, gedrückt (auch Hover+gedrückt), deaktiviert; Fokus wie `Button` | Aktionsleisten-Slot (48 × 48 px), Taschenplatz (48 × 48 px), Menüleisten-Button und Schließen-Button „X“ eines Fensters (40 × 40 px) |
| `SlotFlash` | `Panel` | halbtransparente helle Fläche ohne Rahmen | kurzes Aufleuchten eines Aktionsslots bei Klick oder Taste (blendet in 0,25 s aus); fängt keine Mausklicks ab |
| `SlotHotkey` | `Label` | Schriftgröße 14 px | Taste unten rechts im Aktionsslot (4 px Abstand zum Rand) |
| `SlotRow` | `HBoxContainer` | Abstand 4 px | Slots einer Aktionsleiste, Menüleiste, Taschenleiste |
| `SlotColumn` | `VBoxContainer` | Abstand 4 px | übereinanderliegende Aktionsleisten |
| `ZoneBannerTitle` | `Label` | Schriftgröße 48 px, helle Schrift mit 8-px-Kontur in dunkler Konturfarbe | Gebietsname der Einblendung beim Betreten eines Gebiets (#15) |
| `ZoneBannerSubtitle` | `Label` | Schriftgröße 20 px, gedämpft helle Schrift mit 6-px-Kontur | Stufenbereich unter dem Gebietsnamen („Stufe 4–6“); entfällt bei Gebieten ohne Stufenbereich |
| `MapZoneLabel` | `Label` | Schriftgröße 18 px, helle Schrift mit 6-px-Kontur | Gebietsnamen auf der Karte (über dem Kartenbild lesbar, egal welche Bodenfarbe darunter liegt) |
| `LogText` | `Label` | Schriftgröße 16 px, helle Schrift mit 4-px-Kontur in dunkler Konturfarbe | Zeilen im Log-Bereich des HUD (#30, z. B. „Arthas hat die Welt betreten.“), lesbar ohne Hintergrundfläche über der 3D-Welt |

**Basistypen ohne Variation:**

- `Label`: Schriftgröße 16 px (wie `BodyText`).
- `Button`: eigene `StyleBoxFlat` für normal, Hover, gedrückt (auch Hover+gedrückt), deaktiviert und Fokus. Fokus ist ein zusätzlicher heller Rahmen über dem jeweiligen Zustand. Innenabstand 16 px horizontal / 12 px vertikal; damit sind Buttons mit Standardschrift 47 px hoch und erfüllen die **Mindesthöhe von 40 px** aus Abschnitt 6.
- `Panel` und `PanelContainer`: eine `StyleBoxFlat` mit 16 px Innenabstand.
- `TooltipPanel` / `TooltipLabel`: Tooltip mit eigener `StyleBoxFlat` (8 px horizontal / 4 px vertikal Innenabstand, 1-px-Rahmen), Schriftgröße 16 px. Gilt für alle `tooltip_text` im Spiel (z. B. Menüleiste: „Charakter (C)“).
- `MapMarker` (eigener Theme-Typ ohne Basistyp, gelesen von `scripts/ui/map_marker.gd`, das die Symbole selbst zeichnet): Farben `player_color` (eigener Pfeil, hell), `respawn_color` (Wiedereinstiegspunkt, mittelgrau), `outline_color` (Kontur, dunkel); Konstanten `player_size` 28 px, `respawn_size` 22 px, `mate_size` 16 px (Mitspieler, #30), `outline_width` 2 px. Mitspieler sind gefüllte Punkte in ihrer Klassenfarbe (aus den Daten, siehe „Klassenfarben“) mit dunkler Kontur. Zweites Erkennungsmerkmal ist die Form (Pfeil, Kreis mit Kreuz, Punkt) und bei Wiedereinstiegspunkt und Mitspieler ein Tooltip (Ort bzw. Name).
- `LineEdit`: eigene `StyleBoxFlat` für normal und deaktiviert (`read_only`, bei `editable = false`), Fokus wie `Button`. Innenabstand 12 px horizontal / 8 px vertikal, Schriftgröße 16 px, gedämpfte Farbe für Platzhaltertext.

**Mindestbreiten** kann ein Theme nicht festlegen; sie stehen als `custom_minimum_size` in der Szene (Menü-Buttons: 240 px breit, „Welt betreten“ und „Erstellen“: 280 px, Dialog: 480 px, Dialog-Buttons: 160 px, Namensfeld: 320 px, Meldungszeile unter dem Namensfeld: 480 × 44 px für zwei Zeilen; Spielmenü-Buttons: 280 px; HUD siehe unten).

### Basisgröße und Skalierung

Die Basisgröße des Projekts ist **1920 × 1080** (`display/window/size/viewport_width/height`, Stretch-Modus `canvas_items`, Aspect `expand`). Alle Pixelangaben in diesem Dokument sind logische Pixel bei dieser Basisgröße; bei 1440p wird alles mit Faktor 1,33 skaliert. Das Testfenster startet mit 1280 × 720 (`window_width/height_override`), damit zwei Instanzen nebeneinander passen; dort wirkt alles entsprechend kleiner.

### Interface im Spiel (HUD, Ticket #17)

Szene `game/scenes/ui/hud.tscn` mit Teilen in `game/scenes/ui/hud/`. Außenrand `ScreenMargin` (32 px).

| Element | Aufbau | Position |
|---|---|---|
| Aktionsleisten | 2 × 12 `SlotButton`-Slots à 48 × 48 px in `SlotRow`, Leisten in `SlotColumn`; Leiste 1 unten, Leiste 2 darüber | unten mittig |
| Menüleiste | 5 `SlotButton` à 40 × 40 px mit Platzhalter-Buchstaben (C, Z, T, K, S), Tooltip „Name (Taste)“ | unten rechts, über der Taschenleiste |
| Taschenleiste | 4 Taschenplätze + Rucksack („R“) à 48 × 48 px, Rucksack ganz rechts | unten rechts |
| Fenster | `PanelContainer` mit `WindowTitle`, Schließen-Button „X“ (`SlotButton` 40 × 40 px) und Inhaltsbereich; leer mit `HintText` „Kommt bald“ | siehe unten |
| Spielmenü | `DimOverlay` + `DialogPanel` mit `WindowTitle` und `ButtonList`; nicht belegte Punkte deaktiviert | Bildschirmmitte |

Fenstergrößen und Plätze: Charakter und Zauberbuch 400 × 520 px links nebeneinander (feste Reihenfolge, 12 px Abstand, 128 px vom oberen Rand, unter Namens- und Infozeile); Talente 640 × 520 px mittig im Platz rechts davon; Karte ca. 70 % des Bildschirms mittig; Taschen 360 × 280 px unten rechts über Menü- und Taschenleiste. Bei 16:9 überlappen sich gleichzeitig offene Fenster nicht; die Karte schließt beim Öffnen alle anderen Fenster.

**Gebietsnamen-Einblendung (#15):** `game/scenes/ui/hud/zone_banner.tscn`, Teil von `hud.tscn`. Oben mittig, 160 px vom oberen Rand: Gebietsname (`ZoneBannerTitle`), darunter Stufenbereich (`ZoneBannerSubtitle`). Blendet in 0,5 s ein, bleibt 2,5 s und blendet in 1,5 s aus (Deckkraft, keine Farbänderung). Fängt keine Mausklicks ab.

**Karte (#15):** Inhalt des Kartenfensters ist `game/scenes/ui/hud/map_view.tscn`: quadratisches Kartenbild (von oben gerendert, Norden oben), mittig im Fenster, darüber Gebietsnamen (`MapZoneLabel`), Wiedereinstiegspunkte und eigene Position (`MapMarker`). Der Fenstertitel nennt das aktuelle Gebiet („Karte – Wolfswiese“). Ohne Grafikausgabe steht statt des Bilds der `HintText` „Kartenbild nicht verfügbar“. Mitspieler (#30) erscheinen als Punkte in Klassenfarbe (`MapMarker`, `mate_size`) mit ihrem Namen als Tooltip.

**Entwickler-Panel (#15, nur Debug-Builds):** `game/scenes/ui/dev/dev_panel.tscn`, F10. `PanelContainer` 360 px breit am rechten Rand (128 px von oben, 200 px Abstand unten), Titel `WindowTitle`, Abschnittsüberschriften `Subtitle`, Einträge in `ButtonList` (Standard-`Button`, `CheckBox` und `HSlider` mit Godot-Standardaussehen, Infozeilen `SmallLabel`), bei Bedarf mit Bildlaufleiste. Werkzeug für Entwickler, kein Teil des Spiel-Interfaces; spätere Tickets (#19) ergänzen eigene Abschnitte. Abschnitt „Netzwerk“ (#30): Infozeile „Künstliche Verzögerung: 150 ms“ und darunter ein Schieberegler 0–300 ms in 10-ms-Schritten.

**Log-Bereich (#30):** `game/scenes/ui/hud/message_log.tscn`, Teil von `hud.tscn`. Unten links (32 px vom linken und unteren Rand), 480 px breit, ohne Hintergrundfläche; Zeilen `LogText`, neueste unten, höchstens 8 Zeilen. Jede Zeile bleibt 20 s sichtbar und blendet in 2 s aus (Deckkraft). Fängt keine Mausklicks ab. Später schreiben hier auch Chat und Kampflog.

**Spielerliste (#30):** `game/scenes/ui/hud/player_list.tscn`, sichtbar solange O gehalten wird (Aktion `player_list`). `PanelContainer` 560 px breit, oben mittig 128 px vom oberen Rand. Titel `WindowTitle` („Spieler (2 / 5)“), darunter ein Raster mit fünf Spalten (`ChoiceGrid`-Abstände): Überschriften `HintText` (Name, Stufe, Klasse, Ping), Zeilen `BodyText`; die Klasse steht in Klassenfarbe, der Host ist mit dem Wort „Host“ gekennzeichnet (nicht nur über die Farbe), sein Ping als „–“. Fängt keine Mausklicks ab.

**Netzwerk-Overlay (#30):** `game/scenes/ui/hud/net_overlay.tscn`, F3 (Aktion `toggle_net_overlay`). `PanelContainer` 360 px breit oben rechts (32 px vom Rand), drei Zeilen `SmallLabel`: Peer-ID und Host ja/nein, Ping und Spielerzahl, gesendete und empfangene KB/s. Endet oberhalb des Entwickler-Panels (128 px), damit beide gleichzeitig offen sein können. Werkzeug, kein Teil des Spiel-Interfaces.

**Namensplakette (#30):** Über jeder fremden Spielfigur in der 3D-Welt (die eigene Figur hat keine; ihr Name steht oben links im HUD). Zwei `Label3D` mit Billboard, 0,3 m über dem Kopf: Name (`font_size` 40, Kontur 10) in Klassenfarbe, darunter „Stufe N“ (`font_size` 26, Kontur 8) in Standardfarbe; `pixel_size` 0,01 m, ausgeblendet ab 80 m. Label3D kann kein Theme nutzen, deshalb stehen die Werte in `game/scenes/player/player.tscn`. Vorläufig, bis #31 die Plaketten ersetzt.

### Dialoge (#30)

- **Verbindungsdialog** (`game/scenes/ui/connect_dialog.tscn`) nach „Welt betreten“: wie der Löschdialog `DimOverlay` + `DialogPanel` (480 px), Titel `WindowTitle` („Spiel hosten“ / „Spiel beitreten“), Hinweis `HintText` (beim Hosten zur Portfreigabe im Router), Felder IP-Adresse und Port als `LineEdit` mit Beschriftung `BodyText` in einem zweispaltigen Raster (`ChoiceGrid`), darunter eine Meldungszeile (432 × 44 px): Fehler als `ErrorText`, Status („Verbinde mit … “) als `BodyText`. Buttons rechts (`ButtonRow`, 160 px): „Abbrechen“, „Starten“ bzw. „Verbinden“. Während des Verbindens sind die Felder gesperrt und nur „Abbrechen“ ist zu sehen.
- **Hinweis- und Bestätigungsdialog** (`game/scenes/ui/message_dialog.tscn`): gleicher Aufbau mit Titel, Text `BodyText` und einem („OK“) oder zwei Buttons. Verwendet für „Der Host hat die Sitzung beendet“ im Hauptmenü und die Rückfrage des Hosts im Spielmenü.

**Klassenfarben (vorläufig):** Solange die Tokens `class/*` in Abschnitt 3 TBD sind, steht die Klassenfarbe als vorläufiger Wert in den Klassendaten (`ClassData.color` in `game/data/classes/*.tres`) und wird zur Laufzeit auf den Klassennamen gesetzt. Das ist die einzige Farbe, die nicht aus dem Theme kommt, weil sie aus Daten stammt. Nach Freigabe der Tokens werden die Werte in den `.tres`-Dateien durch die Token-Werte ersetzt. Dieselbe Farbe färbt in der Charakterauswahl und -erstellung auch das Platzhaltermodell (Kapsel) in der 3D-Vorschau, im Spiel die Kapsel jeder Spielfigur, den Namen auf ihrer Namensplakette, die Klasse in der Spielerliste und den Mitspieler-Punkt auf der Karte (#30). Der Klassenname steht immer zusätzlich als Text da (Farbe nie als einziger Bedeutungsträger).

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
