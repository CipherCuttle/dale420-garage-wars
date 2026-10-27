extends Node3D
class_name GarageWarsGame

enum Mission { HOME, KUNG_FU, ESCAPE_FOREST, HIDEOUT, FOREST_PRACTICE, CRUMBS, RETURN_GARAGE, FAMILY_WAVE, BOSS, FREE_ROAM }
const HOME := Vector3(30, 0.1, -4)
const CAMP := Vector3(-40, 0.1, -27)
const GARAGE := Vector3(19, 0.1, -4)
@export var config: GarageConfig = GarageConfig.new()
var player: ErikPlayer
var family: Array[FamilyEnemy] = []
var car: YellowSportsCar
var world: MackebyWorld
var camera: Camera3D
var hud: Control
var mission: Mission = Mission.HOME
var running: bool = false
var started: bool = false
var dead: bool = false
var checkpoint: Dictionary = {}
var checkpoint_name: String = "HEMMA"
var mission_history: Array[int] = []
var cam_yaw: float = PI
var cam_distance: float = 12.5
var dragging: bool = false
var speech: String = ""
var speaker: String = ""
var speech_clock: float = 0
var impact: float = 0
var flash := Color(0, 0, 0, 0)
var hazards: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var dodges: int = 0
var kungfu_hits: int = 0
var kicks: int = 0
var counters: int = 0
var heals: int = 0
var target_hits: int = 0
var forest_healed: bool = false
var forest_supplies: bool = false
var home_relieved: bool = false
var audio_events: int = 0

func _ready() -> void:
	_setup_inputs()
	_build_environment()
	world = MackebyWorld.new()
	add_child(world)
	world.build()
	player = ErikPlayer.new()
	add_child(player)
	player.setup(self, config)
	for who in ["Morgana", "Bellatrix", "Sabrina", "Lotusmicke"]:
		var enemy := FamilyEnemy.new()
		add_child(enemy)
		enemy.setup(self, who)
		family.append(enemy)
	car = YellowSportsCar.new()
	add_child(car)
	car.setup(self)
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 63
	camera.far = 240
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://scripts/hud.gd").new()
	layer.add_child(hud)
	hud.game = self
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reset_home()
	_update_camera(1.0, true)

