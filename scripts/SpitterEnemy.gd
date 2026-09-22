class_name SpitterEnemy
extends Node2D

const STANDOFF_RANGE := 130.0
const FIRE_INTERVAL := 1.6
const DAMAGE := 6.0

var speed := 30.0
var hp := 16.0
var max_hp := 16.0
var target: Node2D
var fire_timer := 0.0

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	if dist > STANDOFF_RANGE:
		global_position += to_target.normalized() * speed * delta
	else:
		fire_timer += delta
		if fire_timer >= FIRE_INTERVAL:
			fire_timer = 0.0
			target.take_damage(DAMAGE)
			queue_redraw()

func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0:
		if GridManager.scrap_per_kill > 0:
			GridManager.global_scrap += GridManager.scrap_per_kill
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(0.35, 0.75, 0.35))
	draw_arc(Vector2.ZERO, STANDOFF_RANGE, 0, TAU, 24, Color(0.35, 0.75, 0.35, 0.1), 1.0)
	if hp < max_hp:
		var pct: float = clamp(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-9, -17, 18, 3), Color(0.15, 0.15, 0.15, 0.8))
		draw_rect(Rect2(-9, -17, 18 * pct, 3), Color(0.9, 0.2, 0.2))
