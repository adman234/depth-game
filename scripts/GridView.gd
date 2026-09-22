class_name GridView
extends Node2D

const TILE := 32

var map_w := 30
var map_h := 20

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	for x in range(map_w):
		for y in range(map_h):
			var cell := Vector2i(x, y)
			var pos := Vector2(x * TILE, y * TILE)
			var col := Color(0.13, 0.12, 0.11)
			var res: String = GridManager.get_resource_type(cell)
			if res == "scrap":
				col = Color(0.42, 0.40, 0.38)
			elif res == "circuitry":
				col = Color(0.18, 0.35, 0.4)
			draw_rect(Rect2(pos, Vector2(TILE, TILE)), col)
			draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color(0, 0, 0, 0.15), false)
