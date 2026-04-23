extends Node

## AudioManager — Autoload singleton.
## Infrastruktur audio terpusat. Siap untuk BGM/SFX saat aset tersedia.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION        := "audio"

var master_volume: float = 1.0
var bgm_volume: float    = 0.8
var sfx_volume: float    = 1.0


func _ready() -> void:
	load_from_config()
	_apply_volumes()


func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()


func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()


func _apply_volumes() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
	# BGM & SFX bus akan ditambahkan di Godot Audio settings nanti
	# Saat ini cukup kontrol Master


func save_to_config() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # Preserve existing sections (game settings, dll)
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
