extends SpawnMode
class_name SquareShot

func update_guides(guide: GhostGuide, head_xf: Transform3D) -> void:
	var head_pos: Vector3 = head_xf.origin
	var fwd: Vector3 = (-head_xf.basis.z).normalized()
	var right: Vector3 = head_xf.basis.x.normalized()

	# START ghosts (use the shared params)
	var start_center: Vector3 = head_pos + fwd * start_z
	start_center.y = head_pos.y + start_y_offset
	guide.set_start_positions(
		start_center - right * start_side,
		start_center + right * start_side
	)

	# SPAWN ghosts (use the same params your logic uses)
	var cx: float = spawn_gap * 0.5
	var spawn_center: Vector3 = head_pos + fwd * spawn_z
	spawn_center.y = head_pos.y + spawn_y_offset
	guide.set_spawn_positions(
		spawn_center - right * cx,
		spawn_center + right * cx
	)

func spawn(manager: Node, head_xf: Transform3D, left: XRController3D, right: XRController3D, speed: float) -> void:
	var rock := RigidBody3D.new()
	rock.continuous_cd = true

	# visual
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.30, 0.30, 0.03)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mi.set_surface_override_material(0, mat)
	rock.add_child(mi)

	# collision
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	col.shape = shape
	rock.add_child(col)

	get_tree().current_scene.add_child(rock)

	# spawn position & forward from head height (matches guides)
	var head_pos: Vector3 = head_xf.origin
	var fwd: Vector3 = (-head_xf.basis.z).normalized()

	var spawn_center: Vector3 = head_pos + fwd * spawn_z
	spawn_center.y = head_pos.y + spawn_y_offset

	rock.global_transform = Transform3D(Basis().looking_at(spawn_center + fwd, Vector3.UP), spawn_center)
	rock.linear_velocity = fwd * speed

	# cleanup on hit
	rock.body_entered.connect(manager._on_rock_body_entered.bind(rock))
