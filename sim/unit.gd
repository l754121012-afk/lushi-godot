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
var spell_skill: Dictionary = {}
var spell_cast_skill: Dictionary = {}
var attack_skill: Dictionary = {}
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
var _evoGainTick: int = 0 # 本场进化触发计数，每2次结算一次即时成长
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
var source_card: Dictionary = {}
var mech_head_grow: int = 0   # 合体头部：攻击后成长
var mech_dmg_grow: int = 0    # 合体肢体：受击后成长
var head_double: bool = false # 合体头部成长翻倍
var repair: int = 0           # 协同维修参数

# Web 战斗运行态。字段名保持与 index.html 一致，后续移植钩子时不做无意义改名。
var _t: int = 0
var _g: int = 0
var _gb: int = 0
var _dHit: int = 0
var _mhT: int = 0
var _iceT: int = 0
var _coreT: int = 0
var _atkT: int = 0
var _di: int = 0
var _udBase: int = 0
var _hit: int = 0
var _pr: int = 0
var _sc: int = 0
var _srT: int = 0
var _healT: int = 0
var _hT: int = 0
var _atkLeft: int = 0
var _ev: int = 0
var _skipOnce: bool = false
var _atkDone: bool = false
var _extraAtk: int = 0
var _phA: int = 0
var _phH: int = 0
var _poisonAtk: bool = false
var _dAtk: int = 0
var _noTurn: bool = false
var _side: String = ""
var _phase: int = 0

const PERSISTENT_RUNTIME_KEYS := [
	"_t", "_g", "_gb", "_mhT", "_iceT", "_coreT", "_di", "_udBase",
	"_hit", "_pr", "_sc", "_srT", "_healT", "_hT", "_ev",
]

static func from_card(card: Dictionary, id: int) -> RefCounted:
	var u = preload("res://sim/unit.gd").new()
	u.source_card = card.duplicate(true)
	u.uid = id
	u.card_name = String(card.get("n", "?"))
	u.star = int(card.get("star", card.get("s", 1)))
	u.race = String(card.get("race", "neutral"))
	u.atk = int(card.get("a", 0))
	u.hp = int(card.get("h", 0))
	u.max_hp = int(card.get("mh", u.hp))
	if card.has("k"):
		for ch in String(card["k"]):
			u.keywords.append(ch)
	u.skill = card.get("sk", {})
	u.battlecry = card.get("bc", {})
	u.spell_skill = card.get("sc", {})
	u.spell_cast_skill = card.get("scSk", {})
	u.attack_skill = card.get("atkSk", {})
	u.charge_max = int(card.get("chargeMax", 0))
	u.charge_fx = String(card.get("chargeFx", ""))
	u.charge_a = int(card.get("chargeA", 0))
	u.charge_h = int(card.get("chargeH", 0))
	u.part = String(card.get("part", ""))
	u.evo = int(card.get("evo", card.get("_evo", 0)))
	u.vd = int(card.get("vd", card.get("_vd", 0)))
	u.vc = int(card.get("vc", card.get("_vc", 0)))
	u.gene = int(card.get("gene", card.get("_gene", 0)))
	u.charge = int(card.get("charge", card.get("_charge", 0)))
	u.battle_armor = int(card.get("battleArmor", card.get("battle_armor", card.get("_battleArmor", 0))))
	u.mech_body = bool(card.get("_mechBody", card.get("_mech_body", false)))
	u.follow_type = String(card.get("followType", card.get("follow_type", card.get("_followType", ""))))
	u.follow_body_id = int(card.get("_followBodyId", 0))
	u.mech_head_grow = int(card.get("_mechHeadGrow", 0))
	u.mech_dmg_grow = int(card.get("_mechDmgGrow", 0))
	u.head_double = bool(card.get("_headDouble", false))
	u.repair = int(card.get("_repair", card.get("repair", 0)))
	u._t = int(card.get("_t", 0))
	u._g = int(card.get("_g", 0))
	u._gb = int(card.get("_gb", 0))
	u._dHit = int(card.get("_dHit", 0))
	u._mhT = int(card.get("_mhT", 0))
	u._iceT = int(card.get("_iceT", 0))
	u._coreT = int(card.get("_coreT", 0))
	u._atkT = int(card.get("_atkT", 0))
	u._di = int(card.get("_di", 0))
	u._udBase = int(card.get("_udBase", 0))
	u._hit = int(card.get("_hit", 0))
	u._pr = int(card.get("_pr", 0))
	u._sc = int(card.get("_sc", 0))
	u._srT = int(card.get("_srT", 0))
	u._healT = int(card.get("_healT", 0))
	u._hT = int(card.get("_hT", 0))
	u._atkLeft = int(card.get("_atkLeft", 0))
	u._ev = int(card.get("_ev", 0))
	u._skipOnce = bool(card.get("_skipOnce", false))
	u._atkDone = bool(card.get("_atkDone", false))
	u._extraAtk = int(card.get("_extraAtk", 0))
	u._phA = int(card.get("_phA", 0))
	u._phH = int(card.get("_phH", 0))
	u._poisonAtk = bool(card.get("_poisonAtk", false))
	u._dAtk = int(card.get("_dAtk", 0))
	u._noTurn = bool(card.get("_noTurn", false))
	u._side = String(card.get("_side", ""))
	u._phase = int(card.get("_phase", 0))
	return u

## 把战斗单位中的跨阶段运行态写回备战卡牌。
## 每场战斗重置的计数不在这里回写，避免把上一场战斗态带进下一场。
static func sync_runtime_to_card(card: Dictionary, u) -> void:
	if card == null or u == null:
		return
	card["a"] = u.atk
	# Web 在战后把所有持久随从恢复到最大生命，伤害与死亡状态不跨场。
	card["h"] = u.max_hp if u.max_hp > 0 else u.hp
	card["mh"] = u.max_hp if u.max_hp > 0 else u.hp
	card["n"] = u.card_name
	card["s"] = u.star
	card["star"] = u.star
	card["race"] = u.race
	card["k"] = "".join(u.keywords)
	card["sk"] = u.skill.duplicate(true)
	card["bc"] = u.battlecry.duplicate(true)
	card["sc"] = u.spell_skill.duplicate(true)
	card["scSk"] = u.spell_cast_skill.duplicate(true)
	card["atkSk"] = u.attack_skill.duplicate(true)
	for key in PERSISTENT_RUNTIME_KEYS:
		card[key] = u.get(key)
	card["_mechHeadGrow"] = u.mech_head_grow
	card["_mechDmgGrow"] = u.mech_dmg_grow
	card["_headDouble"] = u.head_double
	card["_repair"] = u.repair
	card["evo"] = u.evo
	card["_evo"] = u.evo
	card["vd"] = u.vd
	card["_vd"] = u.vd
	card["vc"] = u.vc
	card["_vc"] = u.vc
	card["gene"] = u.gene
	card["_gene"] = u.gene
	card["charge"] = u.charge
	card["_charge"] = u.charge

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
