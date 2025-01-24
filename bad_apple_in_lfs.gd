extends MarginContainer


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

var insim := InSim.new()

var plids: Array[int]
var grid: GridContainer = null
var timer: Timer = null
var frame_data: Array[FrameLights] = []
var current_frame := 0


func _ready() -> void:
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	for i in MATRIX_COUNT:
		var matrix := preload("res://supermatrix.tscn").instantiate() as Supermatrix
		grid.add_child(matrix)
	timer = Timer.new()
	add_child(timer)

	add_child(insim)
	insim.initialize("127.0.0.1", 29999, InSimInitializationData.new())
	await insim.isp_ver_received
	var _discard := insim.isp_reo_received.connect(get_grid)
	insim.send_packet(InSimTinyPacket.new(1, InSim.Tiny.TINY_REO))


func get_grid(reo_packet: InSimREOPacket) -> void:
	plids = reo_packet.plids


func send_ai_control(plid: int, input: InSim.AIControl, value: int) -> void:
	var packet := InSimAICPacket.new()
	packet.plid = plid
	packet.input = input
	packet.value = value
	insim.send_packet(packet)


func send_ai_reset(plid: int) -> void:
	for light: Light in Light:
		var input := 0
		var value := 0
		match light:
			Light.HEADLIGHTS:
				input = InSim.AIControl.CS_HEADLIGHTS
			Light.FLASH:
				input = InSim.AIControl.CS_FLASH
			Light.FOG_FRONT:
				input = InSim.AIControl.CS_FOGFRONT
			Light.FOG_REAR:
				input = InSim.AIControl.CS_FOGFRONT
			Light.EXTRA:
				input = InSim.AIControl.CS_EXTRALIGHT
			Light.INDICATORS_OFF:
				input = InSim.AIControl.CS_INDICATORS
				value = 1
			_:
				continue
		var packet := InSimAICPacket.new()
		packet.plid = plid
		packet.input = input as InSim.AIControl
		packet.value = value
		insim.send_packet(packet)


func send_ai_state(plid: int, lights: Array[bool]) -> void:
	send_ai_control(plid, InSim.AIControl.CS_INDICATORS, 1)  # Resets indicator timer
	send_ai_control(plid, InSim.AIControl.CS_FOGREAR, lights[0])
	send_ai_control(plid, InSim.AIControl.CS_FOGFRONT, lights[1])
	send_ai_control(plid, InSim.AIControl.CS_EXTRALIGHT, lights[3])
	send_ai_control(plid, InSim.AIControl.CS_FLASH, lights[5])
	send_ai_control(plid, InSim.AIControl.CS_HEADLIGHTS, lights[6])
	if lights[2] or lights[4]:
		send_ai_control(plid, InSim.AIControl.CS_INDICATORS,
				4 if lights[2] and lights[4] else 2 if lights[2] else 3)


func set_frame_data(frame: int) -> void:
	var frame_lights := frame_data[frame]
	for m in MATRIX_COUNT:
		var matrix := grid.get_child(m) as Supermatrix
		var offset := m * Supermatrix.LIGHT_COUNT
		for i in Supermatrix.LIGHT_COUNT:
			matrix.lights[i] = frame_lights.lights[offset + i]
			matrix.queue_redraw()
		send_ai_state(plids[m], matrix.lights)


func start_video() -> void:
	for plid in plids:
		send_ai_reset(plid)
	for matrix in grid.get_children() as Array[Supermatrix]:
		matrix.set_all_lights(false)
	current_frame = 0
	set_frame_data(current_frame)
	timer.start(1 / VIDEO_FPS)


func _on_timer_timeout() -> void:
	current_frame += 1
	set_frame_data(current_frame)
