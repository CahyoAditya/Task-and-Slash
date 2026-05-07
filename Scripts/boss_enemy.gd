extends CharacterBody3D

## Boss Enemy — muncul setiap kelipatan wave 5.
## Gabungan melee dan ranged. HP 5x melee biasa.

signal enemy_died(enemy: Node)

const DAMAGE_NUMBER_SCENE := "res://Scenes/damage_number.tscn"
const ATTACK_FLASH_SCENE  := "res://Scenes/attack_flash.tscn"
const DEATH_BURST_SCENE   := "res://Scenes/death_burst.tscn"
const PROJECTILE_SCENE    := "res://Scenes/projectile.tscn"

const BURST_COLOR := Color(0.6, 0.1, 0.9, 1.0)

## ── Shockwave Attack ─────────────────────────────────────────────────────────
## Serangan khusus yang bypass parry dan i-frame. Player harus menjauh.
const SHOCKWAVE_CHANCE : float = 0.20  ## 20% per serangan
const RANGED_CHANCE    : float = 0.35  ## 35% dari sisanya
const SHOCKWAVE_MIN_GAP: int   = 2     ## Min. serangan biasa sebelum shockwave bisa terpicu lagi
const SHOCKWAVE_RADIUS    : float = 3.5  ## Jangkauan AoE
const SHOCKWAVE_DAMAGE    : int   = 15   ## Damage (tidak bisa di-blok)
const SHOCKWAVE_CHARGE_TIME: float = 1.6 ## Lebih lama agar player punya waktu lari

@export var max_health: int = 20
@export var speed: float = 3.5
@export var damage: int = 20
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.8
@export var charge_time: float = 1.0
@export var score_value: int = 100

## Fase boss: MELEE atau RANGED (bergantian setiap 2 serangan)
var _attack_count: int = 0
var health: int
var is_charging: bool = false
var _target: Node3D = null
var _attack_timer: float = 1.0
var _charge_countdown: float = 0.0
var _is_staggered: bool = false
var _preferred_distance: float = 5.0
var _using_ranged: bool = false
var _attacks_since_shockwave: int = 10  ## Mulai tinggi agar shockwave bisa muncul lebih awal
var _pending_shockwave: bool = false  ## True saat serangan ini akan jadi shockwave
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

var _damage_number_scene: PackedScene
var _attack_flash_scene: PackedScene
var _burst_scene: PackedScene
var _projectile_scene: PackedScene
var _hit_mat: StandardMaterial3D = null
var _shockwave_mat: StandardMaterial3D = null  ## Material glow oranye saat charge shockwave
var _active_flash: Node3D = null  ## Referensi ke flash node yang sedang aktif

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	add_to_group("boss")  ## Dipakai player untuk skip knockback parry pada boss
	collision_layer = 2
	collision_mask = 1
	_damage_number_scene = load(DAMAGE_NUMBER_SCENE)
	_attack_flash_scene  = load(ATTACK_FLASH_SCENE)
	_burst_scene         = load(DEATH_BURST_SCENE)
	_projectile_scene    = load(PROJECTILE_SCENE)
	_hit_mat = StandardMaterial3D.new()
	_hit_mat.albedo_color = Color(3.0, 2.5, 0.5, 1.0)  # Gold flash
	_hit_mat.emission_enabled = true
	_hit_mat.emission = Color(1.0, 0.8, 0.0)
	# Material glow oranye terang — sinyal visual bahwa shockwave akan terpicu
	_shockwave_mat = StandardMaterial3D.new()
	_shockwave_mat.albedo_color = Color(1.0, 0.35, 0.0, 1.0)
	_shockwave_mat.emission_enabled = true
	_shockwave_mat.emission = Color(1.0, 0.2, 0.0)
	_shockwave_mat.emission_energy_multiplier = 2.5
	_target = get_tree().get_first_node_in_group("player")
	# Boss lebih besar
	scale = Vector3(1.5, 1.5, 1.5)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta * 2
	velocity.z = 0.0
	transform.origin.z = 0.0

	if _target == null:
		_target = get_tree().get_first_node_in_group("player")
		move_and_slide()
		return

	if _is_staggered:
		velocity.x = move_toward(velocity.x, 0.0, speed * 20.0 * delta)
		move_and_slide()
		return

	var dist: float = abs(global_position.x - _target.global_position.x)
	var dir_x: float = sign(_target.global_position.x - global_position.x)
	if dir_x == 0.0:
		dir_x = 1.0

	if is_charging:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		_charge_countdown -= delta
		if _charge_countdown <= 0.0:
			is_charging = false
			_attack_timer = attack_cooldown
			if mesh_instance:
				mesh_instance.material_override = null
			if _pending_shockwave:
				_pending_shockwave = false
				_do_shockwave()
			elif _using_ranged:
				_using_ranged = false
				_fire(dir_x)
			else:
				_do_melee_attack()
		move_and_slide()
		return

	# Gerakan: ke arah player untuk melee, jaga jarak untuk ranged
	if _using_ranged:  # Serangan berikutnya adalah ranged — jaga jarak
		if dist < _preferred_distance - 1.0:
			velocity.x = -dir_x * speed
		elif dist > _preferred_distance + 1.5:
			velocity.x = dir_x * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
	else:
		if dist > attack_range:
			velocity.x = dir_x * speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)

	rotation.y = 0.0 if dir_x > 0 else PI

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_start_charge()

	move_and_slide()


