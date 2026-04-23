extends Node3D

## Mengelola fase Cafe (FOCUS & READY).
## Subscribe ke GameManager.state_changed — tidak punya timer sendiri.

@onready var player_sprite: Sprite3D = $Player
@onready var timer_text: RichTextLabel = $TimerText

## Threshold (detik) untuk mulai animasi warning
const WARNING_TIME: float = 60.0

## Tween aktif untuk animasi warning
var _warning_tween: Tween = null
var _is_warning_active: bool = false

## Vignette overlay
var _vignette: ColorRect = null

## Status label (bawah tengah)
var _status_label: Label = null

## Pause UI
var _pause_ui: Control = null
var _is_paused: bool = false


func _ready() -> void:
	# Proses tetap berjalan saat game di-pause (diperlukan untuk pause menu & input)
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.change_state(GameManager.GameState.FOCUS)
	_setup_vignette()
	_setup_status_label()
	_setup_pause_menu()
	_apply_state(GameManager.current_state)


func _process(_delta: float) -> void:
	# Jangan update timer saat game di-pause
	if _is_paused:
		return
	var time_left := GameManager.get_time_left()
	timer_text.text = GameManager.format_time(time_left)

	if _status_label:
		if GameManager.current_state == GameManager.GameState.FOCUS:
			_status_label.text = "⏱ Kerjakan tugasmu!"
			_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
		elif GameManager.current_state == GameManager.GameState.READY:
			_status_label.text = "⚔  Tekan Enter untuk Combat Mode"
			_status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7, 1.0))

	if GameManager.current_state == GameManager.GameState.FOCUS:
		if time_left < WARNING_TIME and not _is_warning_active:
			_start_warning_animation()
	else:
		_stop_warning_animation()


func _input(event: InputEvent) -> void:
	# Escape: pause/unpause
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	# Enter: READY → ACTION
	if not _is_paused and GameManager.current_state == GameManager.GameState.READY:
		if event.is_action_pressed("ui_accept"):
			GameManager.change_state(GameManager.GameState.ACTION)


func _on_state_changed(new_state: GameManager.GameState) -> void:
	_apply_state(new_state)


func _apply_state(state: GameManager.GameState) -> void:
	_stop_warning_animation()
	match state:
		GameManager.GameState.FOCUS:
			player_sprite.modulate = Color.WHITE
		GameManager.GameState.READY:
			_pulse_ready()
		GameManager.GameState.ACTION:
			SceneTransition.go_to("res://Scenes/World.tscn")


## ── STATUS LABEL ─────────────────────────────────────────────────────────────

func _setup_status_label() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	_status_label = Label.new()
	_status_label.text = "⏱ Kerjakan tugasmu!"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	# Anchor manual: full-width, 40px dari bawah layar
	_status_label.anchor_left   = 0.0
	_status_label.anchor_right  = 1.0
	_status_label.anchor_top    = 1.0
	_status_label.anchor_bottom = 1.0
	_status_label.offset_left   = 0.0
	_status_label.offset_right  = 0.0
	_status_label.offset_top    = -60.0
	_status_label.offset_bottom = -20.0
	canvas.add_child(_status_label)


## ── PAUSE MENU ───────────────────────────────────────────────────────────────

func _setup_pause_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	# Canvas layer harus selalu aktif agar bisa diklik saat pause
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	_pause_ui = Control.new()
	_pause_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_ui.visible = false
	canvas.add_child(_pause_ui)

	# Overlay gelap
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_ui.add_child(overlay)

	# Panel tengah
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left  = -140.0
	panel.offset_right =  140.0
	panel.offset_top   = -100.0
	panel.offset_bottom = 100.0
	_pause_ui.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "JEDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var btn_resume := Button.new()
	btn_resume.text = "Lanjutkan"
	btn_resume.custom_minimum_size = Vector2(220.0, 44.0)
	btn_resume.pressed.connect(_toggle_pause)
	vbox.add_child(btn_resume)

	var btn_menu := Button.new()
	btn_menu.text = "Main Menu"
	btn_menu.custom_minimum_size = Vector2(220.0, 44.0)
	btn_menu.pressed.connect(_go_to_main_menu)
	vbox.add_child(btn_menu)


func _toggle_pause() -> void:
	_is_paused = !_is_paused
	get_tree().paused = _is_paused
	if _pause_ui:
		_pause_ui.visible = _is_paused


func _go_to_main_menu() -> void:
	get_tree().paused = false
	if GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.disconnect(_on_state_changed)
	SceneTransition.go_to("res://Scenes/MainMenu.tscn")


## ── VISUAL EFFECTS ───────────────────────────────────────────────────────────

func _pulse_ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(player_sprite, "modulate", Color(1.5, 1.5, 0.2, 1.0), 0.5)
	tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.5)


func _start_warning_animation() -> void:
	_is_warning_active = true
	_warning_tween = create_tween().set_loops()
	_warning_tween.tween_property(player_sprite, "modulate", Color(1.5, 0.3, 0.3, 1.0), 1.0)
	_warning_tween.tween_property(player_sprite, "modulate", Color.WHITE, 1.0)
	if _vignette:
		_warning_tween.parallel().tween_property(_vignette, "modulate:a", 0.35, 1.0)
		_warning_tween.parallel().tween_property(_vignette, "modulate:a", 0.05, 1.0)


func _stop_warning_animation() -> void:
	if _warning_tween:
		_warning_tween.kill()
		_warning_tween = null
	_is_warning_active = false
	if _vignette:
		_vignette.modulate.a = 0.0


func _setup_vignette() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_vignette = ColorRect.new()
	_vignette.color = Color(0.8, 0.05, 0.05, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_vignette)
