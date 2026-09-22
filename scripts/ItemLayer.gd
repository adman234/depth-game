class_name ItemLayer
extends Node2D

# Drawing every in-transit item from one node with a high, absolute z_index
# guarantees items are always on top of every belt/building, regardless of
# sibling order or per-node z_index ties between two adjacent carrying belts.
func _ready() -> void:
	z_index = 100
	z_as_relative = false
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for building in GridManager.buildings.values():
		if building is Belt and building.has_item:
			var belt: Belt = building
			# span the full tile (-16..+16) so the position lines up exactly
			# with the next belt's start, instead of leaving a small gap that
			# reads as a lurch/snap at every tile boundary
			var offset: Vector2 = Vector2(belt.direction) * (belt.progress * 32.0 - 16.0)
			var pos: Vector2 = belt.position + offset
			if belt.item_type == "plate":
				_draw_magazine(pos, Color(0.75, 0.78, 0.8))
			elif belt.item_type == "adv_plate":
				_draw_magazine(pos, Color(0.4, 0.85, 0.9))
			else:
				draw_circle(pos, 6.0, _item_color(belt.item_type))

func _draw_magazine(pos: Vector2, body_color: Color) -> void:
	var points := PackedVector2Array([
		pos + Vector2(-3, -6),
		pos + Vector2(3, -6),
		pos + Vector2(3, 3),
		pos + Vector2(1.5, 6),
		pos + Vector2(-1.5, 6),
		pos + Vector2(-3, 3),
	])
	draw_colored_polygon(points, body_color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), Color(0.25, 0.25, 0.25, 0.8), 1.0)
	draw_line(pos + Vector2(-2.2, -3), pos + Vector2(2.2, -3), Color(0.15, 0.15, 0.18, 0.6), 1.0)
	draw_line(pos + Vector2(-2, 0), pos + Vector2(2, 0), Color(0.15, 0.15, 0.18, 0.6), 1.0)

func _item_color(t: String) -> Color:
	match t:
		"scrap":
			return Color(0.62, 0.6, 0.56)
		"circuitry":
			return Color(0.35, 0.8, 0.85)
		_:
			return Color.WHITE
