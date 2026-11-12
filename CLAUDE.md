# CLAUDE.md

## Projekt

Ein Koop-Rollenspiel im Stil von WoW für 1 bis 5 Spieler, mit klassischem Tab-Targeting-Kampf und Comic-Grafik. Zuerst entsteht eine einzelne, kleine Startzone („Vertical Slice“), in der Kampf, Klassen, Ausrüstung, Gegner, Quests und Multiplayer vollständig funktionieren – erst als Graubox, später mit echter Grafik. Erst wenn das überzeugt, wird die Welt gebaut.

**Verbindliche Referenz ist [docs/GDD.md](docs/GDD.md).** Bei Widersprüchen gilt das GDD. Ist etwas im GDD nicht geregelt, nachfragen statt raten.

Für das Aussehen gelten zusätzlich [docs/UI-STYLEGUIDE.md](docs/UI-STYLEGUIDE.md) und [docs/GAME-STYLEGUIDE.md](docs/GAME-STYLEGUIDE.md) (siehe Abschnitt „Styleguides“).

## Technische Grundsätze

Diese fünf Regeln gelten für jedes Feature (wörtlich aus dem GDD):

1. **Engine: Godot 4 mit GDScript.** Szenen, Ressourcen und Skripte sind Textdateien, die Claude Code direkt lesen und bearbeiten kann.
2. **Multiplayer von Anfang an.** Host-Client-Modell: Ein Spieler hostet, bis zu 4 treten bei. Kein eigener Server nötig. Jedes Feature wird netzwerkfähig gebaut, über Godots eingebaute Bausteine (MultiplayerSpawner, MultiplayerSynchronizer). Spielstände liegen beim Host bzw. lokal.
3. **Datengetrieben.** Fähigkeiten, Auren, Gegenstände, Gegner, Klassen, Völker und Quests sind Daten, kein einzeln programmierter Code. Flache Werte-Daten stehen als CSV-Tabellen mit Schema, strukturierte Daten (Effekte, Auren, Fähigkeitslogik, Gebiete) als .tres (Godot-Resources). Neue Inhalte entstehen ohne Code-Änderung.
4. **Effekt- und Aura-System als Kern.** Eine Fähigkeit ist eine Liste von Effekten (Schaden, Heilung, Aura anwenden, Bedrohung, Ressource ändern). Buffs, Debuffs, Kontrolleffekte, Volksfähigkeiten, Talente, Siegel und Talismane sind Auren, auch solche, die auf Ereignisse reagieren (Procs). Talente können Fähigkeiten hinzufügen, verändern und ersetzen.
5. **Graubox zuerst.** Technik wird mit Platzhaltern gebaut (Kapseln, Würfel, graue Blöcke). Grafik ersetzt Platzhalter erst, wenn das System funktioniert.

Godot-Version: **4.7** (Standardversion, nicht .NET), Renderer **Forward+**.

## Datentabellen

- **Flache Spieldaten gehören in die Tabellen unter `game/data/tables/`** (siehe [docs/DATENTABELLEN.md](docs/DATENTABELLEN.md)). Verweise immer über IDs.
- **Nach jeder Änderung an Tabellen `--daten-pruefen` ausführen:** `godot --headless --path game -- --daten-pruefen` (Rückgabewert 1 bei Fehlern). Nach Änderungen an Schemas außerdem `--daten-doku`, damit die Spaltenübersicht in `docs/DATENTABELLEN.md` stimmt.
- **Struktur (Fähigkeiten, Auren, Talente) bleibt in .tres, Zahlen kommen aus den Tabellen.** Klassen und Gebiete bleiben ebenfalls .tres.
- **Zugriff nur über den Autoload `Data`** (`game/scripts/autoload/data.gd`), z. B. `Data.gegner(&"wolf_jung")`, `Data.konstante(&"gcd")`. Kein System liest CSV-Dateien selbst.

## Netzwerk: Der Host entscheidet

- **Spielentscheidungen trifft der Host:** Schaden, Heilung, Beute, Erfahrung, Gegner-KI, Teleports, Wiedereinstieg. Clients senden Wünsche (RPC an den Host, Peer 1) und zeigen die Ergebnisse an, die der Host überträgt. Ein Client verändert nie selbst den Spielzustand anderer.
- **Ausnahme Bewegung:** Jeder Client bewegt seine eigene Figur sofort selbst; der Host prüft sie grob und setzt sie bei Verstößen zurück.
- **Zentrale Stelle ist der Autoload `Network`** (`game/scripts/autoload/network.gd`): `Network.is_host()`, `Network.get_local_peer_id()`, `Network.get_players()`, `Network.get_player(peer_id)`, Signale `player_entered_world`, `player_left_world`, `players_changed`. Neue Systeme bauen keine eigene Verbindung auf.
- **Übertragen** wird über Godots Bausteine: Objekte erzeugt der Host unter einem `MultiplayerSpawner`, Zustand überträgt ein `MultiplayerSynchronizer` (Authority Host, außer der eigenen Bewegung), Wünsche und Ereignisse laufen über `@rpc`. Ohne Sitzung (offline) ist die eigene Instanz der Host; derselbe Code läuft dann ohne Netzwerk.

## Ordnerstruktur

```
WoM/
├── CLAUDE.md          ← diese Regeln
├── .claude/agents/    ← Agenten: refiner (Tickets prüfen), umsetzer (Tickets umsetzen)
├── docs/              ← GDD.md, UI-STYLEGUIDE.md, GAME-STYLEGUIDE.md, DATENTABELLEN.md, später Rig-Konvention
├── art-source/        ← Blender-Arbeitsdateien (.blend) – nur lesen!
├── tools/blender/     ← Blender-Skripte für die Art-Pipeline (z. B. humanoid_rig.py: Skelett nach Godot-Profil)
└── game/              ← Godot-Projekt (project.godot)
    ├── assets/        ← exportierte Modelle (.glb), Texturen, Audio
    │   └── ui/        ← theme.tres (zentrales UI-Theme), fonts/ (Schriften + Lizenzen), icons/<kategorie>/<id>.png
    ├── lokal/         ← nur auf dem eigenen PC (über .git/info/exclude ignoriert), z. B. Testmodelle mit fremder Lizenz – nie committen!
    │   └── modelle/   ← lokale Volksmodelle <volk>.tres, gehen data/modelle/ vor
    ├── data/          ← Daten: strukturierte als .tres (Fähigkeiten, Auren, Klassen, Gebiete, Quests); modelle/<volk>.tres = Volksmodell
    │   ├── tables/    ← flache Werte als CSV-Tabellen (Gegner, Gegenstände, Beute, Völker, Konstanten …)
    │   └── schemas/   ← ein Schema (.tres) pro Tabelle
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
