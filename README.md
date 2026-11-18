# PGR Panel · Godot

战双帕弥什风格的桌面全息面板，Godot 4.7 (GDScript) 重写版。

Web 版（Electron + React，`D:\ui`）已封存，功能与视觉以此项目为准继续演进。

## 当前状态

已跑通：

- 透明无边框窗口（472×554，内部 760×892 画布按 0.621 缩放）
- **透视倾斜**：SubViewport 渲染 + 逆单应矩阵 shader，参数与 Web 版 CSS 一致
- 蓝色面板 + 网格、顶部时间/日期、九宫格、底部快捷图标、镜头球、两片投影光带
- **音乐**：后台线程调 `nowplaying.ps1` 读 SMTC，封面转圆角贴图并顺时针旋转，歌名放不下自动右→左滚动
- **交互**：九宫格 hover 高亮 + 滚轮滚动（带右侧滚动条）、左键点击按 `config.json` 的 actions 打开网址/程序、点镜头球收起/展开
- **窗口**：右键拖动整个挂件（`set_position` 跟手，不再缩放抖动）、位置记忆（`user://window.cfg`）、透明区域点击穿透（`window_set_mouse_passthrough`）

## 下一步

1. **按钮编辑**：右键改文字/图标/目标（`config.json` 已经在读）。
2. **托盘 + 全局热键**：Godot 没有内置托盘，需要 GDExtension 或外部小工具。
3. **本地音乐**：内嵌封面解析、iTunes 在线补图。
4. **设置面板**：缩放、光带透明度、粒子数。
5. **待验证**：点击穿透区域、无损缩放（现在是固定 0.621）、多显示器。

## 运行

```powershell
D:\Tools\Godot\Godot_v4.7.2-stable_win64.exe --path D:\pgr-godot
```

改完脚本直接再跑；首次打开会自动导入 `assets/`。

生成截图（不需要编辑器）：

```powershell
D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --path D:\pgr-godot -- --shot=D:/pgr-godot/out/shot.png
```

## 下一步

1. **透视倾斜**：Web 版用 CSS `perspective(850px) rotateY(-18deg) rotateX(6deg) rotateZ(2.4deg)`，
   是真正的投影变换，2D 仿射做不到。Godot 方案：CanvasItem shader 里对 `uv` 做 3×3 单应矩阵变换，
   或把整个面板绘制到 `SubViewport`，再用 quad 做 3D 变换。
2. **交互**：九宫格滚动（ScrollContainer）、按钮 hover/按下动效、右键改按钮（文字/图标/目标）。
3. **窗口行为**：始终贴桌面（不进 Z 序顶层）、点击穿透（`DisplayServer.window_set_mouse_passthrough` 区域）、
   右键拖动位置并记忆、托盘图标、全局热键。
4. **音乐**：复用 Web 版的 `nowplaying.ps1`（SMTC 读标题/封面），Godot 用 `OS.execute`/`OS.create_process`
   调 PowerShell 并解析 JSON；本地音乐目录内嵌封面用 GDExtension 或外部小工具解析。
5. **设置面板**：缩放、光带透明度、粒子数、在线补封面开关。

## 资产

`assets/icons`、`assets/fonts` 取自游戏客户端，仅作个人学习用途，见 `DISCLAIMER.md`。
