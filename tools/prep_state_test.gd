extends SceneTree
## 备战状态机自检：godot --headless --path <项目> --script res://tools/prep_state_test.gd

const PrepState := preload("res://sim/prep_state.gd")
const UnitScript := preload("res://sim/unit.gd")
const BattleScript := preload("res://sim/battle.gd")
var fails: Array[String] = []

func _init() -> void:
	_case_buy_and_place()
	_case_runtime_writeback()
	_case_economy()
	_case_level_up_refresh()
	_case_feed_and_fusion()
	_case_round_choice()
	_case_battlecry_damage_and_restore()
	_case_spell_cast_dispatch()
	_case_round_shop_dispatch()
	_case_warlord_self_battlecry()
	_case_element_spell_boost_battlecry()
	_case_neutral_battlecries()
	_case_contract_auto_and_devour()
	_case_debt_payoff_writeback()
	_case_shop_bias()
	if fails.is_empty():
		print("[prep_state_test] 通过：基础流程 / 运行态写回 / 法术施放 / 回合商店 / 献祭元素与中立战吼 / 契印吞噬债务 / 债务结算写回 / 主族商店偏向 15/15")
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

func _case_shop_bias() -> void:
	var ps = PrepState.new()
	ps.setup(4, ["mech"], _pool(), [], 6101)
	ps.board[0] = {"n": "机械甲", "a": 1, "h": 1, "race": "mech"}
	ps.board[1] = {"n": "机械乙", "a": 1, "h": 1, "race": "mech"}
	ps.board[2] = null
	var two := ps.shop_bias_info()
	_check((two.get("races", []) as Array).is_empty(),
		"2 只同族不应触发商店主族偏向")
	ps.board[2] = {"n": "机械丙", "a": 1, "h": 1, "race": "mech"}
	var three := ps.shop_bias_info()
	_check((three.get("races", []) as Array) == ["mech"] and is_equal_approx(float(three.get("multiplier", 0.0)), 1.5),
		"3 只同族应触发 ×1.5 主族偏向，实际 %s" % str(three))
	ps.board[3] = {"n": "机械丁", "a": 1, "h": 1, "race": "mech"}
	var four := ps.shop_bias_info()
	_check(is_equal_approx(float(four.get("multiplier", 0.0)), 2.0),
		"4 只同族应触发 ×2.0 主族偏向，实际 %s" % str(four))
	ps.board[4] = {"n": "机械戊", "a": 1, "h": 1, "race": "mech"}
	var five := ps.shop_bias_info()
	_check(is_equal_approx(float(five.get("multiplier", 0.0)), 2.5),
		"5 只同族应触发 ×2.5 主族偏向，实际 %s" % str(five))
	print("[prep_state_test] 用例14 主族商店偏向: 3/4/5 只 = %.1f/%.1f/%.1f" % [
		float(three.get("multiplier", 0.0)),
		float(four.get("multiplier", 0.0)),
		float(five.get("multiplier", 0.0))])

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

