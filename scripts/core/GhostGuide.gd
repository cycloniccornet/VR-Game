# GhostGuide.gd
class_name GhostGuide
extends Node3D

@export var color_start: Color = Color(0.1, 1.0, 0.1, 0.25) # ARMED / start = green
@export var color_spawn: Color = Color(1.0, 1.0, 0.1, 0.25) # SPAWN = yellow
@export var guide_spawn_y_nudge: float = -0.12  # negative = move spawn ghosts down

@export var radius: float = 0.08
@export var unshaded: bool = true

var start_L: MeshInstance3D
var start_R: MeshInstance3D
var spawn_L: MeshInstance3D
var spawn_R: MeshInstance3D

func _ready() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = max(0.01, radius)
	sphere.height = sphere.radius * 2.0

	var mat_start: StandardMaterial3D = _make_mat(color_start)
	var mat_spawn: StandardMaterial3D = _make_mat(color_spawn)

	start_L = _make_ball(sphere, mat_start)
	start_R = _make_ball(sphere, mat_start)
	spawn_L = _make_ball(sphere, mat_spawn)
	spawn_R = _make_ball(sphere, mat_spawn)

	add_child(start_L)
	add_child(start_R)
	add_child(spawn_L)
	add_child(spawn_R)

	# Important: ignore parent transforms so we don't inherit any stretch.
	start_L.top_level = true
	start_R.top_level = true
	spawn_L.top_level = true
	spawn_R.top_level = true

	# Make sure their scale is uniform.
	start_L.scale = Vector3.ONE
	start_R.scale = Vector3.ONE
	spawn_L.scale = Vector3.ONE
	spawn_R.scale = Vector3.ONE

	show_none()


func _make_mat(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m

func _make_ball(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	# Safety: start from identity, no scale.
	mi.transform = Transform3D(Basis(), Vector3.ZERO)
	mi.scale = Vector3.ONE
	return mi


# ---- Positioning ----
func set_start_positions(L: Vector3, R: Vector3) -> void:
	start_L.global_transform = Transform3D(Basis(), L)
	start_R.global_transform = Transform3D(Basis(), R)

func set_spawn_positions(L: Vector3, R: Vector3) -> void:
	spawn_L.global_transform = Transform3D(Basis(), L)
	spawn_R.global_transform = Transform3D(Basis(), R)

# ---- Visibility helpers ----
func show_start_only() -> void:
	start_L.visible = true
	start_R.visible = true
	spawn_L.visible = false
	spawn_R.visible = false

func show_spawn_only() -> void:
	start_L.visible = false
	start_R.visible = false
	spawn_L.visible = true
	spawn_R.visible = true

func show_both() -> void:
	start_L.visible = true
	start_R.visible = true
	spawn_L.visible = true
	spawn_R.visible = true

func show_none() -> void:
	start_L.visible = false
	start_R.visible = false
	spawn_L.visible = false
	spawn_R.visible = false

# ---- Runtime tweaks (optional) ----
func set_alpha(a: float) -> void:
	a = clamp(a, 0.0, 1.0)
	_set_alpha_on(start_L, a)
	_set_alpha_on(start_R, a)
	_set_alpha_on(spawn_L, a)
	_set_alpha_on(spawn_R, a)

func _set_alpha_on(mi: MeshInstance3D, a: float) -> void:
	var mat: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
	if mat:
		var c: Color = mat.albedo_color
		c.a = a
		mat.albedo_color = c

func set_colors(start_col: Color, spawn_col: Color) -> void:
	_update_color_on(start_L, start_col)
	_update_color_on(start_R, start_col)
	_update_color_on(spawn_L, spawn_col)
	_update_color_on(spawn_R, spawn_col)

func _update_color_on(mi: MeshInstance3D, col: Color) -> void:
	var mat: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = col
