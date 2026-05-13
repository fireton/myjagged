class_name RangeView
extends Control

signal geometry_changed

const PIXELS_PER_METER := 100.0
const MIN_ZOOM := 0.025
const MAX_ZOOM := 3.0
const HANDLE_RADIUS := 18.0
const DISTANCE_RINGS := [3, 8, 15, 25, 35, 50, 100]

var shooter_world_position := Vector2(-3.0, 0.0)
var target_world_position := Vector2(5.0, 0.0)
var zoom := 1.0
var pan := Vector2.ZERO

var show_shot_line := false:
	set(value):
		show_shot_line = value
		queue_redraw()

var _dragging := ""
var _panning := false
var _last_mouse_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)


func get_shot_geometry() -> Dictionary:
	var distance := get_distance_meters()
	return {
		"shot_origin": shooter_world_position,
		"target_point": target_world_position,
		"intended_target_distance": distance,
		"raycast_distance": distance,
		"line_of_fire_blocked": false,
	}


func get_distance_meters() -> float:
	return shooter_world_position.distance_to(target_world_position)


func get_bearing_degrees() -> float:
	var delta := target_world_position - shooter_world_position
	return rad_to_deg(atan2(delta.y, delta.x))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _unhandled_input(event: InputEvent) -> void:
	_try_handle_zoom_event(event)


func _input(event: InputEvent) -> void:
	_try_handle_zoom_event(event)


func _try_handle_zoom_event(event: InputEvent) -> void:
	if event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		if _mouse_is_over_field():
			_zoom_at(get_local_mouse_position(), 1.0 - pan_event.delta.y * 0.06)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMagnifyGesture:
		var magnify_event := event as InputEventMagnifyGesture
		if _mouse_is_over_field():
			_zoom_at(get_local_mouse_position(), magnify_event.factor)
			get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return

	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return
	if not mouse_event.pressed:
		return

	if not _mouse_is_over_field():
		return

	var local_position := get_local_mouse_position()
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_at(local_position, 1.12)
	else:
		_zoom_at(local_position, 1.0 / 1.12)

	get_viewport().set_input_as_handled()


func _mouse_is_over_field() -> bool:
	return Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	_last_mouse_position = event.position

	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.12)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / 1.12)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = _pick_handle(event.position)
			if _dragging != "":
				show_shot_line = false
				accept_event()
		else:
			_dragging = ""
	elif event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		_panning = event.pressed
		accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _dragging == "shooter":
		shooter_world_position = _screen_to_world(event.position)
		_emit_geometry_changed()
	elif _dragging == "target":
		target_world_position = _screen_to_world(event.position)
		_emit_geometry_changed()
	elif _panning:
		pan += event.relative
		queue_redraw()

	_last_mouse_position = event.position


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var world_before := _screen_to_world(screen_position)
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	pan = screen_position - size * 0.5 - world_before * PIXELS_PER_METER * zoom
	queue_redraw()


func _emit_geometry_changed() -> void:
	geometry_changed.emit()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.065, 0.075, 0.08), true)
	_draw_grid()
	_draw_distance_rings()
	_draw_crosshair(Vector2.ZERO)

	var shooter := _world_to_screen(shooter_world_position)
	var target := _world_to_screen(target_world_position)

	draw_line(shooter, target, Color(0.9, 0.9, 0.86, 0.24), 1.0, true)

	if show_shot_line:
		draw_line(shooter, target, Color(1.0, 0.74, 0.26), 3.0, true)

	_draw_actor(shooter, Color(0.22, 0.60, 0.96), "S")
	_draw_actor(target, Color(0.95, 0.25, 0.30), "T")
	_draw_hud()


func _draw_grid() -> void:
	var grid_step := _grid_step_meters()
	var top_left: Vector2 = _screen_to_world(Vector2.ZERO)
	var bottom_right: Vector2 = _screen_to_world(size)
	var start_x: int = int(floor(top_left.x / grid_step) * grid_step)
	var end_x: int = int(ceil(bottom_right.x / grid_step) * grid_step)
	var start_y: int = int(floor(top_left.y / grid_step) * grid_step)
	var end_y: int = int(ceil(bottom_right.y / grid_step) * grid_step)

	for meter_x in range(start_x, end_x + 1, grid_step):
		var screen_x := _world_to_screen(Vector2(float(meter_x), 0.0)).x
		var color := Color(1.0, 1.0, 1.0, 0.12 if meter_x == 0 else 0.055)
		draw_line(Vector2(screen_x, 0.0), Vector2(screen_x, size.y), color)

	for meter_y in range(start_y, end_y + 1, grid_step):
		var screen_y := _world_to_screen(Vector2(0.0, float(meter_y))).y
		var color := Color(1.0, 1.0, 1.0, 0.12 if meter_y == 0 else 0.055)
		draw_line(Vector2(0.0, screen_y), Vector2(size.x, screen_y), color)


func _draw_distance_rings() -> void:
	var origin := _world_to_screen(shooter_world_position)
	for meters in DISTANCE_RINGS:
		var radius := float(meters) * PIXELS_PER_METER * zoom
		if radius < 8.0:
			continue
		var ring_color := Color(0.72, 0.82, 0.92, 0.16 if meters in [35, 50, 100] else 0.10)
		draw_arc(origin, radius, 0.0, TAU, 160, ring_color, 2.0, true)
		draw_string(ThemeDB.fallback_font, origin + Vector2(radius + 6.0, -6.0), "%dm" % meters, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13.0, Color(0.72, 0.82, 0.92, 0.62))


func _draw_crosshair(world_position: Vector2) -> void:
	var screen_position := _world_to_screen(world_position)
	draw_line(screen_position + Vector2(-8.0, 0.0), screen_position + Vector2(8.0, 0.0), Color(1.0, 1.0, 1.0, 0.18))
	draw_line(screen_position + Vector2(0.0, -8.0), screen_position + Vector2(0.0, 8.0), Color(1.0, 1.0, 1.0, 0.18))


func _draw_actor(position: Vector2, color: Color, label: String) -> void:
	draw_circle(position, HANDLE_RADIUS, color)
	draw_circle(position, HANDLE_RADIUS + 2.0, Color(1.0, 1.0, 1.0, 0.72), false, 2.0)
	draw_string(ThemeDB.fallback_font, position + Vector2(-5.0, 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16.0, Color(0.04, 0.05, 0.055))


func _draw_hud() -> void:
	var text := "Перетащи S/T | Колесо: масштаб %.0f%% | ПКМ/СКМ: панорама | Дистанция %.1f м" % [zoom * 100.0, get_distance_meters()]
	draw_string(ThemeDB.fallback_font, Vector2(18.0, 28.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16.0, Color(0.88, 0.90, 0.88, 0.9))


func _grid_step_meters() -> int:
	var pixels_per_meter := PIXELS_PER_METER * zoom
	if pixels_per_meter >= 32.0:
		return 1
	if pixels_per_meter >= 12.0:
		return 5
	if pixels_per_meter >= 5.0:
		return 10
	if pixels_per_meter >= 2.0:
		return 25
	return 50


func _pick_handle(screen_position: Vector2) -> String:
	if screen_position.distance_to(_world_to_screen(shooter_world_position)) <= HANDLE_RADIUS + 8.0:
		return "shooter"
	if screen_position.distance_to(_world_to_screen(target_world_position)) <= HANDLE_RADIUS + 8.0:
		return "target"
	return ""


func _world_to_screen(world_position: Vector2) -> Vector2:
	return size * 0.5 + pan + world_position * PIXELS_PER_METER * zoom


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - size * 0.5 - pan) / (PIXELS_PER_METER * zoom)
