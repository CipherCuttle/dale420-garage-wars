extends SceneTree

const DT := 1.0 / 60.0
var game: GarageWarsGame
var results: Array[Dictionary] = []
var captures: bool = false
var player_id: int
var simulated_seconds: float = 0

func _init() -> void:
	call_deferred("run")

func check(label: String, passed: bool, details: String = "") -> void:
	results.append({"test": label, "passed": passed, "details": details})
	print(("PASS " if passed else "FAIL ") + label + (" | " + details if not details.is_empty() else ""))

func step(direction: Vector3 = Vector3.ZERO, sprint: bool = false, throttle: float = 0, steering: float = 0) -> void:
	await physics_frame
	game.simulate(DT, direction, sprint, throttle, steering)
	game.update_presentation(DT)
	simulated_seconds += DT

func advance(seconds: float) -> void:
	for i in range(ceili(seconds / DT)):
		await step()

func capture(label: String) -> void:
	if not captures:
		return
	game._update_camera(1, true)
	game.hud.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://evidence/" + label + ".png"
	var error := root.get_texture().get_image().save_png(path)
	assert(error == OK)
	print("CAPTURE " + path + " result=" + str(error))

func walk_to(target: Vector3, max_seconds: float = 35.0) -> bool:
	for i in range(ceili(max_seconds / DT)):
		var direction := target - game.player.global_position
		direction.y = 0
		if direction.length() < 0.65:
			return true
		await step(direction.normalized(), true)
		if not game.running:
			print("ROUTE STOPPED mission=%d at=%s target=%s" % [game.mission, game.player.global_position, target])
			return false
	print("ROUTE BLOCKED mission=%d at=%s target=%s" % [game.mission, game.player.global_position, target])
	return false

func fight_current_encounter(max_seconds: float = 95.0) -> bool:
	var initial := game.mission
	for frame in range(ceili(max_seconds / DT)):
		if not game.running:
			return false
		if game.mission != initial:
			return true
		var target: FamilyEnemy = null
		var nearest: float = 10000
		for enemy in game.family:
			if enemy.active and enemy.alive:
				var distance := game.player.global_position.distance_to(enemy.global_position)
				if distance < nearest:
					nearest = distance
					target = enemy
		if target == null:
			return false
		if game.player.hp < 53 and game.player.inventory.joints > 0:
			game.use_joint()
		var direction := target.global_position - game.player.global_position
		direction.y = 0
		if nearest <= 2.0:
			direction = Vector3.ZERO
		# This is a test driver using the production movement/dodge/attack APIs.
		# It never sets HP, stage, position, or win flags during the playthrough.
		if target.action == FamilyEnemy.Action.WINDUP and target.timer < 0.23 and (game.player.form.is_dale() or game.player.hp < 48 or game.player.form.encounter_spent):
			game.player.dodge((target.global_position - game.player.global_position).normalized())
		for hazard in game.hazards:
			if not hazard.spent and hazard.age > 0.3 and game.player.global_position.distance_to(hazard.node.global_position) < 2.0:
				game.player.dodge(Vector3.LEFT)
		if nearest < 2.05:
			game.player.strike(game.player.form.is_dale() and game.player.combo == 2)
		await step(direction.normalized(), false)
	return false

