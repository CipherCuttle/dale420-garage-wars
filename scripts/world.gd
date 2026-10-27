extends Node3D
class_name MackebyWorld

var obstacles: Array[Rect2] = []
var trees: Array[Vector2] = []
var target: StaticBody3D
var clue: Node3D
var stash: Node3D
var camp_marker: Label3D
var clue_marker: Label3D

func build() -> void:
	name = "Mackeby"
	GarageGeometry.box(self, Vector3(0, -0.25, 0), Vector3(180, 0.5, 180), Color("758565"), true)
	# The original intersecting roads, houses, garage and western forest layout.
	GarageGeometry.box(self, Vector3(0, 0.015, 9), Vector3(175, 0.03, 12), Color("959887"))
	GarageGeometry.box(self, Vector3(0, 0.04, 9), Vector3(175, 0.04, 9), Color("535b5c"))
	GarageGeometry.box(self, Vector3(-7, 0.015, 0), Vector3(12, 0.03, 170), Color("959887"))
	GarageGeometry.box(self, Vector3(-7, 0.045, 0), Vector3(9, 0.04, 170), Color("535b5c"))
	for x in range(-85, 86, 10):
		if absf(x + 7) > 8:
			GarageGeometry.box(self, Vector3(x, 0.075, 9), Vector3(5, 0.02, 0.2), Color("ead391"))
	for z in range(-85, 86, 10):
		if absf(z - 9) > 8:
			GarageGeometry.box(self, Vector3(-7, 0.08, z), Vector3(0.2, 0.02, 5), Color("ead391"))
	# A little more front-yard clearance than the browser alpha keeps the native
	# third-person camera and the four-person garage fight clear of building edges.
	house(Vector3(36, 0, 7), Vector3(14, 6.3, 12), Color("d3bda0"))
	house(Vector3(48, 0, -17), Vector3(15, 7.2, 15), Color("a76d52"))
	house(Vector3(47, 0, 30), Vector3(14, 5.8, 14), Color("b4a779"))
	house(Vector3(-26, 0, 29), Vector3(16, 5.8, 15), Color("bb8966"))
	house(Vector3(-52, 0, 26), Vector3(14, 5.8, 12), Color("d3bda0"))
	house(Vector3(65, 0, 25), Vector3(18, 7.4, 14), Color("9d9c9b"))
	GarageGeometry.box(self, Vector3(19, 2.5, -13), Vector3(15, 5, 13), Color("a3a58e"), true)
	obstacles.append(Rect2(11.5, -19.5, 15, 13))
	GarageGeometry.box(self, Vector3(19, 5.4, -13), Vector3(16, 0.8, 14), Color("535953"))
	GarageGeometry.box(self, Vector3(19, 2, -6.44), Vector3(10.8, 3.9, 0.18), Color("56615d"))
	for i in range(5):
		GarageGeometry.box(self, Vector3(19, 0.5 + i * 0.7, -6.3), Vector3(10.8, 0.045, 0.1), Color("89928a"))
	var garage_sign := GarageGeometry.label(self, Vector3(19, 4.6, -6.1), "MICKE'S GARAGE\nMACKOR • MOTOR • MAKT", Color("ffe27b"), 22)
	garage_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	garage_sign.pixel_size = 0.009
	GarageGeometry.box(self, Vector3(18.5, 0.04, 0), Vector3(9, 0.08, 12), Color("a4a18b"))
	GarageGeometry.sandwich(self, Vector3(22, 1.2, -5.9))
	GarageGeometry.box(self, Vector3(22, 0.6, -5.9), Vector3(1.5, 1.1, 0.8), Color("66533b"))
	var home_sign := GarageGeometry.label(self, Vector3(36, 3.8, 0.8), "HEMMA HOS ERIK • 25 ÅR", Color("f5e1b5"), 19)
	home_sign.pixel_size = 0.009
	home_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	home_sign.rotation.y = PI
	GarageGeometry.box(self, Vector3(4, 1.5, 20), Vector3(3, 3, 2), Color("c14d4d"), true)
	GarageGeometry.label(self, Vector3(4, 3.5, 20), "MACKLUCKAN", Color("ffdf84"), 24)
	for x in [-70, -40, 10, 42, 70]:
		for z in [1, 17]:
			GarageGeometry.box(self, Vector3(x, 3.3, z), Vector3(0.16, 6.6, 0.16), Color("414f4d"))
			GarageGeometry.box(self, Vector3(x + 0.55, 6.6, z), Vector3(1.2, 0.14, 0.4), Color("ffe8b4"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 420420
	for i in range(125):
		var x := rng.randf_range(-81, -15)
		var z := rng.randf_range(-80, -10)
		# Clear the camp, firing line and a wide walkable approach.
		if Rect2(-60, -46, 30, 39).has_point(Vector2(x, z)) or absf(z + 20) < 4.0:
			continue
		tree(x, z, rng.randf_range(0.7, 1.35))
	for i in range(12):
		tree(rng.randf_range(35, 75), rng.randf_range(-77, -40), 1.1)
	# Erik's own hideout: no Erik NPC is instantiated here.
	GarageGeometry.box(self, Vector3(-42, 0.03, -25), Vector3(18, 0.06, 15), Color("85856c"))
	GarageGeometry.box(self, Vector3(-44, 0.7, -30), Vector3(3, 1.4, 2), Color("69553e"))
	GarageGeometry.box(self, Vector3(-44, 1.45, -30), Vector3(3.4, 0.15, 2.4), Color("45574b"))
	GarageGeometry.cone(self, Vector3(-47, 0, -20), 1.3, 2.7, Color("c77d3c"))
	GarageGeometry.box(self, Vector3(-40, 0.6, -27), Vector3(2.7, 1.2, 0.8), Color("715238"))
	stash = GarageGeometry.box(self, Vector3(-40, 1.3, -27), Vector3(0.7, 0.2, 0.55), Color("9eae66"))
	GarageGeometry.box(self, Vector3(-40, 1.45, -27), Vector3(1.7, 0.13, 0.12), Color("3b4140"))
	camp_marker = GarageGeometry.label(self, Vector3(-40, 4, -27), "ERIKS GÖMSTÄLLE\n[E] FÖRRÅD & LUFTGEVÄR", Color("dfff89"), 27)
	target = StaticBody3D.new()
	target.name = "PracticeTarget"
	target.collision_layer = 16
	target.add_to_group("practice_target")
	add_child(target)
	target.position = Vector3(-53, 1.65, -16)
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 2.4, 0.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	target.add_child(collision)
	GarageGeometry.box(target, Vector3.ZERO, shape.size, Color("ead6ab"))
	GarageGeometry.box(target, Vector3(0, 0, 0.17), Vector3(1, 1, 0.05), Color("c54d43"))
	GarageGeometry.box(target, Vector3(0, 0, 0.21), Vector3(0.35, 0.35, 0.05), Color("f5e5be"))
	GarageGeometry.box(target, Vector3(0, -1.3, 0), Vector3(0.18, 1, 0.18), Color("69553e"))
	GarageGeometry.label(target, Vector3(0, 2, 0), "MÅLTAVLA • BARA BURKAR", Color("efe2bb"), 20)
	clue = Node3D.new()
	add_child(clue)
	clue.position = Vector3(-44, 1.7, -29.8)
	for i in range(6):
		GarageGeometry.box(clue, Vector3((i % 3) * 0.18, 0, (i / 3) * 0.17), Vector3(0.12, 0.1, 0.13), Color("ffc36b"))
	clue_marker = GarageGeometry.label(clue, Vector3(0, 1.5, 0), "HEMLIGA MACKSMULOR\n[E] GRANSKA", Color("ffdb71"), 24)
	clue.visible = false
	GarageGeometry.label(self, Vector3(-23, 2.4, -20), "← ERIKS SKOG / GARAGET →", Color("efdab0"), 23)
	# Physical map edges prevent the car leaving the playable district.
	for side in [-1, 1]:
		GarageGeometry.box(self, Vector3(side * 88, 1, 0), Vector3(1, 4, 180), Color("68765c"), true)
		GarageGeometry.box(self, Vector3(0, 1, side * 88), Vector3(180, 4, 1), Color("68765c"), true)

func house(pos: Vector3, size: Vector3, color: Color) -> void:
	GarageGeometry.box(self, pos + Vector3.UP * size.y * 0.5, size, color, true)
	obstacles.append(Rect2(pos.x - size.x * 0.5, pos.z - size.z * 0.5, size.x, size.z))
	GarageGeometry.box(self, pos + Vector3.UP * (size.y + 0.4), Vector3(size.x + 1, 0.8, size.z + 1), Color("695052"))
	for side in [-1, 1]:
		for x in [-0.26, 0.26]:
			GarageGeometry.box(self, pos + Vector3(x * size.x, 3, side * (size.z * 0.5 + 0.03)), Vector3(1.6, 1.7, 0.1), Color("476473"))

func tree(x: float, z: float, scale_factor: float) -> void:
	trees.append(Vector2(x, z))
	GarageGeometry.box(self, Vector3(x, scale_factor, z), Vector3(0.45, 2 * scale_factor, 0.45), Color("6d563c"), true)
	GarageGeometry.cone(self, Vector3(x, scale_factor * 1.4, z), 2.2 * scale_factor, 4.2 * scale_factor, Color("345c47"))
	GarageGeometry.cone(self, Vector3(x, scale_factor * 3, z), 1.6 * scale_factor, 3.6 * scale_factor, Color("426d4e"))

func walkable(point: Vector3, radius: float) -> bool:
	if absf(point.x) > 84 or absf(point.z) > 84:
		return false
	for obstacle in obstacles:
		if obstacle.grow(radius).has_point(Vector2(point.x, point.z)):
			return false
	for trunk in trees:
		if trunk.distance_to(Vector2(point.x, point.z)) < radius + 0.35:
			return false
	return true