## Tentukan tipe serangan berikutnya secara acak berbobot.
## Shockwave punya minimum gap agar tidak terlalu sering.
func _determine_next_attack() -> void:
	_attacks_since_shockwave += 1

	# Shockwave: 20% chance, tapi hanya jika sudah melewati minimum gap
	if _attacks_since_shockwave >= SHOCKWAVE_MIN_GAP and randf() < SHOCKWAVE_CHANCE:
		_pending_shockwave = true
		_using_ranged = false
		_attacks_since_shockwave = 0
		return

	_pending_shockwave = false
	# Ranged: 35% dari serangan non-shockwave
	_using_ranged = randf() < RANGED_CHANCE


func _start_charge() -> void:
	_determine_next_attack()

	var duration: float = SHOCKWAVE_CHARGE_TIME if _pending_shockwave else charge_time
	is_charging = true
	_charge_countdown = duration

	if _pending_shockwave:
		# Glow oranye pada mesh selama charge shockwave
		if mesh_instance and _shockwave_mat:
			mesh_instance.material_override = _shockwave_mat
		# Warning text mengambang di atas boss
		if _damage_number_scene:
			var warn: Node3D = _damage_number_scene.instantiate()
			get_tree().current_scene.add_child(warn)
			warn.show_text_at("⚡ SHOCKWAVE!",
				global_position + Vector3(0.0, 2.5, 0.0),
				Color(1.0, 0.5, 0.0, 1.0), 40)

	if _attack_flash_scene:
		var flash: Node3D = _attack_flash_scene.instantiate()
		add_child(flash)
		flash.start(duration)
		_active_flash = flash


## Batalkan charge: hapus flash + shockwave state. Bisa dipanggil dari luar (parry).
func interrupt_charge() -> void:
	if _active_flash and is_instance_valid(_active_flash):
		_active_flash.queue_free()
		_active_flash = null
	if is_charging:
		is_charging = false
		_attack_timer = attack_cooldown
		if _pending_shockwave:
			_pending_shockwave = false
			if mesh_instance:
				mesh_instance.material_override = null


## Shockwave — AoE yang bypass semua defense player dalam radius SHOCKWAVE_RADIUS.
## Player harus berlari menjauh sebelum charge selesai.
func _do_shockwave() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var dist: float = absf(global_position.x - _target.global_position.x)
	if dist > SHOCKWAVE_RADIUS:
		return  # Player sudah berhasil lari — shockwave miss

	GameManager.request_screen_shake(0.3, 0.5)

	# Arah knockback: player terlempar menjauh dari boss
	var kb_dir: float = sign(_target.global_position.x - global_position.x)
	if kb_dir == 0.0:
		kb_dir = 1.0

	# Panggil metode khusus yang bypass parry dan i-frame
	if _target.has_method("take_unblockable_damage"):
		_target.call("take_unblockable_damage", SHOCKWAVE_DAMAGE, kb_dir)

	# Visual: burst oranye di posisi boss sebagai AoE indicator
	if _burst_scene:
		var burst: Node3D = _burst_scene.instantiate()
		get_tree().current_scene.add_child(burst)
		burst.global_position = global_position
		burst.start(Color(1.0, 0.45, 0.0, 1.0))


func _do_melee_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# Cek jarak — player mungkin sudah menjauh saat charge berakhir
	var dist: float = absf(global_position.x - _target.global_position.x)
	if dist > attack_range * 1.5:
		return
	if _target.has_method("take_damage"):
		_target.take_damage(damage, self)


func _fire(dir_x: float) -> void:
	if _projectile_scene == null:
		return
	var proj: Node3D = _projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(dir_x * 1.2, 0.0, 0.0)
	proj.set("direction", dir_x)
	if proj.has_method("set"):
		proj.set("speed", 8.0)   # Boss proyektil lebih cepat
		proj.set("damage", 15)


func take_damage(amount: int) -> void:
	if health <= 0:
		return  # Sudah mati — cegah double-die dari AoE di frame yang sama
	health -= amount
	_is_staggered = true
	interrupt_charge()  # Hapus flash + shockwave state + reset cooldown jika charging
	get_tree().create_timer(0.1).timeout.connect(
		func() -> void: _is_staggered = false, CONNECT_ONE_SHOT)
	if _damage_number_scene:
		var dn: Node3D = _damage_number_scene.instantiate()
		get_tree().current_scene.add_child(dn)
		dn.show_at(amount, global_position + Vector3(0, 1.0, 0))
	if mesh_instance and _hit_mat:
		mesh_instance.material_override = _hit_mat
		get_tree().create_timer(0.1).timeout.connect(
			func() -> void:
				if is_instance_valid(mesh_instance):
					mesh_instance.material_override = null, CONNECT_ONE_SHOT)
	if mesh_instance:
		var tween := create_tween()
		tween.tween_property(mesh_instance, "position", Vector3(0.2, 0.0, 0.0), 0.05)
		tween.tween_property(mesh_instance, "position", Vector3.ZERO, 0.05)
	if health <= 0:
		_die()


func _die() -> void:
	if _burst_scene:
		var burst: Node3D = _burst_scene.instantiate()
		get_tree().current_scene.add_child(burst)
		burst.global_position = global_position
		burst.start(BURST_COLOR)
	enemy_died.emit(self)
	queue_free()
