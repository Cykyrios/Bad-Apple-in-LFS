extends VBoxContainer


enum Light {
	HEADLIGHTS,
	FLASH,
	FOG_FRONT,
	FOG_REAR,
	EXTRA,
	INDICATORS_OFF,
	INDICATORS_LEFT,
	INDICATORS_RIGHT,
	INDICATORS_BOTH,
}

const MATRIX_COUNT := 20
const VIDEO_FPS := 30.0
const TEMPO := 138

var insim := InSim.new()

var plids: Array[int]
var video_processor: VideoProcessor = null
var grid: GridContainer = null
var indicator_timer: Timer = null

@onready var video_button: Button = %VideoButton


func _ready() -> void:
	video_processor = VideoProcessor.new()
	add_child(video_processor)
	var _connect := video_button.pressed.connect(_on_video_button_pressed)
	_connect = video_processor.frame_processed.connect(_on_frame_processed)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	for i in MATRIX_COUNT:
		var matrix := preload("res://supermatrix.tscn").instantiate() as Supermatrix
		grid.add_child(matrix)
	indicator_timer = Timer.new()
	_connect = indicator_timer.timeout.connect(_on_indicator_timer_timeout)
	add_child(indicator_timer)

	add_child(insim)
	insim.initialize("127.0.0.1", 29999, InSimInitializationData.new())
	await insim.isp_ver_received
	_connect = insim.isp_reo_received.connect(get_grid)
	insim.send_packet(InSimTinyPacket.new(1, InSim.Tiny.TINY_REO))


func get_grid(reo_packet: InSimREOPacket) -> void:
	plids = reo_packet.plids
	for i in plids.size():
		if plids[i] == 0:
			var _discard := plids.resize(i)
			break


func create_ai_control(input: int, gis_time: float, value: int) -> AIInputVal:
	var ai_input := AIInputVal.new()
	ai_input.input = input
	ai_input.gis_time = gis_time
	ai_input.value = value
	var _discard := ai_input.get_buffer()
	return ai_input


func send_ai_reset(plid: int) -> void:
	var matrix := grid.get_child(plids.find(plid)) as Supermatrix
	matrix.set_all_lights(false)
	send_ai_state(plid, matrix.lights)


func send_ai_state(plid: int, lights: Array[bool]) -> void:
	var hold_time := 1 / VIDEO_FPS + 0.02
	var inputs: Array[AIInputVal] = []
	inputs.append(create_ai_control(InSim.AIControl.CS_FOGREAR, 0, 3 if lights[0] else 2))
	inputs.append(create_ai_control(InSim.AIControl.CS_FOGFRONT, 0, 3 if lights[1] else 2))
	inputs.append(create_ai_control(InSim.AIControl.CS_EXTRALIGHT, 0, 3 if lights[3] else 2))
	if lights[5]:
		inputs.append(create_ai_control(InSim.AIControl.CS_FLASH, hold_time, 1))
	inputs.append(create_ai_control(InSim.AIControl.CS_HEADLIGHTS, 0, 3 if lights[5] else 1))
	var indicators := 4 if lights[2] and lights[4] else 2 if lights[2] else 3 if lights[4] else 1
	inputs.append(create_ai_control(InSim.AIControl.CS_INDICATORS, 0, indicators))
	var packet := InSimAICPacket.new()
	packet.plid = plid
	packet.inputs = inputs
	insim.send_packet(packet)


func _on_frame_processed(lights: Array[bool]) -> void:
	for m in MATRIX_COUNT:
		var plid := plids[m]
		var matrix := grid.get_child(m) as Supermatrix
		matrix.previous_lights = matrix.lights.duplicate()
		var offset := m * Supermatrix.LIGHT_COUNT
		for i in Supermatrix.LIGHT_COUNT:
			matrix.lights[i] = lights[offset + i]
			matrix.queue_redraw()
		send_ai_state(plid, matrix.lights)


func _on_indicator_timer_timeout() -> void:
	for plid in plids:
		var packet := InSimAICPacket.new()
		packet.plid = plid
		packet.inputs.append(create_ai_control(InSim.AIControl.CS_INDICATORS, 0, 1))
		insim.send_packet(packet)


func _on_video_button_pressed() -> void:
	for m in plids.size():
		send_ai_reset(plids[m])
	video_processor.process_video()
	indicator_timer.start(60.0 / TEMPO)
