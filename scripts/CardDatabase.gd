class_name CardDatabase

# Every card maps to one of a small set of real effect hooks on GridManager
# (see Main._apply_card). Many commons share a hook at different magnitudes —
# same approach Balatro/roguelites use so a big, flavorful card pool doesn't
# require a bespoke mechanic per entry. rarity: "common" | "uncommon" | "rare"

const CARDS := [
	# --- COMMON (70) ---
	{"name": "Greased Gears", "desc": "+8% assembler speed", "rarity": "common", "effect": "assembler_speed", "value": 0.08},
	{"name": "Oiled Pistons", "desc": "+8% assembler speed", "rarity": "common", "effect": "assembler_speed", "value": 0.08},
	{"name": "Tighter Tolerances", "desc": "+10% assembler speed", "rarity": "common", "effect": "assembler_speed", "value": 0.10},
	{"name": "Overclocked Assembler", "desc": "+10% assembler speed", "rarity": "common", "effect": "assembler_speed", "value": 0.10},
	{"name": "Scavenged Bearings", "desc": "+12% assembler speed", "rarity": "common", "effect": "assembler_speed", "value": 0.12},
	{"name": "Precision Jig", "desc": "+15% assembler speed", "rarity": "common", "effect": "assembler_speed", "value": 0.15},

	{"name": "Extra Hands", "desc": "+8% building placement speed", "rarity": "common", "effect": "build_speed", "value": 0.08},
	{"name": "Steady Rhythm", "desc": "+8% building placement speed", "rarity": "common", "effect": "build_speed", "value": 0.08},
	{"name": "Prefab Panels", "desc": "+10% building placement speed", "rarity": "common", "effect": "build_speed", "value": 0.10},
	{"name": "Quick-Release Bolts", "desc": "+10% building placement speed", "rarity": "common", "effect": "build_speed", "value": 0.10},
	{"name": "Practiced Crew", "desc": "+12% building placement speed", "rarity": "common", "effect": "build_speed", "value": 0.12},
	{"name": "Blueprint Shortcuts", "desc": "+15% building placement speed", "rarity": "common", "effect": "build_speed", "value": 0.15},

	{"name": "Longer Cables", "desc": "+5% depot supply radius", "rarity": "common", "effect": "depot_range", "value": 0.05},
	{"name": "Signal Booster", "desc": "+5% depot supply radius", "rarity": "common", "effect": "depot_range", "value": 0.05},
	{"name": "Relay Node", "desc": "+8% depot supply radius", "rarity": "common", "effect": "depot_range", "value": 0.08},
	{"name": "Wider Manifest", "desc": "+8% depot supply radius", "rarity": "common", "effect": "depot_range", "value": 0.08},
	{"name": "Extended Ledger", "desc": "+10% depot supply radius", "rarity": "common", "effect": "depot_range", "value": 0.10},
	{"name": "Supply Line Extension", "desc": "+12% depot supply radius", "rarity": "common", "effect": "depot_range", "value": 0.12},

	{"name": "Sharpened Rounds", "desc": "+6% turret damage", "rarity": "common", "effect": "turret_damage", "value": 0.06},
	{"name": "Hotter Powder", "desc": "+6% turret damage", "rarity": "common", "effect": "turret_damage", "value": 0.06},
	{"name": "Hollow Points", "desc": "+8% turret damage", "rarity": "common", "effect": "turret_damage", "value": 0.08},
	{"name": "Tungsten Core Rounds", "desc": "+8% turret damage", "rarity": "common", "effect": "turret_damage", "value": 0.08},
	{"name": "Overpressure Load", "desc": "+10% turret damage", "rarity": "common", "effect": "turret_damage", "value": 0.10},
	{"name": "Armor-Piercing Batch", "desc": "+12% turret damage", "rarity": "common", "effect": "turret_damage", "value": 0.12},

	{"name": "Lighter Bolt Carrier", "desc": "+6% turret fire rate", "rarity": "common", "effect": "turret_fire_rate", "value": 0.06},
	{"name": "Polished Chamber", "desc": "+8% turret fire rate", "rarity": "common", "effect": "turret_fire_rate", "value": 0.08},
	{"name": "Quick-Cycle Spring", "desc": "+8% turret fire rate", "rarity": "common", "effect": "turret_fire_rate", "value": 0.08},
	{"name": "Trigger Job", "desc": "+10% turret fire rate", "rarity": "common", "effect": "turret_fire_rate", "value": 0.10},
	{"name": "Belt-Fed Linkage", "desc": "+10% turret fire rate", "rarity": "common", "effect": "turret_fire_rate", "value": 0.10},
	{"name": "Match-Grade Action", "desc": "+12% turret fire rate", "rarity": "common", "effect": "turret_fire_rate", "value": 0.12},

	{"name": "Scope Upgrade", "desc": "+5% turret range", "rarity": "common", "effect": "turret_range", "value": 0.05},
	{"name": "Barrel Extension", "desc": "+8% turret range", "rarity": "common", "effect": "turret_range", "value": 0.08},
	{"name": "Wind Reading", "desc": "+8% turret range", "rarity": "common", "effect": "turret_range", "value": 0.08},
	{"name": "Elevated Mount", "desc": "+10% turret range", "rarity": "common", "effect": "turret_range", "value": 0.10},
	{"name": "Rangefinder Scrap-Mod", "desc": "+10% turret range", "rarity": "common", "effect": "turret_range", "value": 0.10},
	{"name": "Stabilized Tripod", "desc": "+12% turret range", "rarity": "common", "effect": "turret_range", "value": 0.12},

	{"name": "Sharper Drill Bit", "desc": "+8% mining speed", "rarity": "common", "effect": "miner_speed", "value": 0.08},
	{"name": "Lubricated Auger", "desc": "+8% mining speed", "rarity": "common", "effect": "miner_speed", "value": 0.08},
	{"name": "Vibration Dampener", "desc": "+10% mining speed", "rarity": "common", "effect": "miner_speed", "value": 0.10},
	{"name": "Reinforced Drive Shaft", "desc": "+10% mining speed", "rarity": "common", "effect": "miner_speed", "value": 0.10},
	{"name": "Twin-Stage Drill", "desc": "+12% mining speed", "rarity": "common", "effect": "miner_speed", "value": 0.12},
	{"name": "Overdriven Motor", "desc": "+15% mining speed", "rarity": "common", "effect": "miner_speed", "value": 0.15},

	{"name": "Waxed Rollers", "desc": "+8% belt speed", "rarity": "common", "effect": "belt_speed", "value": 0.08},
	{"name": "Tensioned Belt", "desc": "+8% belt speed", "rarity": "common", "effect": "belt_speed", "value": 0.08},
	{"name": "Ball-Bearing Rollers", "desc": "+10% belt speed", "rarity": "common", "effect": "belt_speed", "value": 0.10},
	{"name": "Low-Friction Coating", "desc": "+12% belt speed", "rarity": "common", "effect": "belt_speed", "value": 0.12},
	{"name": "Servo-Assisted Drive", "desc": "+12% belt speed", "rarity": "common", "effect": "belt_speed", "value": 0.12},
	{"name": "Redlined Conveyor", "desc": "+15% belt speed", "rarity": "common", "effect": "belt_speed", "value": 0.15},

	{"name": "Patch Plating", "desc": "+10 max core HP", "rarity": "common", "effect": "core_max_hp", "value": 10},
	{"name": "Sandbag Perimeter", "desc": "+10 max core HP", "rarity": "common", "effect": "core_max_hp", "value": 10},
	{"name": "Reinforced Bulkhead", "desc": "+15 max core HP", "rarity": "common", "effect": "core_max_hp", "value": 15},
	{"name": "Spall Liner", "desc": "+15 max core HP", "rarity": "common", "effect": "core_max_hp", "value": 15},
	{"name": "Blast Shielding", "desc": "+20 max core HP", "rarity": "common", "effect": "core_max_hp", "value": 20},
	{"name": "Hardened Core Casing", "desc": "+25 max core HP", "rarity": "common", "effect": "core_max_hp", "value": 25},
	{"name": "Redundant Plating", "desc": "+12 max core HP", "rarity": "common", "effect": "core_max_hp", "value": 12},

	{"name": "Cache Found", "desc": "+15 scrap, immediately", "rarity": "common", "effect": "starting_scrap_bonus", "value": 15},
	{"name": "Buried Stockpile", "desc": "+20 scrap, immediately", "rarity": "common", "effect": "starting_scrap_bonus", "value": 20},
	{"name": "Scavenger's Luck", "desc": "+20 scrap, immediately", "rarity": "common", "effect": "starting_scrap_bonus", "value": 20},
	{"name": "Looted Convoy", "desc": "+25 scrap, immediately", "rarity": "common", "effect": "starting_scrap_bonus", "value": 25},
	{"name": "Forgotten Vault", "desc": "+30 scrap, immediately", "rarity": "common", "effect": "starting_scrap_bonus", "value": 30},
	{"name": "Motherlode Tip-Off", "desc": "+30 scrap, immediately", "rarity": "common", "effect": "starting_scrap_bonus", "value": 30},

	{"name": "Extra Shelving", "desc": "+10 depot capacity", "rarity": "common", "effect": "depot_capacity", "value": 10},
	{"name": "Stacked Crates", "desc": "+10 depot capacity", "rarity": "common", "effect": "depot_capacity", "value": 10},
	{"name": "Reinforced Bins", "desc": "+15 depot capacity", "rarity": "common", "effect": "depot_capacity", "value": 15},
	{"name": "Double-Wide Racks", "desc": "+15 depot capacity", "rarity": "common", "effect": "depot_capacity", "value": 15},
	{"name": "Overflow Annex", "desc": "+20 depot capacity", "rarity": "common", "effect": "depot_capacity", "value": 20},

	{"name": "Battlefield Salvage", "desc": "+2 scrap per wave cleared", "rarity": "common", "effect": "wave_clear_scrap_bonus", "value": 2},
	{"name": "Scrap Collection Detail", "desc": "+3 scrap per wave cleared", "rarity": "common", "effect": "wave_clear_scrap_bonus", "value": 3},
	{"name": "Post-Wave Sweep", "desc": "+3 scrap per wave cleared", "rarity": "common", "effect": "wave_clear_scrap_bonus", "value": 3},
	{"name": "Recovery Squad", "desc": "+4 scrap per wave cleared", "rarity": "common", "effect": "wave_clear_scrap_bonus", "value": 4},

	{"name": "Self-Sealing Plating", "desc": "Core regenerates +0.4 HP/sec", "rarity": "common", "effect": "core_regen_per_sec", "value": 0.4},
	{"name": "Patch Kit Rotation", "desc": "Core regenerates +0.4 HP/sec", "rarity": "common", "effect": "core_regen_per_sec", "value": 0.4},
	{"name": "Field Repair Detail", "desc": "Core heals +5 HP per wave cleared", "rarity": "common", "effect": "core_heal_per_wave", "value": 5},
	{"name": "Salvage Repair Crew", "desc": "Core heals +8 HP per wave cleared", "rarity": "common", "effect": "core_heal_per_wave", "value": 8},

	# --- UNCOMMON (25) ---
	{"name": "Salvage Protocol", "desc": "Deconstructing a depot refunds +15% of its stored scrap to the pool", "rarity": "uncommon", "effect": "depot_deconstruct_refund", "value": 0.15},
	{"name": "Efficient Teardown", "desc": "Deconstructing a depot refunds +20% of its stored scrap to the pool", "rarity": "uncommon", "effect": "depot_deconstruct_refund", "value": 0.20},
	{"name": "Waste Not", "desc": "Deconstructing a depot refunds +25% of its stored scrap to the pool", "rarity": "uncommon", "effect": "depot_deconstruct_refund", "value": 0.25},

	{"name": "Twin Feed", "desc": "Turrets: +10% chance to fire twice", "rarity": "uncommon", "effect": "turret_double_shot_chance", "value": 0.10},
	{"name": "Double Tap Rig", "desc": "Turrets: +15% chance to fire twice", "rarity": "uncommon", "effect": "turret_double_shot_chance", "value": 0.15},
	{"name": "Rapid Split-Fire", "desc": "Turrets: +20% chance to fire twice", "rarity": "uncommon", "effect": "turret_double_shot_chance", "value": 0.20},

	{"name": "Fragmentation Rounds", "desc": "Turrets: +20% chance shots splash to a nearby enemy", "rarity": "uncommon", "effect": "turret_splash_chance", "value": 0.20},
	{"name": "Shrapnel Load", "desc": "Turrets: +30% chance shots splash to a nearby enemy", "rarity": "uncommon", "effect": "turret_splash_chance", "value": 0.30},

	{"name": "Rapid Deployment Kit", "desc": "Next 3 buildings placed complete construction instantly", "rarity": "uncommon", "effect": "instant_build_charges", "value": 3},
	{"name": "Prefab Airdrop", "desc": "Next 5 buildings placed complete construction instantly", "rarity": "uncommon", "effect": "instant_build_charges", "value": 5},

	{"name": "Battlefield Scavenging", "desc": "+1 scrap per enemy killed", "rarity": "uncommon", "effect": "scrap_per_kill", "value": 1},
	{"name": "Corpse Stripping Protocol", "desc": "+2 scrap per enemy killed", "rarity": "uncommon", "effect": "scrap_per_kill", "value": 2},

	{"name": "Long-Haul Relay", "desc": "+20% depot supply radius", "rarity": "uncommon", "effect": "depot_range", "value": 0.20},
	{"name": "Overclocked Network", "desc": "+25% depot supply radius", "rarity": "uncommon", "effect": "depot_range", "value": 0.25},

	{"name": "Depleted Uranium Rounds", "desc": "+15% turret damage", "rarity": "uncommon", "effect": "turret_damage", "value": 0.15},
	{"name": "Experimental Payload", "desc": "+20% turret damage", "rarity": "uncommon", "effect": "turret_damage", "value": 0.20},

	{"name": "Assembly Line Overhaul", "desc": "+20% assembler speed", "rarity": "uncommon", "effect": "assembler_speed", "value": 0.20},
	{"name": "Second Shift", "desc": "+25% assembler speed", "rarity": "uncommon", "effect": "assembler_speed", "value": 0.25},

	{"name": "Bunker Retrofit", "desc": "+35 max core HP", "rarity": "uncommon", "effect": "core_max_hp", "value": 35},
	{"name": "Fortress Core", "desc": "+45 max core HP", "rarity": "uncommon", "effect": "core_max_hp", "value": 45},

	{"name": "Warehouse Expansion", "desc": "+30 depot capacity", "rarity": "uncommon", "effect": "depot_capacity", "value": 30},
	{"name": "Mega Racking", "desc": "+40 depot capacity", "rarity": "uncommon", "effect": "depot_capacity", "value": 40},

	{"name": "Long Barrel Conversion", "desc": "+20% turret range", "rarity": "uncommon", "effect": "turret_range", "value": 0.20},

	{"name": "Rich Vein Sense", "desc": "Miners: +15% chance to yield twice as fast", "rarity": "uncommon", "effect": "miner_double_yield_chance", "value": 0.15},
	{"name": "Prospector's Instinct", "desc": "Miners: +20% chance to yield twice as fast", "rarity": "uncommon", "effect": "miner_double_yield_chance", "value": 0.20},

	{"name": "Nanite Repair Swarm", "desc": "Core regenerates +1.0 HP/sec", "rarity": "uncommon", "effect": "core_regen_per_sec", "value": 1.0},
	{"name": "Automated Repair Bay", "desc": "Core heals +15 HP per wave cleared", "rarity": "uncommon", "effect": "core_heal_per_wave", "value": 15},

	# --- RARE (5) ---
	{"name": "Depot Detonator", "desc": "Deconstructing a depot triggers an explosion that damages nearby enemies", "rarity": "rare", "effect": "depot_explosion_on_deconstruct", "value": true},
	{"name": "Core Backlash", "desc": "The core taking damage releases a shockwave that damages nearby enemies", "rarity": "rare", "effect": "core_shockwave_on_hit", "value": true},
	{"name": "Twin Barrel Mount", "desc": "Turrets gain a second barrel and always fire twice", "rarity": "rare", "effect": "turret_extra_gun", "value": true},
	{"name": "Black Market Contact", "desc": "All building costs reduced by 25%", "rarity": "rare", "effect": "cost_discount_mult", "value": 0.75},
	{"name": "Core Overcharge", "desc": "The core periodically pulses, damaging nearby enemies on its own", "rarity": "rare", "effect": "core_passive_pulse", "value": true},
]

