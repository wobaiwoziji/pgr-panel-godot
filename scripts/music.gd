extends Node
## 后台读 Windows「正在播放」（SMTC）：起一个线程循环调 PowerShell，解析 JSON 后发信号
## 解析封面的工作也在这里做，UI 线程只拿现成的 Texture2D

signal changed(track: Dictionary)

const INTERVAL_MS := 1200

var _thread: Thread
var _script := ""
var _last_key := ""


func _ready() -> void:
	_script = ProjectSettings.globalize_path("res://nowplaying.ps1")
	if "--fake" in OS.get_cmdline_user_args():
		return
	_thread = Thread.new()
	_thread.start(_loop)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func _loop() -> void:
	while true:
		var out := []
		var args := ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", _script]
		var code := OS.execute("powershell", args, out, true)
		if code == 0 and out.size() > 0:
			var txt: String = out[0].strip_edges()
			var data = JSON.parse_string(txt)
			if data is Dictionary:
				_handle(data)
		OS.delay_msec(INTERVAL_MS)


func _handle(data: Dictionary) -> void:
	if not data.get("ok", false):
		_emit({ "title": "", "artist": "", "cover": null, "playing": false })
		return

	var title: String = data.get("title", "")
	var artist: String = data.get("artist", "")
	var key := title + "|" + artist
	var cover_tex: Texture2D = null

	if title != "" and key != _last_key:
		_last_key = key
		var url: String = data.get("cover", "")
		if url.begins_with("data:"):
			cover_tex = _texture_from_data_url(url)

	_emit({ "title": title, "artist": artist, "cover": cover_tex, "playing": data.get("playing", false) })


func _emit(track: Dictionary) -> void:
	call_deferred("emit_signal", "changed", track)


func _texture_from_data_url(url: String) -> Texture2D:
	var comma := url.find(",")
	if comma < 0:
		return null
	var raw := Marshalls.base64_to_raw(url.substr(comma + 1))
	var img := Image.new()
	var err := OK
	if url.contains("image/png"):
		err = img.load_png_from_buffer(raw)
	else:
		err = img.load_jpg_from_buffer(raw)
	if err != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	img = _circle_mask(img)
	return ImageTexture.create_from_image(img)


## 方形封面裁成圆形，省得画的时候再抠
func _circle_mask(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var r := minf(w, h) * 0.5
	var c := Vector2(w * 0.5, h * 0.5)
	for y in h:
		for x in w:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > r - 1.5:
				var a := img.get_pixel(x, y).a
				img.set_pixel(x, y, Color(img.get_pixel(x, y), a * (r - d) / 1.5))
	return img
