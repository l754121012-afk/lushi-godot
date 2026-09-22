extends Control
## 备战界面（按原版 index.html 的布局与配色逐项还原）
## 结构对应：bar → rope → brd(AI侧/我侧) → hand → shop → act → log
## 配色对应：body #1a1a2e / 面板 #16213e / 空槽 #0f0f1a+虚线 #2d3047 / 有牌 #2d3047+实线 #4a4d6b
##          攻击 #ff6b6b / 生命 #55efc4 / 金 #fdcb6e / 次要文字 #636e72 / 按钮 灰·蓝·浅蓝·橙红

const UiTheme := preload("res://scripts/ui_theme.gd")
const PrepState := preload("res://sim/prep_state.gd")
const AI := preload("res://sim/ai.gd")
const UnitScript := preload("res://sim/unit.gd")
const BattleScript := preload("res://sim/battle.gd")
const Economy := preload("res://sim/economy.gd")

const SLOT_W := 80
const SLOT_H := 88
const SHOP_W := 85
const SHOP_H := 75
const HAND_W := 72
const HAND_H := 54
const ZONE_SLOTS := 4
const APP_W := 1000

# —— 原版配色（与 index.html 的 CSS 一一对应）——
const C_BG := Color("1a1a2e")
const C_PANEL := Color("16213e")
const C_SLOT_EMPTY := Color("0f0f1a")
const C_SLOT_FILL := Color("2d3047")
const C_LINE := Color("2d3047")
const C_LINE_FILL := Color("4a4d6b")
const C_NAME := Color("dfe6e9")
const C_ATK := Color("ff6b6b")
const C_HP := Color("55efc4")
const C_GOLD := Color("fdcb6e")
const C_MUTED := Color("636e72")
const C_BLUE := Color("74b9ff")
const C_BTN_REFRESH := Color("636e72")
const C_BTN_FREEZE := Color("0984e3")
const C_BTN_LEVEL := Color("74b9ff")
const C_BTN_FIGHT := Color("e17055")

var ps
var ep
var _hp: Label
var _gold: Label
var _hint: Label
var _round_label: Label
var _level_label: Label
var _rope: RopeBar
var _ai_row: HBoxContainer
var _p_row: HBoxContainer
var _hand_row: HBoxContainer
var _shop_row: HBoxContainer
var _shop_hdr: Label
var _log: RichTextLabel
var _choice_host: VBoxContainer
var _busy := false
var _prep_left := 45.0
var _speed := 1.0
var _selected := -1
var _zone_tween: Tween
var p_hp := 100
var e_hp := 100

func _ready() -> void:
	theme = UiTheme.build()
	ps = PrepState.new()
	ep = PrepState.new()
	ps.setup(1, ["mech", "elem", "star"], _demo_pool(), [{"n": "力祝"}], 20260922)
	ep.setup(1, ["mech", "elem", "star"], _demo_pool(), [{"n": "力祝"}], 20260922 + 777)
	AI.run_turn(ep, ep.races, 4)
	_build()
	_refresh()
	var args := OS.get_cmdline_user_args()
	if args.has("--selftest"):
		print("[prep_view] 回合=", ps.round_no, " 金币=", ps.gold, " 等级=", ps.level,
			" 商店=", ps.shop.size(), " 我方上阵=", _count(ps.board), " AI上阵=", _count(ep.board))
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_dump_layout()
		get_tree().quit()
	if args.has("--shot"):
		_capture(args)

func _count(board: Array) -> int:
	var n := 0
	for c in board:
		if c != null:
			n += 1
	return n

