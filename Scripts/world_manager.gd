extends Node3D

## World/Combat scene manager.
## Handles: HUD, pause menu, game over, wave spawning.

@onready var timer_text: RichTextLabel = $TimerText

const ENEMY_SCENE        := "res://Scenes/enemy.tscn"
const RANGED_ENEMY_SCENE := "res://Scenes/ranged_enemy.tscn"
const FAST_ENEMY_SCENE   := "res://Scenes/fast_enemy.tscn"
const SPAWN_RANGE        : float = 9.0

var _enemy_scene: PackedScene
var _ranged_enemy_scene: PackedScene
var _fast_enemy_scene: PackedScene
var _enemies_alive: int = 0
var _wave_number: int = 0
var _total_kills: int = 0
var _total_score: int = 0
var _wave_clearing: bool = false  # Mencegah double-spawn saat banyak enemy mati sekaligus

## HUD
var _health_bar: ProgressBar = null
var _hp_label: Label = null
var _wave_label: Label = null
var _kill_label: Label = null
var _combo_label: Label = null
var _score_label: Label = null

## Pause
var _pause_ui: Control = null
var _is_paused: bool = false

## Game Over
var _game_over_ui: Control = null

## Post-combat summary
var _summary_ui: Control = null

## Colors
const C_CYAN  := Color(0.42, 0.82, 1.0,  1.0)
const C_RED   := Color(1.0,  0.25, 0.25, 1.0)
const C_DARK  := Color(0.04, 0.04, 0.07, 1.0)


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	_enemy_scene = load(ENEMY_SCENE)
	_ranged_enemy_scene = load(RANGED_ENEMY_SCENE)
	_fast_enemy_scene   = load(FAST_ENEMY_SCENE)
	_setup_hud()
	_setup_pause_menu()
	_setup_game_over()
	_setup_summary()
	_spawn_wave()
	# Wait 1 frame so player node is fully initialized
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
			_on_player_health_changed(player.health, player.max_health)
		if player.has_signal("player_died"):
			player.player_died.connect(_show_game_over)
		if player.has_signal("combo_changed"):
			player.combo_changed.connect(_on_combo_changed)


func _process(_delta: float) -> void:
	if not _is_paused:
		timer_text.text = GameManager.format_time(GameManager.get_time_left())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if _game_over_ui and not _game_over_ui.visible:
			_toggle_pause()


func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.FOCUS:
		get_tree().paused = false
		_show_post_combat_summary()


## ── WAVE SPAWNING ────────────────────────────────────────────────────────────

func _spawn_wave() -> void:
	_wave_number += 1
	var melee_count  : int = mini(1 + _wave_number, 5)
	var ranged_count : int = _wave_number / 2
	var fast_count   : int = maxi(_wave_number - 2, 0)  # Muncul mulai wave 3
	_enemies_alive = melee_count + ranged_count + fast_count

	if _wave_label:
		_wave_label.text = "WAVE  %d" % _wave_number

	var positions := _make_positions(melee_count + ranged_count + fast_count)
	for i in melee_count:
		_instantiate_enemy(_enemy_scene, positions[i])
	for i in ranged_count:
		_instantiate_enemy(_ranged_enemy_scene, positions[melee_count + i])
	for i in fast_count:
		_instantiate_enemy(_fast_enemy_scene, positions[melee_count + ranged_count + i])


func _instantiate_enemy(scene: PackedScene, pos: Vector3) -> void:
	if scene == null:
		return
	var e: Node3D = scene.instantiate()
	# Scale HP per wave
	if "max_health" in e:
		e.max_health = int(e.max_health * (1.0 + (_wave_number - 1) * 0.3))
	add_child(e)
	e.global_position = pos
	if e.has_signal("enemy_died"):
		e.enemy_died.connect(_on_enemy_died)


