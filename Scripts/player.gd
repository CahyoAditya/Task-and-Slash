extends CharacterBody3D

enum GameState {
	WALK,
	DASH,
	RUN
}

@export var speed: float = 6.0
@export var jump_velocity: float = 10.0
@export var transition: float = 0.5

# Gravity default of godot
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_state: GameState = GameState.WALK

@onready var sprite: Sprite3D = $Sprite3D
@onready var run_timer: Timer = $RunTimer

func _ready() -> void:
	run_timer.timeout.connect(_on_run_timer_timeout)
	change_state(GameState.WALK)

# State machine handler
func change_state(new_state: GameState) -> void:
	current_state = new_state
	
	match current_state:
		GameState.WALK:
			print("WALK")
			speed = 6.0
		GameState.DASH:
			print("DASH")
			speed = 20.0
		GameState.RUN:
			print("RUN")
			speed = 10.0


func _physics_process(delta: float) -> void:
	## If you want jump mechanics
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Dash & Run state
	if Input.is_action_just_pressed("sprint"):
		change_state(GameState.DASH)
		await get_tree().create_timer(transition/1.5).timeout
		change_state(GameState.RUN)

	if not is_on_floor():
		velocity.y -= gravity * delta * 2
	
	# Movement handler
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		# Timer for Run to Walk transition
		run_timer.start(transition)
		
		velocity.x = direction * speed
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# Position Z always 0
	velocity.z = 0
	transform.origin.z = 0

	move_and_slide()


func _on_run_timer_timeout() -> void:
	change_state(GameState.WALK)
