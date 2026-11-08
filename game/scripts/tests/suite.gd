class_name TestSuite
extends RefCounted
## Grundlage einer Testsammlung für den eigenen Test-Runner (Ticket #34,
## Entscheidung: kein GUT, keine neue Abhängigkeit). Eine Sammlung ist ein
## Skript in res://scripts/tests/, dessen Dateiname mit „test_“ beginnt und
## das TestSuite erweitert. Jede Funktion, deren Name mit „test_“ beginnt, ist
## ein Test. Prüfungen mit check(), check_equal() und check_near(); jede
## fehlgeschlagene Prüfung wird mit Text gemeldet, der Test läuft weiter.
##
## before_all()/after_all() laufen einmal vor bzw. nach allen Tests der
## Sammlung (z. B. Einheiten in den Baum hängen und wieder entfernen).
## Start: godot --headless --path game -- --tests (siehe TestRunner).

## Der Szenenbaum (für Tests, die Knoten brauchen).
var tree: SceneTree = null

var _failures: PackedStringArray = []
var _checks := 0


func before_all() -> void:
	pass


func after_all() -> void:
	pass


## Prüfung: condition muss wahr sein.
func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func check_equal(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (erwartet %s, erhalten %s)" % [message, expected, actual])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	check(absf(actual - expected) <= tolerance,
			"%s (erwartet %s ± %s, erhalten %s)" % [message, expected, tolerance, actual])


## Für den Runner: Fehler seit dem letzten Aufruf abholen.
func take_failures() -> PackedStringArray:
	var result := _failures
	_failures = []
	return result


func get_check_count() -> int:
	return _checks
