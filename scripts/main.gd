extends Node2D
## PGR 全息面板 —— Godot 骨架
## 设计画布 760×892，窗口按 0.621 缩放；布局数值直接沿用 Web 版 panel.css

const FONT_BODY: FontFile = preload("res://assets/fonts/font_zh.ttf")

const PANEL := Rect2(140, 74, 480, 772)
const LENS_CENTER := Vector2(784, 748)
const LENS_R := 42.0

const COL_CELL := Color(5, 7, 12, 1)
const COL_LABEL := Color(0.957, 0.957, 0.957, 1)
const COL_LABEL_FG := Color(0.031, 0.035, 0.051, 1)
const COL_GRID_H := Color(0.588, 0.804, 1.0, 0.22)
const COL_GRID_V := Color(0.588, 0.804, 1.0, 0.18)
const COL_ACCENT := Color(0.306, 0.639, 1.0, 1)

var buttons := [
	{ "label": "官网主页", "icon": "icon_website" },
	{ "label": "编队推荐", "icon": "icon_team_recommend" },
	{ "label": "编队调整", "icon": "icon_team_edit" },
	{ "label": "云游戏", "icon": "icon_cloud_gaming" },
	{ "label": "官方壁纸", "icon": "icon_wallpaper" },
	{ "label": "官方漫画", "icon": "icon_comic" },
	{ "label": "资源下载", "icon": "icon_download" },
	{ "label": "编队导出", "icon": "icon_export" },
	{ "label": "作战攻略", "icon": "icon_strategy" },
]

var quick := ["icon_friend", "icon_camera", "icon_group", "icon_settings"]
var textures := {}
var shot_path := ""


func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	get_viewport().transparent_bg = true

	for b in buttons:
		textures[b.icon] = load("res://assets/icons/%s.png" % b.icon)
	for q in quick:
		textures[q] = load("res://assets/icons/%s.png" % q)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot_path = arg.substr(7)

	if shot_path != "":
		_take_shot()


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	get_tree().quit()


func _draw() -> void:
	_draw_beams()
	_draw_plane()
	_draw_header()
	_draw_media()
	_draw_grid()
	_draw_quick()
	_draw_lens()


# ── 投影三角：底边贴面板上下沿，顶点指向镜头 ──
func _draw_beams() -> void:
	var top := PackedVector2Array([
		Vector2(172, 108), Vector2(628, 108), LENS_CENTER,
	])
	var top_cols := PackedColorArray([
		Color(0.588, 0.804, 1.0, 0.34), Color(0.588, 0.804, 1.0, 0.34), Color(0.353, 0.627, 0.882, 0.0),
	])
	draw_polygon(top, top_cols)

	var bottom := PackedVector2Array([
		Vector2(172, 841), Vector2(628, 841), LENS_CENTER,
	])
	var bottom_cols := PackedColorArray([
		Color(0.071, 0.22, 0.408, 0.55), Color(0.11, 0.306, 0.541, 0.55), Color(0.11, 0.306, 0.541, 0.0),
	])
	draw_polygon(bottom, bottom_cols)


# ── 蓝色面板：底板 + 纵向渐变 + 网格 ──
func _draw_plane() -> void:
	var shadow := Rect2(PANEL.position + Vector2(44, 10), PANEL.size)
	draw_style_box(_box(Color(0.031, 0.157, 0.345, 0.62), 18), shadow)

	var body := _box(Color(0.024, 0.157, 0.376, 0.62), 18)
	draw_style_box(body, PANEL)

	var w := PANEL.size.x
	var h := PANEL.size.y
	var o := PANEL.position
	var grad := PackedVector2Array([
		o, o + Vector2(w, 0), o + Vector2(w, h), o + Vector2(0, h),
	])
	var gcols := PackedColorArray([
		Color(0.024, 0.157, 0.376, 0.10),
		Color(0.024, 0.157, 0.376, 0.10),
		Color(0.549, 0.843, 1.0, 0.45),
		Color(0.549, 0.843, 1.0, 0.45),
	])
	draw_polygon(grad, gcols)

	var inset := 2.0
	var x := o.x + inset
	while x < o.x + w - inset:
		draw_line(Vector2(x, o.y + inset), Vector2(x, o.y + h - inset), COL_GRID_V, 1.0)
		x += 10.0
	var y := o.y + inset
	while y < o.y + h - inset:
		draw_line(Vector2(o.x + inset, y), Vector2(o.x + w - inset, y), COL_GRID_H, 1.0)
		y += 10.0


