extends SceneTree
## AI 运营决策自检：godot --headless --path <项目> --script res://tools/ai_test.gd

const AI := preload("res://sim/ai.gd")
const PrepState := preload("res://sim/prep_state.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_buy()
	_case_level_up()
	_case_save_gold()
	if fails.is_empty():
		print("[ai_test] 通过：会买牌 / 会升级 / 没钱不乱花 3/3")
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
	var ps = _new_state(30, 1)
	ps.hand = []
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
