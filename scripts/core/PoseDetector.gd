class_name PoseDetector
extends RefCounted

# All thresholds are fields so SpawnerManager can set them once.
var start_side_min: float
var start_side_max: float
var start_fwd_max: float
var start_gap_max: float
var palms_up_dot: float
var hips_band_center: float
var hips_band_half: float

var chest_band_center: float
var chest_band_half: float
var min_gap: float
var max_gap: float
var palms_face_dot: float
var require_palms_face: bool
var palm_axis: int
var invert_palm_up: bool
var require_side_start: bool

func _axis_vec(t: Transform3D) -> Vector3:
	match palm_axis:
		0: return -t.basis.z
		1: return -t.basis.y
		2: return  t.basis.y
		3: return  t.basis.x
		4: return -t.basis.x
		_: return -t.basis.y

func is_start_ok(Lg: Transform3D, Rg: Transform3D, H_inv: Transform3D) -> Dictionary:
	var Lh := H_inv * Lg
	var Rh := H_inv * Rg
	var Lp := Lh.origin
	var Rp := Rh.origin

	var rawL := _axis_vec(Lg).normalized()
	var rawR := _axis_vec(Rg).normalized()
	var upL: float = (-rawL if invert_palm_up else rawL).dot(Vector3.UP)
	var upR: float = (-rawR if invert_palm_up else rawR).dot(Vector3.UP)
	var palms_up_ok := (upL > palms_up_dot and upR > palms_up_dot)

	var side_ok: bool = (
		abs(Lp.x) > start_side_min and abs(Rp.x) > start_side_min and
		abs(Lp.x) < start_side_max and abs(Rp.x) < start_side_max and
		abs(Lp.z) < start_fwd_max and abs(Rp.z) < start_fwd_max
	)

	var y_mid := 0.5 * (Lp.y + Rp.y)
	var in_hips := (y_mid > hips_band_center - hips_band_half and y_mid < hips_band_center + hips_band_half)

	var gap := Lp.distance_to(Rp)
	var gap_ok := (gap < start_gap_max)

	return {
		"ok": palms_up_ok and in_hips and gap_ok and (side_ok or not require_side_start),
		"y_mid": y_mid,
		"palms_up_l": upL, "palms_up_r": upR,
		"Lz": Lp.z, "Rz": Rp.z, "side_Lx": Lp.x, "side_Rx": Rp.x,
		"gap": gap
	}

func is_spawn_ok(Lg: Transform3D, Rg: Transform3D, H_inv: Transform3D) -> Dictionary:
	var Lh := H_inv * Lg
	var Rh := H_inv * Rg
	var Lp := Lh.origin
	var Rp := Rh.origin

	var y_mid := 0.5 * (Lp.y + Rp.y)
	var in_chest := (y_mid > chest_band_center - chest_band_half and y_mid < chest_band_center + chest_band_half)

	var gap := Lp.distance_to(Rp)
	var gap_ok := (gap > min_gap and gap < max_gap)

	var dir := (Rg.origin - Lg.origin)
	var dir_norm := dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	var face_L := _axis_vec(Lg).normalized()
	var face_R := _axis_vec(Rg).normalized()
	var dot_l := face_L.dot(dir_norm)
	var dot_r := face_R.dot(-dir_norm)
	var palms_face := (dot_l > palms_face_dot and dot_r > palms_face_dot)

	var ok := in_chest and gap_ok and (palms_face or not require_palms_face)
	return {
		"ok": ok,
		"y_mid": y_mid,
		"gap": gap,
		"palms_face": palms_face,
	}
