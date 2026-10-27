extends RefCounted
class_name GarageGeometry

const GINGER := Color("dc571f")
const PALE := Color("f2d1b6")
static var materials: Dictionary = {}

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key := "%s:%s" % [color.to_html(), glow]
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		if glow:
			mat.emission_enabled = true
			mat.emission = color
		materials[key] = mat
	return materials[key]

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

static func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node

static func cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos + Vector3.UP * height * 0.5
	parent.add_child(node)
	return node

static func label(parent: Node3D, pos: Vector3, words: String, color: Color, font_size: int = 32) -> Label3D:
	var node := Label3D.new()
	node.text = words
	node.font_size = font_size
	node.pixel_size = 0.014
	node.modulate = color
	node.outline_size = 7
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = false
	node.position = pos
	parent.add_child(node)
	return node

static func ring(parent: Node3D, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.06
	mesh.outer_radius = radius + 0.06
	mesh.rings = 24
	mesh.ring_segments = 6
	node.mesh = mesh
	node.material_override = material(color, true)
	node.position = pos
	parent.add_child(node)
	return node

static func sandwich(parent: Node3D, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position = pos
	box(node, Vector3.ZERO, Vector3(0.6, 0.13, 0.5), Color("b97832"))
	box(node, Vector3(0, 0.11, 0), Vector3(0.56, 0.1, 0.46), Color("f9d446"))
	box(node, Vector3(0, 0.22, 0), Vector3(0.6, 0.13, 0.5), Color("d49a4f"))
	return node
