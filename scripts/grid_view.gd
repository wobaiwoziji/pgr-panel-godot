extends Node2D
## 九宫格：负责画单元格、hover 高亮和滚动偏移（由父级裁剪）

const COLS := 3
const CELL_W := 122.0
const BOX_H := 102.0
const LABEL_H := 32.0
const GAP_X := 26.0
const GAP_Y := 18.0
const VIEW_H := 438.0

const COL_CELL := Color(5, 7, 12, 1)
const COL_CELL_HOVER := Color(10, 18, 30, 1)
const COL_LABEL := Color(0.957, 0.957, 0.957, 1)
const COL_LABEL_FG := Color(0.031, 0.035, 0.051, 1)

var buttons: Array = []
var textures := {}
var scroll := 0.0
var hover := -1
var pressed := -1
var font: FontFile


func content_height() -> float:
	var rows := int(ceil(buttons.size() / float(COLS)))
	return rows * (BOX_H + LABEL_H + GAP_Y) - GAP_Y


func max_scroll() -> float:
	return maxf(0.0, content_height() - VIEW_H)


func set_scroll(v: float) -> void:
	var s := clampf(v, 0.0, max_scroll())
	if not is_equal_approx(s, scroll):
		scroll = s
		queue_redraw()


func row_top(index: int) -> float:
	return (index / COLS) * (BOX_H + LABEL_H + GAP_Y) - scroll


## 返回鼠标（本节点坐标）命中的单元格序号，没命中返回 -1
func hit(local: Vector2) -> int:
	if local.x < 0 or local.x > COLS * CELL_W + (COLS - 1) * GAP_X or local.y < 0 or local.y > VIEW_H:
		return -1
	var col := int(local.x / (CELL_W + GAP_X))
	var row := int((local.y + scroll) / (BOX_H + LABEL_H + GAP_Y))
	var idx := row * COLS + col
	if idx < 0 or idx >= buttons.size():
		return -1
	var x := col * (CELL_W + GAP_X)
	var y := row_top(idx)
	if local.x > x + CELL_W or local.y < y or local.y > y + BOX_H + LABEL_H:
		return -1
	return idx


func _draw() -> void:
	if font == null:
		return
	for i in buttons.size():
		var col := i % COLS
		var y := row_top(i)
		if y > VIEW_H or y + BOX_H + LABEL_H < 0:
			continue
		var x := col * (CELL_W + GAP_X)
		var box := Rect2(x, y, CELL_W, BOX_H)
		draw_rect(box, COL_CELL_HOVER if i == hover else COL_CELL)

		var tex: Texture2D = textures.get(buttons[i].get("icon", ""))
		if tex:
			var s: float = minf(box.size.x, box.size.y) * 0.56
			var dst := Rect2(box.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))
			draw_texture_rect(tex, dst, false, Color(0.92, 0.95, 1.0))

		if i == hover:
			draw_rect(box, Color(0.35, 0.69, 1.0, 0.85), false, 1.5)

		var label: String = buttons[i].get("label", "")
		var lr := Rect2(x + CELL_W * 0.04, y + BOX_H, CELL_W * 0.92, LABEL_H)
		draw_rect(lr, COL_LABEL)
		var fs := 17
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw > lr.size.x - 6:
			fs = int(fs * (lr.size.x - 6) / tw)
			tw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(
			font,
			Vector2(lr.get_center().x - tw * 0.5, lr.position.y + lr.size.y * 0.5 + fs * 0.36),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			COL_LABEL_FG
		)

	if max_scroll() > 0:
		var ratio := VIEW_H / content_height()
		var bar_h := VIEW_H * ratio
		var bar_y := (VIEW_H - bar_h) * (scroll / max_scroll())
		draw_rect(Rect2(COLS * CELL_W + (COLS - 1) * GAP_X + 6, 0, 4, VIEW_H), Color(0.6, 0.7, 0.8, 0.14))
		draw_rect(Rect2(COLS * CELL_W + (COLS - 1) * GAP_X + 6, bar_y, 4, bar_h), Color(0.85, 0.93, 1.0, 0.75))
