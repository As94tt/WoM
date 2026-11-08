# Game Design Document – WoW-artiges Koop-RPG

Nov 3, 2026 · @Alexander Dominik Sorg

## Vision

Ein Koop-Rollenspiel im Stil von WoW für 1 bis 5 Spieler, mit klassischem Tab-Targeting-Kampf und Comic-Grafik. Statt einer offenen Massenwelt entsteht zuerst eine einzelne, kleine Startzone, in der alle Systeme vollständig funktionieren (Vertical Slice). Erst wenn Kampf, Klassen, Ausrüstung und Multiplayer dort überzeugen, wird die Welt gebaut.

**Designsäulen**

- **Gemeinsam stärker:** Klassenrollen (Tank, Heiler, Schaden) ergänzen sich; das Spiel ist auf Gruppen bis 5 Spieler ausgelegt, bleibt aber solo spielbar.
- **Sichtbarer Fortschritt:** Fast jede Ausrüstung ist am Charakter zu sehen. Seltene Trophäen am Gürtel zeigen, was ein Spieler erreicht hat.
- **Spielstil durch Entscheidungen:** Unterklassen, Siegel und Talismane verändern, wie sich eine Klasse spielt, nicht nur ihre Zahlenwerte.
- **Erst funktionieren, dann schön:** Technik wird mit Platzhaltern gebaut, Grafik folgt in einer eigenen Spur.

## Technische Grundsätze

Diese fünf Regeln gelten für jedes Feature und gehören wörtlich in die CLAUDE.md, damit alle Agenten danach arbeiten.

1. **Engine: Godot 4 mit GDScript.** Szenen, Ressourcen und Skripte sind Textdateien, die Claude Code direkt lesen und bearbeiten kann.
2. **Multiplayer von Anfang an.** Host-Client-Modell: Ein Spieler hostet, bis zu 4 treten bei. Kein eigener Server nötig. Jedes Feature wird netzwerkfähig gebaut, über Godots eingebaute Bausteine (MultiplayerSpawner, MultiplayerSynchronizer). Spielstände liegen beim Host bzw. lokal.
3. **Datengetrieben.** Fähigkeiten, Auren, Gegenstände, Gegner, Klassen, Völker und Quests sind Daten, kein einzeln programmierter Code. Flache Werte-Daten stehen als CSV-Tabellen mit Schema, strukturierte Daten (Effekte, Auren, Fähigkeitslogik, Gebiete) als .tres (Godot-Resources). Neue Inhalte entstehen ohne Code-Änderung.
4. **Effekt- und Aura-System als Kern.** Eine Fähigkeit ist eine Liste von Effekten (Schaden, Heilung, Aura anwenden, Bedrohung, Ressource ändern). Buffs, Debuffs, Kontrolleffekte, Volksfähigkeiten, Talente, Siegel und Talismane sind Auren, auch solche, die auf Ereignisse reagieren (Procs). Talente können Fähigkeiten hinzufügen, verändern und ersetzen.
5. **Graubox zuerst.** Technik wird mit Platzhaltern gebaut (Kapseln, Würfel, graue Blöcke). Grafik ersetzt Platzhalter erst, wenn das System funktioniert.

## Kampfsystem

Klassisches Tab-Targeting nach WoW-Vorbild: Man wählt ein Ziel, Fähigkeiten treffen es, solange es in Reichweite und Sichtlinie ist. Kein Zielen mit der Maus.

| Bereich | Regel |
| --- | --- |
| Zielauswahl | Tab-Taste oder Anklicken; Freund- und Feindziele |
| Rhythmus | Globaler Cooldown ca. 1,5 s nach jeder Fähigkeit; eigene Abklingzeiten pro Fähigkeit |
| Zauberarten | Zauberzeit (bricht bei Bewegung ab), Kanalisieren, Sofortzauber (auch in Bewegung) |
| Automatischer Angriff | Für Nahkämpfer, solange ein Feind anvisiert ist |
| Trefferwürfel | Verfehlt, ausgewichen, pariert, geblockt, Treffer, kritischer Treffer |
| Schadensarten | Körperlich (Rüstung reduziert) und magisch (Widerstand reduziert) |
| Unterbrechen | Zauber mit Zauberzeit sind unterbrechbar; gegen Sofortzauber hilft nur Stille |
| Bedrohung | Gegner greifen an, wer die meiste Bedrohung erzeugt; Tanks können spotten |
| Positionierung | Manche Angriffe nur von hinten; Parieren und Blocken nur von vorne |
| Kontrolle | Einfrieren, Betäuben, Stille als Auren mit Laufzeit |
| Tod | Wiederbelebung durch Mitspieler oder Rückkehr zum Wiedereinstiegspunkt |

