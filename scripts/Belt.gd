class_name Belt
extends BuildingBase

const BUILD_TIME := 0.25  # very fast
const TRANSFER_TIME := 0.6

var direction: Vector2i = Vector2i.RIGHT
var has_item := false
var item_type := ""
var progress := 0.0

func _ready() -> void:
	build_time = BUILD_TIME
	queue_redraw()

func try_receive(item: String) -> bool:
	if not is_built or is_deconstructing:
		return false
	if has_item:
		return false
	has_item = true
	item_type = item
	progress = 0.0
	return true

func _process(delta: float) -> void:
	if not _tick_construction(delta):
		return
	if not _tick_deconstruct(delta):
		return
	if not has_item:
		return
	if progress < 1.0:
		progress = min(1.0, progress + delta / TRANSFER_TIME * GridManager.belt_speed_mult)
		return
	var target_cell: Vector2i = cell + direction
	var target: Node = GridManager.get_building(target_cell)
	if target and target.try_receive(item_type):
		has_item = false
		item_type = ""
		progress = 0.0

func _draw() -> void:
	if not is_built:
		draw_rect(Rect2(-16, -16, 32, 32), Color(0.35, 0.35, 0.38, 0.35))
		draw_line(Vector2.ZERO, Vector2(direction) * 12, Color(0.7, 0.7, 0.75, 0.6), 2.0)
		_draw_construction_overlay(16.0)
		return
	if is_deconstructing:
		draw_rect(Rect2(-16, -16, 32, 32), Color(0.35, 0.35, 0.38))
		draw_line(Vector2.ZERO, Vector2(direction) * 12, Color(0.7, 0.7, 0.75), 2.0)
		_draw_deconstruct_overlay(16.0)
		return
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.35, 0.35, 0.38))
	draw_line(Vector2.ZERO, Vector2(direction) * 12, Color(0.7, 0.7, 0.75), 2.0)
