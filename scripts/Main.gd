extends Node2D

const TILE := 32
const MAP_W := 44
const MAP_H := 30
const CAMERA_MARGIN := 1.08
const UI_BAR_HEIGHT := 155.0

enum Tool { MINER, BELT, ASSEMBLER, TURRET, DEPOT }
const TOOL_NAMES := ["Miner", "Belt", "Assembler", "Turret", "Depot"]
const TOOL_NONE := -1

const BUILD_COSTS := {
	Tool.MINER: 5,
	Tool.BELT: 1,
	Tool.ASSEMBLER: 8,
	Tool.TURRET: 8,
	Tool.DEPOT: 15,
}
const STARTING_SCRAP := 160
const FLOOR_START_SCRAP := STARTING_SCRAP  # same as run-start: a new floor needs to be just as buildable as floor 1
const BASE_WAVE_CLEAR_SCRAP := 5  # baseline reward per wave, before any card bonuses
const PASSIVE_SCRAP_INTERVAL := 5.0  # +1 scrap every this many seconds, always

const CAMERA_MIN_ZOOM := 0.4
const CAMERA_ZOOM_STEP := 1.3

const WAVES_PER_LAYER := 6
const CHECKPOINT_EVERY := 5  # layers between Finish Run / push-on checkpoints

var current_tool: int = Tool.BELT
var current_dir: Vector2i = Vector2i.RIGHT

var world_node: Node2D
var grid_view: GridView
var core: Core
var spawner: EnemySpawner
var ghost: GhostPreview
var camera: Camera2D
var camera_max_zoom: float = 3.0
var panning := false
var pan_anchor_world: Vector2
var last_funding_depots: Array = []
var scrap_label_highlighted := false

# left-click drag placement (belts re-face along the drag; miners/assemblers/
# turrets keep whatever facing was selected and just repeat it along the path)
var dragging_place := false
var drag_tool: int = Tool.BELT
var drag_last_cell: Vector2i
var last_placed_belt: Belt

# right-click drag removal
var dragging_remove := false
var remove_last_cell: Vector2i

# Only one building constructs at a time, in the order placed. Everyone else
# waiting in line sits at 0% until the one ahead of them finishes.
var construction_queue: Array = []

var passive_scrap_timer := 0.0

var current_layer := 1
var current_planet := 1
var total_depth := 1  # never resets on planet travel; used for difficulty scaling
var layer_transition_active := false
var collected_upgrades: Array = []
var taken_uncommon_rare: Dictionary = {}
var game_started := false

var hud: CanvasLayer
var hp_label: Label
var tool_label: Label
var time_label: Label
var scrap_label: Label
var setup_label: Label
var layer_label: Label
var skip_button: Button
var tool_buttons: Array = []
var pause_label: Label
var game_over := false
var is_paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	GridManager.reset()
	GridManager.global_scrap = STARTING_SCRAP

	world_node = Node2D.new()
	# Main is PROCESS_MODE_ALWAYS so ESC/HUD still work while paused. Without
	# resetting world_node explicitly, everything under it (enemies, belts,
	# turrets...) would inherit ALWAYS too and keep simulating during pause.
	world_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world_node)

	grid_view = GridView.new()
	grid_view.map_w = MAP_W
	grid_view.map_h = MAP_H
	world_node.add_child(grid_view)

	var item_layer := ItemLayer.new()
	world_node.add_child(item_layer)

	_setup_resource_veins()
	_setup_core_and_spawner()
	_setup_camera()
	_setup_hud()
	_setup_debug_panel()

	ghost = GhostPreview.new()
	world_node.add_child(ghost)

	_show_main_menu()

func _setup_camera() -> void:
	# fit the whole map into the area BELOW the UI bar, not the full window,
	# so the reserved HUD strip doesn't eat into map visibility
	camera = Camera2D.new()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var world_size := Vector2(MAP_W * TILE, MAP_H * TILE)
	var available_height: float = viewport_size.y - UI_BAR_HEIGHT
	var zoom: float = max(world_size.x / viewport_size.x, world_size.y / available_height) * CAMERA_MARGIN
	camera.zoom = Vector2(zoom, zoom)
	camera_max_zoom = zoom * 1.8  # allow zooming out a bit further than the default fit

	var map_center: Vector2 = GridManager.cell_to_world(Vector2i(MAP_W / 2, MAP_H / 2))
	var viewport_center: Vector2 = viewport_size / 2.0
	var desired_screen_center := Vector2(viewport_center.x, UI_BAR_HEIGHT + available_height / 2.0)
	var screen_delta: Vector2 = desired_screen_center - viewport_center
	camera.position = map_center - screen_delta * zoom

	world_node.add_child(camera)
	camera.make_current()

func _zoom_camera(factor: float) -> void:
	var old_zoom: float = camera.zoom.x
	var new_zoom: float = clamp(old_zoom * factor, CAMERA_MIN_ZOOM, camera_max_zoom)
	if is_equal_approx(new_zoom, old_zoom):
		return
	# Use Godot's own (camera-aware) mouse-to-world conversion before and
	# after changing zoom, and shift the camera by the difference — robust
	# regardless of stretch mode/DPI/rounding.
	var world_before: Vector2 = world_node.get_local_mouse_position()
	camera.zoom = Vector2(new_zoom, new_zoom)
	var world_after: Vector2 = world_node.get_local_mouse_position()
	camera.position += world_before - world_after

func _setup_resource_veins() -> void:
	GridManager.resource_veins.clear()
	for c in _random_vein_centers(5):
		_stamp_vein(c, "scrap")
	if total_depth >= 2:
		for c in _random_vein_centers(2):
			_stamp_vein(c, "circuitry")

func _random_vein_centers(count: int) -> Array:
	var centers: Array = []
	for i in range(count):
		centers.append(Vector2i(randi_range(3, MAP_W - 4), randi_range(3, MAP_H - 4)))
	return centers

func _stamp_vein(center: Vector2i, resource_type: String) -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cell: Vector2i = center + Vector2i(dx, dy)
			if cell.x >= 0 and cell.y >= 0 and cell.x < MAP_W and cell.y < MAP_H:
				GridManager.resource_veins[cell] = resource_type