## Klassen

Fünf Grundklassen decken alle Kernmechaniken ab. Sie werden in dieser Reihenfolge eingeführt, weil jede auf den Mechaniken der vorherigen aufbaut. Fähigkeitsnamen sind Platzhalter.

| Reihenfolge | Klasse | Rolle | Ressource | Testet vor allem | Test-Fähigkeiten |
| --- | --- | --- | --- | --- | --- |
| 1 | Magier | Fernkampf-DD | Mana | Zauberzeit, Unterbrechen, Projektile, Fläche, Kontrolle | Feuerball, Frostnova, Gegenzauber |
| 2 | Krieger | Tank | Wut (baut sich im Kampf auf) | Bedrohung, Spott, Blocken/Parieren, Nahkampf | Schildschlag, Spott, Kampfschrei |
| 3 | Druide | Heiler | Mana | Verbündete anvisieren, Heilung über Zeit, Gruppenheilung | Verjüngung, Heilende Berührung, Wildwuchs |
| 4 | Schurke | Nahkampf-DD | Energie + Combopunkte | Aufbauen/Ausgeben, Positionierung, Tarnung | Finsterer Stoß, Ausweiden, Verstohlenheit |
| 5 | Mönch | Nahkampf-DD mit Sofortzaubern | Energie + Chi | Schadensarten, Zaubern in Bewegung, Procs, Bewegungsfähigkeiten | Tigerklaue, Blitzfaust, Fliegender Tritt |

**Schurke und Mönch unterscheiden sich klar:** Der Schurke ist der Präzisionskämpfer (Combopunkte am Ziel, Positionierung, Finisher). Der Mönch ist der Fluss-Kämpfer: Schläge erzeugen Chi, Sofortzauber geben es aus, Abwechslung zwischen Fähigkeiten wird belohnt.

**Unterklassen** kommen später über Talente und sollen die Klassen deutlich unterscheiden. Ein Talent kann Fähigkeiten hinzufügen, verändern oder ersetzen und sogar Rolle und Ressource wechseln (z. B. Druide als Bär-Tank). Das Effekt- und Aura-System muss das von Anfang an tragen.

## Völker

Sechs Völker zum Start, jeweils männlich und weiblich: 12 spielbare Körper auf einem gemeinsamen Skelett. Für Rig, Animationen und Ausrüstung zählen die vier Körperfamilien, nicht die Zahl der Völker.

| Körperfamilie | Völker | Merkmale | Aufwand |
| --- | --- | --- | --- |
| Normal | Mensch, Hochelf, Dunkelelf | Ähnliche Proportionen; Elfen schlanker und größer | Gering: teilen fast alle Animationen und Ausrüstung |
| Kompakt | Zwerg | Klein, breit, kurze Beine, große Hände | Mittel: eigene Laufanimationen, angepasste Ausrüstung |
| Massiv | Ork | Groß, breite Schultern, muskulös | Mittel: wuchtigere Animationen, breitere Rüstung |
| Groß und gebeugt | Troll | Lange Arme, gebückte Haltung, große Füße | Hoch: Härtetest für Rig, Retargeting und Ausrüstung |

- **Referenzpaar:** Mensch männlich und weiblich. An diesem Paar wird die ganze Pipeline gebaut und getestet.
- **Produktionsreihenfolge danach:** Elfen, dann Zwerg und Ork, zuletzt Troll. Der Troll wird früh mit einer einfachen Testfigur geprüft.
- **Volksfähigkeiten** sind dauerhafte Auren (z. B. Frostwiderstand), kein eigener Code.
- **Keine Fraktionen:** Alle Völker können zusammen spielen.
- **Volk-Klasse-Kombinationen:** In der Testphase alle erlaubt; Einschränkungen später als Daten-Regel.
- **Charakter-Anpassung** (Gesichter, Frisuren, Hautfarben) kommt später als eigene Ebene.

