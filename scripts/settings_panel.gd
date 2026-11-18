extends Control
## 设置面板：本地音乐目录、投影缩放、光带强度

signal changed(values: Dictionary)
signal closed

const FONT: FontFile = preload("res://assets/fonts/font_zh.ttf")

var zoom := 100.0
var beam := 100.0
var folder := ""
var count := 0

var _folder_label: Label
var _zoom_value: Label
var _beam_value: Label
var _dialog: FileDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.016, 0.031, 0.063, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.078, 0.204, 0.376, 0.98)
	sb.border_color = Color(0.47, 0.7, 0.96, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := _label("面板设置", 16)
	box.add_child(title)

	# 本地音乐
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	box.add_child(row1)
	row1.add_child(_label("本地音乐", 13))
	var pick := Button.new()
	pick.text = "选择目录"
	pick.add_theme_font_override("font", FONT)
	pick.add_theme_font_size_override("font_size", 12)
	pick.pressed.connect(func(): _dialog.popup_centered_ratio(0.6))
	row1.add_child(pick)
	_folder_label = _label("", 12)
	_folder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_folder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row1.add_child(_folder_label)

	# 缩放
	box.add_child(_slider_row("投影缩放", 60, 140, zoom, func(v):
		zoom = v
		_emit()))

	# 光带
	box.add_child(_slider_row("投影光带", 0, 100, beam, func(v):
		beam = v
		_emit()))

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(btns)
	var close := Button.new()
	close.text = "关闭"
	close.add_theme_font_override("font", FONT)
	close.pressed.connect(func(): closed.emit())
	btns.add_child(close)

	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dialog.use_native_dialog = true
	_dialog.dir_selected.connect(_on_folder)
	add_child(_dialog)

	_refresh()


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	return l


func _slider_row(caption: String, lo: float, hi: float, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap := _label(caption, 13)
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
	var val := _label("%d%%" % int(value), 12)
	val.custom_minimum_size = Vector2(44, 0)
	row.add_child(val)
	s.value_changed.connect(func(v):
		val.text = "%d%%" % int(v)
		cb.call(v))
	if caption == "投影缩放":
		_zoom_value = val
	else:
		_beam_value = val
	return row


func _refresh() -> void:
	var name := "未设置"
	if folder != "":
		name = "%d 首" % count
	_folder_label.text = name
	_zoom_value.text = "%d%%" % int(zoom)
	_beam_value.text = "%d%%" % int(beam)


func _emit() -> void:
	changed.emit({ "zoom": zoom, "beam": beam, "folder": folder })


func _on_folder(dir: String) -> void:
	folder = dir
	changed.emit({ "zoom": zoom, "beam": beam, "folder": folder, "rescan": true })
