class_name BuildingBase
extends Node2D

signal deconstruct_finished
signal construction_finished

var cell: Vector2i

var build_time: float = 0.0
var build_elapsed: float = 0.0
var is_built: bool = false
# Only the head of Main's global construction queue gets to progress; every
# other queued building sits at 0% until its turn (see Main._refresh_construction_queue).
var construction_active: bool = false

var is_deconstructing: bool = false
var deconstruct_elapsed: float = 0.0
var deconstruct_time: float = 0.0
var deconstruct_done: bool = false

# Override in subclasses. Return true if the item was accepted.
func try_receive(_item_type: String) -> bool:
	return false

# Call at the top of each subclass's _process(). Returns true once
# construction is finished, so the subclass can run its normal behavior.
func _tick_construction(delta: float) -> bool:
	if is_built:
		return true
	if GridManager.instant_build_charges > 0:
		GridManager.instant_build_charges -= 1
		is_built = true
		build_elapsed = build_time
		queue_redraw()
		construction_finished.emit()
		return true
	if not construction_active:
		return false
	build_elapsed += delta * GridManager.build_speed_mult
	queue_redraw()
	if build_elapsed >= build_time:
		is_built = true
		build_elapsed = build_time
		queue_redraw()
		construction_finished.emit()
	return is_built

func start_deconstruct() -> void:
	if is_deconstructing:
		return
	is_deconstructing = true
	deconstruct_time = max(0.05, build_time * 0.5)
	deconstruct_elapsed = 0.0
	queue_redraw()

# Call right after _tick_construction in each subclass's _process(). Returns
# false (and keeps ticking down) while mid-deconstruction; a building never
# resumes normal behavior once this has started.
func _tick_deconstruct(delta: float) -> bool:
	if not is_deconstructing:
		return true
	if deconstruct_done:
		return false
	deconstruct_elapsed += delta
	queue_redraw()
	if deconstruct_elapsed >= deconstruct_time:
		deconstruct_done = true
		deconstruct_finished.emit()
	return false

func _draw_construction_overlay(half_size: float) -> void:
	var pct: float = 1.0 if build_time <= 0.0 else clamp(build_elapsed / build_time, 0.0, 1.0)
	draw_rect(Rect2(-half_size, -half_size, half_size * 2.0, half_size * 2.0), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(-half_size, half_size + 4.0, half_size * 2.0, 5.0), Color(0.15, 0.15, 0.15, 0.85))
	draw_rect(Rect2(-half_size, half_size + 4.0, half_size * 2.0 * pct, 5.0), Color(0.95, 0.85, 0.3))

func _draw_deconstruct_overlay(half_size: float) -> void:
	var pct: float = 1.0 if deconstruct_time <= 0.0 else clamp(deconstruct_elapsed / deconstruct_time, 0.0, 1.0)
	draw_rect(Rect2(-half_size, -half_size, half_size * 2.0, half_size * 2.0), Color(0.5, 0.05, 0.05, 0.45))
	draw_rect(Rect2(-half_size, half_size + 4.0, half_size * 2.0, 5.0), Color(0.15, 0.15, 0.15, 0.85))
	draw_rect(Rect2(-half_size, half_size + 4.0, half_size * 2.0 * (1.0 - pct), 5.0), Color(0.9, 0.3, 0.25))
