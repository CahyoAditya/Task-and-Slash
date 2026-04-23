extends Label3D

## Floating damage number / floating text label.
## Muncul di atas posisi tertentu, melayang ke atas, lalu menghilang.


func show_at(amount: int, pos: Vector3) -> void:
	show_text_at(str(amount), pos, Color(1.0, 0.9, 0.1, 1.0), 64)


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