# Clearing a layer moves you to fresh ground: a new resource layout, and your
# physical base (buildings) doesn't come with you — you keep your carried
# scrap pool and every Run Upgrade, same as the design brief's Planet Travel
# framing, just applied every layer rather than only at a planet hop.
func _generate_new_layer_map() -> void:
	for building in GridManager.buildings.values():
		if is_instance_valid(building):
			building.queue_free()
	GridManager.buildings.clear()
	construction_queue.clear()
	last_funding_depots.clear()
	# demolishing buildings for the move is NOT a deconstruct — nothing gets
	# refunded (whatever scrap was invested or stored in a depot is just
	# gone) — so top up a fresh working pool every floor, otherwise a run
	# that spent everything building out floor 1 arrives at floor 2 broke.
	GridManager.global_scrap += FLOOR_START_SCRAP
	_setup_resource_veins()
	if grid_view:
		grid_view.queue_redraw()

func _setup_core_and_spawner() -> void:
	core = Core.new()
	world_node.add_child(core)
	core.position = GridManager.cell_to_world(Vector2i(MAP_W / 2, MAP_H / 2))
	core.died.connect(_on_core_died)

	spawner = EnemySpawner.new()
	spawner.core = core
	var edge_points: Array = []
	for x in range(MAP_W):
		edge_points.append(GridManager.cell_to_world(Vector2i(x, 0)))
		edge_points.append(GridManager.cell_to_world(Vector2i(x, MAP_H - 1)))
	for y in range(MAP_H):
		edge_points.append(GridManager.cell_to_world(Vector2i(0, y)))
		edge_points.append(GridManager.cell_to_world(Vector2i(MAP_W - 1, y)))
	spawner.spawn_points = edge_points
	spawner.wave_cleared.connect(_on_wave_cleared)
	world_node.add_child(spawner)

func _setup_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var viewport_w: float = get_viewport().get_visible_rect().size.x

	# opaque backing bar so the HUD reads as its own panel, not text
	# floating over the map
	var ui_panel := ColorRect.new()
	ui_panel.color = Color(0.07, 0.06, 0.05, 0.97)
	ui_panel.position = Vector2.ZERO
	ui_panel.size = Vector2(viewport_w, UI_BAR_HEIGHT)
	hud.add_child(ui_panel)

	var ui_border := ColorRect.new()
	ui_border.color = Color(0.35, 0.3, 0.2, 0.9)
	ui_border.position = Vector2(0, UI_BAR_HEIGHT - 2.0)
	ui_border.size = Vector2(viewport_w, 2.0)
	hud.add_child(ui_border)

	hp_label = Label.new()
	hp_label.position = Vector2(12, 8)
	hp_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(hp_label)

	tool_label = Label.new()
	tool_label.position = Vector2(12, 34)
	tool_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(tool_label)

	var button_row := HBoxContainer.new()
	button_row.position = Vector2(12, 62)
	button_row.add_theme_constant_override("separation", 6)
	hud.add_child(button_row)

	var tool_group := ButtonGroup.new()
	var labels := ["1 Miner", "2 Belt", "3 Assembler", "4 Turret", "5 Depot"]
	for i in range(labels.size()):
		var btn := Button.new()
		btn.text = labels[i]
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE  # keep keyboard shortcuts (Space etc.) from being swallowed by a focused button
		btn.button_group = tool_group
		btn.custom_minimum_size = Vector2(112, 32)
		btn.pressed.connect(_select_tool.bind(i))
		button_row.add_child(btn)
		tool_buttons.append(btn)

	var help := Label.new()
	help.position = Vector2(12, 100)
	help.text = "Q clear cursor   R/Shift+R rotate   Click/drag place   Right-click/drag remove   Scroll zoom   Middle-drag pan"
	help.add_theme_font_size_override("font_size", 13)
	help.modulate = Color(0.75, 0.75, 0.7)
	hud.add_child(help)

	var right_x: float = viewport_w - 220

	layer_label = Label.new()
	layer_label.position = Vector2(right_x, 8)
	layer_label.add_theme_font_size_override("font_size", 18)
	layer_label.modulate = Color(0.7, 0.85, 0.95)
	hud.add_child(layer_label)

	scrap_label = Label.new()
	scrap_label.position = Vector2(right_x, 34)
	scrap_label.add_theme_font_size_override("font_size", 18)
	scrap_label.modulate = Color(0.75, 0.72, 0.6)
	hud.add_child(scrap_label)

	time_label = Label.new()
	time_label.position = Vector2(right_x, 60)
	time_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(time_label)

	setup_label = Label.new()
	setup_label.position = Vector2(right_x, 86)
	setup_label.add_theme_font_size_override("font_size", 18)
	setup_label.modulate = Color(0.9, 0.85, 0.4)
	hud.add_child(setup_label)

	skip_button = Button.new()
	skip_button.text = "Skip Setup (Space)"
	skip_button.custom_minimum_size = Vector2(150, 32)
	skip_button.position = Vector2(right_x, 114)
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.pressed.connect(_on_skip_pressed)
	hud.add_child(skip_button)

	pause_label = Label.new()
	pause_label.text = "PAUSED — Esc to resume"
	pause_label.add_theme_font_size_override("font_size", 30)
	pause_label.position = Vector2(viewport_w / 2.0 - 160, UI_BAR_HEIGHT + 250)
	pause_label.visible = false
	hud.add_child(pause_label)

	_sync_tool_buttons()
	_update_hud()

func _select_tool(tool: int) -> void:
	current_tool = tool
	_sync_tool_buttons()

func _sync_tool_buttons() -> void:
	for i in range(tool_buttons.size()):
		tool_buttons[i].button_pressed = (i == current_tool)