func _draw_header() -> void:
	var r := Rect2(PANEL.position + Vector2(-44, -11), Vector2(PANEL.size.x, 50))
	draw_style_box(_box(Color(0.988, 0.99, 0.996, 0.97), 3), r)

	var t := Time.get_time_dict_from_system()
	var d := Time.get_date_dict_from_system()
	var clock := "%02d:%02d" % [t.hour, t.minute]
	var date := "%d/%d 星期%s" % [d.month, d.day, "日一二三四五六"[d.weekday]]
	var base := r.position.y + 34
	draw_string(FONT_BODY, Vector2(r.position.x + 18, base), clock, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color(0.04, 0.05, 0.07))
	draw_string(FONT_BODY, Vector2(r.end.x - 168, base), date, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.04, 0.05, 0.07))


func _draw_media() -> void:
	var r := Rect2(PANEL.position + Vector2(-8, 68), Vector2(428, 116))
	draw_rect(r, Color(0.133, 0.125, 0.157, 0.88))

	var c := r.position + Vector2(22 + 41, 58)
	draw_circle(c, 41, Color(0.11, 0.12, 0.16))
	for i in 32:
		var a0 := TAU * i / 32.0
		var a1 := TAU * (i + 1) / 32.0
		var col := Color(0.42, 0.22, 0.35).lerp(Color(0.16, 0.16, 0.22), (i % 5) / 4.0)
		var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 41, c + Vector2(cos(a1), sin(a1)) * 41])
		draw_polygon(pts, PackedColorArray([col, col, col]))

	draw_string(FONT_BODY, r.position + Vector2(137, 38), "音乐", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.86, 0.9, 0.95, 0.8))
	draw_string(FONT_BODY, r.position + Vector2(137, 72), "未在播放", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.84, 0.94, 0.45))


func _draw_grid() -> void:
	var area := Rect2(PANEL.position + Vector2(8, 196), Vector2(420, 438))
	var cols := 3
	var gap_x := 26.0
	var gap_y := 18.0
	var cell_w := (area.size.x - gap_x * 2) / 3.0
	var box_h := 102.0
	var label_h := 32.0

	for i in buttons.size():
		var row := i / cols
		var col := i % cols
		var p := area.position + Vector2(col * (cell_w + gap_x), row * (box_h + label_h + gap_y))
		if p.y + box_h > area.end.y + 40:
			continue
		var box := Rect2(p, Vector2(cell_w, box_h))
		draw_rect(box, COL_CELL)

		var tex: Texture2D = textures.get(buttons[i].icon)
		if tex:
			var s: float = min(box.size.x, box.size.y) * 0.56
			var dst := Rect2(box.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))
			draw_texture_rect(tex, dst, false, Color(0.92, 0.95, 1.0))

		var lr := Rect2(p + Vector2(cell_w * 0.04, box_h), Vector2(cell_w * 0.92, label_h))
		draw_rect(lr, COL_LABEL)
		var text: String = buttons[i].label
		var fs := 17
		var tw := FONT_BODY.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw > lr.size.x - 6:
			fs = int(fs * (lr.size.x - 6) / tw)
			tw = FONT_BODY.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(
			FONT_BODY,
			Vector2(lr.get_center().x - tw * 0.5, lr.position.y + lr.size.y * 0.5 + fs * 0.36),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			COL_LABEL_FG
		)


func _draw_quick() -> void:
	var y := PANEL.end.y - 34 - 56
	var x0 := PANEL.position.x - 38
	var w := 456.0

	draw_rect(Rect2(Vector2(x0 - 10, y - 12), Vector2(w + 20, 78)), Color(0.016, 0.031, 0.059, 0.58))

	var step := w / quick.size()
	for i in quick.size():
		var tex: Texture2D = textures.get(quick[i])
		if not tex:
			continue
		var cx := x0 + step * (i + 0.5)
		var dst := Rect2(Vector2(cx - 28, y), Vector2(56, 56))
		draw_texture_rect(tex, dst, false, Color(0.92, 0.95, 1.0))


func _draw_lens() -> void:
	draw_circle(LENS_CENTER, LENS_R + 10, Color(0.31, 0.63, 1.0, 0.10))
	draw_arc(LENS_CENTER, LENS_R, 0, TAU, 64, Color(0.35, 0.69, 1.0, 0.85), 2.0, true)
	draw_arc(LENS_CENTER, LENS_R - 8, 0, TAU, 64, Color(0.45, 0.78, 1.0, 0.45), 1.0, true)
	draw_circle(LENS_CENTER, 14, Color(0.29, 0.68, 1.0, 0.9))
	draw_circle(LENS_CENTER, 7, Color(0.75, 0.93, 1.0, 0.95))

	for i in 4:
		var ang := TAU * i / 4.0 + PI / 4.0
		var p0 := LENS_CENTER + Vector2(cos(ang), sin(ang)) * (LENS_R + 4)
		var p1 := LENS_CENTER + Vector2(cos(ang), sin(ang)) * (LENS_R + 12)
		draw_line(p0, p1, Color(0.35, 0.69, 1.0, 0.7), 2.0, true)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb
