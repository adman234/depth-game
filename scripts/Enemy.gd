class_name Enemy
extends Node2D

# Configurable so EnemySpawner can build several "kinds" (grunt/charger/brute)
# from one script instead of needing a subclass per kind.
var speed := 40.0
var hp := 20.0
var max_hp := 20.0
var contact_damage := 10.0
var attack_duration := 5.0  # time spent gnawing on the core before it disappears
var body_color := Color(0.75, 0.15, 0.55)
var radius := 10.0
var target: Node2D

var is_attacking := false
var attack_timer := 0.0

func _ready() -> void:
	add_to_group("enemies")
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	if is_attacking:
		attack_timer += delta
		target.take_damage(contact_damage / attack_duration * delta)
		if attack_timer >= attack_duration:
			queue_free()
		return

	var dir: Vector2 = (target.global_position - global_position).normalized()
	global_position += dir * speed * delta
	if global_position.distance_to(target.global_position) < 12.0 + radius:
		is_attacking = true
		attack_timer = 0.0
		queue_redraw()

func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0:
		if GridManager.scrap_per_kill > 0:
			GridManager.global_scrap += GridManager.scrap_per_kill
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, body_color)
	if is_attacking:
		draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 16, Color(1.0, 0.3, 0.1, 0.6), 2.0)
	if hp < max_hp:
		var pct: float = clamp(hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-radius, -radius - 8.0, radius * 2.0, 3.0), Color(0.15, 0.15, 0.15, 0.8))
		draw_rect(Rect2(-radius, -radius - 8.0, radius * 2.0 * pct, 3.0), Color(0.9, 0.2, 0.2))
