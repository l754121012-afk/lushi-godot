extends RefCounted
## 统一 UI 主题：深色底 + 系统中文字体（Godot 默认字体不含 CJK，中文会变方块）。

const BG := Color("1a1a2e")
const PANEL := Color("16213e")
const PANEL_2 := Color("0f0f1a")
const LINE := Color("2d3047")
const TEXT := Color("dfe6e9")
const MUTED := Color("8f98a3")
const ACCENT := Color("fdcb6e")
const GREEN := Color("7bed9f")
const BLUE := Color("74b9ff")
const SUBTLE := Color("b2bec3")
const PURPLE := Color("a29bfe")
const RED := Color("ff6b6b")

static func _system_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Segoe UI", "Microsoft YaHei UI", "Microsoft YaHei", "微软雅黑",
		"SimHei", "Noto Sans CJK SC", "Source Han Sans SC", "sans-serif",
	])
	f.allow_system_fallback = true
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

static func cjk_font() -> Font:
	return _system_font()

static func cjk_font_bold() -> Font:
	var f := _system_font()
	f.font_weight = 700
	return f

static func symbol_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI"])
	f.allow_system_fallback = true
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return f

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = cjk_font()
	theme.default_font_size = 14

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = LINE
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(8)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("2d3047")
	btn.border_color = LINE
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(4)
	btn.set_content_margin_all(8)
	theme.set_stylebox("normal", "Button", btn)
	var btn_hover := btn.duplicate()
	btn_hover.border_color = ACCENT
	theme.set_stylebox("hover", "Button", btn_hover)
	var btn_press := btn.duplicate()
	btn_press.bg_color = Color("3a3f60")
	theme.set_stylebox("pressed", "Button", btn_press)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "RichTextLabel", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	return theme

static func panel_style(color: Color = PANEL, border: Color = LINE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb
