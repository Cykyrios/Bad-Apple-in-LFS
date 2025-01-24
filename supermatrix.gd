class_name Supermatrix
extends HBoxContainer


const LIGHT_COUNT := 7

var light_radius := 10
var light_margin := 2
var lights: Array[bool] = []


func _init() -> void:
	var _discard := lights.resize(LIGHT_COUNT)
	lights.fill(false)
	custom_minimum_size = 2 * Vector2(
		LIGHT_COUNT * (light_radius + light_margin),
		light_radius + light_margin
	)


func _draw() -> void:
	var half_size := light_radius + light_margin
	for i in lights.size():
		draw_circle(Vector2((i * 2 + 1) * half_size, half_size),
				light_radius, Color.WHITE if lights[i] else Color.BLACK, true, -1.0, true)


func set_all_lights(status: bool) -> void:
	for i in lights.size():
		lights[i] = status
	queue_redraw()


func update_light(index: int, status: bool) -> void:
	if index >= LIGHT_COUNT:
		return
	lights[index] = status
	queue_redraw()
