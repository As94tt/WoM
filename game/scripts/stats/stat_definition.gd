class_name StatDefinition
extends Resource
## Ein Wert des Wertesystems (Ticket #19): Name, Erklärung, Abschnitt im
## Charakterfenster und die Formel, nach der er entsteht. Liegt als
## Unterobjekt in StatRules (res://data/stats/stat_rules.tres).
##
## Die Formel beschreibt nur, welche Werte sie nutzt. Die Zahlen kommen aus
## den Tabellen (klassenwachstum.csv, voelker.csv, umrechnung.csv,
## spielkonstanten.csv), siehe docs/DATENTABELLEN.md.
##
## Reihenfolge: Ein Wert darf nur Werte als Quelle nutzen, die in StatRules
## vor ihm stehen.

## Wie der Grundwert (vor Modifikatoren) entsteht:
## INPUT       – Klassenwert der Stufe (Spalte level_column in
##               klassenwachstum.csv) + Volksbonus (Spalte race_column in
##               voelker.csv); ohne Spalten 0 (z. B. Wertungen, Rüstung).
## LINEAR      – Klassenwert der Stufe (level_column, optional)
##               + Konstante base_key + Konstante factor_key × Quelle.
##               Ohne factor_key zählt die Quelle einfach (Faktor 1).
## RATING      – Konstante base_key + Quelle / Umrechnung der eigenen Stufe
##               (Spalte conversion_column in umrechnung.csv).
## DIMINISHING – 100 × Quelle / (Quelle + K), K = Spalte conversion_column
##               in umrechnung.csv: abnehmender Ertrag (Rüstung).
enum Formula { INPUT, LINEAR, RATING, DIMINISHING }

## Abschnitt im Charakterfenster.
enum Category { ATTRIBUTE, OFFENSE, DEFENSE, RESOURCE, RATING, HIDDEN }

## Anzeige des Werts.
## NUMBER     – ganze Zahl („120“)
## PERCENT    – Prozent mit einer Nachkommastelle („12,5 %“)
## PER_SECOND – je Sekunde mit einer Nachkommastelle („3,5 je s“)
enum Display { NUMBER, PERCENT, PER_SECOND }

## Quelle, die für das Hauptattribut der Klasse steht (ClassData.primary_attribute).
const PRIMARY_SOURCE := &"primary_attribute"

## Feste ID im Code und in Modifikatoren (z. B. &"strength").
@export var id: StringName
## Anzeigename (z. B. „Stärke“).
@export var display_name: String
## Kurze Erklärung für den Tooltip.
@export_multiline var description: String
@export var category: Category = Category.HIDDEN
@export var display: Display = Display.NUMBER
## Reihenfolge innerhalb des Abschnitts (gleich = Reihenfolge in StatRules).
@export var display_order := 0

@export_group("Formel")
@export var formula: Formula = Formula.INPUT
## Wert, aus dem die Formel rechnet (StatDefinition-ID oder
## &"primary_attribute"). Leer = keine Quelle.
@export var source: StringName = &""
## Spalte in klassenwachstum.csv (Summe bis zur Stufe).
@export var level_column := ""
## Spalte in voelker.csv (nur INPUT).
@export var race_column := ""
## Spalte in umrechnung.csv (RATING, DIMINISHING).
@export var conversion_column := ""
## Schlüssel in spielkonstanten.csv für den festen Grundanteil.
@export var base_key := ""
## Schlüssel in spielkonstanten.csv für den Faktor auf die Quelle (LINEAR).
@export var factor_key := ""
## Schlüssel in spielkonstanten.csv für die Obergrenze (leer = keine).
## Gilt nach allen Modifikatoren.
@export var cap_key := ""
## true: Wert wird mit Tempo schneller (× (1 + Tempo % / 100)),
## z. B. Energieregeneration.
@export var scales_with_haste := false

@export_group("Gilt nur, wenn …")
## … es das Hauptattribut der Klasse ist (ClassData.primary_attribute).
@export var requires_primary := false
## … die Klasse diesen Kraftwert hat (ClassData.power_stat).
@export var requires_power: StringName = &""
## … die Klasse diese Ressource hat (ClassData.resources).
@export var requires_resource: StringName = &""
## … dieser Zustand gesetzt ist: &"melee_weapon" oder &"shield".
@export var requires_flag: StringName = &""