## Ausrüstung

Bis auf den Schmuck ist jede Ausrüstung am Charakter sichtbar und muss auf alle 12 Körper passen.

| Gruppe | Slots | Sichtbar | Wo am Körper |
| --- | --- | --- | --- |
| Rüstung | Helm, Schulter, Brust, Gürtel, Beine, Schuhe, Handschuhe, Armschienen, Umhang | Ja | Verformt mit dem Körper; Umhang schwingt über eigene Knochen |
| Schmuck | Ring 1, Ring 2, Kette | Nein | – |
| Nahkampf | Einhand, Zweihand, Schild | Ja | Hände; außerhalb des Kampfes Rücken/Gürtel |
| Fernkampf | Zauberstab, Fokus, Fernkampfwaffe | Ja | Hände; außerhalb des Kampfes Rücken/Gürtel |
| Spezial | Siegel, Talisman 1–3 | Ja | Siegel als Brosche an der Brust; Talismane als Trophäen am Gürtel |

**Waffenlogik:** Haupthand und Nebenhand. Zweihandwaffen belegen beide, Schild und Fokus nur die Nebenhand. Schurke und Mönch können zwei Einhandwaffen führen.

**Rüstungsklassen:** Stoff (Magier), Leder (Schurke, Mönch, Druide), Platte (Krieger). Kette später für neue Klassen oder Unterklassen.

**Spielstil-Gegenstände, klar abgegrenzt:**

- **Talente / Unterklasse:** bestimmen Rolle und Grundfähigkeiten.
- **Siegel (1):** großer Eingriff, verändert eine Kernfähigkeit grundlegend. Leuchtet beim Einsatz auf; die Fähigkeit bekommt einen Effekt in Siegelfarbe.
- **Talismane (3):** Kriegstrophäen, selten und prestigeträchtig. Kleinere Veränderungen an einzelnen Fähigkeiten, kombinierbar. Nur über Leistungen erhältlich (seltene Bossbeute, schwere Herausforderungen, Erfolge), jeweils mit kurzer Herkunftsgeschichte im Tooltip.

**Gürtel und Trophäen:** Der Gürtel ist ein eigener Slot und Träger der drei Talismane. Ist er leer, erscheint eine schlichte Standard-Kordel, damit Trophäen immer sichtbar bleiben. Talismane schwingen beim Laufen mit (einfache Pendel-Physik).

**Technische Regeln:** Jeder Helm legt fest, was er verdeckt (Haare, Ohren, Hauer); manche Völker brauchen Helmvarianten. Der Körper ist in Zonen geteilt, die Rüstungsteile ausblenden, damit nichts durchscheint. Jeder Gegenstand ist ein Datensatz: Slot, Rüstungsklasse, Werte, Effekte, Seltenheit, 3D-Modell.

## Art-Pipeline und Rig

Ein gemeinsames Skelett für alle 12 Körper: identische Knochenhierarchie und -namen, Unterschiede nur in der Ruhepose (Knochenlängen und -positionen). Die Knochennamen werden so gewählt, dass sie sich in Godot sauber auf das Humanoid-Profil (SkeletonProfileHumanoid) abbilden lassen.

**Befestigungspunkte, die von Anfang an im Skelett sind:**

- Hände: Waffen, Schild, Fokus
- Rücken und Gürtel: Waffen außerhalb des Kampfes
- Umhang-Knochen am Rücken (physikalisch nachschwingend)
- Drei Trophäenplätze an der Hüfte (Talismane), Position pro Körper einmal eingestellt
- Brust: Siegel
- Kopf: Helm

**Animationen:** Generische Animationen (Emotes, Zauber) werden über Godots Retargeting geteilt. Körpertypische Animationen (Idle, Laufen, Kampf) entstehen pro Körperfamilie und Geschlecht, realistisch etwa 8 Sets. Animationen arbeiten mit Rotationen; Root und Hüfte werden auf die Körpergröße skaliert, Füße und Hände per IK korrigiert.

