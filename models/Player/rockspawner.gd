extends Node3D

# -----------------------
# Spawning / physics
# -----------------------
@export var rock_scene: PackedScene
@export var history_len := 8          # midpoint history for throw velocity
@export var throw_speed_limit := 8.0  # m/s cap

# -----------------------
# Start pose (arms by sides, elbows ~90°, palms up near hips)
# -----------------------
@export var start_hold_ms := 150
@export var start_side_min := 0.10     # looser: allow closer to torso
@export var start_side_max := 0.80     # looser: allow further from torso
@export var start_fwd_max := 0.35      # looser: allow a bit more forward/back
@export var start_gap_max := 1.20      # looser: wide hands still ok
@export var palms_up_dot := 0.15       # looser: weaker palms-up needed
@export var hips_band_center := -0.65  # same center
@export var hips_band_half := 0.35     # looser: taller hip band
@export var require_side_start := false  # optional side-by-side check

# -----------------------
# Spawn pose (raise to chest, hands face each other)
# -----------------------
@export var pose_hold_ms := 120
@export var chest_band_center := -0.05
@export var chest_band_half := 0.30
@export var min_gap := 0.18
@export var max_gap := 0.55
@export var require_palms_face := false
@export var palms_face_dot := 0.40     # how strongly hands should face each other

# -----------------------
# Device orientation options (which axis represents "palm/forward")
# -----------------------
@export_enum("forward(-Z)", "down(-Y)", "up(+Y)", "right(+X)", "left(-X)") var palm_axis := 1
@export var invert_palm_up := true     # set true based on your logs (palms-up was negative)

# -----------------------
# ARMED timeout (auto-disarm if you leave start pose too long)
# -----------------------
@export var armed_timeout_ms := 5000

# -----------------------
# Node refs
# -----------------------
var left: XRController3D
var right: XRController3D
var head: XRCamera3D

# -----------------------
# State
# -----------------------
enum GState { IDLE, ARMED }
var state: int = GState.IDLE
var start_time_ms := 0
var pose_time_ms := 0
var armed_y_mid := 0.0
var out_of_start_ms := 0  # counts time spent out of start pose while ARMED

# mid history for velocity [{p: Vector3, t: int}]
var mid_hist: Array = []

# debug throttle
var _dbg_accum := 0.0
@export var _dbg_interval := 0.20

func _ready() -> void:
	# Keep your existing node paths exactly as requested:
	left  = $"../LeftHand"
	right = $"../RightHand"
	head  = $"../XRCamera3D"

	var ok := (left != null and right != null and head != null)
	print("[RockSpawner] Found nodes? left=", left, " right=", right, " head=", head)
	print("[RockSpawner] Ready. start_hold_ms=", start_hold_ms,
		  " pose_hold_ms=", pose_hold_ms,
		  " armed_timeout_ms=", armed_timeout_ms)

