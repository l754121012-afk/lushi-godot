extends RefCounted
## 机制视觉契约表。
##
## 这里只定义稳定的占位视觉语义，不负责生成最终资源。UI、战斗飘字、脉冲与
## 音效轨迹都先经过此表，后续换美术时只需替换同一 family/style 下的资源。

const FAMILY_ORDER: Array[String] = [
	"sacrifice", "vampire", "evolve", "mech", "dragon", "star",
	"undead", "elem", "gambler", "demon", "neutral",
]

const FAMILY_STYLES := {
	"sacrifice": {
		"label": "献祭",
		"icon": "⚱",
		"color": Color("a29bfe"),
		"accent": Color("ffd166"),
		"deep": Color("5b4bb7"),
		"pale": Color("d6d0ff"),
		"motif": "soul_contract",
		"overlay": "sacrifice_soul_fx",
		"sfx": "contract",
	},
	"vampire": {
		"label": "血族",
		"icon": "✚",
		"color": Color("ff3b30"),
		"accent": Color("ff7675"),
		"deep": Color("7f1d1d"),
		"pale": Color("ffb3b3"),
		"motif": "blood_pulse",
		"overlay": "vampire_blood_fx",
		"sfx": "vampire_heal",
	},
	"evolve": {
		"label": "进化",
		"icon": "✥",
		"color": Color("7bed9f"),
		"accent": Color("fdcb6e"),
		"deep": Color("2f8f5b"),
		"pale": Color("c9f7d5"),
		"motif": "organic_bloom",
		"overlay": "evolve_bloom_fx",
		"sfx": "evolve",
	},
	"mech": {
		"label": "机械",
		"icon": "⚙",
		"color": Color("74b9ff"),
		"accent": Color("fdcb6e"),
		"deep": Color("2d5f8f"),
		"pale": Color("c9e5ff"),
		"motif": "magnetic_circuit",
		"overlay": "mech_circuit_fx",
		"sfx": "magnet",
	},
	"dragon": {
		"label": "龙",
		"icon": "◆",
		"color": Color("55efc4"),
		"accent": Color("fdcb6e"),
		"deep": Color("218c74"),
		"pale": Color("c8fff0"),
		"motif": "scales_roar",
		"overlay": "dragon_roar_fx",
		"sfx": "dragon_aura",
	},
	"star": {
		"label": "星灵",
		"icon": "✦",
		"color": Color("f6e58d"),
		"accent": Color("81ecec"),
		"deep": Color("8e7d2f"),
		"pale": Color("fff5c2"),
		"motif": "constellation_chain",
		"overlay": "star_chain_fx",
		"sfx": "star_chain",
	},
	"undead": {
		"label": "亡灵",
		"icon": "☠",
		"color": Color("dfe6e9"),
		"accent": Color("74b9ff"),
		"deep": Color("58616d"),
		"pale": Color("f5f6fa"),
		"motif": "bone_blue_smoke",
		"overlay": "undead_smoke_fx",
		"sfx": "undead_death",
	},
	"elem": {
		"label": "元素",
		"icon": "✧",
		"color": Color("81ecec"),
		"accent": Color("74b9ff"),
		"deep": Color("218c9b"),
		"pale": Color("e3ffff"),
		"motif": "prismatic_spell",
		"overlay": "element_spell_fx",
		"sfx": "element_cast",
	},
	"gambler": {
		"label": "赌徒",
		"icon": "◆",
		"color": Color("fdcb6e"),
		"accent": Color("e17055"),
		"deep": Color("8a6d1d"),
		"pale": Color("fff0c4"),
		"motif": "coin_flip",
		"overlay": "gambler_coin_fx",
		"sfx": "gamble",
	},
	"demon": {
		"label": "恶魔",
		"icon": "▲",
		"color": Color("e17055"),
		"accent": Color("a29bfe"),
		"deep": Color("7b2d26"),
		"pale": Color("ffc2b4"),
		"motif": "ember_rage",
		"overlay": "demon_rage_fx",
		"sfx": "demon_rage",
	},
	"neutral": {
		"label": "中立",
		"icon": "●",
		"color": Color("b2bec3"),
		"accent": Color("dfe6e9"),
		"deep": Color("636e72"),
		"pale": Color("f5f6fa"),
		"motif": "neutral_pulse",
		"overlay": "neutral_pulse_fx",
		"sfx": "neutral_buff",
	},
}


static func family_style(family: String) -> Dictionary:
	var key := normalize_family(family)
	return Dictionary(FAMILY_STYLES.get(key, FAMILY_STYLES["neutral"])).duplicate(true)


