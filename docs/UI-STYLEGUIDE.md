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

**Basistypen ohne Variation:**

- `Label`: Schriftgröße 16 px (wie `BodyText`).
- `Button`: eigene `StyleBoxFlat` für normal, Hover, gedrückt (auch Hover+gedrückt), deaktiviert und Fokus. Fokus ist ein zusätzlicher heller Rahmen über dem jeweiligen Zustand. Innenabstand 16 px horizontal / 12 px vertikal; damit sind Buttons mit Standardschrift 47 px hoch und erfüllen die **Mindesthöhe von 40 px** aus Abschnitt 6.
- `Panel` und `PanelContainer`: eine `StyleBoxFlat` mit 16 px Innenabstand.

**Mindestbreiten** kann ein Theme nicht festlegen; sie stehen als `custom_minimum_size` in der Szene (Menü-Buttons: 240 px breit).

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
