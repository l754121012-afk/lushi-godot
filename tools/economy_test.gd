extends SceneTree
## 经济自检：godot --headless --path <项目> --script res://tools/economy_test.gd

const Economy := preload("res://sim/economy.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_level_cost()
	_case_income()
	_case_interest()
	if fails.is_empty():
		print("[economy_test] 通过：升级花费 / 回合收入 / 连胜连败利息 3/3")
		quit(0)
	else:
		for f in fails:
			printerr("[economy_test] 失败：", f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _case_level_cost() -> void:
	_check(Economy.level_up_cost(1) == 6, "升 2 级应花 6，实际 %d" % Economy.level_up_cost(1))
	_check(Economy.level_up_cost(6) == 16, "升 7 级应花 16，实际 %d" % Economy.level_up_cost(6))
	_check(Economy.level_up_cost(7) == 0, "满级后应为 0（不可再升）")
	_check(Economy.can_level_up(1, 5) == false and Economy.can_level_up(1, 6) == true, "金币判定错误")
	print("[economy_test] 用例1 升级花费: L1→", Economy.level_up_cost(1), " L6→", Economy.level_up_cost(6), " 刷新=", Economy.refresh_cost())

func _case_income() -> void:
	var r1 := Economy.round_income(1)
	var r5 := Economy.round_income(5)
	_check(r1 == Economy.round_base_gold(1) and r1 > 0, "第 1 回合收入应等于基础值且 >0，实际 %d" % r1)
	_check(r5 >= r1, "后期回合基础金币不应低于前期（R1=%d R5=%d）" % [r1, r5])
	_check(Economy.round_income(3, 2, 0) == Economy.round_base_gold(3) + Economy.streak_interest(2, 0), "连胜利息没有并入收入")
	_check(Economy.round_income(3, 0, 0, 2) == Economy.round_base_gold(3) + 2, "节奏奖励没有并入收入")
	print("[economy_test] 用例2 回合收入: R1=", r1, " R5=", r5, " R3+2连胜=", Economy.round_income(3, 2, 0), " R3+节奏2=", Economy.round_income(3, 0, 0, 2))

func _case_interest() -> void:
	var i1 := Economy.streak_interest(1, 0)
	var i3 := Economy.streak_interest(3, 0)
	var l3 := Economy.streak_interest(0, 3)
	_check(i1 > 0, "1 连胜应有正利息，实际 %d" % i1)
	_check(i3 >= i1, "连胜越高利息不应越低（1=%d 3=%d）" % [i1, i3])
	_check(l3 > 0, "连败也应有正利息（安抚机制），实际 %d" % l3)
	_check(Economy.streak_interest(0, 0) == 0, "无连胜连败时利息应为 0")
	print("[economy_test] 用例3 利息: 1连胜=", i1, " 3连胜=", i3, " 3连败=", l3)
