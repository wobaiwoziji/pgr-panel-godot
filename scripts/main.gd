extends Node2D
## 窗口 + 透视：把 ui_view 画到 SubViewport 里，再用单应矩阵 shader 投影出来
## 参数直接对应 Web 版 CSS：
## perspective(850px) rotateY(-18deg) rotateX(6deg) rotateZ(2.4deg) scale(1.04) translate(-140px,-6px)
## transform-origin: 62% 42%

const CANVAS := Vector2(760, 892)
const TILT_ORIGIN := Vector2(471.2, 374.6)
const TILT_Z := 2.4
const TILT_X := 6.0
const TILT_Y := -18.0
const TILT_SCALE := 1.04
const TILT_MOVE := Vector2(-140, -6)
const PERSPECTIVE := 850.0

var shot_path := ""


func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	get_viewport().transparent_bg = true

	var sub := SubViewport.new()
	sub.size = Vector2i(CANVAS)
	sub.transparent_bg = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.disable_3d = true
	add_child(sub)

	var ui := Node2D.new()
	ui.set_script(load("res://scripts/ui_view.gd"))
	sub.add_child(ui)

	var view := TextureRect.new()
	view.texture = sub.get_texture()
	view.position = Vector2.ZERO
	view.size = CANVAS
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not ("--flat" in OS.get_cmdline_user_args()):
		view.material = _make_tilt_material()
	add_child(view)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot_path = arg.substr(7)
	if shot_path != "":
		_take_shot()


# ── 透视矩阵 ──────────────────────────────────────────────
func _project(p: Vector2) -> Vector2:
	var q := Vector3(p.x - TILT_ORIGIN.x + TILT_MOVE.x, p.y - TILT_ORIGIN.y + TILT_MOVE.y, 0.0) * TILT_SCALE
	q = _rot_z(q, deg_to_rad(TILT_Z))
	q = _rot_x(q, deg_to_rad(TILT_X))
	q = _rot_y(q, deg_to_rad(TILT_Y))
	var w := 1.0 - q.z / PERSPECTIVE
	if absf(w) < 0.0001:
		w = 0.0001
	return TILT_ORIGIN + Vector2(q.x, q.y) / w


func _rot_z(v: Vector3, a: float) -> Vector3:
	return Vector3(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a), v.z)


func _rot_x(v: Vector3, a: float) -> Vector3:
	return Vector3(v.x, v.y * cos(a) - v.z * sin(a), v.y * sin(a) + v.z * cos(a))


func _rot_y(v: Vector3, a: float) -> Vector3:
	return Vector3(v.x * cos(a) + v.z * sin(a), v.y, -v.x * sin(a) + v.z * cos(a))


func _make_tilt_material() -> ShaderMaterial:
	var quad := [
		_project(Vector2(0, 0)),
		_project(Vector2(CANVAS.x, 0)),
		_project(Vector2(CANVAS.x, CANVAS.y)),
		_project(Vector2(0, CANVAS.y)),
	]
	# 源矩形是整块画布，先归一化成单位方形再求到目标四边形的单应矩阵
	var h := _unit_to_quad(quad)
	var inv := _inv3(h)
	print("quad=", quad)
	print("inv=", inv)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/homography.gdshader")
	# 传三列（列主序）
	mat.set_shader_parameter("h0", Vector3(inv[0], inv[3], inv[6]))
	mat.set_shader_parameter("h1", Vector3(inv[1], inv[4], inv[7]))
	mat.set_shader_parameter("h2", Vector3(inv[2], inv[5], inv[8]))
	mat.set_shader_parameter("canvas", CANVAS)
	return mat


## 单位方形 (0,0)(1,0)(1,1)(0,1) → 四边形，返回行主序 3×3
func _unit_to_quad(q: Array) -> Array:
	var x0: float = q[0].x
	var y0: float = q[0].y
	var x1: float = q[1].x
	var y1: float = q[1].y
	var x2: float = q[2].x
	var y2: float = q[2].y
	var x3: float = q[3].x
	var y3: float = q[3].y

	var dx1 := x1 - x2
	var dx2 := x3 - x2
	var dy1 := y1 - y2
	var dy2 := y3 - y2
	var sx := x0 - x1 + x2 - x3
	var sy := y0 - y1 + y2 - y3
	var g := 0.0
	var hh := 0.0
	var den := dx1 * dy2 - dx2 * dy1
	if (absf(sx) > 1e-9 or absf(sy) > 1e-9) and absf(den) > 1e-9:
		g = (sx * dy2 - dx2 * sy) / den
		hh = (dx1 * sy - sx * dy1) / den
	var a := x1 - x0 + g * x1
	var b := x3 - x0 + hh * x3
	var c := x0
	var d := y1 - y0 + g * y1
	var e := y3 - y0 + hh * y3
	var f := y0
	return [a, b, c, d, e, f, g, hh, 1.0]


func _inv3(m: Array) -> Array:
	var a: float = m[0]
	var b: float = m[1]
	var c: float = m[2]
	var d: float = m[3]
	var e: float = m[4]
	var f: float = m[5]
	var g: float = m[6]
	var h: float = m[7]
	var i: float = m[8]
	var det := a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
	if absf(det) < 1e-12:
		return [1, 0, 0, 0, 1, 0, 0, 0, 1]
	det = 1.0 / det
	return [
		(e * i - f * h) * det, (c * h - b * i) * det, (b * f - c * e) * det,
		(f * g - d * i) * det, (a * i - c * g) * det, (c * d - a * f) * det,
		(d * h - e * g) * det, (b * g - a * h) * det, (a * e - b * d) * det,
	]


func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	get_tree().quit()
