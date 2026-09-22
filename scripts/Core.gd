class_name Core
extends Node2D

const SHOCKWAVE_RADIUS := 100.0
const SHOCKWAVE_DAMAGE := 15.0
const PULSE_INTERVAL := 4.0
const PULSE_RADIUS := 80.0
const PULSE_DAMAGE := 6.0

signal hp_changed(hp: float)
signal died

var max_hp := 100.0
var hp := 100.0
var is_dead := false
var pulse_timer := 0.0

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	if is_dead:
		return
	if GridManager.core_regen_per_sec > 0.0 and hp < max_hp:
		hp = min(max_hp, hp + GridManager.core_regen_per_sec * delta)
		hp_changed.emit(hp)
		queue_redraw()
	if not GridManager.core_passive_pulse:
		return
	pulse_timer += delta
	if pulse_timer >= PULSE_INTERVAL:
		pulse_timer = 0.0
		_damage_nearby(PULSE_RADIUS, PULSE_DAMAGE)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	hp = max(0.0, hp - amount)
	hp_changed.emit(hp)
	queue_redraw()
	if GridManager.core_shockwave_on_hit:
		_damage_nearby(SHOCKWAVE_RADIUS, SHOCKWAVE_DAMAGE)
	if hp <= 0.0:
		is_dead = true
		died.emit()

func _damage_nearby(radius: float, damage: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= radius:
			e.take_damage(damage)

func _draw() -> void:
	draw_rect(Rect2(-20, -20, 40, 40), Color(0.9, 0.75, 0.2))
	draw_rect(Rect2(-20, -20, 40, 40), Color(0, 0, 0, 0.4), false, 2.0)
