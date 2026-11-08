# Datentabellen – Anleitung

Flache Spieldaten (Gegner, Gegenstände, Beute, Spawns, Werte pro Stufe, Fähigkeitswerte, Konstanten, Völker) stehen in Tabellen, die man mit Excel oder LibreOffice bearbeiten kann. Strukturierte Daten (Aufbau von Fähigkeiten, Auren, Talente, Klassen, Gebiete) bleiben als `.tres` und holen ihre Zahlen aus den Tabellen.

- **Tabellen:** `game/data/tables/<name>.csv`
- **Schemas** (welche Spalten es gibt, Typ, Pflichtfeld, Standardwert, erlaubte Werte): `game/data/schemas/<name>.tres`
- **Spaltenübersicht:** weiter unten in dieser Datei. Sie wird aus den Schemas erzeugt und nicht von Hand geändert.

## 1. Tabellen öffnen und richtig speichern

Die Dateien sind CSV mit **Semikolon** als Trennzeichen und **UTF-8** als Zeichenkodierung.

**Excel**

1. Datei per Doppelklick öffnen. Umlaute und Spalten sollten richtig angezeigt werden.
2. Bearbeiten.
3. Speichern über *Datei → Speichern unter* und als Dateityp **„CSV UTF-8 (durch Trennzeichen getrennt)“** wählen.
   Nicht „CSV (Trennzeichen-getrennt)“ nehmen: Dann gehen die Umlaute kaputt, und das Spiel meldet „Die Datei ist nicht als UTF-8 gespeichert“.
4. Excel nimmt das Trennzeichen aus den Windows-Ländereinstellungen. Bei deutscher Einstellung ist es das Semikolon. Bei englischer Einstellung schreibt Excel Kommas. Dann meldet das Spiel fehlende Spalten.
5. Zahlen mit Komma schreiben (`1,5`). Ein Punkt (`1.5`) wird vom Spiel auch verstanden, aber deutsches Excel macht daraus gern ein Datum.

**LibreOffice Calc**

1. Datei öffnen. Im Fenster „Textimport“: Zeichensatz **Unicode (UTF-8)**, Trennoptionen **nur Semikolon**, Zeichenketten-Trenner `"`.
2. Bearbeiten.
3. Speichern mit *Strg+S* und **„Aktuelles Format beibehalten“** wählen. Wenn LibreOffice nach den Optionen fragt: Feldtrenner `;`, Zeichensatz UTF-8.

**Danach prüfen:** Im laufenden Spiel (Entwicklungsmodus) **F6** drücken oder im Entwickler-Panel (F10) „Tabellen neu laden“ wählen. Ohne das Spiel geht es auch über die Eingabeaufforderung:

```
godot --headless --path game -- --daten-pruefen
```

`godot` steht für das Godot-Programm, z. B. `Godot_v4.7.2-stable_win64_console.exe`. Die Ausgabe ist „alles in Ordnung“ oder eine Fehlerliste.

## 2. So ist eine Tabelle aufgebaut

- **Erste Zeile:** die Spaltennamen. Reihenfolge egal, Namen genau wie in der Übersicht unten.
- **Zeilen mit `#` am Anfang** und **leere Zeilen** ignoriert das Spiel. Sie sind für Kommentare und Gliederung gedacht.
- **Spalte `notiz`:** Jede Tabelle hat sie. Hier kann man frei Anmerkungen schreiben, das Spiel ignoriert sie.
- **IDs:** nur Kleinbuchstaben, Ziffern und `_`, z. B. `wolf_jung`. Eine ID ist innerhalb der Tabelle eindeutig und wird **nie geändert**, denn andere Tabellen und gespeicherte Charaktere verweisen über sie. Namen dagegen darf man jederzeit ändern.
- **Leere Zelle:** Das Spiel nimmt den Standardwert aus der Übersicht. Ein Pflichtfeld darf nicht leer sein.
- **Listen in einer Zelle:** mit `|` trennen, z. B. `feuerball|frostnova`.
- **Werte-Paare in einer Zelle:** `schluessel:wert`, mit `|` getrennt, z. B. `wolf_jung:3|grauschnauze:1`.
- **Ja/Nein:** `ja` oder `nein` (auch `wahr`/`falsch` geht).
- **Text mit Semikolon:** Den Text in Anführungszeichen setzen. Excel und LibreOffice machen das beim Speichern automatisch.

## 3. Beispiele

### Einen neuen Gegner anlegen

1. `gegner.csv` öffnen und eine Zeile ergänzen, z. B.:
   `wolf_alt;Alter Wolf;;tier;normal;feindlich;nahkampf;2;physisch;1,2;1;1;1;5;0;0;;;;wolf_jung;;1;;`
2. Pflicht sind `id`, `name` und `familie`. Für die anderen Spalten gilt der Standardwert, wenn die Zelle leer bleibt.
3. Leben und Schaden stehen nicht beim Gegner. Sie kommen aus `gegner_stufenwerte.csv` (je Stufe), werden mit dem Rang aus `gegner_raenge.csv` multipliziert und mit `leben_mod`, `schaden_mod` usw. angepasst. `1,2` bei `leben_mod` heißt: 20 % mehr Leben.
4. Speichern, F6 drücken bzw. `--daten-pruefen` ausführen.

