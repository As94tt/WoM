class_name QuickStart
extends RefCounted
## Startparameter für schnelles Testen ohne Menüs (Ticket #30):
##   --host                 startet direkt als Host
##   --join <IP>            tritt direkt bei (z. B. --join 127.0.0.1)
##   --port <Port>          anderer Port als der Standard (optional)
##   --character <Name>     nimmt einen gespeicherten Charakter; fehlt er oder
##                          gibt es ihn nicht, wird ein Testcharakter erzeugt
## Die Parameter dürfen vor oder nach „--“ stehen (z. B. im Editor unter
## Debug → Ausführungsinstanzen anpassen → Startargumente).

enum Mode { NONE, HOST, JOIN }

var mode: Mode = Mode.NONE
var address := ""
var port := 0
var character_name := ""


## Liest die Startparameter des laufenden Spiels.
static func from_command_line() -> QuickStart:
	var args := PackedStringArray()
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	return parse(args)


static func parse(args: PackedStringArray) -> QuickStart:
	var qs := QuickStart.new()
	var i := 0
	while i < args.size():
		var arg := args[i]
		var value := ""
		if arg.contains("="):
			value = arg.get_slice("=", 1)
			arg = arg.get_slice("=", 0)
		elif i + 1 < args.size() and not args[i + 1].begins_with("--"):
			value = args[i + 1]
		match arg:
			"--host":
				qs.mode = Mode.HOST
			"--join":
				qs.mode = Mode.JOIN
				qs.address = value if value != "" else "127.0.0.1"
			"--port":
				qs.port = value.to_int()
			"--character":
				qs.character_name = value
		i += 1
	return qs


## Der gewählte gespeicherte Charakter oder ein neuer Testcharakter.
func get_character() -> CharacterData:
	if character_name != "":
		for c in CharacterStore.list_all():
			if c.character_name.nocasecmp_to(character_name) == 0:
				return c
		push_warning("Startparameter: Charakter „%s“ nicht gefunden, nehme einen Testcharakter." % character_name)
	return CharacterData.make_test_character()
