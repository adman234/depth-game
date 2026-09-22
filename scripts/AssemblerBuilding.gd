class_name AssemblerBuilding
extends BuildingBase

const BUILD_TIME := 1.2  # medium
const CRAFT_TIME := 2.0  # 1.5x faster than the original 3.0s
const ADV_CRAFT_TIME := 2.6  # circuitry recipe takes a bit longer, output is worth more
const MAX_SCRAP_BUFFER := 5
const MAX_CIRCUITRY_BUFFER := 5

var output_dir: Vector2i = Vector2i.RIGHT
var scrap_buffer := 0
var circuitry_buffer := 0
var craft_timer := 0.0
var crafting := false
var crafting_advanced := false
var output_ready := ""  # "" | "plate" | "adv_plate"

func _ready() -> void:
	build_time = BUILD_TIME
	queue_redraw()

func try_receive(item: String) -> bool:
	if not is_built or is_deconstructing:
		return false
	if item == "scrap":
		if scrap_buffer >= MAX_SCRAP_BUFFER:
			return false
		scrap_buffer += 1
		queue_redraw()
		return true
	if item == "circuitry":
		if circuitry_buffer >= MAX_CIRCUITRY_BUFFER:
			return false
		circuitry_buffer += 1
		queue_redraw()
		return true
	return false

func _process(delta: float) -> void:
	if not _tick_construction(delta):
		return
	if not _tick_deconstruct(delta):
		return
	if output_ready != "":
		var target_cell: Vector2i = cell + output_dir
		var target: Node = GridManager.get_building(target_cell)
		if target and target.try_receive(output_ready):
			output_ready = ""
			queue_redraw()
		return

	if not crafting:
		# circuitry recipe takes priority when both are queued — it's the
		# scarcer, later-game resource and produces the better ammo
		if circuitry_buffer > 0:
			crafting = true
			crafting_advanced = true
			craft_timer = 0.0
		elif scrap_buffer > 0:
			crafting = true
			crafting_advanced = false
			craft_timer = 0.0

	if crafting:
		craft_timer += delta * GridManager.assembler_speed_mult
		var needed: float = ADV_CRAFT_TIME if crafting_advanced else CRAFT_TIME
		if craft_timer >= needed:
			crafting = false
			if crafting_advanced:
				circuitry_buffer -= 1
				output_ready = "adv_plate"
			else:
				scrap_buffer -= 1
				output_ready = "plate"
			queue_redraw()

func _draw() -> void:
	if not is_built:
		draw_rect(Rect2(-15, -15, 30, 30), Color(0.55, 0.3, 0.7, 0.35))
		draw_line(Vector2.ZERO, Vector2(output_dir) * 15, Color(1, 1, 1, 0.6), 3.0)
		_draw_construction_overlay(15.0)
		return
	if is_deconstructing:
		draw_rect(Rect2(-15, -15, 30, 30), Color(0.55, 0.3, 0.7))
		draw_line(Vector2.ZERO, Vector2(output_dir) * 15, Color.WHITE, 3.0)
		_draw_deconstruct_overlay(15.0)
		return
	draw_rect(Rect2(-15, -15, 30, 30), Color(0.55, 0.3, 0.7))
	draw_line(Vector2.ZERO, Vector2(output_dir) * 15, Color.WHITE, 3.0)
	if output_ready == "adv_plate":
		draw_circle(Vector2(output_dir) * 10, 6.0, Color(0.4, 0.85, 0.9))
	elif output_ready == "plate":
		draw_circle(Vector2(output_dir) * 10, 6.0, Color(0.8, 0.8, 0.85))
	if crafting:
		var needed: float = ADV_CRAFT_TIME if crafting_advanced else CRAFT_TIME
		var pct: float = craft_timer / needed
		var bar_col: Color = Color(0.4, 0.85, 0.9) if crafting_advanced else Color(0.9, 0.7, 0.3)
		draw_rect(Rect2(-12, 18, 24, 4), Color(0.15, 0.15, 0.15, 0.85))
		draw_rect(Rect2(-12, 18, 24 * pct, 4), bar_col)