## 布局核对：按原版顺序 bar → rope → AI侧 → 我侧 → 手牌 → 商店 → 操作 → 日志，
## 并检查相邻块不重叠（重叠就是"布局混乱"）
func _dump_layout() -> void:
	var order := ["bar", "rope", "side_ai", "side_p", "hand", "shop", "act", "logpanel"]
	var prev_bottom := -1.0
	var bad := 0
	for n in order:
		var node := find_child(n, true, false)
		if node == null:
			print("[layout] 缺少节点 ", n)
			bad += 1
			continue
		var r: Rect2 = (node as Control).get_global_rect()
		var overlap := r.position.y < prev_bottom - 0.5
		print("[layout] %-9s x=%4d y=%4d w=%4d h=%3d%s" % [n, int(r.position.x), int(r.position.y),
			int(r.size.x), int(r.size.y), "  ← 与上一块重叠" if overlap else ""])
		if overlap:
			bad += 1
		prev_bottom = maxf(prev_bottom, r.end.y)
	print("[layout] 顺序与不重叠检查：", "通过" if bad == 0 else "失败 %d 处" % bad)

## 演示卡池：3★ 提供完整机械四部位，方便在界面里验证合体区
func _demo_pool() -> Dictionary:
	var pool := {}
	var races := ["mech", "elem", "star"]
	for star in range(1, 8):
		var list: Array = []
		for i in range(6):
			list.append({"n": "随从%d-%d" % [star, i], "a": star * 2, "h": star * 3, "s": star, "race": races[i % 3]})
		if star == 3:
			list.append({"n": "磁力底盘", "a": 4, "h": 10, "s": 3, "race": "mech", "part": "core", "k": "t"})
			list.append({"n": "核心学徒", "a": 4, "h": 5, "s": 3, "race": "mech", "part": "head"})
			list.append({"n": "磁能臂", "a": 8, "h": 4, "s": 3, "race": "mech", "part": "arm", "k": "w"})
			list.append({"n": "推进肢体", "a": 3, "h": 12, "s": 3, "race": "mech", "part": "leg", "k": "t"})
		pool[star] = list
	return pool

## ---------- 通用小控件 ----------

func _sb(bg: Color, border: Color, pad: int = 4, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s

func _panel(bg: Color = C_PANEL, pad: int = 4) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(bg, bg, pad))
	return p

func _muted(text: String, size: int = 11) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", C_MUTED)
	return l

func _btn(text: String, bg: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", _sb(bg, bg, 4))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.18), C_GOLD, 4))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.2), bg, 4))
	b.add_theme_stylebox_override("disabled", _sb(C_LINE, C_LINE, 4))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)
	return b

