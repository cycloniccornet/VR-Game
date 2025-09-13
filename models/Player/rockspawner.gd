#extends Node3D
#
## -----------------------
## Spawning Guides (visual + logic link)
## -----------------------
#@export var show_guides: bool = true
#@export var guide_alpha: float = 0.25
#@export var guide_radius: float = 0.06
#
#@export var guide_start_side: float = 0.27     # X offset of START ghosts (meters)
#@export var guide_start_z: float = 0.35        # forward Z of START ghosts (meters, in front of head)
#@export var guide_y_offset_start: float = 0.10 # vertical offset from head height for START ghosts
#
#@export var guide_spawn_gap: float = 0.34      # total gap (L↔R) for SPAWN ghosts (meters)
#@export var guide_spawn_z: float = 0.30        # forward Z of SPAWN ghosts (meters, in front of head)
#@export var guide_y_offset_spawn: float = 0.00 # vertical offset from head height for SPAWN ghosts
#@export var spawn_gap_tol: float = 0.08        # ± tolerance for spawn gap match (meters)
#
## -----------------------
## Spawning / physics
## -----------------------
#@export var rock_scene: PackedScene
#@export var history_len: int = 8               # midpoint history for throw velocity
#@export var throw_speed_limit: float = 8.0     # m/s cap
#
## -----------------------
## Start pose (arms by sides, elbows ~90°, palms up near hips)
## -----------------------
#@export var start_hold_ms: int = 150
#@export var start_side_min: float = 0.10
#@export var start_side_max: float = 0.80
#@export var start_fwd_max: float = 0.35
#@export var start_gap_max: float = 1.20
#@export var palms_up_dot: float = 0.15
#@export var hips_band_center: float = -0.65    # meters below head height
#@export var hips_band_half: float = 0.35
#@export var require_side_start: bool = false
#
## -----------------------
## Spawn pose (raise to chest, hands face each other)
## -----------------------
#@export var pose_hold_ms: int = 120
#@export var chest_band_center: float = -0.05   # meters below head height
#@export var chest_band_half: float = 0.30
#@export var min_gap: float = 0.18              # legacy; primary gate is guide_spawn_gap±tol
#@export var max_gap: float = 0.55
#@export var require_palms_face: bool = false
#@export var palms_face_dot: float = 0.40
#
## -----------------------
## Device orientation options (which axis represents "palm/forward")
## -----------------------
#@export_enum("forward(-Z)", "down(-Y)", "up(+Y)", "right(+X)", "left(-X)") var palm_axis: int = 1
#@export var invert_palm_up: bool = true
#
## -----------------------
## ARMED timeout (auto-disarm if you leave start pose too long)
## -----------------------
#@export var armed_timeout_ms: int = 5000
#
## -----------------------
## Node refs
## -----------------------
#var left: XRController3D
#var right: XRController3D
#var head: XRCamera3D
#
## -----------------------
## Spawning Guides
## -----------------------
#var _guide_root: Node3D
#var _start_L: MeshInstance3D
#var _start_R: MeshInstance3D
#var _spawn_L: MeshInstance3D
#var _spawn_R: MeshInstance3D
#
## -----------------------
## State
## -----------------------
#enum GState { IDLE, ARMED }
#var state: int = GState.IDLE
#var start_time_ms: int = 0
#var pose_time_ms: int = 0
#var armed_y_mid: float = 0.0
#var out_of_start_ms: int = 0  # counts time spent out of start pose while ARMED
#
## mid history for velocity [{p: Vector3, t: int}]
#var mid_hist: Array = []
#
## debug throttle
#var _dbg_accum: float = 0.0
#@export var _dbg_interval: float = 0.20
#
#func _ready() -> void:
	#left = $"../LeftHand"
	#right = $"../RightHand"
	#head = $"../XRCamera3D"
#
	#var ok: bool = (left != null and right != null and head != null)
	#print("[RockSpawner] Found nodes? left=", left, " right=", right, " head=", head)
	#print("[RockSpawner] Ready. start_hold_ms=", start_hold_ms,
		  #" pose_hold_ms=", pose_hold_ms,
		  #" armed_timeout_ms=", armed_timeout_ms)
#
	#_create_guides()