**Ausrüstungsanpassung:** Jedes verformbare Teil wird einmal auf dem Referenzkörper modelliert, Gewichte werden automatisch übertragen (Data Transfer), Varianten für die anderen Körper entstehen über Shape Keys. Ein Skript erzeugt die 12 Varianten; Nacharbeit von Hand ist einzuplanen. Starre Teile (Helm, Waffen, Talismane) hängen an Knochen.

**Werkzeuge und Export:** Blender für Modellierung, Rig und Animation, mit Claude über Blender-MCP. Export als glTF (.glb) nach Godot. Arbeitsdateien liegen in art-source/, exportierte Dateien in game/assets/.

## Startzone

Die Startzone ist bewusst klein: Sie enthält jedes System genau einmal, mit minimalem Inhalt.

- **Trainingsbereich** mit Übungspuppen zum Testen von Fähigkeiten und Werten
- **Kleines Gebiet** mit 2–3 Gegnertypen (Nahkampf, Fernkampf, Zauberwirker)
- **Questgeber** mit einfachen Quests (töte X, sammle Y)
- **Kleiner Boss** als Gruppentest für Tank, Heiler und Schaden
- **Wiedereinstiegspunkt** für Tod und Wiederbelebung

Zuerst komplett als Graubox, im Meilenstein M6 mit echter Grafik.

## Meilensteine

Nach M5 ist die Startzone technisch ein vollständiges kleines Spiel, nur noch grau. Dort wird ehrlich geprüft, ob sich der Kampf gut anfühlt, bevor viel Zeit in Grafik fließt.

**Technik-Spur**

1. **M0 Fundament:** Repo, Git LFS, CLAUDE.md, Agenten, Godot-Projekt. *Fertig, wenn* ein Test-Ticket den ganzen Workflow durchläuft.
2. **M1 Zwei Kapseln:** Netzwerk und Bewegung. *Fertig, wenn* zwei Spieler sich gegenseitig herumlaufen sehen.
3. **M2 Kampfkern:** Zielauswahl, Effekt- und Aura-System, UI, Klassen in der Reihenfolge Magier, Krieger, Druide, Schurke, Mönch. *Fertig, wenn* alle fünf Klassen gegen Übungspuppen funktionieren.
4. **M3 Gegner:** NPC-KI, Bedrohung, Tod, Respawn, Beute. *Fertig, wenn* ein Gegner angreift, getötet wird und etwas fallen lässt.
5. **M4 Fortschritt:** Erfahrung, Stufen, Inventar, Ausrüstung. *Fertig, wenn* ein Spieler aufsteigen und ein Item anlegen kann.
6. **M5 Quests und Gruppe:** Questgeber, Gruppe, Speichern. *Fertig, wenn* eine Gruppe gemeinsam eine Quest abschließt und speichert.
7. **M6 Startzone:** Graubox durch Grafik ersetzen. *Fertig, wenn* ein Volk mit Rig, Animationen und Ausrüstung durch die Zone spielt.

**Kunst-Spur (parallel)**

1. Basis-Skelett mit Godot-kompatiblen Knochennamen und allen Befestigungspunkten
2. Referenzpaar Mensch männlich und weiblich, Körper in Zonen geteilt
3. Grundanimationen: Idle, Laufen, Angriff, Zaubern, Tod
4. Troll-Testfigur als Härtetest für Rig und Retargeting
5. Erste Ausrüstungsteile mit Skript für die 12 Varianten

## Entwicklungsworkflow

Ein einziges Git-Repo (Monorepo) enthält Spiel, Kunst-Arbeitsdateien, Dokumentation und Agenten. Große Dateien (.blend, .glb, Texturen) laufen über Git LFS, das gleich zu Beginn eingerichtet wird.

```
mein-spiel/
├── CLAUDE.md          ← Regeln für alle Agenten
├── .claude/agents/    ← Refiner, Umsetzer
├── docs/              ← dieses GDD, Rig-Konvention
├── art-source/        ← Blender-Arbeitsdateien
└── game/              ← Godot-Projekt
    ├── assets/        ← exportierte Modelle (.glb), Texturen
    ├── data/          ← Fähigkeiten, Auren, Klassen (.tres); flache Werte als CSV-Tabellen
    ├── scenes/
    └── scripts/
```