func _update_hud() -> void:
	hp_label.text = "Core HP: %d / %d" % [int(core.hp), int(core.max_hp)]
	if current_tool == TOOL_NONE:
		tool_label.text = "Tool: None"
	else:
		var cost: int = _current_placement_cost(current_tool, _mouse_cell())
		var cost_str: String = "free" if cost <= 0 else "%d scrap" % cost
		tool_label.text = "Tool: %s   (facing %s)   Cost: %s" % [_tool_name(current_tool), _dir_name(current_dir), cost_str]
	var t: float = spawner.elapsed
	time_label.text = "Elapsed: %02d:%02d" % [int(t / 60), int(t) % 60]
	scrap_label.text = "Scrap Pool: %d" % GridManager.global_scrap
	layer_label.text = "Planet %d — Layer %d" % [current_planet, current_layer]

	if spawner.setup_active:
		setup_label.text = "Setup: %02ds" % [int(ceil(spawner.setup_remaining))]
	elif spawner.enemies_to_spawn > 0:
		setup_label.text = "Wave %d — spawning (%d)" % [spawner.wave_number, spawner.enemies_to_spawn]
	elif spawner.enemies_alive() > 0:
		setup_label.text = "Wave %d — %d left" % [spawner.wave_number, spawner.enemies_alive()]
	else:
		setup_label.text = "Wave %d — next in %02ds" % [spawner.wave_number, int(ceil(spawner.wave_countdown))]
	setup_label.visible = true
	# Deliberately never actually .disabled the button — a disabled Button
	# silently swallows clicks, which is a real risk if this flag were ever
	# wrong. Fade it instead so it reads as inactive without any chance of
	# blocking a legitimate press.
	if spawner.setup_active:
		skip_button.text = "Skip Setup (Space)"
		skip_button.modulate = Color(1, 1, 1, 1)
	else:
		skip_button.text = "Setup Complete"
		skip_button.modulate = Color(1, 1, 1, 0.35)

func _tool_name(t: int) -> String:
	if t == TOOL_NONE:
		return "None"
	return TOOL_NAMES[t]

func _dir_name(dir: Vector2i) -> String:
	if dir == Vector2i.RIGHT:
		return "Right"
	if dir == Vector2i.LEFT:
		return "Left"
	if dir == Vector2i.UP:
		return "Up"
	if dir == Vector2i.DOWN:
		return "Down"
	return str(dir)

func _process(delta: float) -> void:
	if not game_started or is_paused or game_over:
		return
	_update_hud()
	if not layer_transition_active:
		_update_ghost()
		_tick_passive_scrap(delta)

func _tick_passive_scrap(delta: float) -> void:
	passive_scrap_timer += delta
	if passive_scrap_timer >= PASSIVE_SCRAP_INTERVAL:
		passive_scrap_timer -= PASSIVE_SCRAP_INTERVAL
		GridManager.global_scrap += 1

func _toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_label.visible = is_paused

func _update_ghost() -> void:
	if current_tool == TOOL_NONE:
		ghost.visible = false
		_clear_funding_highlight()
		return
	var cell: Vector2i = _mouse_cell()
	if not _in_bounds(cell):
		ghost.visible = false
		_clear_funding_highlight()
		return
	ghost.visible = true
	ghost.position = GridManager.cell_to_world(cell)
	var existing: Node = GridManager.get_building(cell)
	var redirecting: bool = existing != null and _tool_for_building(existing) == current_tool
	ghost.set_state(current_tool, current_dir, _is_valid_placement(current_tool, cell), redirecting)
	_update_funding_highlight(cell, current_tool)

# While a build tool is selected, show WHERE its cost would come from: every
# depot that would contribute to funding it lights up, or — if it'd draw from
# the one-time global stash instead — the scrap counter in the corner does.
func _update_funding_highlight(cell: Vector2i, tool: int) -> void:
	var cost: int = _current_placement_cost(tool, cell)
	var contributing: Array = _depots_covering_cost(cell, cost)

	for d in last_funding_depots:
		if is_instance_valid(d) and not contributing.has(d):
			d.highlighted = false
			d.queue_redraw()
	for d in contributing:
		d.highlighted = true
		d.queue_redraw()
	last_funding_depots = contributing

	scrap_label_highlighted = cost > 0 and contributing.is_empty()
	_apply_scrap_highlight()

func _clear_funding_highlight() -> void:
	for d in last_funding_depots:
		if is_instance_valid(d):
			d.highlighted = false
			d.queue_redraw()
	last_funding_depots = []
	scrap_label_highlighted = false
	_apply_scrap_highlight()

func _apply_scrap_highlight() -> void:
	scrap_label.modulate = Color(1.0, 0.9, 0.3) if scrap_label_highlighted else Color(0.75, 0.72, 0.6)

# Belt-over-belt and any same-type-over-same-type redirect are free re-lays,
# not a new build — reflect that in the cost preview instead of always
# showing the flat build cost.
func _current_placement_cost(tool: int, cell: Vector2i) -> int:
	var existing: Node = GridManager.get_building(cell)
	if existing != null and _tool_for_building(existing) == tool:
		return 0
	return int(round(BUILD_COSTS.get(tool, 0) * GridManager.cost_discount_mult))

func _mouse_cell() -> Vector2i:
	return GridManager.world_to_cell(world_node.get_local_mouse_position())

func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_W and cell.y < MAP_H

