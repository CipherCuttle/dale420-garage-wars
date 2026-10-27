extends CharacterBody3D
class_name ErikPlayer

var game: Node3D
var config: GarageConfig
var form: AwakeningState
var hp: float = 100.0
var inventory: Dictionary = {"joints": 3, "air_rifle": false, "crumb_evidence": false}
var rig: FamilyRig
var driving: bool = false
var equipped: bool = false
var attack_cooldown: float = 0.0
var attack_time: float = 0.0
var attack_kind: String = ""
var combo: int = 0
var combo_clock: float = 0.0
var dodge_remaining: float = 0.0
var dodge_wait: float = 0.0
var dodge_vector := Vector3.ZERO
var counter_used: bool = false
var hurt: float = 0.0
var slowed: float = 0.0
var received_attacks: Dictionary = {}

func setup(owner_game: Node3D, tuning: GarageConfig) -> void:
	game = owner_game
	config = tuning
	name = "ErikDale420"
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 8
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 2.35
	collision.shape = shape
	collision.position.y = 1.2
	add_child(collision)
	rig = FamilyRig.new()
	add_child(rig)
	rig.build("Erik")
	form = AwakeningState.new(config)
	form.changed.connect(_form_changed)

func reset_state() -> void:
	hp = config.max_hp
	inventory = {"joints": 3, "air_rifle": false, "crumb_evidence": false}
	driving = false
	equipped = false
	visible = true
	collision_layer = 2
	velocity = Vector3.ZERO
	form.reset()
	clear_combat()

func clear_combat() -> void:
	attack_cooldown = 0.0
	attack_time = 0.0
	combo = 0
	combo_clock = 0.0
	dodge_remaining = 0.0
	dodge_wait = 0.0
	hurt = 0.0
	slowed = 0.0
	received_attacks.clear()

func movement_speed() -> float:
	return config.dale_speed if form.is_dale() else config.erik_speed

func tick(delta: float, direction: Vector3, sprint: bool) -> void:
	form.tick(delta)
	attack_cooldown = maxf(0, attack_cooldown - delta)
	attack_time = maxf(0, attack_time - delta)
	combo_clock = maxf(0, combo_clock - delta)
	dodge_remaining = maxf(0, dodge_remaining - delta)
	dodge_wait = maxf(0, dodge_wait - delta)
	hurt = maxf(0, hurt - delta)
	slowed = maxf(0, slowed - delta)
	if driving:
		global_position = game.car.global_position
		return
	var motion := direction.normalized() * movement_speed() * (1.45 if sprint else 1.0)
	if slowed > 0:
		motion *= 0.45
	if form.mode == AwakeningState.Mode.AWAKENING:
		motion = Vector3.ZERO
	elif dodge_remaining > 0:
		motion = dodge_vector * (16.0 if form.is_dale() else 11.0)
	if direction.length_squared() > 0.01 and dodge_remaining <= 0:
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * 14))
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, -85, 85)
	global_position.z = clampf(global_position.z, -85, 85)
	rig.animate(delta, motion.length() / movement_speed(), form.is_dale(), attack_kind, attack_time, dodge_remaining > 0, hurt, equipped)

func dodge(direction: Vector3) -> bool:
	if not game.running or driving or dodge_wait > 0 or form.mode == AwakeningState.Mode.AWAKENING:
		return false
	dodge_vector = direction.normalized() if direction.length_squared() > 0.01 else -rig.global_basis.z
	dodge_vector.y = 0.0
	dodge_remaining = config.dodge_seconds
	dodge_wait = config.dodge_cooldown
	counter_used = false
	game.dodges += 1
	game.sound(380 if form.is_dale() else 230, 0.12)
	return true

func take_family_hit(source: Node3D, damage: float, attack_id: int, major: bool) -> bool:
	if not game.running or driving or not game.family.has(source) or not source.active or not source.alive:
		return false
	var key := "%s:%s" % [source.identity, attack_id]
	if received_attacks.has(key):
		return false
	received_attacks[key] = true
	if form.mode == AwakeningState.Mode.AWAKENING:
		return false
	if dodge_remaining > 0:
		if form.is_dale() and not counter_used and source.global_position.distance_to(global_position) < 4.0:
			counter_used = true
			attack_kind = "counter"
			attack_time = 0.4
			source.take_damage(config.counter_damage, "counter")
			game.counters += 1
			game.say("DALE420", "KVITTO PÅ DEN! Undvikande kontring.")
			game.burst(global_position, Color("e0ff67"))
		return false
	hp = maxf(0, hp - damage)
	hurt = 0.25
	game.impact = 0.25
	game.flash = Color(1, 0.2, 0.12, 0.17)
	game.sound(90, 0.12)
	if hp <= 0:
		game.defeat()
		return true
	form.family_damage(damage, source.identity, attack_id, major)
	return true

func strike(kick: bool) -> bool:
	if not game.running or driving or attack_cooldown > 0 or form.mode == AwakeningState.Mode.AWAKENING:
		return false
	equipped = false
	if combo_clock <= 0:
		combo = 0
	combo = (combo % 3) + 1
	combo_clock = 1.2
	attack_kind = "kick" if kick else "punch"
	attack_time = 0.4
	attack_cooldown = (0.52 if kick else 0.23) if form.is_dale() else (0.85 if kick else 0.6)
	var damage := (config.dale_kick if kick else config.dale_punch + (combo - 1) * 5.0) if form.is_dale() else config.erik_punch * (1.3 if kick else 1.0)
	var reach := (3.6 if kick else 2.7) if form.is_dale() else 2.1
	var target: Node3D = null
	var nearest := reach
	for enemy in game.family:
		if not enemy.active or not enemy.alive:
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			target = enemy
	if target != null:
		var toward: Vector3 = target.global_position - global_position
		rig.rotation.y = atan2(-toward.x, -toward.z)
		target.take_damage(damage, attack_kind)
		if form.is_dale():
			game.kungfu_hits += 1
			if kick:
				game.kicks += 1
			game.burst(target.global_position + Vector3.UP, Color("dfff64"))
		game.impact = 0.12
	game.sound(140 if kick else 210, 0.08)
	return true

func smoke() -> bool:
	if not game.running or driving or hp >= config.max_hp or int(inventory.joints) <= 0:
		return false
	inventory.joints -= 1
	hp = minf(config.max_hp, hp + config.joint_heal)
	game.heals += 1
	game.flash = Color(0.55, 1, 0.5, 0.12)
	game.say("ERIK", "Skogens vårdcentral. +28 HP. Ingen kölapp.")
	game.sound(310, 0.3)
	game.burst(global_position + Vector3.UP * 2.1, Color("becda5"))
	return true

func _form_changed(previous: int, current: int) -> void:
	# Identity changes never create a node, replace inventory, or touch HP.
	if current == AwakeningState.Mode.AWAKENING:
		equipped = false
		attack_cooldown = 0
		game.impact = 0.8
		game.flash = Color(0.83, 1, 0.3, 0.35)
		game.say("ERIK → DALE420", "NU RÄCKER DET. Asiens självutnämnda kung fu-gud är här!")
		game.sound(110, 0.65, 880)
		game.burst(global_position, Color("eaff80"), 2.4)
	elif current == AwakeningState.Mode.DALE420:
		game.sound(660, 0.35, 990)
		game.on_awakened()
	elif previous == AwakeningState.Mode.DALE420:
		game.say("ERIK", "Okej. Nu behöver den här guden sitta ner en stund.")
		game.on_expired()
