extends SceneTree
## 宣言专项：昼夜任务池、事件统计、达成奖励、progress 叠加与备战选择。
## godot --headless --path <项目> --script res://tools/quest_test.gd

const Quest := preload("res://sim/quest.gd")
const BattleScript := preload("res://sim/battle.gd")
const PrepState := preload("res://sim/prep_state.gd")
const UnitScript := preload("res://sim/unit.gd")

var fails: Array[String] = []
var quests: Dictionary = {}


func _init() -> void:
	quests = _load_quests()
	_case_pools_and_needs()
	_case_event_evaluation()
	_case_reward_complete_and_failed()
	_case_progress_reward_does_not_hatch()
	_case_prep_state_selection()
	if fails.is_empty():
		print("[quest_test] 通过：昼夜池/事件统计/达成与未达成奖励/progress/备战选择 5/5")
		quit(0)
	else:
		for failure in fails:
			printerr("[quest_test] 失败：", failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		fails.append(message)


func _case_pools_and_needs() -> void:
	var day: Array = Quest.pool_for_phase(quests, 0)
	var night: Array = Quest.pool_for_phase(quests, 1)
	_check(day.size() == 3 and String(day[0].get("id", "")) == "hunt", "昼相任务池顺序不正确")
	_check(night.size() == 3 and String(night[0].get("id", "")) == "unyield", "夜相任务池顺序不正确")
	_check(Quest.need_for_id("hunt") == 2 and Quest.need_for_id("press") == 3
		and Quest.need_for_id("frenzy") == 4, "昼相阈值不正确")
	_check(Quest.need_for_id("unyield") == 5 and Quest.need_for_id("symbiosis") == 2
		and Quest.need_for_id("lurk") == 15, "夜相阈值不正确")


func _case_event_evaluation() -> void:
	var own_initial: Array = [
		{"uid": 1, "race": "evolve", "h": 10},
		{"uid": 2, "race": "neutral", "h": 10},
	]
	var foe_initial: Array = [
		{"uid": 101, "race": "neutral", "h": 5},
		{"uid": 102, "race": "neutral", "h": 5},
	]
	var own_final: Array = [
		{"uid": 1, "race": "evolve", "h": 7},
		{"uid": 2, "race": "neutral", "h": 10},
	]
	var events: Array = [
		{"t": "attack", "src": 1, "dst": 101, "swing": 0},
		{"t": "damage", "src": 1, "dst": 101, "dmg": 5, "swing": 0},
		{"t": "death", "id": 101},
		{"t": "attack", "src": 101, "dst": 1, "swing": 0},
		{"t": "damage", "src": 101, "dst": 1, "dmg": 3, "swing": 0},
		{"t": "attack", "src": 1, "dst": 102, "swing": 0},
		{"t": "damage", "src": 1, "dst": 102, "dmg": 5, "swing": 0},
		{"t": "death", "id": 102},
	]
	var stats: Dictionary = Quest.evaluate(events, "p", own_initial, foe_initial, own_final)
	_check(int(stats.get("kills", 0)) == 2, "击杀统计应为2")
	_check(int(stats.get("evoAtk", 0)) == 2, "进化随从攻击统计应为2")
	_check(int(stats.get("evoHit", 0)) == 1, "进化随从受击统计应为1")
	_check(int(stats.get("dmg", 0)) == 3, "我方受击伤害统计应为3")
	_check(int(stats.get("alive", 0)) == 2 and int(stats.get("evoAlive", 0)) == 1,
		"结束存活统计不正确")
	_check(Quest.is_complete("hunt", stats), "猎杀阈值应判定完成")
	_check(not Quest.is_complete("frenzy", stats), "超频阈值不应误判完成")


func _case_reward_complete_and_failed() -> void:
	var complete_board: Array = [
		_mk_evolve(1, "attack", 99),
		_mk_evolve(2, "attack", 99),
		_mk_evolve(3, "attack", 99),
	]
	var enemy: Array = [
		UnitScript.from_card({"n": "宣言木桩", "a": 0, "h": 999, "star": 1, "race": "neutral"}, 101),
	]
	var complete: Dictionary = BattleScript.new().resolve(
		complete_board, enemy, 7, 0, {"questP": "press", "phaseP": 0})
	_check(bool(complete.get("quest_ok_p", false)), "三项存活应判定宣言达成")
	_check(int(complete.get("quest_reward_ticks_p", 0)) == 2, "达成奖励应为2格")
	_check(int(complete_board[0]._ev) == 0, "战斗层不应在战斗尸体上直接结算宣言奖励")
	var complete_ps = PrepState.new()
	complete_ps.setup(1, ["evolve"], _pool(), [], 71, quests)
	complete_ps.board[0] = {
		"n": "宣言测试体", "a": 5, "h": 30, "s": 3, "race": "evolve",
		"sk": {"t": "attack", "e": "evolve", "need": 99, "maxD": 0},
	}
	var complete_targets: Array[Dictionary] = complete_ps.apply_quest_reward(true)
	_check(complete_targets.size() == 1, "备战期宣言奖励应返回1个受益随从")
	_check(int(complete_ps.board[0].get("_ev", 0)) == 2,
		"备战期达成奖励应给进化随从推进2格，实际 %d" % int(complete_ps.board[0].get("_ev", 0)))

	var failed_board: Array = [_mk_evolve(1, "attack", 99)]
	var failed_enemy: Array = [
		UnitScript.from_card({"n": "宣言木桩", "a": 0, "h": 999, "star": 1, "race": "neutral"}, 101),
	]
	var failed: Dictionary = BattleScript.new().resolve(
		failed_board, failed_enemy, 8, 0, {"questP": "hunt", "phaseP": 0})
	_check(not bool(failed.get("quest_ok_p", true)), "无击杀时猎杀宣言不应判定达成")
	_check(int(failed.get("quest_reward_ticks_p", 0)) == 1, "未达成奖励应为1格")
	_check(int(failed_board[0]._ev) == 0, "战斗层不应直接结算未达成奖励")
	var failed_ps = PrepState.new()
	failed_ps.setup(1, ["evolve"], _pool(), [], 72, quests)
	failed_ps.board[0] = {
		"n": "宣言测试体", "a": 5, "h": 30, "s": 3, "race": "evolve",
		"sk": {"t": "attack", "e": "evolve", "need": 99, "maxD": 0},
	}
	var failed_targets: Array[Dictionary] = failed_ps.apply_quest_reward(false)
	_check(failed_targets.size() == 1, "备战期未达成奖励也应返回受益随从")
	_check(int(failed_ps.board[0].get("_ev", 0)) == 1,
		"备战期未达成奖励应给进化随从推进1格，实际 %d" % int(failed_ps.board[0].get("_ev", 0)))


func _case_progress_reward_does_not_hatch() -> void:
	var progress_unit = UnitScript.from_card({
		"n": "孵化体", "a": 4, "h": 20, "star": 3, "race": "evolve",
		"sk": {"t": "battle", "e": "progress", "times": 1}, "_pr": 4,
	}, 1)
	var enemy = UnitScript.from_card({
		"n": "宣言木桩", "a": 0, "h": 999, "star": 1, "race": "neutral",
	}, 101)
	var result: Dictionary = BattleScript.new().resolve(
		[progress_unit], [enemy], 9, 0, {"questP": "press", "phaseP": 0})
	_check(not bool(result.get("quest_ok_p", true)), "单项存活不应满足压制")
	_check(int(progress_unit._pr) == 4, "战斗层不应直接修改孵化进度")
	var progress_ps = PrepState.new()
	progress_ps.setup(1, ["evolve"], _pool(), [], 73, quests)
	progress_ps.board[0] = {
		"n": "孵化体", "a": 4, "h": 20, "s": 3, "race": "evolve",
		"sk": {"t": "battle", "e": "progress", "times": 1}, "_pr": 4,
	}
	var progress_targets: Array[Dictionary] = progress_ps.apply_quest_reward(false)
	_check(progress_targets.size() == 1, "备战期 progress 奖励应返回受益随从")
	_check(int(progress_ps.board[0].get("_pr", 0)) == 5,
		"备战期未达成奖励应把孵化进度从4推进到5，实际 %d" % int(progress_ps.board[0].get("_pr", 0)))
	_check(String(progress_ps.board[0].get("n", "")) == "孵化体", "宣言奖励本身不应直接触发孵化")


func _case_prep_state_selection() -> void:
	var ps = PrepState.new()
	ps.setup(1, ["evolve"], _pool(), [], 11, quests)
	_check(ps.quest_id == "hunt" and ps.quest_index == 0, "备战默认应选择昼相池首任务")
	ps.phase = 1
	_check(ps.ensure_quest() and ps.quest_id == "unyield", "切到夜相后应回落到夜相池首")
	var picked: Dictionary = ps.select_quest(2)
	_check(bool(picked.get("ok", false)) and ps.quest_id == "lurk" and ps.quest_index == 2,
		"夜相三选一没有选中蛰伏")
	ps.apply_quest_stats({"dmg": 15})
	_check(int(ps.evo_prog.get("cur", 0)) == 15 and int(ps.evo_prog.get("need", 0)) == 15,
		"蛰伏进度没有按受伤15点同步")


func _mk_evolve(uid: int, timing: String, need: int) -> RefCounted:
	return UnitScript.from_card({
		"n": "宣言测试体%d" % uid,
		"a": 5,
		"h": 30,
		"star": 3,
		"race": "evolve",
		"sk": {"t": timing, "e": "evolve", "need": need, "maxD": 0},
	}, uid)


func _pool() -> Dictionary:
	var pool: Dictionary = {}
	for star in range(1, 8):
		pool[star] = [{
			"n": "测试进化体%d" % star,
			"a": star,
			"h": star,
			"s": star,
			"race": "evolve",
		}]
	return pool


func _load_quests() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed.get("quests", {})
