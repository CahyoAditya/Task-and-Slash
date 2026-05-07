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
signal session_completed(count: int)
signal parry_cinematic

## Jumlah sesi FOCUS sebelum long break diberikan
const LONG_BREAK_SESSIONS: int = 4

## Durasi fase dalam detik
@export var focus_duration: float = 10.0  ## TESTING: 10 detik (produksi: 20.0 * 60.0)
@export var action_duration: float = 5.0 * 60.0
@export var long_break_duration: float = 15.0 * 60.0

var current_state: GameState = GameState.FOCUS
var sessions_completed: int = 0
var _timer: Timer

## Level prioritas time_scale: 0=normal, 1=dash slowmo, 2=hitstop, 3=parry cinematic
var _timescale_level: int = 0


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer_timeout)
	load_session_count()
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
	var total: int = int(seconds)
	var mins: int = total / 60
	var secs: int = total % 60
	return "%02d:%02d" % [mins, secs]


func _on_timer_timeout() -> void:
	match current_state:
		GameState.FOCUS:
			sessions_completed += 1
			save_session_count()
			session_completed.emit(sessions_completed)
			change_state(GameState.READY)
		GameState.ACTION:
			change_state(GameState.FOCUS)


## Kembalikan true jika sesi berikutnya adalah long break
func is_long_break_due() -> bool:
	return sessions_completed > 0 and sessions_completed % LONG_BREAK_SESSIONS == 0


## Simpan jumlah sesi ke disk
func save_session_count() -> void:
	var cfg := ConfigFile.new()
	# Muat data yang sudah ada agar tidak menimpa key lain
	cfg.load("user://settings.cfg")
	cfg.set_value("stats", "sessions_completed", sessions_completed)
	cfg.save("user://settings.cfg")


## Muat jumlah sesi dari disk
func load_session_count() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://settings.cfg")
	if err == OK:
		sessions_completed = cfg.get_value("stats", "sessions_completed", 0)


## Trigger screen shake — camera.gd menerima signal ini
func request_screen_shake(amount: float, duration: float) -> void:
	screen_shake.emit(amount, duration)


## Hitstop: bekukan waktu sejenak untuk efek impact yang juicy
func do_hitstop(duration: float) -> void:
	if _timescale_level > 2:
		return  # Parry cinematic lebih prioritas
	_timescale_level = 2
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if _timescale_level == 2:
		Engine.time_scale = 1.0
		_timescale_level = 0


## Slowmo ringan — untuk efek dash. Diabaikan jika ada efek yang lebih prioritas.
func do_slowmo(scale: float, duration: float) -> void:
	if _timescale_level > 1:
		return
	_timescale_level = 1
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if _timescale_level == 1:
		Engine.time_scale = 1.0
		_timescale_level = 0


## Efek sinematik saat parry berhasil: slowmo ekstrim + zoom kamera.
## Prioritas tertinggi — mengoverride hitstop dan slowmo.
func request_parry_cinematic() -> void:
	_timescale_level = 3
	parry_cinematic.emit()
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.08, true, false, true).timeout
	Engine.time_scale = 1.0
	_timescale_level = 0
