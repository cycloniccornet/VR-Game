extends Node3D
class_name SpawnerManager

# === References ===
var left: XRController3D
var right: XRController3D
var head: XRCamera3D

# === State ===
enum GState { IDLE, ARMED }
var state: int = GState.IDLE
var start_time_ms: int = 0
var pose_time_ms: int = 0
@export var start_hold_ms: int = 150
@export var pose_hold_ms: int = 120
@export var armed_timeout_ms: int = 5000
var out_of_start_ms: int = 0

# === Throw ===
@export var history_len: int = 8
@export var throw_speed_limit: float = 8.0
var mid_hist: Array = []

# === Pose thresholds (wired into PoseDetector) ===
@export var start_side_min: float = 0.10
@export var start_side_max: float = 0.80
@export var start_fwd_max: float = 0.35
@export var start_gap_max: float = 1.20
@export var palms_up_dot: float = 0.15
@export var hips_band_center: float = -0.65
@export var hips_band_half: float = 0.35
@export var require_side_start: bool = false

@export var chest_band_center: float = -0.05
@export var chest_band_half: float = 0.30
@export var min_gap: float = 0.18
@export var max_gap: float = 0.55
@export var require_palms_face: bool = false
@export var palms_face_dot: float = 0.40
@export_enum("forward(-Z)", "down(-Y)", "up(+Y)", "right(+X)", "left(-X)") var palm_axis: int = 1
@export var invert_palm_up: bool = true

# === Guides ===
@export var show_guides: bool = true
var guide: GhostGuide

# === Modes ===
@export var mode_scene: PackedScene
var mode: SpawnMode
var pd: PoseDetector

func _ready() -> void:
	left  = $"../LeftHand"
	right = $"../RightHand"
	head  = $"../XRCamera3D"
	print("[Spawner] Ready.")

	# Pose detector config
	pd = PoseDetector.new()
	pd.start_side_min = start_side_min
	pd.start_side_max = start_side_max
	pd.start_fwd_max = start_fwd_max
	pd.start_gap_max = start_gap_max
	pd.palms_up_dot = palms_up_dot
	pd.hips_band_center = hips_band_center
	pd.hips_band_half = hips_band_half
	pd.require_side_start = require_side_start

	pd.chest_band_center = chest_band_center
	pd.chest_band_half = chest_band_half
	pd.min_gap = min_gap
	pd.max_gap = max_gap
	pd.require_palms_face = require_palms_face
	pd.palms_face_dot = palms_face_dot
	pd.palm_axis = palm_axis
	pd.invert_palm_up = invert_palm_up

	# === Mode instantiation (safe) ===
	var inst: Node = mode_scene.instantiate() if mode_scene else null
	if inst is SpawnMode:
		mode = inst as SpawnMode
	else:
		mode = SquareShot.new()
	add_child(mode) # SpawnMode is a Node3D

	# === Guide ===
	guide = GhostGuide.new()
	add_child(guide)
	guide.visible = show_guides

func _physics_process(delta: float) -> void:
	if not (left and right and head):
		return

	# update guides head-relative (mode defines positions)
	mode.update_guides(guide, head.global_transform)
	if show_guides:
		if state == GState.IDLE:
			guide.show_start_only()
		else:
			guide.show_spawn_only()

	# track mid for velocity (kept for future thrown-speed logic)
	var mid: Vector3 = 0.5 * (left.global_transform.origin + right.global_transform.origin)
	_push_mid(mid)

	var H_inv: Transform3D = head.global_transform.affine_inverse()

	match state:
		GState.IDLE:
			var start: Dictionary = pd.is_start_ok(left.global_transform, right.global_transform, H_inv)
			start_time_ms = (start_time_ms + int(delta * 1000.0)) if bool(start.get("ok", false)) else max(start_time_ms - int(delta * 2000.0), 0)
			if start_time_ms >= start_hold_ms:
				state = GState.ARMED
				pose_time_ms = 0
				out_of_start_ms = 0
				print("\n====================[  A R M E D  ]====================\n")

		GState.ARMED:
			var pose: Dictionary = pd.is_spawn_ok(left.global_transform, right.global_transform, H_inv)
			var ok_pose: bool = bool(pose.get("ok", false))
			pose_time_ms = (pose_time_ms + int(delta * 1000.0)) if ok_pose else max(pose_time_ms - int(delta * 600.0), 0)
			if pose_time_ms >= pose_hold_ms:
				mode.spawn(self, head.global_transform, left, right, throw_speed_limit)
				_reset_pose()
				return

			var still_start: bool = bool(pd.is_start_ok(left.global_transform, right.global_transform, H_inv).get("ok", false))
			out_of_start_ms = 0 if still_start else (out_of_start_ms + int(delta * 1000.0))
			if out_of_start_ms >= armed_timeout_ms:
				print("[DISARM] timeout")
				_reset_pose()

func _push_mid(p: Vector3) -> void:
	mid_hist.push_front({"p": p, "t": Time.get_ticks_msec()})
	if mid_hist.size() > history_len:
		mid_hist.pop_back()

func _mid_vel() -> Vector3:
	if mid_hist.size() < 3:
		return Vector3.ZERO
	var a: Dictionary = mid_hist[0]
	var b: Dictionary = mid_hist[mid_hist.size() - 1]
	var dt: float = max(float(a["t"] - b["t"]) / 1000.0, 0.0001)
	return (a["p"] - b["p"]) / dt

func _reset_pose() -> void:
	state = GState.IDLE
	start_time_ms = 0
	pose_time_ms = 0
	out_of_start_ms = 0
	mid_hist.clear()

func _on_rock_body_entered(_body: Node, rock: RigidBody3D) -> void:
	if rock and rock.is_inside_tree():
		rock.queue_free()
