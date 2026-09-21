extends RefCounted
## 备战期操作（P1c-7）：磁力喂料
## 对齐 Web 的 magnetFeed：材料牌数值按机械支援牌加成后转移给目标机械
##
## 已实现：金卡翻倍 / 磁暴重臂 ×2 攻击 / 超导装配中枢 ×1.5(2.5金) /
##          matBoost 加成 / 机械泰坦 +30% 攻击 / 统御核心 modGrow 累积 / 关键词转移
## TODO：超导装配中枢的"其他部位按比例追加"分支（Web 中该分支较长，待逐行核对后补）

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

	return {"a": a, "h": h, "k": k}
