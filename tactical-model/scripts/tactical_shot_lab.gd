extends Control

const RangeViewScript := preload("res://scripts/range_view.gd")
const ShotResolverScript := preload("res://scripts/shot_resolver.gd")
const FormulaConfigLoaderScript := preload("res://scripts/formula_config_loader.gd")
const INTERNAL_FORMULA_CONFIG_PATH := "res://config/formula_config.yaml"
const EXTERNAL_FORMULA_CONFIG_FILE := "formula_config.yaml"
const MOVEMENT_STATES := ["Standing", "Walking", "Running", "Sprinting"]
const MOVEMENT_DIRECTIONS := ["Toward shooter", "Away from shooter", "Sideways", "Zigzag"]
const MOVEMENT_STATE_LABELS := {
	"Standing": "Стоит",
	"Walking": "Идет",
	"Running": "Бежит",
	"Sprinting": "Спринт",
}
const MOVEMENT_DIRECTION_LABELS := {
	"Toward shooter": "На стрелка",
	"Away from shooter": "От стрелка",
	"Sideways": "Поперек",
	"Zigzag": "Зигзаг",
}

var rng := RandomNumberGenerator.new()
var formula_config := {}
var formula_config_modified_time := 0
var formula_config_path := ""
var selected_weapon_id := ""
var selected_target_id := ""
var range_view: Control
var skill_slider: HSlider
var aim_ap_slider: HSlider
var weapon_option: OptionButton
var target_option: OptionButton
var movement_state_option: OptionButton
var movement_direction_option: OptionButton
var result_log: TextEdit


func _ready() -> void:
	rng.randomize()
	_load_formula_config()
	_build_ui()
	_start_formula_config_watcher()
	_update_range()
	_fire_once()


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	range_view = RangeViewScript.new()
	range_view.custom_minimum_size = Vector2(640, 480)
	range_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(range_view)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	root.add_child(panel)

	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	panel.add_child(controls)

	var title := Label.new()
	title.text = "Лаборатория стрельбы"
	title.add_theme_font_size_override("font_size", 28)
	controls.add_child(title)

	skill_slider = _add_slider(controls, "Навык оружия", 0.0, 100.0, 35.0)
	aim_ap_slider = _add_slider(controls, "AP на прицеливание", 1.0, 20.0, 1.0)

	weapon_option = _add_option(controls, "Оружие", [])
	_refresh_weapon_options()

	target_option = _add_option(controls, "Цель", [])
	_refresh_target_options()

	movement_state_option = _add_option(controls, "Движение цели", MOVEMENT_STATES, MOVEMENT_STATE_LABELS)
	movement_direction_option = _add_option(controls, "Направление цели", MOVEMENT_DIRECTIONS, MOVEMENT_DIRECTION_LABELS)
	movement_direction_option.select(2)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	controls.add_child(buttons)

	var fire_button := Button.new()
	fire_button.text = "Выстрел"
	fire_button.pressed.connect(_fire_once)
	buttons.add_child(fire_button)

	var simulate_button := Button.new()
	simulate_button.text = "100 выстрелов"
	simulate_button.pressed.connect(_simulate)
	buttons.add_child(simulate_button)

	result_log = TextEdit.new()
	result_log.editable = false
	result_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	result_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(result_log)

	skill_slider.value_changed.connect(func(_value: float) -> void: _update_range())
	aim_ap_slider.value_changed.connect(func(_value: float) -> void: _update_range())
	weapon_option.item_selected.connect(_on_weapon_selected)
	target_option.item_selected.connect(_on_target_selected)
	movement_state_option.item_selected.connect(func(_index: int) -> void: _update_range())
	movement_direction_option.item_selected.connect(func(_index: int) -> void: _update_range())
	range_view.geometry_changed.connect(_update_range)


func _start_formula_config_watcher() -> void:
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_reload_formula_config_if_changed)
	add_child(timer)
	timer.start()


func _load_formula_config() -> void:
	formula_config_path = _resolve_formula_config_path()
	formula_config = FormulaConfigLoaderScript.load_config(formula_config_path, ShotResolverScript.DEFAULT_CONFIG)
	formula_config_modified_time = FileAccess.get_modified_time(formula_config_path)
	if selected_weapon_id.is_empty():
		selected_weapon_id = ShotResolverScript.get_default_weapon_id(formula_config)
	if selected_target_id.is_empty():
		selected_target_id = ShotResolverScript.get_default_target_id(formula_config)


func _reload_formula_config_if_changed() -> void:
	var resolved_path := _resolve_formula_config_path()
	if resolved_path != formula_config_path:
		formula_config_path = resolved_path
		formula_config_modified_time = 0

	var modified_time := FileAccess.get_modified_time(formula_config_path)
	if modified_time == 0 or modified_time == formula_config_modified_time:
		return

	_load_formula_config()
	_refresh_weapon_options()
	_refresh_target_options()
	_update_range()
	result_log.text = "Конфиг формул перечитан.\n%s\n\nНажми Выстрел или 100 выстрелов, чтобы проверить новые значения." % _config_source_label()


