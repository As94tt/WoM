class_name AbilityIcon
extends RefCounted
## Zeigt eine Fähigkeit auf einem Button mit SlotButton-Aussehen (Ticket #21):
## ihr Icon oder, solange es keins gibt (Graubox), ihr Kürzel als Text
## (AbilityData.get_short_name, z. B. „Fe“ für Feuerball). Ausgegraut wird
## über disabled (SlotButton-Zustand „deaktiviert“), nie über eigene Farben.


static func apply(button: Button, ability: AbilityData) -> void:
	if ability == null:
		button.icon = null
		button.text = ""
		return
	button.icon = ability.icon
	button.expand_icon = ability.icon != null
	# Icons sind 128 px groß und werden auf 40–48 px verkleinert (#55).
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = "" if ability.icon != null else ability.get_short_name()
