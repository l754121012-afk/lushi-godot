extends SceneTree
## 磁力喂料自检：godot --headless --path <项目> --script res://tools/prep_test.gd

const Prep := preload("res://sim/prep.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_basic()
	_case_with_support()
	_case_titan_and_core()
	_case_repair_support()
	if fails.is_empty():
		print("[prep_test] 通过：磁力喂料基础/支援加成/泰坦与核心/维修输送车 4/4")
		quit(0)
	else:
		for f in fails:
			printerr("[prep_test] 失败：", f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _case_basic() -> void:
	# 材料牌 magA/magH 转移给目标，关键词一并转移
	var mat := {"n": "装甲模块", "magA": 4, "magH": 6, "magK": "t"}
	var target := {"n": "磁力底盘", "a": 4, "h": 10, "mh": 10, "k": "w"}
	var r := Prep.magnet_feed(mat, target, [], {})
	_check(int(r["a"]) == 4 and int(r["h"]) == 6, "基础喂料应为 4/6，实际 %d/%d" % [int(r["a"]), int(r["h"])])
	_check(int(target["a"]) == 8 and int(target["h"]) == 16, "目标应变为 8/16，实际 %d/%d" % [int(target["a"]), int(target["h"])])
	_check(int(target["mh"]) == 16, "生命上限应同步 +6")
	_check(String(target["k"]) == "wt", "关键词应合并为 wt，实际 %s" % String(target["k"]))
	print("[prep_test] 用例1 基础: 目标=", target["a"], "/", target["h"], " k=", target["k"])

func _case_with_support() -> void:
	# 磁暴重臂：攻击 ×2；超导装配中枢：数值 ×1.5
	var mat := {"n": "超载模块", "magA": 6, "magH": 6}
	var target := {"n": "机械泰坦", "a": 18, "h": 32, "mh": 32, "k": ""}
	var board := [{"n": "磁暴重臂", "a": 16, "h": 12}, {"n": "超导装配中枢", "a": 8, "h": 12}]
	var r := Prep.magnet_feed(mat, target, board, {})
	# a = 6*2=12 → ×1.5 = 18；h = 6*1.5 = 9
	_check(int(r["a"]) == 18 and int(r["h"]) == 9, "支援加成后应为 18/9，实际 %d/%d" % [int(r["a"]), int(r["h"])])
	# 泰坦加成看的是"场上是否有机械泰坦"，本用例场上没有，故不加成（与 Web 的 has("机械泰坦") 一致）
	_check(int(target["a"]) == 36, "无泰坦在场时目标攻击应为 36，实际 %d" % int(target["a"]))
	print("[prep_test] 用例2 支援加成: 转移=", r["a"], "/", r["h"], " 目标攻击=", target["a"])

func _case_titan_and_core() -> void:
	# 统御核心：每次喂料 modGrow +1（金卡 +2）
	var mat := {"n": "装甲模块", "magA": 4, "magH": 6}
	var target := {"n": "核心学徒", "a": 4, "h": 5, "mh": 5}
	var core := {"n": "统御核心", "a": 14, "h": 18, "modGrow": 4}
	var gold_core := {"n": "统御核心", "a": 14, "h": 18, "modGrow": 4, "g": true}
	var r := Prep.magnet_feed(mat, target, [core, gold_core], {"matBoostA": 2, "matBoostH": 0})
	_check(int(r["a"]) == 6 and int(r["h"]) == 6, "带 matBoost 时应为 6/6，实际 %d/%d" % [int(r["a"]), int(r["h"])])
	_check(int(core["modGrow"]) == 5, "普通统御核心应 +1，实际 %d" % int(core["modGrow"]))
	_check(int(gold_core["modGrow"]) == 6, "金统御核心应 +2，实际 %d" % int(gold_core["modGrow"]))
	print("[prep_test] 用例3 核心成长: 核心 modGrow=", core["modGrow"], " 金核心=", gold_core["modGrow"])

func _case_repair_support() -> void:
	var titan_mat := {"n": "装甲模块", "magA": 10, "magH": 0}
	var titan_target := {"n": "磁力底盘", "a": 4, "h": 10, "mh": 10}
	var titan_board := [{"n": "机械泰坦", "a": 18, "h": 32}]
	var titan_res := Prep.magnet_feed(titan_mat, titan_target, titan_board, {})
	_check(int(titan_res["a"]) == 10 and int(titan_target["a"]) == 17,
		"机械泰坦应让本次转移攻击 +30%%，实际 transfer=%d targetA=%d" % [
			int(titan_res["a"]), int(titan_target["a"])])

	var repair_mat := {"n": "装甲模块", "magA": 0, "magH": 10}
	var repair_target := {"n": "维修目标", "a": 4, "h": 100, "mh": 100}
	var repair_board := [{"n": "维修输送车", "a": 5, "h": 9}]
	var repair_res := Prep.magnet_feed(repair_mat, repair_target, repair_board,
		{"mechLevel": 2})
	_check(int(repair_res["mechRepair"]) == 24,
		"维修输送车应按 8+8+8 累积 24 护甲，实际 %d" % int(repair_res["mechRepair"]))
	print("[prep_test] 用例4 泰坦与维修: TitanTarget=", titan_target["a"],
		" repair=", repair_res["mechRepair"])