func _is_valid_placement(tool: int, cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return false
	if cell == GridManager.world_to_cell(core.position):
		return false
	var existing: Node = GridManager.get_building(cell)
	if existing != null:
		# an identical building already here can always be re-faced in place, for free
		if _tool_for_building(existing) == tool:
			return true
		return false
	if tool == Tool.MINER and not GridManager.has_resource(cell):
		return false
	return _can_afford(cell, tool)

# Construction funding can combine multiple in-range depots (nearest first)
# to cover the cost — e.g. two depots holding 5 each can jointly fund a
# 10-cost build — falling back to the one-time global stash if depots
# in range don't have enough between them.
func _depots_in_range(cell: Vector2i) -> Array:
	var cell_world: Vector2 = GridManager.cell_to_world(cell)
	var depots: Array = []
	for building in GridManager.buildings.values():
		if building is Depot and building.is_built and building.reserve > 0:
			if cell_world.distance_to(building.position) <= building.effective_range_px():
				depots.append(building)
	depots.sort_custom(func(a, b): return cell_world.distance_to(a.position) < cell_world.distance_to(b.position))
	return depots

# Returns the (nearest-first) subset of in-range depots whose combined
# reserve covers cost, or [] if depots in range can't cover it at all.
func _depots_covering_cost(cell: Vector2i, cost: int) -> Array:
	if cost <= 0:
		return []
	var depots: Array = _depots_in_range(cell)
	var contributing: Array = []
	var total := 0
	for d in depots:
		if total >= cost:
			break
		contributing.append(d)
		total += d.reserve
	if total < cost:
		return []
	return contributing

func _can_afford(cell: Vector2i, tool: int) -> bool:
	var cost: int = int(round(BUILD_COSTS.get(tool, 0) * GridManager.cost_discount_mult))
	if cost <= 0:
		return true
	if not _depots_covering_cost(cell, cost).is_empty():
		return true
	return GridManager.global_scrap >= cost

func _spend(cell: Vector2i, tool: int) -> void:
	var cost: int = int(round(BUILD_COSTS.get(tool, 0) * GridManager.cost_discount_mult))
	if cost <= 0:
		return
	var depots: Array = _depots_covering_cost(cell, cost)
	if not depots.is_empty():
		var remaining: int = cost
		for d in depots:
			if remaining <= 0:
				break
			var take: int = min(d.reserve, remaining)
			d.reserve -= take
			remaining -= take
			d.queue_redraw()
		return
	GridManager.global_scrap -= cost

func _unhandled_input(event: InputEvent) -> void:
	if not game_started:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if not game_over and not layer_transition_active:
			_toggle_pause()
		return

	if is_paused or game_over:
		return
	if layer_transition_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_select_tool(Tool.MINER)
			KEY_2:
				_select_tool(Tool.BELT)
			KEY_3:
				_select_tool(Tool.ASSEMBLER)
			KEY_4:
				_select_tool(Tool.TURRET)
			KEY_5:
				_select_tool(Tool.DEPOT)
			KEY_Q:
				current_tool = TOOL_NONE
				_sync_tool_buttons()
			KEY_R:
				if event.shift_pressed:
					current_dir = Vector2i(current_dir.y, -current_dir.x)  # rotate left
				else:
					current_dir = Vector2i(-current_dir.y, current_dir.x)  # rotate right
			KEY_SPACE:
				if spawner.setup_active:
					spawner.skip_setup()
		if dragging_place:
			_end_drag_place()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_tool != TOOL_NONE:
				_start_drag_place()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if dragging_place:
				_end_drag_place()
			_start_remove_drag()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = true
			pan_anchor_world = world_node.get_local_mouse_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0 / CAMERA_ZOOM_STEP)
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and dragging_place:
			_end_drag_place()
		elif event.button_index == MOUSE_BUTTON_RIGHT and dragging_remove:
			dragging_remove = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = false

	if event is InputEventMouseMotion:
		if panning:
			# Keep the world point that was under the cursor when the drag
			# started glued to the cursor, using Godot's own camera-aware
			# mouse-to-world conversion — self-correcting every event, so it
			# can't drift or depend on zoom (unlike accumulating raw deltas).
			var current_world: Vector2 = world_node.get_local_mouse_position()
			camera.position += pan_anchor_world - current_world
		if dragging_place:
			_continue_drag_place()
		if dragging_remove:
			_continue_remove_drag()

func _place_belt_at(cell: Vector2i, dir: Vector2i) -> Belt:
	if not _is_valid_placement(Tool.BELT, cell):
		return null
	var existing: Node = GridManager.get_building(cell)
	if existing != null and existing is Belt:
		# identical tile already here — just re-lay its direction in place,
		# no cost, no rebuild, no lost progress
		existing.direction = dir
		existing.queue_redraw()
		return existing

	_spend(cell, Tool.BELT)
	var b := Belt.new()
	b.direction = dir
	b.cell = cell
	world_node.add_child(b)
	b.position = GridManager.cell_to_world(cell)
	GridManager.set_building(cell, b)
	_enqueue_construction(b)
	return b

func _place_fixed_at(tool: int, cell: Vector2i, dir: Vector2i) -> void:
	var existing: Node = GridManager.get_building(cell)
	if existing != null and _tool_for_building(existing) == tool:
		# identical building already here — re-face in place, free, no rebuild
		if existing is Miner:
			existing.facing = dir
		elif existing is AssemblerBuilding:
			existing.output_dir = dir
		existing.queue_redraw()
		return

	if not _is_valid_placement(tool, cell):
		return
	var building: BuildingBase
	match tool:
		Tool.MINER:
			var m := Miner.new()
			m.facing = dir
			building = m
		Tool.ASSEMBLER:
			var a := AssemblerBuilding.new()
			a.output_dir = dir
			building = a
		Tool.TURRET:
			building = TurretBuilding.new()
		Tool.DEPOT:
			building = Depot.new()
		_:
			return
	_spend(cell, tool)
	building.cell = cell
	world_node.add_child(building)
	building.position = GridManager.cell_to_world(cell)
	GridManager.set_building(cell, building)
	_enqueue_construction(building)

# Only the head of the queue actually progresses; everything behind it sits
# at 0% until its turn, in the order things were placed.
func _enqueue_construction(building: BuildingBase) -> void:
	construction_queue.append(building)
	building.construction_finished.connect(_on_construction_progressed, CONNECT_ONE_SHOT)
	_refresh_construction_queue()

func _on_construction_progressed() -> void:
	_refresh_construction_queue()

func _refresh_construction_queue() -> void:
	construction_queue = construction_queue.filter(func(b): return is_instance_valid(b) and not b.is_built)
	for i in range(construction_queue.size()):
		construction_queue[i].construction_active = (i == 0)

func _start_drag_place() -> void:
	var cell: Vector2i = _mouse_cell()
	if not _in_bounds(cell):
		return
	dragging_place = true
	drag_tool = current_tool
	drag_last_cell = cell
	if drag_tool == Tool.BELT:
		last_placed_belt = _place_belt_at(cell, current_dir)
	else:
		_place_fixed_at(drag_tool, cell, current_dir)

