extends TestSuite
## Modell und Grundanimationen der Spielfigur (Ticket #59): Gangwahl,
## Phasen Boden/Absprung/Luft/Landen, Startparameter --spielfigur,
## retargetete Library und ein Modell mit Profil-Skelett (hier im Test
## gebaut, damit keine lokale Testfigur nötig ist).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ANIMS: CharacterAnimationSet = preload("res://data/animations/grundanimationen.tres")


func test_library_hat_alle_clips_mit_profil_spuren() -> void:
	check(ANIMS.library != null, "AnimationLibrary geladen")
	if ANIMS.library == null:
		return
	for clip: StringName in [ANIMS.idle, ANIMS.walk, ANIMS.run, ANIMS.sprint, ANIMS.jump_start, ANIMS.jump_air, ANIMS.land]:
		check(ANIMS.library.has_animation(clip), "Clip %s vorhanden" % clip)
	var anim := ANIMS.library.get_animation(ANIMS.run)
	var paths: Array[String] = []
	for i in anim.get_track_count():
		paths.append(String(anim.track_get_path(i)))
	check(paths.has("%GeneralSkeleton:Hips"), "Spuren auf Profil-Knochen abgebildet (Hips)")
	check(paths.has("%GeneralSkeleton:LeftUpperLeg"), "Spuren auf Profil-Knochen abgebildet (LeftUpperLeg)")


func test_volksmodell_ablage() -> void:
	var paths := CharacterModelData.race_model_paths(&"troll")
	check_equal(paths.size(), 2, "Zwei mögliche Ablagen je Volk")
	check_equal(paths[0], "res://lokal/modelle/troll.tres", "Lokales Testmodell zuerst")
	check_equal(paths[1], "res://data/modelle/troll.tres", "Danach Modell aus den Daten")
	check_equal(CharacterModelData.race_model_paths(&"").size(), 0, "Ohne Volk keine Ablage")
	check(CharacterModelData.for_race(&"gibt_es_nicht") == null, "Unbekanntes Volk: Kapsel")


func test_gangwahl() -> void:
	var walk_limit := 2.5 * CharacterAnimator.WALK_TOLERANCE
	var stand := CharacterAnimator.choose_gait(Vector3.ZERO, 1.0, walk_limit, ANIMS)
	check_equal(stand.gait, CharacterAnimator.Gait.STAND, "Ohne Bewegung: Stehen")
	var walk := CharacterAnimator.choose_gait(Vector3(0, 0, -2.5), 1.0, walk_limit, ANIMS)
	check_equal(walk.gait, CharacterAnimator.Gait.WALK, "2,5 m/s vorwärts: Gehen")
	var run := CharacterAnimator.choose_gait(Vector3(0, 0, -7.0), 1.0, walk_limit, ANIMS)
	check_equal(run.gait, CharacterAnimator.Gait.RUN, "7 m/s vorwärts: Laufen")
	check_near(run.time_scale, 7.0 / ANIMS.run_reference_speed, 0.001, "Tempo passt zur Geschwindigkeit")
	check_near(run.facing, 0.0, 0.001, "Vorwärts: Modell nicht gedreht")
	var back := CharacterAnimator.choose_gait(Vector3(0, 0, 4.5), 1.0, walk_limit, ANIMS)
	check_equal(back.gait, CharacterAnimator.Gait.RUN_BACK, "Rückwärts: Laufen rückwärts")
	check_near(back.facing, 0.0, 0.001, "Rückwärts: Modell blickt weiter nach vorn")
	var right := CharacterAnimator.choose_gait(Vector3(7, 0, 0), 1.0, walk_limit, ANIMS)
	check_equal(right.gait, CharacterAnimator.Gait.RUN, "Seitwärts: Laufen")
	check_near(right.facing, -PI / 2.0, 0.001, "Seitwärts rechts: Modell 90 Grad nach rechts")
	var back_left := CharacterAnimator.choose_gait(Vector3(-3, 0, 3), 1.0, walk_limit, ANIMS)
	check_equal(back_left.gait, CharacterAnimator.Gait.RUN_BACK, "Schräg rückwärts: Laufen rückwärts")
	check_near(back_left.facing, -PI / 4.0, 0.001, "Schräg links rückwärts: Modell 45 Grad nach rechts")
	var haste := CharacterAnimator.choose_gait(Vector3(0, 0, -10.0), 1.0, walk_limit, ANIMS)
	check_equal(haste.gait, CharacterAnimator.Gait.SPRINT, "Mit Eile schnell: Sprinten")
	var big := CharacterAnimator.choose_gait(Vector3(0, 0, -7.0), 2.0, walk_limit, ANIMS)
	check(big.time_scale < run.time_scale, "Größeres Modell macht längere Schritte (langsamer abgespielt)")


