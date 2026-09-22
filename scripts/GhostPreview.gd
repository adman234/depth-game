class_name GhostPreview
extends Node2D

# tool ints match Main.Tool: 0 miner, 1 belt, 2 assembler, 3 turret, 4 depot
var tool: int = 1
var dir: Vector2i = Vector2i.RIGHT
var valid: bool = true
var redirecting: bool = false  # hovering an existing building of the same type — free re-face in place

func set_state(p_tool: int, p_dir: Vector2i, p_valid: bool, p_redirecting: bool) -> void:
	if tool == p_tool and dir == p_dir and valid == p_valid and redirecting == p_redirecting:
		return
	tool = p_tool
	dir = p_dir
	valid = p_valid
	redirecting = p_redirecting
	queue_redraw()

func _draw() -> void:
	var base_col: Color
	match tool:
		0:
			base_col = Color(0.25, 0.55, 0.85)
		1:
			base_col = Color(0.45, 0.45, 0.48)
		2:
			base_col = Color(0.55, 0.3, 0.7)
		3:
			base_col = Color(0.8, 0.25, 0.2)
		4:
			base_col = Color(0.6, 0.55, 0.25)
		_:
			base_col = Color.WHITE

	# redirect-in-place reads as a distinct action (rotate, not build) —
	# override with a bright cyan tint regardless of tool color
	if redirecting:
		base_col = Color(0.3, 0.85, 0.9)
	base_col.a = 0.55 if (valid or redirecting) else 0.25

	if tool == 3:
		draw_rect(Rect2(-14, -14, 28, 28), base_col)
		draw_arc(Vector2.ZERO, 160.0, 0, TAU, 48, Color(1, 0.3, 0.3, 0.1), 1.0)
		if redirecting:
			_draw_rotate_icon(Vector2(20, -20))
		return

	if tool == 4:
		draw_arc(Vector2.ZERO, 15.0 * 32.0, 0, TAU, 64, Color(0.9, 0.85, 0.3, 0.08), 1.0)
		draw_rect(Rect2(-16, -16, 32, 32), base_col)
		if not valid and not redirecting:
			draw_line(Vector2(-16, -16), Vector2(16, 16), Color(0.9, 0.1, 0.1, 0.6), 2.0)
			draw_line(Vector2(-16, 16), Vector2(16, -16), Color(0.9, 0.1, 0.1, 0.6), 2.0)
		return

	var size: float = 32.0 if tool == 1 else 28.0
	var half: float = size * 0.5
	draw_rect(Rect2(-half, -half, size, size), base_col)
	draw_line(Vector2.ZERO, Vector2(dir) * (half - 2.0), Color(1, 1, 1, 0.85), 3.0)

	if redirecting:
		_draw_rotate_icon(Vector2(half + 6.0, -half - 6.0))
	elif not valid:
		draw_line(Vector2(-half, -half), Vector2(half, half), Color(0.9, 0.1, 0.1, 0.6), 2.0)
		draw_line(Vector2(-half, half), Vector2(half, -half), Color(0.9, 0.1, 0.1, 0.6), 2.0)

func _draw_rotate_icon(pos: Vector2) -> void:
	# a clean circular-arrow ("refresh") glyph — means "re-face this in
	# place," distinct from a normal build/invalid indicator
	var r := 7.0
	var start_a := deg_to_rad(-160)
	var end_a := deg_to_rad(100)
	draw_arc(pos, r, start_a, end_a, 20, Color(1, 1, 1, 0.95), 2.5)

	var end_dir := Vector2(cos(end_a), sin(end_a))
	var tangent := Vector2(-sin(end_a), cos(end_a))  # direction of travel at the arc's leading end
	var normal := Vector2(-tangent.y, tangent.x)
	var arc_end: Vector2 = pos + end_dir * r
	var tip: Vector2 = arc_end + tangent * 4.5
	var back_center: Vector2 = arc_end - tangent * 1.0
	var p1: Vector2 = back_center + normal * 4.0
	var p2: Vector2 = back_center - normal * 4.0
	draw_colored_polygon(PackedVector2Array([tip, p1, p2]), Color(1, 1, 1, 0.95))
