extends CharacterBody3D
class_name FamilyEnemy

enum Action { IDLE, SEEK, WINDUP, RECOVER, HEAL }
var game: Node3D
var identity: String
var hp: float
var max_hp: float
var active: bool = false
var alive: bool = true
var rig: FamilyRig
var tag: Label3D
var warning: MeshInstance3D
var action: Action = Action.IDLE
var timer: float = 0
var cooldown: float = 0
var attack_sequence: int = 0
var combo_step: int = 0
var hurt: float = 0
var sandwich_clock: float = 0
var intimidation_clock: float = 0
var healing_kind: String = ""
var attack_count: int = 0
var hazards_created: int = 0
var heal_counts: Dictionary = {"sandwich": 0, "intimidation": 0}

func setup(owner_game: Node3D, who: String) -> void:
	game = owner_game
	identity = who
	name = who
	add_to_group("family")
	max_hp = game.config.boss_hp if who == "Lotusmicke" else {"Morgana": 58.0, "Bellatrix": 72.0, "Sabrina": 52.0}[who]
	hp = max_hp
	collision_layer = 4
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 2.5
	shape.radius = 0.8 if who == "Lotusmicke" else 0.4
	collision.shape = shape
	collision.position.y = 1.25
	add_child(collision)
	rig = FamilyRig.new()
	add_child(rig)
	rig.build(who)
	tag = GarageGeometry.label(self, Vector3(0, 3.3 if who == "Lotusmicke" else 3.05, 0), who.to_upper(), Color("ffe2bd"), 25)
	warning = GarageGeometry.ring(self, Vector3(0, 0.08, 0), 1.4 if who == "Lotusmicke" else 0.9, Color("ffbc4b"))
	warning.visible = false
	tag.visible = true

func reset_at(at: Vector3, enabled: bool) -> void:
	global_position = at
	hp = max_hp
	alive = true
	active = enabled
	action = Action.SEEK if enabled else Action.IDLE
	timer = 0.0
	cooldown = {"Morgana": 0.6, "Bellatrix": 1.3, "Sabrina": 2.0, "Lotusmicke": 0.8}[identity]
	combo_step = 0
	hurt = 0
	healing_kind = ""
	sandwich_clock = 0
	intimidation_clock = 0
	velocity = Vector3.ZERO
	rig.rotation.z = 0
	# Attack IDs remain monotonic across encounter resets.
	warning.visible = false
	tag.visible = true
	tag.text = identity.to_upper()

func tick(delta: float) -> void:
	hurt = maxf(0, hurt - delta)
	if not alive:
		rig.rotation.z = lerp_angle(rig.rotation.z, PI * 0.46, delta * 6)
		return
	var to_player: Vector3 = game.player.global_position - global_position
	to_player.y = 0
	var distance := to_player.length()
	var direction := to_player.normalized()
	if distance > 0.1:
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 7))
	if not active:
		rig.animate(delta, 0, false, "", 0, false, hurt)
		return
	cooldown = maxf(0, cooldown - delta)
	if identity == "Lotusmicke":
		sandwich_clock += delta
		intimidation_clock += delta
	if action in [Action.WINDUP, Action.HEAL]:
		timer -= delta
		warning.visible = true
		warning.scale = Vector3.ONE * (1.0 + sin(timer * 18) * 0.05)
		if timer <= 0:
			warning.visible = false
			if action == Action.HEAL:
				apply_heal(healing_kind)
				action = Action.RECOVER
				cooldown = 0.7
			else:
				_resolve_attack(distance)
		velocity = Vector3(0, -1, 0)
		move_and_slide()
		rig.animate(delta, 0, true, "punch", 0.22, false, hurt)
		return
	if identity == "Lotusmicke" and hp < max_hp and global_position.distance_to(game.GARAGE) <= 22:
		if sandwich_clock >= game.config.sandwich_interval:
			begin_heal("sandwich")
			return
		if intimidation_clock >= game.config.intimidation_interval:
			begin_heal("intimidation")
			return
	var wanted_range := {"Morgana": 6.0, "Bellatrix": 2.1, "Sabrina": 5.0, "Lotusmicke": 2.5}[identity] as float
	var speed := {"Morgana": 2.2, "Bellatrix": 4.2, "Sabrina": 2.8, "Lotusmicke": 3.2}[identity] as float
	var motion := Vector3.ZERO
	if distance > wanted_range:
		motion = direction * speed
	elif identity in ["Morgana", "Sabrina"] and distance < wanted_range - 1.2:
		motion = -direction * speed * 0.65
	if hurt > 0:
		motion *= 0.2
	velocity = Vector3(motion.x, -1 if is_on_floor() else velocity.y - delta * 24, motion.z)
	move_and_slide()
	if cooldown <= 0 and distance < wanted_range + 1.3:
		begin_attack()
	rig.animate(delta, motion.length() / speed, identity == "Bellatrix", "", 0, false, hurt)