## 卡面：星级 / 名字 / 攻(红)-血(绿)，可选价格
func _fill_card(box: Control, c: Dictionary, w: int, height: int, show_price: bool, part_tag: bool) -> void:
	box.custom_minimum_size = Vector2(w, height)
	var packed: Dictionary = c
	var star := int(packed.get("s", packed.get("star", 1)))
	var is_gold: bool = bool(packed.get("g", false))
	var border: Color = C_GOLD if is_gold else C_LINE_FILL
	box.add_theme_stylebox_override("panel", _sb(C_SLOT_FILL, border, 3))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 3)
	m.add_theme_constant_override("margin_left", 2)
	m.add_theme_constant_override("margin_right", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	box.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(vb)

	var head := Label.new()
	head.text = ("◆" if is_gold else "") + "★".repeat(clampi(star, 1, 7))
	head.add_theme_font_size_override("font_size", 7)
	head.add_theme_color_override("font_color", C_GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)

	var nm := Label.new()
	var part := String(packed.get("part", ""))
	if part == "":
		part = String(packed.get("race", ""))
	nm.text = String(packed.get("n", "?")) + ("\n[" + part + "]" if part_tag and part != "" else "")
	nm.add_theme_font_size_override("font_size", 9)
	nm.add_theme_color_override("font_color", C_NAME)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(nm)

	var ah := HBoxContainer.new()
	ah.alignment = BoxContainer.ALIGNMENT_CENTER
	ah.add_theme_constant_override("separation", 2)
	var a := Label.new()
	a.text = str(int(packed.get("a", 0)))
	a.add_theme_font_size_override("font_size", 13)
	a.add_theme_color_override("font_color", C_ATK)
	var sep := Label.new()
	sep.text = "/"
	sep.add_theme_font_size_override("font_size", 13)
	sep.add_theme_color_override("font_color", C_MUTED)
	var hp_lbl := Label.new()
	hp_lbl.text = str(int(packed.get("h", 0)))
	hp_lbl.add_theme_font_size_override("font_size", 13)
	hp_lbl.add_theme_color_override("font_color", C_HP)
	ah.add_child(a); ah.add_child(sep); ah.add_child(hp_lbl)
	vb.add_child(ah)

	if show_price:
		var price := Label.new()
		price.text = "%d金" % ps.buy_cost(packed)
		price.add_theme_font_size_override("font_size", 10)
		price.add_theme_color_override("font_color", C_GOLD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(price)

## ---------- 构建 ----------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = _side_margin()
	root.offset_right = -_side_margin()
	root.add_theme_constant_override("separation", 3)
	add_child(root)
	get_viewport().size_changed.connect(func():
		root.offset_left = _side_margin()
		root.offset_right = -_side_margin())

	root.add_child(_build_bar())
	root.get_child(root.get_child_count() - 1).name = "bar"
	_rope = RopeBar.new()
	_rope.name = "rope"
	_rope.add_theme_font_override("font", UiTheme.cjk_font())
	root.add_child(_rope)
	# 对应原版 #brd{flex:1}：两块战场占据剩余高度
	var brd := VBoxContainer.new()
	brd.name = "brd"
	brd.add_theme_constant_override("separation", 3)
	brd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brd.add_child(_build_side("AI", true)); brd.get_child(brd.get_child_count() - 1).name = "side_ai"
	brd.add_child(_build_side("我", false)); brd.get_child(brd.get_child_count() - 1).name = "side_p"
	root.add_child(brd)
	root.add_child(_build_hand()); root.get_child(root.get_child_count() - 1).name = "hand"
	root.add_child(_build_shop()); root.get_child(root.get_child_count() - 1).name = "shop"
	root.add_child(_build_actions()); root.get_child(root.get_child_count() - 1).name = "act"
	_choice_host = VBoxContainer.new()
	root.add_child(_choice_host)
	root.add_child(_build_log()); root.get_child(root.get_child_count() - 1).name = "logpanel"

func _side_margin() -> float:
	return maxf(4.0, (get_viewport_rect().size.x - APP_W) * 0.5)

func _build_bar() -> PanelContainer:
	var bar := _panel(C_PANEL, 4)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	bar.add_child(hb)
	_hp = Label.new()
	_hp.add_theme_font_size_override("font_size", 12)
	_hp.add_theme_color_override("font_color", C_ATK)
	hb.add_child(_hp)
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", 12)
	_gold.add_theme_color_override("font_color", C_GOLD)
	hb.add_child(_gold)
	_hint = _muted("")
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_hint)
	_round_label = _muted("⏱1")
	hb.add_child(_round_label)
	_level_label = _muted("酒馆Lv1")
	hb.add_child(_level_label)
	hb.add_child(_btn("设置", C_SLOT_FILL, func(): _say("设置面板后续接入")))
	return bar

func _build_side(title: String, is_ai: bool) -> PanelContainer:
	var side := _panel(C_PANEL, 4)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	side.add_child(vb)
	var head := _muted(title, 11)
	vb.add_child(head)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 6)
	vb.add_child(who)
	var dot := Label.new()
	dot.text = "AI" if is_ai else "ME"
	dot.add_theme_font_size_override("font_size", 10)
	dot.add_theme_color_override("font_color", Color.WHITE)
	dot.custom_minimum_size = Vector2(28, 0)
	dot.add_theme_stylebox_override("normal", _sb(Color("5c2e2e") if is_ai else Color("2d4a2d"),
		Color("8b4513") if is_ai else Color("4caf50"), 2, 14))
	who.add_child(dot)
	var hp_lbl := _muted("HP:100", 11)
	who.add_child(hp_lbl)
	if is_ai:
		hp_lbl.name = "ai_hp"
	else:
		hp_lbl.name = "p_hp"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	vb.add_child(row)
	if is_ai:
		_ai_row = row
	else:
		_p_row = row
	return side