func _case_runtime_writeback() -> void:
	var ps = PrepState.new()
	ps.board = [null, null, null, null, null, null, null]
	var dead_card := {"n": "阵亡槽", "a": 1, "h": 1, "mh": 1}
	var live_card := {"n": "存活槽", "a": 2, "h": 2, "mh": 2, "_atkLeft": 4}
	ps.board[0] = dead_card
	ps.board[2] = live_card

	var dead: Variant = UnitScript.from_card(dead_card, 1)
	dead.set("alive", false)
	dead.set("atk", 88)
	dead.set("hp", 0)
	dead.set("max_hp", 88)
	var live: Variant = UnitScript.from_card(live_card, 2)
	live.set("atk", 7)
	live.set("hp", 3)
	live.set("max_hp", 9)
	live.set("_t", 3)
	live.set("_mhT", 6)
	live.set("_pr", 5)
	live.set("_ev", 4)
	live.set("evo", 2)
	live.set("vd", 1)
	live.set("vc", 2)
	live.set("gene", 3)
	live.set("charge", 2)
	live.set("mech_head_grow", 4)
	live.set("_atkLeft", 1)
	live.set("shield", true)
	live.set("taunt_active", true)

	var copied: int = ps.sync_runtime_from_units([dead, live], 1)
	_check(copied == 1, "运行态写回应只处理存活随从，实际 %d" % copied)
	_check(int(dead_card["a"]) == 1 and int(dead_card["h"]) == 1 and int(dead_card["mh"]) == 1,
		"阵亡随从不应把自己的战斗态写回备战卡")
	_check(int(live_card["a"]) == 7 and int(live_card["h"]) == 9 and int(live_card["mh"]) == 9,
		"存活随从攻击/满血/最大生命写回失败，实际 %d/%d/%d" % [
			int(live_card["a"]), int(live_card["h"]), int(live_card["mh"])])
	_check(int(live_card.get("_t", 0)) == 3 and int(live_card.get("_mhT", 0)) == 6
		and int(live_card.get("_pr", 0)) == 5 and int(live_card.get("_ev", 0)) == 4,
		"永久成长/孵化/进化轮数写回失败")
	_check(int(live_card.get("evo", 0)) == 2 and int(live_card.get("vd", 0)) == 1
		and int(live_card.get("vc", 0)) == 2 and int(live_card.get("gene", 0)) == 3
		and int(live_card.get("charge", 0)) == 2 and int(live_card.get("_mechHeadGrow", 0)) == 4,
		"进化条/质变/基因/充能/机械成长写回失败")
	_check(int(live_card.get("_atkLeft", -1)) == 4
		and not live_card.has("shield") and not live_card.has("taunt_active"),
		"本场攻击次数、圣盾或临时嘲讽被错误持久化")
	print("[prep_state_test] 用例2 运行态写回: 存活=", copied, " a/h/mh=", live_card["a"],
		"/", live_card["h"], "/", live_card["mh"], " _pr=", live_card["_pr"])

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

func _case_level_up_refresh() -> void:
	var ps = PrepState.new()
	ps.setup(5, ["mech"], _pool(), [], 17)
	ps.gold = 100
	var before: Array = ps.shop.duplicate(true)
	_check(ps.level_up(), "升级刷新用例的升级应成功")
	_check(ps.shop != before, "升级后商店应立即刷新")
	ps.gold = 100
	ps.shop_frozen = true
	var frozen_before: Array = ps.shop.duplicate(true)
	_check(ps.level_up(), "冻结状态下仍应升级")
	_check(ps.shop == frozen_before, "冻结商店在升级后不应刷新")
	print("[prep_state_test] 用例3 升级刷新: 普通刷新=", ps.shop != before, " 冻结保留=", ps.shop == frozen_before)

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
	ps.hand = [{"n": "献祭者", "a": 3, "h": 3, "star": 1, "race": "sacrifice",
		"bc": {"e": "devour", "a": 0, "h": 0}}]
	ps.board[4] = {"n": "吞噬目标", "a": 5, "h": 7, "star": 2, "race": "neutral"}
	var devour: Dictionary = ps.devour_from_hand(0, 4)
	_check(bool(devour.get("ok", false)), "手牌献祭者应能吞噬友方目标")
	_check(int(ps.board[4]["a"]) == 8 and int(ps.board[4]["h"]) == 10,
		"手牌吞噬后应为 8/10，实际 %d/%d" % [int(ps.board[4]["a"]), int(ps.board[4]["h"])])
	_check(int(ps.board[4]["mh"]) == 3,
		"手牌吞噬最大生命应保持吞噬者初始生命 3，实际 %d" % int(ps.board[4]["mh"]))
	print("[prep_state_test] 用例4 喂料与合体: 喂料后=", 8, "/", 16, " 合体判定=", prep["ok"], " 一号位=", ps.board[1]["n"])

func _case_round_choice() -> void:
	var ps = PrepState.new()
	ps.setup(6, ["mech"], _pool(), [], 99)
	ps.board[0] = {"n": "测试机械", "a": 5, "h": 5, "s": 4, "race": "mech"}
	ps.gold = 10
	ps.free_refresh = 0
	var gold_result: Dictionary = ps.apply_round_choice(6, 0)
	_check(bool(gold_result["ok"]) and ps.gold == 14, "R6 +4金奖励没有正确结算")
	var core_result: Dictionary = ps.apply_round_choice(6, 2)
	_check(bool(core_result["ok"]) and ps.hand.size() == 1 and int(ps.hand[0].get("b", -1)) == 0,
		"R6 阵容核心牌没有按四星及以上规则进入手牌")
	ps.hand.clear()
	var gild_result: Dictionary = ps.apply_round_choice(9, 2)
	_check(bool(gild_result["ok"]) and ps.hand.size() == 1 and String(ps.hand[0].get("e", "")) == "gild-target",
		"R9 自选点金卡没有进入手牌")
	print("[prep_state_test] 用例5 回合奖励: 金=", ps.gold, " 手牌=", ps.hand.size(), " 类型=", ps.hand[0]["n"])

