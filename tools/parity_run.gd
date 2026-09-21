extends SceneTree
## 一致性对照（Godot 侧）：读取 tests/scenarios.json，跑战斗内核并把结果写到 tests/out/godot.json
## 用法：godot --headless --path <项目> --script res://tools/parity_run.gd

const UnitScript := preload("res://sim/unit.gd")
const BattleScript := preload("res://sim/battle.gd")

func _init() -> void:
	var text := FileAccess.get_file_as_string("res://tests/scenarios.json")
	var doc = JSON.parse_string(text)
	if typeof(doc) != TYPE_DICTIONARY:
		printerr("[parity] scenarios.json 解析失败")
		quit(1)
		return

	var results: Array = []
	for sc in doc.get("scenarios", []):
		var p_board := _build(sc.get("p", []))
		var e_board := _build(sc.get("e", []))
		var battle = BattleScript.new()
		var r: Dictionary = battle.resolve(p_board, e_board, int(sc.get("seed", 1)))
		results.append(_summary(sc, r, p_board, e_board))

	var out := {"source": "godot", "version": 1, "results": results}
	var dir := DirAccess.open("res://")
	if dir != null and not dir.dir_exists("tests/out"):
		dir.make_dir_recursive("tests/out")
	var f := FileAccess.open("res://tests/out/godot.json", FileAccess.WRITE)
	if f == null:
		printerr("[parity] 无法写入 tests/out/godot.json")
		quit(1)
		return
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("[parity] Godot 侧结果: ", results.size(), " 个场景 → res://tests/out/godot.json")
	for r in results:
		print("  - ", r["id"], " winner=", r["winner"], " rounds=", r["rounds"], " p=", _fmt(r["p"]), " e=", _fmt(r["e"]))
	quit(0)

func _build(list: Array) -> Array:
	var board: Array = []
	var uid := 1
	for card in list:
		board.append(UnitScript.from_card(card, uid))
		uid += 1
	return board

func _summary(sc: Dictionary, r: Dictionary, p_board: Array, e_board: Array) -> Dictionary:
	var ev_count := {}
	for ev in r["events"]:
		var k: String = String(ev["t"])
		ev_count[k] = int(ev_count.get(k, 0)) + 1
	# 与 Web 版一致：败方掉血 = 胜方存活随从星级之和
	var dmg_p := 0
	var dmg_e := 0
	if String(r["winner"]) == "p":
		dmg_e = _star_sum(p_board)
	elif String(r["winner"]) == "e":
		dmg_p = _star_sum(e_board)
	return {
		"id": sc.get("id", "?"),
		"name": sc.get("name", ""),
		"winner": r["winner"],
		"rounds": r["rounds"],
		"damage_to_p": dmg_p,
		"damage_to_e": dmg_e,
		"p": _units(p_board),
		"e": _units(e_board),
		"events": ev_count,
	}

func _star_sum(board: Array) -> int:
	var n := 0
	for u in board:
		if u != null and u.alive:
			n += u.star
	return n

func _units(board: Array) -> Array:
	var out: Array = []
	for u in board:
		if u == null:
			continue
		out.append({
			"n": u.card_name, "a": u.atk, "h": u.hp, "mh": u.max_hp, "alive": u.alive,
			"evo": u.evo, "vd": u.vd, "vc": u.vc, "gene": u.gene,
		})
	return out

func _fmt(arr: Array) -> String:
	var parts: Array[String] = []
	for u in arr:
		parts.append("%s %d/%d%s" % [u["n"], u["a"], u["h"], "" if u["alive"] else "✝"])
	return "[" + ", ".join(parts) + "]"
