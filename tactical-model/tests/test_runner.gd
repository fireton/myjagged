extends SceneTree

var _failures := 0
var _checks := 0


func _initialize() -> void:
	print("Running TacticalModel tests...")

	_test_yaml_config_loads_weapons_and_targets()
	_test_yaml_inline_comments_keep_numeric_values()
	_test_aim_ap_improves_carbine_handling()
	_test_carbine_beats_pistol_at_100m_when_aimed()
	_test_bigger_target_is_easier_to_hit()
	_test_distance_reduces_hit_chance()

	if _failures == 0:
		print("All tests passed. Checks: %d" % _checks)
		quit(0)
	else:
		push_error("%d test checks failed. Checks: %d" % [_failures, _checks])
		quit(1)


func _test_yaml_config_loads_weapons_and_targets() -> void:
	var config := _load_config()
	var weapons: Dictionary = config["weapons"]
	var targets: Dictionary = config["targets"]

	_expect(weapons.has("basic_pistol"), "config has basic_pistol")
	_expect(weapons.has("carbine"), "config has carbine")
	_expect(weapons.size() >= 4, "config has several weapons")
	_expect(targets.has("human"), "config has human target")
	_expect(targets.has("elephant"), "config has elephant target")
	_expect(targets.size() >= 4, "config has several target profiles")


func _test_yaml_inline_comments_keep_numeric_values() -> void:
	var parsed := YAMLParser.parse_yaml_string("root:\n  value: 1.25 # inline comment\n  text: \"# not a comment\"\n")
	_expect(parsed["root"]["value"] is float, "inline comment value remains numeric")
	_expect_approx(float(parsed["root"]["value"]), 1.25, 0.0001, "inline comment value parses correctly")
	_expect_equal(String(parsed["root"]["text"]), "# not a comment", "hash inside quotes is preserved")


func _test_aim_ap_improves_carbine_handling() -> void:
	var low_ap := _resolve(100.0, 100, 1, "carbine", "human")
	var high_ap := _resolve(100.0, 100, 20, "carbine", "human")

	_expect(float(high_ap["effective_handling"]) > float(low_ap["effective_handling"]), "aim AP improves effective handling")
	_expect(int(high_ap["hit_chance"]) > int(low_ap["hit_chance"]), "aim AP improves carbine hit chance")
	_expect(float(high_ap["total_error_mrad"]) < float(low_ap["total_error_mrad"]), "aim AP reduces total angular error")


func _test_carbine_beats_pistol_at_100m_when_aimed() -> void:
	var pistol := _resolve(100.0, 100, 20, "basic_pistol", "human")
	var carbine := _resolve(100.0, 100, 20, "carbine", "human")

	_expect(int(carbine["hit_chance"]) > int(pistol["hit_chance"]), "aimed carbine beats aimed pistol at 100m")


func _test_bigger_target_is_easier_to_hit() -> void:
	var human := _resolve(100.0, 50, 5, "carbine", "human")
	var elephant := _resolve(100.0, 50, 5, "carbine", "elephant")

	_expect(int(elephant["hit_chance"]) > int(human["hit_chance"]), "larger target is easier to hit")


func _test_distance_reduces_hit_chance() -> void:
	var at_50 := _resolve(50.0, 100, 10, "carbine", "human")
	var at_100 := _resolve(100.0, 100, 10, "carbine", "human")
	var at_200 := _resolve(200.0, 100, 10, "carbine", "human")

	_expect(int(at_50["hit_chance"]) > int(at_100["hit_chance"]), "50m is easier than 100m")
	_expect(int(at_100["hit_chance"]) > int(at_200["hit_chance"]), "100m is easier than 200m")


func _resolve(distance: float, skill: int, aim_ap: int, weapon_id: String, target_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return ShotResolver.resolve(
		{"intended_target_distance": distance, "line_of_fire_blocked": false},
		skill,
		aim_ap,
		"Standing",
		"Sideways",
		weapon_id,
		target_id,
		rng,
		_load_config()
	)


func _load_config() -> Dictionary:
	return FormulaConfigLoader.load_config("res://config/formula_config.yaml", ShotResolver.DEFAULT_CONFIG)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s. Expected %s, got %s" % [message, str(expected), str(actual)])


func _expect_approx(actual: float, expected: float, tolerance: float, message: String) -> void:
	_expect(absf(actual - expected) <= tolerance, "%s. Expected %.4f, got %.4f" % [message, expected, actual])