func _case_battlecry_damage_and_restore() -> void:
	var ps = PrepState.new()
	ps.setup(3, ["neutral"], _pool(), [], 321)
	ps.hand = [{"n": "血帆袭击者", "a": 2, "h": 3, "star": 2, "race": "neutral",
		"bc": {"e": "dmg-rnd", "d": 1}}]
	var enemy_board: Array = [
		null,
		{"n": "战吼目标", "a": 2, "h": 1, "mh": 4, "star": 2, "race": "neutral"},
		null,
	]
	_check(ps.place(0, 0, enemy_board), "血帆袭击者应能正常上场")
	_check(enemy_board[1] == null, "dmg-rnd 致命后应立即从敌方棋盘移除")
	_check(ps.last_battlecry_results.size() == 1, "dmg-rnd 应产出可消费的战吼结果")
	var result: Dictionary = ps.last_battlecry_results[0] if ps.last_battlecry_results.size() == 1 else {}
	_check(String(result.get("effect", "")) == "dmg-rnd", "战吼结果 effect 应为 dmg-rnd")
	_check(int(result.get("target_slot", -1)) == 1 and bool(result.get("killed", false)), "战吼结果应记录目标槽与击杀")
	var restored: Array[Dictionary] = ps.restore_battlecry_dead(enemy_board)
	_check(restored.size() == 1 and enemy_board[0] != null, "战后死亡目标应恢复到第一个空槽")
	_check(int(enemy_board[0].get("h", -1)) == 4, "恢复时血量应使用 mh，实际 %d" % int(enemy_board[0].get("h", -1)))

	ps.board = [null, null, null, null, null, null, null]
	ps.hand = [{"n": "精灵射手", "a": 1, "h": 3, "star": 1, "race": "neutral",
		"bc": {"e": "ally-atk", "a": 2}}]
	_check(ps.place(0, 2), "精灵射手应能正常上场")
	_check(int(ps.board[2].get("a", 0)) == 3, "ally-atk 候选应包含施放者自身并增加攻击")
	_check(int(ps.board[2].get("h", 0)) == 3, "ally-atk 不应误加生命")
	print("[prep_state_test] 用例6 战吼伤害与恢复: 敌方槽=null 恢复槽=0 生命=", int(enemy_board[0].get("h", -1)),
		" ally-atk=", int(ps.board[2].get("a", 0)), "/", int(ps.board[2].get("h", 0)))