func test_phasen() -> void:
	var p := CharacterAnimator.PhaseTracker.new()
	var dt := 1.0 / 60.0
	check_equal(p.update(false, false, false, dt, ANIMS), CharacterAnimator.Phase.GROUND, "Start am Boden")
	check_equal(p.update(true, true, false, dt, ANIMS), CharacterAnimator.Phase.JUMP_START, "Sprung: Absprung sofort")
	for i in 40:
		p.update(true, i < 20, false, dt, ANIMS)
	check_equal(p.update(false, false, false, dt, ANIMS), CharacterAnimator.Phase.LAND, "Nach Sprung: Landen")
	for i in int(ANIMS.land_time_standing / dt) + 2:
		p.update(false, false, false, dt, ANIMS)
	check_equal(p.phase, CharacterAnimator.Phase.GROUND, "Landung endet im Stehen")
	# Kurz in der Luft ohne Sprung (Stufe hinunter): kein Fallen, kein Landen.
	p.update(true, false, true, dt, ANIMS)
	check_equal(p.phase, CharacterAnimator.Phase.GROUND, "Kurzer Fall: noch Boden")
	check_equal(p.update(false, false, true, dt, ANIMS), CharacterAnimator.Phase.GROUND, "Kurzer Fall: keine Landung")
	# Lange fallen: Luft, dann Landen; beim Weiterlaufen kurze Landung.
	for i in 30:
		p.update(true, false, true, dt, ANIMS)
	check_equal(p.phase, CharacterAnimator.Phase.AIR, "Langer Fall: Luft")
	check_equal(p.update(false, false, true, dt, ANIMS), CharacterAnimator.Phase.LAND, "Langer Fall: Landen")
	for i in int(ANIMS.land_time_moving / dt) + 2:
		p.update(false, false, true, dt, ANIMS)
	check_equal(p.phase, CharacterAnimator.Phase.GROUND, "Beim Weiterlaufen endet die Landung früh")


func test_startparameter() -> void:
	check_equal(PlayerModelOverride.parse(PackedStringArray()), "", "Ohne Parameter nichts")
	check_equal(PlayerModelOverride.parse(PackedStringArray(["--spielfigur", "res://a.tres"])), "res://a.tres", "Wert nach Leerzeichen")
	check_equal(PlayerModelOverride.parse(PackedStringArray(["--host", "--spielfigur=kapsel"])), "kapsel", "Wert nach =")
	check(PlayerModelOverride.load_model("kapsel") == null, "„kapsel“ = kein Modell")


func test_ohne_modell_bleibt_kapsel() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.name = "1"
	tree.root.add_child(player)
	var animator := player.get_node("Model/Animator") as CharacterAnimator
	check(animator.get_model() == null, "Kein Modell erzeugt")
	check(animator.get_tree_node() == null, "Kein AnimationTree")
	check((player.get_node("Model/Body") as Node3D).visible, "Kapsel sichtbar")
	player.free()