#
#func _physics_process(delta: float) -> void:
	#if not (left and right and head):
		#return
#
	#var Lg: Transform3D = left.global_transform
	#var Rg: Transform3D = right.global_transform
	#var H_inv: Transform3D = head.global_transform.affine_inverse()
#
	#if show_guides:
		#_update_guides(H_inv)
#
	## midpoint track for throw velocity
	#var mid: Vector3 = 0.5 * (Lg.origin + Rg.origin)
	#_push_mid(mid)
#
	#match state:
		#GState.IDLE:
			#var start: Dictionary = _is_start_pose(Lg, Rg, H_inv)
			#if bool(start.get("ok", false)):
				#start_time_ms += int(delta * 1000.0)
			#else:
				#start_time_ms = max(start_time_ms - int(delta * 2000.0), 0)
#
			#if start_time_ms >= start_hold_ms:
				#state = GState.ARMED
				#armed_y_mid = float(start.get("y_mid_world_off", 0.0))
				#pose_time_ms = 0
				#out_of_start_ms = 0
				#print("\n======================================[  A R M E D  ]======================================")
				#print("[ARMED] y_off_world=", snappedf(armed_y_mid, 0.001),
					  #" palmsUp(L/R)=", snappedf(float(start.get("palms_up_l", 0.0)), 0.02), "/", snappedf(float(start.get("palms_up_r", 0.0)), 0.02),
					  #" x(L/R)_head=", snappedf(float(start.get("side_Lx", 0.0)), 0.02), "/", snappedf(float(start.get("side_Rx", 0.0)), 0.02),
					  #" z(L/R)_head=", snappedf(float(start.get("Lz", 0.0)), 0.02), "/", snappedf(float(start.get("Rz", 0.0)), 0.02))
				#print("================================================================================================\n")
#
		#GState.ARMED:
			#var pose: Dictionary = _is_spawn_pose(Lg, Rg, H_inv)
			#if bool(pose.get("ok", false)):
				#pose_time_ms += int(delta * 1000.0)
			#else:
				#pose_time_ms = max(pose_time_ms - int(delta * 600.0), 0)
#
			#if pose_time_ms >= pose_hold_ms:
				#_spawn_boulder()
				#_reset_pose()
				#return
#
			#var still_in_start: bool = bool(_is_start_pose(Lg, Rg, H_inv).get("ok", false))
			#if still_in_start:
				#out_of_start_ms = 0
			#else:
				#out_of_start_ms += int(delta * 1000.0)
				#if out_of_start_ms >= armed_timeout_ms:
					#print("[DISARM] Timeout: left start pose for ", out_of_start_ms, "ms without spawning")
					#_reset_pose()
					#return
#
	## Throttled debug
	#_dbg_accum += delta
	#if _dbg_accum >= _dbg_interval:
		#_dbg_accum = 0.0
		#_print_dbg(Lg, Rg, H_inv)
#
## -----------------------
## Pose helpers
## -----------------------
#func axis_vec(t: Transform3D) -> Vector3:
	#match palm_axis:
		#0: return -t.basis.z  # forward(-Z)
		#1: return -t.basis.y  # down(-Y)
		#2: return  t.basis.y  # up(+Y)
		#3: return  t.basis.x  # right(+X)
		#4: return -t.basis.x  # left(-X)
		#_: return -t.basis.y
#
#func _is_start_pose(Lg: Transform3D, Rg: Transform3D, H_inv: Transform3D) -> Dictionary:
	## head-space for X/Z (to match markers), but WORLD Y relative to head height (pitch/roll invariant)
	#var Lh: Transform3D = H_inv * Lg
	#var Rh: Transform3D = H_inv * Rg
	#var head_y: float = head.global_transform.origin.y
#
	## palms-up (uses controller axes in world)
	#var rawL: Vector3 = axis_vec(Lg).normalized()
	#var rawR: Vector3 = axis_vec(Rg).normalized()
	#var upL: float = ((-rawL) if invert_palm_up else rawL).dot(Vector3.UP)
	#var upR: float = ((-rawR) if invert_palm_up else rawR).dot(Vector3.UP)
	#var palms_up_ok: bool = (upL > palms_up_dot and upR > palms_up_dot)