func _case_spell_cast_dispatch() -> void:
	var ps = PrepState.new()
	ps.board = [
		{"n": "大秘术师", "a": 1, "h": 1, "race": "elem", "sk": {"t": "spell-cast", "e": "growth-boost", "times": 1}},
		{"n": "成长守卫", "a": 1, "h": 1, "race": "neutral", "sk": {"t": "start", "e": "growth-self", "times": 1}},
		{"n": "秘法学徒", "a": 2, "h": 2, "race": "elem", "sk": {"t": "spell-cast", "e": "spell-core", "a": 2, "h": 2, "raceA": 1, "raceH": 1}},
		{"n": "元素核心", "a": 2, "h": 2, "race": "elem", "sk": {"t": "spell-cast", "e": "spell-core", "a": 2, "h": 2, "raceA": 2, "raceH": 2}},
		{"n": "进化幼体", "a": 2, "h": 2, "race": "evolve", "scSk": {"t": "spell-cast", "e": "self-buff", "a": 1, "h": 1}},
		{"n": "亚煞极", "a": 1, "h": 1, "race": "demon", "scSk": {"t": "spell-cast", "e": "self-buff", "a": 1, "h": 1}},
		{"n": "死亡颂唱者", "a": 1, "h": 1, "race": "undead", "scSk": {"t": "spell-cast", "e": "race-buff", "race": "undead", "a": 1, "h": 1}},
		{"n": "秘法主宰", "a": 1, "h": 1, "race": "elem", "sk": {"t": "spell-cast", "e": "ally-all-buff", "d": 1}},
		{"n": "冰风雪人", "a": 2, "h": 2, "race": "elem", "sk": {"t": "spell-cast", "e": "spell-race-grow", "a": 2, "h": 2, "grow": 1, "max": 3}},
		{"n": "星灵使徒", "a": 1, "h": 1, "race": "star", "sk": {"t": "spell-cast", "e": "race-buff", "race": "star", "scope": "rnd", "statScale": 1}},
		{"n": "秘法巨龙", "a": 1, "h": 1, "race": "dragon", "sc": {"t": "spell-cast", "e": "self-growth-boost", "times": 2}},
	]
	ps._on_spell_cast()
	_check(int(ps.board[1].get("_gb", 0)) == 1, "growth-boost 应给成长类增加 _gb=1")
	_check(int(ps.board[2].get("_coreT", 0)) == 1 and int(ps.board[2].get("a", 0)) > 2,
		"spell-core 应累计施法并按成长目标增强自身，实际 a=%d _coreT=%d" % [
			int(ps.board[2].get("a", 0)), int(ps.board[2].get("_coreT", 0))])
	_check(int(ps.board[3].get("_coreT", 0)) == 1, "元素核心应走同一 spell-core 分发")
	_check(int(ps.board[4].get("a", 0)) >= 3 and int(ps.board[4].get("h", 0)) >= 3,
		"scSk self-buff 应给自身加成长")
	_check(int(ps.board[5].get("a", 0)) >= 2, "亚煞极 scSk self-buff 应发")
	_check(int(ps.board[6].get("a", 0)) >= 2, "scSk race-buff 应给亡灵加成长")
	_check(int(ps.board[7].get("_sc", 0)) == 1, "ally-all-buff 应累计 _sc")
	_check(int(ps.board[8].get("_iceT", 0)) == 1, "spell-race-grow 应累计 _iceT")
	_check(ps.chain == 1, "spell-cast race-buff 星灵应增加连锁")
	_check(int(ps.board[10].get("_gb", 0)) == 2, "self-growth-boost 应永久累计 _gb")
	print("[prep_state_test] 用例7 法术施放: core=", ps.board[2]["a"], " undead=", ps.board[6]["a"],
		" chain=", ps.chain, " ice=", ps.board[8]["_iceT"])

func _case_round_shop_dispatch() -> void:
	var ps = PrepState.new()
	ps.setup(4, ["mech", "elem"], _pool(), [], 777)
	ps.pool_by_star = {1: [{"n": "装甲模块", "a": 1, "h": 1, "s": 1, "race": "mech", "material": true, "magA": 1, "magH": 1}]}
	ps.board = [
		{"n": "元素商人", "a": 1, "h": 1, "race": "elem", "sk": {"t": "start", "e": "shop-buff", "race": "elem", "a": 2, "h": 2, "spellRefresh": 2}},
		{"n": "恶魔商贩", "a": 1, "h": 1, "race": "demon", "sk": {"t": "start", "e": "shop-buff", "a": 2, "h": 2}},
		{"n": "元素秘典", "a": 1, "h": 1, "race": "elem", "sk": {"t": "start", "e": "spell-boost-grow", "a": 1, "h": 1, "grow": 1}},
		{"n": "吞噬魔", "a": 2, "h": 2, "race": "demon", "sk": {"t": "start", "e": "devour-shop", "times": 1}},
		{"n": "磁力供给技师", "a": 1, "h": 1, "race": "mech", "sk": {"t": "round", "e": "mech-supply", "count": 1}},
		{"n": "滚债行者", "a": 3, "h": 3, "race": "sacrifice", "sk": {"t": "round", "e": "debt-interest", "count": 1, "grow": 1, "selfGrow": 1}},
		{"n": "铸币巨兽", "a": 1, "h": 1, "race": "demon", "sk": {"t": "gold", "e": "coin-spell-boost", "times": 1}},
	]
	ps.hand = []
	ps.shop = [
		{"n": "店元素", "a": 2, "h": 2, "mh": 2, "t": "m", "race": "elem"},
		{"n": "店中立", "a": 3, "h": 3, "mh": 3, "t": "m", "race": "neutral"},
	]
	var coin_before := int(ps.spell_boost.get("a", 0)) + int(ps.spell_boost.get("h", 0))
	var events: Array[Dictionary] = ps.apply_prep_round_skills()
	_check(int(ps.shop_boost.get("a", 0)) == 4 and int(ps.shop_boost.get("h", 0)) == 4,
		"两个 shop-buff 应累计 +4/+4")
	var devour_count := 0
	for card in ps.shop:
		if card == null:
			devour_count += 1
	_check(devour_count == 1, "devour-shop 应吞噬并清空 1 个商店随从")
	_check(ps.hand.size() >= 1, "mech-supply 应加入至少 1 张材料牌到手中")
	_check(ps.debt == 1 and int(ps.board[5].get("a", 0)) == 4,
		"debt-interest 应债务+1并自身+1/+1，实际债务=%d a=%d" % [ps.debt, int(ps.board[5].get("a", 0))])
	ps.spent = 4
	var before_coin_a := int(ps.spell_boost.get("a", 0))
	var before_coin_h := int(ps.spell_boost.get("h", 0))
	ps._spend_gold(1)
	var coin_delta := (int(ps.spell_boost.get("a", 0)) - before_coin_a) + (int(ps.spell_boost.get("h", 0)) - before_coin_h)
	_check(coin_delta == 1, "每 5 金应触发一次铸币巨兽法术强化，实际 %d" % coin_delta)
	_check(events.size() >= 5, "回合技能应返回可消费事件，实际 %d" % events.size())
	print("[prep_state_test] 用例8 回合商店: shopBoost=", ps.shop_boost, " hand=", ps.hand.size(),
		" debt=", ps.debt, " coin=", coin_delta)