func _build_hand() -> PanelContainer:
	var p := _panel(C_PANEL, 4)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	vb.add_child(_muted("手牌", 11))
	_hand_row = HBoxContainer.new()
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_row.add_theme_constant_override("separation", 4)
	vb.add_child(_hand_row)
	p.custom_minimum_size = Vector2(0, 4 + 14 + HAND_H + 6)
	return p

func _build_shop() -> PanelContainer:
	var p := _panel(C_PANEL, 4)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	_shop_hdr = Label.new()
	_shop_hdr.add_theme_font_size_override("font_size", 12)
	_shop_hdr.add_theme_color_override("font_color", C_MUTED)
	vb.add_child(_shop_hdr)
	_shop_row = HBoxContainer.new()
	_shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_row.add_theme_constant_override("separation", 4)
	vb.add_child(_shop_row)
	return p

func _build_actions() -> HBoxContainer:
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 4)
	act.add_child(_btn("🔄刷新", C_BTN_REFRESH, func(): _do_reroll()))
	act.add_child(_btn("❄️冻结", C_BTN_FREEZE, func(): _say("冻结功能后续接入")))
	act.add_child(_btn("升级", C_BTN_LEVEL, func(): _do_level()))
	act.add_child(_btn("开打", C_BTN_FIGHT, func(): _fight()))
	act.add_child(_btn("速度 x1", C_SLOT_FILL, func(): _toggle_speed(act)))
	return act

func _toggle_speed(act: HBoxContainer) -> void:
	_speed = 2.0 if _speed < 2.0 else 1.0
	for child in act.get_children():
		if child is Button and String(child.text).begins_with("速度"):
			child.text = "速度 x%d" % int(_speed)

func _build_log() -> PanelContainer:
	var p := _panel(C_SLOT_EMPTY, 2)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = true
	_log.custom_minimum_size = Vector2(0, 96)
	_log.add_theme_font_size_override("normal_font_size", 11)
	_log.add_theme_color_override("default_color", C_MUTED)
	p.add_child(_log)
	return p

## ---------- 刷新 ----------

func _refresh() -> void:
	_hp.text = "❤ %d" % p_hp
	_gold.text = "🪙 %d" % ps.gold
	_hint.text = "本回合剩余 %d 金：不结转，下回合基准 %d 金" % [ps.gold, Economy.round_base_gold(ps.round_no + 1)]
	_round_label.text = "⏱%d" % ps.round_no
	_level_label.text = "酒馆Lv%d  🪙%d" % [ps.level, ep.gold]
	_shop_hdr.text = "🏪 Lv%d → Lv%d   🪙%d%s" % [ps.level, ps.level + 1,
		Economy.level_up_cost(ps.level), ("  免费刷新×%d" % ps.free_refresh) if ps.free_refresh > 0 else ""]

	_fill_board(_ai_row, ep.board, false)
	_fill_board(_p_row, ps.board, true)

	for c in _hand_row.get_children():
		c.queue_free()
	for i in range(ps.hand.size()):
		var card := Draggable.new()
		card.host = self
		card.index = i
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		_fill_card(card, ps.hand[i], HAND_W, HAND_H, false, false)
		if i == _selected:
			card.add_theme_stylebox_override("panel", _sb(C_SLOT_FILL, C_GOLD, 3))
		_hand_row.add_child(card)

	for c in _shop_row.get_children():
		c.queue_free()
	for i in range(ps.shop.size()):
		var card := Dropless.new()
		card.index = i
		card.host = self
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var data = ps.shop[i]
		if data == null:
			card.add_theme_stylebox_override("panel", _sb(C_SLOT_EMPTY, C_LINE, 3))
			var sold := _muted("已购", 10)
			card.add_child(sold)
		else:
			_fill_card(card, data, SHOP_W, SHOP_H, true, false)
		_shop_row.add_child(card)

	_update_zone_pulse()

