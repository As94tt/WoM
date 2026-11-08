class_name DeathWindow
extends PanelContainer
## Fenster „Ihr seid gestorben“ (Ticket #35), oben mittig im HUD. Erscheint,
## solange die eigene Figur tot ist, und verschwindet, sobald sie wieder lebt.
##
## - Knopf „Am Wiedereinstiegspunkt erscheinen“: Wunsch an den Host
##   (RevivalService.request_release), Rückkehr mit 50 % und „Geschwächt“.
## - Darüber ein Hinweis: ob ein Mitspieler helfen kann („Warten auf Hilfe“),
##   bzw. bei „alle tot“ der Countdown bis zur gemeinsamen Rückkehr.
## - Hilft jemand (Aufhelfen, Wiederbelebung), erscheint die Anfrage
##   „X möchte Euch aufhelfen.“ mit „Annehmen“ und „Ablehnen“.
## Rein lokal; was gilt, entscheidet der Host.

var _player: Unit = null
var _revival: RevivalService = null


func _ready() -> void:
	%ReleaseButton.pressed.connect(_on_release)
	%AcceptButton.pressed.connect(_on_answer.bind(true))
	%DeclineButton.pressed.connect(_on_answer.bind(false))
	visible = false
	set_process(false)


## Eigene Figur und Dienst verbinden (GameWorld, sobald die Figur da ist).
func setup(player: Unit, revival: RevivalService) -> void:
	_player = player
	_revival = revival
	var combat := player.get_combat() if player != null else null
	if combat != null:
		combat.death_changed.connect(_on_death_changed)
	if revival != null:
		revival.offer_changed.connect(func(_name: String) -> void: _refresh())
		revival.all_dead_changed.connect(func(_at: float) -> void: _refresh())
	_on_death_changed(player != null and player.is_dead())


func _process(_delta: float) -> void:
	_refresh()


func _on_death_changed(dead: bool) -> void:
	visible = dead
	set_process(dead)
	if dead:
		_refresh()


func _refresh() -> void:
	if not visible or _player == null or not is_instance_valid(_player):
		return
	var offer := _revival.local_offer if _revival != null else ""
	%OfferBox.visible = offer != ""
	%OfferLabel.text = "%s möchte Euch aufhelfen." % offer
	var release_at := _revival.local_release_at if _revival != null else -1.0
	if release_at >= 0.0:
		var seconds := maxi(0, ceili(release_at - Network.host_time()))
		%InfoLabel.text = "Alle Spieler sind gestorben. Rückkehr zum Wiedereinstiegspunkt in %d s." % seconds
	elif _revival != null and _revival.can_anyone_help(_player):
		%InfoLabel.text = "Warten auf Hilfe: Ein Mitspieler kann Euch aufhelfen."
	else:
		%InfoLabel.text = "Niemand kann Euch gerade aufhelfen."


func _on_release() -> void:
	if _revival != null:
		_revival.request_release()


func _on_answer(accept: bool) -> void:
	if _revival != null:
		_revival.answer_offer(accept)
	_refresh()
