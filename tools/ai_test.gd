extends SceneTree
## AI 运营决策自检：godot --headless --path <项目> --script res://tools/ai_test.gd

const AI := preload("res://sim/ai.gd")
const PrepState := preload("res://sim/prep_state.gd")
const Economy := preload("res://sim/economy.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_buy()
	_case_level_up()
	_case_save_gold()
	_case_template_core()
	_case_mech_material()
	_case_full_board_replacement()
	_case_preserve_accumulated_board()
	_case_dynamic_level()
	_case_cast_spell()
	_case_midgame_composition()
	_case_growth_curve()
	if fails.is_empty():
		print("[ai_test] 通过：买牌 / 升级 / 攒钱 / 模板核心 / 机械材料 / 满场换强 / 保留积累 / 动态升级 / 施法 / 中期阵容 / 成长曲线 11/11")
		quit(0)
	else:
		for f in fails:
			printerr("[ai_test] 失败：", f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _pool() -> Dictionary:
	var pool := {}
	for star in range(1, 8):
		var list: Array = []
		for i in range(6):
			list.append({"n": "M%d-%d" % [star, i], "a": star, "h": star, "race": "mech"})
		pool[star] = list
	return pool

func _new_state(gold: int, level: int) -> Variant:
	var ps = PrepState.new()
	ps.setup(5, ["mech"], _pool(), [], 424242)
	ps.shop_bias_enabled = false
	ps.gold = gold
	ps.level = level
	return ps

func _case_buy() -> void:
	var ps = _new_state(10, 1)
	ps.shop[0] = {"n": "M3-0", "a": 3, "h": 3, "star": 3, "race": "mech"}
	var action: Array = AI.plan_turn(ps, ["mech"], 4)
	# 10 金 / 1 级：升级(6)后仍留得下买牌钱，所以先升级也合理；关键是别空转
	_check(action.size() >= 1 and (String(action[0]) == "buy" or String(action[0]) == "level_up"),
		"有钱又有本族牌时应买牌或升级，实际 %s" % str(action))
	var done := AI.run_turn(ps, ["mech"], 4, 4)
	_check(ps.hand.size() > 0 or ps.board.size() > 0, "AI 跑完一轮后应至少拿到牌或上场")
	print("[ai_test] 用例1 会买牌: 决策=", action, " 执行=", done, " 金币=", ps.gold)

func _case_level_up() -> void:
	var early = _new_state(30, 1)
	early.round_no = 1
	early.board[0] = {"n": "M3-0", "a": 3, "h": 3, "star": 3, "race": "mech"}
	for i in range(early.shop.size()):
		early.shop[i] = {"n": "早期离阵%d" % i, "a": 1, "h": 1, "star": 1, "race": "elem"}
	var early_action: Array = AI.plan_turn(early, ["mech"], 4)
	_check(early_action.is_empty() or String(early_action[0]) != "level_up",
		"第1回合场上不足时 AI 不应空场抢升级，实际 %s" % str(early_action))

	var ps = _new_state(30, 1)
	ps.hand = []
	ps.board[0] = {"n": "M3-0", "a": 3, "h": 3, "star": 3, "race": "mech"}
	ps.board[1] = {"n": "M3-1", "a": 3, "h": 3, "star": 3, "race": "mech"}
	for i in range(ps.shop.size()):
		ps.shop[i] = {"n": "M1-%d" % i, "a": 1, "h": 1, "star": 1, "race": "elem"}   # 非本族，逼它先升级
	var action: Array = AI.plan_turn(ps, ["mech"], 4)
	_check(action.size() == 1 and String(action[0]) == "level_up", "钱多且非本族牌时应升级，实际 %s" % str(action))
	var done := AI.run_turn(ps, ["mech"], 4, 2)
	_check(ps.level >= 2, "AI 应至少升到 2 级，实际 %d" % ps.level)
	print("[ai_test] 用例2 会升级: 决策=", action, " 执行=", done, " 等级=", ps.level, " 金币=", ps.gold)

func _case_save_gold() -> void:
	var ps = _new_state(0, 1)
	for i in range(ps.shop.size()):
		ps.shop[i] = {"n": "M2-%d" % i, "a": 2, "h": 2, "star": 2, "race": "mech"}
	var action: Array = AI.plan_turn(ps, ["mech"], 4)
	_check(action.is_empty(), "零金币时不应乱花钱，实际 %s" % str(action))
	print("[ai_test] 用例3 没钱不乱花: 决策=", action)

func _case_template_core() -> void:
	var ps = _new_state(10, 4)
	ps.round_no = 1
	ps.shop[0] = {"n": "元素路人", "a": 3, "h": 3, "star": 3, "race": "elem"}
	ps.shop[1] = {"n": "磁力底盘", "a": 1, "h": 1, "star": 1, "race": "mech", "part": "core"}
	var templates := [{
		"name": "机械模板", "races": ["mech"], "core": ["磁力底盘"],
		"good": ["核心学徒"], "fill": [],
	}]
	var action: Array = AI.plan_turn(ps, ["mech", "elem"], 4, templates)
	_check(action.size() == 2 and String(action[0]) == "buy" and int(action[1]) == 1,
		"AI 没有按模板优先买核心牌，实际 %s" % str(action))
	print("[ai_test] 用例4 模板核心: 决策=", action)

func _case_mech_material() -> void:
	var ps = _new_state(10, 4)
	ps.round_no = 4
	ps.board[0] = {"n": "磁力底盘", "a": 2, "h": 3, "star": 2, "race": "mech", "part": "core"}
	ps.shop[0] = {"n": "装甲模块", "a": 2, "h": 2, "star": 1, "race": "mech",
		"material": true, "magA": 3, "magH": 3}
	var action: Array = AI.plan_turn(ps, ["mech"], 4)
	_check(action.size() == 2 and String(action[0]) == "buy" and int(action[1]) == 0,
		"AI 没有为机械阵容购买磁力材料，实际 %s" % str(action))
	print("[ai_test] 用例5 机械材料: 决策=", action)

func _case_full_board_replacement() -> void:
	var ps = _new_state(10, 4)
	ps.round_no = 4
	for i in range(ps.board.size()):
		ps.board[i] = {"n": "弱随从%d" % i, "a": 1, "h": 1, "star": 1, "race": "elem"}
	ps.shop[0] = {"n": "机械泰坦", "a": 12, "h": 12, "star": 6, "race": "mech", "part": "core"}
	var templates := [{
		"name": "机械模板", "races": ["mech"], "core": ["机械泰坦"],
		"good": [], "fill": [],
	}]
	var action: Array = AI.plan_turn(ps, ["mech", "elem"], 4, templates)
	_check(action.size() == 2 and String(action[0]) == "sell",
		"满场遇到高价值核心牌时 AI 不会卖弱换强，实际 %s" % str(action))
	print("[ai_test] 用例6 满场换人: 决策=", action)

func _case_preserve_accumulated_board() -> void:
	var ps = _new_state(3, 4)
	ps.round_no = 5
	ps.ai_plan = {"name": "机械测试", "races": ["mech"], "core": ["机械泰坦"], "good": [], "fill": []}
	for i in range(5):
		ps.board[i] = {"n": "机械主力%d" % i, "a": 8 + i, "h": 8 + i, "star": 4, "race": "mech"}
	ps.board[5] = {"n": "旧离阵甲", "a": 2, "h": 3, "star": 1, "race": "elem"}
	ps.board[6] = {"n": "旧离阵乙", "a": 2, "h": 3, "star": 1, "race": "demon"}
	for i in range(ps.shop.size()):
		ps.shop[i] = {"n": "低星离阵%d" % i, "a": 1, "h": 1, "star": 1, "race": "elem"}
	var action: Array = AI.plan_turn(ps, ["mech"], 4)
	var before_count := 0
	for card in ps.board:
		if card != null:
			before_count += 1
	AI.run_turn(ps, ["mech"], 4, 3)
	var after_count := 0
	for card in ps.board:
		if card != null:
			after_count += 1
	_check(action.is_empty() or String(action[0]) != "sell",
		"没有更强替代时 AI 不应主动卖掉已积累的离阵牌，实际 %s" % str(action))
	_check(after_count == before_count, "AI 在没有更强替代时拆掉了已积累阵容")
	print("[ai_test] 用例7 保留积累: 决策=", action, " 场上=", after_count)

func _case_dynamic_level() -> void:
	var ps = _new_state(30, 4)
	ps.round_no = 10
	for i in range(5):
		ps.board[i] = {
			"n": "M3-%d" % i, "a": 3, "h": 3, "star": 3, "race": "mech",
			"part": ["core", "head", "arm", "leg", "head"][i],
		}
	for i in range(ps.shop.size()):
		ps.shop[i] = {"n": "离阵牌%d" % i, "a": 1, "h": 1, "star": 1, "race": "elem"}
	var action: Array = AI.plan_turn(ps, ["mech"], 4)
	_check(action.size() == 1 and String(action[0]) == "level_up",
		"第 10 回合 AI 没有继续升级运营，实际 %s" % str(action))
	print("[ai_test] 用例8 动态升级: 决策=", action)

func _case_cast_spell() -> void:
	var ps = _new_state(10, 4)
	ps.round_no = 4
	ps.board[0] = {"n": "磁力底盘", "a": 2, "h": 3, "star": 2, "race": "mech", "part": "core"}
	ps.hand = [{"n": "王祝", "t": "s", "fx": "", "e": {"a": 3, "h": 3}, "x": "+3/+3"}]
	var action: Array = AI.plan_turn(ps, ["mech"], 4)
	_check(action.size() == 3 and String(action[0]) == "cast_spell" and int(action[2]) == 0,
		"AI 有目标时不会使用手牌法术，实际 %s" % str(action))
	print("[ai_test] 用例9 施法运营: 决策=", action)

func _case_midgame_composition() -> void:
	var races: Array = ["undead", "sacrifice", "star", "gambler", "mech", "elem"]
	var ps = PrepState.new()
	ps.setup(1, races, _real_pool(), _real_spells(), 20260927, {})
	ps.shop_bias_enabled = false
	var templates: Array = _real_templates()
	for round_no in range(1, 7):
		ps.round_no = round_no
		ps.gold = Economy.ai_round_income(round_no, 0, 0, 2)
		if round_no > 1:
			ps.roll_shop()
		ps.apply_prep_round_skills()
		AI.run_turn(ps, races, 4, 14, [], templates)
	var board_count := 0
	var total_power := 0
	var core_count := 0
	var plan_cards := 0
	var off_plan_count := 0
	var race_counts: Dictionary = {}
	var board_names: Array[String] = []
	var plan_races: Array = ps.ai_plan.get("races", [])
	for card in ps.board:
		if card == null:
			continue
		board_count += 1
		total_power += int(card.get("star", card.get("s", 1))) \
			+ (2 if bool(card.get("g", false)) else 0)
		var race := String(card.get("race", ""))
		race_counts[race] = int(race_counts.get(race, 0)) + 1
		board_names.append("%s%s%d★" % [
			"金" if bool(card.get("g", false)) else "",
			String(card.get("n", "?")),
			int(card.get("star", card.get("s", 1))),
		])
		if race == "" or race == "neutral" or plan_races.has(race):
			plan_cards += 1
		else:
			off_plan_count += 1
		for template in templates:
			if Array(template.get("core", [])).has(String(card.get("n", ""))):
				core_count += 1
	var avg_power := float(total_power) / float(maxi(1, board_count))
	var max_race := 0
	for count in race_counts.values():
		max_race = maxi(max_race, int(count))
	_check(ps.level >= 4, "第6回合 AI 等级过低，实际 Lv%d" % ps.level)
	_check(board_count >= 6, "第6回合 AI 场上随从过少，实际 %d" % board_count)
	_check(avg_power >= 2.25, "第6回合 AI 平均战力星级过低，实际 %.2f" % avg_power)
	_check(off_plan_count == 0, "第6回合 AI 仍有 %d 张离阵散牌" % off_plan_count)
	_check(plan_cards == board_count, "第6回合 AI 阵容没有全部落在锁定计划内")
	print("[ai_test] 用例10 中期运营: 计划=%s Lv%d 场%d 平均战力星%.2f 主族%d 计划内%d 离阵%d 核心%d %s %s" % [
		String(ps.ai_plan.get("name", "?")), ps.level, board_count, avg_power, max_race,
		plan_cards, off_plan_count, core_count, str(race_counts),
		",".join(board_names)])

func _case_growth_curve() -> void:
	var races: Array = ["undead", "sacrifice", "star", "gambler", "mech", "elem"]
	var ps = PrepState.new()
	ps.setup(1, races, _real_pool(), _real_spells(), 20260927, {})
	ps.shop_bias_enabled = false
	var stages: Dictionary = {}
	for round_no in range(1, 17):
		ps.round_no = round_no
		ps.gold = Economy.ai_round_income(round_no, 0, 0, 2)
		if round_no > 1:
			ps.roll_shop()
		ps.apply_prep_round_skills()
		AI.run_turn(ps, races, 4, 40, [], _real_templates())
		if round_no in [4, 6, 8, 10, 12, 16]:
			var board_count := 0
			var total := 0
			var stars := 0
			for card in ps.board:
				if card == null:
					continue
				board_count += 1
				total += int(card.get("a", 0)) + int(card.get("h", 0))
				stars += int(card.get("star", card.get("s", 1)))
			stages[round_no] = {
				"level": ps.level,
				"gold": ps.gold,
				"board": board_count,
				"total": total,
				"avg_star": snappedf(float(stars) / float(maxi(1, board_count)), 0.01),
			}
	_check(int(stages[6]["level"]) >= 4 and int(stages[6]["board"]) >= 7 and int(stages[6]["total"]) >= 80,
		"R6 成长曲线过低：%s" % str(stages[6]))
	_check(int(stages[10]["level"]) >= 6 and int(stages[10]["board"]) >= 6 and int(stages[10]["total"]) >= 130,
		"R10 成长曲线过低：%s" % str(stages[10]))
	_check(int(stages[12]["level"]) >= 7 and int(stages[12]["board"]) >= 7 and int(stages[12]["total"]) >= 180,
		"R12 成长曲线过低：%s" % str(stages[12]))
	_check(int(stages[16]["board"]) >= 7 and int(stages[16]["total"]) >= 260,
		"R16 成长曲线过低：%s" % str(stages[16]))
	print("[ai_test] 成长曲线: R4=%s R6=%s R8=%s R10=%s R12=%s R16=%s" % [
		str(stages[4]), str(stages[6]), str(stages[8]), str(stages[10]),
		str(stages[12]), str(stages[16])])

func _load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _real_pool() -> Dictionary:
	var pool: Dictionary = {}
	var doc := _load_json("res://data/cards.json")
	for tier in doc.get("tiers", []):
		pool[int(tier.get("star", 0))] = Array(tier.get("cards", [])).duplicate(true)
	return pool

func _real_spells() -> Array:
	return Array(_load_json("res://data/ai_templates.json").get("spells", [])).duplicate(true)

func _real_templates() -> Array:
	return Array(_load_json("res://data/ai_templates.json").get("templates", [])).duplicate(true)
