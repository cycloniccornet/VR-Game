extends SpawnMode
class_name SquareShot

# Choose a simple bitmask scheme:
const LAYER_WORLD      := 1      # bit 1
const LAYER_PLAYER     := 1 << 1 # bit 2
const LAYER_PROJECTILE := 1 << 2 # bit 3

func update_guides(guide: GhostGuide, head_xf: Transform3D) -> void:
	var head_pos: Vector3 = head_xf.origin
	var fwd: Vector3 = (-head_xf.basis.z).normalized()
	var right: Vector3 = head_xf.basis.x.normalized()

	# START ghosts — baseline at hips, like the old script
	var start_center: Vector3 = head_pos + fwd * start_z
	var start_base_y := (hips_band_center if use_hips_baseline else 0.0)
	start_center.y = head_pos.y + start_base_y + start_y_offset
	guide.set_start_positions(
		start_center - right * start_side,
		start_center + right * start_side
	)

	# SPAWN ghosts — baseline at chest (optional but recommended)
	var cx: float = spawn_gap * 0.5
	var spawn_center: Vector3 = head_pos + fwd * spawn_z
	var spawn_base_y := (chest_band_center if use_chest_baseline else 0.0)
	spawn_center.y = head_pos.y + spawn_base_y + spawn_y_offset
	guide.set_spawn_positions(
		spawn_center - right * cx,
		spawn_center + right * cx
	)

func spawn(manager: Node, head_xf: Transform3D, left: XRController3D, right: XRController3D, speed: float) -> void:
	var rock := RigidBody3D.new()
	rock.continuous_cd = true

	# Collisions: projectile layer; ONLY collide with world
	rock.collision_layer = LAYER_PROJECTILE
	rock.collision_mask  = LAYER_WORLD

	# (If your floor/walls are on WORLD and player is on PLAYER,
	# the rock won't hit you anymore.)

	# Enable hit detection
	rock.contact_monitor = true
	rock.max_contacts_reported = 1

	# visuals + collision...
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.30, 0.30, 0.03)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	rock.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	col.shape = shape
	rock.add_child(col)

	get_tree().current_scene.add_child(rock)

	rock.body_entered.connect(manager._on_rock_body_entered.bind(rock))

	# spawn forward from head (see also #2)
	var head_pos: Vector3 = head_xf.origin
	var fwd: Vector3 = (-head_xf.basis.z).normalized()

	var spawn_center: Vector3 = head_pos + fwd * spawn_z
	spawn_center.y = head_pos.y + spawn_y_offset

	rock.global_transform = Transform3D(Basis().looking_at(spawn_center + fwd, Vector3.UP), spawn_center)
	rock.linear_velocity = fwd * speed