func _continue_drag_place() -> void:
	var target_cell: Vector2i = _mouse_cell()
	if not _in_bounds(target_cell):
		return
	var guard := 0
	while drag_last_cell != target_cell and guard < 64:
		guard += 1
		var next_cell: Vector2i = _next_step(drag_last_cell, target_cell)
		if next_cell == drag_last_cell:
			break

		if drag_tool == Tool.BELT:
			var step_dir: Vector2i = next_cell - drag_last_cell
			current_dir = step_dir  # facing follows the drag direction for belts
			var existing: Node = GridManager.get_building(next_cell)
			if existing != null and not (existing is Belt):
				break
			if last_placed_belt and is_instance_valid(last_placed_belt):
				last_placed_belt.direction = step_dir
				last_placed_belt.queue_redraw()
			var b: Belt = _place_belt_at(next_cell, step_dir)
			if b == null:
				break
			last_placed_belt = b
		else:
			# miners/assemblers/turrets: keep the fixed facing, skip occupied/invalid cells
			_place_fixed_at(drag_tool, next_cell, current_dir)

		drag_last_cell = next_cell

func _next_step(a: Vector2i, b: Vector2i) -> Vector2i:
	var d: Vector2i = b - a
	if abs(d.x) >= abs(d.y) and d.x != 0:
		return a + Vector2i(sign(d.x), 0)
	elif d.y != 0:
		return a + Vector2i(0, sign(d.y))
	return a

func _end_drag_place() -> void:
	dragging_place = false
	last_placed_belt = null

func _start_remove_drag() -> void:
	var cell: Vector2i = _mouse_cell()
	if not _in_bounds(cell):
		return
	dragging_remove = true
	remove_last_cell = cell
	_try_deconstruct(cell)

func _continue_remove_drag() -> void:
	var target_cell: Vector2i = _mouse_cell()
	if not _in_bounds(target_cell):
		return
	var guard := 0
	while remove_last_cell != target_cell and guard < 64:
		guard += 1
		var next_cell: Vector2i = _next_step(remove_last_cell, target_cell)
		if next_cell == remove_last_cell:
			break
		_try_deconstruct(next_cell)
		remove_last_cell = next_cell

# Cancelling a building still under construction is instant and fully
# refunded (nothing was ever "used up"). A completed building instead starts
# a deconstruct timer (half its build time) and only refunds once that
# finishes, so tearing down a base takes real time, same as building one.
func _try_deconstruct(cell: Vector2i) -> void:
	var building: Node = GridManager.get_building(cell)
	if building == null or not (building is BuildingBase):
		return
	var b: BuildingBase = building
	if b.is_deconstructing:
		return
	var tool: int = _tool_for_building(b)
	if not b.is_built:
		_refund(cell, BUILD_COSTS.get(tool, 0), b)
		GridManager.buildings.erase(cell)
		construction_queue.erase(b)
		b.queue_free()
		_refresh_construction_queue()
		return
	b.start_deconstruct()
	b.deconstruct_finished.connect(_on_building_deconstructed.bind(cell, b), CONNECT_ONE_SHOT)

func _on_building_deconstructed(cell: Vector2i, building: Node) -> void:
	_refund(cell, BUILD_COSTS.get(_tool_for_building(building), 0), building)
	if building is Depot:
		if GridManager.depot_deconstruct_bonus > 0.0:
			GridManager.global_scrap += int(building.reserve * GridManager.depot_deconstruct_bonus)
		if GridManager.depot_explosion_on_deconstruct:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(building.position) <= 120.0:
					e.take_damage(40.0)
	if GridManager.get_building(cell) == building:
		GridManager.buildings.erase(cell)
	building.queue_free()

# Deconstructing pays back to the nearest depot (capped by its remaining
# capacity), never to the global stash — scrap beyond that capacity, or with
# no depot at all on the map, is simply lost.
func _refund(cell: Vector2i, cost: int, exclude: Node) -> void:
	if cost <= 0:
		return
	var depot: Depot = _nearest_depot(cell, exclude)
	if depot == null:
		return
	var space: int = Depot.MAX_RESERVE + GridManager.depot_capacity_bonus - depot.reserve
	depot.reserve += min(cost, space)
	depot.queue_redraw()

func _nearest_depot(cell: Vector2i, exclude: Node) -> Depot:
	var cell_world: Vector2 = GridManager.cell_to_world(cell)
	var best: Depot = null
	var best_dist := INF
	for building in GridManager.buildings.values():
		if building is Depot and building.is_built and building != exclude:
			var d: Depot = building
			var dist: float = cell_world.distance_to(d.position)
			if dist < best_dist:
				best_dist = dist
				best = d
	return best

func _tool_for_building(building: Node) -> int:
	if building is Miner:
		return Tool.MINER
	if building is Belt:
		return Tool.BELT
	if building is AssemblerBuilding:
		return Tool.ASSEMBLER
	if building is TurretBuilding:
		return Tool.TURRET
	if building is Depot:
		return Tool.DEPOT
	return -1

func _on_wave_cleared(w: int) -> void:
	GridManager.global_scrap += BASE_WAVE_CLEAR_SCRAP + GridManager.wave_clear_scrap_bonus
	if GridManager.core_heal_per_wave > 0:
		core.hp = min(core.max_hp, core.hp + GridManager.core_heal_per_wave)
	if w % WAVES_PER_LAYER == 0:
		_start_layer_transition()

func _start_layer_transition() -> void:
	layer_transition_active = true
	spawner.paused = true
	ghost.visible = false
	_clear_funding_highlight()
	# _unhandled_input stops running the moment layer_transition_active is
	# true, which means a button-release event (e.g. releasing middle-mouse
	# mid-pan right as this fires) would otherwise never arrive to clear
	# these — leaving them stuck on once the menu closes.
	panning = false
	dragging_place = false
	dragging_remove = false
	get_tree().paused = true
	if current_layer % CHECKPOINT_EVERY == 0:
		_show_checkpoint_screen()
	else:
		_show_map_choice_screen()