func test_modell_mit_profil_skelett() -> void:
	var data := CharacterModelData.new()
	data.scene = _make_profile_model()
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.name = "1"
	player.model_data = data
	tree.root.add_child(player)
	var animator := player.get_node("Model/Animator") as CharacterAnimator
	check(animator.get_model() != null, "Modell erzeugt")
	check(not (player.get_node("Model/Body") as Node3D).visible, "Kapsel ausgeblendet")
	check_near(animator.get_hip_height(), 1.0, 0.001, "Hüfthöhe aus der Ruhepose")
	var anim_tree := animator.get_tree_node()
	check(anim_tree != null and anim_tree.active, "AnimationTree aktiv")
	if anim_tree != null:
		anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.move_state = PlayerCharacter.MoveState.RUNNING
		player.visual_velocity = Vector3(0, 0, -7.0)
		animator._process(0.1)
		anim_tree.advance(0.1)
		check_equal(String(anim_tree.get("parameters/gang/current_state")), "laufen", "Laufen gewählt")
		check_equal(String(anim_tree.get("parameters/zustand/current_state")), "boden", "Am Boden")
		var skeleton := CharacterAnimator.find_skeleton(animator.get_model())
		var leg := skeleton.find_bone("LeftUpperLeg")
		check(not skeleton.get_bone_pose_rotation(leg).is_equal_approx(skeleton.get_bone_rest(leg).basis.get_rotation_quaternion()),
				"Animation bewegt das Bein (keine Ruhepose)")
		player.move_state = PlayerCharacter.MoveState.JUMPING
		animator._process(0.05)
		anim_tree.advance(0.05)
		check_equal(String(anim_tree.get("parameters/zustand/current_state")), "absprung", "Sprung: Absprung")
	player.free()


func test_zauber_clips_vorhanden() -> void:
	check(ANIMS.has_spell_clips(), "Zauber-Clips im Standardsatz")
	for clip: StringName in [ANIMS.spell_enter, ANIMS.spell_idle, ANIMS.spell_shoot, ANIMS.spell_exit]:
		check(ANIMS.library.has_animation(clip), "Clip %s vorhanden" % clip)
	check_equal(ANIMS.library.get_animation(ANIMS.spell_idle).loop_mode, Animation.LOOP_LINEAR, "Halten läuft in Schleife")
	var leer := CharacterAnimationSet.new()
	leer.library = ANIMS.library
	leer.spell_shoot = &""
	check(not leer.has_spell_clips(), "Ohne Clipname keine Zauber-Animationen")


func test_oberkoerper_filter() -> void:
	var paths: Array[String] = []
	for path in CharacterAnimator.upper_body_tracks(ANIMS):
		paths.append(String(path))
	for bone in ["Chest", "UpperChest", "Neck", "Head", "LeftUpperArm", "RightHand", "LeftIndexProximal", "thumb_04_leaf_l"]:
		check(paths.has("%GeneralSkeleton:" + bone), "Oberkörper enthält %s" % bone)
	for bone in ["Hips", "LeftUpperLeg", "RightLowerLeg", "LeftFoot", "RightToes"]:
		check(not paths.has("%GeneralSkeleton:" + bone), "Oberkörper ohne %s" % bone)


func test_zauber_ablauf_zauberzeit() -> void:
	var s := SpellAnimation.new()
	var dt := 1.0 / 60.0
	check_equal(s.update(dt, ANIMS), SpellAnimation.Stage.NONE, "Anfangs kein Zauber")
	s.begin_cast()
	check_equal(s.stage, SpellAnimation.Stage.ENTER, "Zauberzeit: Heben")
	_run(s, ANIMS.spell_enter_time + 0.05)
	check_equal(s.stage, SpellAnimation.Stage.IDLE, "Danach Halten")
	check_near(s.weight, 1.0, 0.001, "Oberkörper voll eingeblendet")
	_run(s, 3.0)
	check_equal(s.stage, SpellAnimation.Stage.IDLE, "Halten bleibt, solange der Zauber läuft")
	s.end_cast(true)
	check_equal(s.stage, SpellAnimation.Stage.SHOOT, "Erfolg: Loslassen")
	_run(s, ANIMS.spell_shoot_time + 0.02)
	check_equal(s.stage, SpellAnimation.Stage.EXIT, "Danach Senken")
	check_near(s.weight, 1.0, 0.001, "Beim Übergang zum Senken noch voll eingeblendet")
	_run(s, ANIMS.spell_exit_time + ANIMS.spell_blend_time)
	check_equal(s.stage, SpellAnimation.Stage.NONE, "Danach fertig")
	check_near(s.weight, 0.0, 0.001, "Oberkörper wieder ausgeblendet")


