class_name Depot
extends BuildingBase

const BUILD_TIME := 1.6
const MAX_RESERVE := 100
const RANGE_TILES := 15

var reserve: int = 0
var highlighted: bool = false

func _ready() -> void:
	build_time = BUILD_TIME
	queue_redraw()

func try_receive(item: String) -> bool:
	if not is_built or is_deconstructing:
		return false
	if item != "scrap":
		return false
	if reserve >= MAX_RESERVE + GridManager.depot_capacity_bonus:
		return false
	reserve += 1
	queue_redraw()
	return true

func effective_range_px() -> float:
	return RANGE_TILES * 32.0 * GridManager.depot_range_mult

func _process(delta: float) -> void:
	if not _tick_construction(delta):
		return
	_tick_deconstruct(delta)

func _draw() -> void:
	if not is_built:
		draw_rect(Rect2(-16, -16, 32, 32), Color(0.6, 0.55, 0.25, 0.35))
		_draw_construction_overlay(16.0)
		return
	if is_deconstructing:
		draw_rect(Rect2(-16, -16, 32, 32), Color(0.6, 0.55, 0.25))
		_draw_deconstruct_overlay(16.0)
		return
	var range_px: float = effective_range_px()
	if highlighted:
		draw_arc(Vector2.ZERO, range_px, 0, TAU, 64, Color(1.0, 0.95, 0.4, 0.16), 2.0)
	else:
		draw_arc(Vector2.ZERO, range_px, 0, TAU, 64, Color(0.9, 0.85, 0.3, 0.07), 1.0)
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.6, 0.55, 0.25))
	if highlighted:
		draw_rect(Rect2(-18, -18, 36, 36), Color(1.0, 0.95, 0.4, 0.9), false, 3.0)
	else:
		draw_rect(Rect2(-16, -16, 32, 32), Color(0, 0, 0, 0.35), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-13, 5), str(reserve), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
