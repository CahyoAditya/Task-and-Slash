extends CharacterBody3D

## Enemy dasar — placeholder untuk Sprint 1.
## Bergerak ke arah player, serang jika dalam jangkauan.
## Punya fase CHARGING (telegraph) sebelum menyerang.

signal enemy_died(enemy: Node)
signal health_changed(current: int, maximum: int)

const _DN_SCENE    := preload("res://Scenes/damage_number.tscn")
const _FLASH_SCENE := preload("res://Scenes/attack_flash.tscn")
const _BURST_SCENE := preload("res://Scenes/death_burst.tscn")

## Warna burst saat mati (merah untuk melee)
const BURST_COLOR := Color(1.0, 0.25, 0.15, 1.0)

@export var max_health: int = 3
@export var speed: float = 3.0
@export var damage: int = 10
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.5
@export var charge_time: float = 0.75
@export var score_value: int = 10

var health: int
## Public — player bisa cek apakah enemy sedang charging
var is_charging: bool = false

var _target: Node3D = null
var _attack_timer: float = 0.8   # Delay serangan pertama
var _charge_countdown: float = 0.0
var _is_staggered: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

static var _hit_mat: StandardMaterial3D  ## Dibagi semua instance enemy — dibuat sekali
var _active_flash: Node3D = null  ## Referensi ke flash node yang sedang aktif

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	collision_layer = 2
	collision_mask = 1
	# Pre-bake material hit flash agar tidak realokasi tiap frame
	if _hit_mat == null:
		_hit_mat = StandardMaterial3D.new()
		_hit_mat.albedo_color = Color(2.5, 2.5, 2.5, 1.0)
		_hit_mat.emission_enabled = true
		_hit_mat.emission = Color.WHITE
	_target = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta * 2
	velocity.z = 0.0
	transform.origin.z = 0.0

	if _target == null:
		_target = get_tree().get_first_node_in_group("player")
		move_and_slide()
		return

	# Stagger: berhenti sejenak setelah kena hit
	if _is_staggered:
		velocity.x = move_toward(velocity.x, 0.0, speed * 20.0 * delta)
		move_and_slide()
		return

	# Charging: diam di tempat, tunggu countdown
	if is_charging:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		_charge_countdown -= delta
		if _charge_countdown <= 0.0:
			is_charging = false
			_attack_timer = attack_cooldown
			_do_attack()
		move_and_slide()
		return

	var dist: float = abs(global_position.x - _target.global_position.x)

	if dist > attack_range:
		var dir_x: float = sign(_target.global_position.x - global_position.x)
		velocity.x = dir_x * speed
		rotation.y = 0.0 if dir_x > 0 else PI
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_start_charge()

	move_and_slide()


## Mulai fase telegraph — tampilkan flash, tunggu charge_time sebelum serang
func _start_charge() -> void:
	# Batasi maks 2 enemy charging bersamaan
	var charging_count: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e != self and e.get("is_charging") == true:
			charging_count += 1
	if charging_count >= 2:
		_attack_timer = attack_cooldown * 0.6  # Coba lagi sebentar
		return
	is_charging = true
	_charge_countdown = charge_time
	# Spawn attack flash sebagai child
	if _FLASH_SCENE:
		var flash: Node3D = _FLASH_SCENE.instantiate()
		add_child(flash)
		flash.start(charge_time)
		_active_flash = flash


## Batalkan charge: hapus flash, reset cooldown. Bisa dipanggil dari luar (parry).
func interrupt_charge() -> void:
	if _active_flash and is_instance_valid(_active_flash):
		_active_flash.queue_free()
		_active_flash = null
	if is_charging:
		is_charging = false
		_attack_timer = attack_cooldown  # Paksa cooldown penuh seolah serangan sudah dipakai


func _do_attack() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# Cek jarak saat charge berakhir — player mungkin sudah menjauh
	var dist: float = absf(global_position.x - _target.global_position.x)
	if dist > attack_range * 1.5:
		return
	if _target.has_method("take_damage"):
		_target.take_damage(damage, self)


## Dipanggil saat player menyerang enemy (hitbox overlap)
func take_damage(amount: int) -> void:
	if health <= 0:
		return  # Sudah mati — cegah double-die dari AoE di frame yang sama
	health -= amount
	health_changed.emit(health, max_health)
	_is_staggered = true
	interrupt_charge()  # Hapus flash + reset cooldown jika sedang charging
	get_tree().create_timer(0.15).timeout.connect(
		func() -> void: _is_staggered = false, CONNECT_ONE_SHOT)
	if _DN_SCENE:
		var dn: Node3D = _DN_SCENE.instantiate()
		get_tree().current_scene.add_child(dn)
		dn.show_at(amount, global_position)
	# Hit flash: berkedip putih singkat
	if mesh_instance and _hit_mat:
		mesh_instance.material_override = _hit_mat
		get_tree().create_timer(0.08).timeout.connect(
			func() -> void:
				if is_instance_valid(mesh_instance):
					mesh_instance.material_override = null, CONNECT_ONE_SHOT)
	# Mesh shake
	if mesh_instance:
		var tween := create_tween()
		tween.tween_property(mesh_instance, "position", Vector3(0.15, 0.0, 0.0), 0.04)
		tween.tween_property(mesh_instance, "position", Vector3.ZERO, 0.04)
	if health <= 0:
		_die()


func _die() -> void:
	# Spawn death burst
	if _BURST_SCENE:
		var burst: Node3D = _BURST_SCENE.instantiate()
		get_tree().current_scene.add_child(burst)
		burst.global_position = global_position
		burst.start(BURST_COLOR)
	enemy_died.emit(self)
	queue_free()
