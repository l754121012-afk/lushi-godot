extends SceneTree
## 合体自检：godot --headless --path <项目> --script res://tools/fusion_test.gd

const Fusion := preload("res://sim/fusion.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_body()
	_case_summons()
	_case_no_formation()
	if fails.is_empty():
		print("[fusion_test] 通过：合体区判定 / 四部位继承 / 协同随从 3/3")
		quit(0)
	else:
		for f in fails:
			printerr("[fusion_test] 失败：", f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _parts() -> Array:
	return [
		{"n": "磁力底盘", "a": 4, "h": 10, "s": 3, "race": "mech", "part": "core", "k": "t", "chargeMax": 3, "chargeFx": "shield"},
		{"n": "核心学徒", "a": 4, "h": 5, "s": 3, "race": "mech", "part": "head", "modGrow": 1, "chargeMax": 2, "chargeFx": "buff"},
		{"n": "磁能臂", "a": 8, "h": 4, "s": 3, "race": "mech", "part": "arm", "k": "w", "chargeMax": 2, "chargeFx": "rally"},
		{"n": "推进肢体", "a": 3, "h": 12, "s": 3, "race": "mech", "part": "leg", "k": "t", "chargeMax": 3, "chargeFx": "heal"},
	]

func _case_body() -> void:
	var parts := _parts()
	var body := Fusion.build_body(parts, 4, 0)
	_check(int(body["a"]) == 19, "合体攻击应为 4+4+8+3=19，实际 %d" % int(body["a"]))
	_check(int(body["h"]) == 31, "合体生命应为 10+5+4+12=31，实际 %d" % int(body["h"]))
	_check(int(body["mh"]) == 31, "合体生命上限应为 31，实际 %d" % int(body["mh"]))
	_check(String(body["k"]) == "tw", "关键词应取并集 tw，实际 %s" % String(body["k"]))
	_check(int(body["_mechHeadGrow"]) == 1, "头部成长应为 1")
	_check(int(body["s"]) == 3, "星级应为 1+floor(4/2)=3，实际 %d" % int(body["s"]))
	print("[fusion_test] 用例1 合体体: ", body["a"], "/", body["h"], " k=", body["k"], " s=", body["s"])

func _case_summons() -> void:
	var body := Fusion.build_body(_parts(), 4, 0, 9001)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260924
	var su := Fusion.summons_for(body, 4, rng)
	_check(su.size() == 3, "协同随从应为 3 个")
	var ba: int = int(body["a"])
	var bh: int = int(body["h"])
	var expected := {
		"strike": [max(4, int(round(float(ba) * 0.45))) + 4, max(6, int(round(float(bh) * 0.3))) + 4],
		"repair": [max(3, int(round(float(ba) * 0.25))) + 4, max(8, int(round(float(bh) * 0.4))) + 4],
		"guard": [max(4, int(round(float(ba) * 0.3))) + 4, max(10, int(round(float(bh) * 0.5))) + 4],
	}
	var seen_types := {}
	for i in range(su.size()):
		var kind := String(su[i]["_followType"])
		seen_types[kind] = true
		_check(expected.has(kind), "协同随从类型越界：%s" % kind)
		if expected.has(kind):
			_check(int(su[i]["a"]) == expected[kind][0] and int(su[i]["h"]) == expected[kind][1],
				"协同随从数值应匹配 %s 公式，实际 %d/%d" % [kind, int(su[i]["a"]), int(su[i]["h"])])
		_check(int(su[i]["_followBodyId"]) == int(body["id"]), "协同随从应绑定合体体 id")
	_check(seen_types.size() >= 1, "协同随从应至少抽到 1 种类型")
	print("[fusion_test] 用例2 协同随从: ", su[0]["a"], "/", su[0]["h"], " | ", su[1]["a"], "/", su[1]["h"], " | ", su[2]["a"], "/", su[2]["h"])

func _case_no_formation() -> void:
	var board: Array = [null, null, null, null, null, null, null]
	_check(Fusion.find_formation(board) == -1, "空棋盘不应判定为合体")
	var parts := _parts()
	var no_core := [parts[1], parts[2], parts[3], null, null, null, null]
	_check(Fusion.find_formation(no_core) == -1, "没有首脑不应判定为合体")
	var ok_board := [parts[0], parts[1], parts[2], parts[3], null, null, null]
	_check(Fusion.find_formation(ok_board) == 0, "标准四部位应判定为合体")
	var moved := [null, parts[0], parts[1], parts[2], parts[3], null, null]
	_check(Fusion.find_formation(moved) == 1, "整体后移一格也应判定（合体区不锁定前四格）")
	var prepared := Fusion.prepare(ok_board, 4, 6, 12, 20260924, 9002, 90020)
	_check(bool(prepared["ok"]), "合体准备失败")
	_check(int(prepared["armor"]) == 12, "维修护甲应带入战斗")
	_check(String(prepared["board"][1].get("_followType", "")) != "", "合体后第 2 格应替换为协同随从")
	_check(int(prepared["board"][1]["_followBodyId"]) == int(prepared["body"]["id"]), "合体后协同随从应绑定合体体")
	print("[fusion_test] 用例3 判定与替换: 合体区起点=", prepared["index"], " 护甲=", prepared["armor"], " 二号位=", prepared["board"][1]["n"])