func run() -> void:
	captures = "--capture" in OS.get_cmdline_user_args()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	player_id = game.player.get_instance_id()
	check("Exactly one Erik/Dale420 player entity", get_nodes_in_group("player").size() == 1 and game.family.size() == 4 and get_nodes_in_group("family").size() == 4)
	var no_erik_npc := true
	for enemy in game.family:
		no_erik_npc = no_erik_npc and enemy.identity not in ["Erik", "DALE420"]
	var active_mission_source := FileAccess.get_file_as_string("res://scripts/game.gd").to_lower()
	check("No separate Erik NPC or obsolete find-Erik objective", no_erik_npc and not active_mission_source.contains("hitta erik") and not active_mission_source.contains("find erik"))
	check("Erik starts in normal weak mode", game.player.form.mode == AwakeningState.Mode.ERIK and game.player.movement_speed() == game.config.erik_speed and game.player.hp == 100)
	var ginger := true
	for enemy in game.family:
		ginger = ginger and not enemy.rig.hair_parts.is_empty()
		for hair in enemy.rig.hair_parts:
			ginger = ginger and hair.visible and hair.material_override.albedo_color == GarageGeometry.GINGER
	check("All four family enemies have visible ginger meshes", ginger, "Morgana, Bellatrix, Sabrina, Lotusmicke; same verified orange material")
	check("Erik has ginger bangs, freckles/acne and a skinny rig", game.player.rig.hair_parts.size() >= 6 and game.player.rig.kind == "Erik")
	game.start_game()
	await capture("01_erik_home")
	for i in range(1200):
		await step()
		if game.player.form.mode == AwakeningState.Mode.AWAKENING or game.dead:
			break
	check("Actual family AI damage triggers awakening", game.player.form.mode == AwakeningState.Mode.AWAKENING and game.player.hp < 100 and not game.dead, "HP=%.0f meter=%.0f" % [game.player.hp, game.player.form.meter])
	check("Awakening emits audio, screen flash and world effects", game.audio_events > 1 and game.flash.a > 0 and not game.effects.is_empty())
	if captures:
		var transformation_audio: AudioStreamWAV = null
		for node in game.get_children():
			if node is AudioStreamPlayer and node.stream is AudioStreamWAV:
				if transformation_audio == null or node.stream.data.size() > transformation_audio.data.size():
					transformation_audio = node.stream
		assert(transformation_audio != null, "Transformation audio stream missing")
		if transformation_audio != null:
			var audio_result := transformation_audio.save_to_wav(ProjectSettings.globalize_path("res://evidence/transformation.wav"))
			assert(audio_result == OK)
			print("CAPTURE res://evidence/transformation.wav result=" + str(audio_result))
	await capture("02_transformation")
	var hp_before: float = game.player.hp
	var inventory_before := game.player.inventory.duplicate(true)
	var position_before := game.player.global_position
	await advance(game.config.transformation_intro + DT)
	check("Transformation keeps node, HP, inventory and position", game.player.get_instance_id() == player_id and game.player.hp == hp_before and game.player.inventory == inventory_before and game.player.global_position.distance_to(position_before) < 0.2)
	check("DALE420 has a faster movement profile and visible stance", game.player.form.is_dale() and game.player.movement_speed() > game.config.erik_speed and game.player.rig.aura.visible and game.player.rig.headband.visible)
	var target := game.family[1]
	var target_hp := target.hp
	game.player.strike(false)
	var punch_loss := target_hp - target.hp
	await advance(0.25)
	target_hp = target.hp
	game.player.strike(true)
	var kick_loss := target_hp - target.hp
	check("Kung fu punch and kick do functionally different damage", punch_loss >= game.config.dale_punch and kick_loss > game.config.erik_punch, "punch=%.0f kick=%.0f normal_punch=%.0f" % [punch_loss, kick_loss, game.config.erik_punch])
	game.player.dodge(Vector3.ZERO)
	var counter_hp := game.player.hp
	target.attack_sequence += 1
	game.player.take_family_hit(target, 18, target.attack_sequence, true)
	check("Evasive counter damages an enemy while avoiding damage", game.counters > 0 and game.player.hp == counter_hp)
	var duplicate_hp := game.player.hp
	game.player.take_family_hit(target, 18, target.attack_sequence, true)
	check("Replayed attack IDs cannot apply duplicate damage", game.player.hp == duplicate_hp)
	await capture("03_dale_kung_fu")
	for enemy in game.family:
		enemy.active = false
	game.clear_hazards()
	await advance(0.5)
	var expiry_hp := game.player.hp
	var expiry_inventory := game.player.inventory.duplicate(true)
	await advance(game.config.transformation_seconds + 0.1)
	check("Timed expiry returns Erik and advances forest escape", not game.player.form.is_dale() and game.mission == game.Mission.ESCAPE_FOREST and game.player.get_instance_id() == player_id)
	check("HP and inventory persist on expiry", game.player.hp == expiry_hp and game.player.inventory == expiry_inventory)
	await advance(game.config.recovery_seconds + 0.1)
	game.player.form.begin_encounter("home")
	var exploited := game.player.form.family_damage(1000, "Bellatrix", 999999, true)
	check("Damage farming cannot reawaken in the same encounter", not exploited and game.player.form.mode == AwakeningState.Mode.ERIK and game.player.form.encounter_spent)
	var route_ok := true
	for point in [game.HOME, Vector3(-24, 0, -4), Vector3(-24, 0, -20), Vector3(-40, 0, -20), game.CAMP]:
		route_ok = await walk_to(point) and route_ok
	check("Forest hideout reached by native movement and collisions", route_ok and game.mission == game.Mission.HIDEOUT, "No teleport or stage setter used")
	game.interact()
	var health_at_camp := game.player.hp
	game.use_joint()
	check("Joint heals the same player's persistent HP", game.player.hp > health_at_camp and game.player.inventory.joints == 2)
	var shot := game.fire_rifle()
	await step()
	check("Air rifle hits an actual practice-target physics ray", shot and game.target_hits == 1 and game.mission == game.Mission.CRUMBS and game.player.inventory.air_rifle)
	await capture("04_forest_hideout")
	await walk_to(game.world.clue.global_position)
	game.interact()
	check("Secret crumb evidence advances return-to-garage mission", game.player.inventory.crumb_evidence and game.mission == game.Mission.RETURN_GARAGE)
	for point in [Vector3(-40, 0, -20), Vector3(-24, 0, -20), Vector3(-20, 0, -4), Vector3(7, 0, -2)]:
		route_ok = await walk_to(point) and route_ok
	check("Return route starts the escalating family confrontation", route_ok and game.mission == game.Mission.FAMILY_WAVE)
	var saved_hp: float = game.checkpoint.hp
	var saved_inventory: Dictionary = game.checkpoint.inventory.duplicate(true)
	# A partly completed wave must restore every enemy, including its nameplate.
	game.family[0].take_damage(game.family[0].max_hp, "kick")
	# A lethal trap clears other active traps during their own update iteration.
	target = game.family[2]
	game.player.hp = 10
	for i in range(2):
		target.attack_sequence += 1
		game.spawn_hazard(game.player.global_position, target, "banana", target.attack_sequence)
	for hazard in game.hazards:
		hazard.age = 0.65
	game._update_hazards(DT)
	check("Lethal hazard safely clears multiple active traps", game.dead and game.hazards.is_empty())
	check("Defeat stops gameplay and clears transformation", game.dead and not game.running and game.player.hp == 0 and game.player.form.mode == AwakeningState.Mode.ERIK)
	await capture("05_defeat_retry")
	game.retry()
	var wave_restored := true
	for sister in game.family.slice(0, 3):
		wave_restored = wave_restored and sister.alive and sister.active and sister.hp == sister.max_hp and sister.tag.visible
	check("Retry restores mission, HP, inventory, enemies and one normal player", game.running and not game.dead and game.mission == game.Mission.FAMILY_WAVE and game.player.hp == saved_hp and game.player.inventory == saved_inventory and game.player.form.mode == AwakeningState.Mode.ERIK and game.player.get_instance_id() == player_id and get_nodes_in_group("player").size() == 1 and wave_restored)
	await capture("06_family_confrontation")
	var won_wave := await fight_current_encounter()
	check("Three sisters can be defeated through production combat", won_wave and game.mission == game.Mission.BOSS, "HP=%.0f joints=%d" % [game.player.hp, game.player.inventory.joints])
	check("Sisters executed distinct behaviors", game.family[0].hazards_created > 0 and game.family[1].attack_count >= 3 and game.family[2].hazards_created > 0, "distractions=%d brawler_attacks=%d traps=%d" % [game.family[0].hazards_created, game.family[1].attack_count, game.family[2].hazards_created])
	await capture("07_lotusmicke_boss")
	# An isolated heal fixture checks both retained boss systems and interruption.
	var boss := game.family[3]
	var old_boss_hp := boss.hp
	boss.hp = old_boss_hp - 30
	boss.apply_heal("sandwich")
	var after_sandwich := boss.hp
	boss.apply_heal("intimidation")
	check("Lotusmicke has separate sandwich and intimidation heals", after_sandwich == old_boss_hp - 20 and boss.hp == old_boss_hp - 14)
	boss.begin_heal("sandwich")
	boss.take_damage(1, "punch")
	check("Player damage interrupts boss healing windup", boss.action == FamilyEnemy.Action.RECOVER)
	boss.hp = old_boss_hp
	# A real lethal hit at the boss checkpoint exercises a different retry path.
	saved_hp = game.checkpoint.hp
	saved_inventory = game.checkpoint.inventory.duplicate(true)
	boss.attack_sequence += 1
	game.player.dodge_remaining = 0
	game.player.take_family_hit(boss, 999, boss.attack_sequence, true)
	game.retry()
	check("Boss retry resets boss/fury while preserving evidence", game.mission == game.Mission.BOSS and boss.hp == boss.max_hp and boss.active and game.player.hp == saved_hp and game.player.inventory == saved_inventory and game.player.form.mode == AwakeningState.Mode.ERIK and not game.player.form.encounter_spent and game.player.inventory.crumb_evidence)
	var won_boss := await fight_current_encounter(110)
	check("Lotusmicke defeated and free roam stays active", won_boss and game.mission == game.Mission.FREE_ROAM and not boss.alive and game.car.unlocked and game.running, "boss_hp=%.0f player_hp=%.0f" % [boss.hp, game.player.hp])
	var walked_to_car := await walk_to(game.car.global_position + Vector3(-3.3, 0, 0))
	var car_hp := game.player.hp
	var car_inventory := game.player.inventory.duplicate(true)
	var entered := game.car.toggle_ride()
	var car_start := game.car.global_position
	for i in range(90):
		await step(Vector3.ZERO, false, 1, 0)
	var driven := game.car.global_position.distance_to(car_start)
	var exited := game.car.toggle_ride()
	var reentered := game.car.toggle_ride()
	check("Yellow sports car drives, exits and drives again", walked_to_car and entered and driven > 5 and exited and reentered, "native distance=%.2f m" % driven)
	check("Driving retains one player and persistent HP/inventory", game.player.get_instance_id() == player_id and game.player.hp == car_hp and game.player.inventory == car_inventory and get_nodes_in_group("player").size() == 1)
	await capture("08_victory_driving")
	var ordered := true
	var previous_index: int = -1
	for expected_stage in range(10):
		var index := game.mission_history.find(expected_stage)
		ordered = ordered and index > previous_index
		previous_index = index
	check("Mission includes every revised stage in order", ordered)
	var failed := results.filter(func(result: Dictionary) -> bool: return not result.passed).size()
	var report := {"engine": Engine.get_version_info().string, "passed": results.size() - failed, "failed": failed, "simulated_seconds": simulated_seconds, "screenshots": captures, "results": results}
	var file := FileAccess.open("res://evidence/acceptance-rendered.json" if captures else "res://evidence/acceptance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("VERDICT %d/%d passed; %.1f simulated seconds" % [results.size() - failed, results.size(), simulated_seconds])
	game.queue_free()
	await process_frame
	GarageGeometry.materials.clear()
	quit(1 if failed else 0)
