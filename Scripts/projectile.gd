extends Area3D

## Proyektil dari ranged enemy — bergerak di sumbu X, damage player saat overlap.

@export var speed: float = 10.0
@export var damage: int = 8
@export var lifetime: float = 3.5

var direction: float = 1.0  # +1 = kanan, -1 = kiri
var _elapsed: float = 0.0


func _ready() -> void:
	collision_layer = 8   # layer proyektil
	collision_mask = 4    # deteksi player (layer 4)
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	global_position.x += direction * speed * delta
	global_position.z = 0.0


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
