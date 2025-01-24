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


func send_ai_control(plid: int, input: InSim.AIControl, value: int) -> void:
	var packet := InSimAICPacket.new()
	packet.plid = plid
	packet.input = input
	packet.value = value
	insim.send_packet(packet)


func send_ai_reset(plid: int) -> void:
	var matrix := grid.get_child(plids.find(plid)) as Supermatrix
	matrix.set_all_lights(false)
	send_ai_state(plid, matrix.lights, matrix.previous_lights)


func send_ai_state(plid: int, lights: Array[bool], previous_lights: Array[bool]) -> void:
	if lights[0] != previous_lights[0]:
		send_ai_control(plid, InSim.AIControl.CS_FOGREAR, 1)
	if lights[1] != previous_lights[1]:
		send_ai_control(plid, InSim.AIControl.CS_FOGFRONT, 1)
	if lights[3] != previous_lights[3]:
		send_ai_control(plid, InSim.AIControl.CS_EXTRALIGHT, 1)
	if lights[5] != previous_lights[5]:
		send_ai_control(plid, InSim.AIControl.CS_FLASH, 1 if lights[5] else 0)
	if lights[6] != previous_lights[6]:
		send_ai_control(plid, InSim.AIControl.CS_HEADLIGHTS, 3 if lights[6] else 1)
	send_ai_control(plid, InSim.AIControl.CS_INDICATORS,
			4 if lights[2] and lights[4] else 2 if lights[2] else 3 if lights[4] else 1)


func _on_frame_processed(lights: Array[bool]) -> void:
	for m in MATRIX_COUNT:
		var matrix := grid.get_child(m) as Supermatrix
		matrix.previous_lights = matrix.lights.duplicate()
		var offset := m * Supermatrix.LIGHT_COUNT
		for i in Supermatrix.LIGHT_COUNT:
			matrix.lights[i] = lights[offset + i]
			matrix.queue_redraw()
		send_ai_state(plids[m], matrix.lights, matrix.previous_lights)


func _on_indicator_timer_timeout() -> void:
	for plid in plids:
		send_ai_control(plid, InSim.AIControl.CS_INDICATORS, 1)


func _on_video_button_pressed() -> void:
	for m in plids.size():
		send_ai_reset(plids[m])
	video_processor.process_video()
	indicator_timer.start(60.0 / TEMPO)
