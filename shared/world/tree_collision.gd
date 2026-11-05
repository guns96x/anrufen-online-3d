class_name TreeCollision
extends RefCounted

## Trunks block movement; the broad crown blocks only the camera (layer8).
## This keeps the orbit camera outside opaque batched foliage without making
## the leafy canopy an invisible wall for the player.
static func add_to(parent: Node3D, placement: Transform3D = Transform3D.IDENTITY) -> void:
	var scale: Vector3 = placement.basis.get_scale().abs()
	var trunk: StaticBody3D = StaticBody3D.new()
	trunk.name = "TrunkCollision"
	trunk.collision_layer = 1
	trunk.collision_mask = 0
	trunk.position = placement.origin+Vector3.UP*1.75*scale.y
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = 0.38*maxf(scale.x,scale.z)
	cylinder.height = 3.5*scale.y
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = cylinder
	trunk.add_child(collision)
	parent.add_child(trunk)
	var canopy: StaticBody3D = StaticBody3D.new()
	canopy.name = "CameraCanopy"
	canopy.collision_layer = 8
	canopy.collision_mask = 0
	canopy.position = placement.origin+Vector3.UP*4.1*scale.y
	canopy.rotation.y = placement.basis.get_euler().y
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6*scale.x,4*scale.y,6*scale.z)
	var crown: CollisionShape3D = CollisionShape3D.new()
	crown.shape = box
	canopy.add_child(crown)
	parent.add_child(canopy)
