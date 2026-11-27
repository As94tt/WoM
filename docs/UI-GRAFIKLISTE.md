# WoM – Fehlende UI-Grafiken (allgemein, ohne Klassen)

Stand: `main` nach #66 (27.11.2026). Quelle: `docs/UI-STYLEGUIDE.md`, `theme.tres`, HUD-Code, offene Tickets.
Heute ist **alles außer den Klassen-/Magier-Icons Graubox**: Flächen sind `StyleBoxFlat`, Symbole sind Buchstaben-Kürzel, Schrift ist Godots Standardschrift.

**Priorität:** **P1** = im Spiel schon sichtbar (ersetzt einen Platzhalter) · **P2** = kommt mit einem geplanten Ticket.

## Stand: Lieferung UI-Paket „Stone & Brass“ (27.11.2026)

Das Paket des Projektverantwortlichen beantwortet diese Liste (220 Dateien, Manifest in `docs/ui-assets/`). Stilrichtung siehe `docs/UI-STYLEGUIDE.md`, Abschnitt 2 und „UI-Grafiken (Stone & Brass)“.

| Abschnitt | Geliefert | Eingebunden | Offen |
|---|---|---|---|
| 1. Schriften | – (Paket enthält bewusst keine Schriften; Vorschlag in `game/assets/ui/fonts/README.txt`) | – | **OFFEN:** Schriften (SIL OFL 1.1) auswählen und mit Lizenz ablegen |
| 2. Rahmen, Flächen, Knöpfe | alle Elemente inkl. Zustände, 9-Slice-Ränder im Manifest | ja, als `StyleBoxTexture` im Theme; Menüleiste als 20 × 40 px | `DimOverlay` und „nicht nutzbar“ bleiben Farben (keine Grafik nötig) |
| 3. Balken | Leben, Ressource, Zweitressource, Zauber, Erfahrung, Boss | alle außer Boss-Leben (kommt mit #36/#37) | Endgültige Farben (Tokens) **OFFEN** |
| 4.1 Bediensymbole | alle + Menüsymbole für spätere Knöpfe (Taschen, Gruppe, Quests, Gilde, Post, Hilfe, Kampf) | Menüleiste, Rucksack, Schließen, Blättern, Werte, Kampf, Rang, Schild an der Zauberleiste, Münzen, Hinweis-Punkt | `lock`, `bag_slot_empty`, `dialog_*` liegen bereit (kein Platz bzw. Ticket #28) |
| 4.2 Leere Ausrüstungsplätze | alle (englische Dateinamen) | ja, über `ausruestungsplaetze.csv` | – |
| 4.3 Gegenstände | alle 10 Testgegenstände | ja, Spalte `icon` in `gegenstaende.csv` | – |
| 4.4 Allgemeine Fähigkeiten | `auto_attack`, `help_up` (+ `revive`) | ja (`.tres`) | – |
| 4.5 Schadensschulen | alle 9 | Spalte `icon` in `schadensschulen.csv` (Anzeige folgt) | Anzeige im Tooltip |
| 4.6 Völker | 6 Embleme | nein | **OFFEN:** nur Konzept, nicht freigegeben |
| 4.7 Porträts | 6 Silhouetten | nein (Porträt zeigt weiter den Anfangsbuchstaben) | **OFFEN:** echte Porträts bzw. 3D-Porträt |
| 5. Karte, Welt | Pfeil, Mitspieler, Wiedereinstieg, Quest-Symbole, Zielkreis, Bodenziel | Karte (Pfeil, Mitspieler, Wiedereinstieg) | Zielkreis/Bodenziel als Textur statt Mesh, Quest-Symbole (#28) |
| 6. Mauszeiger | alle 8 in 32 und 48 px mit Hotspots | Standardzeiger (32/48 px nach Bildschirmhöhe) | übrige Zeiger mit #28, #36, #38 |
| 7. Bildschirme | App-Symbol, Startbild, Hauptmenü-Hintergrund, Wortmarke, Banner | App-Symbol, Startbild, Hauptmenü-Hintergrund | Wortmarke „WoM“ vorläufig (Spieltitel **OFFEN**); Banner für Aufstieg und Beute noch nicht eingebunden |

---

## 0. Regeln, die für alles gelten

| Thema | Anforderung |
|---|---|
| Basisauflösung | 1920 × 1080; alle Größen hier sind logische Pixel. Bei 1440p wird alles × 1,33 hochskaliert. |
| Format | PNG, RGBA 32 Bit, sRGB. Arbeitsdateien (größer) nach `art-source/`, ins Spiel nur die fertige Größe. |
| Icons | 128 × 128 px, quadratisch, **ohne eigenen Rahmen, ohne Text**, Motiv füllt das Quadrat, Ecke unten rechts ruhig (Tasten, Stapelzahl), bei 20 px noch erkennbar. Import mit Mipmaps. |
| Ablage Icons | `game/assets/ui/icons/<kategorie>/<id>.png`, nur `a–z 0–9 _`, Umlaute umschreiben. Bediensymbole ohne Datensatz: `interface/<bereich>_<bedeutung>.png`. |
| Rahmen/Flächen | als **9-Slice** (Godot `StyleBoxTexture`): Ecken bleiben fest, Kanten und Mitte werden gestreckt oder gekachelt. Pro Grafik die Randbreiten (Texture Margins) in px angeben. Ablageort ist noch nicht festgelegt (Vorschlag: `game/assets/ui/frames/`). |
| Einfärbbar | Alles, was zur Laufzeit eingefärbt wird (Seltenheit, Debuff-Kategorie, Balkenfarben, Klassenfarbe), **in Weiß/Graustufen** liefern; die Farbe kommt aus dem Theme. |
| Farbe | Nie einziger Bedeutungsträger: Form, Symbol oder Text als zweites Signal. |
| Lizenz | Nur eigene Grafiken oder CC0; Schriften bevorzugt SIL OFL 1.1. Jede neue Gruppe in `icons/QUELLEN.md` eintragen. **Keine Motive aus WoW oder anderen Spielen.** |
| Offen | Stilrichtung (Material, Formen, Detailgrad, Farben) ist laut Styleguide noch **OFFEN** – vor dem großen Zeichnen festlegen. |

---

## 1. Schriften (P1)

| Was | Anforderung |
|---|---|
| UI-/Fließtext-Schrift | TTF/OTF, SIL OFL 1.1, Lizenzdatei nach `game/assets/ui/fonts/`. Vollständige deutsche Zeichen (ä ö ü Ä Ö Ü ß „ “ – … ·), Ziffern gut unterscheidbar, gut lesbar bei **14 px**. Normal + Fett. |
| Titel-Schrift | wie oben; für 22–64 px (Fenstertitel, Bildschirmtitel, Gebietsname 48 px, Spieltitel 64 px). Darf verzierter sein, muss aber mit Kontur (4–8 px) lesbar bleiben. |

---

## 2. Rahmen, Flächen, Knöpfe (9-Slice) – P1

| Element (Theme-Name) | Wo | Größe | Zustände / Varianten | Technische Hinweise |
|---|---|---|---|---|
| Fenster (`Panel`/`PanelContainer`) | Charakter, Zauberbuch, Talente, Karte, Taschen | 360 × 280 bis 760 × 560 | 1 | Innenabstand 16 px; Platz für Titel oben und „X“ rechts oben |
| Dialog (`DialogPanel`) | Bestätigen, Verbinden, Stapel teilen, Tod | 360–960 px breit | 1 | Innenabstand 24 px, deutlicher als Fenster |
| Tooltip (`TooltipPanel`) | überall | variabel, ca. 280–340 px breit | 1 | Innenabstand 8 / 4 px, schlanker Rand |
| Knopf (`Button`) | Menüs, Dialoge | ≥ 160 × 47 (Menü 240–280 breit) | normal, Hover, gedrückt, deaktiviert, **Fokus** (Overlay) | Innenabstand 16 / 12 px; Text liegt darauf |
| Großer Knopf (`EnterWorldButton`) | „Welt betreten“, „Erstellen“ | 280 px breit | wie Knopf | darf prominenter sein |
| Listeneintrag (`ListEntryButton`) | Charakterliste | volle Breite | normal, Hover, **ausgewählt**, deaktiviert | „ausgewählt“ heller + breiter linker Rand |
| Auswahlknopf (`ChoiceButton`, `LogTab`, `LockedChoiceButton`) | Volk/Klasse/Geschlecht, Reiter, Log-Reiter | variabel | normal, Hover, ausgewählt, deaktiviert/gesperrt, Fokus | Icon links max. 32 px |
| Slot (`SlotButton`) | Aktionsleiste, Taschenplätze, Talente (48 px); Menüleiste, Zauberbuch, Ausrüstung, „X“ (40 px) | 48 × 48 und 40 × 40 | normal, Hover, gedrückt, deaktiviert, Fokus | quadratischer Rahmen, **Mitte frei für das Icon** (Icon liegt innen) |
| Slot-Aufleuchten (`SlotFlash`) | Klick auf Aktionsslot | 48 × 48 | 1 | helle, halbtransparente Fläche, blendet in 0,25 s aus |
| Proc-Leuchten (`SlotProcGlow`) | Aktionsslot | 48 × 48 (+ Überstand) | 1, gern animiert (Sprite-Sheet) | leuchtender Rand, darf über den Slot hinausragen |
| Aktiv-Rahmen (`SlotActive`) | Haltung, Autoangriff, gelerntes Talent | 48 × 48 | 1 | heller Rahmen |
| Talent vorgemerkt (`TalentPending`) | Talentfenster | 48 × 48 | 1 | Rahmen, einfärbbar |
| Seltenheitsrahmen (`ItemRarityFrame`) | Taschen, später Ausrüstung | 48 / 40 | 1 | **weiß** liefern, wird je Seltenheit eingefärbt |
| Abklingzeit (`CooldownSweep`) | Aktionsslot | 48 × 48 | 1 | optional: Textur für die Uhrzeiger-Abdunklung (wird heute gezeichnet) |
| Einheitenrahmen (`UnitFramePanel`) | Spieler-/Zielrahmen oben links | 340 × ca. 90 | Spieler, Ziel | Platz für 64-px-Porträt links und Balken rechts |
| Porträtrahmen (`UnitPortrait`) | im Einheitenrahmen | 64 × 64 | 1 | heute Anfangsbuchstabe; echte Porträts siehe 3.4 |
| Kennzeichen (`UnitBadge`) | „Elite“, „Selten“, „Boss“, „Im Kampf“, „Schild“ an Zauberleiste | ca. 20 px hoch | 1 | Text liegt darauf; **kein Drache** (Styleguide, auch wenn #36 ihn nennt) |
| Namensplakette Ziel (`NameplateTargetPanel`) | über Einheiten | ca. 140 × 40 | normal, Ziel, Warnung, Ziel+Warnung | dezent, über 3D-Welt lesbar |
| Aura-Rahmen (`AuraBuff`, `AuraDebuff*`) | Buffs/Debuffs | 36, 32, 24, 20 px | Buff (schmal), Debuff (breit) | Debuff-Rahmen **weiß** liefern, wird je Kategorie eingefärbt (Magie, Gift, Krankheit, Fluch, körperlich) |
| Eingabefeld (`LineEdit`, `SpinBox`) | Name, IP/Port, Stapel teilen | 320 × 40 | normal, Fokus, gesperrt | Innenabstand 12 / 8 px |
| Häkchen (`CheckBox`) | Spielmenü (Aktionsleisten sperren, Kampftext) | 24 × 24 Symbol | aus, an, Hover, deaktiviert | heute Godot-Standard |
| Bildlaufleiste (`VScrollBar`) | Talente, Werte, Taschen, Fehlerliste | 12–16 px breit | Schiene, Griff (normal/Hover/gezogen) | heute Godot-Standard |
| Abdunklung (`DimOverlay`) | hinter Dialogen | Vollbild | – | **keine Grafik nötig** (Farbe) |

---

## 3. Balken – P1

Alle als **Hintergrund + Füllung**, waagerecht dehnbar (9-Slice oder kachelbar). Füllung **weiß/grau** liefern, damit eine Grafik für alle Farben reicht (Farbe aus dem Theme).

| Balken | Wo | Höhe | Breite | Varianten |
|---|---|---|---|---|
| Leben (`HealthBar`) | Einheitenrahmen / Namensplakette | 22 / 8 px | 240 / 120 px | – |
| Ressource (`ManaBar`, `RageBar`, `EnergyBar`, `ChiBar`) | Einheitenrahmen | 18 px | ca. 240 px | – |
| Zweitressource | Spielerrahmen | 8 px | ca. 240 px | – |
| Zauberleiste (`CastBar*`) | eigene / Ziel / Plakette | 22 / 18 / 14 px | 360 / voll / 120 px | Zauberzeit, Kanalisieren, fertig, fehlgeschlagen (Farbe), Funken-/Kantenmarke optional |
| Erfahrung (#27, **P2**) | über den Aktionsleisten, ganze Breite | ca. 8–10 px | ca. 640 px | normal, „ausgeruht“ optional |
| Boss-Leben (#36/#37, **P2**) | oben am Bildschirm | ca. 24 px | ca. 600 px | – |

---

## 4. Icons (128 × 128 px, Regeln aus Abschnitt 0)

### 4.1 Bediensymbole `interface/` – P1

| Datei (Vorschlag) | Bedeutung | Anzeige |
|---|---|---|
| `menu_character` | Charakter (C) | 40 px |
| `menu_spellbook` | Zauberbuch | 40 px |
| `menu_talents` | Talente | 40 px |
| `menu_map` | Karte | 40 px |
| `menu_game` | Spielmenü (S) | 40 px |
| `bag_backpack` | Rucksack in der Taschenleiste (Zahl freier Plätze unten rechts!) | 48 px |
| `bag_slot_empty` | leerer Taschenplatz | 48 px |
| `window_close` | „X“ eines Fensters | 40 px |
| `page_prev`, `page_next` | Blättern im Zauberbuch | 40 px |
| `stats_show`, `stats_hide` | Wertebereich ein-/ausklappen (»/«) | 40 px |
| `cast_uninterruptible` | nicht unterbrechbarer Zauber (heute Wort „Schild“) | ca. 16–20 px |
| `state_combat` | „Im Kampf“ im Spielerrahmen | ca. 16–20 px |
| `rank_elite`, `rank_rare`, `rank_boss` | Gegnerrang am Zielrahmen | ca. 16–20 px |
| `lock` | gesperrte Spezialisierung/Reihe | 20–32 px |
| `coin_gold`, `coin_silver`, `coin_copper` | Münzen in der Geldanzeige | **18 px** – sehr einfache Form, zweites Signal (G/S/K) darf ins Motiv |
| `menu_hint` | Hinweis-Punkt am Menüknopf | 10 px |

### 4.2 Leere Ausrüstungsplätze `interface/slot_*` – P1
Zeigen im Charakterfenster, welcher Platz leer ist. 40 px, eher blass/silhouettenhaft. 15 Motive:
`slot_helm`, `slot_kette`, `slot_schulter`, `slot_umhang`, `slot_brust`, `slot_armschienen`, `slot_handschuhe`, `slot_guertel`, `slot_beine`, `slot_schuhe`, `slot_ring` (für Ring 1+2), `slot_haupthand`, `slot_nebenhand`, `slot_fernkampf`, `slot_siegel`, `slot_talisman` (für Talisman 1–3).

### 4.3 Gegenstände `items/<id>` – P1 (Testgegenstände)
48 px in Taschen, 40 px in Ausrüstung. Werden in `gegenstaende.csv`, Spalte `icon`, eingetragen. **Kein Seltenheitsrahmen ins Bild** (kommt aus dem Theme).
`wolfsfell`, `schwert_rostig`, `lederkappe`, `tasche_klein`, `tasche_mittel`, `tasche_gross`, `leuchtkristall`, `brot_hart`, `zahn_zerbrochen`, `brief_versiegelt`.
Hinweis: Lederbeutel, Lederkappe und Leuchtkristall zeigen heute alle „Le“ – hier hilft ein Icon am meisten.

### 4.4 Allgemeine Fähigkeiten `abilities/` – P1
Gelten für alle Klassen: `automatischer_angriff`, `aufhelfen` (48 px Aktionsleiste, 40 px Zauberbuch).

### 4.5 Schadensschulen `schools/` – P2
`physisch`, `arkan`, `feuer`, `frost`, `blitz`, `natur`, `chi`, `schatten`, `heilig`. Heute nur Text im Tooltip; Ordner ist schon in der Namenskonvention vorgesehen.

### 4.6 Völker – offen
`human`, `high_elf`, `dark_elf`, `dwarf`, `orc`, `troll` für die Auswahlknöpfe der Charaktererstellung (32 px). **Kein Ordner in der Namenskonvention** – müsste ergänzt werden (Vorschlag `races/`).

### 4.7 Porträts – offen
Porträt im Einheitenrahmen (64 × 64): heute Anfangsbuchstabe. Entscheidung nötig: gezeichnete Porträts je Volk/Gegner, oder live gerendertes 3D-Porträt (dann keine Grafik nötig).

---

## 5. Karte und Welt-Markierungen

| Was | Anzeige | Anforderung | Prio |
|---|---|---|---|
| Eigene Position (`MapMarker`) | Karte, ca. 16–24 px | **Pfeil**, wird gedreht (Spitze nach oben im Bild) | P1 |
| Mitspieler | Karte, ca. 10–12 px | weißer Punkt/Form, wird in Klassenfarbe eingefärbt | P1 |
| Wiedereinstiegspunkt | Karte, ca. 16–20 px | eigenes Symbol | P1 |
| Zielkreis am Boden | 3D unter dem Ziel | Textur 256 × 256, weißer Ring auf Transparenz, wird in Gesinnungsfarbe getönt (heute Torus-Mesh) | P1 |
| Bodenziel-Kreis | 3D am Mauszeiger | wie Zielkreis, gern mit Innenmuster; Varianten gültig/ungültig per Farbe | P1 |
| Quest-Symbole „!“ / „?“ (#28 später) | über NPCs | eigenständige Form, nicht WoW-gelb kopieren; verfügbar/abgeschlossen/nicht verfügbar | P2 |

---

## 6. Mauszeiger – P2 (#28, #36, #38)

**Technik:** PNG RGBA, **32 × 32 und 48 × 48** (für 1080p / 1440p; Zeiger werden nicht mit der UI skaliert), je Zeiger die **Klickspitze (Hotspot) in px** angeben. Godot: `Input.set_custom_mouse_cursor`.

| Zeiger | Wann |
|---|---|
| Standard | immer |
| Angreifen | über feindlicher Einheit |
| Sprechen | über NPC mit Gespräch |
| Händler | über Händler |
| Lehrer | über Klassenlehrer |
| Plündern | über Leiche mit Beute |
| Interagieren | Objekt benutzen |
| Nicht möglich | z. B. außer Reichweite (optional) |

---

## 7. Bildschirme und Sonstiges

| Was | Anforderung | Prio |
|---|---|---|
| App-Symbol | heute nicht gesetzt: `.ico` mit 16/32/48/256 px + PNG 512 px für Godot (`config/icon`) | P1 |
| Startbild (Boot-Splash) | PNG 1920 × 1080 (oder Logo auf Fläche) | P1 |
| Logo / Spieltitel | heute Text 64 px; PNG mit Transparenz, ca. 1024 px breit | P1 |
| Hauptmenü-Hintergrund | PNG/JPG 1920 × 1080 (besser 2560 × 1440), mittig ruhig wegen Buttons | P1 |
| Aufstiegsmeldung (#27) | „Stufe 12 erreicht!“ – optional Banner/Glanz-Grafik | P2 |
| Beute-Einblendung (#38) | seltene Funde in Bildschirmmitte – optional Banner | P2 |
| Händler-/Beute-/Dialogfenster (#28, #38) | nutzen Fenster/Slot/Knopf aus Abschnitt 2 + Optionssymbole im Dialog (Sprechen, Handeln, Lernen) als `interface/dialog_*`, 20–24 px | P2 |
| „Nicht nutzbar“-Schleier (#29) | rote Tönung über Item-Icon – reicht als Farbe aus dem Theme, keine Grafik | – |

---

## Empfohlene Reihenfolge
1. **Stilrichtung festlegen** (Abschnitt 2 im Styleguide) – ohne die werden Rahmen doppelt gemacht.
2. Schriften (1) → Fenster, Knopf, Slot, Tooltip (2) → Balken (3): damit sieht das ganze HUD sofort anders aus.
3. Bediensymbole + leere Ausrüstungsplätze + Münzen (4.1, 4.2).
4. Gegenstands-Icons (4.3) und allgemeine Fähigkeiten (4.4).
5. Karte/Weltmarkierungen (5), App-Symbol/Logo/Menühintergrund (7).
6. Mauszeiger und P2-Elemente mit den jeweiligen Tickets.
