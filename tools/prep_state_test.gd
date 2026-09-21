extends SceneTree
## 备战状态机自检：godot --headless --path <项目> --script res://tools/prep_state_test.gd

const PrepState := preload("res://sim/prep_state.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_buy_and_place()
	_case_economy()
	_case_feed_and_fusion()
	if fails.is_empty():
		print("[prep_state_test] 通过：买牌上场 / 经济与升级 / 喂料与合体 3/3")
		quit(0)
	else:
		for f in fails:
			printerr("[prep_state_test] 失败：", f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _pool() -> Dictionary:
	var pool := {}
	for star in range(1, 8):
		var list: Array = []
		for i in range(6):
			list.append({"n": "M%d-%d" % [star, i], "a": star, "h": star, "race": "mech",
				"part": "core" if i == 0 else ("head" if i == 1 else ("arm" if i == 2 else ("leg" if i == 3 else ""))) if star == 3 else "",
				"magA": 2, "magH": 2} if i == 5 else {"n": "M%d-%d" % [star, i], "a": star, "h": star, "race": "mech"})
		pool[star] = list
	return pool

func _case_buy_and_place() -> void:
	var ps = PrepState.new()
	ps.setup(3, ["mech"], _pool(), [], 123)
	_check(ps.shop.size() == 5, "商店应有 5 格")
	var gold_before: int = ps.gold
	var _cost_before: int = ps.buy_cost(ps.shop[0])
	var r := ps.buy(0)
	_check(bool(r["ok"]), "第一格应买得起（金币 %d，价格 %d）" % [gold_before, _cost_before])
	_check(ps.hand.size() == 1, "买完手牌应有 1 张")
	_check(ps.gold == gold_before - int(r.get("cost", 0)), "金币扣减不对")
	var placed := ps.place(0, 0)
	_check(placed and ps.board[0] != null and ps.hand.is_empty(), "上场应把手牌放到 0 号格")
	print("[prep_state_test] 用例1 买牌上场: 金币=", gold_before, "→", ps.gold, " 手牌=", ps.hand.size(), " 棋盘0=", ps.board[0]["n"])

func _case_economy() -> void:
	var ps = PrepState.new()
	ps.setup(5, ["mech"], _pool(), [], 7)
	var income: int = ps.gold
	ps.gold = 0
	ps.reroll()
	_check(ps.gold == 0 or ps.gold == -1, "没钱的刷新不应扣成负数")
	ps.gold = 100
	var lv_before: int = ps.level
	var ok := ps.level_up()
	_check(ok and ps.level == lv_before + 1, "升级应生效")
	_check(ps.gold == 100 - 6, "升 2 级应花 6，剩余 %d" % ps.gold)
	print("[prep_state_test] 用例2 经济与升级: 回合收入=", income, " 升级后 Lv=", ps.level, " 金币=", ps.gold)

func _case_feed_and_fusion() -> void:
	var ps = PrepState.new()
	ps.setup(4, ["mech"], _pool(), [], 55)
	# 手牌放一张材料牌（magA/magH）与一张机械目标，喂料后目标应成长
	ps.hand = [{"n": "装甲模块", "star": 4, "magA": 4, "magH": 6}]
	ps.board[0] = {"n": "磁力底盘", "a": 4, "h": 10, "mh": 10, "k": "t", "race": "mech", "part": "core"}
	var r := ps.feed(0, 0)
	_check(bool(r["ok"]), "材料牌应能喂给机械")
	_check(int(ps.board[0]["a"]) == 8 and int(ps.board[0]["h"]) == 16, "喂料后应为 8/16，实际 %d/%d" % [int(ps.board[0]["a"]), int(ps.board[0]["h"])])
	# 合体区判定：core + head/arm/leg
	ps.board[1] = {"n": "核心学徒", "a": 4, "h": 5, "race": "mech", "part": "head"}
	ps.board[2] = {"n": "磁能臂", "a": 8, "h": 4, "race": "mech", "part": "arm", "k": "w"}
	ps.board[3] = {"n": "推进肢体", "a": 3, "h": 12, "race": "mech", "part": "leg", "k": "t"}
	_check(ps.has_formation(), "四部位齐了应判定可合体")
	var prep := ps.prepare_fusion(2, 0, 0)
	_check(bool(prep.get("ok", false)), "合体准备应成功")
	_check(String(ps.board[1]["n"]) == "磁暴僚机", "合体后 1 号位应是协同随从")
	print("[prep_state_test] 用例3 喂料与合体: 喂料后=", 8, "/", 16, " 合体判定=", prep["ok"], " 一号位=", ps.board[1]["n"])
