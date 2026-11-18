extends Control
## 设置面板：照搬 Web 版那套布局（分区标题 + 滑杆行 + 交流群 + 页脚）

signal changed(values: Dictionary)
signal closed

const FONT: FontFile = preload("res://assets/fonts/font_zh.ttf")
const COL_TITLE := Color(0.72, 0.82, 0.93, 0.85)
const COL_TEXT := Color(0.86, 0.92, 0.98, 1.0)
const COL_DIM := Color(0.62, 0.72, 0.84, 0.7)
const COL_ACCENT := Color(0.31, 0.64, 1.0, 1.0)

var px := Vector2(760, 892)
var zoom := 100.0
var beam := 100.0
var particles := 60.0
var motion := true
var folder := ""
var count := 0

var _folder_label: Label
var _zoom_value: Label
var _beam_value: Label
var _particle_value: Label
var _dialog: FileDialog


func _ready() -> void:
	size = px
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.016, 0.031, 0.063, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(470.0, px.x - 24.0), 0)
	panel.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.078, 0.204, 0.376, 0.97)
	sb.bg_color = Color(0.055, 0.145, 0.28, 0.97)
	sb.border_color = Color(0.47, 0.7, 0.96, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	# 头部
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label("面板设置", 16, COL_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_x := Button.new()
	close_x.text = "×"
	close_x.custom_minimum_size = Vector2(26, 26)
	close_x.add_theme_font_override("font", FONT)
	close_x.add_theme_font_size_override("font_size", 15)
	close_x.pressed.connect(func(): closed.emit())
	head.add_child(close_x)

	_section(box, "外观")
	box.add_child(_slider_row("粒子数量", 0, 140, particles, "%d", func(v):
		particles = v
		_emit(), "particles"))
	box.add_child(_slider_row("投影缩放", 60, 140, zoom, "%d%%", func(v):
		zoom = v
		_emit(), "zoom"))
	box.add_child(_slider_row("投影光带", 0, 100, beam, "%d%%", func(v):
		beam = v
		_emit(), "beam"))

	_section(box, "音乐")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_label("本地音乐", 13, COL_TEXT))
	var pick := Button.new()
	pick.text = "选择目录"
	pick.add_theme_font_override("font", FONT)
	pick.add_theme_font_size_override("font_size", 12)
	pick.pressed.connect(func(): _dialog.popup_centered_ratio(0.6))
	row.add_child(pick)
	_folder_label = _label("", 12, COL_DIM)
	_folder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_folder_label)

	_section(box, "动效")
	var mrow := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(mrow)
	mrow.add_child(_label("界面动画", 13, COL_TEXT))
	var sw := Button.new()
	sw.text = "开" if motion else "关"
	sw.custom_minimum_size = Vector2(54, 0)
	sw.add_theme_font_override("font", FONT)
	sw.add_theme_font_size_override("font_size", 12)
	sw.pressed.connect(func():
		motion = not motion
		sw.text = "开" if motion else "关"
		_emit())
	mrow.add_child(sw)

	_section(box, "插件")
	var empty := _label("暂无插件", 12, COL_DIM)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(empty)

	_section(box, "交流")
	box.add_child(_group_block())

	# 页脚
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	box.add_child(foot)
	var ver := _label("PGR Panel v0.4 · Godot", 11, COL_DIM)
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(ver)
	var cfg_btn := Button.new()
	cfg_btn.text = "打开配置文件"
	cfg_btn.add_theme_font_override("font", FONT)
	cfg_btn.add_theme_font_size_override("font_size", 12)
	cfg_btn.pressed.connect(func():
		OS.shell_open(ProjectSettings.globalize_path("user://config.json")))
	foot.add_child(cfg_btn)
	var quit_btn := Button.new()
	quit_btn.text = "退出程序"
	quit_btn.add_theme_font_override("font", FONT)
	quit_btn.add_theme_font_size_override("font_size", 12)
	quit_btn.add_theme_color_override("font_color", Color(1, 0.84, 0.87))
	quit_btn.pressed.connect(func(): get_tree().quit())
	foot.add_child(quit_btn)

	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dialog.use_native_dialog = true
	_dialog.dir_selected.connect(_on_folder)
	add_child(_dialog)

	_refresh()


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _section(parent: Node, text: String) -> void:
	var l := _label(text, 12, COL_TITLE)
	parent.add_child(l)


func _slider_row(caption: String, lo: float, hi: float, value: float, fmt: String, cb: Callable, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cap := _label(caption, 13, COL_TEXT)
	cap.custom_minimum_size = Vector2(72, 0)
	row.add_child(cap)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 18)
	row.add_child(s)
	var val := _label(fmt % int(value), 12, COL_DIM)
	val.custom_minimum_size = Vector2(48, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	match key:
		"zoom":
			_zoom_value = val
		"beam":
			_beam_value = val
		"particles":
			_particle_value = val
	s.value_changed.connect(func(v):
		val.text = fmt % int(v)
		cb.call(v))
	return row


func _group_block() -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	box.add_child(info)

	info.add_child(_label("升格网络开发交流群", 13, COL_TEXT))
	info.add_child(_label("群号 1091767355", 12, COL_DIM))

	var copy := Button.new()
	copy.text = "复制群号"
	copy.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	copy.add_theme_font_override("font", FONT)
	copy.add_theme_font_size_override("font_size", 12)
	copy.pressed.connect(func(): DisplayServer.clipboard_set("1091767355"))
	info.add_child(copy)

	var hint := _label("有想法、想聊 UI、想加功能的都可以进来", 11, COL_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(hint)

	var qr := TextureRect.new()
	qr.texture = load("res://assets/qq-group.png")
	qr.custom_minimum_size = Vector2(120, 120)
	qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(qr)
	return box


func _refresh() -> void:
	_folder_label.text = ("%d 首" % count) if folder != "" else "未设置"
	if _zoom_value:
		_zoom_value.text = "%d%%" % int(zoom)
	if _beam_value:
		_beam_value.text = "%d%%" % int(beam)
	if _particle_value:
		_particle_value.text = "%d" % int(particles)


func _emit() -> void:
	changed.emit({
		"zoom": zoom, "beam": beam, "particles": particles, "motion": motion, "folder": folder,
	})


func _on_folder(dir: String) -> void:
	folder = dir
	changed.emit({
		"zoom": zoom, "beam": beam, "particles": particles, "motion": motion, "folder": folder, "rescan": true,
	})
