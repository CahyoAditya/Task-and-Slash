extends Node3D

## Mengelola fase Cafe (FOCUS & READY).
## Subscribe ke GameManager.state_changed — tidak punya timer sendiri.

@onready var player_sprite: Sprite3D = $Player
@onready var timer_text: RichTextLabel = $TimerText

## Threshold (detik) untuk mulai animasi warning
const WARNING_TIME: float = 60.0

## Path penyimpanan tasks
const TASKS_PATH := "user://tasks.json"

## Tween aktif untuk animasi warning
var _warning_tween: Tween = null
var _vignette_tween: Tween = null
var _pulse_tween: Tween = null
var _is_warning_active: bool = false

## Vignette overlay
var _vignette: ColorRect = null

## Status label (bawah tengah)
var _status_label: Label = null

## Pause UI
var _pause_ui: Control = null
var _is_paused: bool = false

## Task list
var _tasks: Array = []   # Array of { "text": String, "done": bool }
var _task_list_container: VBoxContainer = null
var _task_input: LineEdit = null


func _ready() -> void:
	# Proses tetap berjalan saat game di-pause (diperlukan untuk pause menu & input)
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.change_state(GameManager.GameState.FOCUS)
	_setup_vignette()
	_setup_status_label()
	_setup_pause_menu()
	_setup_task_list()
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
			if _pulse_tween:
				_pulse_tween.kill()
				_pulse_tween = null
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
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(player_sprite, "modulate", Color(1.5, 1.5, 0.2, 1.0), 0.5)
	_pulse_tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.5)


func _start_warning_animation() -> void:
	_is_warning_active = true
	_warning_tween = create_tween().set_loops()
	_warning_tween.tween_property(player_sprite, "modulate", Color(1.5, 0.3, 0.3, 1.0), 1.0)
	_warning_tween.tween_property(player_sprite, "modulate", Color.WHITE, 1.0)
	if _vignette:
		_vignette_tween = create_tween().set_loops()
		_vignette_tween.tween_property(_vignette, "modulate:a", 0.35, 1.0)
		_vignette_tween.tween_property(_vignette, "modulate:a", 0.05, 1.0)


func _stop_warning_animation() -> void:
	if _warning_tween:
		_warning_tween.kill()
		_warning_tween = null
	if _vignette_tween:
		_vignette_tween.kill()
		_vignette_tween = null
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
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


## ── TASK LIST ────────────────────────────────────────────────────────────────

func _setup_task_list() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	# Panel kanan layar
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -280.0
	panel.offset_right  = -10.0
	panel.offset_top    = 10.0
	panel.offset_bottom = -10.0
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Judul
	var title := Label.new()
	title.text = "📋 TASK LIST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.42, 0.82, 1.0, 1.0))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Input area
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	vbox.add_child(input_row)

	_task_input = LineEdit.new()
	_task_input.placeholder_text = "Tulis tugas..."
	_task_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_input.max_length = 60
	input_row.add_child(_task_input)

	var btn_add := Button.new()
	btn_add.text = "+"
	btn_add.custom_minimum_size = Vector2(36.0, 0.0)
	btn_add.pressed.connect(_on_add_task_pressed)
	input_row.add_child(btn_add)

	# Enter di LineEdit juga trigger add
	_task_input.text_submitted.connect(func(_t: String) -> void: _on_add_task_pressed())

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Scroll container untuk daftar task
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_task_list_container = VBoxContainer.new()
	_task_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_task_list_container)

	_load_tasks()
	_rebuild_task_ui()


func _on_add_task_pressed() -> void:
	if not _task_input:
		return
	var text := _task_input.text.strip_edges()
	if text.is_empty():
		return
	_tasks.append({"text": text, "done": false})
	_task_input.text = ""
	_save_tasks()
	_rebuild_task_ui()


func _rebuild_task_ui() -> void:
	if not _task_list_container:
		return
	# Hapus semua child lama
	for child in _task_list_container.get_children():
		child.queue_free()
	# Rebuild dari _tasks array
	for i in _tasks.size():
		var task: Dictionary = _tasks[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_task_list_container.add_child(row)

		var chk := CheckBox.new()
		chk.button_pressed = task.get("done", false)
		var idx := i  # capture untuk lambda
		chk.toggled.connect(func(pressed: bool) -> void:
			_tasks[idx]["done"] = pressed
			_save_tasks()
			_rebuild_task_ui())
		row.add_child(chk)

		var lbl := Label.new()
		lbl.text = task.get("text", "")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 14)
		if task.get("done", false):
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		else:
			lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
		row.add_child(lbl)

		var btn_del := Button.new()
		btn_del.text = "✕"
		btn_del.custom_minimum_size = Vector2(30.0, 0.0)
		btn_del.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		var del_idx := i
		btn_del.pressed.connect(func() -> void:
			_tasks.remove_at(del_idx)
			_save_tasks()
			_rebuild_task_ui())
		row.add_child(btn_del)


func _save_tasks() -> void:
	var file := FileAccess.open(TASKS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_tasks))
		file.close()


func _load_tasks() -> void:
	if not FileAccess.file_exists(TASKS_PATH):
		return
	var file := FileAccess.open(TASKS_PATH, FileAccess.READ)
	if file:
		var text := file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(text)
		if parsed is Array:
			_tasks = parsed