### Gegner in einem Gebiet erscheinen lassen

1. Das Gebiet muss in `gebiete.csv` stehen (die ID wie in `game/data/zones/`, z. B. `wolfswiese`).
2. In `spawngruppen.csv` eine Gruppe anlegen:
   `wolfswiese_alte;wolfswiese;wolf_alt:1;3;4;2;240;nein;`
   Das heißt: Alte Wölfe der Stufe 3–4, zwei gleichzeitig, sie erscheinen nach 240 s neu und greifen nicht gemeinsam an. Mehrere Gegnertypen mischt man mit Gewichtung, z. B. `wolf_jung:3|wolf_alt:1` (drei von vier sind junge Wölfe).
3. In der Welt verweist ein Spawnbereich auf die ID der Spawngruppe. Er bestimmt nur Ort und Radius. Die Spawnbereiche kommen mit dem Gegner-Ticket (#36).

### Einen neuen Gegenstand anlegen und in eine Beutetabelle aufnehmen

1. In `gegenstaende.csv` eine Zeile ergänzen, z. B. einen Umhang:
   `umhang_wolf;Wolfsumhang;Riecht etwas.;;ausruestung;umhang;gewoehnlich;3;2;stoff;;;;;;;;;;;2;;;;;;;;;;;nein;nein;beim_anlegen;1;15;;;;`
   Rüstung und Waffenschaden dürfen leer bleiben. Sie werden dann aus Gegenstandsstufe, Slot und Rüstungsklasse bzw. Waffentyp berechnet (Gegenstands-Ticket).
2. In `beutetabellen.csv` eine Zeile ergänzen:
   `wolf_jung;umhang_wolf;2;1;1;;;sehr selten`
   Das heißt: Junge Wölfe lassen ihn mit 2 % Chance fallen. Alle Zeilen mit derselben Spalte `tabelle` bilden eine Beutetabelle. Mit `tabelle:<id>` als Eintrag nimmt man eine andere Beutetabelle auf. Einträge mit gleicher `gruppe` schließen sich aus: genau einer davon fällt.

### Einen Zauber schneller oder stärker machen

In `faehigkeitswerte.csv` die Zeile der Fähigkeit suchen, z. B. `feuerball`:

- schneller: `zauberzeit` verkleinern (z. B. `2,5` → `2`), `abklingzeit` verkleinern
- stärker: `grundwert` oder `faktor` erhöhen (Schaden = Grundwert + Faktor × Zaubermacht bzw. Kampfkraft oder Waffenschaden)
- weitere Zahlen stehen in `werte`, z. B. `radius:8` bei der Frostnova

Die `.tres` der Fähigkeit beschreibt nur den Aufbau (welche Effekte), die Zahlen kommen aus dieser Tabelle. So stehen die Zahlen aller Klassen nebeneinander.

### Eine neue Fähigkeit anlegen (#21)

1. In `game/data/abilities/` eine `.tres` vom Typ `AbilityData` anlegen (z. B. eine vorhandene kopieren): `id` (nie ändern, gespeicherte Aktionsleisten verweisen darauf), Name, Beschreibung, optional Icon, Klasse (leer = „Allgemein“), benötigte Stufe, passiv ja/nein.
2. In `faehigkeitswerte.csv` eine Zeile mit derselben `id` ergänzen (Kosten, Ressource, Zauberzeit, Abklingzeit, Reichweite …). Ohne Zeile meldet die Datenprüfung einen Fehler. `klasse` und `stufe` gleich wie in der `.tres` halten; bei Abweichung gilt die `.tres` (Warnung in der Konsole).
3. Die Fähigkeit in die Liste `abilities` der Klasse (`game/data/classes/<klasse>.tres`) bzw. des Reiters „Allgemein“ (`game/data/spellbook/general.tres`) aufnehmen. Dann erscheint sie im Zauberbuch.

### Werte der Charaktere anpassen (Wertesystem #19)

Alle Zahlen des Wertesystems stehen in Tabellen, der Aufbau (welche Formel welche Spalten nutzt, Namen und Tooltips der Werte) in `game/data/stats/stat_rules.tres`. Alle Zahlen sind Platzhalter.

- **Grundwerte je Klasse und Stufe:** `klassenwachstum.csv`. Die Zeile mit Stufe 1 enthält die Grundwerte, jede weitere Zeile den Zuwachs beim Erreichen dieser Stufe. Beispiel: Ein Krieger auf Stufe 3 hat die Stärke aus den Zeilen 1, 2 und 3 zusammen.
- **Volksboni:** Spalten `staerke` bis `willenskraft` in `voelker.csv`; sie werden zu den Klassenwerten addiert.
- **Wertungen in Prozent:** `umrechnung.csv`. Die Spalte nennt, wie viele Punkte einer Wertung 1 % ergeben, z. B. `praezision` = 10 heißt 100 Präzision = 10 % kritische Trefferchance. `ruestung_konstante` ist die Rüstung, bei der der Schaden um 50 % sinkt (abnehmender Ertrag: Verringerung = Rüstung / (Rüstung + Konstante)).
- **Faktoren, Grundwerte, Obergrenzen, Regeneration, Wut und Chi:** `spielkonstanten.csv`, Abschnitte „Wertesystem (#19)“, z. B. `leben_pro_ausdauer`, `obergrenze_krit`, `leben_regen_ausser_kampf`, `chi_verfall_pro_s`.
- **Formeln (Platzhalter):** Leben = Grundleben + `leben_pro_ausdauer` × Ausdauer. Kampfkraft = Grund-Kampfkraft + `kampfkraft_pro_hauptattribut` × Hauptattribut. Zaubermacht = Grund-Zaubermacht + `zaubermacht_pro_intellekt` × Intellekt. Mana = Grundmana + `mana_pro_intellekt` × Intellekt. Prozentwerte = Grundwert + Wertung / Umrechnung, höchstens die Obergrenze. Verfehlen = `verfehlen_grund` + `verfehlen_pro_stufe` × Stufenunterschied, zwischen `verfehlen_min` und `verfehlen_max`.

Testen: Im Spiel C drücken, im Charakterfenster „»“ klicken und im Entwickler-Panel (F10) unter „Werte“ Stufe, Testmodifikatoren usw. ändern. Nach dem Ändern einer Tabelle F6 drücken; die Werte werden sofort mit den neuen Zahlen neu berechnet.

## 4. Was tun bei Fehlermeldungen?

Jede Meldung nennt Datei, Zeile, Spalte und Grund, z. B.:

```
gegner.csv, Zeile 14, Spalte faehigkeiten: Listeneintrag ‚Biss_Stark‘: ‚Biss_Stark‘ ist keine gültige ID (nur Kleinbuchstaben, Ziffern und _).
```

Die Zeilennummer ist die Zeile in der Datei. Kommentar- und Kopfzeilen werden mitgezählt, wie bei der Zeilennummer in Excel.

| Meldung | Was tun |
| --- | --- |
| Pflichtfeld ist leer | Wert eintragen. |
| ‚x‘ ist keine Zahl / keine Ganzzahl | Nur Ziffern, Komma oder Punkt verwenden, ohne Einheit. |
| ‚x‘ ist nicht erlaubt (erlaubt: …) | Einen der genannten Werte nehmen (genau so geschrieben). |
| ‚x‘ ist keine gültige ID | Nur Kleinbuchstaben, Ziffern und `_`. Keine Umlaute, keine Leerzeichen. |
| … gibt es nicht | Tippfehler in der ID? Oder der Eintrag fehlt in der anderen Tabelle. |
| ID ‚x‘ gibt es schon in Zeile n | Jede ID nur einmal verwenden. |
| Endlosschleife: a → b → a | Beutetabellen verweisen im Kreis aufeinander. Einen der Verweise entfernen. |
| Diese Spalte gibt es im Schema nicht / Die Spalte fehlt | Kopfzeile prüfen: Tippfehler oder falsches Trennzeichen (Komma statt Semikolon). |
| Die Zeile hat mehr Zellen als die Kopfzeile Spalten | Ein Semikolon steht im Text. Den Text in `"…"` setzen. |
| Die Datei ist nicht als UTF-8 gespeichert | Neu speichern als „CSV UTF-8“ (siehe Abschnitt 1). |

**Was passiert bei Fehlern?**

- **Beim Spielstart:** Das Spiel startet nicht. Das Hauptmenü zeigt die Fehlerliste. Tabelle korrigieren, speichern und „Neu laden“ drücken.
- **Beim Neu laden (F6) im laufenden Spiel:** Die alten Daten bleiben aktiv. Die Fehler stehen im Log-Bereich unten links und vollständig in der Konsole.

## 5. Neu laden und Mehrspieler

- Neu laden geht nur im Entwicklungsmodus (Editor, Debug-Export): Taste **F6** oder Entwickler-Panel (F10) → „Daten“ → „Tabellen neu laden“.
- Neu erscheinende Gegner, neue Beute, neu gewirkte Fähigkeiten und neue Werteberechnungen nutzen sofort die neuen Werte. Was schon existiert, darf seine alten Werte behalten.
- **Mit Mitspielern ist Neu laden gesperrt.** Es erscheint eine Meldung im Log. Erst die Sitzung verlassen bzw. warten, bis alle Mitspieler weg sind.
- Beim Beitreten vergleicht der Host eine Prüfsumme über alle Tabellen. Weicht sie ab, wird der Beitritt mit „Unterschiedliche Spieldaten“ abgelehnt. Kommentare, Notizen, Zeilenenden und die Schreibweise von Zahlen (`1,5` oder `1.5`) ändern die Prüfsumme nicht.

## 6. Für Entwickler

- **Zugriff** nur über den Autoload `Data`, kein System liest CSV-Dateien selbst. Beispiele: `Data.gegner(&"wolf_jung")`, `Data.konstante(&"gcd")`, `Data.faehigkeitswert(&"frostnova", "werte.radius")`, `Data.beutetabelle(&"wolf_jung")`, `Data.row("tabelle", schluessel)`. Zeilen sind `TableRow` mit Werten im Typ laut Schema. `row.is_blank("spalte")` sagt, ob die Zelle leer war.
- **Wertesystem (#19):** `Data.klassenwerte(&"warrior", 5)` liefert die summierten Klassenwerte einer Stufe, `Data.umrechnung(5)` die Umrechnungszeile, `Data.hoechste_stufe()` die höchste Stufe in `umrechnung.csv`. Gerechnet wird nur in `StatBlock` (`game/scripts/stats/`).
- **Völker** gibt es als `RaceData` über `GameData.get_races()` / `GameData.get_race(id)` bzw. `Data.voelker()`.
- **Verweise auf `.tres`** (Auren, Fähigkeiten, KI-Profile, Klassen, Gebiete) gehen über das Feld `id` der Ressourcen im angegebenen Ordner. Liegen dort noch keine Daten, wird nur das Format der ID geprüft. Sobald es Daten gibt, wird jeder Verweis geprüft.
- **Neue Tabelle:** Schema als `TableSchema` in `game/data/schemas/<name>.tres` anlegen, dazu `game/data/tables/<name>.csv` (Kopfzeile mit allen Spalten und `notiz`) und daneben `<name>.csv.import` mit dem Inhalt `[remap]` / `importer="keep"`. Ohne die `.import`-Datei hält Godot die CSV für eine Übersetzungstabelle und packt sie nicht ins exportierte Spiel. Danach die Spaltenübersicht neu erzeugen:

```
godot --headless --path game -- --daten-doku
```

## 7. Spaltenübersicht

<!-- SPALTEN-ANFANG: automatisch erzeugt mit --daten-doku, nicht von Hand ändern -->

### Gegner

#### gegner.csv – Gegner

Ein Gegnertyp pro Zeile. Kein fester Lebenswert: Leben, Schaden usw. ergeben sich aus der Stufe (vom Spawn), dem Rang (gegner_raenge.csv) und den Modifikatoren.

Eindeutig: `id`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `id` | ID | ja |  |  | Feste ID, wird nie geändert (z. B. wolf_jung). |
| `name` | Text | ja |  |  | Anzeigename. |
| `titel` | Text |  |  |  | Optionaler Titel unter dem Namen, z. B. <Anführer der Banditen>. |
| `familie` | Auswahl | ja |  | `tier`, `humanoid`, `untoter`, `elementar`, `daemon`, `riese` | Familie (für Talente, Fähigkeiten, Immunitäten, Familienbeute). |
| `rang` | Auswahl |  | normal | `normal`, `elite`, `selten`, `boss` | Rang; die Faktoren stehen in gegner_raenge.csv. |
| `gesinnung` | Auswahl |  | feindlich | `feindlich`, `neutral` | feindlich greift an, neutral erst wenn angegriffen. |
| `kampfart` | Auswahl |  | nahkampf | `nahkampf`, `fernkampf`, `zauberwirker` | Art des Kampfes. |
| `angriffstempo` | Kommazahl |  | 2 | 0,1 bis 10 | Sekunden zwischen zwei automatischen Angriffen. |
| `schule` | Auswahl |  | physisch | `physisch`, `feuer`, `frost`, `natur`, `arkan`, `schatten`, `heilig` | Schadensschule des automatischen Angriffs (vorläufige Liste). |
| `leben_mod` | Kommazahl |  | 1 | 0 bis 100 | Faktor auf das Leben aus Stufe und Rang (1 = unverändert). |
| `schaden_mod` | Kommazahl |  | 1 | 0 bis 100 | Faktor auf den Schaden. |
| `ruestung_mod` | Kommazahl |  | 1 | 0 bis 100 | Faktor auf die Rüstung (1,5 = +50 %). |
| `zauberschutz_mod` | Kommazahl |  | 1 | 0 bis 100 | Faktor auf den Zauberschutz. |
| `ausweichen` | Kommazahl |  | 0 | 0 bis 100 | Ausweichchance in Prozent. |
| `parieren` | Kommazahl |  | 0 | 0 bis 100 | Parierchance in Prozent. |
| `blocken` | Kommazahl |  | 0 | 0 bis 100 | Blockchance in Prozent. |
| `immunitaeten` | Liste (ID) |  |  |  | Zustände oder Schulen, gegen die der Gegner immun ist (IDs, z. B. betaeubung\|feuer). |
| `faehigkeiten` | Liste (Verweis) |  |  | Fähigkeit aus `res://data/abilities/` | Fähigkeiten des Gegners (IDs der Fähigkeits-.tres). |
| `ki_profil` | Verweis |  |  | KI-Profil aus `res://data/ai_profiles/` | Verhaltensprofil der KI (ID der KI-Profil-.tres). |
| `beutetabelle` | Verweis |  |  | Beutetabelle aus `beutetabellen.csv` (Spalte `tabelle`) | Optionale eigene Beute (Name in beutetabellen.csv). |
| `modell` | Text |  |  |  | Pfad zum 3D-Modell; leer = Platzhalter-Kapsel. |
| `groesse` | Kommazahl |  | 1 | 0,1 bis 10 | Größenfaktor des Modells. |
| `farbe` | Farbe |  |  |  | Platzhalterfarbe als Hex-Code; leer = Farbe der Familie. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### gegner_stufenwerte.csv – Gegnerwerte pro Stufe

Grundwerte eines normalen Gegners je Stufe. Rang (gegner_raenge.csv) und Modifikatoren (gegner.csv) werden darauf angewendet.

Eindeutig: `stufe`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `stufe` | Ganzzahl | ja |  | 1 bis 100 | Stufe des Gegners. |
| `leben` | Ganzzahl | ja |  | ab 1 | Lebenspunkte. |
| `schaden_min` | Ganzzahl | ja |  | ab 0 | Kleinster Schaden eines automatischen Angriffs. |
| `schaden_max` | Ganzzahl | ja |  | ab 0 | Größter Schaden eines automatischen Angriffs. |
| `ruestung` | Ganzzahl |  |  | ab 0 | Rüstung. |
| `zauberschutz` | Ganzzahl |  |  | ab 0 | Zauberschutz. |
| `erfahrung` | Ganzzahl |  |  | ab 0 | Erfahrung für den Sieg. |
| `geld_min` | Ganzzahl |  |  | ab 0 | Kleinste Geldbeute in Kupfer. |
| `geld_max` | Ganzzahl |  |  | ab 0 | Größte Geldbeute in Kupfer. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### gegner_raenge.csv – Gegnerränge

Faktoren je Rang, mit denen die Stufenwerte multipliziert werden.

Eindeutig: `rang`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `rang` | Auswahl | ja |  | `normal`, `elite`, `selten`, `boss` | Rang. |
| `leben_faktor` | Kommazahl |  | 1 | ab 0 | Faktor auf das Leben. |
| `schaden_faktor` | Kommazahl |  | 1 | ab 0 | Faktor auf den Schaden. |
| `erfahrung_faktor` | Kommazahl |  | 1 | ab 0 | Faktor auf die Erfahrung. |
| `geld_faktor` | Kommazahl |  | 1 | ab 0 | Faktor auf die Geldbeute. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

### Welt

#### gebiete.csv – Gebiete

Flache Werte zu den Gebieten. Die Gebiete selbst (Name, Stufenbereich, Bodenfarbe) bleiben als .tres in res://data/zones/; die ID muss dort existieren.

Eindeutig: `id`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `id` | Verweis | ja |  | Gebiet aus `res://data/zones/` | ID des Gebiets (wie in res://data/zones/). |
| `gebietsbeute` | Verweis |  |  | Beutetabelle aus `beutetabellen.csv` (Spalte `tabelle`) | Beutetabelle für alle Gegner im Gebiet. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### spawngruppen.csv – Spawngruppen

Was in einem Spawnbereich erscheint. Die Spawnbereiche in der Welt bestimmen nur Ort, Radius bzw. feste Punkte und verweisen auf eine Spawngruppe.

Eindeutig: `id`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `id` | ID | ja |  |  | Feste ID der Spawngruppe. |
| `gebiet` | Verweis | ja |  | Gebiet aus `gebiete.csv` | Gebiet der Gruppe. |
| `gegner` | Werte-Paare (Wert: Ganzzahl) | ja |  | ab 1; Schlüssel: Gegner aus `gegner.csv` | Gegner-ID:Gewichtung, z. B. wolf_jung:3\|grauschnauze:1. |
| `stufe_min` | Ganzzahl | ja |  | 1 bis 100 | Niedrigste Stufe der Gegner. |
| `stufe_max` | Ganzzahl | ja |  | 1 bis 100 | Höchste Stufe der Gegner. |
| `anzahl` | Ganzzahl |  | 1 | ab 1 | Wie viele Gegner gleichzeitig. |
| `respawn_s` | Kommazahl |  | 180 | ab 0 | Sekunden bis zum Wiedererscheinen. |
| `gemeinsamer_angriff` | Ja/Nein |  | nein |  | ja = wird einer angegriffen, greifen alle an. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

### Beute

#### beutetabellen.csv – Beutetabellen

Eine Zeile pro Eintrag; alle Zeilen mit gleicher Spalte tabelle bilden eine Beutetabelle. Ein Eintrag ist ein Gegenstand oder eine andere Beutetabelle (tabelle:<id>). Die Spalte bedingung wird gespeichert, aber erst mit dem Beute-Ticket (#38) ausgewertet.

Eindeutig: keine Vorgabe (mehrere Zeilen mit gleichen Werten erlaubt).

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `tabelle` | ID | ja |  |  | Name der Beutetabelle. |
| `eintrag` | Verweis | ja |  | Gegenstand aus `gegenstaende.csv`; oder `tabelle:<id>` aus `beutetabellen.csv` | Gegenstands-ID oder tabelle:<id> für eine verschachtelte Beutetabelle. |
| `chance` | Kommazahl |  | 100 | 0 bis 100 | Chance in Prozent. |
| `anzahl_min` | Ganzzahl |  | 1 | ab 1 | Kleinste Anzahl. |
| `anzahl_max` | Ganzzahl |  | 1 | ab 1 | Größte Anzahl. |
| `gruppe` | ID |  |  |  | Einträge mit gleicher Gruppe: genau einer davon fällt. |
| `bedingung` | Text |  |  |  | Bedingung, z. B. stufe>=5 (wird ab #38 ausgewertet). |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### familienbeute.csv – Familienbeute

Beute, die alle Gegner einer Familie zusätzlich haben können.

Eindeutig: `familie`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `familie` | Auswahl | ja |  | `tier`, `humanoid`, `untoter`, `elementar`, `daemon`, `riese` | Familie. |
| `beutetabelle` | Verweis | ja |  | Beutetabelle aus `beutetabellen.csv` (Spalte `tabelle`) | Beutetabelle der Familie. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### weltbeute.csv – Weltbeute

Zufällige Gegenstände passender Stufe, je Rang und Seltenheit. Beim Tod eines Gegners werden eigene Beute, Familienbeute, Gebietsbeute und Weltbeute zusammengeführt.

Eindeutig: die Kombination `rang` + `seltenheit`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `rang` | Auswahl | ja |  | `normal`, `elite`, `selten`, `boss` | Rang des Gegners. |
| `seltenheit` | Auswahl | ja |  | `gewoehnlich` | Seltenheit (Stufen legt der Projektverantwortliche fest; bis dahin nur gewoehnlich). |
| `chance` | Kommazahl | ja |  | 0 bis 100 | Chance in Prozent. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

### Gegenstände

#### gegenstaende.csv – Gegenstände

Ein Gegenstand pro Zeile. Rüstung und Waffenschaden dürfen leer bleiben; dann werden sie berechnet (Gegenstands-Ticket). Die Prüfung des Wertebudgets folgt mit dem Gegenstands-Ticket.

Eindeutig: `id`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `id` | ID | ja |  |  | Feste ID, wird nie geändert (z. B. schwert_rostig). |
| `name` | Text | ja |  |  | Anzeigename. |
| `beschreibung` | Text |  |  |  | Beschreibung im Tooltip. |
| `icon` | Text |  |  |  | Pfad zum Icon; leer = Platzhalter. |
| `typ` | Auswahl | ja |  | `tasche`, `ausruestung`, `verbrauchsgut`, `material`, `questgegenstand`, `plunder` | Art des Gegenstands. |
| `slot` | Auswahl |  |  | `helm`, `schulter`, `brust`, `guertel`, `beine`, `schuhe`, `handschuhe`, `armschienen`, `umhang`, `ring`, `kette`, `einhand`, `zweihand`, `schild`, `zauberstab`, `fokus`, `fernkampfwaffe`, `siegel`, `talisman` | Ausrüstungsplatz (nur bei Ausrüstung). |
| `seltenheit` | Auswahl |  | gewoehnlich | `gewoehnlich` | Seltenheit (Stufen legt der Projektverantwortliche fest). |
| `gegenstandsstufe` | Ganzzahl |  | 1 | 1 bis 100 | Bestimmt das Wertebudget. |
| `mindeststufe` | Ganzzahl |  | 1 | 1 bis 100 | Mindeststufe zum Anlegen. |
| `ruestungsklasse` | Auswahl |  |  | `stoff`, `leder`, `kette`, `platte` | Nur Rüstungsteile. |
| `waffentyp` | Auswahl |  |  | `dolch`, `schwert`, `axt`, `streitkolben`, `faustwaffe`, `zweihandschwert`, `zweihandaxt`, `kriegshammer`, `kampfstab`, `bogen`, `langbogen`, `kurzbogen`, `armbrust`, `zauberstab`, `schild`, `fokus` | Nur Waffen, Schilde und Fokusse. |
| `handhabung` | Auswahl |  |  | `haupthand`, `nebenhand`, `einhand`, `zweihand`, `fernkampf` | Nur Waffen. |
| `schaden_min` | Ganzzahl |  |  | ab 0 | Kleinster Waffenschaden; leer = aus Gegenstandsstufe und Waffentyp berechnet. |
| `schaden_max` | Ganzzahl |  |  | ab 0 | Größter Waffenschaden; leer = berechnet. |
| `geschwindigkeit` | Kommazahl |  |  | ab 0 | Sekunden pro Waffenschlag. |
| `ruestung` | Ganzzahl |  |  | ab 0 | Rüstung; leer = aus Gegenstandsstufe, Slot und Rüstungsklasse berechnet. |
| `blockwert` | Ganzzahl |  |  | ab 0 | Blockwert (Schilde). |
| `staerke` | Ganzzahl |  |  |  | Stärke. |
| `gewandtheit` | Ganzzahl |  |  |  | Gewandtheit. |
| `intellekt` | Ganzzahl |  |  |  | Intellekt. |
| `ausdauer` | Ganzzahl |  |  |  | Ausdauer. |
| `willenskraft` | Ganzzahl |  |  |  | Willenskraft. |
| `praezision` | Ganzzahl |  |  |  | Präzision. |
| `verheerung` | Ganzzahl |  |  |  | Verheerung. |
| `tempo` | Ganzzahl |  |  |  | Tempo. |
| `durchschlag` | Ganzzahl |  |  |  | Durchschlag. |
| `abwehr` | Ganzzahl |  |  |  | Abwehr. |
| `eile` | Ganzzahl |  |  |  | Eile. |
| `zauberschutz` | Ganzzahl |  |  |  | Zauberschutz. |
| `effekte` | Liste (Verweis) |  |  | Aura aus `res://data/auras/` | Auren, die der Gegenstand verleiht (IDs der Aura-.tres). |
| `klassen` | Liste (Verweis) |  |  | Klasse aus `res://data/classes/` | Nur für diese Klassen; leer = alle. |
| `einzigartig` | Ja/Nein |  | nein |  | Nur einmal im Besitz. |
| `einzigartig_angelegt` | Ja/Nein |  | nein |  | Nur einmal gleichzeitig angelegt. |
| `bindung` | Auswahl |  | keine | `keine`, `beim_aufheben`, `beim_anlegen` | Bindung (vorerst nur Anzeige). |
| `stapelgroesse` | Ganzzahl |  | 1 | ab 1 | Wie viele auf einem Platz. |
| `verkaufswert` | Ganzzahl |  |  | ab 0 | Verkaufswert in Kupfer. |
| `taschenplaetze` | Ganzzahl |  |  | ab 0 | Nur Taschen: Anzahl Plätze. |
| `herkunft` | Text |  |  |  | Herkunftstext (Goldschrift im Tooltip). |
| `modell` | Text |  |  |  | Pfad zum 3D-Modell; leer = Platzhalter je Slot. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### haendler.csv – Händler

Waren der Händler, eine Zeile pro Händler und Gegenstand.

Eindeutig: die Kombination `haendler` + `gegenstand`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `haendler` | ID | ja |  |  | ID des Händlers. |
| `gegenstand` | Verweis | ja |  | Gegenstand aus `gegenstaende.csv` | Angebotener Gegenstand. |
| `preis` | Ganzzahl |  |  | ab 0 | Preis in Kupfer; leer = Standardpreis. |
| `vorrat` | Ganzzahl |  |  | ab 0 | Vorrat; leer = unbegrenzt. |
| `auffuellen_s` | Kommazahl |  |  | ab 0 | Sekunden, bis der Vorrat wieder aufgefüllt ist. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

### Charaktere

#### voelker.csv – Völker

Die spielbaren Völker. Die ID darf nie geändert werden, weil gespeicherte Charaktere sie verwenden.

Eindeutig: `id`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `id` | ID | ja |  |  | Feste ID, unter der Charaktere das Volk speichern (nie ändern!). |
| `name` | Text | ja |  |  | Anzeigename. |
| `beschreibung` | Text |  |  |  | Kurzbeschreibung in der Charaktererstellung. |
| `koerperfamilie` | Auswahl | ja |  | `normal`, `kompakt`, `massiv`, `gross_gebeugt` | Körperfamilie laut GDD (Rig, Animationen, Ausrüstung). |
| `groessenfaktor` | Kommazahl |  | 1 | 0,5 bis 2 | Größe des Platzhaltermodells (Mensch = 1). |
| `reihenfolge` | Ganzzahl |  |  |  | Reihenfolge in Listen. |
| `staerke` | Ganzzahl |  |  |  | Stärke-Bonus des Volks (Platzhalter, wird zu den Klassenwerten addiert). |
| `gewandtheit` | Ganzzahl |  |  |  | Gewandtheit-Bonus des Volks (Platzhalter, wird zu den Klassenwerten addiert). |
| `intellekt` | Ganzzahl |  |  |  | Intellekt-Bonus des Volks (Platzhalter, wird zu den Klassenwerten addiert). |
| `ausdauer` | Ganzzahl |  |  |  | Ausdauer-Bonus des Volks (Platzhalter, wird zu den Klassenwerten addiert). |
| `willenskraft` | Ganzzahl |  |  |  | Willenskraft-Bonus des Volks (Platzhalter, wird zu den Klassenwerten addiert). |
| `volksfaehigkeit` | Verweis |  |  | Aura aus `res://data/auras/` | Volksfähigkeit als dauerhafte Aura (ID der Aura-.tres). |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### klassenwachstum.csv – Klassenwachstum

Wertezuwachs je Klasse und Stufe. Die Zeile mit Stufe 1 enthält die Grundwerte; die Werte einer Stufe sind die Summe aller Zeilen bis zu dieser Stufe. Fehlende Stufen zählen als 0 (Wertesystem #19).

Eindeutig: die Kombination `klasse` + `stufe`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `klasse` | Verweis | ja |  | Klasse aus `res://data/classes/` | Klasse (ID wie in res://data/classes/). |
| `stufe` | Ganzzahl | ja |  | 1 bis 100 | Stufe, die erreicht wird (1 = Grundwerte). |
| `staerke` | Ganzzahl |  |  |  | Stärke-Zuwachs. |
| `gewandtheit` | Ganzzahl |  |  |  | Gewandtheit-Zuwachs. |
| `intellekt` | Ganzzahl |  |  |  | Intellekt-Zuwachs. |
| `ausdauer` | Ganzzahl |  |  |  | Ausdauer-Zuwachs. |
| `willenskraft` | Ganzzahl |  |  |  | Willenskraft-Zuwachs. |
| `leben` | Ganzzahl |  |  |  | Lebenszuwachs. |
| `mana` | Ganzzahl |  |  |  | Manazuwachs. |
| `kampfkraft` | Ganzzahl |  |  |  | Zuwachs der Grund-Kampfkraft (Krieger, Schurke, Mönch; dazu kommt das Hauptattribut). |
| `zaubermacht` | Ganzzahl |  |  |  | Zuwachs der Grund-Zaubermacht (Magier, Druide; dazu kommt der Intellekt). |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### erfahrung.csv – Erfahrungskurve

Benötigte Erfahrung, um von einer Stufe zur nächsten aufzusteigen.

Eindeutig: `stufe`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `stufe` | Ganzzahl | ja |  | 1 bis 100 | Aktuelle Stufe. |
| `benoetigte_erfahrung` | Ganzzahl | ja |  | ab 0 | Erfahrung bis zur nächsten Stufe. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

#### umrechnung.csv – Umrechnung je Stufe

Wie viele Wertungspunkte 1 % ergeben und wie stark Rüstung und Zauberschutz wirken, je Stufe des Charakters (Wertesystem #19). Prozent = Wertung / Spaltenwert der eigenen Stufe.

Eindeutig: `stufe`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `stufe` | Ganzzahl | ja |  | 1 bis 100 | Stufe des Charakters. |
| `praezision` | Kommazahl | ja |  | ab 0,1 | Präzision für 1 % kritische Trefferchance. |
| `verheerung` | Kommazahl | ja |  | ab 0,1 | Verheerung für 1 % kritischen Schaden. |
| `tempo` | Kommazahl | ja |  | ab 0,1 | Tempo für 1 % Tempo. |
| `durchschlag` | Kommazahl | ja |  | ab 0,1 | Durchschlag für 1 % Durchschlag. |
| `abwehr` | Kommazahl | ja |  | ab 0,1 | Abwehr für je 1 % Ausweichen, Parieren und Blocken. |
| `eile` | Kommazahl | ja |  | ab 0,1 | Eile für 1 % Laufgeschwindigkeit. |
| `ruestung_konstante` | Kommazahl | ja |  | ab 0,1 | Rüstungskonstante K: Verringerung = Rüstung / (Rüstung + K); bei Rüstung = K sind es 50 %. |
| `zauberschutz_konstante` | Kommazahl | ja |  | ab 0,1 | Zauberschutzkonstante K, wie bei der Rüstung. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

### Fähigkeiten

#### faehigkeitswerte.csv – Fähigkeitswerte

Die Zahlen aller Fähigkeiten nebeneinander, für das Balancing. Die .tres einer Fähigkeit beschreibt den Aufbau (Effekte, Bedingungen) und liest ihre Zahlen hier, z. B. Data.faehigkeitswert("feuerball", "werte.radius").

Eindeutig: `id`.

Zu jeder Ressource in `res://data/abilities/` muss es eine Zeile geben (sobald dort Daten liegen).

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `id` | Verweis | ja |  | Fähigkeit aus `res://data/abilities/` | ID der Fähigkeit (gleich der ID der Fähigkeits-.tres). |
| `klasse` | Verweis |  |  | Klasse aus `res://data/classes/` | Klasse; leer = keine (z. B. Gegnerfähigkeit). |
| `spezialisierung` | ID |  |  |  | Spezialisierung; leer = alle. |
| `stufe` | Ganzzahl |  | 1 | 1 bis 100 | Stufe, ab der die Fähigkeit gelernt wird. |
| `kosten` | Kommazahl |  |  | ab 0 | Kosten in Einheiten der Ressource. |
| `ressource` | Auswahl |  | keine | `keine`, `mana`, `wut`, `energie`, `chi` | Ressource der Kosten. |
| `zauberzeit` | Kommazahl |  |  | ab 0 | Zauberzeit in Sekunden; 0 = sofort. |
| `kanalisierzeit` | Kommazahl |  |  | ab 0 | Kanalisierzeit in Sekunden. |
| `abklingzeit` | Kommazahl |  |  | ab 0 | Abklingzeit in Sekunden. |
| `aufladungen` | Ganzzahl |  | 1 | ab 1 | Aufladungen. |
| `reichweite` | Kommazahl |  |  | ab 0 | Reichweite in Metern; 0 = Nahkampf bzw. selbst. |
| `grundwert` | Kommazahl |  |  |  | Fester Grundwert (Schaden oder Heilung). |
| `faktor` | Kommazahl |  |  | ab 0 | Faktor auf die Quelle (faktor_quelle). |
| `faktor_quelle` | Auswahl |  |  | `kampfkraft`, `zaubermacht`, `waffe` | Wovon der Faktor abhängt. |
| `dauer` | Kommazahl |  |  | ab 0 | Dauer in Sekunden (Auren, Effekte über Zeit). |
| `tick` | Kommazahl |  |  | ab 0 | Abstand der Ticks in Sekunden. |
| `werte` | Werte-Paare (Wert: Kommazahl) |  |  |  | Alles Weitere als Werte-Paare, z. B. brand_stapel:1\|radius:8. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

### Konstanten

#### spielkonstanten.csv – Spielkonstanten

Alle einzelnen Stellschrauben an einem Ort (z. B. globaler Cooldown, Bedrohungsschwellen, Aggro-Radius).

Eindeutig: `schluessel`.

| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |
| --- | --- | --- | --- | --- | --- |
| `schluessel` | ID | ja |  |  | Name der Konstante. |
| `wert` | Kommazahl | ja |  |  | Wert. |
| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |

<!-- SPALTEN-ENDE -->