static func by_rarity(rarity: String) -> Array:
	var result: Array = []
	for c in CARDS:
		if c.rarity == rarity:
			result.append(c)
	return result

# Mostly common, occasional uncommon, rare chance. Commons can repeat across
# draws (many are just flavored reskins of the same handful of stat hooks
# anyway); once an uncommon or rare has been taken this run, it's excluded —
# pass its name in `excluded_names`.
static func draw_three(excluded_names: Dictionary = {}) -> Array:
	var pool_common: Array = by_rarity("common")
	var pool_uncommon: Array = _without(by_rarity("uncommon"), excluded_names)
	var pool_rare: Array = _without(by_rarity("rare"), excluded_names)
	var picks: Array = []
	var used_names: Dictionary = {}
	var guard := 0
	while picks.size() < 3 and guard < 60:
		guard += 1
		var roll := randf()
		var pool: Array = pool_common
		if roll < 0.05 and not pool_rare.is_empty():
			pool = pool_rare
		elif roll < 0.30 and not pool_uncommon.is_empty():
			pool = pool_uncommon
		if pool.is_empty():
			pool = pool_common
		var card: Dictionary = pool[randi() % pool.size()]
		if used_names.has(card.name):
			continue
		used_names[card.name] = true
		picks.append(card)
	return picks

static func _without(pool: Array, excluded_names: Dictionary) -> Array:
	if excluded_names.is_empty():
		return pool
	return pool.filter(func(c): return not excluded_names.has(c.name))