func _make_positions(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in count:
		var side := 1 if i % 2 == 0 else -1
		out.append(Vector3(randf_range(4.0, SPAWN_RANGE) * side, 2.0, 0.0))
	return out


func _on_enemy_died(e: Node) -> void:
	# Clamp agar tidak negatif (kasus banyak enemy mati bersamaan)
	_enemies_alive = maxi(_enemies_alive - 1, 0)
	_total_kills += 1
	# Score per tipe enemy
	var sv: int = 10
	if is_instance_valid(e):
		var raw = e.get("score_value")
		if raw != null:
			sv = raw as int
	_total_score += sv
	if _kill_label:
		_kill_label.text = "Kills: %d" % _total_kills
	if _score_label:
		_score_label.text = "Score: %d" % _total_score
	# Hanya trigger spawn baru SATU KALI per wave
	if _enemies_alive == 0 and not _wave_clearing:
		_wave_clearing = true
		_show_wave_cleared_banner()
		await get_tree().create_timer(2.0).timeout
		_wave_clearing = false
		if GameManager.current_state == GameManager.GameState.ACTION:
			_spawn_wave()


## ── HUD ──────────────────────────────────────────────────────────────────────

func _setup_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.85)
	bar_bg.size = Vector2(212.0, 28.0)
	bar_bg.position = Vector2(14.0, 14.0)
	canvas.add_child(bar_bg)

	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_bar.size = Vector2(200.0, 20.0)
	_health_bar.position = Vector2(20.0, 18.0)
	_health_bar.show_percentage = false
	canvas.add_child(_health_bar)

	_hp_label = Label.new()
	_hp_label.text = "HP  100 / 100"
	_hp_label.position = Vector2(20.0, 46.0)
	canvas.add_child(_hp_label)

	_kill_label = Label.new()
	_kill_label.text = "Kills: 0"
	_kill_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	_kill_label.position = Vector2(20.0, 68.0)
	canvas.add_child(_kill_label)

	# Combo label — tersembunyi saat tidak aktif
	_combo_label = Label.new()
	_combo_label.text = ""
	_combo_label.add_theme_font_size_override("font_size", 32)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	_combo_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_combo_label.offset_left = -180.0
	_combo_label.offset_top = -20.0
	canvas.add_child(_combo_label)

	_score_label = Label.new()
	_score_label.text = "Score: 0"
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	_score_label.position = Vector2(20.0, 90.0)
	canvas.add_child(_score_label)

	# Badge background untuk wave label
	var wave_bg := ColorRect.new()
	wave_bg.color = Color(0.04, 0.04, 0.10, 0.80)
	wave_bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wave_bg.offset_left   = -170.0
	wave_bg.offset_right  =  -10.0
	wave_bg.offset_top    =   10.0
	wave_bg.offset_bottom =   46.0
	canvas.add_child(wave_bg)

	_wave_label = Label.new()
	_wave_label.text = "WAVE  1"
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.add_theme_font_size_override("font_size", 22)
	_wave_label.add_theme_color_override("font_color", C_CYAN)
	_wave_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave_label.offset_left   = -170.0
	_wave_label.offset_right  =  -10.0
	_wave_label.offset_top    =   14.0
	_wave_label.offset_bottom =   42.0
	canvas.add_child(_wave_label)


func _on_player_health_changed(current: int, maximum: int) -> void:
	if _health_bar:
		_health_bar.max_value = maximum
		_health_bar.value = current
	if _hp_label:
		_hp_label.text = "HP  %d / %d" % [current, maximum]


## ── PAUSE ────────────────────────────────────────────────────────────────────

func _setup_pause_menu() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	_pause_ui = Control.new()
	_pause_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_ui.visible = false
	canvas.add_child(_pause_ui)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_ui.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_ui.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "JEDA"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", C_CYAN)
	vbox.add_child(lbl)

	var sub := Label.new()
	sub.text = "Timer tetap berjalan..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1.0))
	vbox.add_child(sub)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(sp)

	var btn_r := _make_btn("▶   LANJUT  [Esc]", C_CYAN)
	btn_r.pressed.connect(_toggle_pause)
	vbox.add_child(btn_r)

	var btn_m := _make_btn("MAIN MENU", Color(0.65, 0.65, 0.65, 1.0))
	btn_m.pressed.connect(_go_to_main_menu)
	vbox.add_child(btn_m)


func _toggle_pause() -> void:
	_is_paused = !_is_paused
	get_tree().paused = _is_paused
	_pause_ui.visible = _is_paused


func _go_to_main_menu() -> void:
	get_tree().paused = false
	if GameManager.state_changed.is_connected(_on_state_changed):
		GameManager.state_changed.disconnect(_on_state_changed)
	SceneTransition.go_to("res://Scenes/MainMenu.tscn")


## ── GAME OVER ────────────────────────────────────────────────────────────────

