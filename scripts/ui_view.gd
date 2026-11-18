extends Node2D
## 面板本体：只负责画，不处理窗口/透视
## 设计画布 760×892，布局数值沿用 Web 版 panel.css

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

# 当前曲目（由 main.gd 通过 set_track 喂进来）
var track := { "title": "", "artist": "", "cover": null, "playing": false }
var cover_angle := 0.0
var _elapsed := 0.0
var _title_a: Label
var _title_b: Label
var _title_w := 0.0
var _artist: Label
var _media_clip: Control
var grid
var grid_clip
var open := true
var cfg := {}


func _ready() -> void:
	_load_config()
	for b in buttons:
		textures[b.get("icon", "")] = load("res://assets/icons/%s.png" % b.get("icon", ""))
	for q in quick:
		textures[q] = load("res://assets/icons/%s.png" % q)
	_build_text_layer()
	_build_grid_layer()


func _load_config() -> void:
	var f := FileAccess.open("user://config.json", FileAccess.READ)
	if f == null:
		f = FileAccess.open("res://config.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		cfg = data
		var panel: Dictionary = cfg.get("panel", {})
		if panel.has("buttons"):
			buttons = panel["buttons"]
		if panel.has("quick"):
			var q: Array = []
			for item in panel["quick"]:
				q.append(item.get("icon", ""))
			if q.size() > 0:
				quick = q


## 配置被编辑保存后重新载入，重建九宫格
func reload_config() -> void:
	_load_config()
	textures.clear()
	for b in buttons:
		textures[b.get("icon", "")] = load("res://assets/icons/%s.png" % b.get("icon", ""))
	if grid:
		grid.buttons = buttons
		grid.textures = textures
		grid.scroll = 0.0
		grid.queue_redraw()
	queue_redraw()


func set_open(v: bool) -> void:
	open = v
	if grid_clip:
		grid_clip.visible = v
	queue_redraw()


func _build_grid_layer() -> void:
	var area := Rect2(PANEL.position + Vector2(8, 196), Vector2(420, 438))
	grid_clip = Control.new()
	grid_clip.position = area.position
	grid_clip.size = area.size
	grid_clip.clip_contents = true
	grid_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid_clip)

	grid = Node2D.new()
	grid.set_script(load("res://scripts/grid_view.gd"))
	grid.font = FONT_BODY
	grid.buttons = buttons
	grid.textures = textures
	grid_clip.add_child(grid)


func set_track(t: Dictionary) -> void:
	track = t
	_elapsed = 0.0
	_update_text()


func _process(delta: float) -> void:
	_elapsed += delta
	if track.cover != null:
		cover_angle += delta * 0.85
		queue_redraw()
	_advance_marquee()


# ── 音乐卡文字：用 Control 裁剪，歌名放不下就右→左滚 ──
func _build_text_layer() -> void:
	var card := Rect2(PANEL.position + Vector2(-8, 68), Vector2(428, 116))
	_media_clip = Control.new()
	_media_clip.position = card.position + Vector2(137, 18)
	_media_clip.size = Vector2(card.size.x - 137 - 16, 76)
	_media_clip.clip_contents = true
	_media_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_media_clip)

	_title_a = _make_label(Vector2(0, 16), 20, Color(0.94, 0.97, 1.0))
	_title_b = _make_label(Vector2(0, 16), 20, Color(0.94, 0.97, 1.0))
	_artist = _make_label(Vector2(0, 48), 14, Color(0.78, 0.86, 0.96, 0.72))
	_update_text()


func _make_label(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_override("font", FONT_BODY)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_media_clip.add_child(l)
	return l


func _update_text() -> void:
	if _title_a == null:
		return
	var title: String = track.get("title", "")
	var artist: String = track.get("artist", "")
	if title == "":
		_title_a.text = "未在播放"
		_title_b.text = ""
		_title_a.modulate = Color(1, 1, 1, 0.45)
		_title_w = 0.0
	else:
		_title_a.text = title
		_title_b.text = title
		_title_a.modulate = Color(1, 1, 1, 1)
		_title_w = FONT_BODY.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_artist.text = artist
	_artist.visible = artist != ""
	_title_a.position.x = 0
	_title_b.position.x = _title_w + 60


func _advance_marquee() -> void:
	if _title_a == null or _title_w <= _media_clip.size.x:
		if _title_a:
			_title_a.position.x = 0
			_title_b.visible = false
		return
	_title_b.visible = true
	var span := _title_w + 60.0
	var off := -fmod(_elapsed * 55.0, span)
	_title_a.position.x = off
	_title_b.position.x = off + span


# ── 交互 ──
func grid_area() -> Rect2:
	return Rect2(PANEL.position + Vector2(8, 196), Vector2(420, 438))


func hit(p: Vector2) -> Dictionary:
	if p.distance_to(LENS_CENTER) < 60.0:
		return { "type": "lens" }
	if not open:
		return {}
	var area := grid_area()
	if area.has_point(p):
		var idx: int = grid.hit(p - area.position)
		if idx >= 0:
			return { "type": "cell", "index": idx }
	var y := PANEL.end.y - 34 - 56
	var x0 := PANEL.position.x - 38
	var step := 456.0 / maxf(quick.size(), 1)
	for i in quick.size():
		if Rect2(Vector2(x0 + step * i, y - 12), Vector2(step, 80)).has_point(p):
			return { "type": "quick", "index": i }
	return {}


func cursor_move(p: Vector2) -> void:
	if grid == null:
		return
	var idx := -1
	var area := grid_area()
	if open and area.has_point(p):
		idx = grid.hit(p - area.position)
	if idx != grid.hover:
		grid.hover = idx
		grid.queue_redraw()


func wheel(dy: float) -> void:
	if grid == null:
		return
	grid.set_scroll(grid.scroll + dy)



func _draw() -> void:
	if not open:
		_draw_lens()
		return
	_draw_beams()
	_draw_plane()
	_draw_header()
	_draw_media()
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
	if track.get("cover", null) != null:
		draw_set_transform(c, cover_angle)
		draw_texture_rect(track.cover, Rect2(-41, -41, 82, 82), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		_placeholder_disc(c, 41)

	var cap: String = "正在播放" if track.get("title", "") != "" else "音乐"
	draw_string(FONT_BODY, r.position + Vector2(137, 32), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.86, 0.9, 0.95, 0.8))


func _placeholder_disc(c: Vector2, radius: float) -> void:
	draw_circle(c, radius, Color(0.11, 0.12, 0.16))
	for i in 32:
		var a0 := TAU * i / 32.0
		var a1 := TAU * (i + 1) / 32.0
		var col := Color(0.42, 0.22, 0.35).lerp(Color(0.16, 0.16, 0.22), (i % 5) / 4.0)
		var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * radius, c + Vector2(cos(a1), sin(a1)) * radius])
		draw_polygon(pts, PackedColorArray([col, col, col]))


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
