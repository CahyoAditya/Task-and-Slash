extends Node

## Central Pomodoro state machine — Autoload singleton.
## Single source of truth untuk GameState dan timer.
## Scene lain subscribe ke signal state_changed.

enum GameState {
	FOCUS,   ## 20 menit kerja/fokus
	READY,   ## Menunggu Spacebar dari player
	ACTION   ## 5 menit combat
}

signal state_changed(new_state: GameState)
signal screen_shake(amount: float, duration: float)

## Durasi fase dalam detik (ubah ke nilai kecil saat testing)
@export var focus_duration: float = 0.1 * 60.0
@export var action_duration: float = 5.0 * 60.0

var current_state: GameState = GameState.FOCUS
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)
	# Jangan auto-start — cafe_manager.gd yang akan memulai fase FOCUS


func change_state(new_state: GameState) -> void:
	current_state = new_state
	match current_state:
		GameState.FOCUS:
			_timer.start(focus_duration)
		GameState.READY:
			_timer.stop()
		GameState.ACTION:
			_timer.start(action_duration)
	state_changed.emit(current_state)


## Kembalikan sisa waktu timer yang sedang berjalan
func get_time_left() -> float:
	return _timer.time_left


## Format detik menjadi string "MM:SS"
func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func _on_timer_timeout() -> void:
	match current_state:
		GameState.FOCUS:
			change_state(GameState.READY)
		GameState.ACTION:
			change_state(GameState.FOCUS)


## Trigger screen shake — camera.gd menerima signal ini
func request_screen_shake(amount: float, duration: float) -> void:
	screen_shake.emit(amount, duration)


## Hitstop: bekukan waktu sejenak untuk efek impact yang juicy
func do_hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	# ignore_time_scale=true agar timer tetap jalan meski time_scale hampir 0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
