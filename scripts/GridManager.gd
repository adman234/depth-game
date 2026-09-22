extends Node

const TILE_SIZE := 32

var buildings: Dictionary = {}       # Vector2i -> Node
var resource_veins: Dictionary = {}  # Vector2i -> String (resource type, e.g. "scrap", "circuitry")

# --- Run state: scrap economy + every stat upgrade cards can touch. Central
# so any building/enemy script can read/modify it without a Main reference. ---
var global_scrap: int = 0

var assembler_speed_mult := 1.0
var build_speed_mult := 1.0
var miner_speed_mult := 1.0
var belt_speed_mult := 1.0

var depot_range_mult := 1.0
var depot_capacity_bonus := 0
var depot_deconstruct_bonus := 0.0     # fraction of a deconstructed depot's OWN reserve refunded to global scrap
var depot_explosion_on_deconstruct := false

var turret_damage_mult := 1.0
var turret_fire_rate_mult := 1.0
var turret_range_mult := 1.0
var turret_double_shot_chance := 0.0
var turret_splash_chance := 0.0
var turret_extra_gun := false

var core_shockwave_on_hit := false
var core_passive_pulse := false
var core_regen_per_sec := 0.0
var core_heal_per_wave := 0

var cost_discount_mult := 1.0
var scrap_per_kill := 0
var miner_double_yield_chance := 0.0
var wave_clear_scrap_bonus := 0
var instant_build_charges := 0

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE * 0.5, cell.y * TILE_SIZE + TILE_SIZE * 0.5)

func get_building(cell: Vector2i) -> Node:
	return buildings.get(cell, null)

func set_building(cell: Vector2i, node: Node) -> void:
	buildings[cell] = node

func remove_building(cell: Vector2i) -> void:
	if buildings.has(cell):
		var node = buildings[cell]
		if is_instance_valid(node):
			node.queue_free()
		buildings.erase(cell)

func has_resource(cell: Vector2i) -> bool:
	return resource_veins.has(cell)

func get_resource_type(cell: Vector2i) -> String:
	return resource_veins.get(cell, "")

func reset() -> void:
	buildings.clear()
	resource_veins.clear()
	global_scrap = 0
	assembler_speed_mult = 1.0
	build_speed_mult = 1.0
	miner_speed_mult = 1.0
	belt_speed_mult = 1.0
	depot_range_mult = 1.0
	depot_capacity_bonus = 0
	depot_deconstruct_bonus = 0.0
	depot_explosion_on_deconstruct = false
	turret_damage_mult = 1.0
	turret_fire_rate_mult = 1.0
	turret_range_mult = 1.0
	turret_double_shot_chance = 0.0
	turret_splash_chance = 0.0
	turret_extra_gun = false
	core_shockwave_on_hit = false
	core_passive_pulse = false
	core_regen_per_sec = 0.0
	core_heal_per_wave = 0
	cost_discount_mult = 1.0
	scrap_per_kill = 0
	miner_double_yield_chance = 0.0
	wave_clear_scrap_bonus = 0
	instant_build_charges = 0
