class_name ShotResolver
extends RefCounted

const DEFAULT_CONFIG := {
	"default_target": "human",
	"targets": {
		"human": {
			"name": "Human target",
			"hit_radius_m": 0.30,
		},
	},
	"shooter": {
		"min_aim_error_mrad": 2.0,
		"max_aim_error_mrad": 18.0,
		"skill_curve_power": 0.65,
		"aim_error_reduction_per_ap": 0.025,
		"aim_error_reduction_skill_scaling": 0.50,
		"movement_tracking_compensation": 0.75,
	},
	"default_weapon": "basic_pistol",
	"weapons": {
		"basic_pistol": {
			"name": "Basic pistol",
				"mechanical_accuracy_mrad": 6.0,
				"handling": 0.80,
				"handling_error_max_mrad": 10.0,
				"aim_handling_gain_per_ap": 0.015,
				"aim_skill_scaling": 0.30,
				"sight_alignment_error_mrad": 4.0,
		},
	},
	"movement": {
		"tracking_error_mrad_per_mps": 6.0,
		"speeds_mps": {
			"Standing": 0.0,
			"Walking": 1.4,
			"Running": 3.5,
			"Sprinting": 5.5,
		},
		"direction_modifiers": {
			"Toward shooter": 0.35,
			"Away from shooter": 0.50,
			"Sideways": 1.00,
			"Zigzag": 1.45,
		},
	},
	"random": {
		"minimum_hit_chance": 1.0,
		"maximum_hit_chance": 99.0,
		"blocked_line_hit_chance": 0.0,
	},
}


static func resolve(shot_geometry: Dictionary, pistol_skill: int, aim_ap: int, movement_state: String, movement_direction: String, weapon_id: String, target_id: String, rng: RandomNumberGenerator, config: Dictionary = {}) -> Dictionary:
	var active_config := DEFAULT_CONFIG if config.is_empty() else config
	var target := get_target(active_config, target_id)
	var shooter: Dictionary = active_config["shooter"]
	var weapon := get_weapon(active_config, weapon_id)
	var random: Dictionary = active_config["random"]

	var distance := maxf(float(shot_geometry.get("intended_target_distance", 1.0)), 0.1)
	var line_of_fire_blocked := bool(shot_geometry.get("line_of_fire_blocked", false))
	var skill_factor := clampf(float(pistol_skill) / 100.0, 0.0, 1.0)

	var shooter_error_mrad := _shooter_error_mrad(shooter, skill_factor, aim_ap)
	var mechanical_error_mrad := float(weapon["mechanical_accuracy_mrad"])
	var effective_handling := _effective_handling(weapon, skill_factor, aim_ap)
	var handling_error_mrad := _handling_error_mrad(weapon, skill_factor, effective_handling)
	var sight_error_mrad := float(weapon["sight_alignment_error_mrad"])
	var movement_error_mrad := _movement_error_mrad(movement_state, movement_direction, skill_factor, active_config)

	var total_error_mrad := sqrt(
		shooter_error_mrad * shooter_error_mrad
		+ mechanical_error_mrad * mechanical_error_mrad
		+ handling_error_mrad * handling_error_mrad
		+ sight_error_mrad * sight_error_mrad
		+ movement_error_mrad * movement_error_mrad
	)

	var miss_sigma_m := maxf(distance * total_error_mrad / 1000.0, 0.001)
	var hit_radius_m := float(target["hit_radius_m"])
	var hit_chance := _hit_chance_from_error(hit_radius_m, miss_sigma_m)

	if line_of_fire_blocked:
		hit_chance = float(random["blocked_line_hit_chance"])

	hit_chance = clampf(hit_chance, float(random["minimum_hit_chance"]), float(random["maximum_hit_chance"]))

	var hit_roll := rng.randi_range(1, 100)
	var hit := hit_roll <= int(roundf(hit_chance))

	return {
		"hit": hit,
		"quality": "Hit" if hit else "Miss",
		"distance": distance,
		"line_of_fire_blocked": line_of_fire_blocked,
		"hit_chance": int(roundf(hit_chance)),
		"hit_roll": hit_roll,
		"weapon_id": weapon_id,
		"weapon_name": weapon["name"],
		"aim_ap": aim_ap,
		"base_handling": float(weapon["handling"]),
		"effective_handling": effective_handling,
		"target_id": target_id,
		"target_name": target["name"],
		"total_error_mrad": total_error_mrad,
		"miss_sigma_m": miss_sigma_m,
		"target_hit_radius_m": hit_radius_m,
		"modifiers": [
			{"name": "Shooter aim error", "value": shooter_error_mrad, "unit": "mrad"},
			{"name": "Weapon mechanical error", "value": mechanical_error_mrad, "unit": "mrad"},
			{"name": "Weapon handling error", "value": handling_error_mrad, "unit": "mrad"},
			{"name": "Sight alignment error", "value": sight_error_mrad, "unit": "mrad"},
			{"name": "Movement tracking error", "value": movement_error_mrad, "unit": "mrad"},
		],
	}