func _fill_board(row: HBoxContainer, board: Array, is_mine: bool) -> void:
	for c in row.get_children():
		c.queue_free()
	var zone_ready: bool = is_mine and ps.has_formation()
	for i in range(board.size()):
		var slot := DropSlot.new()
		slot.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
		slot.host = self
		slot.slot = i
		slot.is_mine = is_mine
		slot.zone = is_mine and i < ZONE_SLOTS
		slot.zone_ready = zone_ready
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var data = board[i]
		var bg := C_SLOT_EMPTY if data == null else C_SLOT_FILL
		var line := C_LINE if data == null else C_LINE_FILL
		if data != null and bool(data.get("g", false)):
			line = C_GOLD
		slot.add_theme_stylebox_override("panel", _sb(bg, line, 0))
		if data != null and is_mine and i < ZONE_SLOTS and zone_ready:
			slot.add_theme_stylebox_override("panel", _sb(bg, C_GOLD, 0))

		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_top", 12)
		m.add_theme_constant_override("margin_left", 4)
		m.add_theme_constant_override("margin_right", 4)
		m.add_theme_constant_override("margin_bottom", 6)
		slot.add_child(m)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		m.add_child(vb)
		if data == null:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 16)
			plus.add_theme_color_override("font_color", C_MUTED)
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(plus)
		else:
			var head := Label.new()
			head.text = ("◆" if bool(data.get("g", false)) else "") + "★".repeat(clampi(int(data.get("s", data.get("star", 1))), 1, 7))
			head.add_theme_font_size_override("font_size", 7)
			head.add_theme_color_override("font_color", C_GOLD)
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(head)
			var part := String(data.get("part", ""))
			var nm := Label.new()
			nm.text = String(data.get("n", "?")) + (("\n[" + part + "]") if part != "" else "")
			nm.add_theme_font_size_override("font_size", 9)
			nm.add_theme_color_override("font_color", C_NAME)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(nm)
			var spacer := Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			vb.add_child(spacer)
			var ah := HBoxContainer.new()
			ah.alignment = BoxContainer.ALIGNMENT_CENTER
			ah.add_theme_constant_override("separation", 2)
			var a := Label.new(); a.text = str(int(data.get("a", 0)))
			a.add_theme_font_size_override("font_size", 13)
			a.add_theme_color_override("font_color", C_ATK)
			var sep := Label.new(); sep.text = "/"
			sep.add_theme_font_size_override("font_size", 13)
			sep.add_theme_color_override("font_color", C_MUTED)
			var h := Label.new(); h.text = str(int(data.get("h", 0)))
			h.add_theme_font_size_override("font_size", 13)
			h.add_theme_color_override("font_color", C_HP)
			ah.add_child(a); ah.add_child(sep); ah.add_child(h)
			vb.add_child(ah)
		var decor := SlotDecor.new()
		decor.zone = slot.zone
		decor.zone_ready = slot.zone_ready
		decor.has_card = data != null
		decor.hp_ratio = 1.0 if data == null else clampf(float(data.get("h", 1)) / maxf(1.0, float(data.get("mh", data.get("h", 1)))), 0.0, 1.0)
		decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(decor)
		decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if is_mine and i < ZONE_SLOTS and data != null:
			slot.tooltip_text = "合体区 · 第 %d 格" % (i + 1)
		row.add_child(slot)

func _update_zone_pulse() -> void:
	if _zone_tween != null and _zone_tween.is_valid():
		_zone_tween.kill()
	var zone_nodes: Array = []
	for i in range(min(ZONE_SLOTS, _p_row.get_child_count())):
		zone_nodes.append(_p_row.get_child(i))
	if not ps.has_formation():
		for n in zone_nodes:
			n.modulate = Color(1, 1, 1, 1)
		return
	_zone_tween = create_tween().set_loops()
	for n in zone_nodes:
		_zone_tween.parallel().tween_property(n, "modulate", Color(1, 1, 1, 0.62), 0.6).set_trans(Tween.TRANS_SINE)
		_zone_tween.parallel().tween_property(n, "modulate", Color(1, 1, 1, 1.0), 0.6).set_delay(0.6).set_trans(Tween.TRANS_SINE)

