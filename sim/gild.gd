extends RefCounted
## P2-3：三连金卡（对齐 Web 的三连规则）
## 规则：3 张同名（且都还不是金卡）的随从合成 1 张金卡 —— 身材翻倍，
##       技能/法术联动/战吼的数值与次数也翻倍（对应 Web 的 upSkill/upSc/upBc）。

## 找出可以合成的三连：返回 {ok, name, indices, golden}；indices 为原数组下标（升序）
static func try_merge(cards: Array) -> Dictionary:
	var by_name := {}
	for i in range(cards.size()):
		var c = cards[i]
		if c == null:
			continue
		if bool(c.get("g", false)):
			continue
		var n := String(c.get("n", ""))
		if n == "":
			continue
		if not by_name.has(n):
			by_name[n] = []
		by_name[n].append(i)
		if by_name[n].size() == 3:
			var golden := gild(cards[by_name[n][0]])
			return {"ok": true, "name": n, "indices": by_name[n].duplicate(), "golden": golden}
	return {"ok": false}

static func gild(card: Dictionary) -> Dictionary:
	var g: Dictionary = card.duplicate(true)
	g["g"] = true
	g["a"] = int(card.get("a", 0)) * 2
	g["h"] = int(card.get("h", 0)) * 2
	if card.has("mh"):
		g["mh"] = int(card["mh"]) * 2
	for key in ["sk", "sc", "scSk", "atkSk", "bc"]:
		if card.has(key) and card[key] is Dictionary:
			g[key] = _double_effect(card[key])
	return g

static func _double_effect(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	# 与 Web 的 upSkill/upSc/upBc 一致：只翻倍 数值 / 次数 / 成长 / 缩放 / 召唤数量
	for key in ["a", "h", "times", "d", "grow", "statScale", "count", "raceA", "raceH"]:
		if out.has(key) and typeof(out[key]) in [TYPE_INT, TYPE_FLOAT]:
			out[key] = out[key] * 2
	return out

## 在棋盘上就地合成：把三张同名卡的位置替换成"金卡 + 两个空位"
static func merge_in_place(cards: Array) -> Dictionary:
	var res := try_merge(cards)
	if not bool(res["ok"]):
		return res
	var idx: Array = res["indices"]
	cards[idx[0]] = res["golden"]
	cards[idx[1]] = null
	cards[idx[2]] = null
	return res