func begin_attack() -> void:
	action = Action.WINDUP
	timer = {"Morgana": 0.9, "Bellatrix": 0.45 if combo_step == 0 else 0.26, "Sabrina": 0.85, "Lotusmicke": 0.85}[identity]
	warning.visible = true
	if identity == "Lotusmicke":
		game.say("LOTUSMICKE", "INGA SKOR I LOTUSEN! Och var är min dubbelmacka?")
	elif identity == "Morgana":
		game.say("MORGANA", "Familjeråd! Här är en presentation om dina brister.")

func _resolve_attack(distance: float) -> void:
	attack_sequence += 1
	attack_count += 1
	action = Action.RECOVER
	match identity:
		"Morgana":
			hazards_created += 1
			game.spawn_hazard(game.player.global_position, self, "distraction", attack_sequence)
			cooldown = 3.8
		"Sabrina":
			hazards_created += 1
			game.spawn_hazard(game.player.global_position, self, "banana", attack_sequence)
			game.say("SABRINA", "Gratis halkbana! Kommunen bjuder.")
			cooldown = 4.6
		"Bellatrix":
			combo_step += 1
			if distance < 3.2:
				game.player.take_family_hit(self, 18.0 if combo_step == 3 else 7.0, attack_sequence, combo_step == 3)
			if not alive or not game.running:
				return
			if combo_step < 3:
				begin_attack()
			else:
				combo_step = 0
				cooldown = 2.0
		"Lotusmicke":
			if distance < 3.8:
				game.player.take_family_hit(self, 20.0, attack_sequence, true)
			cooldown = 1.5

func begin_heal(kind: String) -> void:
	if not active or not alive or global_position.distance_to(game.GARAGE) > 22:
		return
	healing_kind = kind
	action = Action.HEAL
	timer = 0.9
	if kind == "sandwich":
		sandwich_clock = 0
		game.say("LOTUSMICKE", "Mackpaus! Rostad ost är en mänsklig rättighet.")
	else:
		intimidation_clock = 0
		game.say("LOTUSMICKE", "FAMILJEMÖTE! JAG ÄR ORDFÖRANDE! (+6 HP om ingen avbryter)")

func apply_heal(kind: String) -> bool:
	if not alive or not active or identity != "Lotusmicke" or global_position.distance_to(game.GARAGE) > 22:
		return false
	hp = minf(max_hp, hp + (10.0 if kind == "sandwich" else 6.0))
	heal_counts[kind] += 1
	game.burst(global_position + Vector3.UP, Color("ffbd4a"))
	return true

func take_damage(amount: float, _kind: String) -> void:
	if not active or not alive:
		return
	hp = maxf(0, hp - amount)
	# The opening is a tutorial slapstick scuffle. Nobody can be removed before
	# supplying the major impact that starts the first awakening.
	if game.mission in [game.Mission.HOME, game.Mission.KUNG_FU]:
		hp = maxf(1.0, hp)
	hurt = 0.3
	if action == Action.HEAL:
		action = Action.RECOVER
		cooldown = 1.1
		game.say("ERIK", "Mackpausen är inställd.")
	tag.text = "%s · %d" % [identity.to_upper(), ceili(hp)]
	if hp <= 0:
		alive = false
		active = false
		warning.visible = false
		tag.text = identity.to_upper() + " · FIKAPAUS"
		tag.visible = false
		game.say(identity.to_upper(), "Jag tar fem. Någon annan får vara pinsam nu.")
		game.on_enemy_down(self)
