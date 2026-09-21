extends Control
## 迁移第一批：卡池/配置浏览器（数据全部来自 res://data，方便后续做内容与平衡）。
## 后续阶段会在此基础上接入 备战流程 / 战斗结算 / AI / 表现层。

const UiTheme := preload("res://scripts/ui_theme.gd")

var _race_option: OptionButton
var _star_option: OptionButton
var _search: LineEdit
var _list: ItemList
var _detail: RichTextLabel
var _stats: Label
var _filtered: Array = []
var _race_ids: Array = ["all"]

func _ready() -> void:
	theme = UiTheme.build()
	_build_ui()
	_fill_filters()
	_refresh()
	# 无头/自检模式：打印一次概览后退出（godot --headless -- --selftest）
	if OS.get_cmdline_user_args().has("--selftest"):
		_print_selftest()
		get_tree().quit()
	# 截图模式：渲染一帧后存图并退出（godot -- --shot）
	if OS.get_cmdline_user_args().has("--shot"):
		_capture_screenshot()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var title := Label.new()
	title.text = "炉石旅人 · 卡池与配置浏览器"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	top.add_child(title)
	_stats = Label.new()
	_stats.add_theme_color_override("font_color", UiTheme.MUTED)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_stats)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	root.add_child(filters)
	filters.add_child(_label("种族"))
	_race_option = OptionButton.new()
	_race_option.custom_minimum_size = Vector2(140, 0)
	_race_option.item_selected.connect(func(_i: int) -> void: _refresh())
	filters.add_child(_race_option)
	filters.add_child(_label("星级"))
	_star_option = OptionButton.new()
	_star_option.custom_minimum_size = Vector2(110, 0)
	_star_option.item_selected.connect(func(_i: int) -> void: _refresh())
	filters.add_child(_star_option)
	filters.add_child(_label("搜索"))
	_search = LineEdit.new()
	_search.placeholder_text = "随从名 / 卡名关键字"
	_search.custom_minimum_size = Vector2(220, 0)
	_search.text_changed.connect(func(_t: String) -> void: _refresh())
	filters.add_child(_search)

	var hint := Label.new()
	hint.text = "数据源：lushi-like/index.html 导出 → res://data/*.json"
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	root.add_child(hint)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 460
	root.add_child(split)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(440, 0)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_card_selected)
	split.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.scroll_active = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_stylebox_override("normal", UiTheme.panel_style(UiTheme.PANEL_2))
	right.add_child(_detail)

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UiTheme.MUTED)
	return l

func _fill_filters() -> void:
	_race_option.clear()
	_race_option.add_item("全部种族")
	_race_ids = ["all"]
	var ids: Array = GameData.races.keys()
	ids.sort_custom(func(a, b): return GameData.race_name(a) < GameData.race_name(b))
	for id in ids:
		_race_ids.append(id)
		_race_option.add_item("%s %s" % [GameData.race_icon(id), GameData.race_name(id)])
	_race_option.select(0)

	_star_option.clear()
	_star_option.add_item("全部星级")
	for s in range(1, GameData.by_star.size() + 1):
		_star_option.add_item("%d★" % s)
	_star_option.select(0)

func _selected_race() -> String:
	var i := _race_option.selected
	if i <= 0 or i >= _race_ids.size():
		return "all"
	return String(_race_ids[i])

func _selected_star() -> int:
	return max(0, _star_option.selected)

func _refresh() -> void:
	_filtered = GameData.filter_cards(_selected_race(), _selected_star(), _search.text if _search else "")
	_list.clear()
	for c in _filtered:
		_list.add_item(_card_line(c))
	if not _filtered.is_empty():
		_list.select(0)
		_show_card(_filtered[0])
	else:
		_detail.text = "[color=#8f98a3]没有符合条件的卡[/color]"
	_stats.text = "卡池 %d 张｜当前筛选 %d 张｜种族 %d 个｜星级 %d 档" % [
		GameData.cards.size(), _filtered.size(), GameData.races.size(), GameData.by_star.size()
	]

