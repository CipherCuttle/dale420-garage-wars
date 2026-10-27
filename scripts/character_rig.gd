extends Node3D
class_name FamilyRig

var kind: String
var upper: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var aura: MeshInstance3D
var headband: MeshInstance3D
var rifle: Node3D
var toast: Node3D
var hair_parts: Array[MeshInstance3D] = []
var phase: float = 0.0

func build(identity: String) -> void:
	kind = identity
	var is_dad := kind == "Lotusmicke"
	var is_player := kind == "Erik"
	var width := 0.55 if is_player else 0.9
	var shirt := Color("697466")
	var pants := Color("303b45")
	match kind:
		"Lotusmicke":
			width = 1.85
			shirt = Color("d6ac38")
		"Morgana":
			width = 0.73
			shirt = Color("7751a1")
		"Bellatrix":
			width = 1.1
			shirt = Color("b33b4d")
		"Sabrina":
			width = 0.7
			shirt = Color("319c9a")
	upper = Node3D.new()
	add_child(upper)
	upper.position.y = 1.1
	GarageGeometry.box(upper, Vector3(0, 0.36, 0), Vector3(width, 0.9, 0.44 if is_player else 0.65), shirt)
	if is_dad:
		GarageGeometry.sphere(upper, Vector3(-0.96, 0.65, 0), 0.4, GarageGeometry.PALE)
		GarageGeometry.sphere(upper, Vector3(0.96, 0.65, 0), 0.4, GarageGeometry.PALE)
		GarageGeometry.box(upper, Vector3(0, 0.72, -0.36), Vector3(0.68, 0.1, 0.05), Color("785027"))
	else:
		GarageGeometry.box(upper, Vector3(0, 0.75, 0.04), Vector3(width + 0.09, 0.22, 0.49), shirt)
	head = Node3D.new()
	upper.add_child(head)
	head.position = Vector3(0, 1.02, -0.06)
	GarageGeometry.box(head, Vector3(0, -0.05, 0), Vector3(0.66 if is_dad else 0.46, 0.46, 0.43), GarageGeometry.PALE)
	GarageGeometry.sphere(head, Vector3(0, 0.17, 0.015), 0.31 if is_dad else 0.27, GarageGeometry.PALE)
	# All biological family members share the same conspicuous ginger material.
	hair_parts.append(GarageGeometry.box(head, Vector3(0, 0.36, 0.02), Vector3(0.69 if is_dad else 0.57, 0.16, 0.52), GarageGeometry.GINGER))
	if is_player:
		hair_parts.append(GarageGeometry.box(head, Vector3(0, 0.10, 0.23), Vector3(0.55, 0.61, 0.18), GarageGeometry.GINGER))
		for i in range(5):
			var bang := GarageGeometry.box(head, Vector3(-0.25 + i * 0.12, 0.15 - absf(i - 2) * 0.025, -0.26), Vector3(0.11, 0.43, 0.12), GarageGeometry.GINGER)
			bang.rotation.z = (i - 2) * 0.15
			hair_parts.append(bang)
		for i in range(8):
			GarageGeometry.sphere(head, Vector3(-0.18 + (i % 4) * 0.12, -0.08 - (i / 4) * 0.06, -0.226), 0.019, Color("b8663c"))
		for pos in [Vector3(-0.19, -0.20, -0.225), Vector3(0.12, -0.17, -0.225), Vector3(0.22, -0.02, -0.225)]:
			GarageGeometry.sphere(head, pos, 0.03, Color("c85451"))
		headband = GarageGeometry.box(head, Vector3(0, 0.23, -0.29), Vector3(0.59, 0.1, 0.05), Color("dd2447"))
		headband.visible = false
	elif is_dad:
		GarageGeometry.box(head, Vector3(0, 0.09, -0.248), Vector3(0.72, 0.16, 0.1), Color("17262d"))
		GarageGeometry.box(head, Vector3(0, -0.22, -0.08), Vector3(0.73, 0.19, 0.48), GarageGeometry.PALE)
		GarageGeometry.box(head, Vector3(0, -0.19, -0.33), Vector3(0.34, 0.045, 0.03), Color("783c2b"))
	else:
		GarageGeometry.box(head, Vector3(0, 0.08, -0.24), Vector3(0.36, 0.055, 0.05), Color("32323a"))
		if kind == "Morgana":
			hair_parts.append(GarageGeometry.sphere(head, Vector3(-0.3, 0.16, 0.03), 0.25, GarageGeometry.GINGER))
			hair_parts.append(GarageGeometry.box(head, Vector3(0.27, -0.03, 0.12), Vector3(0.2, 0.7, 0.3), GarageGeometry.GINGER))
		elif kind == "Bellatrix":
			hair_parts.append(GarageGeometry.sphere(head, Vector3(0.26, 0.36, 0.15), 0.21, GarageGeometry.GINGER))
		else:
			for side in [-1, 1]:
				hair_parts.append(GarageGeometry.box(head, Vector3(side * 0.33, -0.02, 0.08), Vector3(0.18, 0.68, 0.22), GarageGeometry.GINGER))
	for side in [-1, 1]:
		var leg := Node3D.new()
		add_child(leg)
		leg.position = Vector3(side * (0.18 if is_player else 0.28), 0.92, 0)
		GarageGeometry.box(leg, Vector3(0, -0.39, 0), Vector3(0.19 if is_player else 0.36, 0.78, 0.3), pants)
		GarageGeometry.box(leg, Vector3(0, -0.83, -0.10), Vector3(0.25 if is_player else 0.43, 0.15, 0.5), Color("23282a"))
		legs.append(leg)
		var arm := Node3D.new()
		upper.add_child(arm)
		arm.position = Vector3(side * (width * 0.5 + 0.13), 0.69, 0)
		GarageGeometry.box(arm, Vector3(0, -0.3, 0), Vector3(0.16 if is_player else 0.36, 0.65, 0.26 if is_player else 0.39), GarageGeometry.PALE if is_dad else shirt)
		GarageGeometry.sphere(arm, Vector3(0, -0.68, 0), 0.12 if is_player else 0.22, Color("a3263b") if kind == "Bellatrix" else GarageGeometry.PALE)
		arms.append(arm)
	if kind == "Morgana":
		GarageGeometry.box(arms[1], Vector3(0, -0.55, -0.2), Vector3(0.4, 0.5, 0.08), Color("e0d1a5"))
	if kind == "Sabrina":
		GarageGeometry.box(upper, Vector3(0, 0.32, 0.46), Vector3(0.6, 0.7, 0.3), Color("e6b83c"))
	if is_dad:
		toast = GarageGeometry.sandwich(arms[1], Vector3(0, -0.5, -0.22))
	if is_player:
		rifle = Node3D.new()
		arms[1].add_child(rifle)
		GarageGeometry.box(rifle, Vector3(0, -0.52, -0.47), Vector3(0.11, 0.13, 1.25), Color("69482c"))
		GarageGeometry.box(rifle, Vector3(0, -0.45, -1.08), Vector3(0.06, 0.06, 0.6), Color("3c4545"))
		rifle.visible = false
		aura = GarageGeometry.ring(self, Vector3(0, 0.1, 0), 1.12, Color("dfff64"))
		aura.visible = false
	if kind == "Morgana":
		scale = Vector3(1, 1.08, 1)
	elif kind == "Sabrina":
		scale = Vector3(1, 0.95, 1)

