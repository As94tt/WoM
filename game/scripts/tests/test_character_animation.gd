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


## Kleines Modell mit Skelett nach SkeletonProfileHumanoid (nur Rumpf und
## linkes Bein), eindeutiger Name wie nach dem Import.
func _make_profile_model() -> PackedScene:
	var root := Node3D.new()
	root.name = "Testmodell"
	var skeleton := Skeleton3D.new()
	skeleton.name = "GeneralSkeleton"
	root.add_child(skeleton)
	skeleton.owner = root
	skeleton.unique_name_in_owner = true
	var bones := [["Root", -1, Vector3.ZERO], ["Hips", 0, Vector3(0, 1, 0)],
			["LeftUpperLeg", 1, Vector3(0.1, 0, 0)], ["LeftLowerLeg", 2, Vector3(0, -0.5, 0)]]
	for bone: Array in bones:
		var index := skeleton.add_bone(bone[0])
		skeleton.set_bone_parent(index, bone[1])
		skeleton.set_bone_rest(index, Transform3D(Basis(), bone[2]))
	skeleton.reset_bone_poses()
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene
