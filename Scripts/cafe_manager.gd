extends Node3D

enum GameState {
	FOCUS,
	READY,
	ACTION
}

var current_state: GameState = GameState.FOCUS

@onready var phase_timer: Timer = $PhaseTimer
@onready var player: Sprite3D = $Player
@onready var timer_text: RichTextLabel = $TimerText

@export var focus_duration: float = 20 * 60

func _ready() -> void:
	phase_timer.timeout.connect(_on_phase_timer_timeout)
	change_state(GameState.FOCUS)

# Handle the state machine
func change_state(new_state: GameState) -> void:
	current_state = new_state
	
	match current_state:
		GameState.FOCUS:
			print("FOCUS PHASE")
			player.modulate = Color.INDIAN_RED
			phase_timer.start(focus_duration)
			
		GameState.READY:
			print("Press Spacebar")
			player.modulate = Color.YELLOW_GREEN
			phase_timer.stop()
			
		GameState.ACTION:
			print("ACTION PHASE")
			#background.color = Color.SEA_GREEN
			# change scene
			get_tree().change_scene_to_file("res://Scenes/World.tscn") 
			#phase_timer.start(action_duration)

# Handle the input for change state to action
func _input(event: InputEvent) -> void:
	if current_state == GameState.READY and event.is_action_pressed("ui_accept"):
		change_state(GameState.ACTION)

# Handle timer timeout
func _on_phase_timer_timeout() -> void:
	match current_state:
		GameState.FOCUS:
			change_state(GameState.READY)
			
		#GameState.ACTION:
			#change_state(GameState.FOCUS)

func _process(delta: float) -> void:
	timer_text.text = str("%.2f" % phase_timer.time_left)