func _physics_process(delta: float) -> void:
	if not (left and right and head):
		return

	var Lg := left.global_transform
	var Rg := right.global_transform
	var H_inv := head.global_transform.affine_inverse()

	# midpoint track for throw velocity
	var mid := 0.5 * (Lg.origin + Rg.origin)
	_push_mid(mid)

	match state:
		GState.IDLE:
			var start := _is_start_pose(Lg, Rg, H_inv)
			if start.ok:
				start_time_ms += int(delta * 1000.0)
			else:
				start_time_ms = max(start_time_ms - int(delta * 2000.0), 0)

			if start_time_ms >= start_hold_ms:
				state = GState.ARMED
				armed_y_mid = start.y_mid
				pose_time_ms = 0
				out_of_start_ms = 0
				# Big banner so ARMED is obvious in console
				print("\n======================================[  A R M E D  ]======================================")
				print("[ARMED] y_mid=", snappedf(start.y_mid, 0.001),
					  " palmsUp(L/R)=", snappedf(start.palms_up_l, 0.02), "/", snappedf(start.palms_up_r, 0.02),
					  " x(L/R)=", snappedf(start.side_Lx, 0.02), "/", snappedf(start.side_Rx, 0.02),
					  " z(L/R)=", snappedf(start.Lz, 0.02), "/", snappedf(start.Rz, 0.02))
				print("================================================================================================\n")

		GState.ARMED:
			# Check for spawn pose
			var pose := _is_spawn_pose(Lg, Rg, H_inv)
			if pose.ok:
				pose_time_ms += int(delta * 1000.0)
			else:
				# gentle decay so tiny wobbles don't nuke progress instantly
				pose_time_ms = max(pose_time_ms - int(delta * 600.0), 0)

			# Spawn if held long enough
			if pose_time_ms >= pose_hold_ms:
				_spawn_boulder()
				_reset_pose()
				return

			# Start timeout only once you move out of start pose
			var still_in_start: bool = bool(_is_start_pose(Lg, Rg, H_inv).get("ok", false))
			if still_in_start:
				out_of_start_ms = 0
			else:
				out_of_start_ms += int(delta * 1000.0)
				if out_of_start_ms >= armed_timeout_ms:
					print("[DISARM] Timeout: left start pose for ", out_of_start_ms, "ms without spawning")
					_reset_pose()
					return

	# Throttled debug
	_dbg_accum += delta
	if _dbg_accum >= _dbg_interval:
		_dbg_accum = 0.0
		_print_dbg(Lg, Rg, H_inv)

# -----------------------
# Pose helpers
# -----------------------
func axis_vec(t: Transform3D) -> Vector3:
	match palm_axis:
		0: return -t.basis.z  # forward(-Z)
		1: return -t.basis.y  # down(-Y)
		2: return  t.basis.y  # up(+Y)
		3: return  t.basis.x  # right(+X)
		4: return -t.basis.x  # left(-X)
		_: return -t.basis.y

func _is_start_pose(Lg: Transform3D, Rg: Transform3D, H_inv: Transform3D) -> Dictionary:
	var Lh := H_inv * Lg
	var Rh := H_inv * Rg
	var Lp := Lh.origin
	var Rp := Rh.origin

	# palms up
	var rawL := axis_vec(Lg).normalized()
	var rawR := axis_vec(Rg).normalized()
	var upL: float = (-rawL if invert_palm_up else rawL).dot(Vector3.UP)
	var upR: float = (-rawR if invert_palm_up else rawR).dot(Vector3.UP)
	var palms_up_ok := (upL > palms_up_dot and upR > palms_up_dot)

	# by sides (|x| large enough, not too far), and not forward/back (|z| small)
	var side_ok: bool = (
		abs(Lp.x) > start_side_min and abs(Rp.x) > start_side_min and
		abs(Lp.x) < start_side_max and abs(Rp.x) < start_side_max and
		abs(Lp.z) < start_fwd_max and abs(Rp.z) < start_fwd_max
	)

	# near hips (band)
	var y_mid := 0.5 * (Lp.y + Rp.y)
	var in_hips := (y_mid > hips_band_center - hips_band_half and y_mid < hips_band_center + hips_band_half)

	# not too far apart
	var gap := Lp.distance_to(Rp)
	var gap_ok := (gap < start_gap_max)

	return {
		"ok": palms_up_ok and in_hips and gap_ok and (side_ok or not require_side_start),
		"palms_up_l": upL, "palms_up_r": upR,
		"side_Lx": Lp.x, "side_Rx": Rp.x, "Lz": Lp.z, "Rz": Rp.z,
		"y_mid": y_mid, "in_hips": in_hips,
		"gap": gap, "gap_ok": gap_ok
	}