static func simulate(shot_geometry: Dictionary, pistol_skill: int, aim_ap: int, movement_state: String, movement_direction: String, weapon_id: String, target_id: String, count: int, rng: RandomNumberGenerator, config: Dictionary = {}) -> Dictionary:
	var stats := {
		"Hit": 0,
		"Miss": 0,
		"total_hit_chance": 0.0,
		"count": count,
	}

	for i in count:
		var result := resolve(shot_geometry, pistol_skill, aim_ap, movement_state, movement_direction, weapon_id, target_id, rng, config)
		stats[result["quality"]] += 1
		stats["total_hit_chance"] += float(result["hit_chance"])

	return stats


static func get_weapon(config: Dictionary, weapon_id: String) -> Dictionary:
	var active_config := DEFAULT_CONFIG if config.is_empty() else config
	var weapons: Dictionary = active_config["weapons"]
	if weapons.has(weapon_id):
		return weapons[weapon_id]

	var default_weapon_id := String(active_config.get("default_weapon", "basic_pistol"))
	if weapons.has(default_weapon_id):
		return weapons[default_weapon_id]

	return weapons[weapons.keys()[0]]


static func get_default_weapon_id(config: Dictionary) -> String:
	var active_config := DEFAULT_CONFIG if config.is_empty() else config
	return String(active_config.get("default_weapon", "basic_pistol"))


static func get_target(config: Dictionary, target_id: String) -> Dictionary:
	var active_config := DEFAULT_CONFIG if config.is_empty() else config
	var targets: Dictionary = active_config["targets"]
	if targets.has(target_id):
		return targets[target_id]

	var default_target_id := String(active_config.get("default_target", "human"))
	if targets.has(default_target_id):
		return targets[default_target_id]

	return targets[targets.keys()[0]]


static func get_default_target_id(config: Dictionary) -> String:
	var active_config := DEFAULT_CONFIG if config.is_empty() else config
	return String(active_config.get("default_target", "human"))


static func _shooter_error_mrad(shooter: Dictionary, skill_factor: float, aim_ap: int) -> float:
	var curved_skill := pow(skill_factor, float(shooter.get("skill_curve_power", 1.0)))
	var base_error := lerpf(float(shooter["max_aim_error_mrad"]), float(shooter["min_aim_error_mrad"]), curved_skill)
	var aim_reduction_per_ap := float(shooter.get("aim_error_reduction_per_ap", 0.0))
	var aim_skill_scaling := float(shooter.get("aim_error_reduction_skill_scaling", 0.0))
	var aim_multiplier := 1.0 + skill_factor * aim_skill_scaling
	var reduction := clampf(1.0 - maxf(0.0, float(aim_ap)) * aim_reduction_per_ap * aim_multiplier, 0.35, 1.0)
	return maxf(float(shooter["min_aim_error_mrad"]), base_error * reduction)


static func _effective_handling(weapon: Dictionary, skill_factor: float, aim_ap: int) -> float:
	var base_handling := clampf(float(weapon["handling"]), 0.0, 1.0)
	var gain_per_ap := float(weapon.get("aim_handling_gain_per_ap", 0.0))
	var skill_scaling := float(weapon.get("aim_skill_scaling", 0.0))
	var skill_multiplier := 1.0 + skill_factor * skill_scaling
	var raw_gain := maxf(0.0, float(aim_ap)) * gain_per_ap * skill_multiplier
	return clampf(base_handling + raw_gain, 0.0, 1.0)


static func _handling_error_mrad(weapon: Dictionary, skill_factor: float, effective_handling: float) -> float:
	var max_error := float(weapon["handling_error_max_mrad"])
	var skill_reduction := lerpf(1.0, 0.45, skill_factor)
	return (1.0 - effective_handling) * max_error * skill_reduction


static func _movement_error_mrad(movement_state: String, movement_direction: String, skill_factor: float, config: Dictionary) -> float:
	var movement: Dictionary = config["movement"]
	var speeds: Dictionary = movement["speeds_mps"]
	var directions: Dictionary = movement["direction_modifiers"]
	var shooter: Dictionary = config["shooter"]

	var target_speed := float(speeds.get(movement_state, 0.0))
	var direction_modifier := float(directions.get(movement_direction, 1.0))
	var compensation := 1.0 - skill_factor * float(shooter["movement_tracking_compensation"])
	return target_speed * direction_modifier * float(movement["tracking_error_mrad_per_mps"]) * compensation


static func _hit_chance_from_error(hit_radius_m: float, miss_sigma_m: float) -> float:
	var radius_ratio := hit_radius_m / miss_sigma_m
	return (1.0 - exp(-0.5 * radius_ratio * radius_ratio)) * 100.0