## ---------- 操作 ----------

func _say(text: String) -> void:
	if _log != null:
		_log.text = text + "\n" + _log.text

func _do_reroll() -> void:
	_say("刷新" if ps.reroll() else "金币不足，无法刷新")
	_refresh()

func _do_level() -> void:
	_say("升级到 Lv%d" % ps.level if ps.level_up() else "金币不足，无法升级")
	_refresh()

func _buy(index: int) -> void:
	var r: Dictionary = ps.buy(index)
	if bool(r["ok"]):
		_say("买入 %s（-%d金）" % [String(r["card"].get("n", "?")), int(r["cost"])])
	else:
		_say("买牌失败：钱不够或手牌已满")
	_refresh()

func begin_drag(index: int) -> void:
	_selected = index
	if index >= 0 and index < ps.hand.size():
		var c = ps.hand[index]
		var is_mat: bool = c.has("magA") or c.has("magH")
		_say("拖动 %s%s" % [String(c.get("n", "?")), "（材料牌：拖到机械上磁力强化）" if is_mat else ""])

func drop_on_slot(hand_index: int, slot: int) -> void:
	if hand_index < 0 or hand_index >= ps.hand.size():
		return
	var c = ps.hand[hand_index]
	var target = ps.board[slot]
	var is_mat: bool = c.has("magA") or c.has("magH")
	if is_mat and target != null and String(target.get("race", "")) == "mech":
		var r: Dictionary = ps.feed(hand_index, slot)
		if bool(r["ok"]):
			_say("磁力强化：%s → %s（+%d/+%d）" % [String(c.get("n", "?")), String(target.get("n", "?")),
				int(r["gained"]["a"]), int(r["gained"]["h"])])
		else:
			_say("磁力喂料失败")
	elif ps.place(hand_index, slot):
		_say("上场：%s" % String(c.get("n", "?")))
		_selected = -1
	else:
		_say("该格已占用，或这张牌不能这样用")
	_refresh()

## ---------- 战斗与回合 ----------

func _fight() -> void:
	if _busy:
		return
	var prep: Dictionary = ps.prepare_fusion(ps.level / 2, 0, 0)
	ep.prepare_fusion(ep.level / 2, 0, 0)
	var p_board := _to_units(ps.board, 1)
	var e_board := _to_units(ep.board, 101)
	if p_board.is_empty():
		_say("场上没有随从，先买牌上场")
		return
	if e_board.is_empty():
		e_board.append(UnitScript.from_card({"n": "训练假人", "a": 3, "h": 20, "s": 2, "race": "elem"}, 999))
	var r: Dictionary = BattleScript.new().resolve(p_board, e_board, 20260922)
	_say("开打结果：%s，回合 %d，事件 %d 条%s" % [
		"胜" if String(r["winner"]) == "p" else "负", int(r["rounds"]), (r["events"] as Array).size(),
		"，机械战神已合体" if bool(prep.get("ok", false)) else ""])
	var names := {}
	for u in p_board:
		names[u.uid] = u.card_name
	for u in e_board:
		names[u.uid] = u.card_name
	_busy = true
	for line in _battle_narrative(r["events"], names, 18):
		_say(line)
		await get_tree().create_timer(0.28 / maxf(0.5, _speed)).timeout
	_busy = false
	if String(r["winner"]) == "p":
		ps.win_streak += 1
		ps.lose_streak = 0
	elif String(r["winner"]) == "e":
		ps.lose_streak += 1
		ps.win_streak = 0
	_advance_round()
	_refresh()

func _to_units(board: Array, base_uid: int) -> Array:
	var out: Array = []
	var uid := base_uid
	for c in board:
		if c != null:
			out.append(UnitScript.from_card(c, uid))
			uid += 1
	return out

