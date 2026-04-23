extends CharacterBody3D

## Player controller — movement, combat, health.
## State: WALK, DASH, RUN, ATTACK, PARRY

enum PlayerState { WALK, DASH, RUN, ATTACK, PARRY }

## Durasi window parry (waktu player bisa menahan serangan)
const PARRY_WINDOW: float  = 0.35
const PARRY_COUNTER_DMG: int = 3
const FLOATING_TEXT_SCENE := "res://Scenes/damage_number.tscn"

signal health_changed(current: int, maximum: int)
signal player_died
signal combo_changed(count: int)

@export var speed: float = 6.0
@export var jump_velocity: float = 10.0
@export var transition: float = 0.5
@export var att_duration: float = 0.2
@export var friction: float = 30.0
@export var max_health: int = 100

## Combo: 3 hit berturut-turut dalam waktu combo_window detik
@export var combo_window: float = 1.0
@export var combo_damage_multiplier: float = 2.0

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_state: PlayerState = PlayerState.WALK

## Lock-on target (enemy terdekat, diperbarui setiap frame)
var _locked_target: Node3D = null

## Splash radius saat menyerang locked target
const ATTACK_SPLASH_RADIUS: float = 1.8

## Parry & i-frame
var _is_parrying: bool = false
var _is_invincible: bool = false
var _ft_scene: PackedScene = null

## Combo tracking
var _combo_count: int = 0
var _combo_timer: float = 0.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var run_timer: Timer = $RunTimer
@onready var att_collision: CollisionShape3D = $AttackCollisionShape
@onready var att_sprite: Sprite3D = $AttackCollisionShape/Sprite3D
@onready var att_timer: Timer = $AttackCollisionShape/SprAttTimer


func _ready() -> void:
	health = max_health
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	_ft_scene = load(FLOATING_TEXT_SCENE)
	run_timer.timeout.connect(_on_run_timer_timeout)
	att_timer.timeout.connect(_on_spr_att_timer_timeout)
	att_collision.disabled = true
	change_state(PlayerState.WALK)


func change_state(new_state: PlayerState) -> void:
	current_state = new_state
	match current_state:
		PlayerState.WALK:
			sprite.modulate = Color.WHITE
			speed = 6.0
			_is_invincible = false
			_is_parrying = false
		PlayerState.DASH:
			sprite.modulate = Color(1, 1, 1, 0.4)
			speed = 20.0
			_is_invincible = true   # I-frames selama dash
		PlayerState.RUN:
			sprite.modulate = Color.WHITE
			speed = 10.0
			_is_invincible = false
		PlayerState.ATTACK:
			sprite.modulate = Color.WHITE
			velocity.x = 0
			att_sprite.visible = true
			att_collision.disabled = false
			# Dash singkat ke arah locked target saat attack dimulai
			if _locked_target and is_instance_valid(_locked_target):
				var dir: float = sign(_locked_target.global_position.x - global_position.x)
				var dist: float = abs(_locked_target.global_position.x - global_position.x)
				var dash: float = clampf(dist - 0.7, 0.0, 0.9)
				global_position.x += dir * dash
			att_timer.start(att_duration)
		PlayerState.PARRY:
			_is_parrying = true
			_is_invincible = true
			# Flash cyan saat parry aktif
			sprite.modulate = Color(0.4, 1.8, 2.0, 1.0)
			# Kembali ke WALK setelah PARRY_WINDOW
			get_tree().create_timer(PARRY_WINDOW).timeout.connect(
				func() -> void:
					if current_state == PlayerState.PARRY:
						change_state(PlayerState.WALK), CONNECT_ONE_SHOT)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta * 2

	# Combo window countdown
	if _combo_count > 0:
		_combo_timer -= delta
		if _combo_timer <= 0:
			_combo_count = 0
			combo_changed.emit(0)

	# Update lock-on setiap frame
	_update_lock_on()

	# Auto-face locked target (kecuali saat sedang attacking/dashing)
	if _locked_target and is_instance_valid(_locked_target) \
			and current_state not in [PlayerState.ATTACK, PlayerState.DASH]:
		var ldir: float = sign(_locked_target.global_position.x - global_position.x)
		if ldir != 0.0:
			_flip_player(ldir)

	if current_state != PlayerState.ATTACK:
		_handle_movement(delta)

		# Jump
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity

		# Dash & Run (dengan i-frames)
		if Input.is_action_just_pressed("sprint") and current_state != PlayerState.DASH:
			change_state(PlayerState.DASH)
			await get_tree().create_timer(transition / 1.5).timeout
			if current_state == PlayerState.DASH:
				change_state(PlayerState.RUN)

		# Attack — hadap enemy terdekat, lalu counter dash / normal attack
		if Input.is_action_just_pressed("attack"):
			_face_nearest_enemy()
			if _get_nearest_charging_enemy() != null:
				_do_counter_dash()
			else:
				change_state(PlayerState.ATTACK)

	# Lock Z axis (2.5D)
	velocity.z = 0
	transform.origin.z = 0
	move_and_slide()


