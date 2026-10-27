extends CharacterBody3D
class_name YellowSportsCar

var game: Node3D
var speed: float = 0
var unlocked: bool = false
var wheels: Array[MeshInstance3D] = []

func setup(owner_game: Node3D) -> void:
	game = owner_game
	name = "YellowSportsCar"
	add_to_group("vehicle")
	collision_layer = 8
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.9, 1.3, 5.3)
	collision.shape = shape
	collision.position.y = 0.8
	add_child(collision)
	# Original alpha proportions, carried over without licensed car assets.
	GarageGeometry.box(self, Vector3(0, 0.68, 0), Vector3(2.9, 0.63, 5.3), Color("e8ad24"))
	GarageGeometry.box(self, Vector3(0, 1.09, 0.25), Vector3(2.55, 0.48, 3.1), Color("f0be2d"))
	GarageGeometry.box(self, Vector3(0, 1.43, 0.34), Vector3(2.27, 0.13, 2.45), Color("f7ca43"))
	GarageGeometry.box(self, Vector3(0, 1.29, -0.62), Vector3(2.35, 0.35, 0.18), Color("344b54"))
	for side in [-1, 1]:
		GarageGeometry.box(self, Vector3(side * 1.29, 1.25, 0.35), Vector3(0.08, 0.34, 1.5), Color("344b54"))
		for z in [-1.45, 1.46]:
			var wheel := GarageGeometry.box(self, Vector3(side * 1.39, 0.5, z), Vector3(0.55, 0.74, 0.8), Color("20272c"))
			wheels.append(wheel)
		GarageGeometry.box(self, Vector3(side * 0.98, 0.75, -2.66), Vector3(0.63, 0.19, 0.12), Color("fff2be"))
	GarageGeometry.box(self, Vector3(0, 0.74, 2.67), Vector3(2.35, 0.2, 0.12), Color("b52935"))
	GarageGeometry.box(self, Vector3(0, 1.35, 2.47), Vector3(2.1, 0.12, 0.37), Color("253333"))

func tick(delta: float, throttle: float, steer: float) -> void:
	# Acceleration, reverse, steering and bounce are the Alpha 01 rules.
	speed = clampf(speed + throttle * 20.0 * delta, -9.0, 24.0)
	if is_zero_approx(throttle):
		speed *= pow(0.90, delta * 60)
	rotation.y += steer * delta * 1.15 * clampf(absf(speed) / 5.0, 0, 1) * signf(speed)
	velocity = -global_basis.z * speed
	velocity.y = -1.0
	move_and_slide()
	if get_slide_collision_count() > 0:
		for index in get_slide_collision_count():
			if absf(get_slide_collision(index).get_normal().y) < 0.6:
				speed *= -0.28
				game.impact = 0.25
				break
	global_position.x = clampf(global_position.x, -84, 84)
	global_position.z = clampf(global_position.z, -84, 84)
	for wheel in wheels:
		wheel.rotation.x += speed * delta

func toggle_ride() -> bool:
	if not game.running:
		return false
	var player: ErikPlayer = game.player
	if player.driving:
		# Verify an exit against world colliders instead of placing Erik in a wall.
		for offset in [Vector3(3.4, 0.3, 0), Vector3(-3.4, 0.3, 0), Vector3(0, 0.3, 4.3), Vector3(0, 0.3, -4.3)]:
			var point: Vector3 = global_position + global_basis * offset
			if game.world.walkable(point, 0.5):
				player.global_position = point
				player.driving = false
				player.visible = true
				player.collision_layer = 2
				speed = 0
				game.say("ERIK", "Min kropp, min HP, pappas bil. Inga smulor.")
				return true
		game.say("ERIK", "Dörrarna är blockerade. Rulla ut en bit först.")
		return false
	if not unlocked or player.global_position.distance_to(global_position) > 4.8:
		game.say("ERIK", "Nyckeln sitter i pappas mackficka." if not unlocked else "Jag måste stå närmare bilen.")
		return false
	player.driving = true
	player.visible = false
	player.collision_layer = 0
	player.global_position = global_position
	game.say("ERIK", "Lotusen är min. Bricka under mackan, förstås.")
	return true
