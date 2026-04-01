extends CharacterBody3D

enum GameState {
	WALK,
	DASH,
	RUN,
	ATTACK
}

@export var speed: float = 6.0
@export var jump_velocity: float = 10.0
@export var transition: float = 0.5
@export var att_duration: float = 0.2
@export var friction: float = 30.0

# Gravity default of godot
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_state: GameState = GameState.WALK

@onready var sprite: Sprite3D = $Sprite3D
@onready var run_timer: Timer = $RunTimer
@onready var att_collision: CollisionShape3D = $AttackCollisionShape
@onready var att_sprite: Sprite3D = $AttackCollisionShape/Sprite3D
@onready var att_timer: Timer = $AttackCollisionShape/SprAttTimer

func _ready() -> void:
	run_timer.timeout.connect(_on_run_timer_timeout)
	att_timer.timeout.connect(_on_spr_att_timer_timeout)
	change_state(GameState.WALK)

# State machine handler
func change_state(new_state: GameState) -> void:
	current_state = new_state
	
	match current_state:
		GameState.WALK:
			print("WALK")
			sprite.modulate = Color.WHITE
			speed = 6.0
		GameState.DASH:
			print("DASH")
			sprite.modulate = Color.TRANSPARENT
			speed = 20.0
		GameState.RUN:
			print("RUN")
			sprite.modulate = Color.WHITE
			speed = 10.0
		GameState.ATTACK:
			print("ATTACK")
			sprite.modulate = Color.WHITE
			velocity.x = 0
			att_sprite.visible = true
			att_timer.start(att_duration)

# Function for movement
func movement(delta: float) -> void:
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * speed
		flip_player(direction)
		
		# Timer for Run to Walk transition
		if not run_timer.is_stopped():
			run_timer.stop()
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		if current_state in [GameState.RUN, GameState.DASH] and run_timer.is_stopped():
			run_timer.start(transition)

# Flip logic
func flip_player(direction: float):
	if direction > 0:
		rotation.y = 0
	elif direction < 0:
		rotation.y = PI

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta * 2
	
	if current_state != GameState.ATTACK:
		# Movement handler
		movement(delta)
	
		# Jump mechanics
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity

		# Dash & Run state
		if Input.is_action_just_pressed("sprint") and current_state != GameState.DASH:
				change_state(GameState.DASH)
				await get_tree().create_timer(transition / 1.5).timeout

				if current_state == GameState.DASH:
					change_state(GameState.RUN)

		# Attack mechanics
		if Input.is_action_just_pressed("attack"):
			change_state(GameState.ATTACK)

	# Position Z always 0
	velocity.z = 0
	transform.origin.z = 0

	move_and_slide()


func _on_run_timer_timeout() -> void:
	if current_state != GameState.ATTACK:
		change_state(GameState.WALK)


func _on_spr_att_timer_timeout() -> void:
	att_sprite.visible = false
	change_state(GameState.WALK)