func _handle_movement(delta: float) -> void:
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * speed
		_flip_player(direction)
		if not run_timer.is_stopped():
			run_timer.stop()
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		if current_state in [PlayerState.RUN, PlayerState.DASH] and run_timer.is_stopped():
			run_timer.start(transition)


func _flip_player(direction: float) -> void:
	if direction > 0:
		rotation.y = 0
	elif direction < 0:
		rotation.y = PI


## Dipanggil oleh enemy saat menyerang player
## source: node enemy yang menyerang (untuk parry counter)
func take_damage(amount: int, source: Node = null) -> void:
	# PARRY: tidak kena damage, balik damage ke enemy
	if _is_parrying:
		_on_parry_success(source)
		return
	# DODGE (i-frames aktif): tidak kena damage
	if _is_invincible:
		_on_dodge_success()
		return

	health -= amount
	health = max(health, 0)
	health_changed.emit(health, max_health)
	GameManager.request_screen_shake(0.15, 0.2)
	# Visual feedback: kilat merah singkat
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 0.2, 0.2, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	print("Player HP: %d / %d" % [health, max_health])
	if health <= 0:
		_on_player_died()


## PARRY berhasil — tidak kena damage, stun enemy, counter
func _on_parry_success(source: Node) -> void:
	GameManager.request_screen_shake(0.08, 0.15)
	GameManager.do_hitstop(0.1)
	# Floating text PERFECT PARRY!
	if _ft_scene:
		var ft: Node3D = _ft_scene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.show_text_at("PERFECT PARRY!", global_position, Color(0.3, 1.6, 2.0, 1.0), 52)
	# Flash putih cerah
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color(0.4, 1.8, 2.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	if source and source.has_method("take_damage"):
		source.take_damage(PARRY_COUNTER_DMG)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get("is_charging") == true:
			enemy.set("_is_staggered", true)
			enemy.set("is_charging", false)
			get_tree().create_timer(0.8).timeout.connect(
				func() -> void:
					if is_instance_valid(enemy):
						enemy.set("_is_staggered", false), CONNECT_ONE_SHOT)




## Cek apakah ada enemy charging dalam radius tertentu (untuk dodge text)
func _has_nearby_charging_enemy() -> bool:
	return _get_nearest_charging_enemy() != null


## Counter Dash — dash cepat ke samping enemy charging lalu AoE
func _do_counter_dash() -> void:
	var target := _get_nearest_charging_enemy()
	if target == null:
		change_state(PlayerState.ATTACK)
		return

	_is_invincible = true
	_is_parrying = false

	# Posisi tujuan: samping enemy (sisi yang dekat player)
	var side: float = sign(global_position.x - target.global_position.x)
	if side == 0.0:
		side = 1.0
	var dest := Vector3(target.global_position.x + side * 0.8,
						global_position.y, 0.0)

	sprite.modulate = Color(1.8, 1.4, 0.3, 0.75)  # Trail kuning

	var tw := create_tween()
	tw.tween_property(self, "global_position", dest, 0.14)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	await tw.finished

	# Cek target masih valid setelah dash (bisa saja sudah mati)
	if is_instance_valid(target):
		_counter_dash_impact(target)
	else:
		GameManager.request_screen_shake(0.08, 0.15)
	_is_invincible = false
	change_state(PlayerState.WALK)


## AoE impact saat counter dash tiba
func _counter_dash_impact(main_target: Node) -> void:
	GameManager.request_screen_shake(0.12, 0.2)
	GameManager.do_hitstop(0.12)

	if _ft_scene:
		var ft: Node3D = _ft_scene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.show_text_at("COUNTER!", global_position, Color(1.0, 0.5, 0.0, 1.0), 56)

	# ── Knockback dulu ke main target (sebelum AoE mungkin membunuhnya) ────
	if is_instance_valid(main_target):
		var kb_dir: float = sign(main_target.global_position.x - global_position.x)
		if kb_dir == 0.0:
			kb_dir = 1.0
		main_target.set("velocity",    Vector3(kb_dir * 10.0, 2.5, 0.0))
		main_target.set("is_charging", false)
		main_target.set("_is_staggered", true)
		# Gunakan instance_id agar lambda tidak capture Node yang sudah freed
		var tid: int = main_target.get_instance_id()
		get_tree().create_timer(0.7).timeout.connect(
			func() -> void:
				var t := instance_from_id(tid)
				if is_instance_valid(t):
					t.set("_is_staggered", false), CONNECT_ONE_SHOT)

	# ── AoE damage semua enemy dalam radius (boleh membunuh main target) ────
	var aoe_radius: float = 2.2
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var en := e as Node3D
		if en == null:
			continue
		var d: float = abs(global_position.x - en.global_position.x)
		if d <= aoe_radius and e.has_method("take_damage"):
			e.call("take_damage", PARRY_COUNTER_DMG)

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(3.0, 2.0, 0.4, 1.0), 0.04)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)