func test_zauber_ablauf_kanalisieren_und_abbruch() -> void:
	var s := SpellAnimation.new()
	s.begin_cast()
	_run(s, 1.0)
	s.end_cast(false)
	check_equal(s.stage, SpellAnimation.Stage.EXIT, "Kanalisieren endet mit Senken")
	_run(s, ANIMS.spell_exit_time + ANIMS.spell_blend_time)
	check_equal(s.stage, SpellAnimation.Stage.NONE, "Danach fertig")
	# Abbruch beim Heben und beim Halten: sofort Senken, kein Loslassen.
	s.begin_cast()
	_run(s, 0.1)
	s.abort()
	check_equal(s.stage, SpellAnimation.Stage.EXIT, "Abbruch beim Heben: Senken")
	s.end_cast(true)
	check_equal(s.stage, SpellAnimation.Stage.EXIT, "Ergebnis nach Abbruch: kein Loslassen")
	s.begin_cast()
	_run(s, 1.0)
	s.abort()
	check_equal(s.stage, SpellAnimation.Stage.EXIT, "Abbruch beim Halten: Senken")
	var serial := s.serial
	s.abort()
	check_equal(s.serial, serial, "Zweiter Abbruch ändert nichts")
	s.end_cast(true)
	_run(s, 2.0)
	check_equal(s.stage, SpellAnimation.Stage.NONE, "Ohne Zauber bleibt alles ruhig")
	s.end_cast(true)
	check_equal(s.stage, SpellAnimation.Stage.NONE, "Ergebnis ohne laufenden Zauber: nichts")


func test_zauber_ablauf_sofort() -> void:
	var s := SpellAnimation.new()
	s.instant(false, ANIMS.spell_self_speed)
	check_equal(s.stage, SpellAnimation.Stage.SHOOT, "Sofortzauber: Loslassen")
	_run(s, ANIMS.spell_shoot_time + 0.02)
	check_equal(s.stage, SpellAnimation.Stage.EXIT, "Danach Senken")
	_run(s, ANIMS.spell_exit_time + ANIMS.spell_blend_time)
	check_equal(s.stage, SpellAnimation.Stage.NONE, "Danach fertig")
	# Zweimal hintereinander: Clip beginnt neu.
	s.instant(false, ANIMS.spell_self_speed)
	var serial := s.serial
	s.instant(false, ANIMS.spell_self_speed)
	check(s.serial > serial, "Zweiter Sofortzauber startet Loslassen neu")
	# Selbstzauber: Heben → Senken, schneller.
	s.instant(true, ANIMS.spell_self_speed)
	check_equal(s.stage, SpellAnimation.Stage.ENTER, "Selbstzauber: Heben")
	check_near(s.speed, ANIMS.spell_self_speed, 0.001, "Selbstzauber schneller")
	_run(s, ANIMS.spell_enter_time / ANIMS.spell_self_speed + 0.02)
	check_equal(s.stage, SpellAnimation.Stage.EXIT, "Selbstzauber: dann Senken, kein Halten")
	_run(s, ANIMS.spell_exit_time / ANIMS.spell_self_speed + 0.02)
	check_equal(s.stage, SpellAnimation.Stage.NONE, "Selbstzauber fertig")
	# Ablehnung durch den Host: wie Abbruch.
	s.instant(false, ANIMS.spell_self_speed)
	s.abort()
	check_equal(s.stage, SpellAnimation.Stage.EXIT, "Abgelehnter Sofortzauber: Senken")