func _resolve_formula_config_path() -> String:
	var executable_dir := OS.get_executable_path().get_base_dir()
	if not executable_dir.is_empty():
		for config_dir in _external_config_dirs(executable_dir):
			var external_path := config_dir.path_join(EXTERNAL_FORMULA_CONFIG_FILE)
			if FileAccess.file_exists(external_path):
				return external_path

	return INTERNAL_FORMULA_CONFIG_PATH


func _external_config_dirs(executable_dir: String) -> Array[String]:
	var dirs: Array[String] = []
	_append_unique_dir(dirs, executable_dir)

	var working_dir := OS.get_environment("PWD")
	if not working_dir.is_empty():
		_append_unique_dir(dirs, working_dir)

	var app_marker := ".app/Contents/MacOS"
	var app_marker_index := executable_dir.find(app_marker)
	if app_marker_index >= 0:
		var app_path := executable_dir.substr(0, app_marker_index + 4)
		_append_unique_dir(dirs, app_path.get_base_dir())

	_append_unique_dir(dirs, executable_dir.path_join("../../..").simplify_path())

	return dirs


func _append_unique_dir(dirs: Array[String], path: String) -> void:
	var normalized := path.simplify_path()
	if normalized.is_empty():
		return
	if not dirs.has(normalized):
		dirs.append(normalized)


func _config_source_label() -> String:
	if formula_config_path == INTERNAL_FORMULA_CONFIG_PATH:
		return "Источник: встроенный конфиг"
	return "Источник: внешний конфиг\n%s" % formula_config_path


func _refresh_weapon_options() -> void:
	if weapon_option == null:
		return

	var previous_weapon_id := selected_weapon_id
	var weapons: Dictionary = formula_config.get("weapons", {})
	if weapons.is_empty():
		weapons = ShotResolverScript.DEFAULT_CONFIG["weapons"]

	weapon_option.clear()
	for weapon_id in weapons.keys():
		var weapon: Dictionary = weapons[weapon_id]
		weapon_option.add_item(String(weapon.get("name", weapon_id)))
		weapon_option.set_item_metadata(weapon_option.item_count - 1, weapon_id)

	var selected_index := 0
	for index in weapon_option.item_count:
		if String(weapon_option.get_item_metadata(index)) == previous_weapon_id:
			selected_index = index
			break

	weapon_option.select(selected_index)
	selected_weapon_id = String(weapon_option.get_item_metadata(selected_index))


func _on_weapon_selected(index: int) -> void:
	selected_weapon_id = String(weapon_option.get_item_metadata(index))
	_update_range()


func _refresh_target_options() -> void:
	if target_option == null:
		return

	var previous_target_id := selected_target_id
	var targets: Dictionary = formula_config.get("targets", {})
	if targets.is_empty():
		targets = ShotResolverScript.DEFAULT_CONFIG["targets"]

	target_option.clear()
	for target_id in targets.keys():
		var target: Dictionary = targets[target_id]
		target_option.add_item(String(target.get("name", target_id)))
		target_option.set_item_metadata(target_option.item_count - 1, target_id)

	var selected_index := 0
	for index in target_option.item_count:
		if String(target_option.get_item_metadata(index)) == previous_target_id:
			selected_index = index
			break

	target_option.select(selected_index)
	selected_target_id = String(target_option.get_item_metadata(selected_index))


func _on_target_selected(index: int) -> void:
	selected_target_id = String(target_option.get_item_metadata(index))
	_update_range()


func _add_slider(parent: VBoxContainer, label_text: String, min_value: float, max_value: float, default_value: float) -> HSlider:
	var label := Label.new()
	label.text = "%s: %.0f" % [label_text, default_value]
	parent.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 1.0
	slider.value = default_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slider)

	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s: %.0f" % [label_text, value]
	)

	return slider


func _add_option(parent: VBoxContainer, label_text: String, values: Array, labels: Dictionary = {}) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)

	var option := OptionButton.new()
	for value in values:
		option.add_item(String(labels.get(value, value)))
		option.set_item_metadata(option.item_count - 1, value)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(option)

	return option


func _update_range() -> void:
	if range_view == null:
		return


func _fire_once() -> void:
	_update_range()
	range_view.show_shot_line = true
	var result: Dictionary = ShotResolverScript.resolve(
		range_view.get_shot_geometry(),
		int(skill_slider.value),
		int(aim_ap_slider.value),
		_selected_text(movement_state_option),
		_selected_text(movement_direction_option),
		selected_weapon_id,
		selected_target_id,
		rng,
		formula_config
	)
	result_log.text = _format_single_result(result)


func _simulate() -> void:
	_update_range()
	range_view.show_shot_line = false
	var stats: Dictionary = ShotResolverScript.simulate(
		range_view.get_shot_geometry(),
		int(skill_slider.value),
		int(aim_ap_slider.value),
		_selected_text(movement_state_option),
		_selected_text(movement_direction_option),
		selected_weapon_id,
		selected_target_id,
		100,
		rng,
		formula_config
	)
	result_log.text = _format_simulation(stats)