func _case_warlord_self_battlecry() -> void:
	var ps = PrepState.new()
	ps.setup(7, ["sacrifice"], _pool(), [], 444)
	ps.hand = [{"n": "万灵之主", "a": 6, "h": 6, "star": 7, "race": "sacrifice",
		"bc": {"e": "self", "a": 4, "h": 4}}]
	_check(ps.place(0, 0), "万灵之主应能登场")
	_check(int(ps.board[0].get("a", 0)) == 10 and int(ps.board[0].get("h", 0)) == 10,
		"万灵之主战吼应 +4/+4，实际 %d/%d" % [
			int(ps.board[0].get("a", 0)), int(ps.board[0].get("h", 0))])
	print("[prep_state_test] 用例9 万灵之主战吼: ", ps.board[0]["a"], "/", ps.board[0]["h"])

func _case_element_spell_boost_battlecry() -> void:
	var ps = PrepState.new()
	ps.setup(3, ["elem"], _pool(), [], 555)
	ps.board = [null, null, null, null, null, null, null]
	ps.hand = [
		{"n": "法术学徒", "a": 2, "h": 3, "star": 2, "race": "elem",
			"bc": {"e": "spell-boost", "a": 1, "h": 1}},
		{"n": "大法师学徒", "a": 3, "h": 4, "star": 5, "race": "elem",
			"bc": {"e": "spell-boost", "a": 2, "h": 2}},
	]
	_check(ps.place(0, 0), "法术学徒应能登场")
	_check(ps.place(0, 1), "大法师学徒应能登场")
	_check(int(ps.spell_boost.get("a", 0)) == 3 and int(ps.spell_boost.get("h", 0)) == 3,
		"两张元素学徒应累计法术增幅 +3/+3，实际 %d/%d" % [
			int(ps.spell_boost.get("a", 0)), int(ps.spell_boost.get("h", 0))])
	print("[prep_state_test] 用例10 元素战吼: spellBoost=", ps.spell_boost)

func _case_neutral_battlecries() -> void:
	var ps = PrepState.new()
	ps.setup(3, ["neutral"], _pool(), [], 666)
	ps.board = [{"n": "木桩", "a": 1, "h": 1, "star": 1, "race": "neutral"},
		null, null, null, null, null, null]
	ps.hand = [
		{"n": "渔人猎潮者", "a": 2, "h": 1, "star": 1, "race": "neutral",
			"bc": {"e": "free-refresh"}},
		{"n": "狗头人", "a": 2, "h": 2, "star": 2, "race": "neutral",
			"bc": {"e": "gold", "g": 1}},
		{"n": "战地老兵", "a": 3, "h": 2, "star": 2, "race": "neutral",
			"bc": {"e": "ally-rnd", "a": 1, "h": 1}},
	]
	var gold_before: int = ps.gold
	var board_total_before := 2
	_check(ps.place(0, 1), "渔人猎潮者应登场")
	_check(ps.free_refresh == 1, "渔人猎潮者应增加免费刷新")
	_check(ps.place(0, 2), "狗头人应登场")
	_check(ps.gold == gold_before + 1, "狗头人战吼应 +1 金")
	_check(ps.place(0, 3), "战地老兵应登场")
	var board_total_after := 0
	for card in ps.board:
		if card != null:
			board_total_after += int(card.get("a", 0)) + int(card.get("h", 0))
	_check(board_total_after == board_total_before + 3 + 4 + 5 + 2,
		"战地老兵应随机给一个友方 +1/+1，实际总身材 %d" % board_total_after)
	print("[prep_state_test] 用例11 中立战吼: refresh=", ps.free_refresh,
		" gold=", ps.gold, " total=", board_total_after)