func _is_spawn_pose(Lg: Transform3D, Rg: Transform3D, H_inv: Transform3D) -> Dictionary:
	var Lh := H_inv * Lg
	var Rh := H_inv * Rg
	var Lp := Lh.origin
	var Rp := Rh.origin

	var y_mid := 0.5 * (Lp.y + Rp.y)
	var in_chest := (y_mid > chest_band_center - chest_band_half and y_mid < chest_band_center + chest_band_half)

	var gap := Lp.distance_to(Rp)
	var gap_ok := (gap > min_gap and gap < max_gap)

	# facing each other (controller "forward" as axis_vec)
	var dir := (Rg.origin - Lg.origin)
	var dir_norm := dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	var face_L := axis_vec(Lg).normalized()
	var face_R := axis_vec(Rg).normalized()
	var dot_l := face_L.dot(dir_norm)
	var dot_r := face_R.dot(-dir_norm)
	var palms_face := (dot_l > palms_face_dot and dot_r > palms_face_dot)

	var ok := in_chest and gap_ok and (palms_face or not require_palms_face)

	return {
		"ok": ok,
		"in_chest": in_chest,
		"gap": gap, "gap_ok": gap_ok,
		"palms_face": palms_face,
		"dot_l": dot_l, "dot_r": dot_r,
		"y_mid": y_mid
	}

# -----------------------
# Velocity tracking
# -----------------------
func _push_mid(p: Vector3) -> void:
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

# -----------------------
# Spawning
# -----------------------
func _spawn_boulder() -> void:
	var rock: RigidBody3D = rock_scene.instantiate() if rock_scene else _make_temp_rock()
	get_tree().current_scene.add_child(rock)

	var Lp: Vector3 = left.global_transform.origin
	var Rp: Vector3 = right.global_transform.origin
	var mid: Vector3 = 0.5 * (Lp + Rp)

	var dir: Vector3 = Rp - Lp
	var dir_norm := dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD

	var pos := mid + dir_norm * 0.08
	var xf := Transform3D().looking_at(pos + (-dir_norm), Vector3.UP) # -Z faces -dir
	xf.origin = pos
	rock.global_transform = xf

	var v := _mid_vel().limit_length(throw_speed_limit)
	rock.linear_velocity = v

	print("[SPAWN] rock at ", pos, " vel=", v)

func _make_temp_rock() -> RigidBody3D:
	var rb := RigidBody3D.new()
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

func _reset_pose() -> void:
	state = GState.IDLE
	start_time_ms = 0
	pose_time_ms = 0
	out_of_start_ms = 0
	mid_hist.clear()

# -----------------------
# Debug print
# -----------------------
func _print_dbg(Lg: Transform3D, Rg: Transform3D, H_inv: Transform3D) -> void:
	var Lh := H_inv * Lg
	var Rh := H_inv * Rg
	var y_mid := 0.5 * (Lh.origin.y + Rh.origin.y)
	var hips_band := (y_mid > hips_band_center - hips_band_half and y_mid < hips_band_center + hips_band_half)
	var chest_band := (y_mid > chest_band_center - chest_band_half and y_mid < chest_band_center + chest_band_half)
	var gap := Lh.origin.distance_to(Rh.origin)

	# For display: palms-up and face dots
	var rawL := axis_vec(Lg).normalized()
	var rawR := axis_vec(Rg).normalized()
	var upL: float = (-rawL if invert_palm_up else rawL).dot(Vector3.UP)
	var upR: float = (-rawR if invert_palm_up else rawR).dot(Vector3.UP)

	var dir := (Rh.origin - Lh.origin)
	var dir_norm := dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	var dot_l := rawL.dot(dir_norm)
	var dot_r := rawR.dot(-dir_norm)

	var start_ms := start_time_ms
	var pose_ms := pose_time_ms

	print("[DBG] state=", state,
		  " y_mid=", snappedf(y_mid, 0.003),
		  " hips_band=", hips_band,
		  " chest_band=", chest_band,
		  " gap=", snappedf(gap, 0.003),
		  " palms_up(L/R)=", snappedf(upL, 0.02), "/", snappedf(upR, 0.02),
		  " palms_face=", (dot_l > palms_face_dot and dot_r > palms_face_dot),
		  " dot(L/R)=", snappedf(dot_l, 0.02), "/", snappedf(dot_r, 0.02),
		  " start_ms=", start_ms, " pose_ms=", pose_ms,
		  " out_of_start_ms=", out_of_start_ms)
