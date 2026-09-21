extends Control
## P2-5：备战界面骨架（把 sim/prep_state.gd 接到可点击控件上）
## 交互（本轮）：点商店买牌 → 点手牌选中 → 点战场空格放置；刷新 / 升级 / 开打按钮
## 下一轮：真拖拽（手牌拖到场上、材料牌拖到机械显示磁力吸附）、合体区电流特效

const UiTheme := preload("res://scripts/ui_theme.gd")
const PrepState := preload("res://sim/prep_state.gd")
const UnitScript := preload("res://sim/unit.gd")
const BattleScript := preload("res://sim/battle.gd")

var ps
var _top: Label
var _shop_row: HBoxContainer
var _hand_row: HBoxContainer
var _board_row: HBoxContainer
var _log: RichTextLabel
var _selected_hand := -1

func _ready() -> void:
	theme = UiTheme.build()
	ps = PrepState.new()
	ps.setup(1, ["mech", "elem"], _demo_pool(), [{"n": "力祝"}], 20260922)
	_build_ui()
	_refresh()
	if OS.get_cmdline_user_args().has("--selftest"):
		print("[prep_scene] 回合=", ps.round_no, " 金币=", ps.gold, " 等级=", ps.level,
			" 商店=", ps.shop.size(), " 手牌=", ps.hand.size(), " 合体区=", ps.has_formation())
		get_tree().quit()

## 演示用卡池：3★ 提供一套可合体的机械四部位，方便在界面里验证合体区高亮
func _demo_pool() -> Dictionary:
	var pool := {}
	for star in range(1, 8):
		var list: Array = []
		for i in range(6):
			list.append({"n": "M%d-%d" % [star, i], "a": star, "h": star, "race": "mech" if i % 2 == 0 else "elem"})
		if star == 3:
			list.append({"n": "磁力底盘", "a": 4, "h": 10, "race": "mech", "part": "core", "k": "t"})
			list.append({"n": "核心学徒", "a": 4, "h": 5, "race": "mech", "part": "head"})
			list.append({"n": "磁能臂", "a": 8, "h": 4, "race": "mech", "part": "arm", "k": "w"})
			list.append({"n": "推进肢体", "a": 3, "h": 12, "race": "mech", "part": "leg", "k": "t"})
		pool[star] = list
	return pool

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	root.add_child(top_row)
	_top = Label.new()
	_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_top)
	var btn_roll := Button.new(); btn_roll.text = "刷新 (1金)"
	btn_roll.pressed.connect(func(): _say("刷新" if ps.reroll() else "金币不足，无法刷新"); _refresh())
	top_row.add_child(btn_roll)
	var btn_level := Button.new(); btn_level.text = "升级"
	btn_level.pressed.connect(func(): _say("升级到 Lv%d" % ps.level if ps.level_up() else "金币不足，无法升级"); _refresh())
	top_row.add_child(btn_level)
	var btn_fight := Button.new(); btn_fight.text = "开打"
	btn_fight.pressed.connect(_fight)
	top_row.add_child(btn_fight)

	root.add_child(_label("商店（点击购买）"))
	_shop_row = HBoxContainer.new(); _shop_row.add_theme_constant_override("separation", 8)
	root.add_child(_shop_row)
	root.add_child(_label("手牌（点手牌 → 点战场空格放置）"))
	_hand_row = HBoxContainer.new(); _hand_row.add_theme_constant_override("separation", 8)
	root.add_child(_hand_row)
	root.add_child(_label("战场（前 4 格为合体区，满足时高亮）"))
	_board_row = HBoxContainer.new(); _board_row.add_theme_constant_override("separation", 8)
	root.add_child(_board_row)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_stylebox_override("normal", UiTheme.panel_style(UiTheme.PANEL_2))
	root.add_child(_log)

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UiTheme.MUTED)
	return l

func _say(text: String) -> void:
	_log.text = text + "\n" + _log.text

func _card_text(c: Dictionary) -> String:
	return "%s\n%d/%d\n%d金" % [String(c.get("n", "?")), int(c.get("a", 0)), int(c.get("h", 0)), ps.buy_cost(c)]

func _refresh() -> void:
	_top.text = "回合 %d   金币 %d   等级 %d   连胜 %d / 连败 %d%s" % [
		ps.round_no, ps.gold, ps.level, ps.win_streak, ps.lose_streak,
		"   合体区就绪！" if ps.has_formation() else ""]

	for child in _shop_row.get_children():
		child.queue_free()
	for i in range(ps.shop.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 76)
		var c = ps.shop[i]
		if c == null:
			b.text = "已购"
			b.disabled = true
		else:
			b.text = _card_text(c)
			b.pressed.connect(func(): _buy(i))
		_shop_row.add_child(b)

	for child in _hand_row.get_children():
		child.queue_free()
	for i in range(ps.hand.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 70)
		b.text = String(ps.hand[i].get("n", "?"))
		if i == _selected_hand:
			b.add_theme_color_override("font_color", UiTheme.ACCENT)
		b.pressed.connect(func(): _select_hand(i))
		_hand_row.add_child(b)

	for child in _board_row.get_children():
		child.queue_free()
	for i in range(ps.board.size()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 70)
		var c = ps.board[i]
		b.text = "+" if c == null else "%s\n%d/%d" % [String(c.get("n", "?")), int(c.get("a", 0)), int(c.get("h", 0))]
		if i < 4:
			b.add_theme_color_override("font_color", UiTheme.ACCENT if ps.has_formation() else UiTheme.BLUE)
		b.pressed.connect(func(): _place(i))
		_board_row.add_child(b)

func _buy(index: int) -> void:
	var r: Dictionary = ps.buy(index)
	if bool(r["ok"]):
		_say("买入 %s（-%d金）" % [String(r["card"].get("n", "?")), int(r["cost"])])
	else:
		_say("买牌失败：钱不够或手牌已满")
	_refresh()

func _select_hand(index: int) -> void:
	_selected_hand = index
	_say("选中手牌：%s" % String(ps.hand[index].get("n", "?")))
	_refresh()

func _place(slot: int) -> void:
	if _selected_hand < 0:
		_say("先点一张手牌再点空格")
		return
	var ok: bool = ps.place(_selected_hand, slot)
	_say("上场成功" if ok else "该格已占用或手牌无效")
	if ok:
		_selected_hand = -1
	_refresh()

func _fight() -> void:
	var prep: Dictionary = ps.prepare_fusion(ps.level / 2, 0, 0)
	var e_board: Array = []
	for i in range(3):
		e_board.append(UnitScript.from_card({"n": "训练假人%d" % (i + 1), "a": 3, "h": 20, "s": 2, "race": "elem"}, i + 100))
	var p_board: Array = []
	var uid := 1
	for c in ps.board:
		if c != null:
			p_board.append(UnitScript.from_card(c, uid))
			uid += 1
	if p_board.is_empty():
		_say("场上没有随从，先买牌上场")
		return
	var r: Dictionary = BattleScript.new().resolve(p_board, e_board, 20260922)
	_say("开打结果：%s，回合 %d，事件 %d 条%s" % [
		"胜" if String(r["winner"]) == "p" else "负", int(r["rounds"]), (r["events"] as Array).size(),
		"，机械战神已合体" if bool(prep.get("ok", false)) else ""])
