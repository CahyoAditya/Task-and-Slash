extends Node3D

## Death burst VFX — partikel simpel saat enemy mati.
## Dibuat sepenuhnya via kode (tidak perlu aset).


func start(base_color: Color) -> void:
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.30

	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	mat.emission_enabled = true
	mat.emission = base_color
	mat.emission_energy_multiplier = 2.5

	var count := 8
	for i in count:
		var mesh := MeshInstance3D.new()
		mesh.mesh = sphere_mesh
		mesh.material_override = mat
		add_child(mesh)

		var angle  := (float(i) / count) * TAU
		var spd    := randf_range(1.5, 3.2)
		var end_x  := cos(angle) * spd
		var end_y  := maxf(sin(angle) * spd, 0.2)
		var end_pos := Vector3(end_x, end_y, 0.0)

		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(mesh, "position", end_pos, 0.45)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(mesh, "scale", Vector3.ZERO, 0.45)\
			.set_delay(0.08).set_ease(Tween.EASE_IN)

	# Auto-free setelah animasi selesai
	get_tree().create_timer(0.55).timeout.connect(queue_free, CONNECT_ONE_SHOT)
