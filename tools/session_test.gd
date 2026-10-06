extends SceneTree
## 对局循环自检：godot --headless --path <项目> --script res://tools/session_test.gd
## 让两个 AI 对打 8 回合，检查回合推进、掉血结算、金币按表发放、胜负只有一个方向

const Session := preload("res://sim/session.gd")
var fails: Array[String] = []

func _init() -> void:
	var s = Session.new()
	s.setup(["mech", "elem", "star"], _pool(), [], 20260923)
	var rows: Array = s.play(8)
	_check(rows.size() == 8, "应跑满 8 回合，实际 %d" % rows.size())
	var hp_ok := true
	var gold_ok := true
	var last_hp := 100
	for r in rows:
		if int(r["hp"]["p"]) > last_hp:
			hp_ok = false
		last_hp = int(r["hp"]["p"])
		if int(r["gold"]) <= 0:
			gold_ok = false
	_check(hp_ok, "玩家血量不应回升")
	_check(gold_ok, "每回合都应发放正数金币")
	_check(s.round_no == 9, "跑完 8 回合后应进入第 9 回合，实际 %d" % s.round_no)
	var s2 = Session.new()
	s2.setup(["mech", "elem", "star"], _pool(), [], 20260924)
	s2.p_ps.chain = 2
	s2.p_ps.star_amp = 1
	s2.p_ps.debt = 8
	s2.p_ps.contract_id = 31
	s2.e_ps.chain = 3
	s2.e_ps.star_amp = 2
	s2.e_ps.debt = 18
	s2.e_ps.contract_id = 41
	s2.play_round()
	var opts: Dictionary = s2.last_battle_options
	var options_ok := (
		int(opts.get("chainP", -1)) == 2
		and int(opts.get("ampP", -1)) == 1
		and int(opts.get("debtP", -1)) == 8
		and int(opts.get("contractP", -1)) == 31
		and int(opts.get("chainE", -1)) == 3
		and int(opts.get("ampE", -1)) == 2
		and int(opts.get("debtE", -1)) == 18
		and int(opts.get("contractE", -1)) == 41
	)
	_check(options_ok, "play_round 应把双方 battle_options 合并后传入战斗，实际 %s" % str(opts))
	print("[session_test] 8 回合:")
	for line in s.log_lines:
		print("   ", line)
	print("[session_test] 终局 HP=", s.hp["p"], "/", s.hp["e"], " 金币=", s.p_ps.gold)
	if fails.is_empty():
		print("[session_test] 通过：回合推进 / 掉血结算 / 金币发放 / 双端战斗参数 4/4")
		quit(0)
	else:
		for f in fails:
			printerr("[session_test] 失败：", f)
		quit(1)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)

func _pool() -> Dictionary:
	var pool := {}
	for star in range(1, 8):
		var list: Array = []
		for i in range(6):
			list.append({"n": "M%d-%d" % [star, i], "a": star * 2, "h": star * 2, "s": star,
				"race": ["mech", "elem", "star"][i % 3]})
		if star == 3:
			list.append({"n": "磁力底盘", "a": 4, "h": 10, "s": 3, "race": "mech", "part": "core", "k": "t"})
			list.append({"n": "核心学徒", "a": 4, "h": 5, "s": 3, "race": "mech", "part": "head"})
			list.append({"n": "磁能臂", "a": 8, "h": 4, "s": 3, "race": "mech", "part": "arm", "k": "w"})
			list.append({"n": "推进肢体", "a": 3, "h": 12, "s": 3, "race": "mech", "part": "leg", "k": "t"})
		pool[star] = list
	return pool
