extends Camera3D

@export var target_path: NodePath
@export var smooth_speed: float = 5.0
@export var offset: Vector3 = Vector3(0, 2, 10)

var target: Node3D

## Screen shake state
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0




func _ready() -> void:
	if target_path:
		target = get_node(target_path)
	GameManager.screen_shake.connect(_on_screen_shake)
	GameManager.parry_cinematic.connect(_on_parry_cinematic)


func _physics_process(delta: float) -> void:
	if not target:
		return

	# Smooth follow (tanpa zoom — zoom diterapkan terpisah di bawah)
	var target_pos := target.global_position + offset
	global_position = global_position.lerp(target_pos, smooth_speed * delta)
	look_at(target.global_position)

	# Screen shake — diterapkan langsung, tanpa lerp
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var sx := randf_range(-_shake_intensity, _shake_intensity)
		var sy := randf_range(-_shake_intensity, _shake_intensity)
		global_position += Vector3(sx, sy, 0.0)
	else:
		_shake_intensity = 0.0




func _on_screen_shake(amount: float, duration: float) -> void:
	_shake_intensity = amount
	_shake_timer = duration


## Zoom via FOV — kamera tidak bergerak, dunia terlihat lebih dekat dari posisi saat ini
func _on_parry_cinematic() -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)  ## Tetap berjalan saat slowmo aktif
	tw.tween_property(self, "fov", 50.0, 0.04)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(0.05)
	tw.tween_property(self, "fov", 75.0, 0.08)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
