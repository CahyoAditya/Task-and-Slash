extends Node

## AudioManager — Autoload singleton.
## Mengelola bus audio BGM & SFX, memutar audio terpusat.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION        := "audio"

## Volume level (0.0 – 1.0)
var master_volume: float = 1.0
var bgm_volume: float    = 0.8
var sfx_volume: float    = 1.0

## AudioStreamPlayer untuk BGM (looping background music)
var _bgm_player: AudioStreamPlayer = null

## Bus indices (akan di-cache di _ready)
var _master_idx: int = 0
var _bgm_idx: int    = -1
var _sfx_idx: int    = -1


func _ready() -> void:
	_ensure_buses()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)
	load_from_config()
	_apply_volumes()


## Pastikan bus BGM dan SFX ada. Jika belum ada, buat secara programatik.
func _ensure_buses() -> void:
	_master_idx = AudioServer.get_bus_index("Master")

	_bgm_idx = AudioServer.get_bus_index("BGM")
	if _bgm_idx == -1:
		AudioServer.add_bus()
		_bgm_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(_bgm_idx, "BGM")
		AudioServer.set_bus_send(_bgm_idx, "Master")

	_sfx_idx = AudioServer.get_bus_index("SFX")
	if _sfx_idx == -1:
		AudioServer.add_bus()
		_sfx_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(_sfx_idx, "SFX")
		AudioServer.set_bus_send(_sfx_idx, "Master")


## Terapkan volume ke semua bus
func _apply_volumes() -> void:
	if _master_idx >= 0:
		AudioServer.set_bus_volume_db(_master_idx, linear_to_db(master_volume))
	if _bgm_idx >= 0:
		AudioServer.set_bus_volume_db(_bgm_idx, linear_to_db(bgm_volume))
	if _sfx_idx >= 0:
		AudioServer.set_bus_volume_db(_sfx_idx, linear_to_db(sfx_volume))


## ── PUBLIC API ───────────────────────────────────────────────────────────────

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()


func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()


## Putar BGM (looping). Jika stream null, hentikan BGM yang sedang berjalan.
func play_bgm(stream: AudioStream) -> void:
	if _bgm_player == null:
		return
	if stream == null:
		_bgm_player.stop()
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return  # Sudah dimainkan, tidak perlu restart
	_bgm_player.stream = stream
	_bgm_player.play()


## Hentikan BGM
func stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()


## Putar SFX satu kali (fire-and-forget). Jika stream null, tidak melakukan apapun.
func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX"
	# Auto-remove setelah selesai
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


## ── PERSISTENCE ──────────────────────────────────────────────────────────────

func save_to_config() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION, "master", master_volume)
	cfg.set_value(SECTION, "bgm",    bgm_volume)
	cfg.set_value(SECTION, "sfx",    sfx_volume)
	cfg.save(SETTINGS_PATH)


func load_from_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume = cfg.get_value(SECTION, "master", 1.0)
	bgm_volume    = cfg.get_value(SECTION, "bgm",    0.8)
	sfx_volume    = cfg.get_value(SECTION, "sfx",    1.0)
