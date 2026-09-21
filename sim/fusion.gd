extends RefCounted
## 机械合体（P1c-5）：合体区判定 + 四部位数值继承 + 协同随从生成
## 公式对齐 Web 的 buildMechBody / prepareMechFusion（攻击=四部位相加+modAtk，生命/上限=相加，关键词取并集）

## 合体区：连续 4 格，第 1 格是 core（首脑），后 3 格分别是另外三个部位
static func find_formation(board: Array) -> int:
	for start in range(0, max(0, board.size() - 3)):
		var core = board[start]
		if core == null or String(core.get("part", "")) != "core":
			continue
		var seen := {}
		var ok := true
		for k in range(start + 1, start + 4):
			var u = board[k]
			var p := "" if u == null else String(u.get("part", ""))
			if p == "":
				ok = false
				break
			seen[p] = true
		if ok and seen.size() == 3:
			return start
	return -1

static func build_body(parts: Array, mech_level: int = 0, mag_t: int = 0) -> Dictionary:
	var body: Dictionary = parts[0].duplicate(true)
	body["_mech_body"] = true
	body["n"] = "合体·" + String(parts[0].get("n", ""))
	body["a"] = 0
	body["h"] = 0
	body["mh"] = 0
	var keywords := String(parts[0].get("k", ""))
	var head_grow := 0
	var dmg_grow := 0
	var head_double := 0
	var has_arm := false
	for bp in parts:
		body["a"] = int(body["a"]) + int(bp.get("a", 0))
		body["h"] = int(body["h"]) + int(bp.get("h", 0))
		body["mh"] = int(body["mh"]) + int(bp.get("mh", bp.get("h", 0)))
		if bp.has("modAtk"):
			body["a"] = int(body["a"]) + int(bp["modAtk"])
		for ch in String(bp.get("k", "")):
			if not keywords.contains(ch):
				keywords += ch
		if int(bp.get("modGrow", 0)) > head_grow:
			head_grow = int(bp["modGrow"])
		if int(bp.get("modDmg", 0)) > dmg_grow:
			dmg_grow = int(bp["modDmg"])
		if bp.has("headDouble"):
			head_double = 1
		if bp.has("modShield") and not keywords.contains("d"):
			keywords += "d"
		if String(bp.get("n", "")) == "磁暴重臂":
			has_arm = true
	body["k"] = keywords
	body["_mechHeadGrow"] = head_grow
	body["_mechDmgGrow"] = dmg_grow
	body["_headDouble"] = head_double
	if has_arm:
		body["_extraAtk"] = min(2, int(floor(float(mag_t) / 2.0)))
	body["s"] = clampi(1 + int(floor(float(mech_level) / 2.0)), 1, 7)
	body["mh"] = max(int(body["mh"]), int(body["h"]))
	body["h"] = int(body["mh"])
	return body

static func summons_for(body: Dictionary, mech_level: int = 0) -> Array:
	var ba := int(body.get("a", 0))
	var bh := int(body.get("h", 0))
	return [
		{"n": "磁暴僚机", "a": max(4, int(round(float(ba) * 0.45))) + mech_level, "h": max(6, int(round(float(bh) * 0.3))) + mech_level, "_followType": "strike"},
		{"n": "维修无人机", "a": max(3, int(round(float(ba) * 0.25))) + mech_level, "h": max(8, int(round(float(bh) * 0.4))) + mech_level, "_followType": "repair"},
		{"n": "电磁拦截者", "a": max(4, int(round(float(ba) * 0.3))) + mech_level, "h": max(10, int(round(float(bh) * 0.5))) + mech_level, "k": "td", "shield": true, "_followType": "guard"},
	]

## 返回 {ok, index, body, summons, board, armor}；board 为替换后的新棋盘
static func prepare(board: Array, mech_level: int = 0, mag_t: int = 0, repair: int = 0) -> Dictionary:
	var idx := find_formation(board)
	if idx < 0:
		return {"ok": false}
	var parts: Array = []
	for i in range(idx, idx + 4):
		parts.append(board[i])
	var body := build_body(parts, mech_level, mag_t)
	var out_board: Array = board.duplicate()
	out_board[idx] = body
	var summons := summons_for(body, mech_level)
	for i in range(3):
		out_board[idx + 1 + i] = summons[i]
	return {"ok": true, "index": idx, "body": body, "summons": summons, "board": out_board, "armor": repair}
