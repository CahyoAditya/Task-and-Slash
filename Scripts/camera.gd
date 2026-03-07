extends Camera3D

@export var target_path: NodePath
@export var smooth_speed: float = 5.0

# Distance from player
@export var offset: Vector3 = Vector3(0, 2, 10)

var target: Node3D

func _ready() -> void:
	if target_path:
		target = get_node(target_path)

func _physics_process(delta: float) -> void:
	if not target:
		return

	# Determine where the camera wants to be
	var target_pos = target.global_position + offset
	
	# Smoothly move from current position to target position
	global_position = global_position.lerp(target_pos, smooth_speed * delta)
	
	# Optional: Make the camera always look at the player
	look_at(target.global_position)
