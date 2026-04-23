extends Control

## Settings Menu — durasi sesi Pomodoro + kontrol volume.
## Tersimpan ke file via AudioManager & GameManager.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_GAME   := "game"

const C_CYAN  := Color(0.42, 0.82, 1.0, 1.0)
const C_TITLE := Color(1.0,  0.95, 0.7, 1.0)

var _focus_slider:  HSlider = null
var _action_slider: HSlider = null
var _master_slider: HSlider = null
var _bgm_slider:    HSlider = null
var _sfx_slider:    HSlider = null

var _focus_val_lbl:  Label = null
var _action_val_lbl: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_load_values()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.custom_minimum_size = Vector2(480.0, 0.0)
	center.add_child(vbox)

	# ── Judul
	var title := Label.new()
	title.text = "PENGATURAN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	var line := ColorRect.new()
	line.color = C_CYAN
	line.custom_minimum_size = Vector2(0.0, 2.0)
	vbox.add_child(line)

	_add_spacer(vbox, 8.0)

	# ── Bagian: Pomodoro
	_add_section_label(vbox, "⏱  DURASI SESI")
	_focus_slider = _add_slider_row(vbox, "Fase Fokus", 1.0, 60.0, GameManager.focus_duration / 60.0,
		"menit", _focus_val_lbl)
	_focus_val_lbl = _get_last_val_label(vbox)
	_focus_slider.value_changed.connect(_on_focus_changed)

	_action_slider = _add_slider_row(vbox, "Fase Combat", 1.0, 15.0, GameManager.action_duration / 60.0,
		"menit", _action_val_lbl)
	_action_val_lbl = _get_last_val_label(vbox)
	_action_slider.value_changed.connect(_on_action_changed)

	_add_spacer(vbox, 4.0)

	# ── Bagian: Audio
	_add_section_label(vbox, "🔊  AUDIO")
	_master_slider = _add_slider_row(vbox, "Master", 0.0, 1.0, AudioManager.master_volume, "", null)
	_master_slider.step = 0.05
	_master_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_master_volume(v))

	_bgm_slider = _add_slider_row(vbox, "BGM", 0.0, 1.0, AudioManager.bgm_volume, "", null)
	_bgm_slider.step = 0.05
	_bgm_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_bgm_volume(v))

	_sfx_slider = _add_slider_row(vbox, "SFX", 0.0, 1.0, AudioManager.sfx_volume, "", null)
	_sfx_slider.step = 0.05
	_sfx_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_sfx_volume(v))

	_add_spacer(vbox, 8.0)

	# ── Tombol
	var btn_back := Button.new()
	btn_back.text = "◀   SIMPAN & KEMBALI"
	btn_back.custom_minimum_size = Vector2(320.0, 54.0)
	btn_back.add_theme_font_size_override("font_size", 20)
	btn_back.add_theme_color_override("font_color", C_CYAN)
	btn_back.pressed.connect(_on_back_pressed)
	vbox.add_child(btn_back)


## ── HELPERS ──────────────────────────────────────────────────────────────────

func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", C_CYAN)
	parent.add_child(lbl)


func _add_slider_row(parent: VBoxContainer, label_text: String,
		min_v: float, max_v: float, init_v: float,
		unit: String, _val_ref: Label) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120.0, 0.0)
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.value = init_v
	slider.step = 1.0 if unit == "menit" else 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(64.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.text = _format_val(init_v, unit)
	hbox.add_child(val_lbl)

	# Update label saat slider bergerak
	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = _format_val(v, unit))

	return slider


func _format_val(v: float, unit: String) -> String:
	if unit == "menit":
		return "%d mnt" % int(v)
	return "%.0f%%" % (v * 100.0)


func _get_last_val_label(parent: VBoxContainer) -> Label:
	var hbox := parent.get_child(parent.get_child_count() - 1) as HBoxContainer
	if hbox:
		return hbox.get_child(hbox.get_child_count() - 1) as Label
	return null


func _add_spacer(parent: VBoxContainer, height: float) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0.0, height)
	parent.add_child(sp)


## ── HANDLERS ─────────────────────────────────────────────────────────────────

func _on_focus_changed(v: float) -> void:
	GameManager.focus_duration = v * 60.0


func _on_action_changed(v: float) -> void:
	GameManager.action_duration = v * 60.0


func _load_values() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var fd: float = cfg.get_value(SECTION_GAME, "focus_minutes",  20.0)
		var ad: float = cfg.get_value(SECTION_GAME, "action_minutes",  5.0)
		if _focus_slider:
			_focus_slider.value = fd
		if _action_slider:
			_action_slider.value = ad
		GameManager.focus_duration  = fd * 60.0
		GameManager.action_duration = ad * 60.0


func _on_back_pressed() -> void:
	var cfg := ConfigFile.new()
	# Muat dulu agar bagian lain (audio) tidak tertimpa
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION_GAME, "focus_minutes",  _focus_slider.value  if _focus_slider  else 20.0)
	cfg.set_value(SECTION_GAME, "action_minutes", _action_slider.value if _action_slider else 5.0)
	cfg.set_value("audio", "master", _master_slider.value if _master_slider else 1.0)
	cfg.set_value("audio", "bgm",    _bgm_slider.value    if _bgm_slider    else 0.8)
	cfg.set_value("audio", "sfx",    _sfx_slider.value    if _sfx_slider    else 1.0)
	cfg.save(SETTINGS_PATH)
	SceneTransition.go_to("res://Scenes/MainMenu.tscn")
