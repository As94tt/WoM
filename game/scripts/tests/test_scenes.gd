extends TestSuite
## Rauchtest (Ticket #34): Die Szenen und Skripte, die Kampftext, Kampflog
## und Spielmenü betreffen, lassen sich laden und erzeugen (fängt Parse- und
## Ladefehler, die beim Start ohne Fenster sonst nicht auffallen). Fehler der
## Engine dabei meldet der TestRunner als fehlgeschlagenen Test.

const SCENES := [
	"res://scenes/ui/hud.tscn",
	"res://scenes/ui/hud/message_log.tscn",
	"res://scenes/ui/hud/game_menu.tscn",
	"res://scenes/ui/style_preview.tscn",
]
const SCRIPTS := [
	"res://scripts/world/game_world.gd",
	"res://scripts/combat/unit_caster.gd",
	"res://scripts/player/player_character.gd",
]


func test_szenen_laden() -> void:
	for path: String in SCENES:
		var scene := load(path) as PackedScene
		check(scene != null, "%s lässt sich laden" % path)
		if scene == null:
			continue
		var node := scene.instantiate()
		check(node != null, "%s lässt sich erzeugen" % path)
		if node != null:
			tree.root.add_child(node)
			node.free()


func test_skripte_laden() -> void:
	for path: String in SCRIPTS:
		var script := load(path) as GDScript
		check(script != null and script.can_instantiate(), "%s lässt sich laden" % path)


func test_kampflog_reiter() -> void:
	var log: MessageLog = (load("res://scenes/ui/hud/message_log.tscn") as PackedScene).instantiate()
	tree.root.add_child(log)
	check(not log.is_combat_tab_shown(), "Start im Reiter „Allgemein“")
	var result := HitResult.new()
	result.source_name = "Arthas"
	result.target_name = "Schadenspuppe"
	result.ability_name = "Feuerball"
	result.school = &"feuer"
	result.amount = 1000.0
	log.show_hit(result)
	var lines := log.get_node("%CombatLines") as VBoxContainer
	check_equal(lines.get_child_count(), 1, "Kampfereignis landet im Reiter „Kampf“")
	if lines.get_child_count() > 0:
		var text := (lines.get_child(0) as Label).text
		check(text.ends_with("Arthas: Feuerball trifft Schadenspuppe: 1.000 Schaden (Feuer)"),
				"Zeile im Kampflog mit Uhrzeit davor: %s" % text)
	(log.get_node("%CombatTab") as Button).button_pressed = true
	check(log.is_combat_tab_shown(), "Reiter „Kampf“ umschaltbar")
	log.free()