func _end_layer_transition() -> void:
	layer_transition_active = false
	spawner.paused = false
	spawner.current_layer = total_depth
	# a fresh floor needs the same build-before-the-storm grace period as the
	# very first one — without this, waves could resume mid-cadence before
	# there's been any chance to rebuild on the new terrain
	spawner.setup_active = true
	spawner.setup_remaining = EnemySpawner.SETUP_TIME
	get_tree().paused = is_paused  # respect a manual ESC-pause that was already active

# --- Map choice: an FTL-style node pick, kept intentionally lightweight for
# now (see design brief — the real branching planet-select map is future
# work). Each option is an immediate, clearly-labeled placeholder effect. ---
func _show_map_choice_screen() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel := _make_modal_panel(viewport_size)

	var title := Label.new()
	title.text = "LAYER %d CLEARED — choose the route down" % current_layer
	title.add_theme_font_size_override("font_size", 26)
	title.position = Vector2(viewport_size.x / 2.0 - 260, UI_BAR_HEIGHT + 40)
	panel.add_child(title)

	var routes := [
		{"name": "Resource Route", "desc": "A scrap-rich stretch of tunnel.\n+25 scrap, immediately.", "apply": func(): GridManager.global_scrap += 25},
		{"name": "Fortified Route", "desc": "Pre-collapse defenses, salvageable.\n+15 depot capacity.", "apply": func(): GridManager.depot_capacity_bonus += 15},
		{"name": "Hazard Route", "desc": "Riskier ground, better haul.\nNext layer's card choice is guaranteed uncommon+.", "apply": func(): _guarantee_rare_next = true},
	]
	var card_w := 260.0
	var start_x: float = viewport_size.x / 2.0 - (card_w * 3 + 40) / 2.0
	for i in range(routes.size()):
		var route: Dictionary = routes[i]
		var box := _make_option_box(Vector2(start_x + i * (card_w + 20), UI_BAR_HEIGHT + 110), card_w, route.name, route.desc, Color(0.3, 0.5, 0.85))
		panel.add_child(box)
		var btn := Button.new()
		btn.text = "Take This Route"
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(card_w, 40)
		btn.position = Vector2(start_x + i * (card_w + 20), UI_BAR_HEIGHT + 300)
		btn.pressed.connect(_on_route_chosen.bind(panel, route.apply))
		panel.add_child(btn)

func _on_route_chosen(panel: Control, apply: Callable) -> void:
	apply.call()
	panel.queue_free()
	_show_card_choice_screen()

# --- Card choice: pick 1 of 3 upgrades, drawn from CardDatabase ---
var _guarantee_rare_next := false
var _traveling_to_new_planet := false

func _show_card_choice_screen() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel := _make_modal_panel(viewport_size)

	var title := Label.new()
	title.text = "CHOOSE AN UPGRADE"
	title.add_theme_font_size_override("font_size", 26)
	title.position = Vector2(viewport_size.x / 2.0 - 160, UI_BAR_HEIGHT + 40)
	panel.add_child(title)

	var cards: Array = CardDatabase.draw_three(taken_uncommon_rare)
	if _guarantee_rare_next and cards.size() > 0:
		_guarantee_rare_next = false
		var boosted: Array = (CardDatabase.by_rarity("uncommon") + CardDatabase.by_rarity("rare")).filter(func(c): return not taken_uncommon_rare.has(c.name))
		if not boosted.is_empty():
			cards[0] = boosted[randi() % boosted.size()]

	var card_w := 260.0
	var start_x: float = viewport_size.x / 2.0 - (card_w * 3 + 40) / 2.0
	var rarity_color := {"common": Color(0.7, 0.7, 0.7), "uncommon": Color(0.35, 0.75, 0.95), "rare": Color(0.95, 0.75, 0.3)}
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var col: Color = rarity_color.get(card.rarity, Color.WHITE)
		var box := _make_option_box(Vector2(start_x + i * (card_w + 20), UI_BAR_HEIGHT + 110), card_w, card.name, card.desc, col)
		var rarity_tag := Label.new()
		rarity_tag.text = card.rarity.to_upper()
		rarity_tag.modulate = col
		rarity_tag.add_theme_font_size_override("font_size", 12)
		rarity_tag.position = Vector2(10, 6)
		box.add_child(rarity_tag)
		panel.add_child(box)
		var btn := Button.new()
		btn.text = "Take Upgrade"
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(card_w, 40)
		btn.position = Vector2(start_x + i * (card_w + 20), UI_BAR_HEIGHT + 300)
		btn.pressed.connect(_on_card_chosen.bind(panel, card))
		panel.add_child(btn)

func _on_card_chosen(panel: Control, card: Dictionary) -> void:
	_apply_card(card)
	panel.queue_free()
	total_depth += 1
	if _traveling_to_new_planet:
		_traveling_to_new_planet = false
		current_planet += 1
		current_layer = 1
	else:
		current_layer += 1
	_generate_new_layer_map()
	_end_layer_transition()

func _apply_card(card: Dictionary) -> void:
	var v = card.value
	match card.effect:
		"assembler_speed":
			GridManager.assembler_speed_mult *= (1.0 + v)
		"build_speed":
			GridManager.build_speed_mult *= (1.0 + v)
		"depot_range":
			GridManager.depot_range_mult *= (1.0 + v)
		"turret_damage":
			GridManager.turret_damage_mult *= (1.0 + v)
		"turret_fire_rate":
			GridManager.turret_fire_rate_mult *= (1.0 + v)
		"turret_range":
			GridManager.turret_range_mult *= (1.0 + v)
		"miner_speed":
			GridManager.miner_speed_mult *= (1.0 + v)
		"belt_speed":
			GridManager.belt_speed_mult *= (1.0 + v)
		"core_max_hp":
			core.max_hp += float(v)
			core.hp += float(v)
		"starting_scrap_bonus":
			GridManager.global_scrap += int(v)
		"depot_capacity":
			GridManager.depot_capacity_bonus += int(v)
		"wave_clear_scrap_bonus":
			GridManager.wave_clear_scrap_bonus += int(v)
		"depot_deconstruct_refund":
			GridManager.depot_deconstruct_bonus += v
		"turret_double_shot_chance":
			GridManager.turret_double_shot_chance += v
		"turret_splash_chance":
			GridManager.turret_splash_chance += v
		"instant_build_charges":
			GridManager.instant_build_charges += int(v)
		"scrap_per_kill":
			GridManager.scrap_per_kill += int(v)
		"miner_double_yield_chance":
			GridManager.miner_double_yield_chance += v
		"depot_explosion_on_deconstruct":
			GridManager.depot_explosion_on_deconstruct = true
		"core_shockwave_on_hit":
			GridManager.core_shockwave_on_hit = true
		"turret_extra_gun":
			GridManager.turret_extra_gun = true
		"cost_discount_mult":
			GridManager.cost_discount_mult *= v
		"core_passive_pulse":
			GridManager.core_passive_pulse = true
		"core_regen_per_sec":
			GridManager.core_regen_per_sec += v
		"core_heal_per_wave":
			GridManager.core_heal_per_wave += int(v)
	collected_upgrades.append(card.name)
	if card.rarity != "common":
		taken_uncommon_rare[card.name] = true


