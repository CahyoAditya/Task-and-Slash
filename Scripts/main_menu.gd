extends Control

## Main menu — scene pertama yang muncul saat game dibuka.
## Semua UI dibuat secara programatik.

const CAFE_SCENE := "res://Scenes/Cafe.tscn"

## Warna palette
const COLOR_BG        := Color(0.04, 0.04, 0.07, 1.0)
const COLOR_ACCENT    := Color(0.42, 0.82, 1.0,  1.0)   # cyan neon
const COLOR_TITLE     := Color(1.0,  0.95, 0.7,  1.0)   # kuning warm
const COLOR_BTN_BG    := Color(0.10, 0.10, 0.18, 1.0)
const COLOR_BTN_HOVER := Color(0.18, 0.18, 0.30, 1.0)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_saved_settings()
	GameManager.focus_duration = 10.0  ## TESTING — hapus/ganti ke 20.0*60.0 sebelum produksi
	_build_ui()
	_play_intro_animation()


func _play_intro_animation() -> void:
	# Mulai dari transparan, fade in ke opaque
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)\
		.set_ease(Tween.EASE_OUT)


## Load durasi timer dari settings file agar konsisten setelah restart
func _load_saved_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		GameManager.focus_duration  = float(cfg.get_value("game", "focus_minutes",  20)) * 60.0
		GameManager.action_duration = float(cfg.get_value("game", "action_minutes",  5)) * 60.0


func _build_ui() -> void:
	# ── Background ──────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── Center container ────────────────────────────────────────────────────
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# ── Judul ───────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "TASK  &  SLASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	vbox.add_child(title)

	# Garis aksen di bawah judul
	var line := ColorRect.new()
	line.color = COLOR_ACCENT
	line.custom_minimum_size = Vector2(420.0, 2.0)
	vbox.add_child(line)

	# ── Tagline ─────────────────────────────────────────────────────────────
	var tagline := Label.new()
	tagline.text = "Pomodoro × Hack & Slash"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 20)
	tagline.add_theme_color_override("font_color", COLOR_ACCENT)
	vbox.add_child(tagline)

	# ── Spacer ───────────────────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 36.0)
	vbox.add_child(spacer)

	# ── Info sesi (dinamis dari settings) ───────────────────────────────────
	var focus_min: int  = int(round(GameManager.focus_duration  / 60.0))
	var action_min: int = int(round(GameManager.action_duration / 60.0))
	var info := Label.new()
	info.text = "🕐 %d menit FOKUS  →  ⚔  %d menit COMBAT" % [focus_min, action_min]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	vbox.add_child(info)

	# ── Stats dari sesi sebelumnya ───────────────────────────────────────────────
	var stats_text := _get_stats_text()
	if not stats_text.is_empty():
		var stats_lbl := Label.new()
		stats_lbl.text = stats_text
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_lbl.add_theme_font_size_override("font_size", 14)
		stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.55, 1.0))
		vbox.add_child(stats_lbl)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0.0, 28.0)
	vbox.add_child(spacer2)

	# ── Tombol Mulai
	var btn_start := _make_button("▶   MULAI FOKUS", COLOR_ACCENT)
	btn_start.pressed.connect(_on_start_pressed)
	vbox.add_child(btn_start)

	# ── Tombol Pengaturan
	var btn_settings := _make_button("⚙   PENGATURAN", Color(0.7, 0.85, 1.0, 1.0))
	btn_settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(btn_settings)

	# ── Tombol Keluar
	var btn_quit := _make_button("KELUAR", Color(0.6, 0.6, 0.6, 1.0))
	btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(btn_quit)

	# ── Versi di sudut ───────────────────────────────────────────────────────
	var ver := Label.new()
	ver.text = "v0.1-dev  |  Sprint 2"
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35, 1.0))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-140.0, -30.0)
	add_child(ver)


## Helper: buat tombol bergaya konsisten
func _make_button(label_text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(320.0, 58.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", accent)
	return btn


func _on_start_pressed() -> void:
	SceneTransition.go_to(CAFE_SCENE)


func _on_settings_pressed() -> void:
	SceneTransition.go_to("res://Scenes/SettingsMenu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _get_stats_text() -> String:
	var cfg := ConfigFile.new()
	var parts: Array[String] = []
	if cfg.load("user://settings.cfg") == OK:
		var sessions: int = cfg.get_value("stats", "sessions_completed", 0)
		if sessions > 0:
			parts.append("🍅 %d sesi selesai" % sessions)
	if cfg.load("user://stats.cfg") == OK:
		var hs: int = cfg.get_value("stats", "highscore", 0)
		if hs > 0:
			parts.append("🏆 Highscore: %d" % hs)
	return "  |  ".join(parts)