**Kanban-Ablauf**

1. **Ideas:** freie Ideen, nur von dir.
2. **Backlog:** von dir fertig durchdachte Tickets, inklusive Verhalten im Multiplayer.
3. **Refinement:** Der Refiner-Agent prüft gegen dieses GDD, stellt Rückfragen als Kommentar und ergänzt die technische Umsetzung. Er ändert keinen Code.
4. **Umsetzung:** Der Umsetzungs-Agent arbeitet auf einem eigenen Branch, baut das Feature und öffnet einen Pull Request mit Zusammenfassung und Screenshots.
5. **Freigabe:** Du testest (bei Multiplayer-Features mit zwei Spielfenstern) und genehmigst den Pull Request.
6. **Implementierung:** Eine normale GitHub-Action ohne KI aktualisiert, testet und merged in Main. Nur bei Merge-Konflikten hilft ein Agent.
7. **Done:** Ticket wird automatisch geschlossen.

**Regeln:** Branch Protection auf Main, nur genehmigte Pull Requests werden gemergt. Der Refiner nutzt ein günstigeres Modell, die Umsetzung das stärkste. Agenten werden zuerst von Hand lokal aufgerufen und erst danach an Label-Trigger gehängt. Für Jobs mit Blender und Godot läuft ein Self-hosted Runner auf dem eigenen PC.

## Werkzeuge und Accounts

Empfehlung: GitHub statt GitLab und Jira. GitHub vereint Repo, Kanban-Board (GitHub Projects), Pull Requests und Automatisierung (GitHub Actions mit der offiziellen Claude-Code-Action) unter einem Account. Jira und GitLab funktionieren auch, bedeuten aber mehr Accounts und mehr Einrichtung.

| Werkzeug | Wofür | Account nötig | Status |
| --- | --- | --- | --- |
| Claude (Pro oder Max) | Claude Code, Agenten | Ja, vorhanden | Pflicht |
| Claude Desktop (Tab „Code“) | Claude Code ohne Kommandozeile | Claude-Account | Pflicht (oder Claude Code im Terminal) |
| GitHub | Repo, Board, Pull Requests, Actions | Ja, github.com | Pflicht |
| Git mit Git LFS | Versionsverwaltung, große Dateien | Nein | Pflicht |
| GitHub Desktop | Git per Oberfläche statt Kommandozeile | GitHub-Account | Empfohlen für Einsteiger |
| Godot 4 (Standardversion, nicht .NET) | Engine | Nein | Pflicht |
| Blender | Modellierung, Rig, Animation | Nein | Pflicht |
| uv | Wird von der Blender-MCP-Verbindung benötigt | Nein | Pflicht für Blender-MCP |
| Blender-MCP-Addon | Claude steuert Blender | Nein | Pflicht für Blender-MCP |
| Visual Studio Code | Code und Dateien ansehen | Nein | Optional (Godot hat einen eigenen Skript-Editor) |
| Jira / GitLab | Board bzw. Repo | Ja | Nicht nötig |

Godot, Blender, Git, uv und VS Code sind kostenlos und brauchen keinen Account. Claude Code kann beim Einrichten von Git LFS, Blender-MCP und dem Godot-Projekt helfen.

## Offene Punkte

Keiner dieser Punkte blockiert M0 bis M2.

- [ ] Name und Hintergrundgeschichte der Welt
- [ ] Grafikstil der Startzone (Farbwelt, Detailgrad)
- [ ] Talentsystem im Detail (Anzahl, Freischaltung)
- [ ] Seltenheitsstufen und Werte der Gegenstände
- [ ] Stufenobergrenze und Erfahrungskurve
- [ ] Verbindung übers Internet (z. B. Steam), nach lokalem Multiplayer

## Quellen

- [Claude Code mit Pro- oder Max-Plan nutzen](https://support.claude.com/de/articles/11145838-claude-code-mit-deinem-pro-oder-max-plan-nutzen)
- [MCP for Blender (GitHub)](https://github.com/ahujasid/mcp-for-blender/wiki)
