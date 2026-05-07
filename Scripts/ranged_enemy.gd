extends CharacterBody3D

## Ranged enemy — menjaga jarak, tembak proyektil ke arah player.

signal enemy_died(enemy: Node)

const _DN_SCENE    := preload("res://Scenes/damage_number.tscn")
const _FLASH_SCENE := preload("res://Scenes/attack_flash.tscn")
const _BURST_SCENE := preload("res://Scenes/death_burst.tscn")
const _PROJ_SCENE  := preload("res://Scenes/projectile.tscn")

const BURST_COLOR := Color(0.1, 0.3, 1.0, 1.0)

@export var max_health: int = 2
@export var speed: float = 2.5
@export var preferred_distance: float = 5.5
@export var fire_cooldown: float = 2.5
@export var charge_time: float = 0.9
@export var score_value: int = 25

var health: int
var is_charging: bool = false
var _target: Node3D = null
var _fire_timer: float = 1.2
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

	if _is_staggered:
		velocity.x = move_toward(velocity.x, 0.0, speed * 20.0 * delta)
		move_and_slide()
		return

	var dist: float = abs(global_position.x - _target.global_position.x)
	var dir_x: float = sign(_target.global_position.x - global_position.x)

	# Charging: diam, tunggu countdown lalu tembak
	if is_charging:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
		_charge_countdown -= delta
		if _charge_countdown <= 0.0:
			is_charging = false
			_fire_timer = fire_cooldown
			_fire(dir_x)
		move_and_slide()
		return

	# Jaga jarak ideal — mundur jika terlalu dekat
	if dist < preferred_distance - 1.0:
		velocity.x = -dir_x * speed
	elif dist > preferred_distance + 1.5:
		velocity.x = dir_x * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 10.0 * delta)
	rotation.y = 0.0 if dir_x > 0 else PI

	# Mulai charge sebelum tembak
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_start_charge()

	move_and_slide()


func _start_charge() -> void:
	var charging_count: int = 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e != self and e.get("is_charging") == true:
			charging_count += 1
	if charging_count >= 2:
		_fire_timer = fire_cooldown * 0.6
		return
	is_charging = true
	_charge_countdown = charge_time
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
		_fire_timer = fire_cooldown  # Paksa cooldown penuh seolah sudah tembak


func _fire(dir_x: float) -> void:
	if dir_x == 0.0:
		dir_x = 1.0  # Default ke kanan jika sejajar
	if _PROJ_SCENE == null:
		return
	var proj: Node3D = _PROJ_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + Vector3(dir_x * 0.9, -0.2, 0.0)
	proj.direction = dir_x


func take_damage(amount: int) -> void:
	if health <= 0:
		return  # Sudah mati — cegah double-die dari AoE di frame yang sama
	health -= amount
	_is_staggered = true
	interrupt_charge()  # Hapus flash + reset cooldown jika sedang charging
	get_tree().create_timer(0.15).timeout.connect(
		func() -> void: _is_staggered = false, CONNECT_ONE_SHOT)
	if _DN_SCENE:
		var dn: Node3D = _DN_SCENE.instantiate()
		get_tree().current_scene.add_child(dn)
		dn.show_at(amount, global_position)
	if mesh_instance and _hit_mat:
		mesh_instance.material_override = _hit_mat
		get_tree().create_timer(0.08).timeout.connect(
			func() -> void:
				if is_instance_valid(mesh_instance):
					mesh_instance.material_override = null, CONNECT_ONE_SHOT)
	if mesh_instance:
		var tween := create_tween()
		tween.tween_property(mesh_instance, "position", Vector3(0.15, 0.0, 0.0), 0.04)
		tween.tween_property(mesh_instance, "position", Vector3.ZERO, 0.04)
	if health <= 0:
		_die()


func _die() -> void:
	if _BURST_SCENE:
		var burst: Node3D = _BURST_SCENE.instantiate()
		get_tree().current_scene.add_child(burst)
		burst.global_position = global_position
		burst.start(BURST_COLOR)
	enemy_died.emit(self)
	queue_free()
