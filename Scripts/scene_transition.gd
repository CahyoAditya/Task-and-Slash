extends CanvasLayer

## SceneTransition — Autoload singleton.
## Memberikan transisi fade-to-black yang mulus antar scene.
## Gunakan SceneTransition.go_to("res://Scenes/X.tscn") sebagai
## pengganti get_tree().change_scene_to_file().

var _overlay: ColorRect = null
var _is_transitioning: bool = false

const DEFAULT_FADE: float = 0.3


func _ready() -> void:
	layer = 100  # Di atas semua UI
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


## Fade ke hitam → ganti scene → fade kembali
func go_to(scene_path: String, fade_time: float = DEFAULT_FADE) -> void:
	if _is_transitioning:
		# Jika sedang transisi, langsung pindah tanpa efek
		get_tree().change_scene_to_file(scene_path)
		return

	_is_transitioning = true

	# Fade TO black
	var tw_in := create_tween()
	tw_in.tween_property(_overlay, "color:a", 1.0, fade_time)\
		.set_ease(Tween.EASE_IN)
	await tw_in.finished

	# Ganti scene
	get_tree().change_scene_to_file(scene_path)
	# Tunggu 1 frame agar scene baru selesai load
	await get_tree().process_frame

	# Fade FROM black
	var tw_out := create_tween()
	tw_out.tween_property(_overlay, "color:a", 0.0, fade_time)\
		.set_ease(Tween.EASE_OUT)
	await tw_out.finished
	_is_transitioning = false
