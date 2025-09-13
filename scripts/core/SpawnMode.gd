extends Node3D
class_name SpawnMode

# Shared guide params
@export var start_side: float = 0.27
@export var start_z: float = 0.35
@export var start_y_offset: float = 0.10

@export var spawn_gap: float = 0.34
@export var spawn_z: float = 0.30
@export var spawn_y_offset: float = 0.00

# NEW: baselines so guides match pose bands
@export var use_hips_baseline: bool = true
@export var hips_band_center: float = -0.65

@export var use_chest_baseline: bool = true
@export var chest_band_center: float = -0.05

func update_guides(guide: GhostGuide, head_xf: Transform3D) -> void:
	pass

func spawn(manager: Node, head_xf: Transform3D, left: XRController3D, right: XRController3D, speed: float) -> void:
	pass