func _advance_round() -> void:
	ps.round_no += 1
	ep.round_no += 1
	ps.gold = Economy.round_income(ps.round_no, ps.win_streak, ps.lose_streak)
	ep.gold = Economy.round_income(ep.round_no, ps.lose_streak, ps.win_streak)
	ps.roll_shop()
	ep.roll_shop()
	AI.run_turn(ep, ep.races, 5)
	_prep_left = 45.0
	if ps.round_no == 3 or ps.round_no == 6 or ps.round_no == 9:
		_show_round_choice(ps.round_no)

func _show_round_choice(r: int) -> void:
	var gain: int = (r / 3) * 2
	var free: int = 1 if r == 3 else 2
	_say("【第 %d 回合选择】请在下方三选一" % r)
	var panel := HBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	panel.add_child(_btn("+%d 金" % gain, C_BTN_LEVEL, func(): ps.gold += gain; panel.queue_free(); _refresh()))
	panel.add_child(_btn("免费刷新 ×%d" % free, C_BTN_FREEZE, func(): ps.free_refresh += free; panel.queue_free(); _refresh()))
	panel.add_child(_btn("+1金 +1刷新", C_BTN_REFRESH, func(): ps.gold += 1; ps.free_refresh += 1; panel.queue_free(); _refresh()))
	_choice_host.add_child(panel)

func _battle_narrative(events: Array, names: Dictionary, max_lines: int = 18) -> Array[String]:
	var out: Array[String] = []
	var uname := func(id) -> String: return String(names.get(int(id), "单位%d" % int(id)))
	for ev in events:
		match String(ev.get("t", "")):
			"attack":
				out.append("%s 出手 → %s（%d）" % [uname.call(ev["src"]), uname.call(ev["dst"]), int(ev.get("atk", 0))])
			"damage":
				out.append("    %s 受 %d 伤害 → HP %d%s" % [uname.call(ev["dst"]), int(ev.get("dmg", 0)), int(ev.get("hp", 0)),
					"（协同）" if ev.get("follow", 0) else ("（回响）" if ev.get("echo", 0) else "")])
			"shield_break": out.append("    圣盾破碎")
			"taunt_break": out.append("    嘲讽被打破")
			"death": out.append("%s 阵亡" % String(ev.get("name", "?")))
			"buff": out.append("    %s 成长 +%d/+%d" % [uname.call(ev["id"]), int(ev.get("a", 0)), int(ev.get("h", 0))])
			"evop": out.append("    %s 进化 %d/%d" % [uname.call(ev["id"]), int(ev.get("evo", 0)), int(ev.get("need", 3))])
			"evo_full": out.append("    %s 满格质变！" % uname.call(ev["id"]))
			"evolve": out.append("    %s 完成质变（%s）" % [uname.call(ev["id"]), String(ev.get("kind", ""))])
			"gene": out.append("    %s 吞噬基因 %d/5" % [uname.call(ev["id"]), int(ev.get("gene", 0))])
			"armor": out.append("    维修护甲吸收 %d（剩 %d）" % [int(ev.get("absorbed", 0)), int(ev.get("left", 0))])
			"debt": out.append("    债务 → %d（节点 %d）" % [int(ev.get("debt", 0)), int(ev.get("tier", 0))])
			"debt_settle": out.append("    债务结算 %d 点 → 全献祭 +%d/+%d" % [int(ev.get("need", 0)), int(ev.get("a", 0)), int(ev.get("h", 0))])
			"ch": out.append("    %s 充能 %d/%d" % [uname.call(ev["id"]), int(ev.get("c", 0)), int(ev.get("cm", 0))])
			"end": out.append("—— 战斗结束 ——")
		if out.size() >= max_lines:
			out.append("……（共 %d 条事件）" % events.size())
			break
	return out

## ---------- 倒计时 ----------

func _process(delta: float) -> void:
	if _busy or ps == null or _rope == null:
		return
	_prep_left -= delta
	if _prep_left <= 0.0:
		_prep_left = 45.0
		_say("⏳ 备战时间到，自动开打")
		_fight()
	_rope.left_ratio = clampf(_prep_left / 45.0, 0.0, 1.0)
	_rope.label = "备战 %ds" % int(maxf(0.0, _prep_left))
	_rope.burning = _prep_left <= 10.0
	_rope.queue_redraw()