#
	## by sides / forward within head-space XZ
	#var side_ok: bool = (
		#abs(Lh.origin.x) > start_side_min and abs(Rh.origin.x) > start_side_min and
		#abs(Lh.origin.x) < start_side_max and abs(Rh.origin.x) < start_side_max and
		#abs(Lh.origin.z) < start_fwd_max and abs(Rh.origin.z) < start_fwd_max
	#)
#
	## near hips: use WORLD Y minus head height
	#var y_mid_world: float = 0.5 * (Lg.origin.y + Rg.origin.y)
	#var y_off_from_head: float = y_mid_world - head_y
	#var in_hips: bool = (y_off_from_head > hips_band_center - hips_band_half
		#and y_off_from_head < hips_band_center + hips_band_half)
#
	## not too far apart (any orientation)
	#var gap: float = Lg.origin.distance_to(Rg.origin)
	#var gap_ok: bool = (gap < start_gap_max)
#
	#return {
		#"ok": palms_up_ok and in_hips and gap_ok and (side_ok or not require_side_start),
		#"palms_up_l": upL, "palms_up_r": upR,
		#"side_Lx": Lh.origin.x, "side_Rx": Rh.origin.x,
		#"Lz": Lh.origin.z, "Rz": Rh.origin.z,
		#"y_mid_world_off": y_off_from_head, "in_hips": in_hips,
		#"gap": gap, "gap_ok": gap_ok
	#}
#
#func _is_spawn_pose(Lg: Transform3D, Rg: Transform3D, H_inv: Transform3D) -> Dictionary:
	#var head_y: float = head.global_transform.origin.y
#
	## chest band: WORLD Y relative to head height
	#var y_mid_world: float = 0.5 * (Lg.origin.y + Rg.origin.y)
	#var y_off_from_head: float = y_mid_world - head_y
	#var in_chest: bool = (y_off_from_head > chest_band_center - chest_band_half
		#and y_off_from_head < chest_band_center + chest_band_half)
#
	## GAP must match visual guides: guide_spawn_gap ± spawn_gap_tol
	#var gap: float = Lg.origin.distance_to(Rg.origin)
	#var gap_ok: bool = (abs(gap - guide_spawn_gap) <= spawn_gap_tol)
#
	## Optional facing check (uses world axes)
	#var dir: Vector3 = (Rg.origin - Lg.origin)
	#var dir_norm: Vector3 = dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	#var face_L: Vector3 = axis_vec(Lg).normalized()
	#var face_R: Vector3 = axis_vec(Rg).normalized()
	#var dot_l: float = face_L.dot(dir_norm)
	#var dot_r: float = face_R.dot(-dir_norm)
	#var palms_face: bool = (dot_l > palms_face_dot and dot_r > palms_face_dot)
#
	#var ok: bool = in_chest and gap_ok and (palms_face or not require_palms_face)
#
	#return {
		#"ok": ok,
		#"in_chest": in_chest,
		#"gap": gap, "gap_ok": gap_ok,
		#"palms_face": palms_face,
		#"dot_l": dot_l, "dot_r": dot_r,
		#"y_mid_world_off": y_off_from_head
	#}
#
## -----------------------
## Velocity tracking
## -----------------------
#func _push_mid(p: Vector3) -> void:
	#mid_hist.push_front({"p": p, "t": Time.get_ticks_msec()})
	#if mid_hist.size() > history_len:
		#mid_hist.pop_back()
#
#func _mid_vel() -> Vector3:
	#if mid_hist.size() < 3:
		#return Vector3.ZERO
	#var a: Dictionary = mid_hist[0]
	#var b: Dictionary = mid_hist[mid_hist.size() - 1]
	#var dt: float = max(float(a["t"] - b["t"]) / 1000.0, 0.0001)
	#return (a["p"] - b["p"]) / dt
#
## -----------------------
## Spawning
## -----------------------
#func _spawn_boulder() -> void:
	#var rock: RigidBody3D = RigidBody3D.new()
	#rock.continuous_cd = true
#
	## --- Visual ---
	#var mesh: BoxMesh = BoxMesh.new()
	#mesh.size = Vector3(0.30, 0.30, 0.03)
	#var mi: MeshInstance3D = MeshInstance3D.new()
	#mi.mesh = mesh
	#rock.add_child(mi)
