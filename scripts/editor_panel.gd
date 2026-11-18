extends Control
## 右键按钮弹出的编辑面板（不参与透视，直接盖在窗口上）

signal closed
signal saved(index: int, data: Dictionary)

const FONT: FontFile = preload("res://assets/fonts/font_zh.ttf")
const ICONS := [
	"icon_website", "icon_team_recommend", "icon_team_edit", "icon_cloud_gaming",
	"icon_wallpaper", "icon_comic", "icon_download", "icon_export", "icon_strategy",
	"icon_friend", "icon_group", "icon_camera", "icon_settings",
]

var index := -1
var data := { "label": "", "icon": "", "target": "" }
var chosen_icon := ""

var _name: LineEdit
var _target: LineEdit
var _grid: GridContainer
var _file: FileDialog
var _img_dialog: FileDialog
var _buttons := {}


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
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.078, 0.204, 0.376, 0.98)
	sb.border_color = Color(0.47, 0.7, 0.96, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "按钮设置"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	_name = _row_line(box, "文字", data.get("label", ""))

	var label := Label.new()
	label.text = "图标"
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.93, 0.8))
	box.add_child(label)

	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_grid)

	chosen_icon = data.get("icon", "")
	for name in ICONS:
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/icons/%s.png" % name)
		b.custom_minimum_size = Vector2(42, 42)
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.modulate = Color(0.55, 0.55, 0.55) if name != chosen_icon else Color(1, 1, 1)
		b.pressed.connect(func(): _pick_icon(name))
		_grid.add_child(b)
		_buttons[name] = b

	_target = _row_line(box, "打开", data.get("target", ""))
	var pick_img := Button.new()
	pick_img.text = "选择图片当图标…"
	pick_img.add_theme_font_override("font", FONT)
	pick_img.pressed.connect(func(): _img_dialog.popup_centered_ratio(0.6))
	box.add_child(pick_img)
	var pick := Button.new()
	pick.text = "浏览…"
	pick.add_theme_font_override("font", FONT)
	pick.pressed.connect(_pick_file)
	box.add_child(pick)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 8)
	box.add_child(btns)

	var cancel := Button.new()
	cancel.text = "取消"
	cancel.add_theme_font_override("font", FONT)
	cancel.pressed.connect(func(): closed.emit())
	btns.add_child(cancel)

	var save := Button.new()
	save.text = "保存"
	save.add_theme_font_override("font", FONT)
	save.pressed.connect(_save)
	btns.add_child(save)

	_file = FileDialog.new()
	_file.access = FileDialog.ACCESS_FILESYSTEM
	_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file.use_native_dialog = true
	_file.file_selected.connect(func(p): _target.text = p)
	add_child(_file)

	_img_dialog = FileDialog.new()
	_img_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_img_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_img_dialog.use_native_dialog = true
	_img_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp, *.bmp ; 图片"])
	_img_dialog.file_selected.connect(_on_custom_icon)
	add_child(_img_dialog)


func _row_line(parent: Node, caption: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := Label.new()
	l.text = caption
	l.custom_minimum_size = Vector2(44, 0)
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 13)
	row.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_font_override("font", FONT)
	e.add_theme_font_size_override("font_size", 13)
	row.add_child(e)
	return e


func _pick_icon(name: String) -> void:
	chosen_icon = name
	for k in _buttons:
		_buttons[k].modulate = Color(1, 1, 1) if k == name else Color(0.55, 0.55, 0.55)


func _pick_file() -> void:
	_file.popup_centered_ratio(0.6)


func _on_custom_icon(path: String) -> void:
	chosen_icon = "file://" + path
	for k in _buttons:
		_buttons[k].modulate = Color(0.55, 0.55, 0.55)


func _save() -> void:
	saved.emit(index, {
		"label": _name.text.strip_edges(),
		"icon": chosen_icon,
		"target": _target.text.strip_edges(),
	})