func test_zauber_auswahl_aus_daten() -> void:
	var feuerball := GameData.get_ability(&"feuerball")
	var frostnova := GameData.get_ability(&"frostnova")
	var heilung := GameData.get_ability(&"heilende_beruehrung")
	var feld := GameData.get_ability(&"test_feld")
	check(SpellAnimation.animates(feuerball), "Feuerball wird animiert")
	check(SpellAnimation.animates(frostnova), "Frostnova wird animiert")
	check(not SpellAnimation.animates(GameData.get_ability(&"tigerklaue")), "Nahkampf ohne Animation")
	check(not SpellAnimation.animates(GameData.get_ability(&"automatischer_angriff")), "Automatischer Angriff ohne Animation")
	check(not SpellAnimation.animates(GameData.get_ability(&"aufhelfen")), "Aufhelfen (kein Zauber) ohne Animation")
	check(not SpellAnimation.animates(null), "Ohne Fähigkeit keine Animation")
	var caster := Node.new()
	var other := Node.new()
	check(not SpellAnimation.is_self_cast(feuerball, caster, other), "Feuerball auf Feind: fremdes Ziel")
	check(SpellAnimation.is_self_cast(frostnova, caster, caster), "Frostnova (ohne Ziel): Selbstzauber")
	check(SpellAnimation.is_self_cast(heilung, caster, caster), "Heilung auf sich: Selbstzauber")
	check(SpellAnimation.is_self_cast(heilung, caster, null), "Heilung ohne Ziel: Selbstzauber")
	check(not SpellAnimation.is_self_cast(heilung, caster, other), "Heilung auf Mitspieler: fremdes Ziel")
	check(not SpellAnimation.is_self_cast(feld, caster, caster), "Bodenziel: fremdes Ziel (Punkt)")
	caster.free()
	other.free()


func test_zauber_schluessel() -> void:
	var feuerball := GameData.get_ability(&"feuerball")
	check_equal(CharacterAnimator.cast_key({}), "", "Kein Zauber: leer")
	var a := CharacterAnimator.cast_key({"ability": feuerball, "req": 3, "start": 1.0})
	var b := CharacterAnimator.cast_key({"ability": feuerball, "req": 3, "start": 1.2})
	check_equal(a, b, "Vorhersage und Host teilen die Wunsch-Nummer")
	var c := CharacterAnimator.cast_key({"ability": feuerball, "req": 0, "start": 1.0})
	var d := CharacterAnimator.cast_key({"ability": feuerball, "req": 0, "start": 5.0})
	check(c != d, "Ohne Wunsch-Nummer unterscheidet die Startzeit")


func test_sofort_meldung_fremder_figuren() -> void:
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.name = "2"
	tree.root.add_child(player)
	var caster := player.get_caster_node()
	var seen: Array = []
	caster.instant_used.connect(func(ability: AbilityData, target: Unit) -> void: seen.append([ability.id, target]))
	caster.instant_cast = [1, "frostnova", player.get_path(), Network.host_time()]
	check_equal(seen.size(), 1, "Fremde Figur: Meldung vom Host löst instant_used aus")
	if seen.size() == 1:
		check_equal(seen[0][0], &"frostnova", "Richtige Fähigkeit")
		check(seen[0][1] == player, "Ziel aufgelöst")
	caster.instant_cast = [2, "frostnova", NodePath(), Network.host_time() - 5.0]
	check_equal(seen.size(), 1, "Veraltete Meldung wird nicht gezeigt")
	player.free()
	var own := PLAYER_SCENE.instantiate() as PlayerCharacter
	own.name = "1"
	tree.root.add_child(own)
	var own_seen: Array = []
	own.get_caster_node().instant_used.connect(func(_a: AbilityData, _t: Unit) -> void: own_seen.append(true))
	own.get_caster_node().instant_cast = [1, "frostnova", NodePath(), Network.host_time()]
	check_equal(own_seen.size(), 0, "Eigene Figur: Meldung vom Host wird ignoriert (Vorhersage)")
	own.free()


