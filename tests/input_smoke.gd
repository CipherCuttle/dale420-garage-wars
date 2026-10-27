extends SceneTree

var game: GarageWarsGame
var results: Array[Dictionary] = []

func _init() -> void:
	call_deferred("run")

func check(label: String, passed: bool) -> void:
	results.append({"test": label, "passed": passed})
	print(("PASS " if passed else "FAIL ") + label)

func key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func tap(code: Key) -> void:
	key(code)
	await frames(2)
	key(code, false)
	await frames(1)

func run() -> void:
	# Small independent clock fixture: no scene, controller, HP or inventory.
	var tuning := GarageConfig.new()
	tuning.transformation_intro = 0.1
	tuning.transformation_seconds = 0.2
	tuning.recovery_seconds = 0.3
	var state := AwakeningState.new(tuning)
	state.begin_encounter("clock_fixture")
	state.family_damage(36, "Lotusmicke", 1, true)
	state.tick(0.1)
	var became_dale := state.is_dale()
	state.tick(0.2)
	var became_recovery := state.mode == AwakeningState.Mode.RECOVERY
	state.tick(0.3)
	check("Configurable intro, transformation and recovery clocks", became_dale and became_recovery and state.mode == AwakeningState.Mode.ERIK)
	state.begin_encounter("clock_fixture")
	check("Re-entering the same encounter does not reset its budget", not state.family_damage(36, "Lotusmicke", 2, true))
	state.begin_encounter("next_encounter")
	check("A new mission encounter can awaken again", state.family_damage(36, "Lotusmicke", 3, true))
	state.reset()
	check("Reset clears fury, clocks, encounter credit and attack IDs", state.mode == AwakeningState.Mode.ERIK and state.meter == 0 and state.remaining == 0 and state.source_credit.is_empty() and state.seen_attacks.is_empty())

	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(2)
	await tap(KEY_ENTER)
	check("Enter starts via Godot's input event routing", game.started and game.running)
	var original := game.player.global_position
	key(KEY_A)
	await frames(20)
	key(KEY_A, false)
	check("WASD physical key events move the native player", game.player.global_position.distance_to(original) > 1.0)
	await tap(KEY_SPACE)
	check("Space triggers dodge through the actual key binding", game.dodges == 1 and game.player.dodge_wait > 0)
	await tap(KEY_SPACE)
	check("Held/repeated dodge cannot bypass its cooldown", game.dodges == 1)
	await tap(KEY_J)
	var punched := game.player.attack_kind == "punch" and game.player.attack_cooldown > 0
	await frames(55)
	await tap(KEY_K)
	check("J and K route to distinct punch and kick actions", punched and game.player.attack_kind == "kick" and game.player.attack_cooldown > 0)
	game.player.hp = 50 # Explicit wounded fixture for the Q binding.
	await tap(KEY_Q)
	check("Q heals through the actual key binding", game.player.hp == 78 and game.player.inventory.joints == 2)
	var old_yaw := game.cam_yaw
	key(KEY_LEFT)
	await frames(12)
	key(KEY_LEFT, false)
	check("Arrow keys orbit the live native camera", game.cam_yaw > old_yaw)
	game.defeat()
	await tap(KEY_R)
	check("R retries from the defeat screen through input routing", not game.dead and game.running and game.mission == game.Mission.HOME and game.player.form.mode == AwakeningState.Mode.ERIK)
	var failed := results.filter(func(result: Dictionary) -> bool: return not result.passed).size()
	var file := FileAccess.open("res://evidence/input-smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "passed": results.size() - failed, "failed": failed, "input": "Input.parse_input_event physical key events through the live SceneTree", "results": results}, "\t"))
	file.close()
	print("INPUT VERDICT %d/%d passed" % [results.size() - failed, results.size()])
	game.queue_free()
	await process_frame
	GarageGeometry.materials.clear()
	quit(1 if failed else 0)
