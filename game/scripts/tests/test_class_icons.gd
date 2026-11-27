extends TestSuite
## Tests der Klassen-Icons (neue Zauber-Icons für Magier und Krieger):
## - jede Magier- und Krieger-Fähigkeit mit Aktionsleisten-Platz (Grundfähigkeit
##   und Variante jeder Spezialisierung) hat ein existierendes Icon unter
##   icons/abilities/mage/ bzw. icons/abilities/warrior/,
## - jedes Icon, das eine Fähigkeit oder Aura nennt, existiert (keine Verweise
##   auf gelöschte Dateien),
## - die alten Zauber-Icons (icons/abilities/<id>.png, icons/auras/) sind weg.

const ICON_ROOT := "res://assets/ui/icons/abilities/"
const CLASSES := {
	"res://data/classes/mage.tres": "mage",
	"res://data/classes/warrior.tres": "warrior",
}


func test_jede_magier_und_krieger_faehigkeit_hat_ein_neues_icon() -> void:
	for class_path: String in CLASSES:
		var data := load(class_path) as ClassData
		var folder := ICON_ROOT + str(CLASSES[class_path]) + "/"
		var abilities: Array[AbilityData] = []
		abilities.append_array(data.abilities)
		for spec in data.specializations:
			for t in spec.transformations:
				abilities.append(t.variant)
		check(abilities.size() >= 7, "%s: Fähigkeiten gefunden" % data.id)
		for ability in abilities:
			check(ability.icon != null, "%s hat ein Icon" % ability.id)
			if ability.icon == null:
				continue
			var path := ability.icon.resource_path
			check(path.begins_with(folder), "%s: Icon %s liegt unter %s" % [ability.id, path, folder])
			check(ResourceLoader.exists(path), "%s: Icon %s existiert" % [ability.id, path])


func test_alle_icons_von_faehigkeiten_und_auren_existieren() -> void:
	for dir in ["res://data/abilities/", "res://data/auras/"]:
		for file in ResourceLoader.list_directory(dir):
			if not file.ends_with(".tres"):
				continue
			var res := load(dir + file)
			var icon: Texture2D = res.get("icon")
			if icon == null:
				continue
			var path := icon.resource_path
			check(ResourceLoader.exists(path), "%s%s: Icon %s existiert" % [dir, file, path])
			check(not path.begins_with("res://assets/ui/icons/auras/"),
					"%s%s: keine alten Aura-Icons mehr (%s)" % [dir, file, path])


func test_alte_zauber_icons_sind_entfernt() -> void:
	for old in ["feuerball", "frostblitz", "blitzpfeil", "magisches_geschoss", "eisschild"]:
		check(not ResourceLoader.exists(ICON_ROOT + old + ".png"), "altes Icon %s entfernt" % old)
	check(not DirAccess.dir_exists_absolute("res://assets/ui/icons/auras"), "Ordner icons/auras entfernt")
