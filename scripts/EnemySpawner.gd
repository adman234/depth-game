class_name EnemySpawner
extends Node2D

signal wave_cleared(wave_number: int)

const SETUP_TIME := 45.0  # Mindustry-style build phase before waves start

# Discrete waves (Mindustry-style): a countdown to the next wave, then a
# burst of enemies trickles in, then — once every enemy from it is cleared —
# the countdown starts again. The countdown shrinks and each wave's enemy
# count grows as elapsed time (since waves started) increases.
const WAVE_INTERVAL_START := 25.0
const WAVE_INTERVAL_FLOOR := 8.0
const WAVE_INTERVAL_RAMP := 120.0

const BASE_WAVE_SIZE := 3
const WAVE_SIZE_GROWTH := 0.5  # extra enemies per wave number
const SPAWN_TRICKLE_INTERVAL := 0.35

const ENEMY_KINDS := {
	"grunt": {"speed": 40.0, "hp": 20.0, "damage": 10.0, "attack_duration": 5.0, "color": Color(0.75, 0.15, 0.55), "radius": 10.0},
	"charger": {"speed": 75.0, "hp": 12.0, "damage": 14.0, "attack_duration": 2.5, "color": Color(0.95, 0.55, 0.15), "radius": 8.0},
	"brute": {"speed": 22.0, "hp": 55.0, "damage": 20.0, "attack_duration": 7.0, "color": Color(0.55, 0.1, 0.1), "radius": 14.0},
}

var elapsed := 0.0
var core: Node2D
var spawn_points: Array = []
var paused := false
var current_layer := 1

var setup_active := true
var setup_remaining := SETUP_TIME

var wave_number := 0
var wave_countdown := 3.0
var enemies_to_spawn := 0
var spawn_trickle_timer := 0.0
var _wave_was_active := false

func _process(delta: float) -> void:
	if paused:
		return
	if setup_active:
		setup_remaining -= delta
		if setup_remaining <= 0.0:
			setup_remaining = 0.0
			setup_active = false
		return
	elapsed += delta

	if enemies_to_spawn > 0:
		_wave_was_active = true
		spawn_trickle_timer -= delta
		if spawn_trickle_timer <= 0.0:
			_spawn_enemy()
			enemies_to_spawn -= 1
			spawn_trickle_timer = SPAWN_TRICKLE_INTERVAL
		return

	# don't start counting down to the next wave until every enemy from this
	# one (or earlier stragglers) is actually dealt with
	if enemies_alive() > 0:
		return

	if _wave_was_active:
		_wave_was_active = false
		wave_cleared.emit(wave_number)

	wave_countdown -= delta
	if wave_countdown <= 0.0:
		_start_next_wave()

func enemies_alive() -> int:
	return get_tree().get_nodes_in_group("enemies").size()

func _start_next_wave() -> void:
	wave_number += 1
	enemies_to_spawn = BASE_WAVE_SIZE + int(wave_number * WAVE_SIZE_GROWTH) + (current_layer - 1)
	spawn_trickle_timer = 0.0
	var t: float = clamp(elapsed / WAVE_INTERVAL_RAMP, 0.0, 1.0)
	wave_countdown = lerp(WAVE_INTERVAL_START, WAVE_INTERVAL_FLOOR, t)

func skip_setup() -> void:
	setup_active = false
	setup_remaining = 0.0
	wave_countdown = 0.0  # start the first wave immediately, not after its own leftover delay

func _spawn_enemy() -> void:
	if spawn_points.is_empty() or core == null:
		return
	var e: Node2D = _make_enemy()
	e.target = core
	get_parent().add_child(e)
	e.position = spawn_points[randi() % spawn_points.size()]

func _make_enemy() -> Node2D:
	var roll := randf()
	if current_layer >= 3 and roll < 0.15:
		return _make_spitter()
	if current_layer >= 2 and roll < 0.40:
		return _make_kind("charger")
	if current_layer >= 2 and roll < 0.55:
		return _make_kind("brute")
	return _make_kind("grunt")

func _make_kind(kind: String) -> Enemy:
	var cfg: Dictionary = ENEMY_KINDS[kind]
	var e := Enemy.new()
	e.speed = cfg.speed
	e.contact_damage = cfg.damage
	e.attack_duration = cfg.attack_duration
	e.body_color = cfg.color
	e.radius = cfg.radius
	e.hp = cfg.hp + elapsed * 0.05 + (current_layer - 1) * 6.0
	e.max_hp = e.hp
	return e

func _make_spitter() -> SpitterEnemy:
	var e := SpitterEnemy.new()
	e.hp = 16.0 + elapsed * 0.05 + (current_layer - 1) * 5.0
	e.max_hp = e.hp
	return e
