extends Node3D

@export var rock_scene: PackedScene
@export var min_gap := 0.32
@export var max_gap := 0.55
@export var pose_hold_ms := 120
@export var history_len := 8
@export var require_palms_face := true  # set true once things work
@export var palms_face_dot := 0.45          # was 0.4 → much looser




var left: XRController3D
var right: XRController3D
var head: XRCamera3D

var pose_time_ms := 0
var mid_hist := [] # [{p: Vector3, t: int}]
var dbg_accum := 0.0   # throttle prints to ~4/s

func _ready():
	left  = $"../LeftHand"
	right = $"../RightHand"
	head  = $"../XRCamera3D"
	print("[RockSpawner] Found nodes? left=", left, " right=", right, " head=", head)
	print("[RockSpawner] Ready. min_gap=", min_gap, " max_gap=", max_gap, " hold_ms=", pose_hold_ms)

func _physics_process(delta):
	if not (left and right and head):
		if Time.get_ticks_msec() % 1000 < 20:
			print("[RockSpawner] Waiting for nodes… left=", left, " right=", right, " head=", head)
		return

	# Controller transforms
	var Lg := left.global_transform
	var Rg := right.global_transform
	var Lp: Vector3 = Lg.origin
	var Rp: Vector3 = Rg.origin
	var mid: Vector3 = 0.5 * (Lp + Rp)
	_push_mid(mid)

	# Head-local for consistent spatial tests
	var H_inv := head.global_transform.affine_inverse()
	var Lh := H_inv * Lg
	var Rh := H_inv * Rg

	var gap: float = Lh.origin.distance_to(Rh.origin)

	var dir := (Rh.origin - Lh.origin)
	var dir_norm: Vector3
	if dir.length() > 0.0001:
		dir_norm = dir.normalized()
	else:
		dir_norm = Vector3.FORWARD

	# Use controller -Z as "forward"
	var l_fwd := -Lg.basis.z
	var r_fwd := -Rg.basis.z
	var palms_face: bool = (l_fwd.dot(dir_norm) > palms_face_dot and r_fwd.dot(-dir_norm) > palms_face_dot)

	# Height band (very loose): ~waist..forehead
	var y_mid: float = 0.5 * (Lh.origin.y + Rh.origin.y)
	# Was: y between -0.35..0.35
	var in_band: bool = (y_mid > -0.28 and y_mid < 0.02)

	var pose_ok: bool = (gap > min_gap and gap < max_gap) and in_band and (palms_face or not require_palms_face)

	# Debounce
	if pose_ok:
		pose_time_ms += int(delta * 1000.0)
	else:
		pose_time_ms = max(pose_time_ms - int(delta * 2000.0), 0)

	# Throttled prints (every ~0.25s)
	# Print every ~0.25s
	dbg_accum += delta
	if dbg_accum >= 0.25:
		dbg_accum = 0.0
		print("[DBG] gap=", snappedf(gap, 0.001),
			  " y_mid=", snappedf(y_mid, 0.001),
			  " pose_ok=", pose_ok,
			  " pose_ms=", pose_time_ms,
			  " L=", Lp, " R=", Rp)

	# Spawn after hold
	if pose_time_ms >= 60: # fast trigger for POC
		print("[SPAWN] pose held ", pose_time_ms, "ms")
		_spawn_boulder()
		_reset_pose()

func _push_mid(p: Vector3):
	mid_hist.push_front({"p": p, "t": Time.get_ticks_msec()})
	if mid_hist.size() > history_len:
		mid_hist.pop_back()

func _mid_vel() -> Vector3:
	if mid_hist.size() < 3:
		return Vector3.ZERO
	var a = mid_hist[0]
	var b = mid_hist[mid_hist.size() - 1]
	var dt: float = max(float(a.t - b.t) / 1000.0, 0.0001)
	return (a.p - b.p) / dt

func _spawn_boulder():
	var rock: RigidBody3D = rock_scene.instantiate() if rock_scene else _make_temp_rock()
	get_tree().current_scene.add_child(rock)

	var Lp: Vector3 = left.global_transform.origin
	var Rp: Vector3 = right.global_transform.origin
	var mid: Vector3 = 0.5 * (Lp + Rp)

	var dir := (Rp - Lp)
	var dir_norm: Vector3
	if dir.length() > 0.0001:
		dir_norm = dir.normalized()
	else:
		dir_norm = Vector3.FORWARD

	var pos := mid + dir_norm * 0.08
	var xf := Transform3D().looking_at(pos + (-dir_norm), Vector3.UP)  # -Z faces -dir
	xf.origin = pos
	rock.global_transform = xf

	rock.linear_velocity = _mid_vel().limit_length(8.0)
	print("[SPAWN] rock at ", pos, " vel=", rock.linear_velocity)

func _make_temp_rock() -> RigidBody3D:
	var rb = RigidBody3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	mesh.mesh = sphere
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.12
	col.shape = shape
	rb.add_child(mesh)
	rb.add_child(col)
	return rb

func _reset_pose():
	pose_time_ms = 0
	mid_hist.clear()