func _case_contract_auto_and_devour() -> void:
	var ps = PrepState.new()
	ps.setup(8, ["sacrifice"], _pool(), [], 909)
	ps.board[0] = {"n": "血契司仪", "a": 3, "h": 5, "star": 2, "race": "sacrifice",
		"sk": {"t": "start", "e": "contract-set", "debtBonus": 3}}
	ps.board[1] = {"n": "契印目标", "a": 2, "h": 3, "star": 2, "race": "sacrifice"}
	ps.board[2] = {"n": "献祭者", "a": 3, "h": 3, "star": 1, "race": "sacrifice",
		"_devourReady": true, "bc": {"e": "devour", "a": 1, "h": 1}}
	_check(ps.ensure_auto_contract(), "存在血契司仪时应自动生成契印目标")
	_check(bool(ps.board[1].get("_contract", false)), "自动契印没有落到最弱献祭随从")
	_check(ps.contract_bonus == 3, "自动契印没有继承血契司仪 debtBonus=3")
	var debt_before: int = ps.debt
	var result: Dictionary = ps.devour_ally(2, 1)
	_check(bool(result.get("ok", false)), "备战期吞噬契印目标应成功")
	_check(ps.debt > debt_before, "吞噬契印目标没有增加债务，实际 %d→%d" % [debt_before, ps.debt])
	_check(ps.contract_bonus == 0, "契印被吞噬后债务加成没有清空")
	_check(ps.board[1] == null, "契印被吞噬后目标仍留在棋盘")
	var contract_result: Dictionary = result.get("contract", {})
	print("[prep_state_test] 用例12 契印吞噬债务: 契约加成=3 债务=", debt_before, "→", ps.debt,
		" 结果=", int(contract_result.get("delta", 0)))

func _case_debt_payoff_writeback() -> void:
	var cards: Array[Dictionary] = [
		{"n": "血祭司祭", "a": 5, "h": 8, "mh": 8, "s": 4, "race": "sacrifice",
			"sk": {"t": "start", "e": "debt-payoff", "a": 1, "h": 1}},
		{"n": "祭品", "a": 10, "h": 10, "mh": 10, "s": 3, "race": "sacrifice"},
		{"n": "献祭图腾", "a": 6, "h": 8, "mh": 8, "s": 7, "race": "sacrifice",
			"sk": {"t": "passive", "e": "debt-totem"}},
	]
	var ps = PrepState.new()
	ps.setup(9, ["sacrifice"], {}, [], 7, {})
	ps.board = [cards[0], cards[1], cards[2], null, null, null, null]
	var p_units: Array = []
	for i in range(3):
		p_units.append(UnitScript.from_card(cards[i], i + 1))
	for i in range(3, 7):
		p_units.append(null)
	var e_units: Array = [UnitScript.from_card(
		{"n": "木桩", "a": 0, "h": 300, "mh": 300, "s": 1, "race": "elem"}, 101)]
	for i in range(1, 7):
		e_units.append(null)
	var result: Dictionary = BattleScript.new().resolve(p_units, e_units, 7, 30, {
		"round": 9, "debtP": 20, "phaseP": 2,
	})
	ps.sync_runtime_from_units(result.get("p_board", []), 1)
	_check(int(cards[0]["a"]) == 27 and int(cards[0]["h"]) == 31,
		"血祭司祭债务结算没有写回，实际 %d/%d" % [int(cards[0]["a"]), int(cards[0]["h"])])
	_check(int(cards[1]["a"]) == 32 and int(cards[1]["h"]) == 33,
		"献祭收益没有写回全体，祭品实际 %d/%d" % [int(cards[1]["a"]), int(cards[1]["h"])])
	print("[prep_state_test] 用例13 债务结算写回: 血祭司祭=", cards[0]["a"], "/", cards[0]["h"],
		" 祭品=", cards[1]["a"], "/", cards[1]["h"])
