extends CharacterBody3D

@export var speed: float = 6.0
@export var run_speed: float = 10.0
@export var jump_velocity: float = 5

# Gravity default of godot
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var sprite: Sprite3D = $Sprite3D

func _physics_process(delta: float) -> void:
	## If you want jump mechanics
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = jump_velocity

	if not is_on_floor():
		velocity.y -= gravity * delta * 2
	
	# Movement handler
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		# Next task: change this shit to state machine, once for dash and then run
		velocity.x = (direction * run_speed) if Input.is_action_pressed("sprint") else (direction * speed)
		
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# Position Z always 0
	velocity.z = 0
	transform.origin.z = 0

	move_and_slide()
