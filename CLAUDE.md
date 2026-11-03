# CLAUDE.md

## Projekt

Ein Koop-Rollenspiel im Stil von WoW für 1 bis 5 Spieler, mit klassischem Tab-Targeting-Kampf und Comic-Grafik. Zuerst entsteht eine einzelne, kleine Startzone („Vertical Slice“), in der Kampf, Klassen, Ausrüstung, Gegner, Quests und Multiplayer vollständig funktionieren – erst als Graubox, später mit echter Grafik. Erst wenn das überzeugt, wird die Welt gebaut.

**Verbindliche Referenz ist [docs/GDD.md](docs/GDD.md).** Bei Widersprüchen gilt das GDD. Ist etwas im GDD nicht geregelt, nachfragen statt raten.

Für das Aussehen gelten zusätzlich [docs/UI-STYLEGUIDE.md](docs/UI-STYLEGUIDE.md) und [docs/GAME-STYLEGUIDE.md](docs/GAME-STYLEGUIDE.md) (siehe Abschnitt „Styleguides“).

## Technische Grundsätze

Diese fünf Regeln gelten für jedes Feature (wörtlich aus dem GDD):

1. **Engine: Godot 4 mit GDScript.** Szenen, Ressourcen und Skripte sind Textdateien, die Claude Code direkt lesen und bearbeiten kann.
2. **Multiplayer von Anfang an.** Host-Client-Modell: Ein Spieler hostet, bis zu 4 treten bei. Kein eigener Server nötig. Jedes Feature wird netzwerkfähig gebaut, über Godots eingebaute Bausteine (MultiplayerSpawner, MultiplayerSynchronizer). Spielstände liegen beim Host bzw. lokal.
3. **Datengetrieben.** Fähigkeiten, Auren, Gegenstände, Gegner, Klassen, Völker und Quests sind Daten (Godot-Resources, .tres), kein einzeln programmierter Code. Neue Inhalte entstehen ohne Code-Änderung.
4. **Effekt- und Aura-System als Kern.** Eine Fähigkeit ist eine Liste von Effekten (Schaden, Heilung, Aura anwenden, Bedrohung, Ressource ändern). Buffs, Debuffs, Kontrolleffekte, Volksfähigkeiten, Talente, Siegel und Talismane sind Auren, auch solche, die auf Ereignisse reagieren (Procs). Talente können Fähigkeiten hinzufügen, verändern und ersetzen.
5. **Graubox zuerst.** Technik wird mit Platzhaltern gebaut (Kapseln, Würfel, graue Blöcke). Grafik ersetzt Platzhalter erst, wenn das System funktioniert.

Godot-Version: **4.7** (Standardversion, nicht .NET), Renderer **Forward+**.

## Ordnerstruktur

```
WoM/
├── CLAUDE.md          ← diese Regeln
├── .claude/agents/    ← Agenten: refiner (Tickets prüfen), umsetzer (Tickets umsetzen)
├── docs/              ← GDD.md, UI-STYLEGUIDE.md, GAME-STYLEGUIDE.md, später Rig-Konvention
├── art-source/        ← Blender-Arbeitsdateien (.blend) – nur lesen!
└── game/              ← Godot-Projekt (project.godot)
    ├── assets/        ← exportierte Modelle (.glb), Texturen, Audio
    │   └── ui/        ← theme.tres (zentrales UI-Theme), fonts/ (Schriften + Lizenzen)
    ├── data/          ← Daten als .tres: Fähigkeiten, Auren, Gegenstände, Klassen, Völker, Gegner, Quests
    ├── scenes/        ← Godot-Szenen (.tscn); UI-Szenen in scenes/ui/
    └── scripts/       ← GDScript-Code (.gd); UI-Skripte in scripts/ui/
```

Große Dateien (.blend, .glb, .gltf, .fbx, .png, .jpg, .tga, .exr, .wav, .ogg, .mp3) laufen über Git LFS (siehe `.gitattributes`).

## Styleguides

- **UI (aktueller Fokus):** Jedes UI-Element nutzt `game/assets/ui/theme.tres` und folgt `docs/UI-STYLEGUIDE.md`. Keine Farben oder Schriften direkt im Code festlegen.
  - Solange `theme.tres` noch fehlt, keine neuen Farb- oder Schrift-Overrides in Szenen oder Code anlegen. Das Theme entsteht in einem eigenen Ticket.
  - Bis zur Freigabe der Stilrichtung enthält das Theme nur neutrale Platzhalterwerte (Graubox, `StyleBoxFlat`).
- **Spielgrafik (Leitlinie für später):** `docs/GAME-STYLEGUIDE.md` beschreibt das Zielbild für Welt, Charaktere, Ausrüstung und Effekte. Solange Graubox gilt, ist er Orientierung, keine Pflicht für Platzhalter. Bei Datenstrukturen (z. B. Seltenheit, Klassen, Effekte) aber schon jetzt mitdenken.
- **Offene Entscheidungen:** Werte, die in den Styleguides als **OFFEN** oder **TBD** markiert sind, trifft nur der Projektverantwortliche. Agenten erfinden keine endgültigen Farben, Schriften oder Stilrichtungen.
- **Styleguides aktuell halten:** Ändert ein Pull Request etwas am Aussehen (Theme, Farbtoken, Schriften, UI-Komponenten, Art-Regeln), wird der betroffene Styleguide **im selben Pull Request** angepasst. Widerspricht eine Änderung einem Styleguide, vorher nachfragen.
- **Keine Kopien:** Keine Grafiken, Rahmen, Icons oder markanten Motive aus WoW oder anderen Spielen. Schriften nur frei lizenziert (bevorzugt SIL OFL 1.1), mit Lizenz im Repo.

## Verbote

- **Niemals direkt auf `main` pushen.** Jede Änderung läuft über einen eigenen Branch und einen Pull Request.
- **Niemals Dateien in `art-source/` verändern.** Dort liegen die Blender-Arbeitsdateien; sie werden nur gelesen.
- **Keine neuen Abhängigkeiten ohne Rückfrage** (Addons, Plugins, Bibliotheken, Werkzeuge).

## Pull Requests

Jedes Feature beschreibt im Pull Request:

- **wie es sich mit mehreren Spielern verhält** (was macht der Host, was die Clients, was wird synchronisiert) und
- **wie man es mit zwei Spielfenstern testet** (Schritt für Schritt, z. B. zwei Instanzen über das Debug-Menü in Godot starten: eine als Host, eine als Client).

Betrifft ein Pull Request das Aussehen, nennt er außerdem, welcher Styleguide angepasst wurde (oder warum keiner).
