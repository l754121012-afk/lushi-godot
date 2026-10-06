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
const MechanicStyle := preload("res://scripts/mechanic_style.gd")
const Quest := preload("res://sim/quest.gd")

const SLOT_W := 80
const SLOT_H := 88
const SHOP_W := 85
const SHOP_H := 75
const HAND_W := 72
const HAND_H := 54
const ZONE_SLOTS := 4
const APP_W := 992
const PREP_SECONDS := 50.0
const ROUND_CHOICE_SECONDS := 15.0

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
const C_SUBTLE := Color("b2bec3")
const C_TAUNT_EDGE := Color("8f98a3")
const C_TAUNT_INNER := Color("dbe2e8")
const C_TAUNT_OUTER := Color("5c6672")
const C_SHIELD_EDGE := Color("8a6d3a")
const C_SHIELD_INNER := Color("e0c07f")
const C_SHIELD_OUTER := Color("5d4622")
const C_BTN_REFRESH := Color("636e72")
const C_BTN_FREEZE := Color("0984e3")
const C_BTN_LEVEL := Color("74b9ff")
const C_BTN_FIGHT := Color("e17055")
const C_CONTRACT := Color("a29bfe")
const C_DEVOUR := Color("ff4d4d")

var ps
var ep
var _hp: Label
var _gold: Label
var _hint: Label
var _round_label: Label
var _level_label: Label
var _mech_stat: Label
var _phase_label: Label
var _quest_label: Button
var _quest_buttons: Array[Button] = []
var _sigil_slot
var _rope: RopeBar
var _ai_row: HBoxContainer
var _p_row: HBoxContainer
var _hand_row: HBoxContainer
var _shop_row: HBoxContainer
var _shop_hdr: Label
var _log: RichTextLabel
var _choice_host: Control
var _choice_overlay: Control
var _choice_countdown: Label
var _choice_options: Array[Dictionary] = []
var _round_choice_time_left := 0.0
var _round_choice_round := 0
var _round_choice_callbacks: Array[Callable] = []
var _round_choice_buttons: Array[Button] = []
var _round_choice_active := false
var _sel_bar: HBoxContainer
var _sel_label: Label
var _spell_arrow: SpellTargetArrow
var _sel_info_btn: Button
var _sel_contract_btn: Button
var _sel_sell_btn: Button
var _sel_cancel_btn: Button
var _freeze_btn: Button
var _freeze_overlay: Control
var _p_avatar: Control
var _e_avatar: Control
var _action_buttons: Array[Button] = []
var _busy := false
var _game_over := false
var _prep_left := PREP_SECONDS
var _speed := 1.0
var _selected := -1
var _selected_slot := -1
var _contract_slot := -1
var _drag_source_slot := -1
var _zone_tween: Tween
var _tooltip_panel: PanelContainer
var _tooltip_label: RichTextLabel
var _tooltip_source: Control
var _tooltip_num_regex: RegEx
var _start_overlay: Control
var _start_diff_buttons: Array[Button] = []
var _race_reveal_overlay: Control
var _race_reveal_clicked := false
var _modal_overlay: Control
var _ai_actions_per_round := 40
var _ai_difficulty := 2
var p_hp := 100
var e_hp := 100
var _battle_frames := 0
var _battle_p_board: Array = []
var _battle_e_board: Array = []
var _battle_fx_trace: Array[String] = []
var _battle_pulse_trace: Array[String] = []
var _sfx_trace: Array[String] = []
var _drop_preview_trace: Array[String] = []
var _interaction_fx_trace: Array[String] = []
var _active_drop_target: Control
var _music_volume := 77.0
var _sfx_volume := 70.0
var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _hit_stream: AudioStream
var _input_debug := false
var _drop_guard_until_msec := 0
var _suppress_board_select_until_msec := 0
var _game_seed := 20260922

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_input_debug = args.has("--input-debug")
	var automated := args.has("--shot") or args.has("--interaction-test") or args.has("--selftest") or args.has("--flow-test") or args.has("--battle-anim-test") or args.has("--sacrifice-test") or args.has("--evolve-test") or args.has("--quest-test") or args.has("--mech-test") or args.has("--dragon-test") or args.has("--star-test") or args.has("--undead-test") or args.has("--families-test") or args.has("--random-start-test")
	_game_seed = _resolve_game_seed(automated)
	theme = UiTheme.build()
	_setup_audio()
	ps = PrepState.new()
	ep = PrepState.new()
	if GameData.cards.is_empty():
		GameData.reload()
	var active_races: Array = _pick_races(_game_seed, 6)
	ps.setup(1, active_races, GameData.by_star, GameData.spells, _game_seed, GameData.quests)
	ep.setup(1, active_races, GameData.by_star, GameData.spells, _game_seed + 777, GameData.quests)
	ep.shop_bias_enabled = false
	ps.ensure_quest()
	ep.ensure_quest()
	AI.run_turn(ep, ep.races, 4, _ai_actions_per_round, ps.board, GameData.ai_templates)
	if args.has("--shot"):
		_apply_shot_fixture()
	elif args.has("--battle-anim-test"):
		_apply_battle_anim_fixture()
	elif args.has("--sacrifice-test"):
		_apply_sacrifice_fixture()
	elif args.has("--mech-test"):
		_apply_mech_fixture()
	_build()
	_refresh()
	if not automated:
		_busy = true
		_show_start_screen()
	if args.has("--interaction-test"):
		var interaction_ok: bool = await _interaction_test()
		get_tree().quit(0 if interaction_ok else 1)
		return
	if args.has("--flow-test"):
		_busy = true
		_show_start_screen()
		var flow_ok: bool = await _flow_test()
		get_tree().quit(0 if flow_ok else 1)
		return
	if args.has("--battle-anim-test"):
		var animation_ok: bool = await _battle_anim_test()
		get_tree().quit(0 if animation_ok else 1)
		return
	if args.has("--sacrifice-test"):
		var sacrifice_ok: bool = await _sacrifice_test()
		get_tree().quit(0 if sacrifice_ok else 1)
		return
	if args.has("--evolve-test"):
		var evolve_ok: bool = await _evolve_test()
		get_tree().quit(0 if evolve_ok else 1)
		return
	if args.has("--quest-test"):
		var quest_ok: bool = await _quest_test()
		get_tree().quit(0 if quest_ok else 1)
		return
	if args.has("--mech-test"):
		var mech_ok: bool = await _mech_test()
		get_tree().quit(0 if mech_ok else 1)
		return
	if args.has("--dragon-test"):
		var dragon_ok: bool = await _dragon_test()
		get_tree().quit(0 if dragon_ok else 1)
		return
	if args.has("--star-test"):
		var star_ok: bool = await _star_test()
		get_tree().quit(0 if star_ok else 1)
		return
	if args.has("--undead-test"):
		var undead_ok: bool = await _undead_test()
		get_tree().quit(0 if undead_ok else 1)
		return
	if args.has("--families-test"):
		var families_ok: bool = await _families_test()
		get_tree().quit(0 if families_ok else 1)
		return
	if args.has("--random-start-test"):
		var random_start_ok: bool = _random_start_test()
		get_tree().quit(0 if random_start_ok else 1)
		return
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

func _pick_races(seed_value: int, count: int) -> Array:
	var pool: Array = GameData.races.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var picked: Array = []
	while picked.size() < count and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)
	return picked

func _resolve_game_seed(automated: bool) -> int:
	if automated:
		return 20260922
	var ticks := Time.get_ticks_usec()
	var wall_clock := int(Time.get_unix_time_from_system() * 1000.0)
	return abs((ticks ^ wall_clock) & 0x7fffffff)

## ---------- 开始页与原版一致的种族揭示 ----------

func _show_start_screen() -> void:
	_busy = true
	_prep_left = PREP_SECONDS
	_start_overlay = Control.new()
	_start_overlay.name = "start_overlay"
	_start_overlay.z_index = 100
	_start_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_start_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_start_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_start_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "炉石旅人"
	title.add_theme_font_override("font", UiTheme.cjk_font_bold())
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := _muted("酒馆战棋", 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var difficulty := Label.new()
	difficulty.text = "AI难度"
	difficulty.add_theme_font_size_override("font_size", 13)
	difficulty.add_theme_color_override("font_color", C_SUBTLE)
	difficulty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty.custom_minimum_size = Vector2(0, 28)
	difficulty.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(difficulty)

	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 8)
	box.add_child(diff_row)
	_start_diff_buttons = [
		_difficulty_button("简单", Color("636e72"), 1),
		_difficulty_button("中等", Color("b8860b"), 2),
		_difficulty_button("困难", Color("8b0000"), 3),
	]
	for button in _start_diff_buttons:
		diff_row.add_child(button)
	_select_difficulty(2)

	var start_btn := _btn("开始游戏", C_SLOT_FILL, _begin_game_from_start)
	start_btn.name = "start_button"
	start_btn.custom_minimum_size = Vector2(180, 52)
	start_btn.add_theme_font_size_override("font_size", 16)
	start_btn.add_theme_stylebox_override("normal", _sb(C_SLOT_FILL, C_LINE_FILL, 8, 8))
	start_btn.add_theme_stylebox_override("hover", _sb(C_SLOT_FILL.lightened(0.10), C_GOLD, 8, 8))
	start_btn.add_theme_stylebox_override("pressed", _sb(C_SLOT_FILL.darkened(0.18), C_LINE_FILL, 8, 8))
	box.add_child(start_btn)

func _difficulty_button(text: String, color: Color, difficulty: int) -> Button:
	var button := _btn(text, color, func() -> void: _select_difficulty(difficulty))
	button.custom_minimum_size = Vector2(100, 40)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _sb(color, C_LINE_FILL, 10, 6))
	button.add_theme_stylebox_override("hover", _sb(color.lightened(0.15), C_GOLD, 10, 6))
	button.add_theme_stylebox_override("pressed", _sb(color.darkened(0.18), C_LINE_FILL, 10, 6))
	return button

func _select_difficulty(difficulty: int) -> void:
	_ai_actions_per_round = [16, 40, 60][clampi(difficulty - 1, 0, 2)]
	_ai_difficulty = clampi(difficulty, 1, 3)
	for i in range(_start_diff_buttons.size()):
		var button := _start_diff_buttons[i]
		var normal := button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		normal.border_color = C_GOLD if i == difficulty - 1 else C_LINE_FILL
		normal.set_border_width_all(2 if i == difficulty - 1 else 1)
		button.add_theme_stylebox_override("normal", normal)

func _begin_game_from_start() -> void:
	if _start_overlay != null:
		_start_overlay.queue_free()
		_start_overlay = null
	_show_race_reveal()

func _show_race_reveal() -> void:
	_busy = true
	_race_reveal_clicked = false
	_race_reveal_overlay = Control.new()
	_race_reveal_overlay.name = "race_reveal"
	_race_reveal_overlay.z_index = 99
	_race_reveal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_race_reveal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_race_reveal_overlay.gui_input.connect(_on_race_reveal_input)
	add_child(_race_reveal_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.90)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_race_reveal_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_race_reveal_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "本局种族"
	title.add_theme_font_override("font", UiTheme.cjk_font_bold())
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.custom_minimum_size = Vector2(0, 44)
	box.add_child(title)

	var races := HBoxContainer.new()
	races.mouse_filter = Control.MOUSE_FILTER_IGNORE
	races.alignment = BoxContainer.ALIGNMENT_CENTER
	races.add_theme_constant_override("separation", 12)
	box.add_child(races)
	for race in ps.races:
		races.add_child(_race_reveal_chip(String(race)))

	var hint := _muted("点击或等待自动开始", 13)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(0, 42)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(hint)

	var elapsed := 0.0
	while elapsed < 3.0 and not _race_reveal_clicked:
		await get_tree().create_timer(0.05).timeout
		elapsed += 0.05
	if _race_reveal_overlay != null:
		_race_reveal_overlay.queue_free()
		_race_reveal_overlay = null
	_busy = false
	_prep_left = PREP_SECONDS
	_say("开始：本局种族 " + "、".join(PackedStringArray(ps.races.map(func(r): return GameData.race_name(String(r))))))
	_refresh()

func _race_reveal_chip(race: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _sb(C_SLOT_FILL, C_GOLD, 0, 8))
	var label := Label.new()
	label.text = _race_reveal_text(race)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("eeeeee"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("outline_size", 0)
	chip.add_child(label)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.remove_child(label)
	margin.add_child(label)
	chip.add_child(margin)
	return chip

func _race_reveal_text(race: String) -> String:
	match race:
		"mech":
			return "⚙机械"
		"sacrifice":
			return "⚱献祭"
		"vampire":
			return "🧛血族"
		_:
			var icon := _race_icon(race)
			return icon + GameData.race_name(race)

func _on_race_reveal_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_race_reveal_clicked = true

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
	for n in ["side_ai", "side_p", "shop"]:
		var side := find_child(n, true, false) as Control
		if side == null or side.get_child_count() == 0:
			continue
		var inner := side.get_child(0)
		for i in range(inner.get_child_count()):
			var child := inner.get_child(i) as Control
			var cr := child.get_global_rect()
			print("[layout] %-9s child%d x=%4d y=%4d w=%4d h=%3d" % [n, i,
				int(cr.position.x), int(cr.position.y), int(cr.size.x), int(cr.size.y)])
	print("[layout] 顺序与不重叠检查：", "通过" if bad == 0 else "失败 %d 处" % bad)

func _interaction_test() -> bool:
	var failures: Array[String] = []
	_prep_left = 1000.0
	_speed = 40.0
	p_hp = 100
	e_hp = 100
	_game_over = false
	_selected = -1
	_selected_slot = -1
	ps.gold = 30
	ps.hand = []
	ps.board = _shot_board([])
	ps.shop = [
		{"n": "点击购买随从", "a": 2, "h": 3, "s": 1, "race": "mech", "part": "head"},
		{"n": "备用随从", "a": 3, "h": 4, "s": 1, "race": "mech", "part": "arm"},
		{"n": "备用随从二", "a": 4, "h": 5, "s": 2, "race": "mech", "part": "leg"},
		{"n": "备用随从三", "a": 5, "h": 6, "s": 2, "race": "mech", "part": "core"},
		{"n": "备用随从四", "a": 6, "h": 7, "s": 3, "race": "mech", "part": "head"},
	]
	ps.shop_frozen = false
	ps.free_refresh = 0
	ps.spell_refund = 0
	_refresh()
	await get_tree().process_frame
	var restart_button := find_child("restart_button", true, false) as Button
	_expect(restart_button != null and restart_button.visible
		and restart_button.tooltip_text.contains("重新开始"),
		"顶栏缺少重新开始游戏按钮", failures)

	var shop_gold: int = ps.gold
	_sfx_trace.clear()
	await _mouse_click(_child_or_null(_shop_row, 0))
	_expect(ps.hand.size() == 1, "商店左键点击没有买入卡牌（手牌 %d）" % ps.hand.size(), failures)
	_expect(ps.gold < shop_gold, "商店买入后金币没有扣减", failures)
	_expect(ps.shop[0] == null, "商店已购格没有清空", failures)
	_expect(not _sfx_trace.has("buy"), "买牌成功不应再播放 buy 音效", failures)

	await _mouse_click(_child_or_null(_hand_row, 0))
	_expect(_count(ps.board) == 1, "手牌左键点击没有自动上场", failures)
	var target: Dictionary = ps.board[0] if ps.board.size() > 0 and ps.board[0] != null else {}
	_expect(not target.is_empty(), "上场后 0 号格仍为空", failures)

	var before_spell_a: int = int(target.get("a", 0))
	var before_spell_h: int = int(target.get("h", 0))
	ps.hand = [{"n": "交互火球", "t": "s", "fx": "", "e": {"a": 2, "h": 3}, "x": "+2/+3"}]
	_refresh()
	await get_tree().process_frame
	await _mouse_click(_child_or_null(_hand_row, 0))
	_expect(_selected == 0, "法术点击后没有进入选中状态", failures)
	await get_tree().process_frame
	_expect(_spell_arrow != null and _spell_arrow.active,
		"法术点击后没有出现跟随鼠标的指向箭头", failures)
	_expect(not _sel_bar.visible, "法术选中时不应展开随从操作栏", failures)
	await _mouse_click(_child_or_null(_p_row, 0))
	_expect(int(target.get("a", 0)) == before_spell_a + 2 and int(target.get("h", 0)) == before_spell_h + 3,
		"点击我方随从没有施放法术", failures)
	_expect(ps.hand.is_empty(), "施放法术后手牌没有消耗", failures)
	_expect(_selected_slot == -1 and not _sel_bar.visible,
		"施放法术后不应把目标随从当成点击随从展开详情/卖出栏", failures)
	_click_board(0, true)
	_expect(_selected_slot == -1 and not _sel_bar.visible,
		"法术手势的重复 board 事件又展开了随从详情/卖出栏", failures)

	var before_feed_a: int = int(target.get("a", 0))
	var before_feed_h: int = int(target.get("h", 0))
	ps.hand = [{"n": "交互材料", "t": "m", "a": 1, "h": 1, "race": "mech", "material": true, "magA": 4, "magH": 5}]
	_refresh()
	await get_tree().process_frame
	await _mouse_click(_child_or_null(_hand_row, 0))
	_expect(_selected == 0, "材料牌点击后没有进入选中状态", failures)
	await get_tree().process_frame
	_expect(_spell_arrow != null and _spell_arrow.active and not _sel_bar.visible,
		"材料牌选中后没有进入指向目标模式", failures)
	await _mouse_click(_child_or_null(_p_row, 0))
	_expect(int(target.get("a", 0)) == before_feed_a + 4 and int(target.get("h", 0)) == before_feed_h + 5,
		"点击机械没有完成磁力喂料", failures)
	_expect(ps.hand.is_empty(), "磁力喂料后材料牌没有消耗", failures)
	_expect(_selected_slot == -1 and not _sel_bar.visible,
		"磁力喂料后不应把目标机械当成点击随从展开详情/卖出栏", failures)
	_click_board(0, true)
	_expect(_selected_slot == -1 and not _sel_bar.visible,
		"材料手势的重复 board 事件又展开了机械详情/卖出栏", failures)

	await get_tree().create_timer(0.14).timeout
	var sell_gold: int = ps.gold
	await _mouse_click(_child_or_null(_p_row, 0))
	_expect(_selected_slot == 0, "点击场上随从没有进入卖出选择", failures)
	var selected_slot_control := _child_or_null(_p_row, 0)
	_expect(_sel_bar.visible and selected_slot_control != null
		and _sel_bar.global_position.y >= selected_slot_control.global_position.y + selected_slot_control.size.y - 1.0,
		"随从操作栏没有显示在随从下方", failures)
	var selected_decor := _find_slot_decor(selected_slot_control)
	_expect(selected_decor != null and selected_decor.is_selected,
		"点击随从后随从身上没有出现选择框", failures)
	_expect(not _sel_label.visible and String(_sel_label.text) == "",
		"随从操作栏旁仍显示随从名", failures)
	_sel_sell_btn.pressed.emit()
	_expect(ps.board[0] == null and ps.gold == sell_gold + 2, "卖出按钮没有移除随从并返金", failures)

	ps.gold = 10
	ps.free_refresh = 0
	_refresh()
	await get_tree().process_frame
	var reroll_gold: int = ps.gold
	await _mouse_click(_action_buttons[0])
	_expect(ps.gold == reroll_gold - 1, "刷新按钮没有扣除 1 金", failures)
	await _mouse_click(_action_buttons[1])
	_expect(ps.shop_frozen and _freeze_btn.text.contains("解冻"), "冻结按钮没有切换状态或按钮文案", failures)
	_expect(find_child("freeze_overlay", true, false) != null, "冻结商店没有冰霜覆盖效果", failures)
	_expect(_action_buttons[0].disabled, "冻结后刷新按钮仍可点击，可能白扣金币", failures)
	var freeze_shop_snapshot: Array = ps.shop.duplicate(true)
	ps.roll_shop()
	_expect(ps.shop == freeze_shop_snapshot, "冻结状态下直接刷新商店仍替换了商品", failures)
	ps.gold = 100
	var level_before: int = ps.level
	var frozen_shop_before: Array = ps.shop.duplicate(true)
	var frozen_cost: int = Economy.level_up_cost(level_before)
	_refresh()
	await _mouse_click(_action_buttons[2])
	_expect(ps.level == level_before + 1, "升级按钮没有提升酒馆等级", failures)
	_expect(ps.gold == 100 - frozen_cost, "冻结升级没有按配置扣除正确金币", failures)
	_expect(ps.shop == frozen_shop_before, "冻结升级不应刷新商店", failures)
	await _mouse_click(_action_buttons[1])
	_expect(not ps.shop_frozen, "解冻按钮没有恢复商店刷新", failures)
	await get_tree().process_frame
	_expect(find_child("freeze_overlay", true, false) == null,
		"解冻后冰霜覆盖效果仍然残留在商店上", failures)
	ps.gold = 100
	level_before = ps.level
	var refresh_cost: int = Economy.level_up_cost(level_before)
	var shop_before: Array = ps.shop.duplicate(true)
	_refresh()
	await _mouse_click(_action_buttons[2])
	_expect(ps.level == level_before + 1, "解冻后升级没有提升酒馆等级", failures)
	_expect(ps.gold == 100 - refresh_cost, "普通升级没有按配置扣除正确金币", failures)
	_expect(ps.shop != shop_before, "普通升级没有立即刷新商店", failures)
	var shop_animated := false
	for child in _shop_row.get_children():
		if bool(child.get_meta("shop_reroll_animated", false)):
			shop_animated = true
			break
	_expect(shop_animated, "普通升级刷新商店后没有换牌入场反馈", failures)

	# 移动必须改变真实槽位与行动顺序，而不是只重排 UI。
	ps.board = _shot_board([
		{"n": "移动甲", "a": 3, "h": 3, "mh": 3, "s": 1, "race": "neutral"},
		{"n": "移动乙", "a": 2, "h": 2, "mh": 2, "s": 1, "race": "neutral"},
		{"n": "移动丙", "a": 1, "h": 1, "mh": 1, "s": 1, "race": "neutral"},
	])
	ps.hand = []
	_refresh()
	await get_tree().process_frame
	drop_board_on_slot(0, 5)
	await get_tree().process_frame
	_expect(ps.board[0] == null and ps.board[5] != null
		and String(ps.board[5].get("n", "")) == "移动甲",
		"把随从拖到空位后没有更新真实棋盘槽位", failures)
	var moved_units: Array = _to_units(ps.board, 1)
	_expect(moved_units.size() == 7 and moved_units[0] == null
		and String(moved_units[1].card_name) == "移动乙"
		and String(moved_units[2].card_name) == "移动丙"
		and String(moved_units[5].card_name) == "移动甲",
		"移动后的战斗单位没有保留空位，仍按默认紧凑顺序排队", failures)

	var long_name := "完整名称不会省略的测试随从"
	ps.hand = []
	ps.board[0] = {"n": long_name, "a": 7, "h": 9, "s": 3, "race": "mech", "part": "core"}
	_refresh()
	await get_tree().process_frame
	var board_slot: Control = _child_or_null(_p_row, 0)
	var board_name := ""
	if board_slot != null:
		var name_label := board_slot.find_child("name_label", true, false) as Label
		if name_label != null:
			board_name = name_label.text
	_expect(board_name.contains(long_name), "棋盘随从名字没有完整保留", failures)

	p_hp = 100
	e_hp = 100
	ps.round_no = 7
	ps.board = _shot_board([{"n": "必胜测试随从", "a": 30, "h": 30, "s": 3, "race": "neutral"}])
	ep.board = _shot_board([{"n": "必败测试随从", "a": 1, "h": 1, "s": 1, "race": "neutral"}])
	var enemy_hp_before: int = e_hp
	_refresh()
	await get_tree().process_frame
	await _mouse_click(_action_buttons[3])
	var fight_wait := 0
	while _busy and fight_wait < 240:
		await get_tree().process_frame
		fight_wait += 1
	_expect(e_hp < enemy_hp_before, "真实战斗胜利后 AI 生命没有扣减", failures)
	_expect(not _game_over, "双方生命仍大于 0 时不应结束对局", failures)

	# 战斗单位不能被战斗清槽反向删除；阵亡只影响本场回放。
	p_hp = 100
	e_hp = 100
	ps.round_no = 4
	ep.round_no = 4
	ps.board = _shot_board([{
		"n": "阵亡后应留下", "a": 0, "h": 1, "mh": 1, "s": 1, "race": "neutral",
	}])
	ep.board = _shot_board([{
		"n": "致死测试敌人", "a": 30, "h": 30, "mh": 30, "s": 3, "race": "neutral",
	}])
	_refresh()
	await get_tree().process_frame
	await _fight()
	_expect(_count(ps.board) == 1 and ps.board[0] != null \
		and String(ps.board[0].get("n", "")) == "阵亡后应留下",
		"战斗阵亡后备战随从被永久删除", failures)

	p_hp = 1
	e_hp = 100
	ps.board = _shot_board([{"n": "残血测试随从", "a": 0, "h": 1, "s": 1, "race": "neutral"}])
	ep.board = _shot_board([{"n": "终结测试随从", "a": 30, "h": 30, "s": 3, "race": "neutral"}])
	var round_before: int = ps.round_no
	await _fight()
	_expect(_game_over and p_hp == 0, "玩家生命归零后没有进入失败结局", failures)
	_expect(_battle_fx_trace.has("hero_burst_fx"), "败者头像没有生成爆裂终场表现", failures)
	_expect(find_child("game_over_banner", true, false) != null,
		"对局结束后没有显示胜利/败北横幅", failures)
	_expect(ps.round_no == round_before, "游戏结束后仍然推进了回合", failures)
	for button in _action_buttons:
		_expect(button.disabled, "游戏结束后操作按钮未禁用", failures)
	_expect(not _choice_host.visible, "游戏结束后选择栏仍可见", failures)
	var stopped_at: float = _prep_left
	await get_tree().create_timer(0.05).timeout
	_expect(is_equal_approx(_prep_left, stopped_at), "游戏结束后倒计时仍在推进", failures)

	if failures.is_empty():
		print("[prep_view] 交互自检通过：购买/上场/法术/喂料/卖出/刷新/冻结/升级/战斗/结束 10/10")
		return true
	for failure in failures:
		printerr("[prep_view] 交互失败：", failure)
	return false

func _flow_test() -> bool:
	var failures: Array[String] = []
	_prep_left = 1000.0
	_speed = 80.0
	await get_tree().process_frame

	var start_button := find_child("start_button", true, false) as Button
	_expect(start_button != null, "开始页没有可点击的开始按钮", failures)
	if start_button != null:
		await _mouse_click(start_button)
	await get_tree().process_frame
	_expect(_start_overlay == null, "点击开始游戏后开始页没有关闭", failures)

	var race_reveal := find_child("race_reveal", true, false) as Control
	_expect(race_reveal != null, "点击开始游戏后没有进入种族揭示", failures)
	if race_reveal != null:
		await _mouse_click(race_reveal)
	var reveal_wait := 0
	while _busy and reveal_wait < 120:
		await get_tree().process_frame
		reveal_wait += 1
	_expect(not _busy, "种族揭示结束后仍处于忙碌状态，整局交互被锁死", failures)
	_expect(find_child("race_reveal", true, false) == null, "种族揭示结束后遮罩没有移除", failures)

	ps.gold = 100
	var shop_index := -1
	for attempt in range(12):
		for i in range(ps.shop.size()):
			var data = ps.shop[i]
			if data == null or String(data.get("t", "")) == "s":
				continue
			if data.has("magA") or data.has("magH"):
				continue
			shop_index = i
			break
		if shop_index >= 0:
			break
		ps.reroll()
		_refresh()
		await get_tree().process_frame
	_expect(shop_index >= 0, "连续刷新后商店仍没有可直接上场的随从", failures)

	var hand_before: int = ps.hand.size()
	var gold_before: int = ps.gold
	if shop_index >= 0:
		await _mouse_click(_child_or_null(_shop_row, shop_index))
	_expect(ps.hand.size() == hand_before + 1, "真实商店点击购买后手牌没有增加", failures)
	_expect(ps.gold < gold_before, "真实商店点击购买后金币没有扣减", failures)

	var board_before: int = _count(ps.board)
	if not ps.hand.is_empty():
		await _mouse_click(_child_or_null(_hand_row, ps.hand.size() - 1))
	_expect(_count(ps.board) == board_before + 1, "点击刚买入的手牌后没有上场", failures)

	var placed_slot := _first_non_empty_slot(ps.board)
	_expect(placed_slot >= 0, "上场后找不到可悬停的我方随从", failures)
	if placed_slot >= 0:
		ps.board[placed_slot] = {
			"n": "完整名称不会省略的流程测试随从",
			"a": 40,
			"h": 40,
			"s": 4,
			"race": "evolve",
			"sk": {"e": "evolve", "need": 3},
			"_evo": 1,
		}
		ps.hand = []
	ep.board = _shot_board([])
	e_hp = 100
	p_hp = 100
	ps.shop_frozen = true
	_refresh()
	await get_tree().process_frame
	_expect(find_child("freeze_overlay", true, false) != null,
		"冻结覆盖层没有在开打前建立，无法验证回合结束清理", failures)

	var round_before: int = ps.round_no
	var enemy_hp_before: int = e_hp
	await _mouse_click(_action_buttons[3])
	_expect(_busy, "点击开打后没有进入战斗忙碌态", failures)
	var frozen_during_battle: bool = ps.shop_frozen
	_toggle_freeze()
	_expect(ps.shop_frozen == frozen_during_battle,
		"战斗期间仍能通过冻结按钮改变商店冻结状态", failures)
	_expect(_action_buttons[1].disabled, "战斗期间冻结按钮没有禁用", failures)
	var fight_wait := 0
	while _busy and fight_wait < 600:
		await get_tree().process_frame
		fight_wait += 1
	_expect(not _busy, "点击开打后战斗流程没有结束", failures)
	_expect(e_hp < enemy_hp_before, "点击开打后 AI 生命没有变化", failures)
	_expect(ps.round_no > round_before, "点击开打后回合没有推进", failures)
	_expect(find_child("freeze_overlay", true, false) == null,
		"回合结束后冻结覆盖层仍然残留", failures)
	_expect(String(_log.text).contains("开打："), "点击开打后日志没有战斗结果", failures)

	var slot_index := _first_non_empty_slot(ps.board)
	var slot := _child_or_null(_p_row, slot_index)
	_expect(slot != null, "战斗刷新后找不到我方随从槽位", failures)
	if slot != null:
		await _mouse_hover(slot)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(_tooltip_panel == null or not _tooltip_panel.visible,
			"悬停卡面本体仍然展开全卡详情，信息入口没有收敛", failures)
		var skill_marker: Label = null
		for child in slot.find_children("*", "Label", true, false):
			if child is Label and String((child as Label).text) == "⚡":
				skill_marker = child as Label
				break
		_expect(skill_marker != null, "棋盘随从没有生成能力查询入口", failures)
		if skill_marker != null:
			await _mouse_hover(skill_marker)
			await get_tree().process_frame
			await get_tree().process_frame
			_expect(_tooltip_panel != null and _tooltip_panel.visible,
				"悬停闪电没有展开随从能力信息", failures)
			if _tooltip_panel != null and _tooltip_panel.visible:
				_expect(_tooltip_label.text.contains("技能："),
					"闪电入口没有只显示随从自身能力", failures)
				_expect(not _tooltip_label.text.contains("公式：") \
					and not _tooltip_label.text.contains("结果：") \
					and (_tooltip_label.text.contains("当前") or _tooltip_label.text.contains("→")),
					"闪电入口没有把公式和动态结果合并进简略说明", failures)
				_expect(_tooltip_label.text.contains("[color=#fdcb6e]") \
					and _tooltip_label.text.contains("[color=#74b9ff]"),
					"闪电入口没有给核心信息和数值使用强调样式", failures)
				_expect(not _tooltip_label.text.contains("触发=") \
					and not _tooltip_label.text.contains("来源=") \
					and not _tooltip_label.text.contains("结算="),
					"闪电入口混入了详细公式与来源信息", failures)
				ps.board[slot_index]["_evo"] = 0
				await get_tree().process_frame
				var first_dynamic_text := _tooltip_label.text
				ps.board[slot_index]["_evo"] = 1
				await get_tree().process_frame
				_expect(_tooltip_label.text != first_dynamic_text and _tooltip_label.text.contains("1/3"),
					"能力悬停没有随实时状态动态刷新公式结果", failures)
		var badge: Label = null
		for child in slot.find_children("*", "Label", true, false):
			if child is Label and String((child as Label).text).begins_with("进化"):
				badge = child as Label
				break
		_expect(badge != null, "棋盘随从没有生成可悬停状态角标", failures)
		if badge != null:
			await _mouse_hover(badge)
			await get_tree().process_frame
			await get_tree().process_frame
			_expect(_tooltip_panel != null and _tooltip_panel.visible,
				"悬停特殊机制角标没有展开机制信息", failures)
			if _tooltip_panel != null and _tooltip_panel.visible:
				_expect(_tooltip_label.text.contains("进化条：") \
					and not _tooltip_label.text.contains("公式：") \
					and not _tooltip_label.text.contains("结果：") \
					and _tooltip_label.text.contains("还差"),
					"特殊机制角标没有把公式和动态结果合并进机制说明", failures)
				_expect(_tooltip_label.text.contains("[color=#fdcb6e]") \
					and _tooltip_label.text.contains("[color=#74b9ff]"),
					"特殊机制角标没有给核心信息和数值使用强调样式", failures)
				_expect(not _tooltip_label.text.contains("技能："),
					"特殊机制角标混入了随从自身能力", failures)

	if failures.is_empty():
		print("[prep_view] 完整流程自检通过：开始/买牌/上场/对战/悬停 5/5")
		return true
	for failure in failures:
		printerr("[prep_view] 流程失败：", failure)
	return false

func _battle_anim_test() -> bool:
	var failures: Array[String] = []
	_speed = 1.0
	_battle_fx_trace.clear()
	var burst_events: Array = [
		{"t": "damage"}, {"t": "damage"}, {"t": "damage"}, {"t": "damage"},
	]
	_expect(_event_burst_scale(burst_events, 0, "damage") >= 1.5,
		"多目标连续事件的播放倍速没有达到至少 1.5 倍", failures)
	_expect(is_equal_approx(_event_burst_scale([{"t": "damage"}], 0, "damage"), 1.0),
		"单对象事件不应被错误加速", failures)
	_expect(_event_burst_scale(
		[{"t": "damage", "direct": true}, {"t": "death"}],
		0, "damage", {"t": "damage", "direct": true}) >= 1.5,
		"dmg-allies 直伤即使与死亡事件交错也没有达到 1.5 倍速", failures)
	_expect(_event_burst_scale(
		[{"t": "damage", "direct": true}, {"t": "death"}],
		1, "death", {"t": "death"}) >= 1.5,
		"dmg-allies 致死后的死亡动画没有同步进入 1.5 倍速", failures)
	var p_display: Array = ps.board.duplicate(true)
	var e_display: Array = ep.board.duplicate(true)
	var by_uid := {}
	for i in range(p_display.size()):
		if p_display[i] != null:
			p_display[i]["_side"] = "p"
			p_display[i]["_slot"] = i
			by_uid[int(p_display[i].get("_uid", -1))] = p_display[i]
	for i in range(e_display.size()):
		if e_display[i] != null:
			e_display[i]["_side"] = "e"
			e_display[i]["_slot"] = i
			by_uid[int(e_display[i].get("_uid", -1))] = e_display[i]

	var source_uid := 101
	var target_uid := 201
	var source := _battle_slot_for_uid(source_uid, by_uid)
	var target := _battle_slot_for_uid(target_uid, by_uid)
	_expect(source != null and target != null, "战斗动画夹具缺少攻击方或目标槽位", failures)
	if source == null or target == null:
		printerr("[prep_view] 战斗动画失败：夹具槽位缺失")
		return false
	_update_battle_slot_in_place(source, 0, p_display[0], true)
	var skill_entry_after_refresh := false
	for child in source.find_children("*", "Label", true, false):
		if child is Label and String((child as Label).text) == "⚡":
			skill_entry_after_refresh = true
			break
	_expect(skill_entry_after_refresh, "战斗中受击刷新槽位后丢失了随从能力入口", failures)
	await get_tree().process_frame

	var slot_ids: Array[int] = []
	var slot_positions: Dictionary = {}
	var slot_scales: Dictionary = {}
	for row in [_p_row, _ai_row]:
		for child in row.get_children():
			var slot := child as Control
			if slot == null:
				continue
			slot_ids.append(slot.get_instance_id())
			slot_positions[slot.get_instance_id()] = slot.position
			slot_scales[slot.get_instance_id()] = slot.scale

	var source_start := source.position
	var source_scale := source.scale
	var target_start := target.position
	var target_scale := target.scale
	var target_style := target.get_theme_stylebox("panel") as StyleBoxFlat
	var target_bg := target_style.bg_color if target_style != null else Color.TRANSPARENT

	var attack_duration := 0.12
	var attack_tween := _battle_animate_attack({"src": source_uid, "dst": target_uid}, by_uid, false)
	_expect(attack_tween != null, "攻击动画没有创建 Tween", failures)
	_expect(_battle_fx_trace.has("attack_path_fx"), "攻击没有生成路径轨迹", failures)
	_expect(find_child("attack_path_fx", true, false) != null, "攻击路径叠加层没有加入场景", failures)
	await get_tree().create_timer(attack_duration * 0.5).timeout
	await get_tree().process_frame
	_expect(source.position.y < source_start.y - 1.0 and source.position.y > source_start.y - 5.0,
		"攻击方没有按原版做约 4px 的上移，start=%s current=%s" % [source_start, source.position], failures)
	_expect(source.scale.x > source_scale.x and source.scale.x < 1.03,
		"攻击方没有按原版放大到约 1.02，start=%s current=%s" % [source_scale, source.scale], failures)
	_expect(target.position.is_equal_approx(target_start), "攻击动作提前移动了受击目标", failures)
	if attack_tween != null:
		await attack_tween.finished
	_expect(source.position.is_equal_approx(source_start), "攻击方没有回到原始位置", failures)
	_expect(source.scale.is_equal_approx(source_scale), "攻击方没有恢复原始缩放", failures)

	var hit_duration := 0.05
	var hit_tween := _battle_animate_hit(target_uid, by_uid)
	_expect(hit_tween != null, "受击动画没有创建 Tween", failures)
	await get_tree().create_timer(hit_duration * 0.5).timeout
	await get_tree().process_frame
	var hit_style := target.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(target.position.x > target_start.x + 1.0 and target.position.x < target_start.x + 6.0,
		"受击目标没有按原版向右抖动", failures)
	_expect(hit_style != null and hit_style.bg_color.is_equal_approx(Color("ff7675")),
		"受击目标没有使用原版 #ff7675 底色", failures)
	_expect(hit_style != null and hit_style.border_color.is_equal_approx(Color("d63031")),
		"受击目标没有使用原版 #d63031 边框", failures)
	_expect(hit_style != null and hit_style.border_width_top == 2,
		"受击目标没有使用 2px 命中边框", failures)
	_expect(source.position.is_equal_approx(source_start), "受击动作移动了攻击方", failures)
	if hit_tween != null:
		await hit_tween.finished
	await get_tree().process_frame
	_expect(target.position.is_equal_approx(target_start), "受击目标没有结束抖动回到原位", failures)
	_expect(target.scale.is_equal_approx(target_scale), "受击目标缩放被意外修改", failures)
	var restored_style := target.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(restored_style != null and restored_style.bg_color.is_equal_approx(target_bg),
		"受击目标没有恢复原始底色", failures)

	var hero_side := String(Dictionary(by_uid[source_uid]).get("_side", "p"))
	await _battle_animate_hero_attack(source_uid, hero_side, by_uid, 4)
	_expect(_battle_fx_trace.has("hero_attack_fx"), "幸存随从没有生成攻击玩家的路径", failures)
	_expect(find_child("hero_damage_float", true, false) != null,
		"攻击玩家后没有生成星级伤害飘字", failures)
	_battle_fx_trace.clear()
	await _play_battle([
		{"t": "buff", "id": target_uid, "src": source_uid, "a": 1, "h": 1, "source": "dragon-attack"},
	], p_display, e_display, {})
	_expect(_battle_fx_trace.has("support_path_fx"),
		"来源型增益没有生成从来源到收益随从的过程路径", failures)
	_battle_fx_trace.clear()
	await _play_battle([
		{"t": "buff", "id": target_uid, "src": source_uid, "a": 1, "h": 1, "source": source_uid},
	], p_display, e_display, {})
	_expect(_battle_fx_trace.has("support_path_fx"),
		"整数 UID 来源的增益没有正常回放", failures)

	var ids_after: Array[int] = []
	for row in [_p_row, _ai_row]:
		for child in row.get_children():
			var slot := child as Control
			if slot != null:
				ids_after.append(slot.get_instance_id())
	_expect(ids_after == slot_ids, "战斗动画重建了槽位实例，仍存在整排刷新风险", failures)
	for uid_value in by_uid.keys():
		var uid := int(uid_value)
		if uid == source_uid or uid == target_uid:
			continue
		var slot := _battle_slot_for_uid(uid, by_uid)
		if slot == null:
			continue
		var key := slot.get_instance_id()
		_expect(slot.position.is_equal_approx(slot_positions[key]), "战斗动画移动了非参战随从", failures)
		_expect(slot.scale.is_equal_approx(slot_scales[key]), "战斗动画缩放了非参战随从", failures)

	if failures.is_empty():
		print("[prep_view] 战斗动画自检通过：攻击路径/攻击位移/攻击缩放/受击配色/左右抖动/收尾攻击/来源路径/槽位复用 8/8")
		return true
	for failure in failures:
		printerr("[prep_view] 战斗动画失败：", failure)
	return false

func _sacrifice_test() -> bool:
	var failures: Array[String] = []
	_speed = 1.0
	_sfx_trace.clear()
	_battle_fx_trace.clear()
	_drop_preview_trace.clear()
	_interaction_fx_trace.clear()
	await get_tree().process_frame

	var sigil = _sigil_slot
	_expect(sigil != null, "献祭夹具没有生成契印槽", failures)
	if sigil == null:
		for failure in failures:
			printerr("[prep_view] 献祭失败：", failure)
		return false
	var sigil_label := sigil.get_node_or_null("sigil_label") as Label
	_expect(sigil.visible, "存在献祭随从时契印槽没有显示", failures)
	_expect(sigil_label != null and String(sigil_label.text).begins_with("契印槽:空"),
		"空契印槽文案不完整：%s" % (String(sigil_label.text) if sigil_label != null else "<null>"), failures)

	var valid_payload := {"kind": "board", "index": 0}
	var invalid_payload := {"kind": "board", "index": 4}
	_expect(bool(sigil._can_drop_data(Vector2.ZERO, valid_payload)),
		"合法献祭随从不能拖入契印槽", failures)
	_expect(sigil.preview_valid and sigil.preview_mode == "sigil",
		"合法契印拖拽没有进入紫色预览态", failures)
	_expect(_drop_preview_trace.has("valid:sigil:sacrifice"),
		"合法契印拖拽没有留下有效预览轨迹，实际 %s" % str(_drop_preview_trace), failures)
	_expect(not bool(sigil._can_drop_data(Vector2.ZERO, invalid_payload)),
		"非献祭随从仍可拖入契印槽", failures)
	_expect(not sigil.preview_valid and sigil.preview_mode == "sigil",
		"非法契印拖拽没有进入错误预览态", failures)
	_expect(_drop_preview_trace.has("invalid:sigil:not_sacrifice"),
		"非法契印拖拽没有留下无效预览轨迹，实际 %s" % str(_drop_preview_trace), failures)
	sigil._drop_data(Vector2.ZERO, valid_payload)
	await get_tree().process_frame
	_expect(_interaction_fx_trace.has("sigil_bind_fx"),
		"立契后没有生成契印吸附/扩张完成动效", failures)
	var contract_slot := _find_contract_slot()
	_expect(contract_slot == 0, "拖入契印槽没有选中 0 号献祭随从", failures)
	_expect(bool(ps.board[0].get("_contract", false)), "拖入后卡牌没有写入契印状态", failures)
	_expect(sigil_label != null and String(sigil_label.text).contains("血契司仪"),
		"立契后契印槽没有显示完整目标名", failures)
	_expect(ps.contract_id == -1,
		"立契阶段不应提前把备战槽位号写入战斗 contract_id", failures)
	_expect(_unit_uid_for_slot(ps.board, contract_slot) == 1,
		"首名存活随从的战斗 UID 不是 1，契印目标会错位", failures)

	_selected_slot = 0
	_toggle_contract_selected_slot()
	await get_tree().process_frame
	_expect(_find_contract_slot() == -1, "选择栏没有解除已有契印", failures)
	_toggle_contract_selected_slot()
	await get_tree().process_frame
	_expect(_find_contract_slot() == 0, "选择栏“立契”没有恢复契印目标", failures)

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	sigil._gui_input(right_click)
	await get_tree().process_frame
	_expect(_find_contract_slot() == -1 and ps.contract_id == -1,
		"右键契印槽没有清空目标与战斗状态", failures)
	_set_contract_slot(0)
	await get_tree().process_frame

	var debt_values: Array[int] = [0, 7, 8, 12, 18, 25, 32, 40]
	var expected_tiers: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
	var expected_colors: Array[Color] = [
		_debt_tier_color(0), _debt_tier_color(0), _debt_tier_color(1), _debt_tier_color(1),
		_debt_tier_color(2), _debt_tier_color(2), _debt_tier_color(3), _debt_tier_color(3),
	]
	var debt_card: Dictionary = ps.board[1]
	for i in range(debt_values.size()):
		var value := debt_values[i]
		debt_card["_debt"] = value
		var specs: Array[Dictionary] = _status_badge_specs(debt_card, ps, 1)
		var debt_badge: Dictionary = {}
		for spec in specs:
			if String(spec.get("text", "")).begins_with("债"):
				debt_badge = spec
				break
		_expect(int(_debt_tier(value)) == expected_tiers[i],
			"债务 %d 的档位不是 %d" % [value, expected_tiers[i]], failures)
		_expect(not debt_badge.is_empty() and String(debt_badge.get("text", "")).begins_with("债%d" % value),
			"债务 %d 的角标文本不正确" % value, failures)
		if not debt_badge.is_empty():
			_expect(Color(debt_badge.get("color", Color.TRANSPARENT)).is_equal_approx(expected_colors[i]),
				"债务 %d 的角标颜色未按原版分档" % value, failures)
	debt_card.erase("_debt")

	var fx_p: Array = ps.board.duplicate(true)
	var fx_e: Array = ep.board.duplicate(true)
	var by_uid: Dictionary = {}
	for i in range(fx_p.size()):
		if fx_p[i] != null:
			fx_p[i]["_uid"] = 1 + i
			fx_p[i]["_side"] = "p"
			fx_p[i]["_slot"] = i
			by_uid[int(fx_p[i]["_uid"])] = fx_p[i]
	for i in range(fx_e.size()):
		if fx_e[i] != null:
			fx_e[i]["_uid"] = 101 + i
			fx_e[i]["_side"] = "e"
			fx_e[i]["_slot"] = i
			by_uid[int(fx_e[i]["_uid"])] = fx_e[i]
	var slot_ids: Array[int] = []
	for row in [_p_row, _ai_row]:
		for child in row.get_children():
			if child is Control:
				slot_ids.append((child as Control).get_instance_id())

	var contract_fx: Control = _battle_contract_mark_fx(1, by_uid)
	_expect(contract_fx != null and contract_fx.name == "contract_mark_fx",
		"契印事件没有生成紫色契印标记", failures)
	await get_tree().process_frame
	if contract_fx != null:
		var contract_text := contract_fx.find_child("contract_label", true, false) as Label
		_expect(contract_text != null and String(contract_text.text) == "契印",
			"契印标记没有原版“契印”文字", failures)
	if contract_fx != null:
		await get_tree().create_timer(0.95).timeout
		_expect(not is_instance_valid(contract_fx), "契印标记没有在约 0.82 秒后清理", failures)

	var offer_fx: Control = _battle_sacrifice_offer_fx(1, 9, by_uid)
	_expect(offer_fx != null and offer_fx.name == "sacrifice_offer_fx",
		"契印死亡没有生成献祭成功面板", failures)
	await get_tree().process_frame
	if offer_fx != null:
		var offer_label := offer_fx.find_child("offer_label", true, false) as Label
		_expect(offer_label != null and String(offer_label.text).contains("献祭成功 债务+9"),
			"献祭面板没有显示实际债务增量", failures)
		_expect(offer_label != null and offer_label.get_theme_color("font_color").is_equal_approx(Color("ffd166")),
			"献祭成功文字没有使用原版 #ffd166", failures)
	if offer_fx != null:
		await get_tree().create_timer(1.85).timeout
		_expect(not is_instance_valid(offer_fx), "献祭成功面板没有按时清理", failures)

	var cast_fx: Control = _battle_debt_cast_fx(1, by_uid, 2)
	_expect(cast_fx != null and cast_fx.name == "debt_cast_fx",
		"债务入账没有分层冲击表现", failures)
	_expect(cast_fx != null and int(cast_fx.get_meta("tier", -1)) == 2,
		"中债务节点没有使用独立层级标记", failures)
	if cast_fx != null:
		await get_tree().create_timer(0.42).timeout
		_expect(not is_instance_valid(cast_fx), "债务冲击环没有按时清理", failures)

	var payoff_fx: Control = _battle_sacrifice_payoff_fx(1, 9, by_uid)
	_expect(payoff_fx != null and payoff_fx.name == "debt_payoff_fx",
		"债务结算没有生成债球结算表现", failures)
	if payoff_fx != null:
		_expect(not bool(payoff_fx.get_meta("full_screen_frame", true)),
			"债务结算仍保留全屏线框标记", failures)
		_expect(payoff_fx.find_child("payoff_frame", true, false) == null,
			"债务结算仍生成全屏线框节点", failures)
		_expect(int(payoff_fx.get_meta("target_count", 0)) >= 2,
			"债务结算没有向全部己方献祭随从连线", failures)
		_expect(int(payoff_fx.get_meta("tier", -1)) == 1,
			"小债务节点没有标记为 tier1", failures)
		_expect(float(payoff_fx.get_meta("orb_radius", 0.0)) >= 14.0,
			"债务结算没有建立可见的大血球半径", failures)
		_expect(int(payoff_fx.get_meta("particle_count", 0))
			>= int(payoff_fx.get_meta("target_count", 0)) * 8,
			"债务结算分裂到随从身上的粒子数量不足", failures)
		var payoff_label := payoff_fx.find_child("payoff_label", true, false) as Label
		_expect(payoff_label != null and String(payoff_label.text).contains("小节点"),
			"小债务节点缺少层级文字", failures)
		await get_tree().create_timer(1.35).timeout
		_expect(not is_instance_valid(payoff_fx), "债务结算表现没有按时清理", failures)
	for tier_probe in [
		{"need": 18, "tier": 2, "label": "中节点"},
		{"need": 32, "tier": 3, "label": "大节点"},
	]:
		var tier_fx: Control = _battle_sacrifice_payoff_fx(
			1, int(tier_probe["need"]), by_uid, int(tier_probe["tier"]))
		_expect(tier_fx != null and int(tier_fx.get_meta("tier", -1)) == int(tier_probe["tier"]),
			"%s债务节点没有独立层级标记" % String(tier_probe["label"]), failures)
		if tier_fx != null:
			var tier_label := tier_fx.find_child("payoff_label", true, false) as Label
			_expect(tier_label != null and String(tier_label.text).contains(String(tier_probe["label"])),
				"%s债务节点缺少层级文字" % String(tier_probe["label"]), failures)
			tier_fx.queue_free()

	var gain_fx: Control = _battle_soul_gain_fx(1, Vector2i(7, 4), by_uid)
	_expect(gain_fx != null and gain_fx.name == "soul_gain_fx",
		"献祭收益没有紫色面板与灵魂粒子表现", failures)
	await get_tree().process_frame
	if gain_fx != null:
		var gain_label := gain_fx.find_child("gain_label", true, false) as Label
		_expect(gain_label != null and String(gain_label.text) == "灵魂 +7/+4",
			"献祭收益飘字没有显示灵魂来源与真实攻击/生命", failures)
		_expect(gain_label != null and gain_label.get_theme_color("font_color").is_equal_approx(Color("c7c0ff")),
			"献祭收益飘字没有使用紫色灵魂色", failures)
		_expect(gain_fx.get_node_or_null("soul_particles") != null
			and gain_fx.get_node("soul_particles").get_child_count() == 8,
			"献祭收益没有 8 个灵魂粒子", failures)
	if gain_fx != null:
		await get_tree().create_timer(0.72).timeout
		_expect(not is_instance_valid(gain_fx), "献祭收益表现没有按时清理", failures)

	await _play_battle(
		[{"t": "contract", "id": 1, "side": "p", "debtBonus": 1}],
		fx_p.duplicate(true), fx_e.duplicate(true), {1: "血契司仪", 2: "债务执事"})
	_expect(_battle_fx_trace.has("contract_mark_fx"), "contract 事件回放没有触发契印标记", failures)

	await _play_battle(
		[{"t": "debt", "side": "p", "src": 1, "reason": "contract_death",
			"old": 0, "debt": 9, "delta": 9, "tier": 1, "node_rewards": [1]}],
		fx_p.duplicate(true), fx_e.duplicate(true), {1: "血契司仪", 2: "债务执事"})
	_expect(_battle_fx_trace.has("sacrifice_offer_fx") and _battle_fx_trace.has("debt_cast_fx"),
		"debt(contract_death) 事件回放没有触发献祭成功与债务冲击表现", failures)

	_battle_fx_trace.clear()
	await _play_battle(
		[
			{"t": "debt_settle", "side": "p", "src": 1, "reason": "payoff",
				"need": 8, "tier": 1, "a": 7, "h": 4, "old": 9, "debt": 1},
			{"t": "buff", "id": 1, "a": 7, "h": 4, "source": "debt-payoff"},
			{"t": "buff", "id": 2, "a": 7, "h": 4, "source": "debt-payoff"},
			{"t": "buff", "id": 3, "a": 7, "h": 4, "source": "debt-payoff"},
		],
		fx_p.duplicate(true), fx_e.duplicate(true), {1: "血契司仪", 2: "债务执事", 3: "血祭司祭"})
	_expect(_battle_fx_trace.has("debt_payoff_fx"),
		"debt_settle 事件回放没有生成中央债球结算表现", failures)
	_expect(not _battle_fx_trace.has("support_path_fx"),
		"债务收益仍触发了普通来源路径，导致末端来回弹", failures)

	_battle_fx_trace.clear()
	await _play_battle(
		[
			{"t": "buff", "id": 1, "a": 4, "h": 4, "source": "debt-lord"},
			{"t": "buff", "id": 2, "a": 4, "h": 4, "source": "debt-lord"},
			{"t": "buff", "id": 3, "a": 4, "h": 4, "source": "debt-lord"},
		],
		fx_p.duplicate(true), fx_e.duplicate(true),
		{1: "万灵之主", 2: "血契司仪", 3: "债务执事"})
	_expect(_battle_fx_trace.has("debt_lord_fx"),
		"万灵之主没有生成单次中央债务领主演出", failures)
	_expect(not _battle_fx_trace.has("support_path_fx"),
		"万灵之主仍按每个收益目标来回播放普通来源路径", failures)
	var lord_fx := find_child("debt_lord_fx", true, false) as Control
	_expect(lord_fx != null, "万灵之主中央债务领主演出没有加入场景", failures)
	if lord_fx != null:
		_expect(not bool(lord_fx.get_meta("full_screen_frame", true)),
			"万灵之主结算仍保留全屏线框标记", failures)
		_expect(lord_fx.find_child("payoff_frame", true, false) == null,
			"万灵之主结算仍生成全屏线框节点", failures)
		await get_tree().create_timer(1.35).timeout
		_expect(not is_instance_valid(lord_fx), "万灵之主中央演出没有按时清理", failures)

	var ids_after: Array[int] = []
	for row in [_p_row, _ai_row]:
		for child in row.get_children():
			if child is Control:
				ids_after.append((child as Control).get_instance_id())
	_expect(ids_after == slot_ids, "献祭表现回放重建了棋盘槽位实例", failures)

	ps.board[3]["_devourReady"] = true
	_selected_slot = 3
	_drag_source_slot = -1
	_refresh()
	await get_tree().process_frame
	var source_slot := _child_or_null(_p_row, 3) as DropSlot
	var valid_target_slot := _child_or_null(_p_row, 1) as DropSlot
	var empty_target_slot := _child_or_null(_p_row, 6) as DropSlot
	_expect(source_slot != null and valid_target_slot != null and empty_target_slot != null,
		"吞噬拖拽夹具缺少源槽、有效目标或空槽", failures)
	if source_slot != null and valid_target_slot != null:
		var drag_payload := {"kind": "board", "index": 3}
		_expect(bool(valid_target_slot._can_drop_data(Vector2.ZERO, drag_payload)),
			"合法吞噬目标没有通过拖放判定", failures)
		_expect(valid_target_slot.preview_mode == "devour" and valid_target_slot.preview_valid,
			"合法吞噬目标没有进入红色吞噬预览态", failures)
		var valid_decor = _find_slot_decor(valid_target_slot)
		_expect(valid_decor != null and valid_decor.drop_preview == "devour"
			and valid_decor.drop_preview_label == "吞噬",
			"合法吞噬目标没有绘制红框/吞噬提示", failures)
	if empty_target_slot != null:
		var invalid_drag_payload := {"kind": "board", "index": 3}
		_expect(not bool(empty_target_slot._can_drop_data(Vector2.ZERO, invalid_drag_payload)),
			"吞噬可以落到空槽", failures)
		var invalid_decor = _find_slot_decor(empty_target_slot)
		_expect(empty_target_slot.preview_mode == "devour" and not empty_target_slot.preview_valid
			and invalid_decor != null and invalid_decor.drop_preview == "invalid",
			"无效吞噬目标没有无效态与叉号反馈", failures)
	var eater_decor := _find_slot_decor(_child_or_null(_p_row, 3))
	var target_decor := _find_slot_decor(_child_or_null(_p_row, 1))
	_expect(eater_decor != null and not eater_decor.is_devour_target,
		"吞噬者自身不应被标记为吞噬目标", failures)
	_expect(target_decor != null and target_decor.is_devour_target,
		"献祭者进入吞噬选择后没有高亮其他友方目标", failures)
	var invalid_devour: Dictionary = ps.devour_ally(3, 3)
	_expect(not bool(invalid_devour.get("ok", false)), "吞噬者可以吞噬自身", failures)
	ps.board[3]["_devourReady"] = true
	drop_board_on_slot(3, 3)
	await get_tree().process_frame
	_expect(not bool(ps.board[3].get("_devourReady", false)), "拖回自身没有取消吞噬", failures)
	ps.board[3]["_devourReady"] = true
	drop_board_on_slot(3, 1)
	await get_tree().process_frame
	_expect(ps.board[1] == null and not bool(ps.board[3].get("_devourReady", false)),
		"合法吞噬没有移除目标并结束选择", failures)
	_expect(_interaction_fx_trace.has("devour_success_fx"),
		"合法吞噬没有生成灵魂吸附完成动效", failures)
	ps.board[6] = {
		"n": "UI契印目标", "a": 2, "h": 3, "mh": 3, "s": 2, "race": "sacrifice",
	}
	_set_contract_slot(6)
	var debt_before_devour: int = ps.debt
	ps.board[3]["_devourReady"] = true
	drop_board_on_slot(3, 6)
	await get_tree().process_frame
	_expect(ps.debt > debt_before_devour,
		"UI 吞噬契印目标没有增加债务，实际 %d→%d" % [debt_before_devour, ps.debt], failures)
	_expect(ps.board[6] == null, "UI 吞噬契印目标后目标仍留在棋盘", failures)
	for sfx_kind in ["contract", "debt", "debt_settle", "devour"]:
		_expect(_sfx_trace.has(sfx_kind), "献祭音效轨迹缺少 %s" % sfx_kind, failures)

	# 契印标记必须只属于我方实际卡牌；移动槽位后不能残留旧槽，也不能命中敌方同号槽。
	ps.board = _shot_board([
		{"n": "契印移动测试甲", "a": 2, "h": 3, "mh": 3, "s": 2, "race": "sacrifice"},
		{"n": "普通友方", "a": 2, "h": 2, "mh": 2, "s": 1, "race": "neutral"},
	])
	ep.board = _shot_board([
		{"n": "敌方同号甲", "a": 2, "h": 2, "mh": 2, "s": 1, "race": "neutral"},
		{"n": "敌方同号乙", "a": 2, "h": 2, "mh": 2, "s": 1, "race": "neutral"},
	])
	_contract_slot = -1
	ps.contract_bonus = 0
	_set_contract_slot(0)
	await get_tree().process_frame
	var p0_decor := _find_slot_decor(_child_or_null(_p_row, 0))
	var e0_decor := _find_slot_decor(_child_or_null(_ai_row, 0))
	_expect(p0_decor != null and p0_decor.is_contract, "我方契印目标没有标记", failures)
	_expect(e0_decor != null and not e0_decor.is_contract,
		"敌方同位置随从被错误标记为契印单位", failures)
	ps.swap_slots(0, 6)
	_refresh()
	await get_tree().process_frame
	var p0_after := _find_slot_decor(_child_or_null(_p_row, 0))
	var p6_after := _find_slot_decor(_child_or_null(_p_row, 6))
	var e6_after := _find_slot_decor(_child_or_null(_ai_row, 6))
	_expect(p0_after != null and not p0_after.is_contract, "契印随从移动后旧槽仍保留契印标记", failures)
	_expect(p6_after != null and p6_after.is_contract, "契印随从移动后新槽没有契印标记", failures)
	_expect(e6_after != null and not e6_after.is_contract, "敌方槽位被契印移动错误标记", failures)

	# 血契司仪自动选择食骸者时只能标记原卡，不能复制或污染敌方同号槽。
	ps.board = _shot_board([
		{"n": "血契司仪", "a": 3, "h": 5, "mh": 5, "s": 2, "race": "sacrifice",
			"sk": {"t": "start", "e": "contract-set", "debtBonus": 3}},
		{"n": "食骸者", "a": 4, "h": 6, "mh": 6, "s": 6, "race": "sacrifice",
			"sk": {"t": "death", "e": "inherit", "rate": 0.0445, "debt": 0.055}},
	])
	ep.board = _shot_board([
		{"n": "敌方同号食骸者", "a": 4, "h": 6, "mh": 6, "s": 6, "race": "sacrifice"},
		{"n": "敌方同号乙", "a": 2, "h": 2, "mh": 2, "s": 1, "race": "neutral"},
	])
	ps.contract_bonus = 0
	_expect(ps.ensure_auto_contract(), "血契司仪没有自动选择食骸者作为契印目标", failures)
	_refresh()
	await get_tree().process_frame
	var p1_eater := _find_slot_decor(_child_or_null(_p_row, 1))
	var e1_eater := _find_slot_decor(_child_or_null(_ai_row, 1))
	_expect(ps.board[1] != null and String(ps.board[1].get("n", "")) == "食骸者"
		and bool(ps.board[1].get("_contract", false)),
		"自动契印没有标记原食骸者", failures)
	_expect(p1_eater != null and p1_eater.is_contract, "食骸者契印目标没有我方视觉标记", failures)
	_expect(e1_eater != null and not e1_eater.is_contract,
		"食骸者契印目标复制或污染了敌方同号槽", failures)

	if failures.is_empty():
		print("[prep_view] 献祭自检通过：契印槽/拖放/选择栏/右键/三档债务/契约表现/吞噬取消 + 音效轨迹")
		return true
	for failure in failures:
		printerr("[prep_view] 献祭失败：", failure)
	return false

func _evolve_test() -> bool:
	var failures: Array[String] = []
	_battle_fx_trace.clear()
	_sfx_trace.clear()
	var evolving: Dictionary = {
		"_uid": 1, "n": "进化幼体", "a": 2, "h": 2, "mh": 2, "s": 3,
		"race": "evolve", "_evo": 0, "_ev": 5, "_vd": 1, "_vc": 0,
		"_pr": 4, "_gene": 0, "sk": {"t": "attack", "e": "evolve-step", "need": 3, "maxD": 3},
	}
	ps.board = _shot_board([evolving])
	ps.phase = 0
	_refresh()
	await get_tree().process_frame
	_expect(_phase_label != null and _phase_label.visible and String(_phase_label.text) == "相:昼",
		"昼相没有在进化棋盘上显示", failures)
	_expect(_phase_label != null and String(_phase_label.tooltip_text).contains("额外推进1格"),
		"昼相没有说明额外进化格来源", failures)
	var status_lines := _dynamic_status_lines(evolving, ps)
	var status_text := "\n".join(PackedStringArray(status_lines))
	_expect(status_text.contains("已进化：5 轮") and status_text.contains("已质变：1/3"),
		"详细技能信息没有显示进化总轮数和质变次数", failures)
	ps.phase = 1
	_refresh()
	await get_tree().process_frame
	_expect(_phase_label != null and String(_phase_label.text) == "相:夜"
		and String(_phase_label.tooltip_text).contains("额外推进1格"),
		"夜相没有正确显示额外受击进化规则", failures)
	var enemy: Dictionary = {"_uid": 101, "n": "木桩", "a": 0, "h": 200, "mh": 200, "s": 1, "race": "neutral"}
	var events: Array = [
		{"t": "evop", "id": 1, "evo": 1, "need": 3},
		{"t": "evo_full", "id": 1},
		{"t": "evolve", "id": 1, "kind": "stat_x2"},
		{"t": "gene", "id": 1, "gene": 1, "a": 2, "h": 2},
		{"t": "progress", "id": 1, "progress": 5, "need": 5},
		{"t": "progress_full", "id": 1},
		{"t": "progress_hatch", "id": 1, "name": "混沌始祖", "layers": 5, "a": 23, "h": 23},
	]
	await _play_battle(events, [evolving], [enemy], {1: "进化幼体", 101: "木桩"})
	for fx_name in ["evo_tick_fx", "evo_full_fx", "evolve_fx", "gene_fx", "progress_fx", "progress_full_fx", "progress_hatch_fx"]:
		_expect(_battle_fx_trace.has(fx_name), "进化动画轨迹缺少 %s" % fx_name, failures)
	for sfx_name in ["evo_tick", "evo_full", "evolve", "gene", "progress", "progress_full", "progress_hatch"]:
		_expect(_sfx_trace.has(sfx_name), "进化音效轨迹缺少 %s" % sfx_name, failures)
	_expect(String(evolving.get("n", "")) == "混沌始祖", "progress_hatch 没有把卡面更新为混沌始祖", failures)
	_expect(int(evolving.get("_pr", 0)) == 5 and int(evolving.get("_gene", 0)) == 5,
		"孵化后没有保留 5 层进度/基因", failures)
	if failures.is_empty():
		print("[prep_view] 进化自检通过：进化条/质变/基因/孵化 UI+动画+音效轨迹")
		return true
	for failure in failures:
		printerr("[prep_view] 进化失败：", failure)
	return false


func _quest_test() -> bool:
	var failures: Array[String] = []
	_busy = false
	_game_over = false
	_prep_left = 1000.0
	ps.phase = 0
	ps.board = _shot_board([{
		"_uid": 1, "n": "进化幼体", "a": 2, "h": 4, "mh": 4, "s": 3,
		"race": "evolve", "sk": {"t": "start", "e": "evolve", "need": 3},
	}])
	ps.select_quest(0)
	ps.evo_prog = {"cur": 0, "need": Quest.need_for_id(ps.quest_id)}
	_refresh()
	await get_tree().process_frame
	_expect(_quest_label != null and _quest_label.visible
		and String(_quest_label.text).contains("宣言:猎杀"), "宣言顶栏没有显示昼相默认任务", failures)
	_expect(String(_quest_label.tooltip_text).contains("+2") and String(_quest_label.tooltip_text).contains("+1"),
		"宣言 tooltip 没有说明达成/未达成奖励", failures)
	_open_quest()
	await get_tree().process_frame
	_expect(find_child("quest_overlay", true, false) != null and _quest_buttons.size() == 3,
		"宣言弹窗没有提供三项选择", failures)
	if _quest_buttons.size() >= 2:
		_quest_buttons[1].pressed.emit()
	await get_tree().process_frame
	_expect(ps.quest_id == "press" and ps.quest_index == 1,
		"点击宣言后没有切换到压制定向", failures)
	ps.evo_prog = {"cur": 3, "need": 3}
	_update_quest_visual()
	_expect(String(_quest_label.text).contains("3/3") and String(_quest_label.text).contains("✔"),
		"宣言进度达成时没有显示完成标记", failures)
	ps.phase = 1
	ps.select_quest(0)
	_update_quest_visual()
	_expect(ps.quest_id == "unyield" and String(_quest_label.text).contains("不屈"),
		"切到夜相后没有重新选择夜相任务池", failures)
	ps.phase = 0
	ps.select_quest(0)
	ps.board = _shot_board([{
		"_uid": 11, "n": "宣言奖励体", "a": 3, "h": 5, "mh": 5, "s": 3,
		"race": "evolve", "sk": {"t": "attack", "e": "evolve", "need": 99, "maxD": 0},
	}])
	_refresh()
	await get_tree().process_frame
	_interaction_fx_trace.clear()
	_sfx_trace.clear()
	var reward_targets: Array[Dictionary] = ps.apply_quest_reward(true)
	_expect(reward_targets.size() == 1, "备战期宣言奖励没有返回受益随从", failures)
	_refresh()
	await _play_quest_reward_prep("p", reward_targets, true)
	_expect(_interaction_fx_trace.has("quest_reward_fx"),
		"宣言奖励没有生成从宣言到随从的光球动效", failures)
	_expect(find_child("quest_reward_fx", true, false) != null,
		"宣言奖励光球动效没有加入场景", failures)
	_expect(_sfx_trace.has("evo_full"), "宣言奖励没有播放奖励音效", failures)
	_expect(int(ps.board[0].get("_ev", 0)) >= 2, "备战期宣言奖励没有写回随从进化轮数", failures)
	if failures.is_empty():
		print("[prep_view] 宣言自检通过：顶栏进度/三选一弹窗/昼夜任务池/备战期奖励光球")
		return true
	for failure in failures:
		printerr("[prep_view] 宣言失败：", failure)
	return false


func _mech_test() -> bool:
	var failures: Array[String] = []
	_sfx_trace.clear()
	_battle_fx_trace.clear()
	_expect(_board_has_mech(ps.board), "机械夹具没有识别到机械随从", failures)
	var mech_badge := _mech_badge_spec(ps.board[0], ps)
	_expect(not mech_badge.is_empty(), "机械随从没有生成机械状态角标", failures)
	drop_on_slot(0, 0)
	await get_tree().process_frame
	_expect(ps.hand.is_empty(), "磁力材料喂料后没有离手", failures)
	var fusion: Dictionary = ps.prepare_fusion(ps.mech_level, ps.mag_t, ps.mech_repair)
	_expect(bool(fusion.get("ok", false)), "四部位齐全后不能进入合体", failures)
	if bool(fusion.get("ok", false)):
		_play_sfx("mech_fuse")

	var body: Dictionary = {
		"_uid": 1, "n": "机械战神", "a": 10, "h": 20, "mh": 20, "s": 5,
		"race": "mech", "_charge": 0, "charge_max": 2, "_followType": "strike",
	}
	var enemy: Dictionary = {"_uid": 101, "n": "木桩", "a": 0, "h": 100, "mh": 100, "s": 1, "race": "neutral"}
	var events: Array = [
		{"t": "ch", "id": 1, "c": 1, "cm": 2},
		{"t": "attack", "src": 1, "dst": 101, "atk": 5, "follow": 1},
		{"t": "damage", "src": 1, "dst": 101, "dmg": 5, "hp": 95, "follow": 1},
		{"t": "guard", "id": 1},
		{"t": "armor", "side": "p", "absorbed": 2, "left": 3},
	]
	await _play_battle(events, [body], [enemy], {1: "机械战神", 101: "木桩"})
	for fx_name in ["mech_charge_fx", "mech_follow_fx", "mech_guard_fx", "mech_armor_fx"]:
		_expect(_battle_fx_trace.has(fx_name), "机械动画轨迹缺少 %s" % fx_name, failures)
	for sfx_name in ["magnet", "mech_fuse", "mech_charge", "mech_follow", "mech_guard", "mech_armor"]:
		_expect(_sfx_trace.has(sfx_name), "机械音效轨迹缺少 %s" % sfx_name, failures)
	if failures.is_empty():
		print("[prep_view] 机械自检通过：合体/磁力/充能/协同/维修 UI+动画+音效轨迹")
		return true
	for failure in failures:
		printerr("[prep_view] 机械失败：", failure)
	return false

func _dragon_test() -> bool:
	var failures: Array[String] = []
	_sfx_trace.clear()
	_battle_fx_trace.clear()
	var dragon: Dictionary = {
		"_uid": 1, "n": "秘法巨龙", "a": 10, "h": 14, "mh": 14, "s": 7,
		"race": "dragon", "_atkT": 0, "_gb": 0,
	}
	var enemy: Dictionary = {"_uid": 101, "n": "木桩", "a": 0, "h": 100, "mh": 100, "s": 1, "race": "neutral"}
	var events: Array = [
		{"t": "buff", "id": 1, "a": 4, "h": 4, "source": "dragon-aura"},
		{"t": "buff", "id": 1, "a": 1, "h": 1, "source": "dragon-attack"},
		{"t": "buff", "id": 1, "a": 2, "h": 2, "source": "atk-react"},
		{"t": "buff", "id": 1, "a": 4, "h": 4, "source": "growth-self"},
	]
	await _play_battle(events, [dragon], [enemy], {1: "秘法巨龙", 101: "木桩"})
	for fx_name in ["dragon_aura_fx", "dragon_attack_fx", "dragon_react_fx", "dragon_growth_fx"]:
		_expect(_battle_fx_trace.has(fx_name), "龙族动画轨迹缺少 %s" % fx_name, failures)
	for sfx_name in ["dragon_aura", "dragon_attack", "dragon_react", "dragon_growth"]:
		_expect(_sfx_trace.has(sfx_name), "龙族音效轨迹缺少 %s" % sfx_name, failures)
	_expect(int(dragon.get("a", 0)) == 21 and int(dragon.get("h", 0)) == 25,
		"龙族事件回放没有累计 +11/+11，实际 %d/%d" % [int(dragon.get("a", 0)), int(dragon.get("h", 0))], failures)
	if failures.is_empty():
		print("[prep_view] 龙族自检通过：龙威/攻击成长/攻击反应/自我成长 UI+动画+音效轨迹")
		return true
	for failure in failures:
		printerr("[prep_view] 龙族失败：", failure)
	return false

func _star_test() -> bool:
	var failures: Array[String] = []
	_sfx_trace.clear()
	_battle_fx_trace.clear()
	var star: Dictionary = {
		"_uid": 1, "n": "星灵斗士", "a": 4, "h": 7, "mh": 7, "s": 3,
		"race": "star", "_chain": 0,
	}
	var enemy: Dictionary = {"_uid": 101, "n": "木桩", "a": 0, "h": 100, "mh": 100, "s": 1, "race": "neutral"}
	var events: Array = [
		{"t": "chain", "id": 1, "value": 1, "source": "start"},
		{"t": "amp", "id": 1, "chain": 2, "amp": 1},
		{"t": "attack", "src": 1, "dst": 101, "atk": 9, "chain_bonus": 5},
		{"t": "damage", "src": 1, "dst": 101, "dmg": 9, "hp": 91, "chain_bonus": 5},
		{"t": "damage", "src": 1, "dst": 101, "dmg": 3, "hp": 88, "echo": 1},
	]
	await _play_battle(events, [star], [enemy], {1: "星灵斗士", 101: "木桩"})
	for fx_name in ["star_chain_fx", "star_amp_fx", "star_chain_bonus_fx", "star_echo_fx"]:
		_expect(_battle_fx_trace.has(fx_name), "星灵动画轨迹缺少 %s" % fx_name, failures)
	for sfx_name in ["star_chain", "star_amp", "star_chain_bonus", "star_echo"]:
		_expect(_sfx_trace.has(sfx_name), "星灵音效轨迹缺少 %s" % sfx_name, failures)
	_expect(int(star.get("_chain", 0)) == 2, "星界增幅后卡面连锁没有更新", failures)
	if failures.is_empty():
		print("[prep_view] 星灵自检通过：连锁/增幅/连锁伤害/星光回响 UI+动画+音效轨迹")
		return true
	for failure in failures:
		printerr("[prep_view] 星灵失败：", failure)
	return false

func _undead_test() -> bool:
	var failures: Array[String] = []
	_sfx_trace.clear()
	_battle_fx_trace.clear()
	var undead: Dictionary = {
		"_uid": 1, "n": "永夜骨王", "a": 6, "h": 6, "mh": 6, "s": 6,
		"race": "undead", "_t": 0,
	}
	var enemy: Dictionary = {"_uid": 101, "n": "木桩", "a": 0, "h": 100, "mh": 100, "s": 1, "race": "neutral"}
	var events: Array = [
		{"t": "summon", "src": 1, "id": 2, "slot": 1, "side": "p", "name": "骷髅兵", "a": 1, "h": 1, "s": 1, "race": "undead"},
		{"t": "buff", "id": 1, "a": 1, "h": 1, "source": "undead-death"},
		{"t": "rebirth", "id": 1, "a": 2, "h": 2},
		{"t": "death", "id": 1, "name": "永夜骨王", "a": 6, "h": 6},
	]
	await _play_battle(events, [undead], [enemy], {1: "永夜骨王", 2: "骷髅兵", 101: "木桩"})
	for fx_name in ["summon_fx", "undead_death_fx", "rebirth_fx", "death_fx"]:
		_expect(_battle_fx_trace.has(fx_name), "亡灵动画轨迹缺少 %s" % fx_name, failures)
	for sfx_name in ["summon", "undead_death", "rebirth", "death"]:
		_expect(_sfx_trace.has(sfx_name), "亡灵音效轨迹缺少 %s" % sfx_name, failures)
	var summoned_slot := _child_or_null(_p_row, 1)
	var summoned_name: Label = null
	if summoned_slot != null:
		summoned_name = summoned_slot.find_child("name_label", true, false) as Label
	_expect(summoned_slot != null and summoned_name != null
		and String(summoned_name.text) == "骷髅兵",
		"亡灵召唤进入空位后没有补全随从卡面，出现空白随从", failures)
	if _battle_p_board.size() > 1:
		_expect(_battle_p_board[1] != null and String(_battle_p_board[1].get("n", "")) == "骷髅兵",
			"亡灵召唤单位没有正确写入空槽位数据", failures)
	if _battle_p_board.size() > 0:
		_expect(_battle_p_board[0] == null, "死亡单位动画结束后仍留在战斗棋盘", failures)
	var dead_slot := _child_or_null(_p_row, 0)
	if dead_slot != null:
		_expect(dead_slot.find_child("name_label", true, false) == null,
			"死亡单位动画结束后槽位仍显示空白随从卡面", failures)

	# 真实战斗事件顺序是“先死亡、后亡语召唤”。单独跑一次解析结果，
	# 防止只在手工夹具里验证 summon→death 时漏掉 UI 等待链回归。
	_speed = 20.0
	var real_summoner = UnitScript.from_card({
		"n": "亡语召唤者", "a": 0, "h": 1, "mh": 1, "s": 2, "race": "undead", "k": "t",
		"sk": {"t": "death", "e": "summon", "count": 1},
	}, 1)
	var real_survivor = UnitScript.from_card({
		"n": "亡语幸存者", "a": 20, "h": 40, "mh": 40, "s": 3, "race": "neutral",
	}, 2)
	var real_killer = UnitScript.from_card({
		"n": "亡语杀手", "a": 5, "h": 10, "mh": 10, "s": 3, "race": "neutral",
	}, 101)
	var real_battle: Dictionary = BattleScript.new().resolve(
		[real_summoner, real_survivor], [real_killer], 77, 20)
	var real_display_p: Array = _display_board([real_summoner, real_survivor])
	var real_display_e: Array = _display_board([real_killer])
	var real_names: Dictionary = {
		1: "亡语召唤者", 2: "亡语幸存者", 101: "亡语杀手",
	}
	await _play_battle(real_battle["events"], real_display_p, real_display_e, real_names)
	_expect(_battle_fx_trace.has("death_fx") and _battle_fx_trace.has("summon_fx"),
		"真实亡语战斗没有完成死亡与召唤的 UI 回放", failures)
	if failures.is_empty():
		print("[prep_view] 亡灵自检通过：召唤补全/亡语成长/重生/死亡清场 UI+动画+音效轨迹")
		return true
	for failure in failures:
		printerr("[prep_view] 亡灵失败：", failure)
	return false

func _families_test() -> bool:
	var failures: Array[String] = []
	var enemy: Dictionary = {"_uid": 101, "n": "木桩", "a": 0, "h": 100, "mh": 100, "s": 1, "race": "neutral"}
	var style_colors := {}
	var style_motifs := {}
	for family in MechanicStyle.FAMILY_ORDER:
		var family_style: Dictionary = MechanicStyle.family_style(family)
		var color_key := Color(family_style.get("color", Color.WHITE)).to_html(false)
		style_colors[color_key] = true
		style_motifs[String(family_style.get("motif", ""))] = true
		_expect(MechanicStyle.placeholder_path(family, "cast").contains("/%s/" % family),
			"%s 机制缺少稳定占位资源路径" % family, failures)
	_expect(style_colors.size() == MechanicStyle.FAMILY_ORDER.size(),
		"机制族主色发生复用，无法靠颜色区分机制", failures)
	_expect(style_motifs.size() == MechanicStyle.FAMILY_ORDER.size(),
		"机制族动效母题发生复用，缺少后续替换契约", failures)
	_expect(not Color(MechanicStyle.family_style("sacrifice").get("color")).is_equal_approx(
		Color(MechanicStyle.family_style("vampire").get("color"))),
		"献祭灵魂紫与血族血红仍被合并", failures)
	var lifesteal_controls := _keyword_controls({"race": "vampire", "k": "l", "n": "吸血探针"})
	var lifesteal_colored := false
	for control in lifesteal_controls:
		if control is Label and (control as Label).get_theme_color("font_color").is_equal_approx(
				Color(MechanicStyle.family_style("vampire").get("color"))):
			lifesteal_colored = true
	_expect(lifesteal_colored, "吸血关键词图标仍使用通用白色，而不是血红", failures)
	_expect(not _debt_tier_color(2).is_equal_approx(
		Color(MechanicStyle.family_style("vampire").get("color"))),
		"献祭债务中档仍复用血族红，机制区分不足", failures)
	var mech_support: Dictionary = _mech_badge_spec({
		"race": "mech", "support": "super", "n": "超导探针",
	})
	_expect(not Color(mech_support.get("color", Color.WHITE)).is_equal_approx(
		Color(MechanicStyle.family_style("sacrifice").get("color"))),
		"机械超导支援仍复用献祭紫", failures)
	var family_probes: Array[Dictionary] = [
		{"family": "sacrifice", "source": "inherit", "label": "亡魂继承"},
		{"family": "vampire", "source": "maxhp-buff", "label": "血池扩容"},
		{"family": "evolve", "source": "", "label": "进化"},
		{"family": "mech", "source": "mech-head", "label": "合体核心"},
		{"family": "dragon", "source": "growth-self", "label": "龙裔成长"},
		{"family": "star", "source": "star-echo", "label": "星光回响"},
		{"family": "undead", "source": "undead-death", "label": "亡语成长"},
		{"family": "elem", "source": "spell-cast", "label": "元素法术"},
		{"family": "gambler", "source": "gamble", "label": "赌徒好运"},
		{"family": "demon", "source": "multihit", "label": "恶魔共鸣"},
		{"family": "neutral", "source": "neutral-buff", "label": "中立"},
	]
	for i in range(family_probes.size()):
		var probe: Dictionary = family_probes[i]
		var family := String(probe["family"])
		var uid := 700 + i
		var probe_card: Dictionary = {
			"_uid": uid, "n": "%s探针" % family, "a": 2, "h": 2, "mh": 2,
			"s": 3, "race": family, "_side": "p", "_slot": 0,
		}
		var probe_event := {
			"t": "buff", "id": uid, "a": 1, "h": 1,
			"source": String(probe["source"]),
		}
		for child in get_children():
			if child is Label and String(child.get_meta("event_kind", "")) == "buff":
				child.queue_free()
		await get_tree().process_frame
		_show_battle_float(probe_event, {uid: probe_card})
		var probe_float := _last_battle_float("buff")
		var expected_style: Dictionary = MechanicStyle.family_style(family)
		_expect(probe_float != null and String(probe_float.get_meta("family", "")) == family,
			"%s 代表事件没有回落到正确族色，实际 %s" % [
				family, String(probe_float.get_meta("family", "")) if probe_float != null else "<null>"], failures)
		_expect(probe_float != null and String(probe_float.text).begins_with(String(probe["label"])),
			"%s 代表事件缺少来源文案，实际 %s" % [
				family, String(probe_float.text) if probe_float != null else "<null>"], failures)
		_expect(probe_float != null and probe_float.get_theme_color("font_color").is_equal_approx(
			Color(expected_style.get("color", Color.WHITE))),
			"%s 代表事件没有使用本族主色" % family, failures)
		if probe_float != null:
			probe_float.queue_free()
	for i in range(family_probes.size()):
		var probe: Dictionary = family_probes[i]
		var family := String(probe["family"])
		var source_label := String(probe["source"])
		if family in ["neutral", "evolve"] or source_label in [
			"growth-self", "maxhp-buff", "self-buff", "evolve", "evolve-step",
		]:
			continue
		var source_uid := 800 + i
		var target_uid := 900 + i
		var inferred := _battle_infer_source_uid(
			{"t": "buff", "id": target_uid, "source": source_label},
			target_uid,
			{
				source_uid: {"_uid": source_uid, "race": family, "_side": "p", "a": 5},
				target_uid: {"_uid": target_uid, "race": "neutral", "_side": "p", "a": 1},
			})
		_expect(inferred == source_uid,
			"%s 的来源型效果无法推断发出随从，实际 %d" % [family, inferred], failures)
	var undead_death_uid := 789
	var undead_death_card: Dictionary = {
		"_uid": undead_death_uid, "n": "亡灵死亡探针", "a": 2, "h": 0, "mh": 2,
		"s": 3, "race": "undead", "_side": "p", "_slot": 0,
	}
	_show_battle_float({"t": "death", "id": undead_death_uid, "name": "亡灵死亡探针"},
		{undead_death_uid: undead_death_card})
	var death_float := _last_battle_float("death")
	_expect(death_float != null and String(death_float.get_meta("family", "")) == "undead"
		and String(death_float.text).contains("亡灵"),
		"亡灵死亡仍使用通用阵亡红，没有回到骨白/魂火表现", failures)
	if death_float != null:
		death_float.queue_free()

	_speed = 8.0
	for i in range(family_probes.size()):
		var probe: Dictionary = family_probes[i]
		var family := String(probe["family"])
		var uid := 800 + i
		var pulse_card: Dictionary = {
			"_uid": uid, "n": "%s脉冲" % family, "a": 2, "h": 2, "mh": 2,
			"s": 3, "race": family, "_side": "p", "_slot": 0,
		}
		var pulse_event := {
			"t": "buff", "id": uid, "a": 1, "h": 1,
			"source": String(probe["source"]),
		}
		_battle_pulse_trace.clear()
		await _play_battle([pulse_event], [pulse_card], [enemy], {uid: pulse_card.get("n", "探针")})
		var expected_color := Color(MechanicStyle.family_style(family).get("color", Color.WHITE)).to_html(false)
		_expect(_battle_pulse_trace.has(expected_color),
			"%s 战斗脉冲没有使用本族主色，轨迹=%s" % [family, str(_battle_pulse_trace)], failures)
	_speed = 1.0

	var element: Dictionary = {"_uid": 1, "n": "元素核心", "a": 2, "h": 2, "mh": 2, "s": 4, "race": "elem"}
	_sfx_trace.clear()
	await _play_battle([{"t": "buff", "id": 1, "a": 2, "h": 2, "source": "spell-cast"}],
		[element], [enemy], {1: "元素核心", 101: "木桩"})
	_expect(_battle_fx_trace.has("element_cast_fx") and _sfx_trace.has("element_cast"),
		"元素法术联动缺少 UI/动画/音效轨迹", failures)

	var vampire: Dictionary = {"_uid": 2, "n": "血之主", "a": 5, "h": 5, "mh": 5, "s": 7, "race": "vampire"}
	_sfx_trace.clear()
	await _play_battle([
		{"t": "buff", "id": 2, "a": 3, "h": 3, "source": "vampire-on-dmg"},
		{"t": "heal", "id": 2, "val": 2},
	], [vampire], [enemy], {2: "血之主", 101: "木桩"})
	_expect(_battle_fx_trace.has("vampire_on_dmg_fx") and _battle_fx_trace.has("vampire_heal_fx")
		and _sfx_trace.has("vampire_heal"), "血族成长/治疗缺少 UI/动画/音效轨迹", failures)
	vampire["_side"] = "p"
	vampire["_slot"] = 0
	_show_battle_float({"t": "buff", "id": 2, "a": 3, "h": 3, "source": "vampire-on-dmg"},
		{2: vampire})
	var vampire_float := _last_battle_float("buff")
	_expect(vampire_float != null and String(vampire_float.text) == "血裔成长 +3/+3",
		"血族成长飘字没有写明来源", failures)
	_expect(vampire_float != null and String(vampire_float.get_meta("family", "")) == "vampire"
		and vampire_float.get_theme_color("font_color").is_equal_approx(Color("ff3b30")),
		"血族成长飘字没有使用血红色", failures)
	if vampire_float != null:
		vampire_float.queue_free()

	var sacrifice_probe: Dictionary = {
		"_uid": 9, "n": "契印目标", "a": 4, "h": 4, "mh": 4, "s": 3,
		"race": "sacrifice", "_side": "p", "_slot": 1,
	}
	_show_battle_float({"t": "debt", "src": 9, "side": "p", "old": 0, "debt": 8, "delta": 8},
		{9: sacrifice_probe})
	var sacrifice_float := _last_battle_float("debt")
	_expect(sacrifice_float != null and String(sacrifice_float.text).contains("灵魂债务")
		and String(sacrifice_float.get_meta("family", "")) == "sacrifice",
		"献祭债务飘字没有注明灵魂债务来源", failures)
	_expect(sacrifice_float != null and sacrifice_float.get_theme_color("font_color").is_equal_approx(Color("a29bfe")),
		"献祭债务飘字没有使用灵魂紫", failures)
	if sacrifice_float != null:
		sacrifice_float.queue_free()
	_audit_skill_descriptions(failures)

	var gambler: Dictionary = {"_uid": 3, "n": "豪赌大师", "a": 8, "h": 8, "mh": 8, "s": 7, "race": "gambler"}
	_sfx_trace.clear()
	await _play_battle([{"t": "gamble", "id": 3, "success": true, "mult": 3, "scope": "all"}],
		[gambler], [enemy], {3: "豪赌大师", 101: "木桩"})
	_expect(_battle_fx_trace.has("gamble_fx") and _sfx_trace.has("gamble"),
		"赌徒掷骰缺少 UI/动画/音效轨迹", failures)

	var demon: Dictionary = {"_uid": 4, "n": "亚煞极", "a": 16, "h": 16, "mh": 16, "s": 7, "race": "demon"}
	_sfx_trace.clear()
	await _play_battle([{"t": "buff", "id": 4, "a": 2, "h": 2, "source": "demon-on-dmg"}],
		[demon], [enemy], {4: "亚煞极", 101: "木桩"})
	_expect(_battle_fx_trace.has("demon_on_dmg_fx") and _sfx_trace.has("demon_rage"),
		"恶魔受击成长缺少 UI/动画/音效轨迹", failures)

	var neutral: Dictionary = {"_uid": 5, "n": "时光祝福者", "a": 6, "h": 8, "mh": 8, "s": 6, "race": "neutral"}
	_sfx_trace.clear()
	await _play_battle([{"t": "buff", "id": 5, "a": 1, "h": 1, "source": "neutral-buff"}],
		[neutral], [enemy], {5: "时光祝福者", 101: "木桩"})
	_expect(_battle_fx_trace.has("neutral_buff_fx") and _sfx_trace.has("neutral_buff"),
		"中立成长缺少 UI/动画/音效轨迹", failures)

	var pain_priest: Dictionary = {"_uid": 6, "n": "苦痛侍僧", "a": 3, "h": 5, "mh": 5, "s": 2, "race": "undead"}
	_battle_fx_trace.clear()
	_battle_pulse_trace.clear()
	await _play_battle([{"t": "buff", "id": 6, "a": 2, "h": 2, "source": 4}],
		[pain_priest], [enemy], {4: "苦痛侍僧", 6: "苦痛侍僧", 101: "木桩"})
	_expect(_battle_fx_trace.has("undead_death_fx") or _battle_pulse_trace.size() > 0,
		"整数 source 的战斗成长事件回放中断", failures)

	if failures.is_empty():
		print("[prep_view] 其余机制族自检通过：元素/血族/赌徒/恶魔/中立")
		return true
	for failure in failures:
		printerr("[prep_view] 其余族失败：", failure)
	return false

func _random_start_test() -> bool:
	var failures: Array[String] = []
	var live_seeds := {}
	for i in range(8):
		live_seeds[_resolve_game_seed(false)] = true
		OS.delay_msec(1)
	_expect(live_seeds.size() > 1, "正常游玩仍使用固定启动种子", failures)
	var race_sets := {}
	var ai_plans := {}
	var sacrifice_count := 0
	var sample_races: Array = []
	for i in range(32):
		var seed_value := 7000 + i * 104729
		var races := _pick_races(seed_value, 6)
		race_sets[str(races)] = true
		if races.has("sacrifice"):
			sacrifice_count += 1
		var probe = PrepState.new()
		probe.setup(1, races, GameData.by_star, GameData.spells, seed_value)
		var plan: Dictionary = AI._choose_plan(probe, races, GameData.ai_templates)
		ai_plans[String(plan.get("name", ""))] = true
		AI.run_turn(probe, races, 4, 4, [], GameData.ai_templates)
		var illegal_cards := 0
		for container in [probe.shop, probe.hand, probe.board]:
			for card in container:
				if card == null or String(card.get("t", "")) == "s":
					continue
				var race := String(card.get("race", ""))
				if race != "" and race != "neutral" and not races.has(race):
					illegal_cards += 1
		_expect(illegal_cards == 0, "种子 %d 的 AI 获得了未开放种族卡牌：%d 张" % [seed_value, illegal_cards], failures)
		if sample_races.size() < 3:
			sample_races.append({"seed": seed_value, "races": races, "ai": plan.get("name", "")})
	_expect(race_sets.size() >= 8, "不同种子没有生成足够多的种族组合", failures)
	_expect(ai_plans.size() >= 2, "AI 阵容模板仍固定为单一起手", failures)
	print("[prep_view] 随机启动自检: 种族组合=%d/32 AI模板=%d 献祭出现=%d/32" % [
		race_sets.size(), ai_plans.size(), sacrifice_count])
	print("[prep_view] 随机样例: ", sample_races)
	if failures.is_empty():
		return true
	for failure in failures:
		printerr("[prep_view] 随机启动失败：", failure)
	return false

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _last_battle_float(kind: String) -> Label:
	var last: Label = null
	for child in get_children():
		if child is Label and String(child.get_meta("event_kind", "")) == kind:
			last = child as Label
	return last

func _audit_skill_descriptions(failures: Array[String]) -> void:
	var ability_count := 0
	var card_with_skill_count := 0
	var mechanism_entry_count := 0
	var raced_cards: Dictionary = {}
	for card in GameData.cards:
		var race := String(card.get("race", "neutral"))
		raced_cards[race] = int(raced_cards.get(race, 0)) + 1
		var has_marker := false
		if _card_has_skill(card):
			card_with_skill_count += 1
			var ability_hover := _ability_hover_text(card, ps)
			_expect(ability_hover.strip_edges() != "", "能力查询入口为空：%s" % String(card.get("n", "?")), failures)
			_expect(not ability_hover.contains("公式：") and not ability_hover.contains("结果："),
				"能力悬停没有把公式和结果合并：%s" % String(card.get("n", "?")), failures)
			var styled_ability := _style_hover_text(ability_hover, "ability")
			_expect(styled_ability.contains("[color=#fdcb6e]"),
				"能力悬停缺少核心强调样式：%s" % String(card.get("n", "?")), failures)
			_expect(not ability_hover.contains("触发=") and not ability_hover.contains("来源=") \
				and not ability_hover.contains("结算="),
				"能力悬停混入详细介绍字段：%s" % String(card.get("n", "?")), failures)
			for control in _keyword_controls(card, ps):
				if control is Label and String((control as Label).text) == "⚡":
					has_marker = true
					break
			if not has_marker:
				var marker := _card_skill_marker(card, ps)
				has_marker = marker is Label and String((marker as Label).text) == "⚡"
			_expect(has_marker, "卡面缺少可悬停的技能图标：%s" % String(card.get("n", "?")), failures)
		for spec in _status_badge_specs(card, ps, -1):
			var tooltip_text := String(spec.get("tooltip", ""))
			if tooltip_text == "":
				continue
			mechanism_entry_count += 1
			_expect(not tooltip_text.contains("公式：") and not tooltip_text.contains("结果："),
				"机制悬停没有把公式和结果合并：%s" % String(card.get("n", "?")), failures)
			var styled_mechanism := _style_hover_text(tooltip_text, "mechanism")
			_expect(styled_mechanism.contains("[color=#fdcb6e]"),
				"机制悬停缺少核心强调样式：%s" % String(card.get("n", "?")), failures)
			_expect(not tooltip_text.contains("技能：") and not tooltip_text.contains("触发=") \
				and not tooltip_text.contains("来源=") and not tooltip_text.contains("结算="),
				"机制悬停混入能力或详细字段：%s" % String(card.get("n", "?")), failures)
		for key in ["bc", "sk", "sc", "scSk", "atkSk"]:
			if not card.has(key) or not (card[key] is Dictionary):
				continue
			var skill: Dictionary = card[key]
			if skill.is_empty():
				continue
			ability_count += 1
			var effect_id := String(skill.get("e", ""))
			var short_text := _effect_short_text(skill) if key == "bc" else _skill_short_text(skill)
			var trigger_override := ""
			if key == "bc":
				trigger_override = "上场时"
			elif key == "sc" or key == "scSk":
				trigger_override = "释放法术后"
			elif key == "atkSk":
				trigger_override = "攻击后"
			var detail_text := _skill_detail_text(skill, card, ps, trigger_override)
			var card_summary := _card_tooltip(card, ps, false)
			var card_detail := _card_tooltip(card, ps, true)
			var label := "%s|%s|%s" % [String(card.get("n", "?")), key, effect_id]
			_expect(effect_id != "", "技能缺少效果 ID：%s" % label, failures)
			_expect(short_text.strip_edges() != "" and not short_text.contains("特殊效果"),
				"简略介绍为空或退回占位文案：%s" % label, failures)
			var short_has_id := effect_id != "" and short_text.contains(effect_id)
			_expect(not short_has_id,
				"简略介绍泄露内部效果 ID：%s" % label, failures)
			var detail_valid := detail_text.strip_edges() != ""
			if effect_id != "":
				detail_valid = detail_valid and not detail_text.contains(effect_id)
			_expect(detail_valid,
				"详细介绍为空或泄露内部效果 ID：%s" % label, failures)
			_expect(short_text != detail_text, "简略介绍与详细介绍相同：%s" % label, failures)
			_expect(card_summary != card_detail, "卡牌简略与详细面板相同：%s" % label, failures)
			_expect(card_detail.contains("触发=") and card_detail.contains("结算=") \
				and card_detail.contains("来源="),
				"详细介绍缺少触发、结算或成长来源：%s" % label, failures)
	var generated = {
		"n": "骷髅将军", "a": 2, "h": 2, "s": 6, "race": "undead",
		"sk": {"t": "aura", "e": "skeleton-army"},
	}
	var generated_detail := _card_tooltip(generated, ps, true)
	_expect(generated_detail.contains("亡灵友方死亡时"), "骷髅将军技能仍退回占位文案", failures)
	_expect(not generated_detail.contains("特殊效果"), "骷髅将军详细说明仍显示特殊效果", failures)
	_expect(raced_cards.size() >= 11, "技能文案审计没有覆盖全种族：%d" % raced_cards.size(), failures)
	_expect(ability_count >= 70, "技能文案审计覆盖的卡牌能力过少：%d" % ability_count, failures)
	print("[skill-audit] 卡牌=%d，能力入口卡=%d，能力实例=%d，机制入口=%d，种族=%d"
		% [GameData.cards.size(), card_with_skill_count, ability_count, mechanism_entry_count, raced_cards.size()])
	var devour_text := _effect_text({"e": "devour"})
	_expect(devour_text.contains("17%"), "devour 描述没有写明吞噬契印额外债务", failures)
	var contract_text := _effect_text({"e": "contract-set", "debtBonus": 3})
	_expect(contract_text.contains("最弱") and contract_text.contains("+3"),
		"contract-set 描述没有写清自动选目标和额外债务", failures)
	var inherit_text := _effect_text({"e": "inherit", "rate": 0.0445, "debt": 0.055})
	_expect(inherit_text.contains("4.45%") and inherit_text.contains("5.5%"),
		"inherit 描述没有写明继承比例和债务转化比例", failures)
	var dragon_text := _effect_text({"e": "dragon-aura", "times": 2})
	_expect(dragon_text.contains("龙威层") and dragon_text.contains("场上龙数"),
		"dragon-aura 描述没有写清跨回合龙威公式", failures)
	var payoff_text := _effect_text({"e": "debt-payoff", "a": 1, "h": 1})
	_expect(payoff_text.contains("8点") and payoff_text.contains("18点")
		and payoff_text.contains("32点") and payoff_text.contains("最多结算1个")
		and payoff_text.contains("11回合起全额"),
		"debt-payoff 描述没有写清节点、合并上限与回合折扣", failures)
	var totem_text := _effect_text({"e": "debt-totem"})
	_expect(totem_text.contains("1.17") and totem_text.contains("11%")
		and totem_text.contains("1.5") and totem_text.contains("22%"),
		"debt-totem 描述没有写清普通/金卡两档倍率", failures)
	var style_sample := _style_hover_text("战吼：获得1次免费刷新", "ability")
	_expect(style_sample.contains("战吼：[color=#fdcb6e][b]获得"),
		"核心句没有在标签后单独标金", failures)
	_expect(not style_sample.contains("[color=#fdcb6e][b]战吼："),
		"战吼标签被错误地整体标金", failures)
	_expect(style_sample.contains("[color=#74b9ff][b]1[/b][/color]"),
		"核心句中的数值没有单独标蓝", failures)
	var free_refresh_hover := _ability_hover_text({"n": "渔人猎潮者", "bc": {"e": "free-refresh"}}, ps)
	_expect(free_refresh_hover.contains("获得1次免费刷新") \
		and not free_refresh_hover.contains("免费刷新 +1") \
		and not free_refresh_hover.contains("免费刷新 0 → 1"),
		"免费刷新悬停仍重复追加公式或结果", failures)
	var split_sample := _style_hover_text("战吼：获得1次免费刷新；这张牌后续补充", "ability")
	_expect(split_sample.contains("[/b][/color]；这张牌后续补充"),
		"核心短语结束后没有恢复正常白色描述", failures)
	_expect(not split_sample.contains("；这张牌后续补充[/b][/color]"),
		"后续补充描述错误地继续继承了核心金色样式", failures)
	var supplement_sample := _style_hover_text("技能：基础效果\n攻击后：补充描述", "ability")
	_expect(not supplement_sample.contains("[color=#55efc4]"),
		"后续补充行被错误地标成强调色", failures)

func _child_or_null(node: Node, index: int) -> Control:
	if node == null or index < 0 or index >= node.get_child_count():
		return null
	return node.get_child(index) as Control

func _mouse_click(control: Control, button: int = MOUSE_BUTTON_LEFT) -> void:
	if control == null:
		return
	var at := control.get_global_rect().get_center()
	var viewport := get_viewport()
	print("[input] click=%s rect=%s at=%s viewport=%s" % [
		control.get_class(), control.get_global_rect(), at, viewport.get_visible_rect().size])
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	await get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else 0
	press.position = at
	press.global_position = at
	viewport.push_input(press, true)
	await get_tree().process_frame
	var hovered := viewport.gui_get_hovered_control()
	print("[input] hovered_after_press=", hovered.get_class() if hovered != null else "<null>")
	var release := InputEventMouseButton.new()
	release.button_index = button
	release.pressed = false
	release.button_mask = 0
	release.position = at
	release.global_position = at
	viewport.push_input(release, true)
	await get_tree().process_frame

func _mouse_hover(control: Control) -> void:
	if control == null:
		return
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await get_tree().process_frame

func _first_non_empty_slot(board: Array) -> int:
	for i in range(board.size()):
		if board[i] != null:
			return i
	return -1

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

## `--shot` 专用夹具：与原版对照脚本注入相同的牌面，避免空场造成假差异。
func _apply_shot_fixture() -> void:
	ps.board = _shot_board([
		_shot_card("磁力底盘", 4, 10, 3, "mech", "core", true),
		_shot_card("核心学徒", 4, 5, 3, "mech", "head"),
		_shot_card("磁能臂", 8, 4, 3, "mech", "arm"),
		_shot_card("推进肢体", 3, 12, 3, "mech", "leg", true),
	])
	ep.board = _shot_board([
		_shot_card("秘法学徒", 3, 4, 3, "elem"),
		_shot_card("星象观测者", 2, 4, 2, "star"),
		_shot_card("重装步兵", 3, 5, 4, "", "", true),
	])
	ps.hand = [
		{"n": "装甲模块", "t": "m", "a": 4, "h": 6, "s": 4, "race": "mech", "magA": 4, "magH": 6, "mh": 6},
		{"n": "细胞体", "t": "m", "a": 1, "h": 2, "s": 1, "race": "evolve", "mh": 2},
	]
	ps.gold = 12
	ps.level = 2
	ps.round_no = 4
	ep.gold = 3
	p_hp = 92
	e_hp = 88

## 战斗时间轴验收夹具：固定来源、目标与两个旁观槽位。
func _apply_battle_anim_fixture() -> void:
	var source := _shot_card("攻击来源", 5, 10, 3, "neutral")
	source["_uid"] = 101
	source["sk"] = {"t": "attack", "e": "self-buff", "a": 1, "h": 1}
	var ally := _shot_card("旁观友军", 3, 8, 2, "neutral")
	ally["_uid"] = 102
	var target := _shot_card("受击目标", 4, 9, 3, "neutral")
	target["_uid"] = 201
	var enemy := _shot_card("旁观敌军", 2, 7, 2, "neutral")
	enemy["_uid"] = 202
	ps.board = _shot_board([source, ally])
	ep.board = _shot_board([target, enemy])
	ps.hand = []
	ps.shop = []
	ps.gold = 10
	ps.level = 2
	ps.round_no = 3
	p_hp = 20
	e_hp = 20

func _apply_sacrifice_fixture() -> void:
	var contract_target := _shot_card("血契司仪", 4, 8, 3, "sacrifice")
	contract_target["sk"] = {"e": "contract-set", "a": 1}
	var debt_boost := _shot_card("债务执事", 3, 7, 3, "sacrifice")
	debt_boost["sk"] = {"e": "debt-boost", "a": 2}
	var payoff := _shot_card("血祭司祭", 5, 6, 4, "sacrifice")
	payoff["sk"] = {"e": "debt-payoff"}
	var devourer := _shot_card("献祭者", 2, 5, 3, "sacrifice")
	devourer["sk"] = {"e": "devour"}
	devourer["bc"] = {"e": "devour", "a": 1, "h": 1}
	var neutral := _shot_card("非献祭随从", 6, 6, 3, "neutral")
	ps.board = _shot_board([contract_target, debt_boost, payoff, devourer, neutral])
	ep.board = _shot_board([
		_shot_card("敌方目标甲", 3, 4, 2, "neutral"),
		_shot_card("敌方目标乙", 4, 5, 3, "neutral"),
	])
	ps.hand = [{
		"n": "手牌献祭者", "t": "m", "a": 2, "h": 3, "s": 3, "race": "sacrifice",
		"mh": 3, "bc": {"e": "devour", "a": 1, "h": 1},
	}]
	ps.shop = []
	ps.gold = 10
	ps.level = 3
	ps.round_no = 5
	ps.debt = 0
	ps.contract_id = -1
	ps.contract_bonus = 0
	p_hp = 30
	e_hp = 30

func _apply_mech_fixture() -> void:
	var core := _shot_card("磁力底盘", 4, 10, 3, "mech", "core")
	core["chargeMax"] = 3
	core["chargeFx"] = "shield"
	var head := _shot_card("核心学徒", 4, 5, 3, "mech", "head")
	head["modGrow"] = 1
	var arm := _shot_card("磁能臂", 8, 4, 3, "mech", "arm", false)
	arm["k"] = "w"
	var leg := _shot_card("推进肢体", 3, 12, 3, "mech", "leg")
	leg["modDmg"] = 2
	ps.board = _shot_board([core, head, arm, leg])
	ep.board = _shot_board([_shot_card("敌方木桩", 2, 10, 2, "neutral")])
	ps.hand = [{"n": "装甲模块", "t": "m", "a": 2, "h": 3, "s": 3, "race": "mech",
		"mh": 3, "magA": 4, "magH": 4, "material": true}]
	ps.shop = []
	ps.gold = 10
	ps.level = 3
	ps.round_no = 4
	p_hp = 30
	e_hp = 30

func _shot_board(cards: Array) -> Array:
	var board: Array = []
	for c in cards:
		board.append(c)
	while board.size() < 7:
		board.append(null)
	return board

func _shot_card(n: String, a: int, h: int, s: int, race: String, part: String = "", taunt: bool = false) -> Dictionary:
	var c := {"n": n, "a": a, "h": h, "s": s, "mh": h}
	if race != "":
		c["race"] = race
	if part != "":
		c["part"] = part
	if taunt:
		c["k"] = "t"
	return c

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

func _btn_sb(bg: Color, border: Color, radius: int = 4) -> StyleBoxFlat:
	var s := _sb(bg, border, 4, radius)
	s.content_margin_top = 3.5
	s.content_margin_bottom = 3.5
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	return s

func _muted(text: String, size: int = 11) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", C_MUTED)
	return l

func _clear_ui_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _btn(text: String, bg: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 24)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", _btn_sb(bg, bg))
	b.add_theme_stylebox_override("hover", _btn_sb(bg.lightened(0.18), C_GOLD))
	b.add_theme_stylebox_override("pressed", _btn_sb(bg.darkened(0.2), bg))
	b.add_theme_stylebox_override("disabled", _btn_sb(C_LINE, C_LINE))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)
	return b

## 卡面：星级 / 种族与关键词 / 名字 / 机械部位 / 攻(红)-血(绿)，可选价格
func _fill_card(box: Control, c: Dictionary, w: int, height: int, show_price: bool) -> void:
	box.custom_minimum_size = Vector2(w, height)
	box.clip_contents = true
	if String(c.get("t", "")) == "s":
		_fill_spell_card(box, c, show_price)
		return
	var packed: Dictionary = c
	var star := int(packed.get("s", packed.get("star", 1)))
	var is_gold: bool = bool(packed.get("g", false))
	var border: Color = C_GOLD if is_gold else C_LINE_FILL
	box.add_theme_stylebox_override("panel", _sb(C_SLOT_FILL, border, 3))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 1)
	m.add_theme_constant_override("margin_left", 2)
	m.add_theme_constant_override("margin_right", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	box.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	m.add_child(vb)

	var head := Label.new()
	head.text = "⭐".repeat(clampi(star, 1, 7))
	head.add_theme_font_size_override("font_size", 7)
	head.add_theme_color_override("font_color", C_GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)

	_fill_name_lines(vb, packed, ps, -1, 10, 20 if show_price else 18)

	var ah := HBoxContainer.new()
	ah.alignment = BoxContainer.ALIGNMENT_CENTER
	ah.add_theme_constant_override("separation", 0)
	var stat_size := 10 if show_price else 9
	var a := Label.new()
	a.text = str(int(packed.get("a", 0)))
	a.add_theme_font_size_override("font_size", stat_size)
	a.add_theme_color_override("font_color", C_ATK)
	var sep := Label.new()
	sep.text = "/"
	sep.add_theme_font_size_override("font_size", stat_size)
	sep.add_theme_color_override("font_color", C_MUTED)
	var hp_lbl := Label.new()
	hp_lbl.text = str(int(packed.get("h", 0)))
	hp_lbl.add_theme_font_size_override("font_size", stat_size)
	hp_lbl.add_theme_color_override("font_color", C_HP)
	ah.add_child(a); ah.add_child(sep); ah.add_child(hp_lbl)
	vb.add_child(ah)

	if show_price:
		var price_spacer := Control.new()
		price_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(price_spacer)
		var price := Label.new()
		price.text = "🪙%d" % ps.buy_cost(packed)
		price.add_theme_font_size_override("font_size", 10)
		price.add_theme_color_override("font_color", C_GOLD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(price)

func _fill_spell_card(box: Control, c: Dictionary, show_price: bool) -> void:
	box.add_theme_stylebox_override("panel", _sb(Color("20233a"), Color("8a6d3a"), 3))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_left", 3)
	m.add_theme_constant_override("margin_right", 3)
	m.add_theme_constant_override("margin_bottom", 2)
	box.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	m.add_child(vb)
	var icon := Label.new()
	icon.text = "✦"
	icon.add_theme_font_size_override("font_size", 10)
	icon.add_theme_color_override("font_color", C_GOLD)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(icon)
	var name := Label.new()
	name.text = String(c.get("n", "法术"))
	name.add_theme_font_size_override("font_size", 10)
	name.add_theme_color_override("font_color", C_GOLD)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.max_lines_visible = 2
	name.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	vb.add_child(name)
	var effect := Label.new()
	effect.text = String(c.get("x", "法术效果"))
	effect.add_theme_font_size_override("font_size", 8)
	effect.add_theme_color_override("font_color", C_SUBTLE)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible = 2
	effect.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	vb.add_child(effect)
	if show_price:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(spacer)
		var price := Label.new()
		price.text = "🪙%d" % ps.buy_cost(c)
		price.add_theme_font_size_override("font_size", 10)
		price.add_theme_color_override("font_color", C_GOLD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(price)

func _fill_name_lines(vb: Control, c: Dictionary, state = null, slot: int = -1, font_size: int = 10, min_height: int = 18) -> void:
	var keyword_controls := _keyword_controls(c, state)
	var badge_specs := _status_badge_specs(c, state, slot)
	var info := VBoxContainer.new()
	info.name = "card_info"
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size = Vector2(0, min_height)
	info.clip_contents = true
	var name_line := HBoxContainer.new()
	name_line.name = "name_line"
	name_line.add_theme_constant_override("separation", 2)
	name_line.alignment = BoxContainer.ALIGNMENT_CENTER
	name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_line.custom_minimum_size = Vector2(0, 12)
	for icon in keyword_controls:
		var keyword_control: Control = icon
		keyword_control.mouse_filter = Control.MOUSE_FILTER_PASS
		name_line.add_child(keyword_control)

	var nm := Label.new()
	nm.name = "name_label"
	nm.text = String(c.get("n", "?"))
	nm.add_theme_font_size_override("font_size", font_size)
	nm.add_theme_color_override("font_color", C_GOLD if bool(c.get("g", false)) else C_NAME)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.clip_text = false
	nm.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_height := maxi(14, min_height - (12 if not badge_specs.is_empty() else 0))
	nm.custom_minimum_size = Vector2(0, name_height)
	nm.mouse_filter = Control.MOUSE_FILTER_PASS
	name_line.add_child(nm)
	name_line.custom_minimum_size = Vector2(0, name_height)
	info.add_child(name_line)
	var badge_line := HFlowContainer.new()
	badge_line.name = "badge_line"
	badge_line.add_theme_constant_override("h_separation", 2)
	badge_line.add_theme_constant_override("v_separation", 0)
	badge_line.alignment = FlowContainer.ALIGNMENT_CENTER
	badge_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_line.custom_minimum_size = Vector2(0, 12)
	badge_line.clip_contents = true
	_fill_badge_line(badge_line, c, state, slot)
	info.add_child(badge_line)
	vb.add_child(info)

func _fill_badge_line(badge_line: HFlowContainer, c: Dictionary, state = null, slot: int = -1) -> void:
	for child in badge_line.get_children():
		badge_line.remove_child(child)
		child.queue_free()
	if _card_has_skill(c):
		var skill_marker := _card_skill_marker(c, state, slot)
		_attach_card_tooltip(skill_marker, c, state)
		badge_line.add_child(skill_marker)
	for spec in _status_badge_specs(c, state, slot):
		badge_line.add_child(_status_badge_label(spec, c, state, slot))

func _status_badge_specs(c: Dictionary, state = null, slot: int = -1) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var mech_spec := _mech_badge_spec(c, state)
	if not mech_spec.is_empty():
		mech_spec["tooltip"] = _mechanism_hover_text(c, state, "mech")
		mech_spec["kind"] = "mech"
		specs.append(mech_spec)
	var race := String(c.get("race", ""))
	if race == "star":
		var chain := int(state.chain) if state != null else 0
		chain = int(c.get("_chain", c.get("chain", chain)))
		specs.append({
			"text": "连锁 %d" % chain,
			"color": MechanicStyle.family_style("star").get("accent", C_GOLD),
			"tooltip": _mechanism_hover_text(c, state, "star"),
			"kind": "star",
		})
	if race == "sacrifice" and state != null:
		var debt := int(state.debt)
		debt = int(c.get("_debt", debt))
		var tier := _debt_tier(debt)
		var tier_text: String = ["", "·小", "·中", "·大"][tier]
		specs.append({
			"text": "债%d%s" % [debt, tier_text],
			"color": _debt_tier_color(tier),
			"tooltip": _mechanism_hover_text(c, state, "sacrifice"),
			"kind": "sacrifice",
		})
		if state == ps and bool(c.get("_contract", false)):
			specs.append({
				"text": "契印",
				"color": C_CONTRACT,
				"tooltip": _mechanism_hover_text(c, state, "sacrifice"),
				"kind": "sacrifice",
			})
	if race == "evolve":
		var skill: Dictionary = c.get("sk", {})
		var effect := String(skill.get("e", ""))
		if effect == "evo-devourer":
			specs.append({
				"text": "基因 %d/5" % mini(5, int(c.get("_gene", c.get("gene", 0)))),
				"color": C_GOLD,
				"tooltip": _mechanism_hover_text(c, state, "evolve"),
				"kind": "evolve",
			})
		elif effect == "progress":
			specs.append({
				"text": "孵化 %d/5" % mini(5, int(c.get("_pr", 0))),
				"color": Color("7bed9f"),
				"tooltip": _mechanism_hover_text(c, state, "evolve"),
				"kind": "evolve",
			})
		else:
			var need := int(skill.get("need", c.get("need", 3)))
			var current := int(c.get("_evo", c.get("evo", 0)))
			specs.append({
				"text": "进化 %d/%d" % [current, need],
				"color": Color("7bed9f"),
				"tooltip": _mechanism_hover_text(c, state, "evolve"),
				"kind": "evolve",
			})
		if bool(c.get("_devourReady", false)):
			specs.append({
				"text": "⚑",
				"color": MechanicStyle.family_style("sacrifice").get("accent", C_GOLD),
				"tooltip": "待吞噬：拖到另一名我方随从上结算。",
				"kind": "devour",
			})
	if race == "dragon":
		specs.append({
			"text": "龙威 %d" % int(state.dragon_layer if state != null else c.get("_dragonLayer", 0)),
			"color": MechanicStyle.family_style("dragon").get("accent", C_GOLD),
			"tooltip": _mechanism_hover_text(c, state, "dragon"),
			"kind": "dragon",
		})
	if race == "undead":
		specs.append({
			"text": "死亡 %d" % int(state.undead_tick if state != null else c.get("_udBase", 0)),
			"color": MechanicStyle.family_style("undead").get("color", C_MUTED),
			"tooltip": _mechanism_hover_text(c, state, "undead"),
			"kind": "undead",
		})
	return specs

func _mechanism_hover_text(c: Dictionary, state = null, kind: String = "") -> String:
	var lines: Array[String] = []
	match kind:
		"star":
			var chain := int(c.get("_chain", state.chain if state != null else 0))
			var amp := int(state.star_amp if state != null else c.get("_amp", 0))
			var damage := int(round(float(chain) * 1.5 * float(maxi(1, amp))))
			lines.append("星灵连锁：当前 %d 层，星界增幅 ×%d；本次追加 %d×1.5×%d=%d 点伤害。" % [
				chain, maxi(1, amp), chain, maxi(1, amp), damage])
		"sacrifice":
			var debt := int(c.get("_debt", state.debt if state != null else 0))
			var tier := _debt_tier(debt)
			var tier_name: String = ["未到节点", "小节点", "中节点", "大节点"][tier]
			var next_node := 8 if debt < 8 else (18 if debt < 18 else (32 if debt < 32 else 32))
			lines.append("献祭债务：当前 %d 点（%s）；8/18/32 点分别进入小/中/大节点。" % [debt, tier_name])
			if debt < 32:
				lines.append("下一节点：%d 点，还差 %d 点。" % [next_node, maxi(0, next_node - debt)])
			else:
				lines.append("已进入大节点，可直接参与结算。")
			if bool(c.get("_contract", false)):
				lines.append("契印：该随从阵亡或备战时被吞噬会追加债务。")
		"evolve":
			var skill: Dictionary = c.get("sk", {})
			var effect := String(skill.get("e", ""))
			if effect == "evo-devourer":
				var gene := mini(5, int(c.get("_gene", c.get("gene", 0))))
				lines.append("基因：%d/5；每层+2/+2，当前基因收益+%d/+%d。" % [gene, gene * 2, gene * 2])
			elif effect == "progress":
				var progress := mini(5, int(c.get("_pr", 0)))
				lines.append("孵化进度：%d/5；战斗胜利与进化宣言推进，还差%d格。" % [progress, maxi(0, 5 - progress)])
			else:
				var need := int(skill.get("need", c.get("need", 3)))
				var current := int(c.get("_evo", c.get("evo", 0)))
				var total := int(c.get("_ev", 0))
				var transformed := int(c.get("_vc", c.get("vc", 0))) \
					if String(skill.get("t", "")) == "on-dmg" else int(c.get("_vd", c.get("vd", 0)))
				lines.append("进化条：%d/%d；每次触发+1格，满%d格质变，还差%d格；已进化%d轮，已质变%d次。" % [
					current, need, need, maxi(0, need - current), total, transformed])
		"mech":
			var mech_state = state if state != null else ps
			var part := _part_label(String(c.get("part", "")))
			var charge_max := int(c.get("chargeMax", 0))
			var charge_now := int(c.get("charge", c.get("_charge", 0)))
			lines.append("机械：部位%s，出击Lv%d，充能%d/%d，护甲%d；由磁力喂料、合体继承和充能协议实时结算。" % [
				part if part != "" else "无", int(mech_state.mech_level), charge_now, charge_max, int(mech_state.mech_repair)])
			if charge_max > 0:
				lines.append("充能：%d/%d；%s" % [
					charge_now, charge_max, _charge_text(c)])
			if String(c.get("support", "")) != "":
				lines.append(_support_text(String(c.get("support", ""))))
		"dragon":
			var layer := int(state.dragon_layer if state != null else c.get("_dragonLayer", 0))
			var dragon_count := _dragon_count(state)
			var gain := layer * dragon_count
			lines.append("龙威：%d 层，场上龙%d；本次 %d×%d=+%d/+%d。" % [
				layer, dragon_count, layer, dragon_count, gain, gain])
		"undead":
			var deaths := int(state.undead_tick if state != null else c.get("_udBase", 0))
			lines.append("本局累计死亡：%d；死亡层级=ceil((%d+1)/2)=%d。" % [
				deaths, deaths, int(ceil(float(deaths + 1) / 2.0))])
		"devour":
			lines.append("待吞噬：拖到另一名我方随从上，获得其当前攻击/生命；契印目标债务额外+17%。")
	return "\n".join(PackedStringArray(lines))

func _status_badge_label(spec: Dictionary, c: Dictionary, state = null, slot: int = -1) -> Label:
	var badge := Label.new()
	var color: Color = spec.get("color", C_MUTED)
	badge.text = String(spec.get("text", ""))
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", color)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0, 0, 0, 0)
	badge_style.border_color = color
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(3)
	badge_style.content_margin_left = 2.0
	badge_style.content_margin_right = 2.0
	badge_style.content_margin_top = 0.0
	badge_style.content_margin_bottom = 0.0
	badge.add_theme_stylebox_override("normal", badge_style)
	badge.custom_minimum_size = Vector2(0, 12)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	badge.set_meta("card_detail_tooltip", true)
	var tooltip_text := String(spec.get("tooltip", ""))
	if tooltip_text != "":
		badge.set_meta("card_tooltip_summary", tooltip_text)
		badge.set_meta("card_tooltip_mode", "mechanism")
		badge.set_meta("mechanism_kind", String(spec.get("kind", "")))
		badge.set_meta("card_tooltip_state", state)
		badge.set_meta("card_tooltip_slot", slot)
		_attach_card_tooltip(badge, c, state)
	return badge

func _mech_badge_label(text: String, c: Dictionary) -> Label:
	return _status_badge_label({"text": text, "color": _mech_badge_color(c)}, c)

func _keyword_controls(c: Dictionary, state = null) -> Array[Control]:
	var controls: Array[Control] = []
	var race := String(c.get("race", ""))
	if race != "":
		if race == "mech" or race == "sacrifice":
			controls.append(_card_glyph(race))
		else:
			controls.append(_keyword_icon(_race_icon(race)))
	var k := String(c.get("k", ""))
	if k.contains("t"):
		controls.append(_card_glyph("shield"))
	if k.contains("d"):
		controls.append(_keyword_icon("🛡✦", C_GOLD))
	if k.contains("p"):
		controls.append(_keyword_icon("☠", Color("7bed9f")))
	if k.contains("w"):
		controls.append(_keyword_icon("⚔⚔", C_GOLD))
	if k.contains("l"):
		controls.append(_keyword_icon("♥", MechanicStyle.family_style("vampire").get("color", C_ATK)))
	if k.contains("b"):
		controls.append(_keyword_icon("🏹", Color("e17055")))
	if bool(c.get("magnet", false)):
		controls.append(_keyword_icon("🧲", MechanicStyle.family_style("mech").get("color", C_BLUE)))
	return controls

func _card_has_skill(c: Dictionary) -> bool:
	for key in ["bc", "sk", "sc", "scSk", "atkSk"]:
		if c.get(key) is Dictionary and not (c[key] as Dictionary).is_empty():
			return true
	if bool(c.get("material", false)) or bool(c.get("magnet", false)):
		return true
	if String(c.get("support", "")) != "" or String(c.get("followType", c.get("follow_type", ""))) != "":
		return true
	if int(c.get("chargeMax", 0)) > 0:
		return true
	if c.has("modGrow") or c.has("modDmg") or c.has("modAtk") or c.has("modShield") or bool(c.get("headDouble", false)):
		return true
	return false

func _card_skill_marker(c: Dictionary, state = null, slot: int = -1) -> Control:
	var icon := _keyword_icon("⚡", _card_skill_color(c))
	var detail_state = state if state != null else ps
	icon.set_meta("card_tooltip_mode", "ability")
	icon.set_meta("card_tooltip_slot", slot)
	icon.set_meta("card_tooltip_summary", _ability_hover_text(c, detail_state))
	icon.set_meta("card_tooltip_detail", _card_tooltip(c, detail_state, true))
	return icon

func _card_skill_color(c: Dictionary) -> Color:
	var race := String(c.get("race", "neutral"))
	if race == "":
		race = "neutral"
	if race == "neutral":
		return C_GOLD
	return Color(MechanicStyle.family_style(race).get("accent", C_GOLD))

func _ability_hover_text(c: Dictionary, state = null) -> String:
	var lines: Array[String] = []
	if c.get("bc") is Dictionary and not (c["bc"] as Dictionary).is_empty():
		lines.append(_ability_hover_line("战吼", c["bc"], c, state, "上场时"))
	if c.get("sk") is Dictionary and not (c["sk"] as Dictionary).is_empty():
		lines.append(_ability_hover_line("技能", c["sk"], c, state))
	if c.get("sc") is Dictionary and not (c["sc"] as Dictionary).is_empty():
		lines.append(_ability_hover_line("法术联动", c["sc"], c, state, "释放法术后"))
	if c.get("scSk") is Dictionary and not (c["scSk"] as Dictionary).is_empty():
		lines.append(_ability_hover_line("施法联动", c["scSk"], c, state, "释放法术后"))
	if c.get("atkSk") is Dictionary and not (c["atkSk"] as Dictionary).is_empty():
		lines.append(_ability_hover_line("攻击后", c["atkSk"], c, state, "攻击后"))
	if int(c.get("chargeMax", 0)) > 0:
		var charge_now := int(c.get("charge", c.get("_charge", 0)))
		lines.append("充能：受击/攻击累积，满%d层触发%s；当前%d/%d，还差%d层。" % [
			int(c.get("chargeMax", 0)), _charge_text(c), charge_now, int(c.get("chargeMax", 0)),
			maxi(0, int(c.get("chargeMax", 0)) - charge_now)])
	if bool(c.get("material", false)):
		lines.append("磁力材料：拖到我方机械随从上，目标获得 +%d/+%d；当前可作为 +%d/+%d 强化材料。" % [
			int(c.get("magA", 0)), int(c.get("magH", 0)), int(c.get("magA", 0)), int(c.get("magH", 0))])
	if String(c.get("support", "")) != "":
		lines.append("支援：" + _support_text(String(c.get("support", ""))))
	if bool(c.get("magnet", false)):
		lines.append("磁力：与目标机械属性合并；当前可直接与我方机械随从合体。")
	if c.has("modGrow") or c.has("modDmg") or c.has("modAtk") or c.has("modShield") or bool(c.get("headDouble", false)):
		lines.append("合体强化：按合体强化字段叠加；当前：" + _mod_text(c) + "。")
	return "\n".join(PackedStringArray(lines))

func _ability_hover_line(label: String, skill: Dictionary, c: Dictionary, state = null, trigger_override: String = "") -> String:
	var text := label + "："
	if trigger_override == "":
		text += _skill_short_text(skill)
	else:
		text += _effect_short_text(skill)
	var effect_id := String(skill.get("e", ""))
	var static_complete := ["free-refresh", "self", "ally-atk", "gold", "dmg-rnd", "summon", "chain-start"].has(effect_id)
	if not static_complete:
		var formula := _ability_hover_formula(skill, c, state)
		if formula != "":
			text += "；" + formula
		var result := _ability_hover_result(skill, c, state)
		if result != "":
			text += "，" + result
	return text

func _ability_hover_formula(skill: Dictionary, _c: Dictionary, _state = null) -> String:
	var effect_id := String(skill.get("e", ""))
	var add_a := int(skill.get("a", 0))
	var add_h := int(skill.get("h", 0))
	var times := maxi(1, int(skill.get("times", 1)))
	match effect_id:
		"ally-atk":
			return "目标攻击 +%d" % add_a
		"ally-rnd":
			return "随机1名友方 +%d/+%d" % [add_a, add_h]
		"self":
			return "自身 +%d/+%d" % [add_a, add_h]
		"self-buff":
			if String(skill.get("t", "")) == "on-dmg" and bool(skill.get("grow", false)):
				return "本次 +%d/+%d，之后每次受击再 +1" % [add_a, add_h]
			return "自身 +%d/+%d" % [add_a, add_h]
		"self-race-buff":
			return "自身与%s +%d/+%d" % [GameData.race_name(String(skill.get("race", ""))), add_a, add_h]
		"maxhp-buff":
			return "本次 +%d/+%d，最大生命同步 +%d" % [add_a, add_h, add_h]
		"growth-self":
			return "本次成长 +%d，之后每回合成长值再 +%d" % [times, times]
		"growth-boost":
			return "成长类效果 +%d" % times
		"spell-boost":
			return "后续法术永久 +%d/+%d" % [add_a, add_h]
		"spell-boost-grow":
			return "每回合法术强化 +%d/+%d，逐回合递增" % [add_a, add_h]
		"spell-core":
			return "每次施法自身 +%d/+%d 且递增；全元素 +%d/+%d" % [
				add_a, add_h, int(skill.get("raceA", add_a)), int(skill.get("raceH", add_h))]
		"spell-race-grow":
			return "全元素 +%d/+%d，本回合每次施法再 +1/+1（最多%d次）" % [
				add_a, add_h, int(skill.get("max", 3))]
		"race-buff":
			var race := String(skill.get("race", ""))
			if race == "star":
				return "连锁 +1；星灵 +当前连锁×%d" % int(skill.get("statScale", 1))
			if race == "undead" and String(skill.get("t", "")) == "death":
				return "亡灵 +(基础%d + 死亡层级%d)/+(基础%d + 死亡层级%d)" % [add_a, add_h, add_a, add_h]
			return "%s +%d/+%d%s" % [GameData.race_name(race), add_a, add_h,
				"×成长层" if bool(skill.get("grow", false)) else ""]
		"rnd-race-buff":
			return "随机亡灵 +(基础%d + 死亡层级)/+(基础%d + 死亡层级)" % [add_a, add_h]
		"gamble":
			return "%d%% 成功，目标 +%d/+%d ×%d-%d倍" % [
				int(round(float(skill.get("succ", 0.65)) * 100.0)), add_a, add_h,
				int(skill.get("ml", times)), int(skill.get("mh", int(skill.get("ml", times)) + 1))]
		"evolve", "evolve-step":
			var need := int(skill.get("need", 2 if skill.has("maxD") else 3))
			if String(skill.get("t", "")) == "on-dmg":
				return "每次受击 +1 攻击、进度 +1；满%d格攻击×1.5" % need
			return "每次触发 +1/+1、进度 +1；满%d格质变" % need
		"evo-advance":
			return "全体进化 +1格；自身 +%d×成长层/+%d×成长层" % [times, times]
		"progress":
			return "战斗胜利 +%d 进度，满5格蜕变" % maxi(1, int(skill.get("times", 1)))
		"evo-devourer":
			return "每层基因 +2/+2，上限5层"
		"chain-start":
			return "连锁 +1"
		"chain-dmg":
			return "追加伤害=连锁×1.5×星界增幅"
		"star-amp":
			return "连锁 +1；连锁伤害翻倍"
		"star-echo":
			return "星光伤害=连锁×1.5"
		"dragon-aura":
			return "龙威 +%d；全龙 +(龙威×场上龙数)" % times
		"dragon-aura-minor":
			return "全龙 +(龙威×场上龙数×3/4)"
		"atk-react":
			return "本次 +%d/+%d，之后按本回合触发次数递增" % [add_a, add_h]
		"undead-rebirth":
			return "重生属性=基础 +%d/+%d，按回合递增" % [add_a, add_h]
		"multihit":
			return "攻击%d次；每次恶魔 +当前回合数/+当前回合数" % times
		"heal-race":
			return "治疗=攻击力一半；受益血族再 +%d/+%d" % [add_a, add_h]
		"race-heal":
			return "治疗=攻击力一半"
		"lockhp":
			return "生命低于50%%时，受伤×0.67"
		"coin-spell-boost":
			return "每花5金，法术强化 +%d 并攻血交替" % times
		"mech-supply":
			return "获得%d张机械材料" % int(skill.get("count", 1))
		"mech-info":
			return String(skill.get("txt", "按机械协议结算"))
		"summon":
			return "召唤%d个骷髅兵" % int(skill.get("count", 1))
		"devour":
			return "获得目标当前攻/血；契印目标额外+17%债务"
		"devour-shop":
			return "" if times <= 1 else "获得商店随从数值×%d" % times
		"contract-set":
			return "契印目标债务额外+%d" % int(skill.get("debtBonus", 3))
		"debt-boost":
			return "契印结算债务额外+%d" % add_a
		"debt-payoff":
			return "8/18/32节点 +1/+1、+2/+3、+3/+8；多个结算合并×1.2"
		"debt-interest":
			return "债务 +%d 且逐回合递增" % maxi(1, int(skill.get("count", 1)))
		"debt-lord":
			return "小/中/大节点分别约 +%d/+%d/+%d" % [
				maxi(1, int(round(float(add_a) / 3.0))), add_a, add_a * 2]
		"death-race-buff":
			return "献祭 +(上回合死亡数×%d/3)，上限随债务节点提高" % add_a
		"debt-totem":
			return "契印债务×1.17（金卡×1.5）；节点结算返还消耗债务的11%（金卡22%）"
		"inherit":
			return "继承死亡友方4.45%攻击/生命，至少+1/+1；债务结算后再吞噬5.5%"
		"dmg-allies":
			return "对除自己外友方造成%d点伤害×%d次" % [int(skill.get("d", 1)), times]
		"all-buff":
			return "友方死亡时全体 +%d/+%d" % [add_a, add_h]
		"shop-buff":
			return "商店%s +%d/+%d" % [
				"元素" if String(skill.get("race", "")) == "elem" else "随从", add_a, add_h]
		"self-growth-boost":
			return "每次施法后，本局成长效果再 +%d" % times
		"free-refresh":
			return "免费刷新 +1"
		"gold":
			return "获得 %d 金" % int(skill.get("g", skill.get("a", 1)))
		"dmg-rnd":
			return "对随机敌人造成 %d 点伤害" % int(skill.get("d", add_a))
		"skeleton-army":
			return "亡灵友方死亡时自身 +1/+1"
	return ""

func _ability_hover_result(skill: Dictionary, c: Dictionary, state = null) -> String:
	var effect_id := String(skill.get("e", ""))
	var add_a := int(skill.get("a", 0))
	var add_h := int(skill.get("h", 0))
	var runtime := _skill_runtime_text(skill, c, state)
	match effect_id:
		"free-refresh":
			var free_now := int(state.free_refresh if state != null else 0)
			return "免费刷新 %d → %d" % [free_now, free_now + 1]
		"gold":
			var gold_now := int(state.gold if state != null else 0)
			var gain := int(skill.get("g", skill.get("a", 1)))
			return "金币 %d → %d" % [gold_now, gold_now + gain]
		"self":
			return "当前 %d/%d → %d/%d" % [
				int(c.get("a", 0)), int(c.get("h", 0)), int(c.get("a", 0)) + add_a, int(c.get("h", 0)) + add_h]
		"self-buff":
			var hit_count := int(c.get("_dHit", 0))
			if bool(skill.get("grow", false)):
				return "当前受击%d次；下次 +%d/+%d" % [
					hit_count, maxi(1, add_a) + hit_count, maxi(1, add_h) + hit_count]
			return "触发后 +%d/+%d" % [add_a, add_h]
		"growth-self":
			var total_growth := int(c.get("_g", 0)) + int(c.get("_gb", 0))
			var gain := total_growth + maxi(1, int(skill.get("times", 1)))
			return "当前成长层%d；下次 +%d/+%d" % [total_growth, gain, gain]
		"spell-boost":
			var boost: Dictionary = state.spell_boost if state != null else {"a": 0, "h": 0}
			return "法术增幅 %d/%d → %d/%d" % [
				int(boost.get("a", 0)), int(boost.get("h", 0)),
				int(boost.get("a", 0)) + add_a, int(boost.get("h", 0)) + add_h]
		"spell-boost-grow":
			var current_boost: Dictionary = state.spell_boost if state != null else {"a": 0, "h": 0}
			return "当前法术增幅 %d/%d" % [int(current_boost.get("a", 0)), int(current_boost.get("h", 0))]
		"spell-core":
			var core_hits := int(c.get("_coreT", 0))
			return "当前施法%d次；下次自身 +%d/+%d，全元素 +%d/+%d" % [
				core_hits, add_a + core_hits, add_h + core_hits,
				int(skill.get("raceA", add_a)), int(skill.get("raceH", add_h))]
		"spell-race-grow":
			var ice_hits := int(c.get("_iceT", 0))
			return "本回合已施法%d次；下次全元素 +%d/+%d" % [
				ice_hits, add_a + ice_hits, add_h + ice_hits]
		"race-buff":
			var race := String(skill.get("race", ""))
			if race == "star":
				var chain := int(state.chain if state != null else 0)
				var gain := int(round(float(chain) * float(skill.get("statScale", 1))))
				return "当前连锁%d；本次 %s星灵 +%d/+%d" % [
					chain, "随机" if String(skill.get("scope", "")) == "rnd" else "全体", gain, gain]
			if race == "undead" and String(skill.get("t", "")) == "death":
				var deaths := int(state.undead_tick if state != null else c.get("_udBase", 0))
				var bonus := int(ceil(float(deaths + 1) / 2.0))
				return "当前累计死亡%d；本次亡灵 +%d/+%d" % [deaths, add_a + bonus, add_h + bonus]
			var level := int(c.get("_t", 1))
			return "当前成长层%d；本次 %s +%d/+%d" % [
				level, GameData.race_name(race), add_a * level, add_h * level]
		"evo-advance":
			var level := int(c.get("_t", 1))
			return "当前成长层%d；本次自身 +%d/+%d" % [level, maxi(1, add_a) * level, maxi(1, add_h) * level]
		"evolve", "evolve-step":
			var need := int(skill.get("need", 2 if skill.has("maxD") else 3))
			var current := int(c.get("_evo", c.get("evo", 0)))
			var finished := int(c.get("_vc", c.get("vc", 0))) \
				if String(skill.get("t", "")) == "on-dmg" else int(c.get("_vd", c.get("vd", 0)))
			return "当前进化条%d/%d，已质变%d次；下次触发后 %d/%d" % [
				current, need, finished, mini(need, current + 1), need]
		"progress":
			return "当前孵化%d/5" % mini(5, int(c.get("_pr", 0)))
		"evo-devourer":
			return "当前基因%d/5" % mini(5, int(c.get("_gene", c.get("gene", 0))))
		"chain-start":
			return "当前连锁%d；触发后 %d" % [
				int(state.chain if state != null else 0),
				int(state.chain if state != null else 0) + 1]
		"chain-dmg":
			var chain := int(state.chain if state != null else 0)
			var amp := maxi(1, int(state.star_amp if state != null else 0))
			return "当前连锁%d，增幅×%d；追加%d伤害" % [chain, amp, int(round(float(chain) * 1.5 * float(amp)))]
		"star-echo":
			var chain2 := int(state.chain if state != null else 0)
			return "当前连锁%d；星响%d伤害" % [chain2, int(round(float(chain2) * 1.5))]
		"star-amp":
			var chain3 := int(state.chain if state != null else 0)
			return "当前连锁%d；触发后连锁%d且连锁伤害翻倍" % [chain3, chain3 + 1]
		"dragon-aura", "dragon-aura-minor":
			var layer := int(state.dragon_layer if state != null else c.get("_dragonLayer", 0))
			var count := _dragon_count(state)
			var gain := layer * count
			if effect_id == "dragon-aura-minor":
				gain = int(round(float(gain) * 0.75))
				return "当前龙威%d，场上龙%d；本次全体龙 +%d/+%d" % [layer, count, gain, gain]
			return "触发后龙威%d；当前场上龙%d，本次全体龙 +%d/+%d" % [layer + maxi(1, int(skill.get("times", 2))), count, gain, gain]
		"atk-react":
			var hits := int(c.get("_atkT", 0))
			return "本回合已触发%d次；下次 +%d/+%d" % [hits, maxi(1, add_a) + hits, maxi(1, add_h) + hits]
		"undead-rebirth":
			var turn := int(c.get("_t", 0))
			var growth := int(c.get("_gb", 0))
			return "当前回合计数%d；下次重生 +%d/+%d" % [
				turn, (add_a + growth) * (turn + 1), (add_h + growth) * (turn + 1)]
		"multihit":
			var hit := int(c.get("_hit", int(skill.get("times", 1))))
			var level := maxi(1, int(c.get("_t", int(skill.get("times", 1)))))
			return "当前攻击%d次；恶魔 +%d/+%d" % [hit, level, level]
		"heal-race", "race-heal":
			var heal := maxi(1, int(floor(float(c.get("a", 0)) * 0.5)))
			return "本次治疗约%d" % heal
		"coin-spell-boost":
			var tick := int(c.get("_coin_tick", 0))
			var gain := maxi(1, int(skill.get("times", 1)))
			return "当前累计%d；本次法术增幅 +%d" % [tick, tick + gain]
		"maxhp-buff":
			return "当前最大生命%d → %d" % [int(c.get("mh", c.get("h", 0))), int(c.get("mh", c.get("h", 0))) + add_h]
		"debt-payoff", "debt-interest", "debt-lord", "debt-totem", "inherit", "debt-boost", "death-race-buff":
			var debt := int(state.debt if state != null else c.get("_debt", 0))
			return "当前债务%d" % debt
	return runtime

func _dragon_count(state = null) -> int:
	var count := 0
	if state == null:
		return count
	for card in state.board:
		if card != null and String(card.get("race", "")) == "dragon":
			count += 1
	return count

func _keyword_icon(text: String, color: Color = C_NAME) -> Label:
	var icon := Label.new()
	icon.text = text
	icon.add_theme_font_size_override("font_size", 9)
	icon.add_theme_color_override("font_color", color)
	icon.custom_minimum_size = Vector2(0, 12)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return icon

func _card_glyph(kind: String) -> Control:
	var glyph := CardGlyph.new()
	glyph.kind = kind
	return glyph

func _race_icon(race: String) -> String:
	match race:
		"undead":
			return "💀"
		"elem":
			return "💧"
		"dragon":
			return "🐉"
		"demon":
			return "😈"
		"star":
			return "💫"
		"mech":
			return ""
		"vampire":
			return "🩸"
		"gambler":
			return "🎲"
		"evolve":
			return "🦋"
		"sacrifice":
			return ""
		_:
			return ""

func _part_label(part: String) -> String:
	match part:
		"core":
			return "首脑"
		"head":
			return "核心"
		"arm":
			return "武装"
		"leg":
			return "肢体"
		_:
			return ""

func _mech_badge_spec(c: Dictionary, state = null) -> Dictionary:
	if String(c.get("race", "")) != "mech":
		return {}
	if bool(c.get("material", false)):
		return {
			"text": "磁力+%d/+%d" % [int(c.get("magA", 0)), int(c.get("magH", 0))],
			"color": C_MUTED,
		}
	var support := String(c.get("support", ""))
	if support != "":
		var support_text := "支援"
		var support_color: Color = MechanicStyle.family_style("mech").get("color", C_BLUE)
		match support:
			"repair":
				support_text = "维修"
				support_color = Color("7fd8c8")
			"supply":
				support_text = "供给"
			"super":
				support_text = "超导"
				support_color = MechanicStyle.family_style("mech").get("accent", C_GOLD)
		return {"text": support_text, "color": support_color}
	var part := _part_label(String(c.get("part", "")))
	if part == "":
		return {"text": "机械", "color": C_MUTED}
	var level := int(state.mech_level) if state != null else int(ps.mech_level)
	var text := "%s Lv%d" % [part, level]
	var charge_max := int(c.get("chargeMax", 0))
	if charge_max > 0:
		text += " ⚡%d/%d" % [int(c.get("charge", c.get("_charge", 0))), charge_max]
	var repair := int(c.get("battleArmor", c.get("battle_armor", 0)))
	if state != null:
		repair = maxi(repair, int(state.mech_repair))
	if repair > 0:
		text += " 护甲%d" % repair
	return {"text": text, "color": _mech_badge_color(c)}

func _mech_badge_text(c: Dictionary, state = null) -> String:
	return String(_mech_badge_spec(c, state).get("text", ""))

func _card_tooltip(c: Dictionary, state = null, detailed: bool = false) -> String:
	if String(c.get("t", "")) == "s":
		var spell_lines: Array[String] = []
		spell_lines.append("【法术】%s" % String(c.get("n", "法术")))
		spell_lines.append(String(c.get("x", "法术效果")))
		if String(c.get("fx", "")) == "spell-boost":
			spell_lines.append("无需选择目标，点击后永久强化后续法术。")
		else:
			spell_lines.append("点击这张牌后再点一名我方随从施放。")
		if detailed:
			spell_lines.append("结算：法术效果按当前法术增幅与实际目标计算。")
		return "\n".join(PackedStringArray(spell_lines))

	var lines: Array[String] = []
	var star := int(c.get("s", c.get("star", 1)))
	lines.append("【%d★】%s" % [star, String(c.get("n", "?"))])
	lines.append("攻击 %d    生命 %d" % [int(c.get("a", 0)), int(c.get("h", 0))])
	if c.has("mh") and int(c.get("mh", 0)) > int(c.get("h", 0)):
		lines.append("当前生命：%d/%d" % [int(c.get("h", 0)), int(c.get("mh", 0))])
	var race := String(c.get("race", "neutral"))
	var race_text := "中立" if race == "neutral" or race == "" else GameData.race_name(race)
	var part := _part_label(String(c.get("part", "")))
	if part != "":
		race_text += " · " + part
	lines.append("种族：%s" % race_text)
	var keyword_names: Array[String] = []
	for ch in String(c.get("k", "")):
		var kw_name := String(GameData.keywords.get("names", {}).get(ch, ch))
		if kw_name != "":
			keyword_names.append(kw_name)
	if not keyword_names.is_empty():
		lines.append("关键词：" + "、".join(PackedStringArray(keyword_names)))
	var abilities := _card_ability_lines(c, state, detailed)
	if not abilities.is_empty():
		lines.append("【随从能力】")
		lines.append_array(abilities)
	var mechanisms := _mechanism_lines(c, state, detailed)
	if not mechanisms.is_empty():
		lines.append("【特殊机制】")
		lines.append_array(mechanisms)
	if detailed:
		lines.append("以上数值按实时状态结算；成长来源与触发次数已在每条能力中标注。")
	return "\n".join(PackedStringArray(lines))

func _card_ability_lines(c: Dictionary, state = null, detailed: bool = false) -> Array[String]:
	var lines: Array[String] = []
	if c.has("bc"):
		var bc: Dictionary = c["bc"]
		lines.append("战吼：" + (_skill_detail_text(bc, c, state, "上场时") if detailed else _effect_short_text(bc)))
	if c.has("sk"):
		var sk: Dictionary = c["sk"]
		lines.append("技能：" + (_skill_detail_text(sk, c, state) if detailed else _skill_short_text(sk)))
	if c.has("sc"):
		var sc: Dictionary = c["sc"]
		lines.append("法术联动：" + (_skill_detail_text(sc, c, state, "释放法术后") if detailed else _effect_short_text(sc)))
	if c.has("scSk"):
		var sc_sk: Dictionary = c["scSk"]
		lines.append("施法联动：" + (_skill_detail_text(sc_sk, c, state, "释放法术后") if detailed else _effect_short_text(sc_sk)))
	if c.has("atkSk"):
		var atk_sk: Dictionary = c["atkSk"]
		lines.append("攻击后：" + (_skill_detail_text(atk_sk, c, state, "攻击后") if detailed else _effect_short_text(atk_sk)))
	if int(c.get("chargeMax", 0)) > 0:
		lines.append("充能：%d 次，%s" % [int(c.get("chargeMax", 0)), _charge_text(c)])
	if bool(c.get("material", false)):
		lines.append(String(c.get("magDesc", "磁力材料：拖到我方机械随从上强化。")))
	var support := String(c.get("support", ""))
	if support != "":
		lines.append(_support_text(support))
	if bool(c.get("magnet", false)):
		lines.append("磁力：可与机械合体。")
	if c.has("modGrow") or c.has("modDmg") or c.has("modAtk") or c.has("modShield") or bool(c.get("headDouble", false)):
		lines.append("合体强化：" + _mod_text(c))
	if detailed:
		for index in range(lines.size()):
			var line := lines[index]
			if line.begins_with("战吼：") or line.begins_with("技能：") \
					or line.begins_with("施法联动：") or line.begins_with("攻击后："):
				lines[index] = line
	return lines

func _mechanism_lines(c: Dictionary, state = null, detailed: bool = false) -> Array[String]:
	var race := String(c.get("race", "neutral"))
	if race == "" or race == "neutral":
		return []
	var lines: Array[String] = []
	if detailed:
		lines.append_array(_dynamic_status_lines(c, state))
		var source_line := _mechanism_source_text(race, c)
		if source_line != "":
			lines.append(source_line)
	else:
		lines.append_array(_mechanism_summary_lines(c, state))
	return lines

func _mechanism_summary_lines(c: Dictionary, state = null) -> Array[String]:
	var lines: Array[String] = []
	var race := String(c.get("race", "neutral"))
	match race:
		"star":
			var chain := int(c.get("_chain", c.get("chain", state.chain if state != null else 0)))
			lines.append("星灵连锁：当前%d层。" % chain)
		"sacrifice":
			var debt := int(c.get("_debt", state.debt if state != null else 0))
			lines.append("献祭债务：当前%d点。" % debt)
		"evolve":
			var skill: Dictionary = c.get("sk", {})
			var effect := String(skill.get("e", ""))
			if effect == "evo-devourer":
				lines.append("基因层：%d/5。" % mini(5, int(c.get("_gene", c.get("gene", 0)))))
			elif effect == "progress":
				lines.append("孵化进度：%d/5。" % mini(5, int(c.get("_pr", 0))))
			else:
				var need := int(skill.get("need", c.get("need", 3)))
				var current := int(c.get("_evo", c.get("evo", 0)))
				lines.append("进化条：%d/%d。" % [current, need])
		"mech":
			var part := _part_label(String(c.get("part", "")))
			if part != "":
				lines.append("机械部位：%s。" % part)
			var charge_max := int(c.get("chargeMax", 0))
			if charge_max > 0:
				lines.append("充能：%d/%d。" % [int(c.get("charge", c.get("_charge", 0))), charge_max])
		"dragon":
			var layer := int(state.dragon_layer if state != null else c.get("_dragonLayer", 0))
			lines.append("龙威层：%d。" % layer)
		"undead":
			var deaths := int(state.undead_tick if state != null else c.get("_udBase", 0))
			lines.append("本局累计死亡：%d。" % deaths)
	return lines

func _mechanism_source_text(race: String, c: Dictionary) -> String:
	match race:
		"star":
			return "连锁公式：连锁攻击追加=当前连锁×1.5×星界增幅；来源=链启、星界增幅与施法联动。"
		"sacrifice":
			return "债务节点：8/18/32；来源=契印死亡、吞噬契印与债务牌；结算收益随祭祀身材和回合提高。"
		"evolve":
			var effect := String((c.get("sk", {}) as Dictionary).get("e", ""))
			if effect == "progress":
				return "孵化来源=战斗胜利与进化宣言；满5格后蜕变为混沌始祖。"
			return "外部推进来源=昼夜相位与进化宣言；质变按卡自身攻击或受击规则结算。"
		"mech":
			return "机械成长来源=磁力喂料、部位继承与支援；充能满后触发对应机械协议。"
		"dragon":
			return "龙威公式=龙威层×场上龙数；来源=龙威光环与任意龙攻击后的反应成长。"
		"undead":
			return "亡灵成长来源=本局死亡计数、亡语与复活；累计值跨战斗保留。"
	return ""

func _dynamic_status_lines(c: Dictionary, state = null) -> Array[String]:
	var lines: Array[String] = []
	var race := String(c.get("race", ""))
	var debt := int(c.get("_debt", state.debt if state != null else 0))
	var chain := int(c.get("_chain", c.get("chain", state.chain if state != null else 0)))
	if race == "star" and chain > 0:
		lines.append("星灵连锁：%d。连锁会强化星灵攻击与连锁效果。" % chain)
	if race == "sacrifice":
		var tier := _debt_tier(debt)
		var tier_name: String = ["未到节点", "小节点", "中节点", "大节点"][tier]
		var next_node: int = [8, 8, 18, 32][tier]
		lines.append("当前债务：%d（%s，下一节点 %d）" % [debt, tier_name, next_node])
		if state == ps and bool(c.get("_contract", false)):
			lines.append("契印：本局已指定一名献祭随从；其阵亡时额外增加债务。")
	if race == "evolve":
		var skill: Dictionary = c.get("sk", {})
		var effect := String(skill.get("e", ""))
		match effect:
			"evo-devourer":
				lines.append("基因：%d/5。吞噬会推进基因层数。" % mini(5, int(c.get("_gene", c.get("gene", 0)))))
			"progress":
				lines.append("孵化进度：%d/5。战斗胜利后继续成长。" % mini(5, int(c.get("_pr", 0))))
			_:
				var need := int(skill.get("need", c.get("need", 3)))
				var current := int(c.get("_evo", c.get("evo", 0)))
				var total := int(c.get("_ev", 0))
				var transformed := int(c.get("_vc", c.get("vc", 0))) \
					if String(skill.get("t", "")) == "on-dmg" else int(c.get("_vd", c.get("vd", 0)))
				var cap := int(skill.get("maxC", 0)) if String(skill.get("t", "")) == "on-dmg" else int(skill.get("maxD", 0))
				lines.append("已进化：%d 轮；当前进化条：%d/%d；已质变：%d%s。"
					% [total, current, need, transformed, "/%d" % cap if cap > 0 else ""])
	if race == "mech":
		if String(c.get("support", "")) != "":
			lines.append(_support_text(String(c.get("support", ""))))
		var part := _part_label(String(c.get("part", "")))
		if part != "":
			lines.append("机械部位：%s；出击等级 %d。" % [part, int(state.mech_level) if state != null else ps.mech_level])
		var charge_max := int(c.get("chargeMax", 0))
		if charge_max > 0:
			lines.append("充能：%d/%d。" % [int(c.get("charge", c.get("_charge", 0))), charge_max])
		var armor := int(c.get("battleArmor", c.get("battle_armor", 0)))
		if state != null:
			armor = maxi(armor, int(state.mech_repair))
		if armor > 0:
			lines.append("维修护甲：%d。战斗中优先吸收伤害。" % armor)
	if bool(c.get("_devourReady", false)):
		lines.append("待吞噬：拖到另一名我方随从上结算。")
	var follow := String(c.get("followType", c.get("follow_type", "")))
	if follow != "":
		lines.append("合体协同：%s。" % follow)
	return lines

func _debt_tier(value: int) -> int:
	if value >= 32:
		return 3
	if value >= 18:
		return 2
	if value >= 8:
		return 1
	return 0

func _debt_tier_color(tier: int) -> Color:
	var style := MechanicStyle.family_style("sacrifice")
	match tier:
		1:
			return Color(style.get("pale", Color("b8a7ff")))
		2:
			return Color(style.get("color", C_CONTRACT))
		3:
			return Color(style.get("accent", C_GOLD))
	return Color("8f86b8")

func _skill_text(skill: Dictionary) -> String:
	var trigger := String(skill.get("t", ""))
	var effect_id := String(skill.get("e", ""))
	var prefix := ""
	match trigger:
		"start":
			prefix = "回合开始" if effect_id == "contract-set" else "战斗开始"
		"attack":
			prefix = "攻击时"
		"on-dmg":
			prefix = "受到伤害后"
		"death":
			prefix = "死亡时"
		"battle":
			prefix = "战斗结算"
		"spell-cast":
			prefix = "施放法术后"
		"round":
			prefix = "回合结算"
		"aura", "passive", "lockhp":
			prefix = "被动"
	if skill.has("txt") and String(skill["txt"]) != "":
		return ("%s：" % prefix if prefix != "" else "") + String(skill["txt"])
	var detail := _effect_text(skill)
	return ("%s：" % prefix if prefix != "" else "") + detail

func _skill_short_text(skill: Dictionary) -> String:
	var trigger := _skill_trigger_text(skill)
	var body := _effect_short_text(skill)
	return ("%s：%s" % [trigger, body]) if trigger != "" else body

func _skill_detail_text(skill: Dictionary, c: Dictionary = {}, state = null, trigger_override: String = "") -> String:
	var trigger := trigger_override if trigger_override != "" else _skill_trigger_text(skill)
	var body := _effect_text(skill)
	var source := _skill_source_text(skill)
	var parts: Array[String] = []
	if trigger != "":
		parts.append("触发=" + trigger)
	parts.append("结算=" + body)
	if source != "":
		parts.append("来源=" + source)
	var runtime := _skill_runtime_text(skill, c, state)
	if runtime != "":
		parts.append("当前=" + runtime)
	return "；".join(PackedStringArray(parts))

func _skill_trigger_text(skill: Dictionary) -> String:
	var trigger := String(skill.get("t", ""))
	var effect_id := String(skill.get("e", ""))
	match trigger:
		"start":
			return "回合开始" if effect_id == "contract-set" else "战斗开始"
		"attack":
			return "攻击后"
		"on-dmg":
			return "受击时"
		"death":
			return "死亡时"
		"battle":
			return "战斗胜利结算"
		"spell-cast":
			return "释放法术后"
		"round":
			return "回合结算"
		"gold":
			return "花费金币后"
		"aura", "passive", "lockhp":
			return "被动"
	return ""

func _skill_source_text(skill: Dictionary) -> String:
	var effect_id := String(skill.get("e", ""))
	match effect_id:
		"evolve", "evolve-step", "evo-advance", "progress", "evo-devourer":
			return "自身进化条、昼夜相位与进化宣言"
		"debt-payoff", "debt-interest", "debt-lord", "debt-totem", "inherit", "debt-boost", "death-race-buff":
			return "献祭债务层、契印与节点结算"
		"chain-dmg", "chain-start", "star-amp", "star-echo":
			return "星灵连锁层与星界增幅"
		"dragon-aura", "dragon-aura-minor", "atk-react", "growth-self":
			return "龙威层、场上龙数与跨回合成长"
		"growth-boost", "spell-boost-grow", "spell-core", "spell-race-grow", "spell-boost", "self-growth-boost":
			return "法术强化层与施法次数"
		"mech-info", "mech-supply":
			return "磁力喂料、合体部位与机械支援"
		"race-buff", "rnd-race-buff", "all-buff", "ally-all-buff", "self-race-buff":
			return "同族场上数量与累计触发次数"
		"gamble":
			return "随机数、成功率与倍率池"
		"undead-rebirth", "summon":
			return "死亡事件与亡灵累计死亡计数"
		"maxhp-buff", "lockhp", "heal-race", "race-heal":
			return "战斗受击、治疗与最大生命变化"
	return "卡牌自身效果与实时战斗状态"

func _skill_runtime_text(skill: Dictionary, c: Dictionary, state = null) -> String:
	var effect_id := String(skill.get("e", ""))
	match effect_id:
		"evolve", "evolve-step", "evo-advance":
			var need := int(skill.get("need", 3))
			var current := int(c.get("_evo", c.get("evo", 0)))
			var total := int(c.get("_ev", 0))
			return "进化条%d/%d，已进化%d轮" % [current, need, total]
		"progress":
			return "孵化%d/5" % mini(5, int(c.get("_pr", 0)))
		"evo-devourer":
			return "基因%d/5" % mini(5, int(c.get("_gene", c.get("gene", 0))))
		"chain-dmg", "chain-start", "star-amp", "star-echo":
			return "连锁%d，星界增幅%d" % [
				int(c.get("_chain", state.chain if state != null else 0)),
				int(state.star_amp if state != null else c.get("_amp", 0))]
		"debt-payoff", "debt-interest", "debt-lord", "debt-totem", "inherit", "debt-boost", "death-race-buff":
			return "债务%d，契印%s" % [
				int(c.get("_debt", state.debt if state != null else 0)),
				"已立契" if bool(c.get("_contract", false)) else "未立契"]
		"dragon-aura", "dragon-aura-minor", "atk-react":
			return "龙威%d层" % int(state.dragon_layer if state != null else c.get("_dragonLayer", 0))
		"undead-rebirth", "summon", "rnd-race-buff":
			return "累计死亡%d次" % int(state.undead_tick if state != null else c.get("_udBase", 0))
		"mech-info", "mech-supply":
			return "机械出击Lv%d，维修护甲%d" % [
				int(state.mech_level if state != null else ps.mech_level),
				int(state.mech_repair if state != null else ps.mech_repair)]
		"spell-boost-grow", "spell-core", "spell-race-grow", "spell-boost", "self-growth-boost":
			var boost: Dictionary = state.spell_boost if state != null else ps.spell_boost
			return "法术增幅攻+%d，生命+%d" % [int(boost.get("a", 0)), int(boost.get("h", 0))]
	return ""

func _effect_short_text(effect: Dictionary) -> String:
	var effect_id := String(effect.get("e", ""))
	var add_a := int(effect.get("a", 0))
	var add_h := int(effect.get("h", 0))
	match effect_id:
		"ally-atk":
			return "使一名友方攻击+%d" % add_a
		"free-refresh":
			return "获得1次免费刷新"
		"self":
			return "自身+%d/+%d" % [add_a, add_h]
		"devour":
			return "吞噬一名友方并获得其数值"
		"devour-shop":
			return "吞噬1个商店随从并获得其数值"
		"ally-rnd":
			return "随机强化一名友方"
		"gold":
			return "获得%d金" % int(effect.get("g", effect.get("a", 1)))
		"dmg-rnd":
			return "对随机敌人造成%d点伤害" % int(effect.get("d", add_a))
		"contract-set":
			return "自动为最弱献祭随从立契"
		"spell-boost":
			return "永久提高后续法术效果"
		"summon":
			return "召唤%d个骷髅兵" % int(effect.get("count", 1))
		"debt-boost":
			return "提高契印结算债务"
		"spell-core":
			return "强化自身与元素随从"
		"spell-race-grow":
			return "施法强化全体元素"
		"race-buff":
			if String(effect.get("race", "")) == "star":
				return "获得连锁并强化星灵"
			if String(effect.get("race", "")) == "undead" and String(effect.get("t", "")) == "death":
				return "强化亡灵，并随亡灵死亡次数增长"
			return "强化全体%s" % GameData.race_name(String(effect.get("race", "")))
		"self-buff":
			if bool(effect.get("grow", false)):
				return "强化自身，并随受击次数递增"
			return "强化自身"
		"self-race-buff":
			return "攻击后强化自身与%s" % GameData.race_name(String(effect.get("race", "")))
		"ally-all-buff":
			return "强化全体友方并逐次递增"
		"growth-self":
			return "每回合成长并递增"
		"growth-boost":
			return "提高成长类效果"
		"spell-boost-grow":
			return "每回合提高法术强化"
		"dragon-aura":
			return "获得龙威并强化全体龙"
		"dragon-aura-minor":
			return "按龙威层额外强化全体龙"
		"atk-react":
			return "任意龙攻击后强化自身"
		"star-echo":
			return "星灵攻击后追加星光伤害"
		"chain-dmg":
			return "攻击时追加连锁伤害"
		"chain-start":
			return "获得1层连锁"
		"undead-rebirth":
			return "开局死亡后复活并强化亡灵"
		"maxhp-buff":
			return "受击后强化自身并提高最大生命"
		"gamble":
			return "掷骰成功时按倍率强化目标"
		"evolve-step", "evolve", "evo-advance":
			if effect_id == "evo-advance":
				return "推进全体进化并强化"
			if String(effect.get("t", "")) == "on-dmg":
				return "受击推进进化，质变时提高攻击"
			return "攻击推进进化并成长"
		"progress":
			return "推进孵化，胜利后继续成长"
		"evo-devourer":
			return "吞噬基因并强化全体进化"
		"debt-payoff":
			return "结算1个债务节点并强化全体献祭"
		"debt-interest":
			return "提高债务并成长自身"
		"debt-lord":
			return "按债务节点强化全体献祭"
		"death-race-buff":
			return "按上回合死亡数强化献祭"
		"debt-totem":
			return "提高契印债务与节点返还"
		"multihit":
			return "攻击多次并强化全体恶魔"
		"lockhp":
			return "低血量时减少受到的伤害"
		"mech-info", "mech-supply":
			var text := String(effect.get("txt", ""))
			return text if text != "" else "执行机械协议"
		"inherit":
			return "继承死亡友方的数值"
		"dmg-allies":
			return "对己方其他随从造成伤害"
		"coin-spell-boost":
			return "花费金币后强化后续法术"
		"heal-race":
			return "攻击后治疗全体血族并强化"
		"race-heal":
			return "攻击时治疗全体血族"
		"rnd-race-buff":
			return "随机强化亡灵并随死亡次数增长"
		"shop-buff":
			return "强化商店随从"
		"self-growth-boost":
			return "提高自身成长效果"
		"all-buff":
			return "友方死亡时强化全体"
		"star-amp":
			return "获得连锁并强化连锁伤害"
		"skeleton-army":
			return "亡灵友方死亡时强化自身"
		"debt-battery":
			return "结算债务后转化为自身永久属性"
		"double-rnd", "double-all":
			return "使友方数值翻倍"
	return "按卡牌实时效果结算"

func _effect_text(effect: Dictionary) -> String:
	var effect_id := String(effect.get("e", ""))
	var add_a := int(effect.get("a", 0))
	var add_h := int(effect.get("h", 0))
	match effect_id:
		"ally-atk":
			return "使一名友方攻击+%d" % add_a
		"free-refresh":
			return "获得 1 次免费刷新"
		"self":
			return "自身 +%d/+%d" % [add_a, add_h]
		"devour":
			return "选择一个友方吞噬，获得其当前攻击与生命；若吞噬契印目标，债务额外+17%"
		"devour-shop":
			return "回合开始吞噬1个商店随从，获得其数值×%d" % maxi(1, int(effect.get("times", 1)))
		"ally-rnd":
			return "随机友方 +%d/+%d" % [add_a, add_h]
		"gold":
			return "获得 %d 金" % int(effect.get("g", effect.get("a", 1)))
		"dmg-rnd":
			return "对随机敌人造成 %d 点伤害" % int(effect.get("d", add_a))
		"contract-set":
			return "自动选择除自己外最弱的献祭随从立契；该目标死亡或备战时被吞噬时，债务额外+%d" % int(effect.get("debtBonus", 3))
		"spell-boost":
			return "本局后续法术效果永久 +%d/+%d" % [add_a, add_h]
		"summon":
			return "召唤 %d 个亡魂" % int(effect.get("count", 1))
		"debt-boost":
			return "契印目标死亡或备战时被吞噬时，本次债务额外+%d" % add_a
		"spell-core":
			return "施法后自身 +%d/+%d，并随施法次数递增；同时使%s随从 +%d/+%d" % [
				add_a, add_h, GameData.race_name(String(effect.get("race", "elem"))),
				int(effect.get("raceA", add_a)), int(effect.get("raceH", add_h))]
		"spell-race-grow":
			return "施法后使%s随从 +%d/+%d；本回合每次施法额外+1/+1，最多%d次" % [
				GameData.race_name(String(effect.get("race", "elem"))), add_a, add_h,
				int(effect.get("max", 3))]
		"race-buff":
			var race_buff := String(effect.get("race", ""))
			if race_buff == "star":
				return "施法后连锁+1，%s星灵获得当前连锁层数的身材" % (
					"随机一名" if String(effect.get("scope", "")) == "rnd" else "全体")
			if race_buff == "undead" and String(effect.get("t", "")) == "death":
				return "友方死亡时，%s +%d/+%d；随本局亡灵死亡次数递增" % [
					GameData.race_name(race_buff), add_a, add_h]
			return "使%s随从 +%d/+%d" % [GameData.race_name(race_buff), add_a, add_h]
		"self-buff":
			if String(effect.get("t", "")) == "on-dmg":
				if bool(effect.get("grow", false)):
					return "受到伤害后自身 +%d/+%d，并随本场受击次数递增" % [maxi(1, add_a), maxi(1, add_h)]
				return "受到伤害后自身 +%d/+%d" % [add_a, add_h]
			return "自身 +%d/+%d；成长效果每回合提高" % [add_a, add_h]
		"self-race-buff":
			return "攻击后自身与%s随从 +%d/+%d" % [
				GameData.race_name(String(effect.get("race", ""))), add_a, add_h]
		"ally-all-buff":
			return "全体友方 +%d/+%d；每次触发后本局效果提高" % [maxi(1, add_a), maxi(1, add_h)]
		"growth-self":
			return "回合开始自身成长；本局每触发一次，成长值再+%d" % maxi(1, int(effect.get("times", 1)))
		"growth-boost":
			return "本局所有成长类效果额外+%d" % maxi(1, int(effect.get("times", 1)))
		"spell-boost-grow":
			return "回合开始法术强化 +%d/+%d，且每回合递增" % [add_a, add_h]
		"dragon-aura":
			return "回合开始龙威层+%d；随后每层龙威×场上龙数，为全体龙增加等量攻击与生命" % maxi(1, int(effect.get("times", 1)))
		"dragon-aura-minor":
			return "回合开始额外按龙威层×场上龙数的 3/4 强化全体龙"
		"atk-react":
			return "任意龙攻击后，自身 +%d/+%d；本回合每次提高1点，最多4次" % [maxi(1, add_a), maxi(1, add_h)]
		"star-echo":
			return "星灵攻击后，对随机敌人造成星光回响伤害"
		"chain-dmg":
			return "攻击时按连锁层数追加伤害：连锁×1.5×星界增幅"
		"chain-start":
			return "回合开始连锁+1"
		"undead-rebirth":
			return "开局死亡时复活，自身 +%d/+%d 并逐回合递增；同时强化全亡灵" % [add_a, add_h]
		"maxhp-buff":
			return "受到伤害后自身 +%d/+%d，并永久提高最大生命" % [add_a, add_h]
		"gamble":
			return "%d%% 成功：随机/本族目标获得 +%d/+%d，再乘以 %d-%d 倍" % [
				int(round(float(effect.get("succ", 0.65)) * 100.0)), add_a, add_h,
				int(effect.get("ml", effect.get("times", 1))),
				int(effect.get("mh", int(effect.get("ml", effect.get("times", 1))) + 1))]
		"evolve-step", "evolve", "evo-advance":
			if effect_id == "evo-advance":
				return "回合开始使全体进化随从 +1 格，并获得 +%d/+%d，触发次数越多收益越高" % [maxi(1, add_a), maxi(1, add_h)]
			var need := int(effect.get("need", 2 if effect.has("maxD") else 3))
			if String(effect.get("t", "")) == "on-dmg":
				return "每2次受击+1攻击，并每次推进1格；满%d格攻击×1.5" % need
			return "每2次触发+1/+1，并每次推进1格；满%d格质变，之后继续成长" % need
		"progress":
			return "回合开始进度+1，战斗胜利再+1；满5格蜕变为混沌始祖"
		"evo-devourer":
			return "每回合吞噬1层基因，永久+2/+2（最多5层）；己方进化随从质变时，自身+2/+2并强化全体进化"
		"debt-payoff":
			return "回合开始结算1个债务节点：8点全献祭+1/+1、18点+2/+3、32点+3/+8（不足8点按剩余债务）；每场最多结算1个节点，多个结算随从合并为+20%增幅；收益随祭祀自身攻击/生命提高，前中期按回合递减，11回合起全额"
		"debt-interest":
			return "回合开始债务+%d并逐回合递增%d；自身同时永久+%d/+%d" % [
				int(effect.get("count", 1)), int(effect.get("grow", 0)),
				int(effect.get("selfGrow", 0)), int(effect.get("selfGrow", 0))]
		"debt-lord":
			return "回合开始按债务节点强化献祭：小节点约+%d，中节点约+%d，大节点约+%d" % [
				maxi(1, int(round(float(add_a) / 3.0))), add_a, add_a * 2]
		"death-race-buff":
			return "回合开始按上回合友方死亡数强化%s；并有几率结算1个债务节点" % (
				GameData.race_name(String(effect.get("race", "sacrifice"))))
		"debt-totem":
			return "被动：契印债务按普通1.17倍/金卡1.5倍结算；节点结算时全体献祭再获得本次消耗债务的普通11%/金卡22%"
		"multihit":
			return "每回合攻击%d次，每次为全体恶魔 +当前次数/+当前次数" % maxi(1, int(effect.get("times", 1)))
		"lockhp":
			return "生命低于50%时受到的伤害降低33%；治疗时永久提高最大生命"
		"mech-info", "mech-supply":
			if String(effect.get("txt", "")) != "":
				return String(effect["txt"])
			return "回合开始获得%d张随机机械材料牌" % int(effect.get("count", 1))
		"inherit":
			return "友方死亡时继承其 4.45%% 攻击与生命，至少+1/+1；债务结算后再吞噬消耗债务的5.5%%"
		"dmg-allies":
			return "回合开始对除自己外的友方造成%d点伤害，重复%d次" % [
				int(effect.get("d", 1)), int(effect.get("times", 1))]
		"coin-spell-boost":
			return "每花5金，下一次法术效果按攻/血交替 +%d" % maxi(1, int(effect.get("times", 1)))
		"heal-race":
			return "攻击后治疗全体%s，并使其 +%d/+%d" % [
				GameData.race_name(String(effect.get("race", "vampire"))), maxi(1, add_a), maxi(1, add_h)]
		"race-heal":
			return "攻击时治疗全体%s，治疗量为攻击力的一半" % GameData.race_name(String(effect.get("race", "vampire")))
		"rnd-race-buff":
			return "友方死亡时随机强化一名%s，并随亡灵死亡次数递增" % GameData.race_name(String(effect.get("race", "undead")))
		"shop-buff":
			return "回合开始使符合种族的商店随从 +%d/+%d" % [add_a, add_h]
		"self-growth-boost":
			return "每次触发法术后，本局成长效果额外+%d" % maxi(1, int(effect.get("times", 1)))
		"all-buff":
			return "友方死亡时，全体友方 +%d/+%d" % [maxi(1, add_a), maxi(1, add_h)]
		"star-amp":
			return "回合开始连锁+1，并使星灵连锁伤害翻倍"
		"skeleton-army":
			return "亡灵友方死亡时，自身 +1/+1"
		"debt-battery":
			return "节点结算后，吞噬本次消耗债务的 25%（金卡 50%）转化为自身永久属性"
		"double-rnd":
			return "随机友方数值翻倍"
		"double-all":
			return "全体友方按掷骰倍率翻倍"
		_:
			return "该效果按卡牌实时状态结算（%s）" % effect_id if effect_id != "" else "该效果按卡牌实时状态结算"

func _charge_text(c: Dictionary) -> String:
	match String(c.get("chargeFx", "")):
		"shield":
			return "满能后获得圣盾"
		"heal":
			return "满能后恢复生命"
		"rally":
			return "满能后为机械协同 +%d/+%d" % [int(c.get("chargeA", 1)), int(c.get("chargeH", 1))]
		"buff":
			return "满能后为全队 +%d/+%d" % [int(c.get("chargeA", 2)), int(c.get("chargeH", 2))]
		_:
			return "满能后触发机械协议"

func _support_text(kind: String) -> String:
	match kind:
		"repair":
			return "维修支援：磁力喂料的一部分生命会转为合体维修护甲。"
		"supply":
			return "供给支援：每回合提供磁力材料或强化资源。"
		"super":
			return "超导支援：强化磁力喂料收益，并可能扩散到相邻部件。"
		_:
			return "机械支援：为合体体系提供额外收益。"

func _mod_text(c: Dictionary) -> String:
	var parts: Array[String] = []
	if int(c.get("modGrow", 0)) != 0:
		parts.append("成长 +%d" % int(c.get("modGrow", 0)))
	if int(c.get("modAtk", 0)) != 0:
		parts.append("喂料攻击 +%d" % int(c.get("modAtk", 0)))
	if int(c.get("modDmg", 0)) != 0:
		parts.append("受击反伤 +%d" % int(c.get("modDmg", 0)))
	if int(c.get("modShield", 0)) != 0:
		parts.append("提供圣盾")
	if bool(c.get("headDouble", false)):
		parts.append("头部收益翻倍")
	return "、".join(PackedStringArray(parts))

func _mech_badge_color(c: Dictionary) -> Color:
	if bool(c.get("material", false)):
		return C_MUTED
	if String(c.get("support", "")) != "":
		return C_BLUE
	match String(c.get("part", "")):
		"core":
			return C_GOLD
		"head":
			return C_BTN_FREEZE
		"arm":
			return C_BTN_FIGHT
		"leg":
			return Color("00b894")
		_:
			return C_MUTED

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
	root.offset_top = 4
	root.offset_bottom = -4
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	get_viewport().size_changed.connect(func():
		root.offset_left = _side_margin()
		root.offset_right = -_side_margin()
		root.offset_top = 4
		root.offset_bottom = -4)

	var bar := _build_bar()
	bar.name = "bar"
	root.add_child(_vspace_block(bar, 0, 2))
	_rope = RopeBar.new()
	_rope.name = "rope"
	_rope.add_theme_font_override("font", UiTheme.cjk_font())
	root.add_child(_vspace_block(_rope, 2, 2))
	# 对应原版 #brd{flex:1}：两块战场占据剩余高度
	var brd := VBoxContainer.new()
	brd.name = "brd"
	brd.add_theme_constant_override("separation", 2)
	brd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brd.add_child(_build_side("AI", true)); brd.get_child(brd.get_child_count() - 1).name = "side_ai"
	brd.add_child(_build_side("我", false)); brd.get_child(brd.get_child_count() - 1).name = "side_p"
	root.add_child(brd)
	var hand := _build_hand()
	hand.name = "hand"
	root.add_child(_vspace_block(hand, 2, 0))
	var shop := _build_shop()
	shop.name = "shop"
	root.add_child(_vspace_block(shop, 2, 0))
	var act := _build_actions()
	act.name = "act"
	root.add_child(act)
	_choice_host = _build_selection_bar()
	_choice_host.z_index = 85
	add_child(_choice_host)
	var logpanel := _build_log()
	logpanel.name = "logpanel"
	root.add_child(_vspace_block(logpanel, 2, 0))
	_build_card_tooltip()
	_spell_arrow = SpellTargetArrow.new()
	_spell_arrow.name = "spell_target_arrow"
	_spell_arrow.z_index = 84
	add_child(_spell_arrow)

func _build_card_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.z_index = 120
	_tooltip_panel.custom_minimum_size = Vector2(310, 0)
	_tooltip_panel.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.06, 0.1, 0.97), C_GOLD, 8, 5))
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.scroll_active = false
	_tooltip_label.add_theme_font_size_override("normal_font_size", 11)
	_tooltip_label.add_theme_color_override("default_color", C_NAME)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(294, 0)
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(_tooltip_label)
	add_child(_tooltip_panel)
	_tooltip_num_regex = RegEx.new()
	_tooltip_num_regex.compile("([+-]?[0-9]+(?:\\.[0-9]+)?(?:/[0-9]+)?)")

func _attach_card_tooltip(control: Control, c: Dictionary, state = null) -> void:
	if control == null:
		return
	control.set_meta("card_detail_tooltip", true)
	control.set_meta("card_detail", c.duplicate(true))
	control.set_meta("card_tooltip_card", c)
	control.set_meta("card_tooltip_state", state)
	if not control.has_meta("card_tooltip_mode"):
		control.set_meta("card_tooltip_mode", "card")
	var summary_override := String(control.get_meta("card_tooltip_summary", ""))
	var detail_override := String(control.get_meta("card_tooltip_detail", ""))
	control.set_meta("card_tooltip_text",
		summary_override if summary_override != "" else _card_tooltip(c, state, false))
	control.set_meta("card_detail_text",
		detail_override if detail_override != "" else _card_tooltip(c, state, true))
	# Card details render in the custom panel. Leaving tooltip_text populated
	# makes Godot draw a second native tooltip underneath it.
	control.tooltip_text = ""
	if not control.mouse_entered.is_connected(_on_card_hover_enter.bind(control, c)):
		control.mouse_entered.connect(_on_card_hover_enter.bind(control, c))
	if not control.mouse_exited.is_connected(_on_card_hover_exit.bind(control)):
		control.mouse_exited.connect(_on_card_hover_exit.bind(control))

func _on_card_hover_enter(control: Control, c: Dictionary) -> void:
	_show_card_tooltip(control, c)

func _on_card_hover_exit(control: Control) -> void:
	if _tooltip_source == control:
		_clear_card_tooltip()

func _show_card_tooltip(source: Control, c: Dictionary) -> void:
	if not is_instance_valid(_tooltip_panel) or not is_instance_valid(_tooltip_label):
		return
	if not is_instance_valid(source) or not source.is_inside_tree() or c.is_empty():
		return
	_tooltip_source = source
	var live_card: Dictionary = _tooltip_live_card(source, c)
	_tooltip_label.text = _card_hover_text_for_source(source, live_card)
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	_position_card_tooltip()

func _card_hover_text_for_source(source: Control, c: Dictionary, fallback_state = null) -> String:
	var state = source.get_meta("card_tooltip_state", fallback_state)
	c = _tooltip_live_card(source, c)
	var mode := String(source.get_meta("card_tooltip_mode", "card"))
	match mode:
		"ability":
			return _style_hover_text(_ability_hover_text(c, state), mode)
		"mechanism":
			return _style_hover_text(_mechanism_hover_text(c, state, String(source.get_meta("mechanism_kind", ""))), mode)
	var summary_text := String(source.get_meta("card_tooltip_text", ""))
	var plain := summary_text if summary_text != "" else _card_tooltip(c, state, false)
	return _style_hover_text(plain, mode)

func _style_hover_text(text: String, _mode: String = "") -> String:
	if text == "":
		return ""
	var lines := text.split("\n")
	var out: Array[String] = []
	for i in range(lines.size()):
		var line := String(lines[i])
		if line.strip_edges() == "":
			continue
		line = _highlight_hover_numbers(line)
		if i == 0:
			var sep := line.find("：")
			if sep > 0:
				var head := line.substr(0, sep + 1)
				var tail := line.substr(sep + 1)
				var core_end := _hover_core_end(tail)
				var core := tail if core_end < 0 else tail.substr(0, core_end)
				var rest := "" if core_end < 0 else tail.substr(core_end)
				line = head + "[color=#fdcb6e][b]" + core + "[/b][/color]" + rest
			else:
				line = "[color=#fdcb6e][b]%s[/b][/color]" % line
		out.append(line)
	return "\n".join(PackedStringArray(out))

func _hover_core_end(text: String) -> int:
	var best := -1
	for punctuation in ["，", "；", "。", ";"]:
		var index := text.find(punctuation)
		if index >= 0 and (best < 0 or index < best):
			best = index
	return best

func _highlight_hover_numbers(line: String) -> String:
	if _tooltip_num_regex == null:
		return line
	return _tooltip_num_regex.sub(line, "[color=#74b9ff][b]$1[/b][/color]", true)

func _tooltip_live_card(source: Control, fallback: Dictionary) -> Dictionary:
	var state = source.get_meta("card_tooltip_state", null)
	var slot := int(source.get_meta("card_tooltip_slot", -1))
	if state != null and slot >= 0 and slot < state.board.size() and state.board[slot] != null:
		return state.board[slot]
	return source.get_meta("card_tooltip_card", fallback)

func _position_card_tooltip() -> void:
	if not is_instance_valid(_tooltip_panel):
		return
	if _tooltip_source == null or not is_instance_valid(_tooltip_source) or not _tooltip_source.is_inside_tree():
		_clear_card_tooltip()
		return
	if not _tooltip_panel.visible:
		return
	var viewport_size := get_viewport_rect().size
	var target_size := _tooltip_panel.get_combined_minimum_size()
	var anchor := _tooltip_source.get_global_rect()
	var pos := anchor.position + Vector2(anchor.size.x + 8.0, -4.0)
	if pos.x + target_size.x > viewport_size.x - 8.0:
		pos.x = anchor.position.x - target_size.x - 8.0
	if pos.y + target_size.y > viewport_size.y - 8.0:
		pos.y = viewport_size.y - target_size.y - 8.0
	_tooltip_panel.position = Vector2(maxf(8.0, pos.x), maxf(8.0, pos.y))

func _update_card_tooltip() -> void:
	if not is_instance_valid(_tooltip_panel) or not is_instance_valid(_tooltip_label):
		return
	if _tooltip_source != null and not is_instance_valid(_tooltip_source):
		_clear_card_tooltip()
	var hovered := get_viewport().gui_get_hovered_control()
	var source: Control = _find_card_detail_source(hovered)
	if source == null:
		_clear_card_tooltip()
		return
	if not source.is_inside_tree():
		_clear_card_tooltip()
		return
	var detail: Dictionary = _tooltip_live_card(source, source.get_meta("card_tooltip_card", source.get_meta("card_detail", {})))
	if detail.is_empty():
		_clear_card_tooltip()
		return
	if _tooltip_source != source:
		_show_card_tooltip(source, detail)
	else:
		var dynamic_text := _card_hover_text_for_source(source, detail)
		if dynamic_text != _tooltip_label.text:
			_tooltip_label.text = dynamic_text
			_tooltip_panel.reset_size()
		_position_card_tooltip()

func _find_card_detail_source(control: Control) -> Control:
	var node: Node = control
	while node != null:
		if not is_instance_valid(node):
			return null
		if node is Control and node.is_inside_tree() and node.has_meta("card_detail"):
			return node as Control
		node = node.get_parent()
	return null

func _clear_card_tooltip() -> void:
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.visible = false
	if is_instance_valid(_tooltip_label):
		_tooltip_label.text = ""
	_tooltip_source = null

func _vspace_block(child: Control, top: int, bottom: int) -> MarginContainer:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", top)
	wrap.add_theme_constant_override("margin_bottom", bottom)
	wrap.add_child(child)
	return wrap

func _side_margin() -> float:
	return maxf(4.0, (get_viewport_rect().size.x - APP_W) * 0.5)

func _build_bar() -> PanelContainer:
	var bar := _panel(C_PANEL, 4)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	bar.add_child(hb)
	_hp = Label.new()
	_hp.add_theme_font_size_override("font_size", 12)
	_hp.add_theme_font_override("font", UiTheme.cjk_font_bold())
	_hp.add_theme_color_override("font_color", C_ATK)
	hb.add_child(_hp)
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", 12)
	_gold.add_theme_font_override("font", UiTheme.cjk_font_bold())
	_gold.add_theme_color_override("font_color", C_GOLD)
	hb.add_child(_gold)
	_hint = _muted("")
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", C_BLUE)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_hint)
	_round_label = _muted("⏱1")
	_round_label.add_theme_font_size_override("font_size", 12)
	hb.add_child(_round_label)
	_level_label = _muted("酒馆Lv1")
	_level_label.add_theme_font_size_override("font_size", 12)
	_level_label.add_theme_color_override("font_color", C_SUBTLE)
	hb.add_child(_level_label)
	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 11)
	_phase_label.add_theme_color_override("font_color", C_GOLD)
	_phase_label.add_theme_stylebox_override("normal", _sb(C_PANEL, C_GOLD, 2, 4))
	_phase_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_phase_label.visible = false
	hb.add_child(_phase_label)
	_quest_label = Button.new()
	_quest_label.name = "quest_button"
	_quest_label.focus_mode = Control.FOCUS_NONE
	_quest_label.add_theme_font_size_override("font_size", 11)
	_quest_label.add_theme_color_override("font_color", Color("7bed9f"))
	_quest_label.add_theme_stylebox_override("normal", _sb(C_PANEL, Color("7bed9f"), 2, 4))
	_quest_label.add_theme_stylebox_override("hover",
		_sb(C_SLOT_FILL, C_GOLD, 2, 4))
	_quest_label.add_theme_stylebox_override("pressed",
		_sb(C_SLOT_FILL.darkened(0.08), Color("7bed9f"), 2, 4))
	_quest_label.custom_minimum_size = Vector2(0, 21)
	_quest_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_quest_label.visible = false
	_quest_label.pressed.connect(_open_quest)
	hb.add_child(_quest_label)
	_mech_stat = Label.new()
	_mech_stat.add_theme_font_size_override("font_size", 11)
	_mech_stat.add_theme_color_override("font_color", C_BLUE)
	_mech_stat.add_theme_stylebox_override("normal", _sb(C_PANEL, C_BLUE, 2, 4))
	_mech_stat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mech_stat.visible = false
	hb.add_child(_mech_stat)
	_sigil_slot = SigilSlot.new()
	_sigil_slot.host = self
	_sigil_slot.visible = false
	_sigil_slot.custom_minimum_size = Vector2(0, 21)
	_sigil_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sigil_label := Label.new()
	sigil_label.name = "sigil_label"
	sigil_label.add_theme_font_size_override("font_size", 11)
	sigil_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sigil_slot.add_child(sigil_label)
	hb.add_child(_sigil_slot)
	var restart_btn := _btn("重开", C_SLOT_FILL, _restart_game)
	restart_btn.name = "restart_button"
	restart_btn.tooltip_text = "重新开始游戏"
	restart_btn.add_theme_font_size_override("font_size", 11)
	restart_btn.add_theme_stylebox_override("normal", _sb(C_SLOT_FILL, C_LINE_FILL, 2))
	restart_btn.add_theme_stylebox_override("hover", _sb(C_SLOT_FILL.lightened(0.08), C_GOLD, 2))
	restart_btn.add_theme_stylebox_override("pressed", _sb(C_SLOT_FILL.darkened(0.1), C_LINE_FILL, 2))
	restart_btn.add_theme_color_override("font_color", C_NAME)
	restart_btn.custom_minimum_size = Vector2(0, 21)
	hb.add_child(restart_btn)
	var set_btn := _btn("⚙设置", C_SLOT_FILL, _open_settings)
	set_btn.add_theme_font_size_override("font_size", 11)
	set_btn.add_theme_font_override("font", UiTheme.symbol_font())
	set_btn.add_theme_stylebox_override("normal", _sb(C_SLOT_FILL, C_LINE_FILL, 2))
	set_btn.add_theme_stylebox_override("hover", _sb(C_SLOT_FILL.lightened(0.08), C_GOLD, 2))
	set_btn.add_theme_stylebox_override("pressed", _sb(C_SLOT_FILL.darkened(0.1), C_LINE_FILL, 2))
	set_btn.add_theme_color_override("font_color", C_NAME)
	set_btn.custom_minimum_size = Vector2(0, 21)
	hb.add_child(set_btn)
	return bar

func _restart_game() -> void:
	if _music_player != null:
		_music_player.stop()
	get_tree().reload_current_scene()

func _open_settings() -> void:
	if find_child("settings_overlay", true, false) != null:
		return
	var overlay := Control.new()
	overlay.name = "settings_overlay"
	overlay.z_index = 130
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", _sb(Color("16213e"), Color("4a4d6b"), 18, 8))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_font_override("font", UiTheme.cjk_font_bold())
	title.add_theme_color_override("font_color", C_GOLD)
	box.add_child(title)
	box.add_child(_settings_slider("音乐音量", int(_music_volume), "Music"))
	box.add_child(_settings_slider("音效音量", int(_sfx_volume), "SFX"))

	var close := _btn("关闭", C_GOLD, overlay.queue_free)
	close.custom_minimum_size = Vector2(100, 34)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_color_override("font_color", C_BG)
	close.add_theme_font_size_override("font_size", 14)
	close.add_theme_stylebox_override("normal", _sb(C_GOLD, C_GOLD, 8, 6))
	close.add_theme_stylebox_override("hover", _sb(C_GOLD.lightened(0.1), C_GOLD, 8, 6))
	close.add_theme_stylebox_override("pressed", _sb(C_GOLD.darkened(0.12), C_GOLD, 8, 6))
	box.add_child(close)

func _settings_slider(label_text: String, default_value: int, bus_name: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 13)
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = default_value
	slider.custom_minimum_size = Vector2(260, 20)
	slider.value_changed.connect(_set_bus_volume.bind(bus_name))
	box.add_child(slider)
	_set_bus_volume(float(default_value), bus_name)
	return box

func _setup_audio() -> void:
	_ensure_audio_bus("Music", _music_volume)
	_ensure_audio_bus("SFX", _sfx_volume)
	var bgm_stream: AudioStream = load("res://assets/audio/bgm.wav")
	_hit_stream = load("res://assets/audio/hit.mp3")
	if bgm_stream != null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MusicPlayer"
		_music_player.bus = "Music"
		_music_player.stream = bgm_stream
		_music_player.finished.connect(_restart_music)
		add_child(_music_player)
		_music_player.play()
	if _hit_stream != null:
		for i in range(8):
			var player := AudioStreamPlayer.new()
			player.name = "SfxPlayer%d" % i
			player.bus = "SFX"
			player.max_polyphony = 1
			add_child(player)
			_sfx_players.append(player)

func _ensure_audio_bus(bus_name: String, volume: float) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_volume_db(index, -80.0 if volume <= 0.0 else linear_to_db(volume / 100.0))
	return index

func _restart_music() -> void:
	if not _game_over and _music_player != null:
		_music_player.play()

func _play_sfx(kind: String) -> void:
	_sfx_trace.append(kind)
	if _hit_stream == null or _sfx_players.is_empty():
		return
	var pitch := 1.0
	var volume_db := 0.0
	match kind:
		"evo_tick":
			pitch = 1.35
			volume_db = -7.0
		"evo_full":
			pitch = 1.60
			volume_db = -3.0
		"evolve":
			pitch = 1.72
			volume_db = -2.0
		"gene":
			pitch = 0.55
			volume_db = -4.0
		"progress":
			pitch = 1.25
			volume_db = -5.0
		"progress_full":
			pitch = 1.45
			volume_db = -3.0
		"progress_hatch":
			pitch = 0.50
			volume_db = -1.0
		"mech_charge":
			pitch = 1.28
			volume_db = -7.0
		"mech_follow":
			pitch = 0.92
			volume_db = -5.0
		"mech_guard":
			pitch = 0.70
			volume_db = -4.0
		"mech_armor":
			pitch = 0.58
			volume_db = -6.0
		"magnet":
			pitch = 0.52
			volume_db = -3.0
		"mech_fuse":
			pitch = 0.42
			volume_db = -1.0
		"dragon_aura":
			pitch = 1.42
			volume_db = -6.0
		"dragon_attack":
			pitch = 1.18
			volume_db = -6.0
		"dragon_react":
			pitch = 1.55
			volume_db = -4.0
		"dragon_growth":
			pitch = 0.88
			volume_db = -5.0
		"star_chain_bonus":
			pitch = 1.75
			volume_db = -3.0
		"star_chain":
			pitch = 1.45
			volume_db = -5.0
		"star_amp":
			pitch = 0.60
			volume_db = -2.0
		"star_echo":
			pitch = 1.90
			volume_db = -4.0
		"summon":
			pitch = 0.78
			volume_db = -4.0
		"rebirth":
			pitch = 1.62
			volume_db = -2.0
		"undead_death":
			pitch = 0.48
			volume_db = -3.0
		"element_cast":
			pitch = 1.38
			volume_db = -5.0
		"vampire_heal":
			pitch = 1.05
			volume_db = -3.0
		"gamble":
			pitch = 1.68
			volume_db = -2.0
		"demon_rage":
			pitch = 0.56
			volume_db = -3.0
		"neutral_buff":
			pitch = 1.22
			volume_db = -6.0
		"devour":
			pitch = 0.62
			volume_db = -1.0
		"contract":
			pitch = 0.82
			volume_db = -3.0
		"debt":
			pitch = 0.76
			volume_db = -4.0
		"debt_settle":
			pitch = 0.66
			volume_db = -2.0
		"hit":
			pitch = 1.0
		"death":
			pitch = 0.72
			volume_db = -2.0
		"buy":
			pitch = 1.18
			volume_db = -5.0
		"place":
			pitch = 1.08
			volume_db = -6.0
		"reroll":
			pitch = 0.88
			volume_db = -7.0
		"level":
			pitch = 1.32
			volume_db = -4.0
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stop()
	player.stream = _hit_stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()

func _set_bus_volume(value: float, bus_name: String) -> void:
	if bus_name == "Music":
		_music_volume = value
	elif bus_name == "SFX":
		_sfx_volume = value
	_ensure_audio_bus(bus_name, value)

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
	dot.add_theme_font_size_override("font_size", 12)
	dot.add_theme_color_override("font_color", Color.WHITE)
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.custom_minimum_size = Vector2(28, 28)
	dot.add_theme_stylebox_override("normal", _sb(Color("5c2e2e") if is_ai else Color("2d4a2d"),
		Color("8b4513") if is_ai else Color("4caf50"), 2, 14))
	if is_ai:
		_e_avatar = dot
	else:
		_p_avatar = dot
	who.add_child(dot)
	var hp_lbl := Label.new()
	hp_lbl.text = "HP: 100"
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", C_NAME)
	who.add_child(hp_lbl)
	if is_ai:
		hp_lbl.name = "ai_hp"
	else:
		hp_lbl.name = "p_hp"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var row_wrap := MarginContainer.new()
	row_wrap.add_theme_constant_override("margin_top", 2)
	row_wrap.add_theme_constant_override("margin_left", 2)
	row_wrap.add_theme_constant_override("margin_right", 2)
	row_wrap.add_theme_constant_override("margin_bottom", 2)
	row_wrap.add_child(row)
	vb.add_child(row_wrap)
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
	p.custom_minimum_size = Vector2(0, 79)
	return p

func _build_shop() -> PanelContainer:
	var p := _panel(C_PANEL, 4)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	var hdr_box := Control.new()
	hdr_box.custom_minimum_size = Vector2(0, 16)
	hdr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_box.clip_contents = true
	vb.add_child(hdr_box)
	_shop_hdr = Label.new()
	_shop_hdr.add_theme_font_size_override("font_size", 12)
	_shop_hdr.add_theme_color_override("font_color", C_NAME)
	_shop_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr_box.add_child(_shop_hdr)
	_shop_hdr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shop_viewport := Control.new()
	shop_viewport.custom_minimum_size = Vector2(0, SHOP_H)
	shop_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_viewport.clip_contents = true
	vb.add_child(shop_viewport)
	_shop_row = HBoxContainer.new()
	_shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_row.add_theme_constant_override("separation", 4)
	shop_viewport.add_child(_shop_row)
	_shop_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return p

func _build_actions() -> HBoxContainer:
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 4)
	act.custom_minimum_size = Vector2(0, 32)
	var buttons: Array[Button] = [
		_btn("🔄刷新", C_BTN_REFRESH, func(): _do_reroll()),
		_btn("冻结", C_BTN_FREEZE, func(): _toggle_freeze()),
		_btn("升级", C_BTN_LEVEL, func(): _do_level()),
		_btn("开打", C_BTN_FIGHT, func(): _fight()),
	]
	_freeze_btn = buttons[1]
	for b in buttons:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_action_buttons.append(b)
		act.add_child(b)
	return act

func _build_selection_bar() -> HBoxContainer:
	_sel_bar = HBoxContainer.new()
	_sel_bar.visible = false
	_sel_bar.add_theme_constant_override("separation", 6)
	_sel_label = Label.new()
	_sel_label.add_theme_font_size_override("font_size", 12)
	_sel_label.add_theme_color_override("font_color", C_GOLD)
	_sel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sel_label.visible = false
	_sel_bar.add_child(_sel_label)
	_sel_info_btn = _btn("查看详情", C_BTN_LEVEL, func(): _show_selected_info())
	_sel_contract_btn = _btn("立契", Color("a29bfe"), func(): _toggle_contract_selected_slot())
	_sel_sell_btn = _btn("卖出 +2", C_BTN_FIGHT, func(): _sell_selected_slot())
	_sel_cancel_btn = _btn("取消", C_BTN_REFRESH, func(): _cancel_selection())
	_sel_bar.add_child(_sel_info_btn)
	_sel_bar.add_child(_sel_contract_btn)
	_sel_bar.add_child(_sel_sell_btn)
	_sel_bar.add_child(_sel_cancel_btn)
	return _sel_bar

func _build_log() -> PanelContainer:
	var p := _panel(C_SLOT_EMPTY, 2)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_active = true
	_log.custom_minimum_size = Vector2(0, 36)
	_log.add_theme_font_size_override("normal_font_size", 11)
	_log.add_theme_color_override("default_color", C_MUTED)
	p.add_child(_log)
	return p

## ---------- 刷新 ----------

func _refresh() -> void:
	_clear_drop_preview()
	_clear_card_tooltip()
	_contract_slot = _find_contract_slot()
	_hp.text = "❤%d" % p_hp
	_gold.text = "🪙%d" % ps.gold
	if _game_over:
		_hint.text = "你赢了！对局结束" if e_hp <= 0 else "你输了！对局结束"
	else:
		_hint.text = "本回合剩余%d金：不结转，下回合基准%d金" % [ps.gold, Economy.round_base_gold(ps.round_no + 1)]
	_round_label.text = "⏱\uFE0E%d" % ps.round_no
	_round_label.add_theme_font_override("font", UiTheme.symbol_font())
	_level_label.text = "酒馆Lv%d 🪙%d" % [ps.level, ep.gold]
	var has_mech := false
	for c in ps.board:
		if c != null and String(c.get("race", "")) == "mech":
			has_mech = true
			break
	_mech_stat.visible = has_mech
	if has_mech:
		var mech_parts := ""
		if ps.has_formation():
			mech_parts = " 可合体"
		elif ps.mech_level > 0:
			mech_parts = " 已出击%d次" % ps.mech_level
		var armor_text := " 护甲%d" % ps.mech_repair if ps.mech_repair > 0 else ""
		_mech_stat.text = "M 出击Lv%d%s%s" % [ps.mech_level, mech_parts, armor_text]
		_mech_stat.tooltip_text = "机械出击等级 %d；磁力强化累计 %d；维修护甲 %d" % [
			ps.mech_level, ps.mag_t, ps.mech_repair]
	_update_sigil_slot()
	_update_phase_visual()
	_update_quest_visual()
	_shop_hdr.text = "🏰 %d -> 🏰 %d 🪙%d%s" % [ps.level, ps.level + 1,
		Economy.level_up_cost(ps.level), ("  免费刷新×%d" % ps.free_refresh) if ps.free_refresh > 0 else ""]
	var ai_hp_label: Label = find_child("ai_hp", true, false) as Label
	var p_hp_label: Label = find_child("p_hp", true, false) as Label
	if ai_hp_label != null:
		ai_hp_label.text = "HP: %d" % e_hp
	if p_hp_label != null:
		p_hp_label.text = "HP: %d" % p_hp

	if _freeze_btn != null:
		_freeze_btn.text = "解冻" if ps.shop_frozen else "冻结"
	if _action_buttons.size() >= 4:
		_action_buttons[0].text = "🔄刷新(%d)" % ps.free_refresh if ps.free_refresh > 0 else "🔄刷新"
		_action_buttons[0].disabled = _busy or _game_over or ps.shop_frozen \
			or (ps.free_refresh <= 0 and ps.gold < Economy.refresh_cost())
		_action_buttons[1].disabled = _busy or _game_over
		_action_buttons[2].disabled = _busy or _game_over or ps.level >= 7 or not Economy.can_level_up(ps.level, ps.gold)
		_action_buttons[3].disabled = _busy or _game_over
	if _game_over:
		_selected = -1
		_selected_slot = -1
		_choice_host.visible = false
		_rope.left_ratio = 0.0
		_rope.label = "对局结束"
		_rope.burning = false
		_rope.queue_redraw()
	elif _choice_host != null:
		_choice_host.visible = true

	_fill_board(_ai_row, ep.board, false)
	_fill_board(_p_row, ps.board, true)

	_clear_ui_children(_hand_row)
	for i in range(ps.hand.size()):
		var card := Draggable.new()
		card.host = self
		card.index = i
		card.custom_minimum_size = Vector2(HAND_W, HAND_H)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.clip_contents = true
		var visual := PanelContainer.new()
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill_card(visual, ps.hand[i], HAND_W, HAND_H, false)
		card.add_child(visual)
		visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if i == _selected:
			visual.add_theme_stylebox_override("panel", _sb(C_SLOT_FILL, C_GOLD, 3))
		_hand_row.add_child(card)
		_make_card_children_passive(visual)

	_clear_ui_children(_shop_row)
	for i in range(ps.shop.size()):
		var card := Dropless.new()
		card.index = i
		card.host = self
		card.custom_minimum_size = Vector2(SHOP_W, SHOP_H)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.clip_contents = true
		var visual := PanelContainer.new()
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var data = ps.shop[i]
		if data == null:
			visual.add_theme_stylebox_override("panel", _sb(C_SLOT_EMPTY, C_LINE, 3))
			var sold := _muted("已购", 10)
			visual.add_child(sold)
		else:
			_fill_card(visual, data, SHOP_W, SHOP_H, true)
		card.add_child(visual)
		visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shop_row.add_child(card)
		if data != null:
			_make_card_children_passive(visual)

	_update_selection_bar()
	_update_zone_pulse()
	_update_board_state_visuals()
	_update_freeze_visual()

func _fill_board(row: HBoxContainer, board: Array, is_mine: bool) -> void:
	_clear_card_tooltip()
	_clear_ui_children(row)
	var has_mech := _board_has_mech(board)
	for i in range(board.size()):
		row.add_child(_make_board_slot(i, board[i], is_mine, has_mech))

func _update_sigil_slot() -> void:
	if _sigil_slot == null:
		return
	var contract_slot := _find_contract_slot()
	var has_sacrifice := false
	for card in ps.board:
		if card != null and String(card.get("race", "")) == "sacrifice":
			has_sacrifice = true
			break
	var show: bool = contract_slot >= 0 or int(ps.debt) > 0 or has_sacrifice
	_sigil_slot.visible = show
	if not show:
		_sigil_slot.tooltip_text = ""
		return
	var text := ""
	var color := C_CONTRACT
	var border := C_CONTRACT
	var active := false
	if contract_slot >= 0:
		var card: Dictionary = ps.board[contract_slot]
		text = "契印:%s" % String(card.get("n", "献祭随从"))
		color = Color("d6d0ff")
		border = C_CONTRACT
		active = true
	else:
		text = "契印槽:空" + (" · 拖随从到此处立契" if has_sacrifice else "")
		if has_sacrifice:
			color = C_GOLD
			border = C_GOLD
	_sigil_slot.set_state(text, color, border, active)
	_sigil_slot.tooltip_text = "契印目标阵亡后转化为献祭债务。右键槽位可清空。"

func _update_phase_visual() -> void:
	if _phase_label == null:
		return
	var active := _board_has_race(ps.board, "evolve")
	_phase_label.visible = active
	if not active:
		_phase_label.tooltip_text = ""
		return
	if ps.phase == 0:
		_phase_label.text = "相:昼"
		_phase_label.add_theme_color_override("font_color", C_GOLD)
		_phase_label.add_theme_stylebox_override("normal", _sb(C_PANEL, C_GOLD, 2, 4))
		_phase_label.tooltip_text = "昼相：本场每名进化随从前2次出手，在自身进化效果之外额外推进1格"
	else:
		_phase_label.text = "相:夜"
		_phase_label.add_theme_color_override("font_color", Color("a29bfe"))
		_phase_label.add_theme_stylebox_override("normal", _sb(C_PANEL, Color("a29bfe"), 2, 4))
		_phase_label.tooltip_text = "夜相：本场每名进化随从前3次受击，在自身进化效果之外额外推进1格"


func _update_quest_visual() -> void:
	if _quest_label == null:
		return
	var active := _board_has_race(ps.board, "evolve")
	_quest_label.visible = active
	if not active:
		_quest_label.tooltip_text = ""
		return
	ps.ensure_quest()
	var definition: Dictionary = ps.quest_definition()
	if definition.is_empty():
		_quest_label.visible = false
		return
	var need: int = Quest.need_for_id(ps.quest_id)
	var current: int = int(ps.evo_prog.get("cur", 0))
	var complete: bool = need > 0 and current >= need
	_quest_label.text = "宣言:%s %d/%d%s" % [
		String(definition.get("n", ps.quest_id)),
		mini(current, need),
		need,
		" ✔" if complete else "",
	]
	var color: Color = C_GOLD if complete else Color("7bed9f")
	_quest_label.add_theme_color_override("font_color", color)
	_quest_label.add_theme_stylebox_override("normal", _sb(C_PANEL, color, 2, 4))
	_quest_label.add_theme_stylebox_override("pressed", _sb(C_SLOT_FILL.darkened(0.08), color, 2, 4))
	_quest_label.tooltip_text = "%s\n达成后全场进化随从 +2 格；未达成 +1 格。点击可三选一更换。" % \
		String(definition.get("t", ""))


func _open_quest() -> void:
	if _busy or _game_over or not _board_has_race(ps.board, "evolve"):
		return
	ps.ensure_quest()
	if find_child("quest_overlay", true, false) != null:
		return
	var pool: Array = Quest.pool_for_phase(ps.quest_pool, ps.phase)
	if pool.is_empty():
		return
	var overlay := Control.new()
	overlay.name = "quest_overlay"
	overlay.z_index = 126
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(340, 0)
	panel.add_theme_stylebox_override("panel", _sb(Color("2d3047"), Color("7bed9f"), 18, 10))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "进化宣言 · %s形态" % ("昼" if ps.phase == 0 else "夜")
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_font_override("font", UiTheme.cjk_font_bold())
	title.add_theme_color_override("font_color", Color("7bed9f"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var rule := Label.new()
	rule.text = "出手攻击时进化+1格 · 每场最多2次" if ps.phase == 0 \
		else "受到攻击时进化+1格 · 每场最多3次"
	rule.add_theme_font_size_override("font_size", 12)
	rule.add_theme_color_override("font_color", C_GOLD if ps.phase == 0 else Color("a29bfe"))
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rule)

	var reward_hint := Label.new()
	reward_hint.text = "达成宣言 → 全场进化随从 +2 格；未达成 +1 格"
	reward_hint.add_theme_font_size_override("font_size", 11)
	reward_hint.add_theme_color_override("font_color", C_SUBTLE)
	reward_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(reward_hint)

	_quest_buttons.clear()
	for index in range(pool.size()):
		if not (pool[index] is Dictionary):
			continue
		var item: Dictionary = pool[index]
		var selected: bool = String(item.get("id", "")) == ps.quest_id
		var button := Button.new()
		var prefix: String = "✔ 已选 · " if selected else ""
		var phase_tag: String = "[攻击加格] " if ps.phase == 0 else "[受击加格] "
		button.text = "%s%s%s：%s" % [
			prefix,
			phase_tag,
			String(item.get("n", "宣言")),
			String(item.get("t", "")),
		]
		button.custom_minimum_size = Vector2(316, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", C_NAME)
		var border: Color = C_BTN_FIGHT if selected else Color("7bed9f")
		var bg: Color = Color("5a4030") if selected else C_LINE_FILL
		button.add_theme_stylebox_override("normal", _sb(bg, border, 6, 6))
		button.add_theme_stylebox_override("hover", _sb(bg.lightened(0.08), C_GOLD, 6, 6))
		button.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.08), border, 6, 6))
		button.pressed.connect(_select_quest.bind(index))
		box.add_child(button)
		_quest_buttons.append(button)

	var close := _btn("关闭", C_BTN_REFRESH, overlay.queue_free)
	close.custom_minimum_size = Vector2(100, 32)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 13)
	box.add_child(close)


func _select_quest(index: int) -> void:
	var result: Dictionary = ps.select_quest(index)
	if not bool(result.get("ok", false)):
		return
	if String(ps.last_message) != "":
		_say(String(ps.last_message))
	var overlay := find_child("quest_overlay", true, false)
	if overlay != null:
		overlay.queue_free()
	_refresh()


func _board_has_mech(board: Array) -> bool:
	for card in board:
		if card != null and String(card.get("race", "")) == "mech":
			return true
	return false

func _board_has_race(board: Array, race: String) -> bool:
	for card in board:
		if card != null and String(card.get("race", "")) == race:
			return true
	return false

func _refresh_board_slot(row: HBoxContainer, board: Array, is_mine: bool, index: int) -> void:
	if index < 0 or index >= board.size() or index >= row.get_child_count():
		return
	var slot := row.get_child(index) as DropSlot
	if slot == null:
		return
	_populate_board_slot(slot, index, board[index], is_mine, _board_has_mech(board))

func _find_slot_decor(slot: Control) -> SlotDecor:
	if slot == null:
		return null
	for child in slot.get_children():
		if child is SlotDecor:
			return child as SlotDecor
	return null

func _update_board_state_visuals() -> void:
	if _p_row == null:
		return
	var contract_slot := _find_contract_slot()
	_contract_slot = contract_slot
	var devour_source := _drag_source_slot
	if devour_source < 0 or devour_source >= ps.board.size():
		devour_source = _selected_slot
	var devour_active := false
	if devour_source >= 0 and devour_source < ps.board.size() and ps.board[devour_source] != null:
		devour_active = bool(ps.board[devour_source].get("_devourReady", false))
	for i in range(mini(_p_row.get_child_count(), ps.board.size())):
		var decor := _find_slot_decor(_p_row.get_child(i) as Control)
		if decor == null:
			continue
		decor.is_contract = i == contract_slot
		decor.is_devour_target = devour_active and i != devour_source and ps.board[i] != null
		decor.is_selected = i == _selected_slot
		decor.queue_redraw()

func _preview_drop(target: Control, valid: bool, mode: String, reason: String) -> void:
	if target == null or not is_instance_valid(target):
		return
	var state := "valid" if valid else "invalid"
	var key := "%s:%s:%s" % [state, mode, reason]
	if _active_drop_target != target:
		_clear_drop_preview()
		_active_drop_target = target
	if String(target.get_meta("drop_preview_key", "")) == key:
		return
	target.set_meta("drop_preview_key", key)
	match state:
		"valid":
			_drop_preview_trace.append("valid:%s:%s" % [mode, reason])
		_:
			_drop_preview_trace.append("invalid:%s:%s" % [mode, reason])
	if target is DropSlot:
		var decor := _find_slot_decor(target)
		if decor != null:
			decor.drop_preview = mode if valid else "invalid"
			decor.drop_preview_label = _drop_preview_label(mode, valid)
			decor.queue_redraw()
	elif target is SigilSlot:
		(target as SigilSlot).set_preview(valid, mode)

func _clear_drop_preview(target: Control = null) -> void:
	if target == null:
		target = _active_drop_target
	if target != null and is_instance_valid(target):
		target.set_meta("drop_preview_key", "")
		if target is DropSlot:
			var decor := _find_slot_decor(target)
			if decor != null:
				decor.drop_preview = ""
				decor.drop_preview_label = ""
				decor.queue_redraw()
		elif target is SigilSlot:
			(target as SigilSlot).set_preview(false, "")
	if target == _active_drop_target:
		_active_drop_target = null

func _drop_preview_label(mode: String, valid: bool) -> String:
	if not valid:
		return "不可用"
	match mode:
		"devour":
			return "吞噬"
		"magnet":
			return "磁力"
		"mech_merge", "mech_upgrade":
			return "合体"
		"place":
			return "上场"
		"sigil":
			return "契印"
		"swap":
			return "交换"
	return ""

func _slot_rect(row: Control, index: int) -> Rect2:
	var slot := _child_or_null(row, index)
	if slot == null:
		return Rect2()
	return Rect2(slot.global_position, slot.size)

func _hand_rect(index: int) -> Rect2:
	var slot := _child_or_null(_hand_row, index)
	if slot == null:
		return Rect2(Vector2.ZERO, Vector2(1, 1))
	return Rect2(slot.global_position, slot.size)


func _update_spell_target_arrow() -> void:
	if _spell_arrow == null:
		return
	if _busy or _game_over or ps == null or _selected < 0 or _selected >= ps.hand.size():
		_spell_arrow.set_targeting(false)
		return
	var card: Dictionary = ps.hand[_selected]
	var color := Color.WHITE
	var needs_target := false
	if String(card.get("t", "")) == "s" and String(card.get("fx", "")) != "spell-boost":
		needs_target = true
		color = C_BLUE
	elif card.has("magA") or card.has("magH"):
		needs_target = true
		color = Color(MechanicStyle.family_style("mech").get("color", C_BLUE))
	if not needs_target:
		_spell_arrow.set_targeting(false)
		return
	var source_rect := _hand_rect(_selected)
	# The arrow is a full-rect sibling of the root layout, so its local and global
	# origins match; keeping global coordinates also avoids a per-frame transform.
	_spell_arrow.set_targeting(true, source_rect.get_center(), get_global_mouse_position(), color)


func _spawn_drop_fx(mode: String, from_rect: Rect2, to_rect: Rect2, label_text: String, style: Dictionary) -> Control:
	var fx := DropFxLayer.new()
	fx.name = "%s_fx" % mode
	fx.mode = mode
	fx.from_rect = from_rect
	fx.to_rect = to_rect
	fx.family = String(style.get("family", "neutral"))
	fx.colors = [
		Color(style.get("color", Color.WHITE)),
		Color(style.get("accent", Color.WHITE)),
		Color(style.get("deep", Color.BLACK)),
		Color(style.get("pale", Color.WHITE)),
	]
	fx.set_meta("drop_mode", mode)
	fx.set_meta("drop_label", label_text)
	fx.set_meta("family", fx.family)
	fx.set_meta("color", fx.colors[0])
	add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if label_text != "":
		var label := Label.new()
		label.name = "drop_fx_label"
		label.text = label_text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_font_override("font", UiTheme.cjk_font_bold())
		label.add_theme_color_override("font_color", fx.colors[0])
		label.add_theme_color_override("font_outline_color", fx.colors[2])
		label.add_theme_constant_override("outline_size", 4)
		fx.add_child(label)
		label.reset_size()
		label.global_position = to_rect.get_center() + Vector2(-label.size.x * 0.5, -34.0)
	var duration := maxf(0.12, 0.86 / maxf(1.0, _speed))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "progress", 1.0, duration)
	tween.tween_property(fx, "modulate:a", 0.0, duration).set_delay(duration * 0.45)
	tween.chain().tween_callback(fx.queue_free)
	_interaction_fx_trace.append("%s_fx" % mode)
	return fx


func _play_quest_reward_prep(side: String, targets: Array[Dictionary], ok: bool) -> void:
	if targets.is_empty():
		return
	var row := _p_row if side == "p" else _ai_row
	var source_control: Control = null
	if side == "p" and _quest_label != null and _quest_label.visible:
		source_control = _quest_label
	else:
		source_control = find_child("side_ai" if side == "e" else "side_p", true, false) as Control
	var source_rect := Rect2(
		Vector2(get_viewport_rect().size.x * 0.5, 8.0),
		Vector2(1.0, 1.0))
	if source_control != null:
		source_rect = Rect2(source_control.global_position, source_control.size)
	var style := MechanicStyle.family_style("evolve")
	for index in range(targets.size()):
		var target: Dictionary = targets[index]
		var slot := int(target.get("slot", -1))
		var target_rect := _slot_rect(row, slot)
		if target_rect.size.x <= 0.0:
			continue
		var fx := _spawn_drop_fx("quest_reward", source_rect, target_rect, "", style)
		if not ok and fx != null:
			fx.modulate = Color(1.0, 1.0, 1.0, 0.72)
		_play_sfx("evo_full")
		await get_tree().create_timer(maxf(0.04, 0.12 / maxf(1.0, _speed))).timeout


func _devour_success_fx(from_rect: Rect2, target_slot: int) -> void:
	var target_rect := _slot_rect(_p_row, target_slot)
	var style := MechanicStyle.family_style("sacrifice")
	_spawn_drop_fx("devour_success", from_rect, target_rect, "灵魂摄取", style)
	_play_sfx("devour")

func _sigil_bind_fx(source_slot: int) -> void:
	var source_rect := _slot_rect(_p_row, source_slot)
	var style := MechanicStyle.family_style("sacrifice")
	_spawn_drop_fx("sigil_bind", source_rect, source_rect, "契印", style)
	_play_sfx("contract")

func _magnet_success_fx(from_rect: Rect2, target_slot: int) -> void:
	var target_rect := _slot_rect(_p_row, target_slot)
	var style := MechanicStyle.family_style("mech")
	_spawn_drop_fx("magnet_success", from_rect, target_rect, "机械协议", style)
	_play_sfx("magnet")

func _place_success_fx(target_slot: int, race: String) -> void:
	var target_rect := _slot_rect(_p_row, target_slot)
	var style := MechanicStyle.family_style(race)
	_spawn_drop_fx("place_success", target_rect, target_rect, "部署", style)
	_play_sfx("place")

func _make_board_slot(index: int, data, is_mine: bool, has_mech: bool) -> DropSlot:
	var slot := DropSlot.new()
	slot.host = self
	_populate_board_slot(slot, index, data, is_mine, has_mech)
	return slot

func _populate_board_slot(slot: DropSlot, index: int, data, is_mine: bool, has_mech: bool) -> void:
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()
	var zone_ready: bool = is_mine and ps.has_formation()
	slot.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
	slot.slot = index
	slot.is_mine = is_mine
	slot.zone = is_mine and has_mech and index < ZONE_SLOTS
	slot.zone_ready = zone_ready
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.clip_contents = true
	slot.self_modulate = Color.WHITE
	slot.scale = Vector2.ONE
	var bg := C_SLOT_EMPTY if data == null else C_SLOT_FILL
	slot.add_theme_stylebox_override("panel", _sb(bg, bg, 0))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 11)
	m.add_theme_constant_override("margin_left", 4)
	m.add_theme_constant_override("margin_right", 4)
	m.add_theme_constant_override("margin_bottom", 6)
	slot.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	m.add_child(vb)
	if data != null:
		var head := Label.new()
		head.name = "card_star"
		head.text = "⭐".repeat(clampi(int(data.get("s", data.get("star", 1))), 1, 7))
		head.add_theme_font_size_override("font_size", 7)
		head.add_theme_color_override("font_color", C_GOLD)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(head)
		_fill_name_lines(vb, data, ps if is_mine else ep, index, 9, 22)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_child(spacer)
		var ah := HBoxContainer.new()
		ah.name = "stat_line"
		ah.alignment = BoxContainer.ALIGNMENT_CENTER
		ah.add_theme_constant_override("separation", 0)
		var a := Label.new(); a.text = str(int(data.get("a", 0)))
		a.name = "stat_atk"
		a.add_theme_font_size_override("font_size", 13)
		a.add_theme_font_override("font", UiTheme.cjk_font_bold())
		a.add_theme_color_override("font_color", C_ATK)
		var sep := Label.new(); sep.text = "/"
		sep.add_theme_font_size_override("font_size", 13)
		sep.add_theme_font_override("font", UiTheme.cjk_font_bold())
		sep.add_theme_color_override("font_color", C_MUTED)
		var h := Label.new(); h.text = str(int(data.get("h", 0)))
		h.name = "stat_hp"
		h.add_theme_font_size_override("font_size", 13)
		h.add_theme_font_override("font", UiTheme.cjk_font_bold())
		h.add_theme_color_override("font_color", C_HP)
		ah.add_child(a); ah.add_child(sep); ah.add_child(h)
		vb.add_child(ah)
	var decor := SlotDecor.new()
	decor.zone = slot.zone
	decor.zone_ready = slot.zone_ready
	decor.has_card = data != null
	decor.is_gold = data != null and bool(data.get("g", false))
	decor.is_taunt = data != null and String(data.get("k", "")).contains("t")
	decor.is_shield = data != null and String(data.get("k", "")).contains("d") and bool(data.get("shield", true))
	decor.is_attacking = false
	decor.is_hit = false
	decor.is_dead = data != null and bool(data.get("_dead", false))
	decor.is_contract = is_mine and data != null and bool(data.get("_contract", false))
	decor.is_devour_target = false
	decor.hp_ratio = 1.0 if data == null else clampf(float(data.get("h", 1)) / maxf(1.0, float(data.get("mh", data.get("h", 1)))), 0.0, 1.0)
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(decor)
	decor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if decor.is_dead:
		slot.modulate = Color(1.0, 1.0, 1.0, 0.28)
		slot.pivot_offset = slot.custom_minimum_size * 0.5
		slot.scale = Vector2(0.84, 0.84)
	if is_mine and data == null:
		var plus := Label.new()
		plus.text = "+"
		plus.add_theme_font_size_override("font_size", 9)
		plus.add_theme_color_override("font_color", C_NAME)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		decor.add_child(plus)
		plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if slot.zone and index == 0:
		decor.add_child(_make_zone_badge(zone_ready))
	if decor.is_contract:
		decor.add_child(_make_contract_badge())
	if data != null:
		slot.tooltip_text = ""
	elif is_mine:
		slot.tooltip_text = "空位：先点手牌，再点这里上场。"
	else:
		slot.tooltip_text = "AI 随从位。"
	_make_card_children_passive(slot)

func _make_contract_badge() -> Label:
	var badge := Label.new()
	badge.text = "契印"
	badge.add_theme_font_size_override("font_size", 7)
	badge.add_theme_color_override("font_color", Color("f1edff"))
	badge.add_theme_stylebox_override("normal", _sb(Color(0.28, 0.22, 0.48, 0.94), C_CONTRACT, 1, 1))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -25.0
	badge.offset_top = 1.0
	badge.offset_right = -1.0
	badge.offset_bottom = 12.0
	return badge

func _make_card_children_passive(root: Control) -> void:
	for child in root.get_children():
		if child is Control:
			var control := child as Control
			if control.has_meta("card_detail_tooltip"):
				control.mouse_filter = Control.MOUSE_FILTER_PASS
			else:
				control.mouse_filter = Control.MOUSE_FILTER_IGNORE
				control.tooltip_text = ""
			_make_card_children_passive(control)

func _make_zone_badge(ready: bool) -> Label:
	var badge := Label.new()
	badge.text = "首脑位"
	badge.add_theme_font_size_override("font_size", 8)
	badge.add_theme_color_override("font_color", Color("222222") if ready else Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.80, 0.43, 0.95) if ready else Color(0.455, 0.725, 1.0, 0.95)
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("normal", style)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -32.0
	badge.offset_right = 0.0
	badge.offset_top = 0.0
	badge.offset_bottom = 12.0
	return badge

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
	if _busy or _game_over:
		return
	if ps.shop_frozen:
		_say("商店已冻结，先解冻再刷新")
		return
	var ok: bool = ps.reroll()
	if ok:
		_play_sfx("reroll")
	_say("刷新" if ok else "金币不足，无法刷新")
	_refresh()
	if ok:
		_animate_shop_reroll()

func _do_level() -> void:
	if _busy or _game_over:
		return
	var shop_before := _shop_signature()
	var ok: bool = ps.level_up()
	if ok:
		_play_sfx("level")
	_say("升级到 Lv%d" % ps.level if ok else "金币不足，无法升级")
	_refresh()
	if ok and _shop_signature() != shop_before:
		_animate_shop_reroll()

func _shop_signature() -> String:
	var parts: Array[String] = []
	for data in ps.shop:
		if data == null:
			parts.append("-")
		else:
			parts.append("%s:%d:%d:%d" % [
				String(data.get("n", "?")),
				int(data.get("a", 0)),
				int(data.get("h", 0)),
				int(data.get("s", data.get("star", 1))),
			])
	return "|".join(parts)

func _animate_shop_reroll() -> void:
	if _shop_row == null:
		return
	var cards := _shop_row.get_children()
	for i in range(cards.size()):
		var card := cards[i] as Control
		if card == null:
			continue
		card.set_meta("shop_reroll_animated", true)
		card.pivot_offset = card.custom_minimum_size * 0.5
		card.scale = Vector2(0.88, 0.88)
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.16).set_delay(float(i) * 0.035)
		tween.tween_property(card, "scale", Vector2.ONE, 0.18).set_delay(float(i) * 0.035).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _toggle_freeze() -> void:
	if _busy or _game_over:
		return
	ps.shop_frozen = not ps.shop_frozen
	if not ps.shop_frozen:
		_clear_freeze_overlay()
	_say("商店已冻结，下回合保留" if ps.shop_frozen else "已解除冻结")
	_refresh()

func _clear_freeze_overlay() -> void:
	var stored := _freeze_overlay
	_freeze_overlay = null
	if stored != null and is_instance_valid(stored):
		stored.visible = false
		stored.queue_free()
	for old in find_children("freeze_overlay", "Control", true, false):
		if old == stored:
			continue
		old.visible = false
		old.queue_free()

func _update_freeze_visual() -> void:
	_clear_freeze_overlay()
	if _shop_hdr != null:
		_shop_hdr.text = _shop_hdr.text.replace("  ❄已冻结", "")
	if not ps.shop_frozen or _shop_row == null:
		return
	if _shop_hdr != null:
		_shop_hdr.text += "  ❄已冻结"
	var overlay := FreezeOverlay.new()
	overlay.name = "freeze_overlay"
	overlay.target = _shop_row
	overlay.z_index = 60
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_freeze_overlay = overlay

func _click_shop(index: int) -> void:
	if _busy or _game_over:
		return
	_buy(index)

func _buy(index: int) -> void:
	var r: Dictionary = ps.buy(index)
	if bool(r["ok"]):
		_say("买入 %s（-%d金）" % [String(r["card"].get("n", "?")), int(r["cost"])])
	else:
		_say("买牌失败：钱不够或手牌已满")
	_refresh()

func begin_drag(index: int) -> void:
	_selected = index
	_selected_slot = -1
	if index >= 0 and index < ps.hand.size():
		var c = ps.hand[index]
		var is_mat: bool = c.has("magA") or c.has("magH")
		_say("拖动 %s%s" % [String(c.get("n", "?")), "（材料牌：拖到机械上磁力强化）" if is_mat else ""])
	_update_selection_bar()

func begin_board_drag(slot: int) -> void:
	if slot < 0 or slot >= ps.board.size() or ps.board[slot] == null:
		return
	_clear_drop_preview()
	_selected = -1
	_selected_slot = -1
	_drag_source_slot = slot
	var card = ps.board[slot]
	if card != null and bool(card.get("_devourReady", false)):
		_say("选择吞噬目标：拖到另一名友方随从身上，拖回自身取消")
	_update_selection_bar()
	_update_board_state_visuals()

func drop_on_slot(hand_index: int, slot: int) -> void:
	if hand_index < 0 or hand_index >= ps.hand.size():
		return
	var c = ps.hand[hand_index]
	var target = ps.board[slot]
	var is_mat: bool = c.has("magA") or c.has("magH")
	var battlecry: Dictionary = c.get("bc", {})
	var from_rect := _hand_rect(hand_index)
	if target != null and String(battlecry.get("e", "")) == "devour":
		var devour_result: Dictionary = ps.devour_from_hand(hand_index, slot)
		if bool(devour_result.get("ok", false)):
			var eater: Dictionary = devour_result.get("eater", {})
			_say("吞噬：%s → %s（%d/%d）" % [
				String(devour_result.get("prey", {}).get("n", "友方")),
				String(eater.get("n", "献祭者")),
				int(eater.get("a", 0)), int(eater.get("h", 0))])
			_devour_success_fx(from_rect, slot)
			_selected = -1
			_selected_slot = -1
		else:
			_say("吞噬失败：需要选择另一名友方随从")
	elif is_mat and target != null and String(target.get("race", "")) == "mech":
		var r: Dictionary = ps.feed(hand_index, slot)
		if bool(r["ok"]):
			_magnet_success_fx(from_rect, slot)
			_say("磁力强化：%s → %s（+%d/+%d）" % [String(c.get("n", "?")), String(target.get("n", "?")),
				int(r["gained"]["a"]), int(r["gained"]["h"])])
		else:
			_say("磁力喂料失败")
	elif ps.place(hand_index, slot, ep.board):
		_place_success_fx(slot, String(c.get("race", "neutral")))
		_say("上场：%s" % String(c.get("n", "?")))
		_selected = -1
		_selected_slot = -1
	else:
		_say("该格已占用，或这张牌不能这样用")
	_refresh()

func drop_board_on_slot(source_slot: int, target_slot: int) -> void:
	if source_slot < 0 or source_slot >= ps.board.size():
		return
	if target_slot < 0 or target_slot >= ps.board.size():
		return
	var source = ps.board[source_slot]
	if source == null:
		return
	var source_rect := _slot_rect(_p_row, source_slot)
	if source_slot == target_slot:
		if bool(source.get("_devourReady", false)):
			source["_devourReady"] = false
			_say("已取消吞噬")
			_drag_source_slot = -1
			_clear_drop_preview()
			_refresh()
		return
	var target = ps.board[target_slot]
	if target != null and bool(source.get("_devourReady", false)):
		var devour: Dictionary = ps.devour_ally(source_slot, target_slot)
		if bool(devour.get("ok", false)):
			_say("吞噬：%s → %s" % [String(target.get("n", "随从")), String(source.get("n", "随从"))])
			_devour_success_fx(source_rect, target_slot)
			_drag_source_slot = -1
			_refresh()
			return
	if target != null and (source.has("magA") or source.has("magH")):
		var feed_result: Dictionary = ps.feed_board(source_slot, target_slot)
		if bool(feed_result.get("ok", false)):
			_magnet_success_fx(source_rect, target_slot)
			_say("磁力强化：%s → %s（+%d/+%d）" % [
				String(source.get("n", "材料")), String(target.get("n", "机械")),
				int(feed_result.get("gained", {}).get("a", 0)),
				int(feed_result.get("gained", {}).get("h", 0))])
			_refresh()
			return
	if target != null:
		var upgrade: Dictionary = ps.upgrade_part(source_slot, target_slot)
		if bool(upgrade.get("ok", false)):
			_magnet_success_fx(source_rect, target_slot)
			_say("零件升级：%s → %s（继承 +%d/+%d）" % [
				String(source.get("n", "零件")), String(target.get("n", "零件")),
				int(upgrade.get("gain", 0)), int(upgrade.get("gain", 0))])
			_refresh()
			return
		var merge: Dictionary = ps.magnet_merge(source_slot, target_slot)
		if bool(merge.get("ok", false)):
			_magnet_success_fx(source_rect, target_slot)
			_say("磁力合体：%s → %s" % [String(source.get("n", "机械")), String(target.get("n", "机械"))])
			_refresh()
			return
	ps.swap_slots(source_slot, target_slot)
	_drag_source_slot = -1
	_refresh()

func _click_hand(index: int, from_drag_start: bool = false) -> void:
	if _input_debug:
		var debug_card: Dictionary = ps.hand[index] if index >= 0 and index < ps.hand.size() else {}
		print("[input-debug] _click_hand enter index=%d selected=%d drag_start=%s busy=%s over=%s hand=%d board=%d type=%s name=%s" % [
			index, _selected, str(from_drag_start), str(_busy), str(_game_over), ps.hand.size(), _count(ps.board),
			String(debug_card.get("t", "")), String(debug_card.get("n", ""))])
	if _busy or _game_over or index < 0 or index >= ps.hand.size():
		return
	if _selected == index:
		if not from_drag_start:
			if _input_debug:
				print("[input-debug] _click_hand branch=cancel-selection index=%d" % index)
			_cancel_selection()
			return
		# Godot can publish drag data before a short press is released. That
		# same gesture is still a click, so do not consume it as a selection.
		_selected = -1
	var card: Dictionary = ps.hand[index]
	_selected_slot = -1
	if String(card.get("t", "")) == "s":
		if String(card.get("fx", "")) == "spell-boost":
			var boosted: Dictionary = ps.cast_spell(index)
			if bool(boosted.get("ok", false)):
				_say("施放 %s：后续法术永久 +1/+1" % String(card.get("n", "法术")))
			_selected = -1
		else:
			_selected = index
			_say("已选中 %s：点击一名我方随从施放" % String(card.get("n", "法术")))
			_refresh()
			return
	elif card.has("magA") or card.has("magH"):
		_selected = index
		_say("已选中 %s：点击一名我方机械随从进行磁力强化" % String(card.get("n", "材料")))
		_refresh()
		return
	else:
		var placed: int = ps.place_first_empty(index, ep.board)
		if _input_debug:
			print("[input-debug] _click_hand branch=place placed=%d hand_after=%d board_after=%d" % [
				placed, ps.hand.size(), _count(ps.board)])
		if placed >= 0:
			_say("上场：%s → 第 %d 格" % [String(card.get("n", "?")), placed + 1])
		else:
			_say("没有空位或这张牌不能直接上场")
		_selected = -1
	_refresh()

func _click_board(slot: int, is_mine: bool, from_drag_start: bool = false) -> void:
	if _busy or _game_over or not is_mine:
		return
	# 法术/材料已经由同一手势消费时，鼠标释放可能再落到随从上；这里吞掉重复事件，
	# 防止把施法目标误当成“点开随从详情/卖出”。
	if _selected < 0 and Time.get_ticks_msec() < _suppress_board_select_until_msec:
		return
	if slot < 0 or slot >= ps.board.size():
		return
	var target = ps.board[slot]
	if _selected >= 0 and _selected < ps.hand.size():
		var card: Dictionary = ps.hand[_selected]
		if String(card.get("t", "")) == "s":
			var spell_result: Dictionary = ps.cast_spell(_selected, slot)
			if bool(spell_result.get("ok", false)):
				_say("施放 %s：目标 %s +%d/+%d" % [
					String(card.get("n", "法术")), String(target.get("n", "随从")),
					int(spell_result.get("a", 0)), int(spell_result.get("h", 0))])
				_selected = -1
				_selected_slot = -1
				_suppress_board_select_until_msec = Time.get_ticks_msec() + 120
				_update_selection_bar()
			else:
				_say("法术需要点一名我方场上随从作为目标")
			_refresh()
			return
		if card.has("magA") or card.has("magH"):
			if target != null and String(target.get("race", "")) == "mech":
				var feed_result: Dictionary = ps.feed(_selected, slot)
				if bool(feed_result.get("ok", false)):
					_play_sfx("magnet")
					_say("磁力强化：%s → %s（+%d/+%d）" % [
						String(card.get("n", "材料")), String(target.get("n", "机械")),
						int(feed_result.get("gained", {}).get("a", 0)),
						int(feed_result.get("gained", {}).get("h", 0))])
					_selected = -1
					_selected_slot = -1
					_suppress_board_select_until_msec = Time.get_ticks_msec() + 120
					_update_selection_bar()
				else:
					_say("材料牌只能喂给我方机械随从")
				_refresh()
				return
		if target == null and ps.place(_selected, slot, ep.board):
			_say("上场：%s → 第 %d 格" % [String(card.get("n", "?")), slot + 1])
			_selected = -1
			_selected_slot = -1
			_update_selection_bar()
			_refresh()
			return
	if _selected_slot >= 0 and _selected_slot < ps.board.size() and ps.board[_selected_slot] != null:
		if _selected_slot == slot:
			if from_drag_start:
				_selected_slot = -1
				if target != null:
					_selected_slot = slot
					_update_selection_bar()
				return
			_cancel_selection()
			return
		var source: Dictionary = ps.board[_selected_slot]
		if target == null:
			ps.swap_slots(_selected_slot, slot)
			_selected = -1
			_selected_slot = slot
			_say("移动：%s → 第 %d 格" % [String(source.get("n", "随从")), slot + 1])
			_refresh()
			return
		var source_index := _selected_slot
		drop_board_on_slot(source_index, slot)
		if slot < ps.board.size() and ps.board[slot] != null:
			_selected = -1
			_selected_slot = slot
		else:
			_selected_slot = -1
		_update_selection_bar()
		return
	if target != null:
		_selected_slot = slot
		_selected = -1
		_update_selection_bar()
	else:
		_say("空槽：先点手牌，再点这里上场")

func _cancel_selection() -> void:
	_selected = -1
	_selected_slot = -1
	_drag_source_slot = -1
	_update_selection_bar()
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and (_selected >= 0 or _selected_slot >= 0):
		_cancel_selection()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT or mouse.pressed:
		return
	if Time.get_ticks_msec() < _drop_guard_until_msec:
		return
	if _click_at(get_global_mouse_position()):
		get_viewport().set_input_as_handled()

func _click_at(pos: Vector2) -> bool:
	if _busy or _game_over:
		return false
	var shop_index := _child_index_at(_shop_row, pos)
	if shop_index >= 0:
		_click_shop(shop_index)
		return true
	var hand_index := _child_index_at(_hand_row, pos)
	if hand_index >= 0:
		_click_hand(hand_index)
		return true
	var board_index := _child_index_at(_p_row, pos)
	if board_index >= 0:
		_click_board(board_index, true)
		return true
	return false

func _child_index_at(row: Control, pos: Vector2) -> int:
	if row == null or not row.visible:
		return -1
	for i in range(row.get_child_count()):
		var child := row.get_child(i) as Control
		if child != null and child.visible and child.get_global_rect().has_point(pos):
			return i
	return -1

func _register_drop() -> void:
	_drop_guard_until_msec = Time.get_ticks_msec() + 60

func _update_selection_bar() -> void:
	if _sel_bar == null or _sel_label == null:
		return
	_update_board_state_visuals()
	if _selected_slot >= 0 and _selected_slot < ps.board.size() and ps.board[_selected_slot] != null:
		var unit: Dictionary = ps.board[_selected_slot]
		_sel_label.text = ""
		_sel_label.visible = false
		_sel_info_btn.visible = true
		var can_contract := String(unit.get("race", "")) == "sacrifice"
		_sel_contract_btn.visible = can_contract
		_sel_contract_btn.disabled = not can_contract
		_sel_contract_btn.text = "解除契印" if bool(unit.get("_contract", false)) else "立契"
		_sel_sell_btn.visible = true
		_sel_cancel_btn.visible = true
		_sel_bar.visible = true
		_position_selection_bar()
		return
	_selected_slot = -1
	_sel_contract_btn.visible = false
	_sel_bar.visible = false
	_update_board_state_visuals()

func _position_selection_bar() -> void:
	if _sel_bar == null or not _sel_bar.visible:
		return
	var anchor: Control = null
	if _selected_slot >= 0 and _selected_slot < ps.board.size() and ps.board[_selected_slot] != null:
		anchor = _child_or_null(_p_row, _selected_slot)
	elif _selected >= 0 and _selected < ps.hand.size():
		anchor = _child_or_null(_hand_row, _selected)
	if anchor == null:
		return
	_sel_bar.reset_size()
	var target_size := _sel_bar.get_combined_minimum_size()
	_sel_bar.size = target_size
	var desired := anchor.global_position + Vector2(
		anchor.size.x * 0.5 - target_size.x * 0.5, anchor.size.y + 5.0)
	var viewport_size := get_viewport_rect().size
	desired.x = clampf(desired.x, 8.0, viewport_size.x - target_size.x - 8.0)
	desired.y = clampf(desired.y, 8.0, viewport_size.y - target_size.y - 8.0)
	_sel_bar.global_position = desired

func _selected_card() -> Dictionary:
	if _selected_slot >= 0 and _selected_slot < ps.board.size() and ps.board[_selected_slot] != null:
		return ps.board[_selected_slot]
	if _selected >= 0 and _selected < ps.hand.size():
		return ps.hand[_selected]
	return {}

func _show_selected_info() -> void:
	var card: Dictionary = _selected_card()
	if card.is_empty():
		return
	var state = ep if _selected_slot >= 0 and bool(ps.board[_selected_slot].get("_side", "p") == "e") else ps
	_popup_card(card, state)

func _popup_card(card: Dictionary, state = null) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "随从详情"
	dialog.dialog_text = _card_tooltip(card, state, true)
	dialog.ok_button_text = "关闭"
	dialog.min_size = Vector2i(420, 240)
	add_child(dialog)
	dialog.popup_centered(Vector2i(420, 240))

func _sell_selected_slot() -> void:
	if _selected_slot < 0 or _selected_slot >= ps.board.size() or ps.board[_selected_slot] == null:
		_cancel_selection()
		return
	var name := String(ps.board[_selected_slot].get("n", "随从"))
	var was_contract := bool(ps.board[_selected_slot].get("_contract", false))
	if ps.sell(_selected_slot):
		if was_contract:
			_clear_contract()
		_say("卖出 %s（+2金）" % name)
	_cancel_selection()

func _toggle_contract_selected_slot() -> void:
	if _selected_slot < 0 or _selected_slot >= ps.board.size() or ps.board[_selected_slot] == null:
		return
	_set_contract_slot(_selected_slot)

func _set_contract_slot(slot: int, announce: bool = true) -> bool:
	if slot < 0 or slot >= ps.board.size() or ps.board[slot] == null:
		if announce:
			_say("契印失败：槽位没有随从")
		return false
	var card: Dictionary = ps.board[slot]
	if String(card.get("race", "")) != "sacrifice":
		if announce:
			_say("只有献祭随从可以作为契印目标")
		return false
	if _contract_slot == slot and bool(card.get("_contract", false)):
		_clear_contract()
		if announce:
			_say("契印槽已清空")
		_update_selection_bar()
		_refresh()
		return true
	_clear_contract()
	card["_contract"] = true
	_contract_slot = slot
	ps.contract_bonus = ps.contract_bonus_for_board()
	_sigil_bind_fx(slot)
	if announce:
		_say("契印：%s" % String(card.get("n", "献祭随从")))
	_update_selection_bar()
	_update_sigil_slot()
	_refresh()
	return true

func _clear_contract() -> void:
	for card in ps.board:
		if card != null:
			card.erase("_contract")
	_contract_slot = -1
	ps.contract_id = -1
	ps.contract_bonus = 0

func _find_contract_slot() -> int:
	for i in range(ps.board.size()):
		var card = ps.board[i]
		if card != null and bool(card.get("_contract", false)):
			return i
	return -1

## ---------- 战斗与回合 ----------

func _fight() -> void:
	if _busy or _game_over:
		return
	_busy = true
	for button in _action_buttons:
		button.disabled = true
	_prep_left = PREP_SECONDS
	var contract_slot := _find_contract_slot()
	var contract_uid := _unit_uid_for_slot(ps.board, contract_slot)
	var prep: Dictionary = ps.prepare_fusion(ps.mech_level, ps.mag_t, ps.mech_repair)
	var eprep: Dictionary = ep.prepare_fusion(ep.mech_level, ep.mag_t, ep.mech_repair)
	if bool(prep.get("ok", false)):
		_play_sfx("mech_fuse")
	if bool(eprep.get("ok", false)):
		_play_sfx("mech_fuse")
	var p_board := _to_units(ps.board, 1)
	var e_board := _to_units(ep.board, 101)
	var p_display := _display_board(p_board)
	var e_display := _display_board(e_board)
	var names := {}
	for u in p_board:
		if u != null:
			names[u.uid] = u.card_name
	for u in e_board:
		if u != null:
			names[u.uid] = u.card_name
	ps.contract_id = contract_uid
	var seed_value: int = _game_seed + ps.round_no * 7919
	var opts: Dictionary = ps.battle_options("p")
	opts.merge(ep.battle_options("e"), true)
	opts["round"] = ps.round_no
	ps.contract_id = -1
	var r: Dictionary = BattleScript.new().resolve(p_board, e_board, seed_value, 50, opts)
	ps.sync_runtime_from_units(r.get("p_board", []), 1)
	ep.sync_runtime_from_units(r.get("e_board", []), 101)
	ps.apply_quest_stats(r.get("quest_stats_p", {}))
	ep.apply_quest_stats(r.get("quest_stats_e", {}))
	ps.debt = int(r.get("debt_p", ps.debt))
	ps.chain = int(r.get("chain_p", ps.chain))
	ps.star_amp = int(r.get("amp_p", ps.star_amp))
	ps.mech_repair = int(r.get("armor_p", ps.mech_repair))
	ps.dragon_layer = int(r.get("dragon_layer_p", ps.dragon_layer))
	ps.undead_tick = int(r.get("undead_tick_p", ps.undead_tick))
	ps.prev_death_tick = int(r.get("death_delta_p", ps.prev_death_tick))
	ep.dragon_layer = int(r.get("dragon_layer_e", ep.dragon_layer))
	ep.undead_tick = int(r.get("undead_tick_e", ep.undead_tick))
	ep.prev_death_tick = int(r.get("death_delta_e", ep.prev_death_tick))
	var p_fusion_alive: bool = bool(prep.get("ok", false)) and _fusion_alive(r.get("p_board", []), int(prep.get("index", -1)))
	var e_fusion_alive: bool = bool(eprep.get("ok", false)) and _fusion_alive(r.get("e_board", []), int(eprep.get("index", -1)))
	if bool(prep.get("ok", false)):
		ps.finish_fusion(p_fusion_alive)
	if bool(eprep.get("ok", false)):
		ep.finish_fusion(e_fusion_alive)
	ps.restore_battlecry_dead(ep.board)
	ep.restore_battlecry_dead(ps.board)
	var winner := String(r.get("winner", "draw"))
	var p_alive: int = int(r.get("p_alive", 0))
	var e_alive: int = int(r.get("e_alive", 0))
	var p_loss := 0
	var e_loss := 0
	if winner == "p":
		e_loss = _alive_star_total(r.get("p_board", []))
		e_hp -= e_loss
		ps.win_streak += 1
		ps.lose_streak = 0
		ep.lose_streak += 1
		ep.win_streak = 0
	elif winner == "e":
		p_loss = _alive_star_total(r.get("e_board", []))
		p_hp -= p_loss
		ps.lose_streak += 1
		ps.win_streak = 0
		ep.win_streak += 1
		ep.lose_streak = 0
	else:
		ps.win_streak = 0
		ps.lose_streak = 0
		ep.win_streak = 0
		ep.lose_streak = 0
	var outcome := "平局"
	if winner == "p":
		outcome = "胜利"
	elif winner == "e":
		outcome = "失败"
	_say("开打：%s（我方存活%d / AI存活%d，伤害%d%s）%s" % [
		outcome, p_alive, e_alive, e_loss if winner == "p" else p_loss,
		"（AI扣血）" if winner == "p" else ("（我方扣血）" if winner == "e" else ""),
		"，机械战神已合体" if bool(prep.get("ok", false)) or bool(eprep.get("ok", false)) else ""])
	await _play_battle(r["events"], p_display, e_display, names)
	ps.apply_quest_stats(r.get("quest_stats_p", {}))
	ep.apply_quest_stats(r.get("quest_stats_e", {}))
	var p_quest_ok := bool(r.get("quest_ok_p", false))
	var e_quest_ok := bool(r.get("quest_ok_e", false))
	var p_reward_targets: Array[Dictionary] = []
	var e_reward_targets: Array[Dictionary] = []
	if int(r.get("quest_reward_ticks_p", 0)) > 0:
		p_reward_targets = ps.apply_quest_reward(p_quest_ok)
	if int(r.get("quest_reward_ticks_e", 0)) > 0:
		e_reward_targets = ep.apply_quest_reward(e_quest_ok)
	# 切回持久备战棋盘后再播放宣言奖励，不在战斗尸体上结算。
	_refresh()
	await _play_quest_reward_prep("p", p_reward_targets, p_quest_ok)
	await _play_quest_reward_prep("e", e_reward_targets, e_quest_ok)
	_busy = false
	if p_hp <= 0 or e_hp <= 0:
		p_hp = maxi(p_hp, 0)
		e_hp = maxi(e_hp, 0)
		_game_over = true
		_refresh()
		await _play_game_over_celebration(e_hp <= 0 and p_hp > 0)
		return
	_advance_round()
	_refresh()

func _display_board(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if u == null:
			out.append(null)
		else:
			var card: Dictionary = u.source_card
			out.append({
				"_uid": int(u.uid),
				"n": String(u.card_name),
				"a": int(u.atk),
				"h": int(u.hp),
				"mh": int(u.max_hp),
				"s": int(u.star),
				"race": String(u.race),
				"k": "".join(PackedStringArray(u.keywords)),
				"part": String(u.part),
				"g": bool(u.gold_card),
				"evo": int(u.evo),
				"vd": int(u.vd),
				"vc": int(u.vc),
				"gene": int(u.gene),
				"charge": int(u.charge),
				"charge_max": int(u.charge_max),
				"battle_armor": int(u.battle_armor),
				"follow_type": String(u.follow_type),
				"mech_body": bool(u.mech_body),
				"material": bool(card.get("material", false)),
				"support": String(card.get("support", "")),
				"modGrow": int(card.get("modGrow", 0)),
				"modAtk": int(card.get("modAtk", 0)),
				"modDmg": int(card.get("modDmg", 0)),
				"modShield": int(card.get("modShield", 0)),
				"headDouble": bool(card.get("headDouble", false)),
				"need": int(card.get("sk", {}).get("need", 0)),
				"_devourReady": bool(card.get("_devourReady", false)),
			})
	while out.size() < 7:
		out.append(null)
	return out

func _play_game_over_celebration(player_won: bool) -> void:
	var winner_avatar: Control = _p_avatar if player_won else _e_avatar
	var loser_avatar: Control = _e_avatar if player_won else _p_avatar
	if winner_avatar != null and is_instance_valid(winner_avatar):
		winner_avatar.pivot_offset = winner_avatar.size * 0.5
		var win_tween := create_tween()
		win_tween.set_parallel(true)
		win_tween.tween_property(winner_avatar, "scale", Vector2(1.16, 1.16),
			maxf(0.08, 0.22 / maxf(1.0, _speed))).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		win_tween.tween_property(winner_avatar, "modulate", Color("ffe59a"),
			maxf(0.08, 0.22 / maxf(1.0, _speed)))
		win_tween.chain().tween_property(winner_avatar, "scale", Vector2.ONE,
			maxf(0.08, 0.18 / maxf(1.0, _speed)))
		win_tween.parallel().tween_property(winner_avatar, "modulate", Color.WHITE,
			maxf(0.08, 0.18 / maxf(1.0, _speed)))
	await _play_hero_burst(loser_avatar)
	_show_game_over_banner(player_won)

func _play_hero_burst(avatar: Control) -> void:
	if avatar == null or not is_instance_valid(avatar) or not avatar.is_inside_tree():
		return
	_battle_fx_trace.append("hero_burst_fx")
	_play_sfx("death")
	var burst := HeroBurstFx.new()
	burst.name = "hero_burst_fx"
	burst.color = Color("ff5a4f")
	burst.z_index = 180
	var pad := Vector2(44, 44)
	burst.position = avatar.global_position - pad
	burst.size = avatar.size + pad * 2.0
	add_child(burst)
	avatar.pivot_offset = avatar.size * 0.5
	var hide_tween := create_tween()
	hide_tween.set_parallel(true)
	hide_tween.tween_property(avatar, "scale", Vector2(0.16, 0.16),
		maxf(0.10, 0.42 / maxf(1.0, _speed))).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	hide_tween.tween_property(avatar, "modulate:a", 0.0,
		maxf(0.10, 0.42 / maxf(1.0, _speed)))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "progress", 1.0, maxf(0.12, 0.72 / maxf(1.0, _speed)))
	tween.tween_property(burst, "modulate:a", 0.0, maxf(0.12, 0.72 / maxf(1.0, _speed)))
	await _battle_wait(0.80)
	if is_instance_valid(burst):
		burst.queue_free()

func _show_game_over_banner(player_won: bool) -> void:
	var layer := CenterContainer.new()
	layer.name = "game_over_banner"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 190
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var label := Label.new()
	label.text = "胜利！" if player_won else "AI 胜利"
	label.add_theme_font_override("font", UiTheme.cjk_font_bold())
	label.add_theme_font_size_override("font_size", 44 if player_won else 32)
	label.add_theme_color_override("font_color", C_GOLD if player_won else Color("d6d0ff"))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color("1a1a2e"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.65, 0.65)
	label.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, maxf(0.08, 0.20 / maxf(1.0, _speed)))
	tween.tween_property(label, "scale", Vector2.ONE, maxf(0.10, 0.28 / maxf(1.0, _speed))) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(maxf(0.25, 0.75 / maxf(1.0, _speed)))
	tween.chain().tween_property(label, "modulate:a", 0.0, maxf(0.1, 0.25 / maxf(1.0, _speed)))
	tween.chain().tween_callback(layer.queue_free)

func _fusion_alive(board: Array, index: int) -> bool:
	if index < 0 or index >= board.size():
		return false
	var body = board[index]
	return body != null and bool(body.alive)

func _play_battle(events: Array, p_display: Array, e_display: Array, names: Dictionary) -> void:
	var by_uid := {}
	_battle_fx_trace.clear()
	while p_display.size() < 7:
		p_display.append(null)
	while e_display.size() < 7:
		e_display.append(null)
	var quest_initial_p: Array = p_display.duplicate(true)
	var quest_initial_e: Array = e_display.duplicate(true)
	_battle_p_board = p_display
	_battle_e_board = e_display
	for card in p_display:
		if card != null:
			by_uid[int(card.get("_uid", -1))] = card
	for card in e_display:
		if card != null:
			by_uid[int(card.get("_uid", -1))] = card
	for i in range(p_display.size()):
		if p_display[i] != null:
			p_display[i]["_side"] = "p"
			p_display[i]["_slot"] = i
	for i in range(e_display.size()):
		if e_display[i] != null:
			e_display[i]["_side"] = "e"
			e_display[i]["_slot"] = i
	var quest_processed: Array = []
	var debt_lord_fx_played := false
	_refresh_live_quest_progress(quest_processed, quest_initial_p, quest_initial_e)
	for ev_index in range(events.size()):
		var ev: Dictionary = events[ev_index]
		quest_processed.append(ev)
		var kind := String(ev.get("t", ""))
		var burst_scale := _event_burst_scale(events, ev_index, kind, ev)
		var line := _battle_event_line(ev, names)
		if line != "":
			_say(line)
		match kind:
			"attack":
				if int(ev.get("chain_bonus", 0)) > 0:
					_play_sfx("star_chain_bonus")
					_battle_fx_trace.append("star_chain_bonus_fx")
				if int(ev.get("follow", 0)) != 0:
					_play_sfx("mech_follow")
					_battle_fx_trace.append("mech_follow_fx")
				var attack_tween := _battle_animate_attack(ev, by_uid, false)
				if attack_tween != null:
					await attack_tween.finished
			"hero_attack":
				await _battle_animate_hero_attack(
					int(ev.get("id", -1)),
					String(ev.get("side", "p")),
					by_uid,
					int(ev.get("star", 1)))
			"damage":
				var damaged_uid := int(ev.get("dst", -1))
				# 星灵回响没有独立的 attack 事件，需要在这里补一段来源冲刺。
				# 机械协同攻击已经在前一条 attack 事件里处理，不能再重复冲刺。
				if int(ev.get("echo", 0)) != 0:
					_play_sfx("star_echo")
					_battle_fx_trace.append("star_echo_fx")
					var echo_tween := _battle_animate_attack(ev, by_uid, true)
					if echo_tween != null:
						await echo_tween.finished
				if by_uid.has(damaged_uid):
					var damaged: Dictionary = by_uid[damaged_uid]
					damaged["h"] = int(ev.get("hp", 0))
					_refresh_battle_uid(damaged_uid, by_uid)
					await get_tree().process_frame
					_show_battle_float(ev, by_uid)
				var hit_tween := _battle_animate_hit(damaged_uid, by_uid, burst_scale)
				if hit_tween != null:
					await hit_tween.finished
				# Web 版每个 m/h 命中步末尾 await 500ms；attack 与 damage 在
				# Godot 是两条事件，但这里只保留这一处停顿，避免节奏翻倍。
				await _battle_wait(0.50 / burst_scale)
			"poison":
				var poisoned_uid := int(ev.get("dst", -1))
				_show_battle_float(ev, by_uid)
				var poison_tween := _battle_animate_hit(poisoned_uid, by_uid, burst_scale)
				if poison_tween != null:
					await poison_tween.finished
				await _battle_wait(0.50 / burst_scale)
			"death":
				var dead_uid := int(ev.get("id", -1))
				_battle_fx_trace.append("death_fx")
				_show_battle_float(ev, by_uid)
				if by_uid.has(dead_uid) and bool(by_uid[dead_uid].get("_contract", false)):
					_battle_sacrifice_offer_fx(dead_uid, 0, by_uid)
				await _battle_animate_death(dead_uid, by_uid, burst_scale)
			"buff":
				var buffed_uid := int(ev.get("id", -1))
				if by_uid.has(buffed_uid):
					var buffed: Dictionary = by_uid[buffed_uid]
					buffed["a"] = int(buffed.get("a", 0)) + int(ev.get("a", 0))
					buffed["h"] = int(buffed.get("h", 0)) + int(ev.get("h", 0))
					buffed["mh"] = int(buffed.get("mh", 0)) + maxi(0, int(ev.get("h", 0)))
					_refresh_battle_uid(buffed_uid, by_uid)
					await get_tree().process_frame
					match str(ev.get("source", "")):
						"dragon-aura", "dragon-aura-minor":
							_play_sfx("dragon_aura")
							_battle_fx_trace.append("dragon_aura_fx")
						"dragon-attack":
							_play_sfx("dragon_attack")
							_battle_fx_trace.append("dragon_attack_fx")
						"atk-react":
							_play_sfx("dragon_react")
							_battle_fx_trace.append("dragon_react_fx")
						"growth-self":
							_play_sfx("dragon_growth")
							_battle_fx_trace.append("dragon_growth_fx")
						"undead-death":
							_play_sfx("undead_death")
							_battle_fx_trace.append("undead_death_fx")
						"spell-cast":
							_play_sfx("element_cast")
							_battle_fx_trace.append("element_cast_fx")
						"vampire-on-dmg":
							_play_sfx("vampire_heal")
							_battle_fx_trace.append("vampire_on_dmg_fx")
						"demon-on-dmg":
							_play_sfx("demon_rage")
							_battle_fx_trace.append("demon_on_dmg_fx")
						"neutral-buff":
							_play_sfx("neutral_buff")
							_battle_fx_trace.append("neutral_buff_fx")
					_show_battle_float(ev, by_uid)
					var buff_style := MechanicStyle.event_style(ev, buffed)
					var support_source := _battle_infer_source_uid(ev, buffed_uid, by_uid)
					var debt_gain := str(ev.get("source", "")) in [
						"debt-payoff", "debt-totem", "debt-battery", "debt-lord",
					]
					if not debt_gain and support_source >= 0 and support_source != buffed_uid:
						await _battle_animate_support_path(
							support_source, buffed_uid, by_uid,
							Color(buff_style.get("color", C_BLUE)))
					if str(ev.get("source", "")) == "debt-lord" and not debt_lord_fx_played:
						debt_lord_fx_played = true
						var lord_fx := _battle_sacrifice_payoff_fx(
							support_source, 0, by_uid, 2,
							"债务领主 · 全献祭 +%d/+%d" % [
								int(ev.get("a", 0)), int(ev.get("h", 0))],
							"debt_lord_fx")
						if lord_fx != null:
							_battle_fx_trace.append("debt_lord_fx")
					await _battle_pulse(buffed_uid, by_uid,
						Color(buff_style.get("color", C_BLUE)), 1.04, burst_scale)
			"heal":
				var healed_uid := int(ev.get("id", -1))
				if by_uid.has(healed_uid):
					var healed: Dictionary = by_uid[healed_uid]
					healed["h"] = mini(int(healed.get("mh", healed.get("h", 0))),
						int(healed.get("h", 0)) + int(ev.get("val", 0)))
					_refresh_battle_uid(healed_uid, by_uid)
					await get_tree().process_frame
					if String(healed.get("race", "")) == "vampire":
						_play_sfx("vampire_heal")
						_battle_fx_trace.append("vampire_heal_fx")
					_show_battle_float(ev, by_uid)
					var heal_style := MechanicStyle.event_style(ev, healed)
					var heal_source := _battle_infer_source_uid(ev, healed_uid, by_uid)
					if heal_source >= 0 and heal_source != healed_uid:
						await _battle_animate_support_path(
							heal_source, healed_uid, by_uid,
							Color(heal_style.get("color", C_HP)))
					await _battle_pulse(healed_uid, by_uid,
						Color(heal_style.get("color", C_HP)), 1.04, burst_scale)
			"shield_break":
				var shield_uid := int(ev.get("id", -1))
				if by_uid.has(shield_uid):
					var shielded: Dictionary = by_uid[shield_uid]
					shielded["shield"] = false
					_refresh_battle_uid(shield_uid, by_uid)
					await get_tree().process_frame
					_show_battle_float(ev, by_uid)
					await _battle_pulse(shield_uid, by_uid, C_GOLD)
			"taunt_break":
				var taunt_uid := int(ev.get("id", -1))
				if by_uid.has(taunt_uid):
					var taunting: Dictionary = by_uid[taunt_uid]
					taunting["k"] = String(taunting.get("k", "")).replace("t", "")
					_refresh_battle_uid(taunt_uid, by_uid)
					await get_tree().process_frame
					await _battle_pulse(taunt_uid, by_uid, C_GOLD)
			"armor":
				_play_sfx("mech_armor")
				_battle_fx_trace.append("mech_armor_fx")
				_show_battle_float(ev, by_uid)
			"evop":
				var evo_uid := int(ev.get("id", -1))
				if by_uid.has(evo_uid):
					var evolving: Dictionary = by_uid[evo_uid]
					evolving["_evo"] = int(ev.get("evo", 0))
					_refresh_battle_uid(evo_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("evo_tick")
					_battle_fx_trace.append("evo_tick_fx")
					_show_battle_float(ev, by_uid)
					await _battle_pulse(evo_uid, by_uid, Color("7bed9f"))
			"evo_full":
				var full_uid := int(ev.get("id", -1))
				_play_sfx("evo_full")
				_battle_fx_trace.append("evo_full_fx")
				_show_battle_float(ev, by_uid)
				await _battle_pulse(full_uid, by_uid, C_GOLD, 1.12)
			"evolve":
				var evolved_uid := int(ev.get("id", -1))
				_play_sfx("evolve")
				_battle_fx_trace.append("evolve_fx")
				_show_battle_float(ev, by_uid)
				await _battle_pulse(evolved_uid, by_uid, C_GOLD, 1.08)
			"gene":
				var gene_uid := int(ev.get("id", -1))
				if by_uid.has(gene_uid):
					var gene_card: Dictionary = by_uid[gene_uid]
					gene_card["_gene"] = int(ev.get("gene", 0))
					_refresh_battle_uid(gene_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("gene")
					_battle_fx_trace.append("gene_fx")
					_show_battle_float(ev, by_uid)
					await _battle_pulse(gene_uid, by_uid, C_GOLD)
			"progress":
				var progress_uid := int(ev.get("id", -1))
				if by_uid.has(progress_uid):
					var progress_card: Dictionary = by_uid[progress_uid]
					progress_card["_pr"] = int(ev.get("progress", 0))
					_refresh_battle_uid(progress_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("progress")
					_battle_fx_trace.append("progress_fx")
					_show_battle_float(ev, by_uid)
					await _battle_pulse(progress_uid, by_uid, Color("7bed9f"))
			"progress_full":
				var progress_full_uid := int(ev.get("id", -1))
				_play_sfx("progress_full")
				_battle_fx_trace.append("progress_full_fx")
				_show_battle_float(ev, by_uid)
				await _battle_pulse(progress_full_uid, by_uid, C_GOLD, 1.12)
			"progress_hatch":
				var hatch_uid := int(ev.get("id", -1))
				if by_uid.has(hatch_uid):
					var hatch_card: Dictionary = by_uid[hatch_uid]
					hatch_card["n"] = String(ev.get("name", "混沌始祖"))
					hatch_card["a"] = int(ev.get("a", hatch_card.get("a", 0)))
					hatch_card["h"] = int(ev.get("h", hatch_card.get("h", 0)))
					hatch_card["mh"] = int(ev.get("h", hatch_card.get("mh", hatch_card.get("h", 0))))
					hatch_card["s"] = 7
					hatch_card["_pr"] = int(ev.get("layers", 5))
					hatch_card["_gene"] = int(ev.get("layers", 5))
					_refresh_battle_uid(hatch_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("progress_hatch")
					_battle_fx_trace.append("progress_hatch_fx")
					_show_battle_float(ev, by_uid)
					await _battle_pulse(hatch_uid, by_uid, C_GOLD, 1.18)
			"ch":
				var charge_uid := int(ev.get("id", -1))
				if by_uid.has(charge_uid):
					var charged: Dictionary = by_uid[charge_uid]
					charged["_charge"] = int(ev.get("c", 0))
					charged["charge_max"] = int(ev.get("cm", 0))
					_refresh_battle_uid(charge_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("mech_charge")
					_battle_fx_trace.append("mech_charge_fx")
					_show_battle_float(ev, by_uid)
					await _battle_pulse(charge_uid, by_uid, Color("74b9ff"))
			"guard":
				var guard_uid := int(ev.get("id", -1))
				if by_uid.has(guard_uid):
					var guard_card: Dictionary = by_uid[guard_uid]
					guard_card["shield"] = true
					guard_card["k"] = String(guard_card.get("k", "")) + "t"
					_refresh_battle_uid(guard_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("mech_guard")
					_battle_fx_trace.append("mech_guard_fx")
					_show_battle_float(ev, by_uid)
					await _battle_pulse(guard_uid, by_uid, C_BLUE, 1.10)
			"gamble":
				var gamble_uid := int(ev.get("id", -1))
				if by_uid.has(gamble_uid):
					_play_sfx("gamble")
					_battle_fx_trace.append("gamble_fx")
					_show_battle_float(ev, by_uid)
					await _battle_pulse(gamble_uid, by_uid, C_GOLD, 1.12)
			"summon":
				var summon_id := int(ev.get("id", -1))
				var summon_slot := int(ev.get("slot", -1))
				if summon_id >= 0 and summon_slot >= 0:
					var summoned: Dictionary = {
						"_uid": summon_id,
						"n": String(ev.get("name", "召唤物")),
						"a": int(ev.get("a", 0)),
						"h": int(ev.get("h", 0)),
						"mh": int(ev.get("h", 0)),
						"s": int(ev.get("s", 1)),
						"race": String(ev.get("race", "undead")),
						"_side": String(ev.get("side", "p")),
						"_slot": summon_slot,
					}
					by_uid[summon_id] = summoned
					_refresh_battle_uid(summon_id, by_uid)
					await get_tree().process_frame
					_play_sfx("summon")
					_battle_fx_trace.append("summon_fx")
					_show_battle_float(ev, by_uid)
					var summon_style := MechanicStyle.event_style(ev, summoned)
					await _battle_pulse(summon_id, by_uid,
						Color(summon_style.get("color", Color("74b9ff"))), 1.10)
			"rebirth":
				var rebirth_uid := int(ev.get("id", -1))
				if by_uid.has(rebirth_uid):
					var rebirth_card: Dictionary = by_uid[rebirth_uid]
					rebirth_card["h"] = int(rebirth_card.get("mh", rebirth_card.get("h", 0)))
					rebirth_card["a"] = int(rebirth_card.get("a", 0)) + int(ev.get("a", 0))
					rebirth_card["h"] = int(rebirth_card.get("h", 0)) + int(ev.get("h", 0))
					_refresh_battle_uid(rebirth_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("rebirth")
					_battle_fx_trace.append("rebirth_fx")
					_show_battle_float(ev, by_uid)
					var rebirth_style := MechanicStyle.event_style(ev, rebirth_card)
					await _battle_pulse(rebirth_uid, by_uid,
						Color(rebirth_style.get("color", C_HP)), 1.16)
			"chain":
				var chain_uid := int(ev.get("id", -1))
				if by_uid.has(chain_uid):
					var chain_card: Dictionary = by_uid[chain_uid]
					chain_card["_chain"] = int(ev.get("value", 0))
					_refresh_battle_uid(chain_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("star_chain")
					_battle_fx_trace.append("star_chain_fx")
					_show_battle_float(ev, by_uid)
					var chain_style := MechanicStyle.event_style(ev, chain_card)
					await _battle_pulse(chain_uid, by_uid,
						Color(chain_style.get("color", C_GOLD)), 1.08)
			"amp":
				var amp_uid := int(ev.get("id", -1))
				if by_uid.has(amp_uid):
					var amp_card: Dictionary = by_uid[amp_uid]
					amp_card["_chain"] = int(ev.get("chain", 0))
					amp_card["_starAmp"] = int(ev.get("amp", 0))
					_refresh_battle_uid(amp_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("star_amp")
					_battle_fx_trace.append("star_amp_fx")
					_show_battle_float(ev, by_uid)
					var amp_style := MechanicStyle.event_style(ev, amp_card)
					await _battle_pulse(amp_uid, by_uid,
						Color(amp_style.get("color", C_GOLD)), 1.12)
			"contract":
				var contract_uid := int(ev.get("id", -1))
				if by_uid.has(contract_uid):
					var contract_card: Dictionary = by_uid[contract_uid]
					contract_card["_contract"] = true
					_refresh_battle_uid(contract_uid, by_uid)
					await get_tree().process_frame
					_play_sfx("contract")
					_battle_contract_mark_fx(contract_uid, by_uid)
					_battle_fx_trace.append("contract_mark_fx")
					_show_battle_float(ev, by_uid)
					await _battle_pulse(contract_uid, by_uid, Color("a29bfe"), 1.06)
			"debt":
				_play_sfx("debt")
				_apply_battle_debt_state(ev, by_uid)
				await get_tree().process_frame
				var debt_source_uid := int(ev.get("src", -1))
				if String(ev.get("reason", "")) == "contract_death":
					_battle_sacrifice_offer_fx(debt_source_uid, int(ev.get("delta", 0)), by_uid)
					_battle_debt_cast_fx(debt_source_uid, by_uid, int(ev.get("tier", 0)))
					_battle_fx_trace.append("sacrifice_offer_fx")
					_battle_fx_trace.append("debt_cast_fx")
				_show_battle_float(ev, by_uid)
				if by_uid.has(debt_source_uid):
					await _battle_pulse(debt_source_uid, by_uid, Color("a29bfe"), 1.04)
			"debt_settle":
				_play_sfx("debt_settle")
				_apply_battle_debt_state(ev, by_uid)
				await get_tree().process_frame
				var settle_source := int(ev.get("src", -1))
				_battle_sacrifice_payoff_fx(settle_source, int(ev.get("need", 0)), by_uid,
					int(ev.get("tier", -1)))
				_battle_fx_trace.append("debt_payoff_fx")
				await _battle_wait(1.12)
			"quest_reward":
				var complete := bool(ev.get("ok", false))
				_play_sfx("evo_full" if complete else "evo_tick")
				_battle_fx_trace.append("quest_reward_fx" if complete else "quest_fail_fx")
				_show_quest_reward_banner(complete, int(ev.get("ticks", 1)))
				await _battle_wait(0.30)
		if kind in ["damage", "death", "summon"]:
			_refresh_live_quest_progress(quest_processed, quest_initial_p, quest_initial_e)
		_battle_frames += 1
		await _battle_wait(0.035 / burst_scale)


func _refresh_live_quest_progress(events: Array, initial_p: Array, initial_e: Array) -> void:
	if _board_has_race(ps.board, "evolve"):
		ps.apply_quest_stats(Quest.evaluate(events, "p", initial_p, initial_e, _battle_p_board))
	if _board_has_race(ep.board, "evolve"):
		ep.apply_quest_stats(Quest.evaluate(events, "e", initial_e, initial_p, _battle_e_board))
	_update_quest_visual()


func _show_quest_reward_banner(complete: bool, ticks: int) -> void:
	var layer := CenterContainer.new()
	layer.name = "quest_reward_banner"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 120
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var panel := PanelContainer.new()
	var color: Color = C_GOLD if complete else Color("7bed9f")
	panel.add_theme_stylebox_override("panel", _sb(Color("16213e"), color, 10, 8))
	layer.add_child(panel)
	var label := Label.new()
	label.text = "宣言达成 · 全进化 +%d格" % ticks if complete \
		else "宣言未达成 · 全进化 +%d格" % ticks
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_font_override("font", UiTheme.cjk_font_bold())
	label.add_theme_color_override("font_color", color)
	panel.add_child(label)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.82, 0.82)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.42)
	tween.chain().tween_property(panel, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(layer.queue_free)


func _apply_battle_debt_state(ev: Dictionary, by_uid: Dictionary) -> void:
	var side := String(ev.get("side", "p"))
	var debt := int(ev.get("debt", 0))
	for uid_value in by_uid.keys():
		var uid := int(uid_value)
		var card: Dictionary = by_uid[uid]
		if bool(card.get("_dead", false)):
			continue
		if String(card.get("_side", "p")) != side or String(card.get("race", "")) != "sacrifice":
			continue
		card["_debt"] = debt
		_refresh_battle_uid(uid, by_uid)

func _row_for_side(side: String) -> HBoxContainer:
	return _p_row if side == "p" else _ai_row

func _battle_wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.004, seconds / maxf(1.0, _speed))).timeout

func _event_burst_scale(events: Array, index: int, kind: String,
		current: Dictionary = {}) -> float:
	if kind == "":
		return 1.0
	var run := 1
	var cursor := index + 1
	while cursor < events.size():
		var next_event: Dictionary = events[cursor]
		if String(next_event.get("t", "")) != kind:
			break
		run += 1
		cursor += 1
	var scale := 1.0
	if run >= 2:
		scale = maxf(1.5, minf(2.4, 1.3 + float(run) * 0.12))
	# 苦痛侍僧这类 dmg-allies 的直伤会与死亡事件交错。
	if kind == "damage" and bool(current.get("direct", false)):
		scale = maxf(scale, 1.5)
	if kind == "death":
		var prev_direct := false
		var next_direct := false
		if index > 0:
			var prev_event: Dictionary = events[index - 1]
			prev_direct = String(prev_event.get("t", "")) == "damage" \
				and bool(prev_event.get("direct", false))
		if index + 1 < events.size():
			var next_event: Dictionary = events[index + 1]
			next_direct = String(next_event.get("t", "")) == "damage" \
				and bool(next_event.get("direct", false))
		if prev_direct or next_direct:
			scale = maxf(scale, 1.5)
	return scale

func _refresh_battle_uid(uid: int, by_uid: Dictionary) -> Control:
	if not by_uid.has(uid):
		return null
	var card: Dictionary = by_uid[uid]
	var side := String(card.get("_side", "p"))
	var row := _row_for_side(side)
	var index := int(card.get("_slot", -1))
	if row == null or index < 0 or index >= row.get_child_count():
		return null
	var board: Array = _battle_p_board if side == "p" else _battle_e_board
	if index >= board.size():
		return null
	var slot := row.get_child(index) as DropSlot
	if slot == null:
		return null
	if bool(card.get("_dead", false)):
		return slot
	board[index] = card
	if slot.find_child("name_label", true, false) == null:
		_populate_board_slot(slot, index, card, side == "p", _board_has_mech(board))
	else:
		_update_battle_slot_in_place(slot, index, card, side == "p")
	return slot

func _clear_battle_card(uid: int, by_uid: Dictionary) -> void:
	if not by_uid.has(uid):
		return
	var card: Dictionary = by_uid[uid]
	var side := String(card.get("_side", "p"))
	var row := _row_for_side(side)
	var index := int(card.get("_slot", -1))
	if row == null or index < 0 or index >= row.get_child_count():
		return
	var board: Array = _battle_p_board if side == "p" else _battle_e_board
	if index < board.size():
		board[index] = null
	var slot := row.get_child(index) as DropSlot
	if slot != null:
		_populate_board_slot(slot, index, null, side == "p", _board_has_mech(board))

func _update_battle_slot_in_place(slot: DropSlot, index: int, data: Dictionary, is_mine: bool) -> void:
	if slot == null or data == null:
		return
	var board: Array = _battle_p_board if is_mine else _battle_e_board
	var has_mech: bool = _board_has_mech(board)
	var zone_ready: bool = is_mine and ps.has_formation()
	slot.slot = index
	slot.is_mine = is_mine
	slot.zone = is_mine and has_mech and index < ZONE_SLOTS
	slot.zone_ready = zone_ready
	var bg := C_SLOT_FILL
	slot.add_theme_stylebox_override("panel", _sb(bg, bg, 0))

	var star := slot.find_child("card_star", true, false) as Label
	if star != null:
		star.text = "⭐".repeat(clampi(int(data.get("s", data.get("star", 1))), 1, 7))
	var nm := slot.find_child("name_label", true, false) as Label
	var state = ps if is_mine else ep
	if nm != null:
		nm.text = String(data.get("n", "?"))
		nm.add_theme_color_override("font_color", C_GOLD if bool(data.get("g", false)) else C_NAME)
	var atk := slot.find_child("stat_atk", true, false) as Label
	if atk != null:
		atk.text = str(int(data.get("a", 0)))
	var hp := slot.find_child("stat_hp", true, false) as Label
	if hp != null:
		hp.text = str(int(data.get("h", 0)))
	var badge_line := slot.find_child("badge_line", true, false) as HFlowContainer
	if badge_line != null:
		_fill_badge_line(badge_line, data, state, index)

	var decor := _find_slot_decor(slot)
	if decor != null:
		decor.zone = slot.zone
		decor.zone_ready = slot.zone_ready
		decor.has_card = true
		decor.is_gold = bool(data.get("g", false))
		decor.is_taunt = String(data.get("k", "")).contains("t")
		decor.is_shield = String(data.get("k", "")).contains("d") and bool(data.get("shield", true))
		decor.is_dead = bool(data.get("_dead", false))
		decor.is_contract = is_mine and bool(data.get("_contract", false))
		decor.hp_ratio = clampf(float(data.get("h", 1)) / maxf(1.0, float(data.get("mh", data.get("h", 1)))), 0.0, 1.0)
		decor.queue_redraw()
	slot.tooltip_text = ""
	_make_card_children_passive(slot)
	if bool(data.get("_dead", false)):
		slot.modulate = Color(1.0, 1.0, 1.0, 0.28)
		slot.pivot_offset = slot.custom_minimum_size * 0.5
		slot.scale = Vector2(0.84, 0.84)

func _battle_slot_for_uid(uid: int, by_uid: Dictionary) -> Control:
	if not by_uid.has(uid):
		return null
	var card: Dictionary = by_uid[uid]
	var row := _row_for_side(String(card.get("_side", "p")))
	return _child_or_null(row, int(card.get("_slot", -1)))

func _battle_animate_attack(ev: Dictionary, by_uid: Dictionary, _reaction: bool) -> Tween:
	var src_uid := int(ev.get("src", -1))
	var source := _battle_slot_for_uid(src_uid, by_uid)
	if source == null:
		return null
	var target := _battle_slot_for_uid(int(ev.get("dst", -1)), by_uid)
	if target != null:
		var path_style: Dictionary = MechanicStyle.family_style("neutral")
		if by_uid.has(src_uid):
			path_style = MechanicStyle.family_style(
				String(Dictionary(by_uid[src_uid]).get("race", "neutral")))
		var path_color := Color(path_style.get("color", C_GOLD))
		if int(ev.get("chain_bonus", 0)) > 0:
			path_color = Color(MechanicStyle.family_style("star").get("accent", C_GOLD))
		var path_fx := BattlePathFx.new()
		path_fx.name = "attack_path_fx"
		path_fx.from_rect = Rect2(source.global_position, source.size)
		path_fx.to_rect = Rect2(target.global_position, target.size)
		path_fx.color = path_color
		add_child(path_fx)
		path_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_battle_fx_trace.append("attack_path_fx")
		var path_duration := maxf(0.04, 0.22 / maxf(1.0, _speed))
		var path_tween := create_tween()
		path_tween.set_parallel(true)
		path_tween.tween_property(path_fx, "progress", 1.0, path_duration)
		path_tween.tween_property(path_fx, "modulate:a", 0.0, path_duration)
		path_tween.chain().tween_callback(path_fx.queue_free)
	var start: Vector2 = source.position
	# Web 版攻击方不是朝目标做对角线冲刺，而是 translateY(-4px) + scale(1.02)，持续 120ms。
	var offset := Vector2(0.0, -4.0)
	var duration := maxf(0.012, 0.12 / maxf(1.0, _speed))
	source.set_meta("battle_attack", true)
	var tween := create_tween()
	tween.tween_property(source, "position", start + offset, duration)
	tween.parallel().tween_property(source, "scale", Vector2(1.02, 1.02), duration)
	tween.tween_property(source, "position", start, duration)
	tween.parallel().tween_property(source, "scale", Vector2.ONE, duration)
	tween.finished.connect(func():
		if is_instance_valid(source):
			source.position = start
			source.scale = Vector2.ONE
			source.set_meta("battle_attack", false))
	return tween


func _battle_hero_hp_control(attacker_side: String) -> Control:
	var target_name := "ai_hp" if attacker_side == "p" else "p_hp"
	return find_child(target_name, true, false) as Control


func _battle_animate_hero_attack(uid: int, attacker_side: String, by_uid: Dictionary,
		star: int) -> void:
	var source := _battle_slot_for_uid(uid, by_uid)
	var target := _battle_hero_hp_control(attacker_side)
	if source == null or target == null:
		await _battle_wait(0.10)
		return
	var style: Dictionary = MechanicStyle.family_style("neutral")
	if by_uid.has(uid):
		style = MechanicStyle.family_style(String(Dictionary(by_uid[uid]).get("race", "neutral")))
	var path_color := Color(style.get("color", C_ATK))
	var path_fx := BattlePathFx.new()
	path_fx.name = "hero_attack_path_fx"
	path_fx.from_rect = Rect2(source.global_position, source.size)
	path_fx.to_rect = Rect2(target.global_position, target.size)
	path_fx.color = path_color
	add_child(path_fx)
	path_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_fx_trace.append("hero_attack_fx")
	var path_duration := maxf(0.04, 0.20 / maxf(1.0, _speed))
	var path_tween := create_tween()
	path_tween.set_parallel(true)
	path_tween.tween_property(path_fx, "progress", 1.0, path_duration)
	path_tween.tween_property(path_fx, "modulate:a", 0.0, path_duration)
	path_tween.chain().tween_callback(path_fx.queue_free)
	var start: Vector2 = source.position
	var duration := maxf(0.018, 0.14 / maxf(1.0, _speed))
	source.set_meta("battle_attack", true)
	var tween := create_tween()
	tween.tween_property(source, "position", start + Vector2(0.0, -6.0), duration)
	tween.parallel().tween_property(source, "scale", Vector2(1.03, 1.03), duration)
	tween.tween_property(source, "position", start, duration)
	tween.parallel().tween_property(source, "scale", Vector2.ONE, duration)
	tween.finished.connect(func():
		if is_instance_valid(source):
			source.position = start
			source.scale = Vector2.ONE
			source.set_meta("battle_attack", false))
	await tween.finished
	_show_hero_damage_float(target, star)
	await _battle_wait(0.16)


func _battle_infer_source_uid(ev: Dictionary, target_uid: int, by_uid: Dictionary) -> int:
	if int(ev.get("src", -1)) >= 0:
		return int(ev.get("src", -1))
	var source := str(ev.get("source", ev.get("reason", "")))
	if source == "":
		if bool(ev.get("gamble", false)):
			source = "gambler"
		else:
			return -1
	var self_sources: Array[String] = [
		"self-buff", "growth-self", "maxhp-buff", "evolve", "evolve-step",
		"evo-advance", "evo-devourer",
	]
	if self_sources.has(source):
		return target_uid
	var target_card: Dictionary = by_uid.get(target_uid, {})
	var target_side := String(target_card.get("_side", ""))
	var wanted_race := ""
	if source.contains("dragon") or source == "atk-react":
		wanted_race = "dragon"
	elif source.contains("vampire") or source in ["lifesteal", "race-heal", "heal-race", "maxhp-buff"]:
		wanted_race = "vampire"
	elif source.contains("undead") or source in ["summon", "rebirth", "death-race-buff"]:
		wanted_race = "undead"
	elif source.contains("mech") or source == "armor" or source == "mech_dmg":
		wanted_race = "mech"
	elif source.contains("star") or source in ["chain-dmg", "star-echo"]:
		wanted_race = "star"
	elif source.contains("elem") or source.contains("spell"):
		wanted_race = "elem"
	elif source.contains("gambl"):
		wanted_race = "gambler"
	elif source.contains("debt") or source in ["inherit", "contract", "debt-payoff", "debt-totem", "debt-battery"]:
		wanted_race = "sacrifice"
	elif source.contains("demon") or source == "multihit":
		wanted_race = "demon"
	if wanted_race == "":
		return -1
	var best_uid := -1
	var best_atk := -9999
	for uid_value in by_uid.keys():
		var uid := int(uid_value)
		if uid == target_uid:
			continue
		var card: Dictionary = by_uid[uid]
		if bool(card.get("_dead", false)) or String(card.get("race", "")) != wanted_race:
			continue
		if target_side != "" and String(card.get("_side", "")) != target_side:
			continue
		var atk := int(card.get("a", 0))
		if atk > best_atk:
			best_atk = atk
			best_uid = uid
	if best_uid < 0 and target_side != "":
		for uid_value in by_uid.keys():
			var uid := int(uid_value)
			var card: Dictionary = by_uid[uid]
			if bool(card.get("_dead", false)) or String(card.get("race", "")) != wanted_race:
				continue
			var atk := int(card.get("a", 0))
			if atk > best_atk:
				best_atk = atk
				best_uid = uid
	return best_uid


func _battle_animate_support_path(source_uid: int, target_uid: int, by_uid: Dictionary,
		color: Color) -> void:
	if source_uid < 0 or source_uid == target_uid:
		return
	var source := _battle_slot_for_uid(source_uid, by_uid)
	var target := _battle_slot_for_uid(target_uid, by_uid)
	if source == null or target == null:
		return
	await _battle_pulse(source_uid, by_uid, color, 1.06)
	var path_fx := BattlePathFx.new()
	path_fx.name = "support_path_fx"
	path_fx.from_rect = Rect2(source.global_position, source.size)
	path_fx.to_rect = Rect2(target.global_position, target.size)
	path_fx.color = color
	add_child(path_fx)
	path_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_fx_trace.append("support_path_fx")
	var duration := maxf(0.04, 0.20 / maxf(1.0, _speed))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(path_fx, "progress", 1.0, duration)
	tween.tween_property(path_fx, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(path_fx.queue_free)
	await tween.finished


func _show_hero_damage_float(target: Control, damage: int) -> void:
	var popup := Label.new()
	popup.name = "hero_damage_float"
	popup.text = "-%d" % damage
	popup.z_index = 95
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_font_override("font", UiTheme.cjk_font_bold())
	popup.add_theme_color_override("font_color", C_ATK)
	add_child(popup)
	popup.reset_size()
	popup.global_position = target.global_position + Vector2(
		target.size.x * 0.5 - popup.size.x * 0.5, -4.0)
	var tween := create_tween()
	tween.tween_property(popup, "position", popup.position + Vector2(0.0, -28.0), 0.48)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.48)
	tween.tween_callback(popup.queue_free)


func _battle_animate_hit(uid: int, by_uid: Dictionary, speed_scale: float = 1.0) -> Tween:
	var slot := _battle_slot_for_uid(uid, by_uid)
	if slot == null:
		return null
	_play_sfx("hit")
	var start: Vector2 = slot.position
	var old_panel: StyleBox = slot.get_theme_stylebox("panel")
	var hit_panel := _sb(Color("ff7675"), Color("d63031"), 0)
	hit_panel.set_border_width_all(2)
	if old_panel is StyleBoxFlat:
		var old_flat := old_panel as StyleBoxFlat
		hit_panel.content_margin_left = old_flat.content_margin_left
		hit_panel.content_margin_top = old_flat.content_margin_top
		hit_panel.content_margin_right = old_flat.content_margin_right
		hit_panel.content_margin_bottom = old_flat.content_margin_bottom
	slot.add_theme_stylebox_override("panel", hit_panel)
	slot.set_meta("battle_hit", true)
	var duration := maxf(0.012, 0.05 / (maxf(1.0, _speed) * maxf(1.0, speed_scale)))
	var tween := create_tween()
	tween.tween_property(slot, "position", start + Vector2(5.0, 0.0), duration)
	tween.tween_property(slot, "position", start - Vector2(3.0, 0.0), duration)
	tween.tween_property(slot, "position", start, duration)
	tween.finished.connect(func():
		if is_instance_valid(slot):
			slot.position = start
			if old_panel != null:
				slot.add_theme_stylebox_override("panel", old_panel)
			else:
				slot.remove_theme_stylebox_override("panel")
			slot.set_meta("battle_hit", false))
	return tween

func _battle_pulse(uid: int, by_uid: Dictionary, color: Color,
		scale_peak: float = 1.04, speed_scale: float = 1.0) -> void:
	var slot := _battle_slot_for_uid(uid, by_uid)
	if slot == null:
		return
	_battle_pulse_trace.append(color.to_html(false))
	slot.pivot_offset = slot.size * 0.5
	var duration := maxf(0.02, 0.075 / (maxf(1.0, _speed) * maxf(1.0, speed_scale)))
	var out_tween := create_tween()
	out_tween.set_parallel(true)
	out_tween.tween_property(slot, "self_modulate", color, duration)
	out_tween.tween_property(slot, "scale", Vector2.ONE * scale_peak, duration)
	await out_tween.finished
	var back_tween := create_tween()
	back_tween.set_parallel(true)
	back_tween.tween_property(slot, "self_modulate", Color.WHITE, duration)
	back_tween.tween_property(slot, "scale", Vector2.ONE, duration)
	await back_tween.finished

func _battle_contract_mark_fx(uid: int, by_uid: Dictionary) -> Control:
	var slot := _battle_slot_for_uid(uid, by_uid)
	if slot == null:
		return null
	var old_fx := slot.get_node_or_null("contract_mark_fx")
	if old_fx != null:
		old_fx.queue_free()
	var fx := SacrificeFxLayer.new()
	fx.name = "contract_mark_fx"
	fx.mode = "contract"
	fx.set_meta("fx_mode", "contract")
	slot.add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.name = "contract_label"
	label.text = "契印"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_font_override("font", UiTheme.cjk_font_bold())
	label.add_theme_color_override("font_color", Color("c7c0ff"))
	fx.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "progress", 1.0, maxf(0.08, 0.82 / maxf(1.0, _speed)))
	tween.tween_property(fx, "modulate:a", 0.0, maxf(0.08, 0.82 / maxf(1.0, _speed)))
	tween.chain().tween_callback(fx.queue_free)
	return fx

func _battle_sacrifice_offer_fx(uid: int, debt_delta: int, by_uid: Dictionary) -> Control:
	var slot := _battle_slot_for_uid(uid, by_uid)
	if slot == null:
		return null
	var fx := slot.get_node_or_null("sacrifice_offer_fx") as Control
	if fx == null:
		var created := SacrificeFxLayer.new()
		created.name = "sacrifice_offer_fx"
		created.mode = "offer"
		created.set_meta("fx_mode", "offer")
		created.set_meta("particle_count", 15)
		slot.add_child(created)
		created.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var label := Label.new()
		label.name = "offer_label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_font_override("font", UiTheme.cjk_font_bold())
		label.add_theme_color_override("font_color", Color("ffd166"))
		created.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(created, "progress", 1.0, maxf(0.1, 1.7 / maxf(1.0, _speed)))
		tween.tween_property(created, "modulate:a", 0.0, maxf(0.1, 1.7 / maxf(1.0, _speed)))
		tween.chain().tween_callback(created.queue_free)
		fx = created
	fx.set_meta("debt_delta", debt_delta)
	var label := fx.get_node_or_null("offer_label") as Label
	if label != null:
		label.text = "献祭成功 债务+%d" % debt_delta
	return fx

func _battle_debt_cast_fx(uid: int, by_uid: Dictionary, tier: int = 0) -> Control:
	var slot := _battle_slot_for_uid(uid, by_uid)
	if slot == null:
		return null
	var fx := SacrificeFxLayer.new()
	fx.name = "debt_cast_fx"
	fx.mode = "cast"
	fx.tier = clampi(tier, 0, 3)
	fx.set_meta("fx_mode", "cast")
	fx.set_meta("tier", fx.tier)
	slot.add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "progress", 1.0, maxf(0.06, 0.42 / maxf(1.0, _speed)))
	tween.tween_property(fx, "scale", Vector2(1.3, 1.3), maxf(0.06, 0.42 / maxf(1.0, _speed)))
	tween.tween_property(fx, "modulate:a", 0.0, maxf(0.06, 0.42 / maxf(1.0, _speed)))
	tween.chain().tween_callback(fx.queue_free)
	return fx

func _battle_sacrifice_payoff_fx(uid: int, need: int, by_uid: Dictionary, tier: int = -1,
		label_text: String = "", fx_name: String = "debt_payoff_fx") -> Control:
	var source := _battle_slot_for_uid(uid, by_uid)
	if source == null:
		return null
	var side := "p"
	if by_uid.has(uid):
		side = String(by_uid[uid].get("_side", "p"))
	var source_point := source.global_position + source.size * 0.5
	var center_y := 0.0
	if _p_row != null and _ai_row != null:
		center_y = (_ai_row.global_position.y + _ai_row.size.y + _p_row.global_position.y) * 0.5
	else:
		center_y = get_viewport_rect().size.y * 0.5
	var center_point := Vector2(get_viewport_rect().size.x * 0.5, center_y)
	var target_points: Array[Vector2] = []
	for uid_value in by_uid.keys():
		var target_uid := int(uid_value)
		var card: Dictionary = by_uid[target_uid]
		if String(card.get("_side", "p")) != side or String(card.get("race", "")) != "sacrifice":
			continue
		var target_slot := _battle_slot_for_uid(target_uid, by_uid)
		if target_slot == null:
			continue
		target_points.append(target_slot.global_position + target_slot.size * 0.5)
	var fx := SacrificeFxLayer.new()
	fx.name = fx_name
	fx.mode = "payoff"
	fx.tier = _debt_tier(need) if tier < 0 else clampi(tier, 0, 3)
	fx.source_point = source_point
	fx.center_point = center_point
	fx.target_points = target_points
	fx.need = need
	fx.z_index = 92
	fx.set_meta("fx_mode", "payoff")
	fx.set_meta("target_count", target_points.size())
	fx.set_meta("need", need)
	fx.set_meta("tier", fx.tier)
	fx.set_meta("orb_radius", 11.0 + float(fx.tier) * 3.0)
	fx.set_meta("particle_count", target_points.size() * (6 + fx.tier * 2))
	fx.set_meta("full_screen_frame", false)
	add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.name = "payoff_label"
	label.text = label_text if label_text != "" else \
		"债务结算·" + ["余债", "小节点", "中节点", "大节点"][fx.tier]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_font_override("font", UiTheme.cjk_font_bold())
	label.add_theme_color_override("font_color",
		Color("ffd166") if fx.tier == 3 else (Color("a29bfe") if fx.tier == 2 else Color("d6d0ff")))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color("2d2458"))
	fx.add_child(label)
	label.reset_size()
	label.position = center_point - Vector2(label.size.x * 0.5, 48.0)
	var tween := create_tween()
	tween.set_parallel(true)
	var duration := maxf(0.16, 1.10 / maxf(1.0, _speed))
	tween.tween_property(fx, "progress", 1.0, duration)
	tween.tween_property(fx, "modulate:a", 0.0, duration).set_delay(duration * 0.78)
	var cleanup := create_tween()
	cleanup.tween_interval(duration + 0.08)
	cleanup.tween_callback(fx.queue_free)
	return fx

func _battle_soul_gain_fx(uid: int, gain: Vector2i, by_uid: Dictionary) -> Control:
	var slot := _battle_slot_for_uid(uid, by_uid)
	if slot == null:
		return null
	var fx := SacrificeFxLayer.new()
	fx.name = "soul_gain_fx"
	fx.mode = "gain"
	fx.set_meta("fx_mode", "gain")
	fx.set_meta("gain", gain)
	slot.add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.name = "gain_label"
	label.text = "灵魂 +%d/+%d" % [gain.x, gain.y]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_font_override("font", UiTheme.cjk_font_bold())
	label.add_theme_color_override("font_color", Color("c7c0ff"))
	fx.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var particles := Node2D.new()
	particles.name = "soul_particles"
	fx.add_child(particles)
	var offsets: Array[Vector2] = [
		Vector2(-14, -7), Vector2(-5, -10), Vector2(7, -9), Vector2(15, -4),
		Vector2(-12, 5), Vector2(-2, 8), Vector2(9, 7), Vector2(16, 3),
	]
	for i in range(8):
		var particle := ColorRect.new()
		particle.name = "soul%d" % i
		particle.color = Color("a29bfe") if i % 2 == 0 else Color("6c5ce7")
		particle.size = Vector2(2, 6)
		particle.position = slot.size * 0.5 + offsets[i]
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		particles.add_child(particle)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "progress", 1.0, maxf(0.08, 0.62 / maxf(1.0, _speed)))
	tween.tween_property(fx, "modulate:a", 0.0, maxf(0.08, 0.62 / maxf(1.0, _speed)))
	for child in particles.get_children():
		var particle := child as ColorRect
		tween.tween_property(particle, "position:y", particle.position.y + 24.0,
			maxf(0.08, 0.62 / maxf(1.0, _speed)))
	tween.chain().tween_callback(fx.queue_free)
	return fx

func _battle_animate_death(uid: int, by_uid: Dictionary, speed_scale: float = 1.0) -> void:
	var slot := _battle_slot_for_uid(uid, by_uid)
	if slot != null:
		_play_sfx("death")
		slot.pivot_offset = slot.size * 0.5
		var duration := maxf(0.05, 0.26 / (maxf(1.0, _speed) * maxf(1.0, speed_scale)))
		var death_color := C_ATK
		if by_uid.has(uid):
			var death_style: Dictionary = MechanicStyle.family_style(
				String(Dictionary(by_uid[uid]).get("race", "neutral")))
			if String(death_style.get("family", "neutral")) != "neutral":
				death_color = Color(death_style.get("color", C_ATK))
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(slot, "self_modulate", Color(death_color.r, death_color.g, death_color.b, 0.0), duration)
		tween.tween_property(slot, "scale", Vector2(0.72, 0.72), duration)
		# 死亡动画不能把整场回放锁在 tween.finished 上；亡语链额外插入事件时，
		# 任何等待异常都必须由固定时长兜底放行。
		await _battle_wait(duration + 0.03)
		if tween.is_valid():
			tween.kill()
		if is_instance_valid(slot):
			slot.self_modulate = Color(death_color.r, death_color.g, death_color.b, 0.0)
			slot.scale = Vector2(0.72, 0.72)
	if by_uid.has(uid):
		var dead: Dictionary = by_uid[uid]
		dead["h"] = 0
		dead["_dead"] = true
		_clear_battle_card(uid, by_uid)

func _show_battle_float(ev: Dictionary, by_uid: Dictionary) -> void:
	var kind := String(ev.get("t", ""))
	var uid := -1
	var text := ""
	var color := C_NAME
	match kind:
		"damage":
			uid = int(ev.get("dst", -1))
			text = "-%d" % int(ev.get("dmg", 0))
			color = C_ATK
		"heal":
			uid = int(ev.get("id", -1))
			text = "+%d" % int(ev.get("val", 0))
			color = C_HP
		"buff":
			uid = int(ev.get("id", -1))
			text = "+%d/+%d" % [int(ev.get("a", 0)), int(ev.get("h", 0))]
			color = C_BLUE
		"shield_break":
			uid = int(ev.get("id", -1))
			text = "圣盾破"
			color = C_GOLD
		"death":
			uid = int(ev.get("id", -1))
			text = "阵亡"
			color = C_ATK
		"poison":
			uid = int(ev.get("dst", -1))
			text = "剧毒"
			color = Color("7bed9f")
		"evop":
			uid = int(ev.get("id", -1))
			text = "进化 %d/%d · 总%d" % [
				int(ev.get("evo", 0)), int(ev.get("need", 3)), int(ev.get("total", 0))]
			color = Color("7bed9f")
		"evo_full":
			uid = int(ev.get("id", -1))
			text = "质变! · 总%d" % int(ev.get("total", 0))
			color = C_GOLD
		"evolve":
			uid = int(ev.get("id", -1))
			text = "质变完成"
			color = C_GOLD
		"gene":
			uid = int(ev.get("id", -1))
			text = "基因 %d/5" % int(ev.get("gene", 0))
			color = C_GOLD
		"progress":
			uid = int(ev.get("id", -1))
			text = "进度 %d/5" % int(ev.get("progress", 0))
			color = Color("7bed9f")
		"progress_full":
			uid = int(ev.get("id", -1))
			text = "进度满"
			color = C_GOLD
		"progress_hatch":
			uid = int(ev.get("id", -1))
			text = "孵化!"
			color = C_GOLD
		"armor":
			text = ""
			color = C_BLUE
		"guard":
			uid = int(ev.get("id", -1))
			text = "拦截"
			color = C_BLUE
		"chain":
			uid = int(ev.get("id", -1))
			text = "连锁 %d" % int(ev.get("value", 0))
			color = C_GOLD
		"amp":
			uid = int(ev.get("id", -1))
			text = "增幅 %d" % int(ev.get("amp", 0))
			color = Color("a29bfe")
		"summon":
			uid = int(ev.get("id", -1))
			text = "召唤"
			color = Color("74b9ff")
		"rebirth":
			uid = int(ev.get("id", -1))
			text = "重生"
			color = C_HP
		"gamble":
			uid = int(ev.get("id", -1))
			text = "赌徒成功 ×%d" % int(ev.get("mult", 0))
			color = C_GOLD
		"ch":
			uid = int(ev.get("id", -1))
			text = "充能 %d/%d" % [int(ev.get("c", 0)), int(ev.get("cm", 0))]
			color = Color("74b9ff")
		"contract":
			uid = int(ev.get("id", -1))
			text = "契印"
			color = Color("a29bfe")
		"debt":
			uid = int(ev.get("src", -1))
			text = "债务 %d→%d" % [int(ev.get("old", 0)), int(ev.get("debt", 0))]
			color = Color("a29bfe")
		"debt_settle":
			uid = int(ev.get("src", -1))
			text = "偿还%d 全献祭+%d/+%d" % [int(ev.get("need", 0)), int(ev.get("a", 0)), int(ev.get("h", 0))]
			color = C_GOLD
	if uid < 0 or text == "" or not by_uid.has(uid):
		return
	var target: Dictionary = by_uid[uid]
	var style := MechanicStyle.event_style(ev, target)
	var family := String(style.get("family", "neutral"))
	var source := str(ev.get("source", ev.get("reason", "")))
	if kind == "buff":
		var label := MechanicStyle.source_label(style, source if source != "" else family)
		var a := int(ev.get("a", 0))
		var h := int(ev.get("h", 0))
		text = "%s +%d/+%d" % [label, a, h]
		color = Color(style.get("color", color))
	elif kind == "heal":
		if family == "vampire":
			text = "吸血 +%d" % int(ev.get("val", 0))
			color = Color(style.get("color", Color("ff3b30")))
		else:
			text = "生命 +%d" % int(ev.get("val", 0))
	elif kind == "damage":
		if family == "star":
			text = "星光回响 -%d" % int(ev.get("dmg", 0)) if int(ev.get("echo", 0)) != 0 \
				else "连锁伤害 -%d" % int(ev.get("dmg", 0))
			color = Color(style.get("color", C_GOLD))
		elif family == "vampire":
			color = Color(style.get("color", C_ATK))
	elif kind == "death":
		if family != "neutral":
			text = "%s · 阵亡" % String(style.get("label", "随从"))
			color = Color(style.get("color", C_ATK))
	elif kind in ["contract", "debt", "debt_settle"]:
		text = "%s · %s" % [MechanicStyle.source_label(style, kind), text]
		color = Color(style.get("color", color))
	elif kind in ["evop", "evo_full", "evolve", "gene", "progress", "progress_full", "progress_hatch"]:
		text = "进化 · %s" % text
		color = Color(style.get("color", color)) if kind in ["evop", "progress"] else C_GOLD
	elif kind in ["ch", "guard", "armor"]:
		if text != "":
			text = "机械 · %s" % text
		color = Color(style.get("color", color))
	elif kind in ["chain", "amp"]:
		text = "星灵 · %s" % text
		color = Color(style.get("color", color))
	elif kind in ["summon", "rebirth"]:
		text = "%s · %s" % [String(style.get("label", "亡灵")), text]
		color = Color(style.get("color", color))
	elif kind == "gamble":
		text = "赌徒 · %s" % text
		color = Color(style.get("color", color))
	var row: HBoxContainer = _p_row if String(target.get("_side", "p")) == "p" else _ai_row
	var slot: Control = _child_or_null(row, int(target.get("_slot", -1)))
	if slot == null:
		return
	var popup := Label.new()
	popup.name = "battle_float_%s" % kind
	popup.text = text
	popup.z_index = 90
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.set_meta("family", family)
	popup.set_meta("source_label", MechanicStyle.source_label(style, source if source != "" else kind))
	popup.set_meta("event_kind", kind)
	popup.add_theme_font_size_override("font_size", 15)
	popup.add_theme_font_override("font", UiTheme.cjk_font_bold())
	popup.add_theme_color_override("font_color", color)
	add_child(popup)
	popup.reset_size()
	popup.global_position = slot.global_position + Vector2(slot.size.x * 0.5 - popup.size.x * 0.5, 12.0)
	var tween := create_tween()
	tween.tween_property(popup, "position", popup.position + Vector2(0, -26), 0.45)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.45)
	tween.tween_callback(popup.queue_free)

func _battle_event_line(ev: Dictionary, names: Dictionary) -> String:
	var uname := func(id) -> String: return String(names.get(int(id), "单位%d" % int(id)))
	match String(ev.get("t", "")):
		"attack":
			return "%s 出手 → %s（%d）" % [uname.call(ev.get("src", -1)), uname.call(ev.get("dst", -1)), int(ev.get("atk", 0))]
		"hero_attack":
			return "    %s 攻击玩家（%d★）" % [
				uname.call(ev.get("id", -1)), int(ev.get("star", 1))]
		"damage":
			return "    %s 受 %d 伤害 → HP %d%s" % [uname.call(ev.get("dst", -1)), int(ev.get("dmg", 0)), int(ev.get("hp", 0)),
				"（协同）" if ev.get("follow", 0) else ("（回响）" if ev.get("echo", 0) else "")]
		"shield_break":
			return "    圣盾破碎"
		"taunt_break":
			return "    嘲讽被打破"
		"death":
			return "%s 阵亡" % String(ev.get("name", "?"))
		"buff":
			return "    %s 成长 +%d/+%d" % [uname.call(ev.get("id", -1)), int(ev.get("a", 0)), int(ev.get("h", 0))]
		"heal":
			return "    %s 回复 %d 生命" % [uname.call(ev.get("id", -1)), int(ev.get("val", 0))]
		"poison":
			return "    剧毒命中"
		"armor":
			return "    维修护甲吸收 %d（剩 %d）" % [int(ev.get("absorbed", 0)), int(ev.get("left", 0))]
		"guard":
			return "    %s 进入拦截模式" % uname.call(ev.get("id", -1))
		"chain":
			return "    %s 连锁 → %d" % [uname.call(ev.get("id", -1)), int(ev.get("value", 0))]
		"amp":
			return "    %s 星界增幅 → %d（连锁 %d）" % [
				uname.call(ev.get("id", -1)), int(ev.get("amp", 0)), int(ev.get("chain", 0))]
		"summon":
			return "    %s 召唤到场（槽 %d）" % [String(ev.get("name", "召唤物")), int(ev.get("slot", -1)) + 1]
		"rebirth":
			return "    %s 死亡重生 +%d/+%d" % [uname.call(ev.get("id", -1)), int(ev.get("a", 0)), int(ev.get("h", 0))]
		"gamble":
			return "    %s 掷骰 %s ×%d" % [
				uname.call(ev.get("id", -1)), "成功" if bool(ev.get("success", false)) else "失败", int(ev.get("mult", 0))]
		"evop":
			return "    %s 进化 %d/%d" % [uname.call(ev.get("id", -1)), int(ev.get("evo", 0)), int(ev.get("need", 3))]
		"evo_full":
			return "    %s 满格质变！" % uname.call(ev.get("id", -1))
		"evolve":
			return "    %s 完成质变（%s）" % [uname.call(ev.get("id", -1)), String(ev.get("kind", ""))]
		"gene":
			return "    %s 吞噬基因 %d/5" % [uname.call(ev.get("id", -1)), int(ev.get("gene", 0))]
		"progress":
			return "    %s 进化进度 %d/5" % [uname.call(ev.get("id", -1)), int(ev.get("progress", 0))]
		"progress_full":
			return "    %s 进度已满" % uname.call(ev.get("id", -1))
		"progress_hatch":
			return "    %s 孵化为 %s" % [uname.call(ev.get("id", -1)), String(ev.get("name", "混沌始祖"))]
		"debt":
			return "    债务 → %d（节点 %d）" % [int(ev.get("debt", 0)), int(ev.get("tier", 0))]
		"debt_settle":
			return "    债务结算 %d 点 → 全献祭 +%d/+%d" % [int(ev.get("need", 0)), int(ev.get("a", 0)), int(ev.get("h", 0))]
		"quest_reward":
			return "    %s宣言：全进化 +%d格" % [
				"达成" if bool(ev.get("ok", false)) else "未达成",
				int(ev.get("ticks", 1)),
			]
		"ch":
			return "    %s 充能 %d/%d" % [uname.call(ev.get("id", -1)), int(ev.get("c", 0)), int(ev.get("cm", 0))]
		"end":
			return "—— 战斗结束 ——"
	return ""

func _to_units(board: Array, base_uid: int) -> Array:
	var out: Array = []
	var uid := base_uid
	for c in board:
		if c == null:
			out.append(null)
			continue
		out.append(UnitScript.from_card(c, uid))
		uid += 1
	while out.size() < 7:
		out.append(null)
	return out

func _unit_uid_for_slot(board: Array, slot: int) -> int:
	if slot < 0 or slot >= board.size() or board[slot] == null:
		return -1
	var uid := 1
	for i in range(slot):
		if board[i] != null:
			uid += 1
	return uid

func _alive_star_total(board: Array) -> int:
	var total := 0
	for u in board:
		if u != null and bool(u.alive):
			total += maxi(1, int(u.star))
	return total

func _advance_round() -> void:
	var keep_shop: bool = ps.shop_frozen
	ps.shop_frozen = false
	_clear_freeze_overlay()
	ps.round_no += 1
	ep.round_no += 1
	ps.gold = Economy.round_income(ps.round_no, ps.win_streak, ps.lose_streak)
	ep.gold = Economy.ai_round_income(ep.round_no, ep.win_streak, ep.lose_streak, _ai_difficulty)
	ps.spell_refund = 0
	ep.spell_refund = 0
	if not keep_shop:
		ps.roll_shop()
		ep.roll_shop()
	ps.apply_prep_round_skills()
	ep.apply_prep_round_skills()
	AI.run_turn(ep, ep.races, 4, _ai_actions_per_round, ps.board, GameData.ai_templates)
	if _board_has_race(ps.board, "evolve"):
		ps.phase = 1 - ps.phase
		ps.select_quest(0)
	else:
		ps.ensure_quest()
	if _board_has_race(ep.board, "evolve"):
		ep.phase = 1 - ep.phase
		var e_pool: Array = Quest.pool_for_phase(ep.quest_pool, ep.phase)
		var e_index: int = ep.rng.randi_range(0, e_pool.size() - 1) if not e_pool.is_empty() else 0
		ep.select_quest(e_index)
	else:
		ep.ensure_quest()
	_prep_left = PREP_SECONDS
	if ps.round_no == 3 or ps.round_no == 6 or ps.round_no == 9:
		_show_round_choice(ps.round_no)

func _show_round_choice(r: int) -> void:
	_choice_options = [
		{"label": "+%d金" % ((r / 3) * 2)},
		{"label": "免费刷新%d次" % (1 if r == 3 else 2)},
		{
			"label": "下回合法术免费" if r == 3 else ("获得阵容核心牌" if r == 6 else "获得自选点金卡"),
		},
	]
	_round_choice_round = r
	_round_choice_time_left = ROUND_CHOICE_SECONDS
	_round_choice_active = true
	_busy = true
	_say("【第 %d 回合选择】请在下方三选一" % r)
	_clear_card_tooltip()
	_choice_overlay = Control.new()
	_choice_overlay.name = "round_choice_overlay"
	_choice_overlay.z_index = 125
	_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_choice_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", _sb(Color("2d3047"), C_GOLD, 18, 10))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "第%d回合选择" % r
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_font_override("font", UiTheme.cjk_font_bold())
	title.add_theme_color_override("font_color", C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_choice_countdown = Label.new()
	_choice_countdown.add_theme_font_size_override("font_size", 12)
	_choice_countdown.add_theme_color_override("font_color", C_GOLD)
	_choice_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_choice_countdown)

	for index in range(_choice_options.size()):
		var button := _btn(String(_choice_options[index]["label"]), Color("4a4d6b"),
			_resolve_round_choice.bind(index))
		button.custom_minimum_size = Vector2(240, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_stylebox_override("normal", _sb(Color("4a4d6b"), C_BLUE, 8, 6))
		button.add_theme_stylebox_override("hover", _sb(Color("5d6182"), C_GOLD, 8, 6))
		button.add_theme_stylebox_override("pressed", _sb(Color("3d405b"), C_BLUE, 8, 6))
		box.add_child(button)

func _resolve_round_choice(index: int) -> void:
	if not _round_choice_active:
		return
	_round_choice_active = false
	var result: Dictionary = ps.apply_round_choice(_round_choice_round, index)
	if bool(result.get("ok", false)) and String(ps.last_message) != "":
		_say(String(ps.last_message))
	if _choice_overlay != null and is_instance_valid(_choice_overlay):
		_choice_overlay.queue_free()
	_choice_overlay = null
	_choice_countdown = null
	_busy = false
	_refresh()

func _battle_narrative(events: Array, names: Dictionary, max_lines: int = 18) -> Array[String]:
	var out: Array[String] = []
	var uname := func(id) -> String: return String(names.get(int(id), "单位%d" % int(id)))
	for ev in events:
		match String(ev.get("t", "")):
			"attack":
				out.append("%s 出手 → %s（%d）" % [uname.call(ev["src"]), uname.call(ev["dst"]), int(ev.get("atk", 0))])
			"hero_attack":
				out.append("%s 攻击玩家（%d★）" % [
					uname.call(ev["id"]), int(ev.get("star", 1))])
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
	if _round_choice_active:
		_round_choice_time_left = maxf(0.0, _round_choice_time_left - delta)
		if is_instance_valid(_choice_countdown):
			_choice_countdown.text = "剩余 %d 秒" % ceili(_round_choice_time_left)
		if _round_choice_time_left <= 0.0:
			_resolve_round_choice(0)
		return
	_update_card_tooltip()
	_update_spell_target_arrow()
	if _busy or _game_over or ps == null or _rope == null:
		return
	_prep_left -= delta
	if _prep_left <= 0.0:
		_prep_left = PREP_SECONDS
		_say("⏳ 备战时间到，自动开打")
		_fight()
	_rope.left_ratio = clampf(_prep_left / PREP_SECONDS, 0.0, 1.0)
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

class Draggable extends Control:
	var host
	var index := -1
	var _mouse_down := false
	var _down_pos := Vector2.ZERO
	var _drag_started := false
	func _get_drag_data(_at_position: Vector2) -> Variant:
		if host == null or host._busy or host._game_over:
			return null
		if index < 0 or index >= host.ps.hand.size():
			return null
		_drag_started = true
		if host._input_debug:
			print("[input-debug] Draggable drag-start index=%d" % index)
		host.begin_drag(index)
		var card: Dictionary = host.ps.hand[index]
		var preview := Label.new()
		preview.text = "%s  %d/%d" % [String(card.get("n", "?")), int(card.get("a", 0)), int(card.get("h", 0))]
		preview.add_theme_font_size_override("font_size", 11)
		preview.add_theme_color_override("font_color", Color.WHITE)
		preview.add_theme_stylebox_override("normal", host._sb(host.C_SLOT_FILL, host.C_GOLD, 4, 4))
		preview.custom_minimum_size = Vector2(96, 24)
		preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_drag_preview(preview)
		return {"kind": "hand", "index": index}
	func _gui_input(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton):
			return
		var mouse := ev as InputEventMouseButton
		if host != null and host._input_debug:
			print("[input-debug] Draggable index=%d button=%d pressed=%s pos=%s hovered=%s" % [
				index, mouse.button_index, str(mouse.pressed), mouse.position,
				str(get_viewport().gui_get_hovered_control())])
		if mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
			if host != null:
				host._cancel_selection()
			accept_event()
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_mouse_down = true
			_down_pos = mouse.position
			return
		if not _mouse_down:
			return
		_mouse_down = false
		var from_drag_start := _drag_started
		_drag_started = false
		if Time.get_ticks_msec() < host._drop_guard_until_msec:
			accept_event()
			return
		if mouse.position.distance_to(_down_pos) <= 16.0 and host != null:
			host._click_hand(index, from_drag_start)
		accept_event()

class Dropless extends Control:
	var host
	var index := -1
	var _mouse_down := false
	func _gui_input(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton):
			return
		var mouse := ev as InputEventMouseButton
		if host != null and host._input_debug:
			print("[input-debug] Dropless index=%d button=%d pressed=%s pos=%s hovered=%s" % [
				index, mouse.button_index, str(mouse.pressed), mouse.position,
				str(get_viewport().gui_get_hovered_control())])
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_mouse_down = true
			elif _mouse_down:
				_mouse_down = false
				if host != null:
					host._click_shop(index)
				accept_event()

class FreezeOverlay extends Control:
	var target: Control
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if target == null or not is_instance_valid(target):
			return
		var rect := Rect2(target.global_position, target.size).grow(4.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		draw_rect(rect, Color(0.45, 0.78, 1.0, 0.10 + 0.05 * pulse), true)
		draw_rect(rect, Color(0.72, 0.92, 1.0, 0.72 + 0.22 * pulse), false, 2.0)
		for i in range(9):
			var x := rect.position.x + 8.0 + float(i) * maxf(16.0, (rect.size.x - 16.0) / 8.0)
			var y := rect.position.y + fposmod(float(i) * 23.0 + Time.get_ticks_msec() * 0.018, rect.size.y)
			draw_line(Vector2(x - 3.0, y), Vector2(x + 3.0, y),
				Color(0.85, 0.97, 1.0, 0.78), 1.5)
			draw_line(Vector2(x, y - 3.0), Vector2(x, y + 3.0),
				Color(0.85, 0.97, 1.0, 0.78), 1.5)

class HeroBurstFx extends Control:
	var progress := 0.0
	var color := Color("ff5a4f")
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var p := clampf(progress, 0.0, 1.0)
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.5
		var flash := Color(1.0, 0.86, 0.62, 0.72 * (1.0 - p))
		draw_circle(center, radius * (0.12 + 0.66 * p), Color(1.0, 0.22, 0.16, 0.18 * (1.0 - p)))
		draw_circle(center, radius * maxf(0.0, 1.0 - p) * 0.24, flash)
		for ring in range(3):
			var ring_r := radius * (0.18 + float(ring) * 0.10 + p * (0.58 + float(ring) * 0.08))
			draw_arc(center, ring_r, 0.0, TAU, 52,
				Color(color.r, color.g, color.b, (0.72 - float(ring) * 0.16) * (1.0 - p)),
				2.5 - float(ring) * 0.45)
		for i in range(24):
			var angle := float(i) * TAU / 24.0 + float(i % 3) * 0.12
			var distance := radius * (0.12 + p * (0.72 + float(i % 5) * 0.08))
			var shard_center := center + Vector2(cos(angle), sin(angle)) * distance
			var direction := Vector2(cos(angle), sin(angle))
			var normal := Vector2(-direction.y, direction.x)
			var length := 3.0 + float(i % 4) * 2.2
			var width := 1.4 + float(i % 3) * 0.8
			var points := PackedVector2Array([
				shard_center + direction * length,
				shard_center - direction * length * 0.45 + normal * width,
				shard_center - direction * length * 0.45 - normal * width,
			])
			var shard_color := Color("ffd166") if i % 4 == 0 else (
				Color("ff8b5e") if i % 3 == 0 else color)
			draw_colored_polygon(points, Color(shard_color.r, shard_color.g, shard_color.b, 0.88 * (1.0 - p)))
		for spark in range(16):
			var angle2 := float(spark) * TAU / 16.0 + 0.21
			var spark_distance := radius * (0.25 + p * (0.82 + float(spark % 4) * 0.05))
			var spark_pos := center + Vector2(cos(angle2), sin(angle2)) * spark_distance
			draw_circle(spark_pos, maxf(0.8, 2.8 * (1.0 - p)),
				Color(1.0, 0.86, 0.42, 0.70 * (1.0 - p)))


class BattlePathFx extends Control:
	var progress := 0.0
	var from_rect := Rect2()
	var to_rect := Rect2()
	var color := Color.WHITE
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if from_rect.size.x <= 0.0 or to_rect.size.x <= 0.0:
			return
		var from := from_rect.get_center()
		var to := to_rect.get_center()
		var alpha := clampf(1.0 - progress * 0.85, 0.08, 1.0)
		var head := from.lerp(to, clampf(progress * 1.35, 0.0, 1.0))
		draw_line(from, head, Color(color.r, color.g, color.b, 0.58 * alpha), 3.0)
		draw_line(from, head, Color(1.0, 1.0, 1.0, 0.82 * alpha), 1.0)
		for i in range(6):
			var t := clampf(progress * 1.35 - float(i) * 0.075, 0.0, 1.0)
			if t <= 0.0:
				continue
			var p := from.lerp(to, t)
			draw_circle(p, maxf(1.0, 4.0 - float(i) * 0.5),
				Color(color.r, color.g, color.b, alpha * (0.7 - float(i) * 0.09)))
		draw_circle(head, 4.5, Color(1.0, 1.0, 1.0, 0.86 * alpha))
		draw_circle(head, 2.2, Color(color.r, color.g, color.b, alpha))

class DropFxLayer extends Control:
	var mode := ""
	var progress := 0.0
	var from_rect := Rect2()
	var to_rect := Rect2()
	var family := "neutral"
	var colors: Array[Color] = []
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if to_rect.size.x <= 0.0 or to_rect.size.y <= 0.0:
			return
		var target := to_rect.get_center()
		var source := from_rect.get_center() if from_rect.size.x > 0.0 else target - Vector2(0.0, 45.0)
		var main: Color = colors[0] if not colors.is_empty() else Color.WHITE
		var accent: Color = colors[1] if colors.size() > 1 else main
		var deep: Color = colors[2] if colors.size() > 2 else main.darkened(0.5)
		var pale: Color = colors[3] if colors.size() > 3 else main.lightened(0.5)
		var alpha := clampf(1.0 - progress * 0.82, 0.12, 1.0)
		match mode:
			"devour_success":
				var line_alpha := (1.0 - progress) * 0.8
				draw_line(source, target, Color(deep.r, deep.g, deep.b, line_alpha), 3.0)
				draw_line(source, target, Color(pale.r, pale.g, pale.b, line_alpha), 1.0)
				for i in range(18):
					var t := fposmod(progress * 1.55 + float(i) / 18.0, 1.0)
					var p := source.lerp(target, t)
					var offset := Vector2(sin(float(i) * 2.4 + progress * 8.0), cos(float(i) * 1.7)) * (4.0 + float(i % 4))
					var particle_color := main if i % 3 != 0 else accent
					draw_circle(p + offset, 2.0 + float(i % 3) * 0.7,
						Color(particle_color.r, particle_color.g, particle_color.b, alpha))
				draw_arc(target, 18.0 + progress * 25.0, 0.0, TAU, 48,
					Color(main.r, main.g, main.b, 0.82 * alpha), 3.0)
				draw_arc(target, 8.0 + progress * 15.0, -progress * 4.0, TAU - progress * 4.0, 40,
					Color(accent.r, accent.g, accent.b, 0.72 * alpha), 2.0)
				draw_circle(target, 5.0 * (1.0 - progress), Color(1.0, 0.18, 0.18, alpha))
			"sigil_bind":
				var ring_t := clampf(progress * 1.25, 0.0, 1.0)
				var ring := Rect2(target - Vector2(20, 20) * ring_t, Vector2(40, 40) * ring_t)
				draw_rect(ring, Color(main.r, main.g, main.b, 0.75 * alpha), false, 3.0)
				draw_rect(ring.grow(5.0 + progress * 12.0),
					Color(accent.r, accent.g, accent.b, 0.38 * alpha), false, 1.0)
				for i in range(12):
					var angle := float(i) * TAU / 12.0 + progress * 2.0
					var radius := 10.0 + progress * 30.0
					var p := target + Vector2(cos(angle), sin(angle)) * radius
					draw_circle(p, 2.0, Color(pale.r, pale.g, pale.b, alpha))
			"magnet_success":
				var cyan := Color("74b9ff")
				var spoke := target - source
				for i in range(4):
					var offset := Vector2(0, float(i - 2) * 5.0)
					draw_line(source + offset, target + offset,
						Color(cyan.r, cyan.g, cyan.b, 0.55 * alpha), 1.5)
				draw_arc(target, 16.0 + progress * 20.0, 0.0, TAU, 40,
					Color(cyan.r, cyan.g, cyan.b, 0.85 * alpha), 2.0)
				draw_circle(target, 4.0 + (1.0 - progress) * 4.0, Color(accent.r, accent.g, accent.b, alpha))
				draw_line(target - spoke.normalized() * 18.0, target + spoke.normalized() * 18.0,
					Color(pale.r, pale.g, pale.b, 0.6 * alpha), 2.0)
			"place_success":
				draw_arc(target, 14.0 + progress * 22.0, 0.0, TAU, 32,
					Color(main.r, main.g, main.b, 0.78 * alpha), 3.0)
				draw_arc(target, 5.0 + progress * 12.0, 0.0, TAU, 24,
					Color(accent.r, accent.g, accent.b, 0.6 * alpha), 2.0)
			"quest_reward":
				var source_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
				draw_circle(source, 8.0 + 8.0 * source_pulse,
					Color(main.r, main.g, main.b, 0.14 * alpha))
				draw_arc(source, 10.0 + 8.0 * source_pulse, 0.0, TAU, 36,
					Color(pale.r, pale.g, pale.b, 0.72 * alpha), 2.0)
				var travel := clampf(progress * 1.35, 0.0, 1.0)
				var orb := source.lerp(target, travel)
				draw_line(source, orb, Color(main.r, main.g, main.b, 0.48 * alpha), 2.0)
				for i in range(10):
					var trail_t := clampf(travel - float(i) * 0.055, 0.0, 1.0)
					var trail := source.lerp(target, trail_t)
					draw_circle(trail, maxf(1.0, 4.5 - float(i) * 0.32),
						Color(main.r, main.g, main.b, alpha * (0.62 - float(i) * 0.045)))
				draw_circle(orb, 7.0, Color(accent.r, accent.g, accent.b, alpha))
				draw_circle(orb, 3.5, Color(1.0, 1.0, 1.0, alpha))
				draw_arc(target, 15.0 + progress * 25.0, 0.0, TAU, 42,
					Color(main.r, main.g, main.b, 0.82 * alpha), 3.0)
				draw_circle(target, 5.0 * (1.0 - progress), Color(pale.r, pale.g, pale.b, alpha))

class SacrificeFxLayer extends Control:
	var mode := ""
	var progress := 0.0
	var target_points: Array[Vector2] = []
	var source_point := Vector2.ZERO
	var center_point := Vector2.ZERO
	var need := 0
	var tier := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var rect := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		match mode:
			"contract":
				if rect.size.x <= 0.0 or rect.size.y <= 0.0:
					return
				draw_rect(rect, Color(0.64, 0.61, 1.0, 0.08 + 0.12 * (1.0 - progress)), true)
				_dashed_rect(rect, Color(0.64, 0.61, 1.0, 0.95), 3.0, 7.0)
				_dashed_rect(rect.grow(-3.0), Color(0.79, 0.75, 1.0, 0.45), 1.0, 5.0)
			"offer":
				draw_rect(rect, Color(0.12, 0.07, 0.24, 0.78 * (1.0 - progress * 0.45)), true)
				var center := size * 0.5
				for i in range(15):
					var angle := float(i) * TAU / 15.0 + progress * 0.9
					var radius := 5.0 + progress * (12.0 + float(i % 4) * 4.0)
					var point := center + Vector2(cos(angle), sin(angle)) * radius
					var particle_color := Color("6c5ce7") if i % 2 == 0 else Color("c7c0ff")
					if i % 5 == 0:
						particle_color = Color("ffd166")
					draw_circle(point, 1.5 + float(i % 3) * 0.5, particle_color)
			"cast":
				var center := size * 0.5
				var alpha := 1.0 - progress
				var cast_colors: Array[Color] = [
					Color("8f86b8"), Color("d6d0ff"), Color("a29bfe"), Color("ffd166"),
				]
				var cast_color: Color = cast_colors[clampi(tier, 0, 3)]
				draw_circle(center, 8.0 + progress * 20.0,
					Color(cast_color.r, cast_color.g, cast_color.b, 0.14 * alpha))
				for ring_index in range(1 + clampi(tier, 0, 3)):
					draw_arc(center, 9.0 + progress * (17.0 + float(ring_index) * 5.0),
						float(ring_index) * 0.35, TAU + float(ring_index) * 0.35, 48,
						Color(cast_color.r, cast_color.g, cast_color.b, (0.90 - float(ring_index) * 0.18) * alpha),
						2.2)
				var d := 16.0 + progress * 16.0
				draw_line(center - Vector2(d, 0), center + Vector2(d, 0),
					Color(cast_color.r, cast_color.g, cast_color.b, 0.66 * alpha), 1.0)
				draw_line(center - Vector2(0, d), center + Vector2(0, d),
					Color(cast_color.r, cast_color.g, cast_color.b, 0.78 * alpha), 1.0)
			"payoff":
				var center := size * 0.5
				var t := clampf(progress, 0.0, 1.0)
				var draw_center := center_point if center_point != Vector2.ZERO else center
				var draw_source := source_point if source_point != Vector2.ZERO else draw_center
				var tier_index := clampi(tier, 0, 3)
				var tier_colors: Array[Color] = [
					Color("8f86b8"), Color("d6d0ff"), Color("a29bfe"), Color("ffd166"),
				]
				var tier_color: Color = tier_colors[tier_index]
				# 1) 从血祭司祭身上抽出债务层。
				var extract_t := clampf(t / 0.22, 0.0, 1.0)
				var debt_radius := 12.0 + 7.0 * extract_t
				draw_circle(draw_source, debt_radius,
					Color(0.28, 0.14, 0.50, 0.16 + 0.18 * (1.0 - t)))
				draw_arc(draw_source, debt_radius + 3.0, 0.0, TAU, 40,
					Color(0.78, 0.70, 1.0, 0.42 * (1.0 - extract_t * 0.45)), 2.0)
				var extract_path := draw_source.lerp(draw_center, extract_t)
				draw_line(draw_source, extract_path,
					Color(0.78, 0.70, 1.0, 0.42 * (1.0 - extract_t)), 2.0)

				# 2) 债务层到中央后闪光。
				var flash_t := clampf((t - 0.20) / 0.10, 0.0, 1.0)
				var flash_alpha := sin(flash_t * PI) * 0.86
				draw_circle(draw_center, 30.0 + 36.0 * flash_t,
					Color(0.90, 0.82, 1.0, 0.18 * flash_alpha))
				var flash_ray := 20.0 + 32.0 * flash_t
				for ray in range(12):
					var ray_angle := float(ray) * TAU / 12.0
					draw_line(draw_center + Vector2(cos(ray_angle), sin(ray_angle)) * 8.0,
						draw_center + Vector2(cos(ray_angle), sin(ray_angle)) * flash_ray,
						Color(0.88, 0.76, 1.0, 0.72 * flash_alpha), 1.4)

				# 3) 中央大紫球。
				var orb_t := clampf((t - 0.24) / 0.18, 0.0, 1.0)
				var orb := draw_center
				var orb_radius := (15.0 + float(tier_index) * 4.0) * (0.35 + 0.65 * orb_t)
				draw_circle(orb, orb_radius * 1.85, Color(0.35, 0.17, 0.58, 0.14 + 0.10 * orb_t))
				draw_circle(orb, orb_radius, Color(0.42, 0.24, 0.68, 0.90))
				draw_circle(orb, orb_radius * 0.62, Color(0.72, 0.58, 0.96, 0.96))
				draw_circle(orb - Vector2(orb_radius * 0.28, orb_radius * 0.30),
					maxf(1.2, orb_radius * 0.18), Color(1.0, 0.93, 1.0, 0.88))
				for bead in range(12 + tier_index * 4):
					var angle := float(bead) * TAU / float(12 + tier_index * 4) + t * 6.0
					var bead_radius := orb_radius + 3.0 + 3.0 * (0.5 + 0.5 * sin(t * 10.0 + float(bead)))
					var bead_color := Color("ffd166") if bead % 4 == 0 else Color("c7c0ff")
					draw_circle(orb + Vector2(cos(angle), sin(angle)) * bead_radius,
						1.2 + float(bead % 3) * 0.55, bead_color)
				var burst_t := clampf((t - 0.36) / 0.16, 0.0, 1.0)
				var burst_radius := 18.0 + 54.0 * burst_t
				for burst_ray in range(16 + tier_index * 4):
					var burst_angle := float(burst_ray) * TAU / float(16 + tier_index * 4) + t * 2.0
					draw_line(draw_center,
						draw_center + Vector2(cos(burst_angle), sin(burst_angle)) * burst_radius,
						Color(0.84, 0.72, 1.0, 0.56 * (1.0 - burst_t)), 1.4)
				var converge_raw := clampf((t - 0.40) / 0.60, 0.0, 1.0)
				var converge_t := pow(converge_raw, 2.0)
				for point_index in range(target_points.size()):
					var target: Vector2 = target_points[point_index]
					if target == Vector2.ZERO:
						target = draw_center + Vector2(0.0, 34.0)
					var point := target - draw_center
					var point_len := point.length()
					var perp := Vector2(-point.y, point.x).normalized() if point_len > 0.01 else Vector2(0.0, 1.0)
					var arc_offset := perp * (8.0 + float(tier_index) * 2.5) \
						* sin(float(point_index) * 1.7 + t * 7.0) * (1.0 - converge_t)
					var head := draw_center.lerp(target, converge_t) + arc_offset
					draw_line(draw_center, target,
						Color(tier_color.r, tier_color.g, tier_color.b, 0.12 + 0.20 * converge_raw),
						1.2 + float(tier_index) * 0.45)
					var particle_total := 6 + tier_index * 2
					for particle in range(particle_total):
						var phase := fposmod(converge_raw * (2.3 + float(tier_index) * 0.35)
							+ float(particle) / float(particle_total)
							+ float(point_index) * 0.13, 1.0)
						var tail := head - (target - draw_center).normalized() * phase * (10.0 + float(tier_index) * 2.0)
						var particle_color := Color("ffd166") if particle % 4 == 0 else (
							Color("d6d0ff") if particle % 2 == 0 else tier_color)
						var particle_radius := 1.2 + float((particle + point_index) % 3) * 0.7
						draw_circle(tail, particle_radius,
							Color(particle_color.r, particle_color.g, particle_color.b, 0.72 - phase * 0.28))
					if converge_raw > 0.78:
						var impact_t := clampf((converge_raw - 0.78) / 0.22, 0.0, 1.0)
						var impact := 7.0 + 16.0 * impact_t
						draw_arc(target, impact, -impact_t * 3.0, TAU - impact_t * 3.0, 34,
							Color(0.78, 0.58, 1.0, 0.88 * (1.0 - impact_t * 0.25)), 2.4)
						draw_circle(target, 5.5 * (1.0 - impact_t * 0.35),
							Color(0.90, 0.78, 1.0, 0.92 * (1.0 - impact_t * 0.25)))
				draw_circle(orb, orb_radius * 0.34, Color(1.0, 0.96, 1.0, 0.92))
			"gain":
				var alpha := 1.0 - progress
				draw_rect(rect, Color(0.64, 0.61, 1.0, 0.12 * alpha), true)
				_dashed_rect(rect, Color(0.78, 0.75, 1.0, 0.82 * alpha), 2.0, 5.0)
	func _dashed_rect(r: Rect2, color: Color, width: float, dash: float) -> void:
		_dashed_line(r.position, Vector2(r.end.x, r.position.y), color, width, dash)
		_dashed_line(Vector2(r.end.x, r.position.y), r.end, color, width, dash)
		_dashed_line(r.end, Vector2(r.position.x, r.end.y), color, width, dash)
		_dashed_line(Vector2(r.position.x, r.end.y), r.position, color, width, dash)
	func _dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash: float) -> void:
		var length := from.distance_to(to)
		if length <= 0.0:
			return
		var direction := (to - from) / length
		var cursor := 0.0
		while cursor < length:
			var segment_end := minf(length, cursor + dash * 0.62)
			draw_line(from + direction * cursor, from + direction * segment_end, color, width)
			cursor += dash

class SigilSlot extends PanelContainer:
	var host
	var active := false
	var preview_valid := false
	var preview_mode := ""
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_exited.connect(_on_mouse_exited)
	func set_state(text: String, color: Color, border: Color, is_active: bool) -> void:
		active = is_active
		var label := get_node_or_null("sigil_label") as Label
		if label != null:
			label.text = text
			label.add_theme_color_override("font_color", color)
		if host != null:
			var fill := Color(0.11, 0.10, 0.18, 0.96) if active else Color(0.08, 0.08, 0.13, 0.96)
			add_theme_stylebox_override("panel", host._sb(fill, border, 2, 4))
	func set_preview(valid: bool, mode: String) -> void:
		preview_valid = valid
		preview_mode = mode
		if host != null:
			var style := MechanicStyle.family_style("sacrifice")
			var preview_color: Color = Color(style.get("color", Color.WHITE)) if valid else Color("ff4d4d")
			add_theme_stylebox_override("panel", host._sb(Color(0.11, 0.08, 0.18, 0.97), preview_color, 3, 5))
		queue_redraw()
	func _process(_delta: float) -> void:
		if preview_mode != "":
			queue_redraw()
	func _draw() -> void:
		if preview_mode == "":
			return
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		var style := MechanicStyle.family_style("sacrifice")
		var color: Color = Color(style.get("color", Color.WHITE)) if preview_valid else Color("ff4d4d")
		var rect := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		draw_rect(rect.grow(-2.0), Color(color.r, color.g, color.b, 0.10 + 0.16 * pulse), true)
		draw_rect(rect.grow(-1.0), Color(color.r, color.g, color.b, 0.55 + 0.45 * pulse), false, 2.0)
	func _on_mouse_exited() -> void:
		if host != null:
			host._clear_drop_preview(self)
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if host == null or host._busy or host._game_over or not (data is Dictionary):
			if host != null:
				host._preview_drop(self, false, "sigil", "busy_or_invalid_data")
			return false
		var payload: Dictionary = data
		if String(payload.get("kind", "")) != "board":
			host._preview_drop(self, false, "sigil", "not_board")
			return false
		var source_slot := int(payload.get("index", -1))
		if source_slot < 0 or source_slot >= host.ps.board.size() or host.ps.board[source_slot] == null:
			host._preview_drop(self, false, "sigil", "empty_source")
			return false
		var valid := String(host.ps.board[source_slot].get("race", "")) == "sacrifice"
		host._preview_drop(self, valid, "sigil", "sacrifice" if valid else "not_sacrifice")
		return valid
	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not _can_drop_data(_at_position, data):
			return
		var payload: Dictionary = data
		host._clear_drop_preview(self)
		host._set_contract_slot(int(payload.get("index", -1)))
	func _gui_input(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton):
			return
		var mouse := ev as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_RIGHT or not mouse.pressed:
			return
		if host == null or host._busy or host._game_over:
			return
		host._clear_contract()
		host._say("契印槽已清空")
		host._update_selection_bar()
		host._refresh()
		accept_event()

class DropSlot extends PanelContainer:
	var host
	var slot := -1
	var is_mine := true
	var zone := false
	var zone_ready := false
	var preview_mode := ""
	var preview_valid := false
	var _mouse_down := false
	var _drag_started := false
	func _init() -> void:
		mouse_exited.connect(_on_mouse_exited)
	func _get_drag_data(_at_position: Vector2) -> Variant:
		if not is_mine or host == null or host._busy or host._game_over:
			return null
		if slot < 0 or slot >= host.ps.board.size() or host.ps.board[slot] == null:
			return null
		_drag_started = true
		if host._input_debug:
			print("[input-debug] DropSlot drag-start slot=%d" % slot)
		host.begin_board_drag(slot)
		var card: Dictionary = host.ps.board[slot]
		var preview := Label.new()
		preview.text = "%s  %d/%d" % [String(card.get("n", "?")), int(card.get("a", 0)), int(card.get("h", 0))]
		preview.add_theme_font_size_override("font_size", 11)
		preview.add_theme_color_override("font_color", Color.WHITE)
		preview.add_theme_stylebox_override("normal", host._sb(host.C_SLOT_FILL, host.C_GOLD, 4, 4))
		preview.custom_minimum_size = Vector2(96, 24)
		preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_drag_preview(preview)
		return {"kind": "board", "index": slot}
	func _preview(valid: bool, mode: String, reason: String) -> void:
		if host == null:
			return
		preview_valid = valid
		preview_mode = mode
		host._preview_drop(self, valid, mode, reason)
		var decor = host._find_slot_decor(self) as SlotDecor
		if decor != null:
			decor.drop_preview = mode if valid else "invalid"
			decor.drop_preview_label = host._drop_preview_label(mode, valid)
			decor.queue_redraw()
	func _on_mouse_exited() -> void:
		if host != null:
			host._clear_drop_preview(self)
	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not is_mine or host == null or host._busy or host._game_over:
			if host != null:
				_preview(false, "place", "busy_or_not_mine")
			return false
		if not (data is Dictionary):
			_preview(false, "place", "invalid_payload")
			return false
		var payload: Dictionary = data
		var kind := String(payload.get("kind", ""))
		if kind == "hand":
			var hand_index := int(payload.get("index", -1))
			if hand_index < 0 or hand_index >= host.ps.hand.size():
				_preview(false, "place", "invalid_hand")
				return false
			var hand_card: Dictionary = host.ps.hand[hand_index]
			var target = host.ps.board[slot]
			var valid := true
			var mode := "place" if target == null else "swap"
			if String(hand_card.get("bc", {}).get("e", "")) == "devour":
				valid = target != null
				mode = "devour"
			elif hand_card.has("magA") or hand_card.has("magH"):
				valid = target != null and String(target.get("race", "")) == "mech"
				mode = "magnet"
			elif target != null:
				valid = false
				mode = "place"
			var reason := "valid_hand"
			if not valid:
				reason = "invalid_target"
			_preview(valid, mode, reason)
			return valid
		if kind == "board":
			var source_slot := int(payload.get("index", -1))
			if source_slot < 0 or source_slot >= host.ps.board.size() or host.ps.board[source_slot] == null:
				_preview(false, "swap", "invalid_board_source")
				return false
			var source: Dictionary = host.ps.board[source_slot]
			var target2 = host.ps.board[slot]
			var valid2 := true
			var mode2 := "swap"
			if bool(source.get("_devourReady", false)):
				valid2 = source_slot != slot and target2 != null
				mode2 = "devour"
			elif source.has("magA") or source.has("magH"):
				valid2 = target2 != null and String(target2.get("race", "")) == "mech"
				mode2 = "magnet"
			elif target2 != null and String(source.get("race", "")) == "mech" \
					and String(target2.get("race", "")) == "mech":
				mode2 = "mech_merge"
			_preview(valid2, mode2, "valid_board" if valid2 else "invalid_board")
			return valid2
		_preview(false, "place", "invalid_kind")
		return false
	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not _can_drop_data(_at_position, data):
			return
		host._clear_drop_preview(self)
		preview_mode = ""
		host._register_drop()
		var payload: Dictionary = data
		if String(payload.get("kind", "")) == "hand":
			host.drop_on_slot(int(payload.get("index", -1)), slot)
		else:
			host.drop_board_on_slot(int(payload.get("index", -1)), slot)
	func _gui_input(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton):
			return
		var mouse := ev as InputEventMouseButton
		if host != null and host._input_debug:
			print("[input-debug] DropSlot slot=%d mine=%s button=%d pressed=%s pos=%s hovered=%s" % [
				slot, str(is_mine), mouse.button_index, str(mouse.pressed), mouse.position,
				str(get_viewport().gui_get_hovered_control())])
		if mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
			if host != null:
				host._cancel_selection()
			accept_event()
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_mouse_down = true
			return
		if not _mouse_down:
			return
		_mouse_down = false
		var from_drag_start := _drag_started
		_drag_started = false
		if Time.get_ticks_msec() < host._drop_guard_until_msec:
			accept_event()
			return
		if host != null:
			host._click_board(slot, is_mine, from_drag_start)
		accept_event()

## 槽位装饰：空槽虚线框 / 合体区描边（就绪转金色实线）/ 底部生命条（对应原版 .sl::after 与 .hpbar）
class SpellTargetArrow extends Control:
	var active := false
	var from_pos := Vector2.ZERO
	var to_pos := Vector2.ZERO
	var arrow_color := Color.WHITE
	var dash_phase := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = false

	func set_targeting(active_flag: bool, source: Vector2 = Vector2.ZERO,
			target: Vector2 = Vector2.ZERO, color: Color = Color.WHITE) -> void:
		active = active_flag
		from_pos = source
		to_pos = target
		arrow_color = color
		visible = active_flag
		queue_redraw()

	func _process(delta: float) -> void:
		if not active:
			return
		dash_phase = fmod(dash_phase + delta * 30.0, 13.0)
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var delta_vec: Vector2 = to_pos - from_pos
		var distance: float = delta_vec.length()
		if distance < 8.0:
			return
		var direction: Vector2 = delta_vec / distance
		var end_point: Vector2 = to_pos - direction * 13.0
		_draw_dashed(from_pos, end_point, arrow_color, 2.0, 8.0, 5.0, dash_phase)
		var normal := Vector2(-direction.y, direction.x)
		var head := PackedVector2Array([
			to_pos,
			to_pos - direction * 15.0 + normal * 7.0,
			to_pos - direction * 15.0 - normal * 7.0,
		])
		draw_colored_polygon(head, arrow_color)
		draw_circle(from_pos, 4.0,
			Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.78))

	func _draw_dashed(start: Vector2, end: Vector2, color: Color, width: float,
			dash: float, gap: float, phase: float) -> void:
		var total: float = (end - start).length()
		if total <= 0.0:
			return
		var direction: Vector2 = (end - start) / total
		var cursor: float = -fmod(phase, dash + gap)
		while cursor < total:
			var from_t: float = maxf(0.0, cursor)
			var to_t: float = minf(total, cursor + dash)
			if to_t > from_t:
				draw_line(start + direction * from_t, start + direction * to_t, color, width)
			cursor += dash + gap


class SlotDecor extends Control:
	var zone := false
	var zone_ready := false
	var has_card := false
	var is_gold := false
	var is_taunt := false
	var is_shield := false
	var is_attacking := false
	var is_hit := false
	var is_dead := false
	var is_contract := false
	var is_devour_target := false
	var is_selected := false
	var drop_preview := ""
	var drop_preview_label := ""
	var hp_ratio := 1.0
	func _process(_delta: float) -> void:
		if is_contract or is_devour_target or is_selected or drop_preview != "":
			queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		if has_card:
			if is_taunt:
				_layered_outline(r, C_TAUNT_EDGE, C_TAUNT_INNER, C_TAUNT_OUTER)
			elif is_shield:
				_layered_outline(r, C_SHIELD_EDGE, C_SHIELD_INNER, C_SHIELD_OUTER)
			else:
				draw_rect(r, C_GOLD if is_gold else C_LINE_FILL, false, 1.0)
		else:
			_dashed(r, C_LINE, 1.0, 4.0)
		if zone:
			var zr := Rect2(Vector2(2, 2), size - Vector2(4, 4))
			var col: Color = C_GOLD if zone_ready else Color(0.455, 0.725, 1.0, 0.65)
			if zone_ready:
				draw_rect(zr, col, false, 2.0)
			else:
				_dashed(zr, col, 2.0, 5.0)
		if is_contract:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			var cr := Rect2(Vector2(2, 2), size - Vector2(4, 4))
			draw_rect(cr, Color(C_CONTRACT.r, C_CONTRACT.g, C_CONTRACT.b, 0.08 + 0.13 * pulse), true)
			_dashed(cr, Color(C_CONTRACT.r, C_CONTRACT.g, C_CONTRACT.b, 0.72 + 0.28 * pulse), 2.0, 5.0)
		if is_devour_target and has_card:
			var devour_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
			var dr := Rect2(Vector2(1, 1), size - Vector2(2, 2))
			draw_rect(dr, Color(C_DEVOUR.r, C_DEVOUR.g, C_DEVOUR.b, 0.07 + 0.14 * devour_pulse), true)
			draw_rect(dr.grow(-1.0), C_DEVOUR, false, 2.0)
			draw_rect(dr.grow(-4.0), Color(C_DEVOUR.r, C_DEVOUR.g, C_DEVOUR.b, 0.45 + 0.5 * devour_pulse), false, 1.0)
		if is_selected and has_card:
			var selected_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.011)
			var sr := Rect2(Vector2(1, 1), size - Vector2(2, 2))
			draw_rect(sr.grow(-1.0), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.08 + 0.10 * selected_pulse), true)
			draw_rect(sr.grow(-1.0), C_GOLD, false, 3.0)
			draw_rect(sr.grow(-5.0), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.35 + 0.35 * selected_pulse), false, 1.0)
		if drop_preview != "":
			var preview_style := MechanicStyle.family_style(
				"sacrifice" if drop_preview in ["devour", "sigil"] else
				("mech" if drop_preview in ["magnet", "mech_merge", "mech_upgrade"] else "neutral")
			)
			var preview_color: Color = Color(preview_style.get("color", C_GOLD))
			if drop_preview == "invalid":
				preview_color = Color("ff4d4d")
			elif drop_preview == "place":
				preview_color = C_GOLD
			var preview_pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.014)
			var pr := Rect2(Vector2(1, 1), size - Vector2(2, 2))
			draw_rect(pr.grow(-1.0), Color(preview_color.r, preview_color.g, preview_color.b,
				0.12 + 0.20 * preview_pulse), true)
			draw_rect(pr.grow(-1.0), preview_color, false, 3.0)
			draw_rect(pr.grow(-5.0), Color(preview_color.r, preview_color.g, preview_color.b,
				0.45 + 0.45 * preview_pulse), false, 1.0)
			if drop_preview == "devour":
				var center := size * 0.5
				draw_arc(center, 20.0 + 7.0 * preview_pulse, 0.0, TAU, 32,
					Color(1.0, 0.16, 0.18, 0.42 + 0.42 * preview_pulse), 2.0)
			if drop_preview == "invalid" and has_card:
				draw_line(Vector2(pr.position.x + 8.0, pr.position.y + 8.0),
					Vector2(pr.end.x - 8.0, pr.end.y - 8.0), Color(1.0, 0.2, 0.2, 0.9), 2.0)
				draw_line(Vector2(pr.end.x - 8.0, pr.position.y + 8.0),
					Vector2(pr.position.x + 8.0, pr.end.y - 8.0), Color(1.0, 0.2, 0.2, 0.9), 2.0)
		if has_card:
			var w: float = maxf(0.0, (size.x - 2.0) * hp_ratio)
			if w > 0.0:
				draw_rect(Rect2(Vector2(1, size.y - 4), Vector2(w, 3)), C_HP)
			if is_attacking:
				draw_rect(r, C_GOLD, false, 3.0)
			if is_hit:
				draw_rect(r, C_ATK, false, 3.0)
		if is_dead:
			draw_line(Vector2(r.position.x + 4.0, r.position.y + 4.0),
				Vector2(r.end.x - 4.0, r.end.y - 4.0), C_ATK, 2.0)
			draw_line(Vector2(r.end.x - 4.0, r.position.y + 4.0),
				Vector2(r.position.x + 4.0, r.end.y - 4.0), C_ATK, 2.0)
	func _layered_outline(r: Rect2, edge: Color, inner: Color, outer: Color) -> void:
		draw_rect(r, outer, false, 1.0)
		draw_rect(Rect2(r.position + Vector2.ONE, r.size - Vector2(2, 2)), inner, false, 1.0)
		draw_rect(Rect2(r.position + Vector2.ONE * 2.0, r.size - Vector2(4, 4)), edge, false, 2.0)
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
	var label := "备战 50s"
	var burning := false
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 10)
		var lbl := Label.new()
		lbl.name = "txt"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_font_override("font", UiTheme.cjk_font_bold())
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lbl)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.06, 0.06, 0.1, 0.9), true)
		var w: float = maxf(0.0, r.size.x * left_ratio)
		if w > 0.0:
			if burning:
				_gradient(Rect2(0, 0, w, r.size.y), Color("ff6b6b"), Color("fdcb6e"), Color("ff6b6b"))
			else:
				_gradient(Rect2(0, 0, w, r.size.y), Color("7bed9f"), Color("55efc4"), Color("55efc4"))
		draw_rect(r, Color("ff6b6b") if burning else Color("2d3047"), false, 1.0)
		var lbl := get_node_or_null("txt") as Label
		if lbl != null:
			lbl.text = label
			lbl.add_theme_color_override("font_color", Color("ff9c9c") if burning else Color.WHITE)
			lbl.add_theme_stylebox_override("normal", _text_bg())
			lbl.reset_size()
			lbl.position = Vector2(size.x - 6.0 - lbl.size.x, -4.0)
	func _gradient(r: Rect2, left: Color, middle: Color, right: Color) -> void:
		var mid := r.position.x + r.size.x * 0.5
		draw_polygon(PackedVector2Array([
			r.position, Vector2(mid, r.position.y), Vector2(mid, r.end.y),
			Vector2(r.position.x, r.end.y),
		]), PackedColorArray([left, middle, middle, left]))
		draw_polygon(PackedVector2Array([
			Vector2(mid, r.position.y), Vector2(r.end.x, r.position.y),
			Vector2(r.end.x, r.end.y), Vector2(mid, r.end.y),
		]), PackedColorArray([middle, right, right, middle]))
	func _text_bg() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.06, 0.06, 0.1, 0.85)
		s.set_corner_radius_all(3)
		s.set_content_margin_all(2)
		return s

## 种族/关键词小图标：保持 Web SVG 的 12px 内联尺寸，避免 emoji 字体改变基线。
class CardGlyph extends Control:
	var kind := ""
	func _ready() -> void:
		custom_minimum_size = Vector2(12, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		match kind:
			"mech":
				var blue := Color("74b9ff")
				var points := PackedVector2Array([
					Vector2(6.0, 0.75), Vector2(7.5, 2.25), Vector2(9.75, 2.25),
					Vector2(10.5, 4.5), Vector2(9.0, 6.0), Vector2(10.5, 7.5),
					Vector2(9.75, 9.75), Vector2(7.5, 9.75), Vector2(6.0, 11.25),
					Vector2(4.5, 9.75), Vector2(2.25, 9.75), Vector2(1.5, 7.5),
					Vector2(3.0, 6.0), Vector2(1.5, 4.5), Vector2(2.25, 2.25),
					Vector2(4.5, 2.25), Vector2(6.0, 0.75),
				])
				draw_polyline(points, blue, 1.05, true)
				draw_circle(Vector2(6.0, 6.0), 1.5, blue)
			"sacrifice":
				var purple := Color("a29bfe")
				draw_rect(Rect2(5.25, 0.75, 1.5, 10.5), purple)
				draw_circle(Vector2(6.0, 2.625), 0.975, Color("ffeaa7"))
				draw_rect(Rect2(3.0, 4.5, 6.0, 1.125), purple)
				draw_rect(Rect2(2.25, 7.5, 7.5, 1.35), purple)
				draw_rect(Rect2(3.75, 9.75, 4.5, 1.125), purple)
			"shield":
				var shield := PackedVector2Array([
					Vector2(6.0, 0.75), Vector2(10.5, 2.25), Vector2(10.5, 6.0),
					Vector2(6.0, 11.25), Vector2(1.5, 6.0), Vector2(1.5, 2.25),
					Vector2(6.0, 0.75),
				])
				draw_polyline(shield, Color("b9d7ff"), 1.0, true)
