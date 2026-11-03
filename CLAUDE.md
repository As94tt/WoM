# CLAUDE.md

## Projekt

Ein Koop-Rollenspiel im Stil von WoW für 1 bis 5 Spieler, mit klassischem Tab-Targeting-Kampf und Comic-Grafik. Zuerst entsteht eine einzelne, kleine Startzone („Vertical Slice“), in der Kampf, Klassen, Ausrüstung, Gegner, Quests und Multiplayer vollständig funktionieren – erst als Graubox, später mit echter Grafik. Erst wenn das überzeugt, wird die Welt gebaut.

**Verbindliche Referenz ist [docs/GDD.md](docs/GDD.md).** Bei Widersprüchen gilt das GDD. Ist etwas im GDD nicht geregelt, nachfragen statt raten.

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
├── docs/              ← GDD.md, später Rig-Konvention
├── art-source/        ← Blender-Arbeitsdateien (.blend) – nur lesen!
└── game/              ← Godot-Projekt (project.godot)
    ├── assets/        ← exportierte Modelle (.glb), Texturen, Audio
    ├── data/          ← Daten als .tres: Fähigkeiten, Auren, Gegenstände, Klassen, Völker, Gegner, Quests
    ├── scenes/        ← Godot-Szenen (.tscn)
    └── scripts/       ← GDScript-Code (.gd)
```

Große Dateien (.blend, .glb, .gltf, .fbx, .png, .jpg, .tga, .exr, .wav, .ogg, .mp3) laufen über Git LFS (siehe `.gitattributes`).

## Verbote

- **Niemals direkt auf `main` pushen.** Jede Änderung läuft über einen eigenen Branch und einen Pull Request.
- **Niemals Dateien in `art-source/` verändern.** Dort liegen die Blender-Arbeitsdateien; sie werden nur gelesen.
- **Keine neuen Abhängigkeiten ohne Rückfrage** (Addons, Plugins, Bibliotheken, Werkzeuge).

## Pull Requests

Jedes Feature beschreibt im Pull Request:

- **wie es sich mit mehreren Spielern verhält** (was macht der Host, was die Clients, was wird synchronisiert) und
- **wie man es mit zwei Spielfenstern testet** (Schritt für Schritt, z. B. zwei Instanzen über das Debug-Menü in Godot starten: eine als Host, eine als Client).