#
	## --- Collision ---
	#var col: CollisionShape3D = CollisionShape3D.new()
	#var shape: BoxShape3D = BoxShape3D.new()
	#shape.size = Vector3(0.30, 0.30, 0.03)
	#col.shape = shape
	#rock.add_child(col)
#
	## --- Despawn on hit ---
	#rock.contact_monitor = true
	#rock.max_contacts_reported = 1
	#rock.connect("body_entered", Callable(self, "_on_rock_body_entered").bind(rock))
#
	#get_tree().current_scene.add_child(rock)
#
	## Launch forward
	#var Lp: Vector3 = left.global_transform.origin
	#var Rp: Vector3 = right.global_transform.origin
	#var mid: Vector3 = 0.5 * (Lp + Rp)
	#var forward: Vector3 = (-head.global_transform.basis.z).normalized()
#
	#var pos: Vector3 = mid + forward * 0.50
	#var xf: Transform3D = Transform3D().looking_at(pos + forward, Vector3.UP)
	#xf.origin = pos
	#rock.global_transform = xf
	#rock.linear_velocity = forward * throw_speed_limit
#
	#print("[SPAWN] square at ", pos, " vel=", rock.linear_velocity)
	#
#func _on_rock_body_entered(body: Node, rock: RigidBody3D) -> void:
	#if rock and rock.is_inside_tree():
		#rock.queue_free()
#
#func _make_temp_rock() -> RigidBody3D:
	#var rb: RigidBody3D = RigidBody3D.new()
	#var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	#var sphere: SphereMesh = SphereMesh.new()
	#sphere.radius = 0.12
	#mesh_inst.mesh = sphere
	#var col: CollisionShape3D = CollisionShape3D.new()
	#var shape: SphereShape3D = SphereShape3D.new()
	#shape.radius = 0.12
	#col.shape = shape
	#rb.add_child(mesh_inst)
	#rb.add_child(col)
	#return rb
#
#func _reset_pose() -> void:
	#state = GState.IDLE
	#start_time_ms = 0
	#pose_time_ms = 0
	#out_of_start_ms = 0
	#mid_hist.clear()
#
## -----------------------
## Debug print
## -----------------------
#func _print_dbg(Lg: Transform3D, Rg: Transform3D, H_inv: Transform3D) -> void:
	#var head_y: float = head.global_transform.origin.y
#
	## World-y relative to head height (orientation-invariant)
	#var y_mid_world: float = 0.5 * (Lg.origin.y + Rg.origin.y)
	#var y_off_from_head: float = y_mid_world - head_y
	#var hips_band: bool = (y_off_from_head > hips_band_center - hips_band_half
		#and y_off_from_head < hips_band_center + hips_band_half)
	#var chest_band: bool = (y_off_from_head > chest_band_center - chest_band_half
		#and y_off_from_head < chest_band_center + chest_band_half)
#
	## For display: palms-up and face dots
	#var rawL: Vector3 = axis_vec(Lg).normalized()
	#var rawR: Vector3 = axis_vec(Rg).normalized()
	#var upL: float = ((-rawL) if invert_palm_up else rawL).dot(Vector3.UP)
	#var upR: float = ((-rawR) if invert_palm_up else rawR).dot(Vector3.UP)
#
	#var dir: Vector3 = (Rg.origin - Lg.origin)
	#var dir_norm: Vector3 = dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD
	#var dot_l: float = rawL.dot(dir_norm)
	#var dot_r: float = rawR.dot(-dir_norm)
#
	#var gap: float = Lg.origin.distance_to(Rg.origin)
	#var start_ms: int = start_time_ms
	#var pose_ms: int = pose_time_ms
#
	#print("[DBG] state=", state,
		  #" y_off_head=", snappedf(y_off_from_head, 0.003),
		  #" hips_band=", hips_band,
		  #" chest_band=", chest_band,
		  #" gap=", snappedf(gap, 0.003),
		  #" palms_up(L/R)=", snappedf(upL, 0.02), "/", snappedf(upR, 0.02),
		  #" palms_face=", (dot_l > palms_face_dot and dot_r > palms_face_dot),
		  #" dot(L/R)=", snappedf(dot_l, 0.02), "/", snappedf(dot_r, 0.02),
		  #" start_ms=", start_ms, " pose_ms=", pose_ms,
		  #" out_of_start_ms=", out_of_start_ms)
