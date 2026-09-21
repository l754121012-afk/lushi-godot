extends RefCounted
## 战斗单位：从 data/cards.json 的卡牌字典构造，只保留战斗需要的状态。
## 纯数据对象，不依赖任何节点，方便无头测试与批量模拟。

var uid: int = 0
var card_name: String = ""
var star: int = 1
var race: String = "neutral"
var atk: int = 0
var hp: int = 0
var max_hp: int = 0
var keywords: Array[String] = []
var skill: Dictionary = {}
var battlecry: Dictionary = {}
var gold_card: bool = false

# 战斗内状态
var alive: bool = true
var shield: bool = false
var taunt_active: bool = false
var attacked_this_round: bool = false
var evo: int = 0          # 进化条
var vd: int = 0           # 质变次数（身材线）
var vc: int = 0           # 质变次数（受击线）
var gene: int = 0         # 混沌始祖：基因层数
var stat_gain: int = 1    # 每格进化附带的即时收益基数
var pay_a: int = 0        # 债务结算前的攻击快照（血祭司祭/祭坛大师）
var pay_h: int = 0        # 债务结算前的生命快照
var charge: int = 0       # 机械：当前充能
var charge_max: int = 0   # 机械：充能上限
var charge_fx: String = ""  # shield / heal / rally / buff
var charge_a: int = 0
var charge_h: int = 0
var part: String = ""     # 机械合体部位：core / head / arm / leg
var battle_armor: int = 0 # 维修护甲（战斗内吸收）
var mech_body: bool = false   # 是否为合体体
var follow_type: String = ""  # 协同随从类型：strike / repair / guard
var follow_body_id: int = 0   # 所属合体体

static func from_card(card: Dictionary, id: int) -> RefCounted:
	var u = preload("res://sim/unit.gd").new()
	u.uid = id
	u.card_name = String(card.get("n", "?"))
	u.star = int(card.get("star", card.get("s", 1)))
	u.race = String(card.get("race", "neutral"))
	u.atk = int(card.get("a", 0))
	u.hp = int(card.get("h", 0))
	u.max_hp = u.hp
	if card.has("k"):
		for ch in String(card["k"]):
			u.keywords.append(ch)
	u.skill = card.get("sk", {})
	u.battlecry = card.get("bc", {})
	u.charge_max = int(card.get("chargeMax", 0))
	u.charge_fx = String(card.get("chargeFx", ""))
	u.charge_a = int(card.get("chargeA", 0))
	u.charge_h = int(card.get("chargeH", 0))
	u.part = String(card.get("part", ""))
	u.mech_body = bool(card.get("_mechBody", card.get("_mech_body", false)))
	u.follow_type = String(card.get("_followType", ""))
	u.follow_body_id = int(card.get("_followBodyId", 0))
	return u

func has_kw(k: String) -> bool:
	return keywords.has(k)

func refresh_alive() -> void:
	alive = hp > 0

func gain(a: int, h: int) -> void:
	atk += a
	hp += h
	if h > 0:
		max_hp += h

func describe() -> String:
	return "%s %d/%d [%s]%s" % [card_name, atk, hp, race, "" if alive else " ✝"]