func _card_line(c: Dictionary) -> String:
	var star := int(c.get("star", 0))
	var race := String(c.get("race", "neutral"))
	var kind := "随从"
	if c.has("t") and String(c["t"]) == "s":
		kind = "法术"
	var atk := int(c.get("a", 0))
	var hp := int(c.get("h", 0))
	var skill := GameData.skill_id(c)
	var tail := ""
	if skill != "":
		tail = "  · " + skill
	return "%s  %d★  %s  %d/%d  [%s]%s" % ["★".repeat(star), star, String(c.get("n", "?")), atk, hp, GameData.race_name(race), tail]

func _on_card_selected(index: int) -> void:
	if index >= 0 and index < _filtered.size():
		_show_card(_filtered[index])

func _show_card(c: Dictionary) -> void:
	var lines: Array[String] = []
	var star := int(c.get("star", 0))
	var race := String(c.get("race", "neutral"))
	lines.append("[font_size=20][color=#fdcb6e]%s[/color][/font_size]" % String(c.get("n", "?")))
	lines.append("[color=#8f98a3]%s   %s   %d★[/color]" % [GameData.race_icon(race), GameData.race_name(race), star])
	lines.append("")
	lines.append("[color=#ff6b6b]攻击 %d[/color]   [color=#55efc4]生命 %d[/color]" % [int(c.get("a", 0)), int(c.get("h", 0))])
	if c.has("k"):
		lines.append("[color=#74b9ff]关键词：%s[/color]" % String(c["k"]))
	var skill := GameData.skill_id(c)
	if skill != "":
		lines.append("[color=#7bed9f]主技能：%s[/color]" % skill)
	if c.has("bc"):
		lines.append("[color=#a29bfe]战吼：%s[/color]" % JSON.stringify(c["bc"]))
	if c.has("sc") or c.has("scSk"):
		lines.append("[color=#a29bfe]法术联动：%s[/color]" % JSON.stringify(c.get("sc", c.get("scSk"))))
	if c.has("atkSk"):
		lines.append("[color=#a29bfe]攻击联动：%s[/color]" % JSON.stringify(c["atkSk"]))
	lines.append("")
	lines.append("[color=#8f98a3]上阵/商店字段：[/color]")
	lines.append("[code]%s[/code]" % JSON.stringify(c).replace("},{", "},\n{"))
	_detail.text = "\n".join(lines)

func _print_selftest() -> void:
	var per_star: Array[String] = []
	for s in GameData.by_star.keys():
		per_star.append("%d★=%d" % [s, GameData.by_star[s].size()])
	per_star.sort()
	print("[selftest] 卡池总数=", GameData.cards.size())
	print("[selftest] 星级分布: ", " ".join(per_star))
	var per_race: Array[String] = []
	for r in GameData.by_race.keys():
		per_race.append("%s=%d" % [GameData.race_name(r), GameData.by_race[r].size()])
	per_race.sort()
	print("[selftest] 种族分布: ", " ".join(per_race))
	var evolve_names: Array[String] = []
	for c in GameData.by_race.get("evolve", []):
		evolve_names.append(String(c.get("n", "?")))
	print("[selftest] 进化随从: ", " ".join(evolve_names))
	print("[selftest] 酒馆等级花费: ", GameData.config.get("levelCost", []))
	print("[selftest] 宣言池: ", GameData.quests.keys())

func _capture_screenshot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	print("[shot] 列表条目=", _list.item_count, " 选中=", _list.get_selected_items(),
		" 统计=", _stats.text)
	var img := get_viewport().get_texture().get_image()
	var out := "user://godot_card_browser.png"
	img.save_png(out)
	print("[shot] 截图=", ProjectSettings.globalize_path(out), " 尺寸=", img.get_size())
	get_tree().quit()