static func normalize_family(value: String) -> String:
	var key := value.to_lower()
	if FAMILY_STYLES.has(key):
		return key
	if key.contains("vampire") or key.contains("lifesteal") or key.contains("blood") \
			or key.contains("lockhp") or key.contains("maxhp"):
		return "vampire"
	if key.contains("sacrifice") or key.contains("sac") or key.contains("debt") \
			or key.contains("contract") or key.contains("soul") or key.contains("devour") \
			or key.contains("inherit"):
		return "sacrifice"
	if key.contains("evolve") or key.contains("evo") or key.contains("gene") \
			or key.contains("progress") or key.contains("hatch"):
		return "evolve"
	if key.contains("mech") or key.contains("magnet") or key.contains("charge") \
			or key.contains("guard") or key.contains("armor") or key.contains("fusion"):
		return "mech"
	if key.contains("dragon") or key.contains("aura"):
		return "dragon"
	if key.contains("star") or key.contains("chain") or key.contains("echo") \
			or key.contains("amp"):
		return "star"
	if key.contains("undead") or key.contains("skeleton") or key.contains("rebirth") \
			or key.contains("summon") or key.contains("death"):
		return "undead"
	if key.contains("elem") or key.contains("spell"):
		return "elem"
	if key.contains("gambl") or key.contains("coin") or key.contains("dice"):
		return "gambler"
	if key.contains("demon") or key.contains("rage"):
		return "demon"
	return "neutral"


static func event_style(event: Dictionary, card: Dictionary = {}) -> Dictionary:
	var kind := String(event.get("t", ""))
	var source := str(event.get("source", event.get("reason", "")))
	var family := ""
	match kind:
		"contract", "debt", "debt_settle":
			family = "sacrifice"
		"ch", "guard", "armor":
			family = "mech"
		"evop", "evo_full", "evolve", "gene", "progress", "progress_full", "progress_hatch":
			family = "evolve"
		"chain", "amp":
			family = "star"
		"summon", "rebirth":
			family = String(card.get("race", "undead"))
		"gamble":
			family = "gambler"
		"heal":
			if source != "" and normalize_family(source) != "neutral":
				family = normalize_family(source)
			else:
				family = String(card.get("race", ""))
		"damage":
			if int(event.get("echo", 0)) != 0 or int(event.get("chain_bonus", 0)) > 0:
				family = "star"
			elif String(card.get("race", "")) == "vampire":
				family = "vampire"
		"buff":
			var source_family := normalize_family(source)
			family = source_family if source != "" and source_family != "neutral" \
				else String(card.get("race", ""))
		_:
			var source_family2 := normalize_family(source)
			family = source_family2 if source != "" and source_family2 != "neutral" \
				else String(card.get("race", ""))
	if family == "":
		family = "neutral"
	var style := family_style(family)
	style["family"] = normalize_family(family)
	style["source"] = source
	style["kind"] = kind
	return style


static func source_label(style: Dictionary, kind: String) -> String:
	var family := String(style.get("family", "neutral"))
	match kind:
		"contract":
			return "契印"
		"debt":
			return "灵魂债务"
		"debt_settle":
			return "债务偿还"
		"debt-payoff":
			return "债务偿还"
		"debt-totem":
			return "债务图腾"
		"debt-battery":
			return "债务转化"
		"debt-lord":
			return "债务领主"
		"devour":
			return "灵魂摄取"
		"inherit":
			return "亡魂继承"
		"lifesteal", "race-heal", "heal-race":
			return "吸血"
		"vampire-on-dmg":
			return "血裔成长"
		"maxhp-buff":
			return "血池扩容"
		"lockhp":
			return "锁血"
		"summon":
			return "亡灵召唤"
		"rebirth":
			return "亡灵重生"
		"undead-death", "death-race-buff":
			return "亡语成长"
		"element":
			return "元素法术"
		"gamble":
			return "赌徒好运"
		"demon":
			return "恶魔狂怒"
		"mech":
			return "机械协议"
		"race-synergy":
			return "同族共鸣"
		"dragon-aura-minor":
			return "龙威回响"
		"dragon-aura":
			return "龙威"
		"dragon-attack":
			return "龙裔成长"
		"growth-self":
			return "龙裔成长"
		"atk-react":
			return "龙袭反应"
		"atkSk":
			return "攻击成长"
		"mech-head":
			return "合体核心"
		"multihit":
			return "恶魔共鸣"
		"on_dmg", "on-dmg":
			return "受击成长"
		"spell-cast":
			return "元素法术"
		"star-echo":
			return "星光回响"
		"star-amp":
			return "星界增幅"
	var label := String(style.get("label", "中立"))
	return label if label != "" else "中立"


static func placeholder_path(family: String, layer: String) -> String:
	var style := family_style(family)
	var key := String(style.get("motif", "neutral_pulse"))
	return "res://assets/fx/%s/%s_%s.png" % [normalize_family(family), key, layer]
