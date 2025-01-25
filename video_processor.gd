class_name VideoProcessor
extends VBoxContainer


signal frame_processed(lights: Array[bool])

const VIDEO_FPS := 30.0

var video_player: VideoStreamPlayer = null
var video := preload("res://bad_apple.ogv")

var timer: Timer = null


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	video_player = VideoStreamPlayer.new()
	add_child(video_player)
	video_player.stream = video
	video_player.volume_db = -9

	timer = Timer.new()
	add_child(timer)
	var _connect := timer.timeout.connect(_on_timer_timeout)


func play_video() -> void:
	video_player.play()


func process_frame(image: Image) -> void:
	var width := image.get_width()
	width = 14
	var height := image.get_height()
	height = 10
	var data := FrameLights.new()
	var _discard := data.lights.resize(width * height)
	for y in height:
		for x in width:
			var on_off := roundi(image.get_pixel(x, y).get_luminance()) as bool
			data.lights[y * width + x] = on_off
	frame_processed.emit(data.lights)


func process_video() -> void:
	video_player.play()
	var texture := video_player.get_video_texture()
	print("Video size: %dx%d" % [texture.get_width(), texture.get_height()])
	await get_tree().create_timer(1 / VIDEO_FPS / 2).timeout
	process_frame(video_player.get_video_texture().get_image())
	timer.start(1 / VIDEO_FPS)


func _on_timer_timeout() -> void:
	process_frame(video_player.get_video_texture().get_image())
