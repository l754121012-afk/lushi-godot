extends RefCounted
## 备战期操作（P1c-7）：磁力喂料
## 对齐 Web 的 magnetFeed：材料牌数值按机械支援牌加成后转移给目标机械
##
## 已实现：金卡翻倍 / 磁暴重臂 ×2 攻击 / 超导装配中枢 ×1.5(2.5金) /
##          matBoost 加成 / 机械泰坦 +30% 攻击 / 统御核心 modGrow 累积 / 关键词转移
## 已实现：超导装配中枢扩散 / 维修输送车护甲 / matBoost 累积 / 喂料次数

static func magnet_feed(card: Dictionary, target: Dictionary, board: Array, state: Dictionary = {}) -> Dictionary:
	var has := func(n: String) -> bool:
		for x in board:
			if x != null and String(x.get("n", "")) == n:
				return true
		return false
	var gold_has := func(n: String) -> bool:
		for x in board:
			if x != null and String(x.get("n", "")) == n and bool(x.get("g", false)):
				return true
		return false

	var gold_mult := 2 if bool(card.get("g", false)) else 1
	var a := int(card.get("magA", 0)) * gold_mult
	var h := int(card.get("magH", 0)) * gold_mult
	var k := String(card.get("magK", ""))

	if has.call("磁暴重臂"):
		a *= 2
	if has.call("超导装配中枢"):
		var factor := 2.5 if gold_has.call("超导装配中枢") else 1.5
		a = int(round(float(a) * factor))
		h = int(round(float(h) * factor))
	a += int(state.get("matBoostA", 0))
	h += int(state.get("matBoostH", 0))

	target["a"] = int(target.get("a", 0)) + a
	target["h"] = int(target.get("h", 0)) + h
	if target.has("mh"):
		target["mh"] = int(target.get("mh", 0)) + h
	var tk := String(target.get("k", ""))
	for ch in k:
		if not tk.contains(ch):
			tk += ch
	if tk != "":
		target["k"] = tk

	if has.call("机械泰坦"):
		target["a"] = int(target.get("a", 0)) + int(round(float(a) * 0.3))
	if has.call("统御核心"):
		for x in board:
			if x != null and String(x.get("n", "")) == "统御核心":
				var add := 2 if bool(x.get("g", false)) else 1
				x["modGrow"] = int(x.get("modGrow", 0)) + add
	if has.call("超导装配中枢"):
		var spread_gold: bool = bool(gold_has.call("超导装配中枢"))
		var spread_a := int(round(float(a) * (0.6 if spread_gold else 0.35)))
		var spread_h := int(round(float(h) * (0.6 if spread_gold else 0.35)))
		for part in board:
			if part == null or part == target or String(part.get("part", "")) == "":
				continue
			part["a"] = int(part.get("a", 0)) + spread_a
			part["h"] = int(part.get("h", 0)) + spread_h
			if part.has("mh"):
				part["mh"] = int(part.get("mh", 0)) + spread_h
		var boost := 2 if spread_gold else 1
		state["matBoostA"] = int(state.get("matBoostA", 0)) + boost
		state["matBoostH"] = int(state.get("matBoostH", 0)) + boost
	if has.call("维修输送车"):
		var repair_gold: bool = bool(gold_has.call("维修输送车"))
		var target_hp := int(target.get("mh", target.get("h", 0)))
		var repair := int(round(float(h) * (1.2 if repair_gold else 0.8)))
		repair += int(floor(float(target_hp) * (0.15 if repair_gold else 0.08)))
		repair += int(state.get("mechLevel", 0)) * (8 if repair_gold else 4)
		state["mechRepair"] = int(state.get("mechRepair", 0)) + maxi(1, repair)
	state["_magT"] = int(state.get("_magT", 0)) + 1

	return {
		"a": a,
		"h": h,
		"k": k,
		"matBoostA": int(state.get("matBoostA", 0)),
		"matBoostH": int(state.get("matBoostH", 0)),
		"mechRepair": int(state.get("mechRepair", 0)),
		"magT": int(state.get("_magT", 0)),
	}