func _capture(args: PackedStringArray) -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	var img := get_viewport().get_texture().get_image()
	var path := "user://prep_view.png"
	img.save_png(path)
	print("[shot] ", ProjectSettings.globalize_path(path), " 尺寸=", img.get_size(),
		" 商店=", ps.shop.size(), " 手牌=", ps.hand.size())
	get_tree().quit()

## ---------- 拖拽与装饰（内部类） ----------

class Draggable extends PanelContainer:
	var host
	var index := -1
	func _get_drag_data(_pos: Vector2):
		if host != null:
			host.begin_drag(index)
		var preview := Label.new()
		preview.text = "  拖拽中  "
		preview.add_theme_color_override("font_color", C_GOLD)
		set_drag_preview(preview)
		return {"kind": "hand", "index": index}

class Dropless extends PanelContainer:
	var host
	var index := -1
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and host != null:
			host._buy(index)

class DropSlot extends PanelContainer:
	var host
	var slot := -1
	var is_mine := true
	var zone := false
	var zone_ready := false
	func _can_drop_data(_pos: Vector2, data) -> bool:
		return is_mine and data is Dictionary and String(data.get("kind", "")) == "hand"
	func _drop_data(_pos: Vector2, data) -> void:
		if host != null:
			host.drop_on_slot(int(data.get("index", -1)), slot)

## 槽位装饰：空槽虚线框 / 合体区描边（就绪转金色实线）/ 底部生命条（对应原版 .sl::after 与 .hpbar）
class SlotDecor extends Control:
	var zone := false
	var zone_ready := false
	var has_card := false
	var hp_ratio := 1.0
	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		if zone and has_card:
			var col: Color = C_GOLD if zone_ready else Color(0.455, 0.725, 1.0, 0.65)
			if zone_ready:
				draw_rect(r, col, false, 2.0)
			else:
				_dashed(r, col, 2.0, 5.0)
		if has_card:
			var w: float = maxf(0.0, (size.x - 2.0) * hp_ratio)
			if w > 0.0:
				draw_rect(Rect2(Vector2(1, size.y - 4), Vector2(w, 3)), C_HP)
	func _dashed(r: Rect2, col: Color, w: float, dash: float) -> void:
		var x := r.position.x
		while x < r.end.x:
			var seg: float = minf(dash, r.end.x - x)
			draw_line(Vector2(x, r.position.y), Vector2(x + seg, r.position.y), col, w)
			draw_line(Vector2(x, r.end.y), Vector2(x + seg, r.end.y), col, w)
			x += dash * 2.0
		var y := r.position.y
		while y < r.end.y:
			var seg2: float = minf(dash, r.end.y - y)
			draw_line(Vector2(r.position.x, y), Vector2(r.position.x, y + seg2), col, w)
			draw_line(Vector2(r.end.x, y), Vector2(r.end.x, y + seg2), col, w)
			y += dash * 2.0

## 备战倒计时条（对应原版 #rope：底槽 + 渐变填充 + 燃烧告警）
class RopeBar extends Panel:
	var left_ratio := 1.0
	var label := "备战 45s"
	var burning := false
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 10)
		var lbl := Label.new()
		lbl.name = "txt"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.offset_right = -6
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.06, 0.06, 0.1, 0.9), true)
		var w: float = maxf(0.0, r.size.x * left_ratio)
		if w > 0.0:
			var fill := Color("ff6b6b") if burning else Color("7bed9f")
			draw_rect(Rect2(Vector2.ZERO, Vector2(w, r.size.y)), fill, true)
		draw_rect(r, Color("ff6b6b") if burning else Color("2d3047"), false, 1.0)
		var lbl = get_node_or_null("txt")
		if lbl != null:
			lbl.text = label
			lbl.add_theme_color_override("font_color", Color("ff9c9c") if burning else Color.WHITE)
