extends Node3D

## Attack telegraph flash — muncul di atas enemy sebelum menyerang.
## Spawn sebagai child enemy, auto-free setelah selesai.


func start(charge_duration: float) -> void:
	visible = true
	scale = Vector3(0.1, 0.1, 0.1)

	var tween := create_tween()
	# Burst muncul cepat
	tween.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), 0.1)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	# Pulse selama charge window
	var pulse_time := (charge_duration - 0.25) * 0.5
	tween.tween_property(self, "scale", Vector3(1.2, 1.2, 1.2), pulse_time)
	tween.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), pulse_time)
	# Disappear saat serangan keluar
	tween.tween_property(self, "scale", Vector3.ZERO, 0.08)
	tween.tween_callback(queue_free)
