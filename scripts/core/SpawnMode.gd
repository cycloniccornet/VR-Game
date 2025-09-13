extends Node3D
class_name SpawnMode

# Shared guide params (the same values your guides & logic should use)
@export var start_side: float = 0.27
@export var start_z: float = 0.35
@export var start_y_offset: float = 0.10

@export var spawn_gap: float = 0.34
@export var spawn_z: float = 0.30
@export var spawn_y_offset: float = 0.00

func update_guides(guide: GhostGuide, head_xf: Transform3D) -> void:
	# Base does nothing; concrete modes override
	pass

func spawn(manager: Node, head_xf: Transform3D, left: XRController3D, right: XRController3D, speed: float) -> void:
	# Base does nothing; concrete modes override
	pass