#
## -----------------------
## Guides
## -----------------------
#func _create_guides() -> void:
	#_guide_root = Node3D.new()
	#head.add_child(_guide_root)
#
	## Start = green
	#var mat_start: StandardMaterial3D = StandardMaterial3D.new()
	#mat_start.albedo_color = Color(0.1, 1.0, 0.1, guide_alpha) # green
	#mat_start.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#mat_start.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
#
	## Spawn = yellow
	#var mat_spawn: StandardMaterial3D = StandardMaterial3D.new()
	#mat_spawn.albedo_color = Color(1.0, 1.0, 0.1, guide_alpha) # yellow
	#mat_spawn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	#mat_spawn.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
#
	## Sphere mesh
	#var sphere: SphereMesh = SphereMesh.new()
	#sphere.radius = max(guide_radius, 0.08)
	#sphere.height = sphere.radius * 2.0
	#sphere.radial_segments = 24
	#sphere.rings = 12
#
	## Start L/R
	#_start_L = MeshInstance3D.new()
	#_start_L.mesh = sphere
	#_start_L.set_surface_override_material(0, mat_start)
	#_guide_root.add_child(_start_L)
#
	#_start_R = MeshInstance3D.new()
	#_start_R.mesh = sphere
	#_start_R.set_surface_override_material(0, mat_start)
	#_guide_root.add_child(_start_R)
#
	## Spawn L/R
	#_spawn_L = MeshInstance3D.new()
	#_spawn_L.mesh = sphere
	#_spawn_L.set_surface_override_material(0, mat_spawn)
	#_guide_root.add_child(_spawn_L)
#
	#_spawn_R = MeshInstance3D.new()
	#_spawn_R.mesh = sphere
	#_spawn_R.set_surface_override_material(0, mat_spawn)
	#_guide_root.add_child(_spawn_R)
#
	#_guide_root.visible = show_guides
	#print("[Guides] created under head; show_guides=", show_guides)
#
#func _update_guides(_H_inv_unused: Transform3D) -> void:
	#if not _guide_root or not head:
		#return
#
	## Head basis & position
	#var hgt: Transform3D = head.global_transform
	#var head_pos: Vector3 = hgt.origin
	#var fwd: Vector3 = (-hgt.basis.z).normalized()
	#var right: Vector3 = hgt.basis.x.normalized()
#
	## ---------- START ghosts ----------
	#var sx: float = guide_start_side
	#var sz: float = guide_start_z
	#var start_center: Vector3 = head_pos + fwd * sz
	#start_center.y = head_pos.y + hips_band_center + guide_y_offset_start
#
	#var start_L_pos: Vector3 = start_center + right * (-sx)
	#var start_R_pos: Vector3 = start_center + right * ( sx)
	#_start_L.global_transform = Transform3D(Basis(), start_L_pos)
	#_start_R.global_transform = Transform3D(Basis(), start_R_pos)
#
	## ---------- SPAWN ghosts ----------
	#var cx: float = guide_spawn_gap * 0.5
	#var cz: float = guide_spawn_z
	#var spawn_center: Vector3 = head_pos + fwd * cz
	#spawn_center.y = head_pos.y + chest_band_center + guide_y_offset_spawn
#
	#var spawn_L_pos: Vector3 = spawn_center + right * (-cx)
	#var spawn_R_pos: Vector3 = spawn_center + right * ( cx)
	#_spawn_L.global_transform = Transform3D(Basis(), spawn_L_pos)
	#_spawn_R.global_transform = Transform3D(Basis(), spawn_R_pos)
#
	## Visibility by state
	#var show_start_state: bool = show_guides and state == GState.IDLE
	#var show_spawn_state: bool = show_guides and state == GState.ARMED
	#_start_L.visible = show_start_state
	#_start_R.visible = show_start_state
	#_spawn_L.visible = show_spawn_state
	#_spawn_R.visible = show_spawn_state
#
	#_guide_root.visible = show_guides
