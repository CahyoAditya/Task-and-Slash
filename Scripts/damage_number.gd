extends Label3D

## Floating damage number / floating text label.
## Muncul di atas posisi tertentu, melayang ke atas, lalu menghilang.


func show_at(amount: int, pos: Vector3) -> void:
	if amount >= 2:
		# Damage besar (combo finisher) — tampilkan lebih mencolok
		show_text_at(str(amount), pos, Color(1.0, 0.6, 0.1, 1.0), 80)
	else:
		show_text_at(str(amount), pos, Color(1.0, 0.9, 0.1, 1.0), 64)


## Tampilkan angka damage kritikal — lebih besar, warna oranye-merah, dengan efek scale
func show_critical_at(amount: int, pos: Vector3) -> void:
	global_position = pos + Vector3(randf_range(-0.2, 0.2), 2.2, 0.0)
	text = "💥 %d!" % amount
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = 88
	outline_size = 10
	modulate = Color(1.0, 0.4, 0.05, 1.0)  # Oranye api

	# Scale punch: mulai besar, shrink ke normal lalu fade
	scale = Vector3(1.5, 1.5, 1.5)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "global_position",
		global_position + Vector3(0.0, 1.8, 0.0), 0.9)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)\
		.set_delay(0.5)
	tween.chain().tween_callback(queue_free)


## Generic floating text — untuk PARRY!, DODGE!, dan pesan lain
func show_text_at(msg: String, pos: Vector3, col: Color, size: int = 48) -> void:
	global_position = pos + Vector3(randf_range(-0.3, 0.3), 1.8, 0.0)
	text = msg
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = size
	outline_size = 8
	modulate = col

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position",
		global_position + Vector3(0.0, 1.4, 0.0), 0.75)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)\
		.set_delay(0.35)
	tween.chain().tween_callback(queue_free)