## DODGE berhasil (i-frames saat dash)
func _on_dodge_success() -> void:
	if _ft_scene:
		var ft: Node3D = _ft_scene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.show_text_at("DODGE!", global_position, Color(0.7, 0.9, 1.0, 1.0), 44)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.6, 0.9, 2.0, 0.7), 0.05)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0.4), 0.1)


## Cari enemy charging terdekat dalam radius
func _get_nearest_charging_enemy() -> Node3D:
	var detect_range: float = 4.0
	var nearest: Node3D = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var en := e as Node3D
		if en == null:
			continue
		if e.get("is_charging") != true:
			continue
		var d: float = abs(global_position.x - en.global_position.x)
		if d <= detect_range and d < nearest_dist:
			nearest_dist = d
			nearest = en
	return nearest


## Hadap ke enemy terdekat (X-axis saja, sesuai 2.5D)
func _face_nearest_enemy() -> void:
	var nearest: Node3D = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var en := e as Node3D
		if en == null:
			continue
		var d: float = abs(global_position.x - en.global_position.x)
		if d < nearest_dist:
			nearest_dist = d
			nearest = en
	if nearest:
		var dir_x: float = sign(nearest.global_position.x - global_position.x)
		if dir_x != 0.0:
			_flip_player(dir_x)



## Hitung damage serangan — combo hit ke-3 mendapat bonus
func _calculate_attack_damage() -> int:
	_combo_count += 1
	_combo_timer = combo_window
	combo_changed.emit(_combo_count)
	var base_damage := 1
	if _combo_count >= 3:
		_combo_count = 0
		combo_changed.emit(0)
		print("COMBO FINISHER!")
		return int(base_damage * combo_damage_multiplier)
	return base_damage


func _on_player_died() -> void:
	print("Player mati!")
	set_physics_process(false)
	set_process_input(false)
	player_died.emit()


func _on_run_timer_timeout() -> void:
	if current_state != PlayerState.ATTACK:
		change_state(PlayerState.WALK)


func _on_spr_att_timer_timeout() -> void:
	_check_attack_hits()
	att_sprite.visible = false
	att_collision.disabled = true
	change_state(PlayerState.WALK)


## Cek enemy yang masuk area hitbox saat serangan aktif (physics query)
func _check_attack_hits() -> void:
	var space := get_world_3d().direct_space_state
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = att_collision.shape
	shape_query.transform = att_collision.global_transform
	shape_query.collision_mask = 2  # Layer 2 = enemy
	shape_query.exclude = [self]
	var results := space.intersect_shape(shape_query)
	var hit_something := false
	for result in results:
		var body: Node = result["collider"]
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			var dmg := _calculate_attack_damage()
			body.take_damage(dmg)
			hit_something = true
	if hit_something:
		GameManager.do_hitstop(0.07)
		GameManager.request_screen_shake(0.04, 0.08)


## Perbarui locked target ke enemy terdekat setiap frame
func _update_lock_on() -> void:
	var nearest: Node3D = null
	var nearest_dist: float = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var en := e as Node3D
		if en == null:
			continue
		var d: float = abs(global_position.x - en.global_position.x)
		if d < nearest_dist:
			nearest_dist = d
			nearest = en
	_locked_target = nearest
