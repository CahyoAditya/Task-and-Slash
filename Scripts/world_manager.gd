extends Node3D

enum GameState {
	FOCUS,
	READY,
	ACTION
}

var current_state: GameState = GameState.ACTION
@onready var phase_timer: Timer = $PhaseTimer
@onready var timer_text: RichTextLabel = $TimerText
@export var action_duration: float = 5 * 60

func _ready() -> void:
	phase_timer.timeout.connect(_on_phase_timer_timeout)
	change_state(GameState.ACTION)

# Handle the state machine
func change_state(new_state: GameState) -> void:
	current_state = new_state
	
	match current_state:
		GameState.FOCUS:
			print("FOCUS PHASE")
			get_tree().change_scene_to_file("res://Scenes/Cafe.tscn")
			
		GameState.ACTION:
			print("ACTION PHASE")
			phase_timer.start(action_duration)

# Handle timer timeout
func _on_phase_timer_timeout() -> void:
	match current_state:
		GameState.ACTION:
			change_state(GameState.FOCUS)

func _process(delta: float) -> void:
	timer_text.text = str("%.2f" % phase_timer.time_left)