func animate(delta: float, moving: float, powered: bool, attack: String, attack_time: float, dodging: bool, hurt: float, equipped: bool = false) -> void:
	phase += delta * (9.0 if powered else 6.0)
	var walk := sin(phase) * minf(moving, 1.0) * (0.65 if powered else 0.4)
	upper.rotation = Vector3(0.20 if kind == "Erik" and not powered else -0.06, 0, 0)
	upper.position.y = 1.08 + absf(sin(phase)) * (0.08 if powered else 0.025)
	for i in range(2):
		legs[i].rotation = Vector3(walk * (1 if i == 0 else -1), 0, (0.14 if powered else 0.02) * (1 if i == 0 else -1))
		arms[i].rotation = Vector3(-0.65 if powered else -walk * (1 if i == 0 else -1), 0, (0.32 if powered else 0.06) * (1 if i == 0 else -1))
	if powered:
		arms[0].rotation.x = -1.2
	if attack_time > 0:
		var swing := sin(minf(attack_time * 9.0, PI))
		if attack in ["kick", "counter"]:
			legs[1].rotation.x = -1.65 * swing
			upper.rotation.z = -0.2 * swing
		else:
			arms[1].rotation.x = -1.9 * swing
			upper.rotation.y = swing * 0.5
	if dodging:
		upper.position.y -= 0.32
		upper.rotation.z = 0.4
	if hurt > 0:
		upper.rotation.x = -0.3
	if kind == "Erik":
		aura.visible = powered
		aura.rotation.y += delta * 3.0
		headband.visible = powered
		rifle.visible = equipped and not powered