# --- Checkpoint (every CHECKPOINT_EVERY layers): Finish Run banks a clean
# win; Continue pushes on like any other layer transition, at higher risk. ---
func _show_checkpoint_screen() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel := _make_modal_panel(viewport_size)

	var title := Label.new()
	title.text = "CHECKPOINT — LAYER %d CLEARED" % current_layer
	title.add_theme_font_size_override("font_size", 28)
	title.position = Vector2(viewport_size.x / 2.0 - 220, UI_BAR_HEIGHT + 60)
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "Bank the win, or push on and risk it for rarer rewards."
	sub.modulate = Color(0.8, 0.8, 0.78)
	sub.position = Vector2(viewport_size.x / 2.0 - 220, UI_BAR_HEIGHT + 100)
	panel.add_child(sub)

	var finish_btn := Button.new()
	finish_btn.text = "Finish Run (bank the win)"
	finish_btn.focus_mode = Control.FOCUS_NONE
	finish_btn.custom_minimum_size = Vector2(260, 60)
	finish_btn.position = Vector2(viewport_size.x / 2.0 - 280, UI_BAR_HEIGHT + 170)
	finish_btn.add_theme_font_size_override("font_size", 18)
	finish_btn.pressed.connect(_on_finish_run.bind(panel))
	panel.add_child(finish_btn)

	var push_btn := Button.new()
	push_btn.text = "Push On (higher risk)"
	push_btn.focus_mode = Control.FOCUS_NONE
	push_btn.custom_minimum_size = Vector2(260, 60)
	push_btn.position = Vector2(viewport_size.x / 2.0 + 20, UI_BAR_HEIGHT + 170)
	push_btn.add_theme_font_size_override("font_size", 18)
	push_btn.pressed.connect(_on_push_on.bind(panel))
	panel.add_child(push_btn)

func _on_finish_run(panel: Control) -> void:
	panel.queue_free()
	game_over = true
	spawner.paused = true
	get_tree().paused = true
	_show_run_summary("RUN COMPLETE — LAYER %d BANKED" % current_layer, Color(0.3, 0.55, 0.25, 0.28))

func _on_push_on(panel: Control) -> void:
	panel.queue_free()
	_traveling_to_new_planet = true
	_show_card_choice_screen()

func _show_run_summary(headline: String, tint: Color) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var tint_rect := ColorRect.new()
	tint_rect.color = tint
	tint_rect.size = viewport_size
	tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tint_rect)

	var go := Label.new()
	go.text = "%s\nSurvived %02d:%02d — %d upgrades collected" % [headline, int(spawner.elapsed / 60), int(spawner.elapsed) % 60, collected_upgrades.size()]
	go.add_theme_font_size_override("font_size", 26)
	go.position = Vector2(220, 280)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(go)

	var restart_btn := Button.new()
	restart_btn.text = "Restart"
	restart_btn.focus_mode = Control.FOCUS_NONE
	restart_btn.custom_minimum_size = Vector2(240, 70)
	restart_btn.position = Vector2(viewport_size.x / 2.0 - 120, 400)
	restart_btn.add_theme_font_size_override("font_size", 32)
	restart_btn.pressed.connect(_on_restart_pressed)
	hud.add_child(restart_btn)

# --- shared modal helpers ---
func _make_modal_panel(viewport_size: Vector2) -> Control:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	var backing := ColorRect.new()
	backing.color = Color(0.03, 0.03, 0.03, 0.88)
	backing.size = viewport_size
	backing.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(backing)
	return panel

# Manually pre-wrapping into real newlines sidesteps Godot's Label autowrap
# entirely (which turned out unreliable outside a Container — clip_text was
# fighting it last attempt) — this always renders correctly regardless.
func _wrap_text(text: String, max_chars: int) -> String:
	var out_lines: Array = []
	for paragraph in text.split("\n"):
		var current_line := ""
		for word in paragraph.split(" "):
			var candidate: String = word if current_line == "" else current_line + " " + word
			if candidate.length() > max_chars and current_line != "":
				out_lines.append(current_line)
				current_line = word
			else:
				current_line = candidate
		out_lines.append(current_line)
	return "\n".join(out_lines)

func _make_option_box(pos: Vector2, w: float, title_text: String, desc_text: String, accent: Color) -> Control:
	var box := Panel.new()
	box.position = pos
	box.custom_minimum_size = Vector2(w, 170)
	box.size = Vector2(w, 170)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.11, 0.95)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	box.add_theme_stylebox_override("panel", style)

	var name_label := Label.new()
	name_label.text = _wrap_text(title_text, 22)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.position = Vector2(10, 30)
	name_label.size = Vector2(w - 20, 40)
	box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = _wrap_text(desc_text, 34)
	desc_label.modulate = Color(0.8, 0.8, 0.78)
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.position = Vector2(10, 75)
	desc_label.size = Vector2(w - 20, 90)
	box.add_child(desc_label)

	return box

func _on_skip_pressed() -> void:
	spawner.skip_setup()

