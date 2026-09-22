class_name Miner
extends BuildingBase

const BUILD_TIME := 1.2  # medium
const MINE_INTERVAL := 2.0

var facing: Vector2i = Vector2i.RIGHT
var timer := 0.0

func _ready() -> void:
	build_time = BUILD_TIME
	queue_redraw()

func _process(delta: float) -> void:
	if not _tick_construction(delta):
		return
	if not _tick_deconstruct(delta):
		return
	timer += delta * GridManager.miner_speed_mult
	if timer >= MINE_INTERVAL:
		var resource_type: String = GridManager.get_resource_type(cell)
		if resource_type == "":
			return
		var target_cell: Vector2i = cell + facing
		var target: Node = GridManager.get_building(target_cell)
		if target and target.try_receive(resource_type):
			timer = 0.0
			# a belt only holds one item at a time, so "double yield" can't
			# stuff a second item through immediately — instead it halves
			# the wait for the next one, which has the same economic effect
			if randf() < GridManager.miner_double_yield_chance:
				timer = MINE_INTERVAL * 0.5

func _draw() -> void:
	if not is_built:
		draw_rect(Rect2(-14, -14, 28, 28), Color(0.25, 0.55, 0.85, 0.35))
		draw_line(Vector2.ZERO, Vector2(facing) * 14, Color(1, 1, 1, 0.6), 3.0)
		_draw_construction_overlay(14.0)
		return
	if is_deconstructing:
		draw_rect(Rect2(-14, -14, 28, 28), Color(0.25, 0.55, 0.85))
		draw_line(Vector2.ZERO, Vector2(facing) * 14, Color.WHITE, 3.0)
		_draw_deconstruct_overlay(14.0)
		return
	draw_rect(Rect2(-14, -14, 28, 28), Color(0.25, 0.55, 0.85))
	draw_line(Vector2.ZERO, Vector2(facing) * 14, Color.WHITE, 3.0)
