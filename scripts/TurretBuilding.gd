class_name TurretBuilding
extends BuildingBase

const BUILD_TIME := 2.5  # slow
const MAX_AMMO := 5
const RANGE := 160.0
const FIRE_INTERVAL := 0.65
const DAMAGE := 8.0
const RECOIL_SHRINK := 0.8
const RECOIL_RECOVERY_SPEED := 8.0
const SPLASH_RADIUS := 50.0
const SPLASH_DAMAGE_FRACTION := 0.5

const SEARCH_TURN_SPEED := deg_to_rad(45.0)   # slow idle scanning
const TARGET_TURN_SPEED := deg_to_rad(260.0)  # fast lock-on once a target exists
const AIM_TOLERANCE := deg_to_rad(6.0)
const SEARCH_RETARGET_MIN := 2.0
const SEARCH_RETARGET_MAX := 3.5

var ammo := 0
var fire_timer := 0.0
var aim_dir: Vector2 = Vector2.UP
var recoil_scale := 1.0

var aim_angle: float = -PI / 2.0
var search_target_angle: float = -PI / 2.0
var search_timer: float = 0.0

func _ready() -> void:
	build_time = BUILD_TIME
	queue_redraw()

func try_receive(item: String) -> bool:
	if not is_built or is_deconstructing:
		return false
	if item == "plate":
		if ammo >= MAX_AMMO:
			return false
		ammo += 1
		queue_redraw()
		return true
	if item == "adv_plate":
		if ammo >= MAX_AMMO:
			return false
		ammo = min(MAX_AMMO, ammo + 2)
		queue_redraw()
		return true
	return false

func _process(delta: float) -> void:
	if not _tick_construction(delta):
		return
	if not _tick_deconstruct(delta):
		return

	var effective_range: float = RANGE * GridManager.turret_range_mult
	var target: Node2D = _find_target(effective_range)
	var is_aimed := false

	if target:
		var desired_angle: float = (target.global_position - global_position).angle()
		aim_angle = _rotate_towards(aim_angle, desired_angle, TARGET_TURN_SPEED * delta)
		is_aimed = absf(wrapf(desired_angle - aim_angle, -PI, PI)) <= AIM_TOLERANCE
	else:
		search_timer -= delta
		if search_timer <= 0.0:
			search_target_angle = randf() * TAU
			search_timer = SEARCH_RETARGET_MIN + randf() * (SEARCH_RETARGET_MAX - SEARCH_RETARGET_MIN)
		aim_angle = _rotate_towards(aim_angle, search_target_angle, SEARCH_TURN_SPEED * delta)

	aim_dir = Vector2.from_angle(aim_angle)

	recoil_scale = lerp(recoil_scale, 1.0, min(1.0, delta * RECOIL_RECOVERY_SPEED))
	scale = Vector2.ONE * recoil_scale

	fire_timer += delta * GridManager.turret_fire_rate_mult
	if target and is_aimed and fire_timer >= FIRE_INTERVAL and ammo > 0:
		_fire_at(target)
		fire_timer = 0.0
		recoil_scale = RECOIL_SHRINK
		var extra_shots := 0
		if GridManager.turret_extra_gun:
			extra_shots = 1
		elif randf() < GridManager.turret_double_shot_chance:
			extra_shots = 1
		if extra_shots > 0 and ammo > 0:
			_fire_at(target)

	queue_redraw()

func _fire_at(target: Node2D) -> void:
	target.take_damage(DAMAGE * GridManager.turret_damage_mult)
	ammo -= 1
	if randf() < GridManager.turret_splash_chance:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != target and e.global_position.distance_to(target.global_position) <= SPLASH_RADIUS:
				e.take_damage(DAMAGE * GridManager.turret_damage_mult * SPLASH_DAMAGE_FRACTION)

func _rotate_towards(from: float, to: float, max_delta: float) -> float:
	var diff: float = wrapf(to - from, -PI, PI)
	if absf(diff) <= max_delta:
		return to
	return from + sign(diff) * max_delta

func _find_target(range_px: float) -> Node2D:
	var closest: Node2D = null
	var closest_dist: float = range_px
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d <= closest_dist:
			closest_dist = d
			closest = e
	return closest

func _draw() -> void:
	if not is_built:
		draw_rect(Rect2(-14, -14, 28, 28), Color(0.8, 0.25, 0.2, 0.35))
		_draw_construction_overlay(14.0)
		return
	if is_deconstructing:
		draw_rect(Rect2(-14, -14, 28, 28), Color(0.8, 0.25, 0.2))
		_draw_deconstruct_overlay(14.0)
		return
	var col: Color = Color(0.8, 0.25, 0.2) if ammo > 0 else Color(0.4, 0.15, 0.15)
	draw_rect(Rect2(-14, -14, 28, 28), col)
	draw_line(Vector2.ZERO, aim_dir * 18.0, Color(0.95, 0.95, 0.9), 4.0)
	if GridManager.turret_extra_gun:
		var side: Vector2 = aim_dir.rotated(PI / 2.0) * 5.0
		draw_line(side, side + aim_dir * 16.0, Color(0.95, 0.95, 0.9), 3.0)
		draw_line(-side, -side + aim_dir * 16.0, Color(0.95, 0.95, 0.9), 3.0)
	draw_arc(Vector2.ZERO, RANGE * GridManager.turret_range_mult, 0, TAU, 48, Color(1, 0.3, 0.3, 0.15), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-13, 5), str(ammo), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	# reload/fire-cooldown bar: fills up as the next shot becomes ready
	var reload_pct: float = clamp(fire_timer / FIRE_INTERVAL, 0.0, 1.0)
	draw_rect(Rect2(-12, 18, 24, 4), Color(0.15, 0.15, 0.15, 0.85))
	draw_rect(Rect2(-12, 18, 24 * reload_pct, 4), Color(0.9, 0.4, 0.3) if reload_pct < 1.0 else Color(0.4, 0.9, 0.4))