func _setup_game_over() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)

	_game_over_ui = Control.new()
	_game_over_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_ui.visible = false
	canvas.add_child(_game_over_ui)

	var overlay := ColorRect.new()
	overlay.color = Color(0.06, 0.0, 0.0, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_ui.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_ui.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "GAME OVER"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", C_RED)
	vbox.add_child(lbl)

	var sub := Label.new()
	sub.text = "Kamu dikalahkan di fase combat!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	vbox.add_child(sub)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(sp)

	var btn_retry := _make_btn("COBA LAGI", C_CYAN)
	btn_retry.pressed.connect(_retry)
	vbox.add_child(btn_retry)

	var btn_menu := _make_btn("MAIN MENU", Color(0.65, 0.65, 0.65, 1.0))
	btn_menu.pressed.connect(_go_to_main_menu)
	vbox.add_child(btn_menu)


func _show_game_over() -> void:
	if _game_over_ui:
		_game_over_ui.visible = true


func _retry() -> void:
	SceneTransition.go_to("res://Scenes/Cafe.tscn")


## ── HELPER ───────────────────────────────────────────────────────────────────

func _make_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(300.0, 54.0)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", color)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	return btn


## ── COMBO DISPLAY ────────────────────────────────────────────────────────────

func _on_combo_changed(count: int) -> void:
	if not _combo_label:
		return
	if count <= 1:
		_combo_label.text = ""
		return
	var labels := ["", "", "2 HIT!", "COMBO!", "FINISHER!!"]
	var colors := [C_CYAN, C_CYAN, Color(1.0, 0.9, 0.3, 1.0),
		Color(1.0, 0.6, 0.1, 1.0), C_RED]
	var idx := mini(count, labels.size() - 1)
	_combo_label.text = labels[idx]
	_combo_label.add_theme_color_override("font_color", colors[idx])
	# Scale punch animation
	_combo_label.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.15)


## ── POST-COMBAT SUMMARY ──────────────────────────────────────────────────────

func _setup_summary() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 25
	add_child(canvas)

	_summary_ui = Control.new()
	_summary_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary_ui.visible = false
	canvas.add_child(_summary_ui)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary_ui.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary_ui.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "SESI SELESAI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", C_CYAN)
	vbox.add_child(title)

	var kills_lbl := Label.new()
	kills_lbl.name = "KillsLabel"
	kills_lbl.text = "Enemy dikalahkan: 0"
	kills_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kills_lbl.add_theme_font_size_override("font_size", 28)
	vbox.add_child(kills_lbl)

	var wave_lbl := Label.new()
	wave_lbl.name = "WaveLabel"
	wave_lbl.text = "Wave tertinggi: 1"
	wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_lbl.add_theme_font_size_override("font_size", 28)
	vbox.add_child(wave_lbl)

	var score_lbl := Label.new()
	score_lbl.name = "ScoreLabel"
	score_lbl.text = "Skor: 0"
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 32)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	vbox.add_child(score_lbl)

	var sub := Label.new()
	sub.text = "Kembali ke Cafe..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	vbox.add_child(sub)


func _show_post_combat_summary() -> void:
	# ── Bekukan semua activity ───────────────────────────────────────────────
	# Player tidak bisa bergerak/mati selama summary
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(false)
		player.set_process_input(false)
	# Semua enemy berhenti
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			enemy.set_physics_process(false)
	# Hapus semua proyektil yang masih melayang
	for node in get_tree().get_nodes_in_group("projectile"):
		node.queue_free()

	if not _summary_ui:
		SceneTransition.go_to("res://Scenes/Cafe.tscn")
		return

	var kills_lbl  := _summary_ui.find_child("KillsLabel",  true, false) as Label
	var wave_lbl   := _summary_ui.find_child("WaveLabel",   true, false) as Label
	var score_lbl2 := _summary_ui.find_child("ScoreLabel",  true, false) as Label
	if kills_lbl:  kills_lbl.text  = "Enemy dikalahkan: %d" % _total_kills
	if wave_lbl:   wave_lbl.text   = "Wave tertinggi: %d"   % _wave_number
	if score_lbl2: score_lbl2.text = "Skor: %d" % _total_score

	_summary_ui.visible = true

	await get_tree().create_timer(4.0).timeout
	if is_inside_tree():
		SceneTransition.go_to("res://Scenes/Cafe.tscn")


## Notifikasi singkat saat wave selesai
func _show_wave_cleared_banner() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 15
	add_child(canvas)

	var lbl := Label.new()
	lbl.text = "WAVE %d  CLEARED!" % _wave_number
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 44)
	lbl.add_theme_color_override("font_color", C_CYAN)
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.offset_top = 80.0
	lbl.offset_left = -300.0
	lbl.offset_right = 300.0
	canvas.add_child(lbl)

	# Animasi: slide down + fade
	lbl.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_property(lbl, "offset_top", 120.0, 0.4).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(1.0).timeout
	var tw2 := create_tween()
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.3)
	await tw2.finished
	canvas.queue_free()
