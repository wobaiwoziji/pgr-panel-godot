extends Node
## 后台读 Windows「正在播放」（SMTC）：起一个线程循环调 PowerShell，解析 JSON 后发信号
## 解析封面的工作也在这里做，UI 线程只拿现成的 Texture2D

signal changed(track: Dictionary)

const INTERVAL_MS := 1200

var _thread: Thread
var _script := ""
var _last_key := ""
var _thumb_script := ""
var local_root := ""
var local_files := []

const AUDIO_EXT := ["mp3", "flac", "m4a", "aac", "ogg", "opus", "wav", "wma", "ape"]


func _ready() -> void:
	_script = ProjectSettings.globalize_path("res://nowplaying.ps1")
	_thumb_script = ProjectSettings.globalize_path("res://thumb.ps1")
	if "--fake" in OS.get_cmdline_user_args():
		return
	_thread = Thread.new()
	_thread.start(_loop)


## 选好目录后扫一遍文件名（不读标签，很快）
func set_local_folder(dir: String) -> int:
	local_root = dir
	local_files.clear()
	if dir != "":
		_scan(dir, 0)
	return local_files.size()


func _scan(dir: String, depth: int) -> void:
	if depth > 6:
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full := dir.path_join(name)
		if d.current_is_dir():
			_scan(full, depth + 1)
		else:
			var ext := name.get_extension().to_lower()
			if AUDIO_EXT.has(ext):
				local_files.append(full)
		name = d.get_next()
	d.list_dir_end()


func _norm(text: String) -> String:
	var t := text.to_lower()
	var re := RegEx.new()
	re.compile("^\\s*\\d+[\\s._-]+")
	t = re.sub(t, "", true)
	t = t.replace("(", " ").replace(")", " ").replace("（", " ").replace("）", " ")
	t = t.replace("[", " ").replace("]", " ").replace("【", " ").replace("】", " ")
	return t.strip_edges()


func find_local(title: String) -> String:
	var t := _norm(title)
	if t == "" or local_files.is_empty():
		return ""
	for f in local_files:
		var base := _norm(f.get_file().get_basename())
		if base.contains(t) or t.contains(base):
			return f
	return ""


func fetch_thumb(path: String) -> Texture2D:
	var out := []
	var code := OS.execute("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", _thumb_script, "-Path", path], out, true)
	if code != 0 or out.is_empty():
		return null
	var b64: String = String(out[0]).strip_edges()
	if b64 == "NONE" or b64 == "":
		return null
	return _texture_from_data_url("data:image/jpeg;base64," + b64)


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
		else:
			# 播放器没给封面：先找本地音乐目录里的内嵌图（秒出），没有再交给主线程上网找
			var file := find_local(title)
			if file != "":
				cover_tex = fetch_thumb(file)

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
