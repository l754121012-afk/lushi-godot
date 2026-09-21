extends SceneTree
## 三连金卡自检：godot --headless --path <项目> --script res://tools/gild_test.gd

const Gild := preload("res://sim/gild.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_merge()
	_case_golden_stats()
	_case_no_merge_with_golden()
	if fails.is_empty():
		print("[gild_test] 通过：三连判定 / 金卡翻倍 / 金卡不参与三连 3/3")
		quit(0)
	else:
		for f in fails:
			printerr("[gild_test] 失败：", f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _cell() -> Dictionary:
	return {"n": "细胞体", "a": 1, "h": 2, "s": 1, "race": "evolve", "sk": {"t": "attack", "e": "evolve-step", "need": 3, "a": 4, "h": 4}}

func _case_merge() -> void:
	var cards: Array = [_cell(), {"n": "别的牌", "a": 1, "h": 1}, _cell(), _cell(), null]
	var res := Gild.merge_in_place(cards)
	_check(bool(res["ok"]), "三张同名应可合成")
	_check(String(res["name"]) == "细胞体", "合成对象应为 细胞体，实际 %s" % String(res["name"]))
	_check(bool(cards[0].get("g", false)), "合成后第 1 格应为金卡")
	_check(cards[2] == null and cards[3] == null, "另外两张应被清空")
	print("[gild_test] 用例1 三连判定: 合成=", res["name"], " 下标=", res["indices"])

func _case_golden_stats() -> void:
	var g := Gild.gild(_cell())
	_check(int(g["a"]) == 2 and int(g["h"]) == 4, "金卡身材应翻倍为 2/4，实际 %d/%d" % [int(g["a"]), int(g["h"])])
	_check(int(g["sk"]["a"]) == 8 and int(g["sk"]["h"]) == 8, "金卡技能数值应翻倍为 8/8，实际 %d/%d" % [int(g["sk"]["a"]), int(g["sk"]["h"])])
	_check(int(g["sk"]["need"]) == 3, "进化所需格数不应被翻倍（Web 也不翻倍），实际 %d" % int(g["sk"]["need"]))
	print("[gild_test] 用例2 金卡翻倍: 身材=", g["a"], "/", g["h"], " 技能=+", g["sk"]["a"], "/+", g["sk"]["h"], " need=", g["sk"]["need"])

func _case_no_merge_with_golden() -> void:
	var gold := Gild.gild(_cell())
	var cards: Array = [_cell(), _cell(), gold, null]
	var res := Gild.try_merge(cards)
	_check(not bool(res["ok"]), "金卡不应再参与三连")
	var two: Array = [_cell(), _cell(), null]
	_check(not bool(Gild.try_merge(two)["ok"]), "两张不应合成")
	print("[gild_test] 用例3 金卡不参与: 结果=", res["ok"])
