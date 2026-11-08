class_name TestRunner
extends RefCounted
## Eigener kleiner Test-Runner ohne Fenster (Ticket #34). Startet alle
## Testsammlungen in res://scripts/tests/ (Dateien „test_*.gd“, die
## TestSuite erweitern), gibt je Test „OK“ bzw. „FEHLER“ mit Begründung aus
## und beendet das Programm mit Rückgabewert 0 (alles bestanden) bzw. 1.
##
## Aufruf (wie --daten-pruefen, ausgewertet vom Autoload „Data“):
##   godot --headless --path game -- --tests
## Nur eine Sammlung: zusätzlich --tests=hit_formulas (Teil des Dateinamens).

const TEST_DIR := "res://scripts/tests/"
const PREFIX := "test_"


## Zählt Fehlermeldungen der Engine (z. B. Skriptfehler, die einen Test
## mittendrin abbrechen); ein Test mit neuen Fehlern gilt als fehlgeschlagen.
class ErrorCounter:
	extends Logger

	var errors: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var result := errors
		errors = []
		_mutex.unlock()
		return result


## Führt alle Tests aus und gibt den Rückgabewert zurück (0 = bestanden).
static func run(tree: SceneTree, filter := "") -> int:
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var code := _run_all(tree, filter, counter)
	OS.remove_logger(counter)
	return code


static func _run_all(tree: SceneTree, filter: String, counter: ErrorCounter) -> int:
	var failed := 0
	var passed := 0
	var checks := 0
	for path in _suite_paths(filter):
		var script := load(path) as GDScript
		if script == null:
			printerr("Tests: %s lässt sich nicht laden." % path)
			failed += 1
			continue
		var suite := script.new() as TestSuite
		if suite == null:
			printerr("Tests: %s erweitert nicht TestSuite." % path)
			failed += 1
			continue
		suite.tree = tree
		print("== %s" % path.get_file())
		counter.take()
		suite.before_all()
		var setup_errors := counter.take()
		if not setup_errors.is_empty():
			failed += 1
			printerr("  FEHLER  before_all")
			for message in setup_errors:
				printerr("          - Engine-Fehler: %s" % message)
		for test_name in _test_names(suite):
			suite.call(test_name)
			var failures := suite.take_failures()
			for message in counter.take():
				failures.append("Engine-Fehler: %s" % message)
			if failures.is_empty():
				passed += 1
				print("  OK      %s" % test_name)
			else:
				failed += 1
				printerr("  FEHLER  %s" % test_name)
				for message in failures:
					printerr("          - %s" % message)
		suite.after_all()
		checks += suite.get_check_count()
	print("Tests: %d bestanden, %d fehlgeschlagen (%d Prüfungen)." % [passed, failed, checks])
	return 1 if failed > 0 or passed == 0 else 0


static func _suite_paths(filter: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if not file.begins_with(PREFIX) or not file.ends_with(".gd"):
			continue
		if filter != "" and not file.contains(filter):
			continue
		result.append(TEST_DIR + file)
	result.sort()
	return result


static func _test_names(suite: TestSuite) -> PackedStringArray:
	var result: PackedStringArray = []
	for method: Dictionary in suite.get_method_list():
		var method_name := str(method["name"])
		if method_name.begins_with(PREFIX) and not result.has(method_name):
			result.append(method_name)
	return result