func _on_core_died() -> void:
	game_over = true
	spawner.paused = true
	get_tree().paused = true  # freeze the whole sim so nothing can hit the core again
	_update_hud()  # one last refresh so the HP line shows the true final (0) value
	_show_run_summary("BASE FALLS — RUN OVER (Layer %d)" % current_layer, Color(0.6, 0.05, 0.05, 0.28))

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

# --- Debug/testing controls — not part of the real game UI ---
func _setup_debug_panel() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var row := HBoxContainer.new()
	row.position = Vector2(12, viewport_size.y - 36)
	row.add_theme_constant_override("separation", 6)
	hud.add_child(row)

	var label := Label.new()
	label.text = "DEBUG:"
	label.modulate = Color(0.95, 0.35, 0.35)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var speed_btn := Button.new()
	speed_btn.text = "1x Speed"
	speed_btn.focus_mode = Control.FOCUS_NONE
	speed_btn.custom_minimum_size = Vector2(90, 28)
	speed_btn.pressed.connect(_on_debug_speed_toggle.bind(speed_btn))
	row.add_child(speed_btn)

	var scrap_btn := Button.new()
	scrap_btn.text = "+100 Scrap"
	scrap_btn.focus_mode = Control.FOCUS_NONE
	scrap_btn.custom_minimum_size = Vector2(100, 28)
	scrap_btn.pressed.connect(func(): GridManager.global_scrap += 100)
	row.add_child(scrap_btn)

	var kill_btn := Button.new()
	kill_btn.text = "Kill All Enemies"
	kill_btn.focus_mode = Control.FOCUS_NONE
	kill_btn.custom_minimum_size = Vector2(130, 28)
	kill_btn.pressed.connect(_on_debug_kill_all)
	row.add_child(kill_btn)

	var wave_btn := Button.new()
	wave_btn.text = "Force Next Wave"
	wave_btn.focus_mode = Control.FOCUS_NONE
	wave_btn.custom_minimum_size = Vector2(130, 28)
	wave_btn.pressed.connect(func(): spawner.wave_countdown = 0.0)
	row.add_child(wave_btn)

const DEBUG_SPEED_STEPS := [1.0, 2.0, 4.0, 8.0]
var debug_speed_index := 0

func _on_debug_speed_toggle(btn: Button) -> void:
	debug_speed_index = (debug_speed_index + 1) % DEBUG_SPEED_STEPS.size()
	Engine.time_scale = DEBUG_SPEED_STEPS[debug_speed_index]
	btn.text = "%dx Speed" % int(Engine.time_scale)

func _on_debug_kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()

# --- Main menu ---
func _show_main_menu() -> void:
	get_tree().paused = true
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var menu := _make_modal_panel(viewport_size)

	var title := Label.new()
	title.text = "DEPTH"
	title.add_theme_font_size_override("font_size", 52)
	title.position = Vector2(viewport_size.x / 2.0 - 100, viewport_size.y / 2.0 - 180)
	menu.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "roguelike factory descent — Phase 0/1 prototype"
	subtitle.modulate = Color(0.75, 0.75, 0.72)
	subtitle.position = Vector2(viewport_size.x / 2.0 - 150, viewport_size.y / 2.0 - 120)
	menu.add_child(subtitle)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.focus_mode = Control.FOCUS_NONE
	play_btn.custom_minimum_size = Vector2(220, 50)
	play_btn.position = Vector2(viewport_size.x / 2.0 - 110, viewport_size.y / 2.0 - 40)
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.pressed.connect(_on_play_pressed.bind(menu))
	menu.add_child(play_btn)

	var unlocks_btn := Button.new()
	unlocks_btn.text = "View Unlocks"
	unlocks_btn.focus_mode = Control.FOCUS_NONE
	unlocks_btn.custom_minimum_size = Vector2(220, 50)
	unlocks_btn.position = Vector2(viewport_size.x / 2.0 - 110, viewport_size.y / 2.0 + 30)
	unlocks_btn.add_theme_font_size_override("font_size", 20)
	unlocks_btn.pressed.connect(_show_unlocks_screen)
	menu.add_child(unlocks_btn)

func _on_play_pressed(menu: Control) -> void:
	menu.queue_free()
	game_started = true
	get_tree().paused = false

func _show_unlocks_screen() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel := _make_modal_panel(viewport_size)

	var title := Label.new()
	title.text = "UNLOCKS — Card Catalog"
	title.add_theme_font_size_override("font_size", 26)
	title.position = Vector2(viewport_size.x / 2.0 - 160, 24)
	panel.add_child(title)

	var note := Label.new()
	note.text = "\"Picked\" reflects the current run only — there's no cross-run save yet."
	note.modulate = Color(0.7, 0.7, 0.68)
	note.add_theme_font_size_override("font_size", 12)
	note.position = Vector2(viewport_size.x / 2.0 - 220, 56)
	panel.add_child(note)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(viewport_size.x / 2.0 - 300, 90)
	scroll.size = Vector2(600, viewport_size.y - 150)
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(580, 0)
	scroll.add_child(list)

	var rarity_color := {"rare": Color(0.95, 0.75, 0.3), "uncommon": Color(0.35, 0.75, 0.95), "common": Color(0.7, 0.7, 0.7)}
	for rarity in ["rare", "uncommon", "common"]:
		var header := Label.new()
		header.text = "%s (%d)" % [rarity.to_upper(), CardDatabase.by_rarity(rarity).size()]
		header.add_theme_font_size_override("font_size", 18)
		header.modulate = rarity_color[rarity]
		list.add_child(header)
		for card in CardDatabase.by_rarity(rarity):
			var picked: bool = collected_upgrades.has(card.name)
			var row := Label.new()
			row.text = "%s — %s%s" % [card.name, card.desc, "   [PICKED]" if picked else ""]
			row.modulate = Color(0.55, 0.9, 0.55) if picked else Color(0.75, 0.75, 0.72)
			row.add_theme_font_size_override("font_size", 13)
			list.add_child(row)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.position = Vector2(viewport_size.x / 2.0 - 60, viewport_size.y - 50)
	back_btn.pressed.connect(panel.queue_free)
	panel.add_child(back_btn)