func _selected_text(option: OptionButton) -> String:
	var metadata: Variant = option.get_item_metadata(option.selected)
	if metadata != null:
		return String(metadata)
	return option.get_item_text(option.selected)


func _selected_label(option: OptionButton) -> String:
	return option.get_item_text(option.selected)


func _format_single_result(result: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("Результат выстрела")
	lines.append(_config_source_label())
	lines.append("")
	lines.append("Дистанция: %.1f м" % result["distance"])
	lines.append("Азимут: %.0f град." % range_view.get_bearing_degrees())
	lines.append("Оружие: %s" % result["weapon_name"])
	lines.append("Цель: %s" % result["target_name"])
	lines.append("Навык оружия: %d" % int(skill_slider.value))
	lines.append("AP на прицеливание: %d" % int(aim_ap_slider.value))
	lines.append("Движение цели: %s" % _selected_label(movement_state_option))
	lines.append("Направление цели: %s" % _selected_label(movement_direction_option))
	lines.append("")
	lines.append("Шанс попадания: %d%%" % result["hit_chance"])
	lines.append("Бросок попадания: %d" % result["hit_roll"])
	lines.append("Попадание: %s" % ("Да" if result["hit"] else "Нет"))
	lines.append("")
	lines.append("Радиус зоны попадания: %.2f м" % result["target_hit_radius_m"])
	lines.append("Handling: %.2f -> %.2f" % [result["base_handling"], result["effective_handling"]])
	lines.append("Ожидаемое отклонение sigma: %.2f м" % result["miss_sigma_m"])
	lines.append("Суммарная угловая ошибка: %.2f mrad" % result["total_error_mrad"])
	lines.append("")
	lines.append("Бюджет угловой ошибки:")
	for modifier in result["modifiers"]:
		if float(modifier["value"]) == 0.0:
			continue
		lines.append("%s: %.2f %s" % [_modifier_label(modifier["name"]), modifier["value"], modifier["unit"]])
	lines.append("")
	lines.append("Объяснение:")
	lines.append(_explain_result(result))
	return "\n".join(lines)


func _format_simulation(stats: Dictionary) -> String:
	var count := int(stats["count"])
	var average_hit_chance := float(stats["total_hit_chance"]) / float(count)
	var lines := PackedStringArray()
	lines.append("Симуляция: %d выстрелов" % count)
	lines.append(_config_source_label())
	lines.append("")
	lines.append("Дистанция: %.1f м" % range_view.get_distance_meters())
	lines.append("Азимут: %.0f град." % range_view.get_bearing_degrees())
	lines.append("Оружие: %s" % ShotResolverScript.get_weapon(formula_config, selected_weapon_id).get("name", "неизвестно"))
	lines.append("Цель: %s" % ShotResolverScript.get_target(formula_config, selected_target_id).get("name", "неизвестно"))
	lines.append("Навык оружия: %d" % int(skill_slider.value))
	lines.append("AP на прицеливание: %d" % int(aim_ap_slider.value))
	lines.append("Движение цели: %s" % _selected_label(movement_state_option))
	lines.append("Направление цели: %s" % _selected_label(movement_direction_option))
	lines.append("")
	for quality in ["Hit", "Miss"]:
		var percent := int(roundf(float(stats[quality]) / float(count) * 100.0))
		lines.append("%-11s %3d%%" % [_quality_label(quality) + ":", percent])
	lines.append("")
	lines.append("Средний расчетный шанс попадания: %.1f%%" % average_hit_chance)
	return "\n".join(lines)


func _format_quality(quality: String) -> String:
	match quality:
		"PoorHit":
			return "Плохое попадание"
		"NormalHit":
			return "Обычное попадание"
		"GoodHit":
			return "Хорошее попадание"
		"CriticalHit":
			return "Критическое попадание"
		_:
			return quality


func _quality_label(quality: String) -> String:
	match quality:
		"Hit":
			return "Попадания"
		"Miss":
			return "Промахи"
		_:
			return _format_quality(quality)


func _modifier_label(modifier_name: String) -> String:
	match modifier_name:
		"Shooter aim error":
			return "Ошибка стрелка"
		"Weapon mechanical error":
			return "Механическая ошибка оружия"
		"Weapon handling error":
			return "Ошибка handling"
		"Sight alignment error":
			return "Ошибка прицела"
		"Movement tracking error":
			return "Ошибка сопровождения цели"
		_:
			return modifier_name


func _explain_result(result: Dictionary) -> String:
	if not result["hit"]:
		return "Выстрел промахнулся: бросок оказался выше расчетного шанса попадания. Шанс считается из угловой ошибки, дистанции, размера цели и сопровождения движения."

	return "Выстрел попал: бросок оказался в пределах расчетного шанса попадания. Части тела и урон пока намеренно отключены."
