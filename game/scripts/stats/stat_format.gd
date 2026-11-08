class_name StatFormat
extends RefCounted
## Schreibweise von Werten und Modifikatoren für Anzeige und Tooltips
## (Ticket #19): deutsches Komma, „%“ bzw. „je s“, echtes Minuszeichen.

const MINUS := "−"


## Wert in der Schreibweise seiner Definition, z. B. „120“, „12,5 %“,
## „3,5 je s“.
static func value(definition: StatDefinition, amount: float) -> String:
	if definition == null:
		return number(amount, 0)
	match definition.display:
		StatDefinition.Display.PERCENT:
			return number(amount, 1) + " %"
		StatDefinition.Display.PER_SECOND:
			return number(amount, 1) + " je s"
	return number(amount, 0)


## Wie value(), aber mit Vorzeichen (für Bonus und Malus), z. B. „+50“,
## „−2,5 %“.
static func signed_value(definition: StatDefinition, amount: float) -> String:
	var text := value(definition, absf(amount))
	return ("+" if amount >= 0.0 else MINUS) + text


## Zahl mit decimals Nachkommastellen und deutschem Komma; überflüssige
## Nullen nach dem Komma entfallen nicht, damit Spalten ruhig bleiben.
static func number(amount: float, decimals: int) -> String:
	var text: String
	if decimals <= 0:
		text = str(roundi(amount))
	else:
		text = String.num(amount, decimals)
		if not text.contains("."):
			text += "." + "0".repeat(decimals)
		text = text.replace(".", ",")
	return text.replace("-", MINUS)


## Ganze Zahl mit Tausenderpunkten, z. B. „1.250“ (Lebensbalken, #31).
static func grouped(amount: float) -> String:
	var value := roundi(amount)
	var digits := str(absi(value))
	var parts := PackedStringArray()
	while digits.length() > 3:
		parts.insert(0, digits.substr(digits.length() - 3))
		digits = digits.substr(0, digits.length() - 3)
	parts.insert(0, digits)
	return (MINUS if value < 0 else "") + ".".join(parts)


## Ganze Zahl wie grouped(), aber über threshold abgekürzt (Kampftext, #34):
## „9.999“, „12,3 Tsd.“, „123 Tsd.“, „1,2 Mio.“ (eine Nachkommastelle unter
## 100, darüber keine).
static func short_amount(amount: float, threshold := 10000.0) -> String:
	var value := absf(roundf(amount))
	if value <= threshold:
		return grouped(amount)
	var sign := MINUS if amount < 0.0 else ""
	var unit := "Tsd."
	var scaled := value / 1000.0
	if value >= 1000000.0:
		unit = "Mio."
		scaled = value / 1000000.0
	var text := grouped(floorf(scaled)) if scaled >= 100.0 else number(floorf(scaled * 10.0) / 10.0, 1)
	return "%s%s %s" % [sign, text, unit]


## Kurzer Text eines Modifikators, z. B. „+50 Stärke“ oder „−20 % Kampfkraft“.
static func modifier(stat_name: String, definition: StatDefinition, kind: StatModifier.Kind,
		amount: float) -> String:
	var sign := "+" if amount >= 0.0 else MINUS
	var text: String
	if kind == StatModifier.Kind.PERCENT:
		var whole := is_equal_approx(amount, roundf(amount))
		text = number(absf(amount), 0 if whole else 1) + " %"
	else:
		text = value(definition, absf(amount))
	return "%s%s %s" % [sign, text, stat_name]