func _setup_inputs() -> void:
	var bindings := {
		"walk_left": [KEY_A], "walk_right": [KEY_D], "walk_forward": [KEY_W], "walk_back": [KEY_S],
		"sprint": [KEY_SHIFT], "punch": [KEY_J], "kick": [KEY_K], "dodge": [KEY_SPACE],
		"interact": [KEY_E], "ride": [KEY_F], "heal": [KEY_Q], "rifle": [KEY_T],
		"camera_left": [KEY_LEFT], "camera_right": [KEY_RIGHT], "start": [KEY_ENTER], "retry": [KEY_R]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("a1b7c4")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c5d0c6")
	settings.ambient_light_energy = 0.4
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	settings.fog_enabled = true
	settings.fog_light_color = Color("afb8a0")
	settings.fog_density = 0.002
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffe4b2")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60

func start_game() -> void:
	if started:
		return
	started = true
	running = true
	say("MORGANA", "25 år, Erik. Din längsta anställning är fortfarande vid kylskåpet.", 5)
	sound(420, 0.25)

func _reset_home() -> void:
	player.reset_state()
	player.global_position = HOME
	car.global_position = Vector3(18, 0.1, 1)
	car.rotation.y = PI
	car.speed = 0
	car.unlocked = false
	mission = Mission.HOME
	mission_history = [Mission.HOME]
	dodges = 0
	kungfu_hits = 0
	kicks = 0
	counters = 0
	heals = 0
	target_hits = 0
	forest_healed = false
	forest_supplies = false
	home_relieved = false
	world.clue.visible = false
	family[0].reset_at(Vector3(35, 0.1, -9), true)
	family[1].reset_at(Vector3(30, 0.1, -8), true)
	family[2].reset_at(Vector3(37, 0.1, -4), true)
	family[3].reset_at(Vector3(16, 0.1, -4), false)
	player.form.begin_encounter("home")
	save_checkpoint("HEMMA", HOME)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		if dead:
			retry()
		else:
			start_game()
	if event.is_action_pressed("retry") and dead:
		retry()
	if not running:
		return
	if event.is_action_pressed("punch"):
		player.strike(false)
	if event.is_action_pressed("kick"):
		player.strike(true)
	if event.is_action_pressed("dodge"):
		player.dodge(input_direction())
	if event.is_action_pressed("interact"):
		interact()
	if event.is_action_pressed("ride"):
		car.toggle_ride()
	if event.is_action_pressed("heal"):
		use_joint()
	if event.is_action_pressed("rifle"):
		fire_rifle()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = maxf(7.0, cam_distance - 1)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = minf(24.0, cam_distance + 1)
	if event is InputEventMouseMotion and dragging:
		cam_yaw -= event.relative.x * 0.007

func input_direction() -> Vector3:
	return Vector3(Input.get_axis("walk_left", "walk_right"), 0, Input.get_axis("walk_forward", "walk_back")).normalized()

func _physics_process(delta: float) -> void:
	if running:
		simulate(delta, input_direction(), Input.is_action_pressed("sprint"), Input.get_axis("walk_back", "walk_forward"), Input.get_axis("walk_right", "walk_left"))
	cam_yaw += Input.get_axis("camera_right", "camera_left") * delta * 1.45
	update_presentation(delta)

func update_presentation(delta: float) -> void:
	_update_camera(delta)
	_update_effects(delta)
	speech_clock = maxf(0, speech_clock - delta)
	flash.a = move_toward(flash.a, 0, delta * 0.8)
	impact = maxf(0, impact - delta)
	hud.queue_redraw()

func simulate(delta: float, direction: Vector3 = Vector3.ZERO, sprint: bool = false, throttle: float = 0, steering: float = 0) -> void:
	if not running:
		return
	if player.driving:
		car.tick(delta, throttle, steering)
	player.tick(delta, direction, sprint)
	for enemy in family:
		if player.form.mode == AwakeningState.Mode.AWAKENING:
			enemy.rig.animate(delta, 0, false, "", 0, false, 0)
			continue
		enemy.tick(delta)
		if not running:
			break
	_update_hazards(delta)
	if not running:
		return
	if mission == Mission.KUNG_FU and kungfu_hits >= 3 and kicks > 0 and not home_relieved:
		home_relieved = true
		for sister in family.slice(0, 3):
			sister.active = false
		clear_hazards()
		say("DALE420", "FAMILJERÅDET ÄR AVSLUTAT! Snart tar superkrafterna slut. Skogen väntar.", 6)
	if mission == Mission.ESCAPE_FOREST and player.global_position.distance_to(CAMP) < 8:
		set_mission(Mission.HIDEOUT)
		say("ERIK", "Mitt skogskontor. Ingen chef, ingen familjechatt.")
	if mission == Mission.RETURN_GARAGE and player.global_position.distance_to(GARAGE) < 13:
		_start_garage_wave()
	if mission == Mission.FOREST_PRACTICE and forest_healed and target_hits > 0:
		set_mission(Mission.CRUMBS)
		world.clue.visible = true
		say("ERIK", "Ost i min skog? Pappa har ett hemligt dubbelmackeliv!")

func set_mission(next: Mission) -> void:
	mission = next
	mission_history.append(next)
	sound(660, 0.12, 880)

func on_awakened() -> void:
	if mission == Mission.HOME:
		set_mission(Mission.KUNG_FU)

func on_expired() -> void:
	if running and mission in [Mission.HOME, Mission.KUNG_FU]:
		set_mission(Mission.ESCAPE_FOREST)
		for sister in family.slice(0, 3):
			sister.active = false
		clear_hazards()

func interact() -> bool:
	if not running or player.driving:
		return false
	# Mission evidence takes priority where the stash and clue radii overlap.
	if mission == Mission.CRUMBS and player.global_position.distance_to(world.clue.global_position) < 4.5:
		player.inventory.crumb_evidence = true
		world.clue.visible = false
		set_mission(Mission.RETURN_GARAGE)
		say("ERIK", "Smulbevis säkrat. Nu blir det internrevision i garaget.")
		return true
	if player.global_position.distance_to(CAMP) < 4.5:
		player.inventory.air_rifle = true
		player.equipped = true
		if not forest_supplies:
			player.inventory.joints = maxi(3, player.inventory.joints)
			forest_supplies = true
		if mission == Mission.HIDEOUT:
			forest_healed = player.hp >= config.max_hp
			set_mission(Mission.FOREST_PRACTICE)
			save_checkpoint("SKOGSGÖMSTÄLLET", CAMP)
		say("ERIK", "Mitt luftgevär, mina burkar. [T] provskjut • [Q] joint +28 HP.")
		return true
	if player.global_position.distance_to(car.global_position) < 5:
		say("ERIK", "[F] Kör den gula bilen." if car.unlocked else "Pappas gula Lotus. Först måste jag få tag på nyckeln.")
		return true
	return false

func use_joint() -> bool:
	var used := player.smoke()
	if used and mission == Mission.FOREST_PRACTICE and player.global_position.distance_to(CAMP) < 10:
		forest_healed = true
	return used

func fire_rifle() -> bool:
	if not running or player.driving or not player.inventory.air_rifle or player.form.is_dale() or player.form.mode == AwakeningState.Mode.AWAKENING:
		return false
	if player.global_position.distance_to(world.target.global_position) > 24:
		say("ERIK", "Luftgeväret är för tavlan vid mitt gömställe.")
		return false
	player.equipped = true
	var origin := player.global_position + Vector3.UP * 1.7
	var aim := world.target.global_position - origin
	player.rig.rotation.y = atan2(-aim.x, -aim.z)
	# Arcade aim assist, with an actual world ray: walls and trees block shots.
	var query := PhysicsRayQueryParameters3D.create(origin, world.target.global_position, 1 | 16)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	sound(160, 0.055)
	if not hit.is_empty() and hit.collider == world.target:
		target_hits += 1
		burst(hit.position, Color("ffd573"))
		say("ERIK", "TRÄFF! Burken har lämnat arbetsmarknaden.")
		return true
	say("ERIK", "Skymd sikt. Flytta närmare skjutbänken.")
	return false

func _start_garage_wave() -> void:
	clear_hazards()
	cam_yaw = 0.0
	set_mission(Mission.FAMILY_WAVE)
	family[0].reset_at(Vector3(10, 0.1, -3), true)
	family[1].reset_at(Vector3(19, 0.1, 4), true)
	family[2].reset_at(Vector3(27, 0.1, -3), true)
	player.form.begin_encounter("garage_family")
	player.received_attacks.clear()
	save_checkpoint("GARAGEGÅRDEN", Vector3(7, 0.1, -2))
	say("MORGANA", "En smula är inte ett bevis. Jag har gjort ett diagram som säger det.")

func on_enemy_down(enemy: FamilyEnemy) -> void:
	if enemy.identity == "Lotusmicke" and mission == Mission.BOSS:
		car.unlocked = true
		set_mission(Mission.FREE_ROAM)
		clear_hazards()
		say("ERIK / DALE420", "SMULORNAS HÄMND! Nyckeln är din. [F] kör • fri körning i Mackeby.", 8)
		save_checkpoint("FRI KÖRNING", Vector3(13, 0.1, 2))
	elif mission == Mission.FAMILY_WAVE:
		var all_down := true
		for sister in family.slice(0, 3):
			if sister.alive:
				all_down = false
		if all_down:
			clear_hazards()
			set_mission(Mission.BOSS)
			cam_yaw = 0.0
			family[3].reset_at(Vector3(16, 0.1, -4), true)
			player.form.begin_encounter("lotusmicke")
			player.received_attacks.clear()
			save_checkpoint("LOTUSMICKE", Vector3(11, 0.1, -2))
			say("LOTUSMICKE", "RÖR INTE MIN ELISE! Jag har precis dammsugit mackfacket!")

func save_checkpoint(label: String, at: Vector3) -> void:
	checkpoint_name = label
	checkpoint = {"mission": mission, "position": at, "hp": player.hp, "inventory": player.inventory.duplicate(true), "forest_supplies": forest_supplies, "forest_healed": forest_healed, "target_hits": target_hits}

func defeat() -> void:
	dead = true
	running = false
	player.form.reset()
	car.speed = 0
	for enemy in family:
		enemy.active = false
	clear_hazards()
	say("ERIK", "Tillfällig fikapaus. Tryck R för att försöka igen.")

func retry() -> void:
	if not dead:
		return
	clear_hazards()
	player.reset_state()
	player.global_position = checkpoint.position
	player.hp = checkpoint.hp
	player.inventory = checkpoint.inventory.duplicate(true)
	mission = checkpoint.mission
	forest_supplies = checkpoint.forest_supplies
	forest_healed = checkpoint.forest_healed
	target_hits = checkpoint.target_hits
	dead = false
	running = true
	match mission:
		Mission.HOME:
			_reset_home()
		Mission.FAMILY_WAVE:
			_start_garage_wave()
		Mission.BOSS:
			for sister in family.slice(0, 3):
				sister.alive = false
				sister.active = false
			family[3].reset_at(Vector3(16, 0.1, -4), true)
			player.form.begin_encounter("lotusmicke")
		Mission.FREE_ROAM:
			car.unlocked = true
		_:
			for enemy in family:
				enemy.active = false
	world.clue.visible = mission == Mission.CRUMBS
	_update_camera(1, true)
	say("ERIK", "Tillbaka vid " + checkpoint_name.to_lower() + ". Samma Erik, nytt försök.")

func spawn_hazard(at: Vector3, source: FamilyEnemy, kind: String, attack_id: int) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(at.x, 0.1, at.z)
	GarageGeometry.ring(node, Vector3.ZERO, 1.65 if kind == "distraction" else 1.1, Color("bf8df4") if kind == "distraction" else Color("ffe06b"))
	if kind == "banana":
		var peel := GarageGeometry.box(node, Vector3(0, 0.06, 0), Vector3(0.65, 0.12, 0.2), Color("ffce36"))
		peel.rotation.y = 0.6
	else:
		GarageGeometry.label(node, Vector3(0, 1.2, 0), "FAMILJERÅD!", Color("e5c3ff"), 20)
	hazards.append({"node": node, "source": source, "kind": kind, "id": attack_id, "age": 0.0, "spent": false})

func _update_hazards(delta: float) -> void:
	# Damage/counters can end the encounter and clear this collection mid-hit.
	for hazard in hazards.duplicate():
		if not hazards.has(hazard):
			continue
		hazard.age += delta
		if hazard.age > 6.0:
			hazard.node.queue_free()
			hazards.erase(hazard)
			continue
		var radius := 1.65 if hazard.kind == "distraction" else 1.1
		if not hazard.spent and hazard.age > 0.65 and player.global_position.distance_to(hazard.node.global_position) < radius:
			hazard.spent = true
			var hit: bool = player.take_family_hit(hazard.source, 10.0 if hazard.kind == "distraction" else 14.0, hazard.id, hazard.kind == "banana")
			if not running:
				return
			if hit:
				player.slowed = 1.0 if hazard.kind == "distraction" else 0.65
				say(hazard.source.identity.to_upper(), "Dödsallvarlig powerpoint!" if hazard.kind == "distraction" else "Halkade du på ditt CV, Erik?")

func clear_hazards() -> void:
	for hazard in hazards:
		hazard.node.queue_free()
	hazards.clear()

func burst(at: Vector3, color: Color, size: float = 1.0) -> void:
	var node := Node3D.new()
	add_child(node)
	node.global_position = at
	GarageGeometry.ring(node, Vector3.UP * 0.2, 0.7, color)
	for i in range(8):
		var angle := i * TAU / 8
		GarageGeometry.box(node, Vector3(cos(angle), 0.6, sin(angle)) * 0.7, Vector3(0.1, 0.65, 0.1), color)
	effects.append({"node": node, "age": 0.0, "size": size})

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var effect := effects[i]
		effect.age += delta
		effect.node.scale = Vector3.ONE * (0.4 + effect.age * 2.4) * effect.size
		effect.node.rotation.y += delta * 2
		if effect.age > 0.65:
			effect.node.queue_free()
			effects.remove_at(i)

func say(who: String, words: String, seconds: float = 3.5) -> void:
	speaker = who
	speech = words
	speech_clock = seconds

func sound(frequency: float, seconds: float, end_frequency: float = -1) -> void:
	audio_events += 1
	if DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(seconds * 22050)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var phase: float = 0
	for i in range(samples):
		var progress := float(i) / samples
		var freq := lerpf(frequency, end_frequency if end_frequency > 0 else frequency, progress)
		phase += TAU * freq / 22050
		bytes.encode_s16(i * 2, int(sin(phase) * 3500 * (1.0 - progress)))
	stream.data = bytes
	var audio := AudioStreamPlayer.new()
	add_child(audio)
	audio.stream = stream
	audio.volume_db = -6
	audio.finished.connect(audio.queue_free)
	audio.play()

func _update_camera(delta: float, snap: bool = false) -> void:
	var focus := player.global_position + Vector3.UP * 1.55
	var offset := Vector3(sin(cam_yaw) * cam_distance, cam_distance * 0.52 + 1.2, cos(cam_yaw) * cam_distance)
	var wanted := focus + offset
	var query := PhysicsRayQueryParameters3D.create(focus, wanted, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		wanted = hit.position + hit.normal * 0.6
	camera.global_position = wanted if snap else camera.global_position.lerp(wanted, minf(1, delta * 9))
	if impact > 0:
		camera.global_position += Vector3(sin(Time.get_ticks_msec() * 0.067), cos(Time.get_ticks_msec() * 0.093), 0) * impact * 0.13
	if camera.global_position.distance_squared_to(focus) > 0.01:
		camera.look_at(focus)

func objective() -> Dictionary:
	match mission:
		Mission.HOME:
			return {"title": "ERIKS SÄMSTA FAMILJERÅD", "detail": "WASD: rör dig. Mellanslag: undvik. Familjens tecknade attacker fyller mätaren. En rejäl smäll väcker DALE420.", "target": HOME}
		Mission.KUNG_FU:
			return {"title": "DALE420 HAR VAKNAT", "detail": "J: trestegskombo. K: kraftspark. Undvik en attack med Mellanslag för automatisk kontring. Träffar: %d • sparkar: %d" % [kungfu_hits, kicks], "target": player.global_position}
		Mission.ESCAPE_FOREST:
			return {"title": "ERIK BEHÖVER EN PAUS", "detail": "DALE420 har gått hem. Du är Erik igen. Fly till DITT gömställe i skogen västerut. Följ markören och kartan.", "target": CAMP}
		Mission.HIDEOUT:
			return {"title": "DITT SKOGSKONTOR", "detail": "Gå till skjutbänken. E: öppna ditt förråd och ta ditt luftgevär. Här finns en engångspåfyllning av joints.", "target": CAMP}
		Mission.FOREST_PRACTICE:
			return {"title": "SKOGENS VÅRDCENTRAL", "detail": "Q: joint återställer 28 HP. T: skjut måltavlan med luftgeväret (sikthjälp). Bara burkar. Läkning: %s • träffar: %d" % ["klar" if forest_healed else "väntar", target_hits], "target": CAMP}
		Mission.CRUMBS:
			return {"title": "HEMLIGA MACKSMULOR", "detail": "Något glimmar på lådan bakom bänken. E: granska smulbeviset från pappas hemliga dubbelmackor.", "target": world.clue.global_position}
		Mission.RETURN_GARAGE:
			return {"title": "INTERNREVISION I GARAGET", "detail": "Återvänd till Lotusmickes garage med smulbeviset. Systrarna vill ha ett ord. Eller en hel powerpoint.", "target": GARAGE}
		Mission.FAMILY_WAVE:
			return {"title": "FAMILJERÅD: RETURMATCH", "detail": "Morgana distraherar. Bellatrix kör snabba trestegskombor. Sabrina lägger halkfällor. Avsluta deras fikapausplan.", "target": GARAGE}
		Mission.BOSS:
			return {"title": "LOTUSMICKE • MACKOR & MAKT", "detail": "Undvik gula attackvarningar. Avbryt mackpauser med slag eller sparkar. Familjevrålet läker också honom. Nyckeln är i hans ficka.", "target": family[3].global_position}
		_:
			return {"title": "SMULORNAS HÄMND • KLART", "detail": "Du är fortfarande Erik. DALE420 är din stridsidentitet. Lotusen är upplåst: F nära bilen. Kör, kliv ur, kör igen. Fri körning!", "target": car.global_position}

func hint() -> String:
	if player.driving:
		return "WASD KÖR • F KLIV UR"
	if mission == Mission.CRUMBS and player.global_position.distance_to(world.clue.global_position) < 4.5:
		return "E GRANSKA MACKSMULOR"
	if player.global_position.distance_to(CAMP) < 4.5:
		return "E FÖRRÅD • Q LÄK • T LUFTGEVÄR"
	if player.global_position.distance_to(car.global_position) < 4.8:
		return "F KÖR LOTUSEN" if car.unlocked else "BILEN ÄR LÅST • BESEGRA LOTUSMICKE"
	return ""