func test_modell_zauber_im_oberkoerper() -> void:
	var data := CharacterModelData.new()
	data.scene = _make_profile_model()
	var player := PLAYER_SCENE.instantiate() as PlayerCharacter
	player.name = "2"
	player.model_data = data
	tree.root.add_child(player)
	var animator := player.get_node("Model/Animator") as CharacterAnimator
	var anim_tree := animator.get_tree_node()
	check(anim_tree != null, "AnimationTree vorhanden")
	if anim_tree == null:
		player.free()
		return
	var root := anim_tree.tree_root as AnimationNodeBlendTree
	check(root.has_node(&"oberkoerper") and root.has_node(&"zauber"), "Zauberknoten im Baum")
	var blend := root.get_node(&"oberkoerper") as AnimationNodeBlend2
	check(blend.filter_enabled, "Oberkörper gefiltert")
	check(blend.is_path_filtered(^"%GeneralSkeleton:LeftUpperArm"), "Arm im Filter")
	check(not blend.is_path_filtered(^"%GeneralSkeleton:LeftUpperLeg"), "Bein nicht im Filter")
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.move_state = PlayerCharacter.MoveState.RUNNING
	player.visual_velocity = Vector3(0, 0, -7.0)
	var caster := player.get_caster_node()
	# Sofortzauber im Laufen (Meldung vom Host für eine fremde Figur).
	caster.instant_cast = [1, "feuerball", NodePath(), Network.host_time()]
	for i in 6:
		animator._process(0.05)
		anim_tree.advance(0.05)
	check_equal(String(anim_tree.get("parameters/zauber/current_state")), "loslassen", "Sofortzauber: Loslassen")
	check_equal(String(anim_tree.get("parameters/gang/current_state")), "laufen", "Beine laufen weiter")
	check(float(anim_tree.get("parameters/oberkoerper/blend_amount")) > 0.9, "Oberkörper eingeblendet")
	var skeleton := CharacterAnimator.find_skeleton(animator.get_model())
	var arm := skeleton.find_bone("LeftUpperArm")
	var spell_arm := ANIMS.library.get_animation(ANIMS.spell_shoot)
	var arm_track := spell_arm.find_track(^"%GeneralSkeleton:LeftUpperArm", Animation.TYPE_ROTATION_3D)
	if arm_track >= 0:
		var expected := spell_arm.rotation_track_interpolate(arm_track, 0.3)
		check(skeleton.get_bone_pose_rotation(arm).is_equal_approx(expected) \
				or skeleton.get_bone_pose_rotation(arm).angle_to(expected) < 0.15, "Arm folgt dem Zauber-Clip")
	for i in 20:
		animator._process(0.05)
		anim_tree.advance(0.05)
	check_near(float(anim_tree.get("parameters/oberkoerper/blend_amount")), 0.0, 0.001, "Danach ausgeblendet")
	# Ablehnung (beim Besitzer) bricht ab.
	caster.instant_cast = [2, "feuerball", NodePath(), Network.host_time()]
	animator._process(0.05)
	caster.instant_rejected.emit(GameData.get_ability(&"feuerball"))
	animator._process(0.05)
	anim_tree.advance(0.05)
	check_equal(animator.get_spell_animation().stage, SpellAnimation.Stage.EXIT, "Ablehnung: Senken")
	check_equal(String(anim_tree.get("parameters/zauber/current_state")), "senken", "Baum: Senken")
	player.free()


func _run(s: SpellAnimation, seconds: float) -> void:
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < seconds:
		s.update(dt, ANIMS)
		t += dt


## Kleines Modell mit Skelett nach SkeletonProfileHumanoid (Rumpf, linker
## Arm und linkes Bein), eindeutiger Name wie nach dem Import.
func _make_profile_model() -> PackedScene:
	var root := Node3D.new()
	root.name = "Testmodell"
	var skeleton := Skeleton3D.new()
	skeleton.name = "GeneralSkeleton"
	root.add_child(skeleton)
	skeleton.owner = root
	skeleton.unique_name_in_owner = true
	var bones := [["Root", -1, Vector3.ZERO], ["Hips", 0, Vector3(0, 1, 0)],
			["LeftUpperLeg", 1, Vector3(0.1, 0, 0)], ["LeftLowerLeg", 2, Vector3(0, -0.5, 0)],
			["Spine", 1, Vector3(0, 0.1, 0)], ["Chest", 4, Vector3(0, 0.2, 0)],
			["LeftUpperArm", 5, Vector3(0.2, 0.2, 0)]]
	for bone: Array in bones:
		var index := skeleton.add_bone(bone[0])
		skeleton.set_bone_parent(index, bone[1])
		skeleton.set_bone_rest(index, Transform3D(Basis(), bone[2]))
	skeleton.reset_bone_poses()
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene
