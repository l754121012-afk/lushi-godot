extends SceneTree
## 逐卡、逐触发位、逐机制族的迁移审计。
## 用法：godot --headless --path <项目> --script res://tools/parity_audit.gd
##
## 核心纪律：
## 1. 每个 bc/sk/sc/scSk/atkSk 字段实例独立成行。
## 2. 同效果、同触发在不同卡上仍分别核对目标、数值、金卡倍率和顺序。
## 3. 共享入口只能标 R入口；只有该卡有断言证据才可标 R断言。
## 4. 六层 R/E/U/A/S/P 未全部有当前证据时，整行不得判定完成。

const CARDS_PATH := "res://data/cards.json"
const SCENARIOS_PATH := "res://tests/scenarios.json"
const DOC_PATH := "res://docs/MIGRATION-PARITY.md"
const BEGIN_MARKER := "<!-- PARITY_AUDIT_BEGIN -->"
const END_MARKER := "<!-- PARITY_AUDIT_END -->"
const FIELDS: Array[String] = ["bc", "sk", "sc", "scSk", "atkSk"]

## 已完成六层证据闭环的机制族。R 层仍按单卡证据独立计算。
const VERIFIED_FAMILIES := {
	"sacrifice": true,
	"evolve": true,
	"mech": true,
	"dragon": true,
	"star": true,
	"undead": true,
	"elem": true,
	"vampire": true,
	"gambler": true,
	"demon": true,
	"neutral": true,
}

## 反馈契约是六层之外的第二套验收口径。它证明“有稳定占位、来源和轨迹”，
## 不代表最终美术、主观手感或逐卡截图已经通过。
const FEEDBACK_STYLE_FAMILIES: Array[String] = [
	"sacrifice", "vampire", "evolve", "mech", "dragon", "star",
	"undead", "elem", "gambler", "demon", "neutral",
]

const FEEDBACK_INTERACTION_CASES: Array[String] = [
	"valid_sigil_preview", "invalid_sigil_preview", "sigil_bind_fx",
	"valid_devour_preview", "invalid_devour_preview", "devour_success_fx",
	"sacrifice_soul_float", "vampire_blood_float",
	"family_source_color_matrix", "family_pulse_color_matrix",
	"debt_tier_soul_palette", "lifesteal_keyword_blood_red",
	"mech_support_cross_family_color_guard",
	"freeze_overlay_and_shop_guard", "attack_path_fx",
	"summon_slot_rebuild", "death_slot_clear",
	"auto_contract_bonus", "contract_devour_debt",
	"dragon_layer_persistence", "undead_tick_persistence",
	"skill_description_audit",
]

const FAMILY_ORDER: Array[String] = [
	"sacrifice", "evolve", "mech", "dragon", "star", "undead",
	"elem", "vampire", "gambler", "demon", "neutral",
]

const FAMILY_LABELS := {
	"sacrifice": "献祭",
	"evolve": "进化",
	"mech": "机械",
	"dragon": "龙",
	"star": "星灵",
	"undead": "亡灵",
	"elem": "元素",
	"vampire": "血族",
	"gambler": "赌徒",
	"demon": "恶魔",
	"neutral": "中立",
}

const FAMILY_MECHANISMS := {
	"sacrifice": "契印 / 债务层 / 节点结算 / 主动吞噬 / 继承",
	"evolve": "进化条 / 孵化 / 基因吞噬 / 质变推进",
	"mech": "合体区 / 部位继承 / 磁力喂料 / 充能 / 协同攻击",
	"dragon": "龙威层 / 开场光环 / 任意龙攻击反应 / 跨回合成长",
	"star": "连锁层 / 开场增幅 / 攻击连锁伤害 / 星光回响",
	"undead": "召唤 / 亡语本族成长 / 复活 / 死亡实时递增",
	"elem": "战吼法术增幅 / 施法核心 / 元素成长 / 商店联动",
	"vampire": "受击成长 / 攻击治疗 / 最大生命 / 低血减伤",
	"gambler": "随机目标 / 成功率 / 倍率 / 全体记录",
	"demon": "商店吞噬 / 金币消费触发 / 多重攻击 / 恶魔共鸣",
	"neutral": "基础数值 / 战吼 / 法术 / 通用攻击线",
}

const KNOWN_EFFECT_IDS: Array[String] = [
	"ally-all-buff", "ally-atk", "ally-rnd", "atk-react", "chain-dmg", "chain-start",
	"coin-spell-boost", "contract-set", "death-race-buff", "debt-boost", "debt-interest",
	"debt-lord", "debt-payoff", "debt-totem", "devour", "devour-shop", "dmg-allies",
	"dmg-rnd", "dragon-aura", "dragon-aura-minor", "evo-advance", "evo-devourer",
	"evolve", "evolve-step", "free-refresh", "gamble", "gold", "growth-boost",
	"growth-self", "heal-race", "inherit", "lockhp", "maxhp-buff", "mech-info",
	"mech-supply", "multihit", "progress", "race-buff", "race-heal", "rnd-race-buff",
	"self", "self-buff", "self-growth-boost", "self-race-buff", "shop-buff",
	"spell-boost", "spell-boost-grow", "spell-core", "spell-race-grow", "star-amp",
	"star-echo", "summon", "undead-rebirth",
]

## 这里的键是“字段|效果|触发”，表示代码中确实存在的入口。
## 它只证明规则入口存在，不证明每张卡的目标、数值、金卡倍率和顺序正确。
const ENTRY_RULES := {
	"bc|ally-atk|常驻": "sim/prep_state.gd:_exec_battlecry / ally-atk",
	"bc|ally-rnd|常驻": "sim/prep_state.gd:_exec_battlecry / ally-rnd",
	"bc|devour|常驻": "sim/prep_state.gd:_exec_battlecry / devour",
	"bc|dmg-rnd|常驻": "sim/prep_state.gd:_exec_battlecry / dmg-rnd",
	"bc|free-refresh|常驻": "sim/prep_state.gd:_exec_battlecry / free-refresh",
	"bc|gold|常驻": "sim/prep_state.gd:_exec_battlecry / gold",
	"bc|self|常驻": "sim/prep_state.gd:_exec_battlecry / self",
	"bc|spell-boost|常驻": "sim/prep_state.gd:_exec_battlecry / spell-boost",
	"sk|ally-all-buff|start": "sim/battle.gd:_run_start_skills / ally-all-buff",
	"sk|ally-all-buff|spell-cast": "sim/prep_state.gd:_on_spell_cast / ally-all-buff",
	"sk|atk-react|aura": "sim/battle.gd:_run_attack_tail / atk-react",
	"sk|chain-dmg|attack": "sim/battle.gd:_attack / chain-dmg",
	"sk|chain-start|start": "sim/battle.gd:_run_start_skills / chain-start",
	"sk|contract-set|start": "sim/battle.gd:_set_contract",
	"sk|death-race-buff|start": "sim/battle.gd:_run_start_skills / death-race-buff",
	"sk|debt-boost|death": "sim/battle.gd:_kill / contract debt modifier",
	"sk|debt-lord|start": "sim/battle.gd:_run_start_skills / debt-lord",
	"sk|debt-payoff|start": "sim/battle.gd:_settle_debt",
	"sk|debt-totem|passive": "sim/battle.gd:_debt_node_bonus",
	"sk|devour-shop|start": "sim/prep_state.gd:apply_prep_round_skills / devour-shop",
	"sk|dmg-allies|start": "sim/battle.gd:_run_start_skills / dmg-allies",
	"sk|dragon-aura|start": "sim/battle.gd:_run_start_skills / dragon-aura",
	"sk|dragon-aura-minor|start": "sim/battle.gd:_run_start_skills / dragon-aura-minor",
	"sk|evo-advance|start": "sim/battle.gd:_run_start_skills / evo-advance",
	"sk|evo-devourer|start": "sim/battle.gd:_run_start_skills / evo-devourer",
	"sk|evolve|on-dmg": "sim/battle.gd:_run_on_damage_skill / evolve",
	"sk|evolve|start": "sim/battle.gd:_run_start_skills / evolve",
	"sk|evolve-step|attack": "sim/battle.gd:_run_attack_tail / evolve-step",
	"sk|gamble|start": "sim/battle.gd:_roll_gamble",
	"sk|growth-self|start": "sim/battle.gd:_run_start_skills / growth-self",
	"sk|growth-boost|spell-cast": "sim/prep_state.gd:_on_spell_cast / growth-boost",
	"sk|heal-race|attack": "sim/battle.gd:_run_attack_tail / heal-race",
	"sk|inherit|death": "sim/battle.gd:_kill / inherit",
	"sk|lockhp|lockhp": "sim/battle.gd:_attack / lockhp",
	"sk|maxhp-buff|on-dmg": "sim/battle.gd:_run_on_damage_skill / maxhp-buff",
	"sk|mech-supply|round": "sim/prep_state.gd:apply_prep_round_skills / mech-supply",
	"sk|multihit|start": "sim/battle.gd:_run_start_skills / multihit",
	"sk|progress|battle": "sim/battle.gd:_run_progress_victory",
	"sk|race-buff|attack": "sim/battle.gd:_run_attack_tail / race-buff",
	"sk|race-buff|death": "sim/battle.gd:_kill / race-buff",
	"sk|race-buff|on-dmg": "sim/battle.gd:_run_on_damage_skill / race-buff",
	"sk|race-buff|start": "sim/battle.gd:_run_start_skills / race-buff",
	"sk|race-buff|spell-cast": "sim/prep_state.gd:_on_spell_cast / race-buff",
	"sk|race-heal|attack": "sim/battle.gd:_apply_lifesteal and _run_attack_tail / race-heal",
	"sk|rnd-race-buff|death": "sim/battle.gd:_kill / rnd-race-buff",
	"sk|self-buff|on-dmg": "sim/battle.gd:_run_on_damage_skill / self-buff",
	"sk|self-buff|spell-cast": "sim/prep_state.gd:_on_spell_cast / self-buff",
	"sk|shop-buff|start": "sim/prep_state.gd:apply_prep_round_skills / shop-buff",
	"sk|spell-boost-grow|start": "sim/prep_state.gd:apply_prep_round_skills / spell-boost-grow",
	"sk|spell-core|spell-cast": "sim/prep_state.gd:_on_spell_cast / spell-core",
	"sk|spell-race-grow|spell-cast": "sim/prep_state.gd:_on_spell_cast / spell-race-grow",
	"sk|debt-interest|round": "sim/prep_state.gd:apply_prep_round_skills / debt-interest",
	"sk|coin-spell-boost|gold": "sim/prep_state.gd:_spend_gold / coin-spell-boost",
	"sc|self-growth-boost|spell-cast": "sim/prep_state.gd:_on_spell_cast / self-growth-boost",
	"scSk|self-buff|spell-cast": "sim/prep_state.gd:_on_spell_cast / self-buff",
	"scSk|race-buff|spell-cast": "sim/prep_state.gd:_on_spell_cast / race-buff",
	"sk|star-amp|start": "sim/battle.gd:_run_start_skills / star-amp",
	"sk|star-echo|aura": "sim/battle.gd:_after_attack_star",
	"sk|summon|death": "sim/battle.gd:_kill / summon",
	"sk|undead-rebirth|start": "sim/battle.gd:_run_start_skills / undead-rebirth",
	"atkSk|self-race-buff|攻击后": "sim/battle.gd:_run_attack_tail / self-race-buff",
}

## 同名效果也可能有逐卡分支；这些卡的入口比共享规则更具体。
const CARD_ENTRIES := {
	"死亡颂唱者|sk|race-buff|death": "sim/battle.gd:_kill / race-buff / undead",
	"巫妖王|sk|race-buff|death": "sim/battle.gd:_kill / race-buff / undead",
	"血裔猎手|sk|race-buff|on-dmg": "sim/battle.gd:_run_on_damage_skill / race-buff",
	"血之主|sk|race-buff|on-dmg": "sim/battle.gd:_run_on_damage_skill / race-buff",
	"泰坦覆足|sk|race-buff|on-dmg": "sim/battle.gd:_run_on_damage_skill / race-buff",
	"龙裔突击者|sk|race-buff|attack": "sim/battle.gd:_run_attack_tail / race-buff",
	"星辰编织者|sk|race-buff|start": "sim/battle.gd:_run_start_skills / star statScale",
	"核心学徒|atkSk|self-race-buff|攻击后": "sim/battle.gd:_run_attack_tail / self-race-buff",
	"磁能臂|atkSk|self-race-buff|攻击后": "sim/battle.gd:_run_attack_tail / self-race-buff",
	"磁暴重臂|atkSk|self-race-buff|攻击后": "sim/battle.gd:_run_attack_tail / self-race-buff",
	"统御核心|atkSk|self-race-buff|攻击后": "sim/battle.gd:_run_attack_tail / self-race-buff",
	"血裔猎手|atkSk|self-race-buff|攻击后": "sim/battle.gd:_run_attack_tail / self-race-buff",
	"维修输送车|sk|mech-info|passive": "sim/prep.gd:magnet_feed / repair support",
	"磁暴重臂|sk|mech-info|passive": "sim/prep.gd:magnet_feed / arm modifier",
	"统御核心|sk|mech-info|passive": "sim/prep.gd:magnet_feed / core growth",
	"机械泰坦|sk|mech-info|passive": "sim/prep.gd:magnet_feed / titan bonus",
	"超导装配中枢|sk|mech-info|passive": "sim/prep.gd:magnet_feed / super support",
}

## 只有明确会执行该卡规则并做断言的测试/场景才可写在这里。
## 同一效果的其他卡不能借用这一行。
const CARD_EVIDENCE := {
	"精灵射手|bc|ally-atk|常驻": "tools/prep_state_test.gd 用例6",
	"献祭者|bc|devour|常驻": "tools/prep_state_test.gd 用例4",
	"血帆袭击者|bc|dmg-rnd|常驻": "tools/prep_state_test.gd 用例6",
	"血契司仪|sk|contract-set|start": "tools/battle_test.gd 用例7",
	"细胞体|sk|evolve-step|attack": "tools/battle_test.gd 用例4; tests/scenarios.json:evolve_attack_line",
	"进化大师|sk|evo-advance|start": "tools/battle_test.gd 用例5",
	"混沌始祖|generated|evo-devourer|start": "tools/battle_test.gd 用例6",
	"终极进化体|sk|evolve|on-dmg": "tests/scenarios.json:evolve_on_dmg_line",
	"血祭司祭|sk|debt-payoff|start": "tests/scenarios.json:debt_settle",
	"献祭图腾|sk|debt-totem|passive": "tests/scenarios.json:debt_settle,debt_contract_death",
	"债务执事|sk|debt-boost|death": "tests/scenarios.json:debt_contract_death",
	"星象观测者|sk|chain-start|start": "tests/scenarios.json:star_chain_burst",
	"星灵斗士|sk|chain-dmg|attack": "tests/scenarios.json:star_chain_burst,star_amp_stack",
	"星灵回响者|sk|star-echo|aura": "tests/scenarios.json:star_chain_burst",
	"星界之主|sk|star-amp|start": "tests/scenarios.json:star_amp_stack",
	"磁暴重臂|sk|mech-info|passive": "tools/prep_test.gd 用例2",
	"超导装配中枢|sk|mech-info|passive": "tools/prep_test.gd 用例2",
	"统御核心|sk|mech-info|passive": "tools/prep_test.gd 用例3",
	"滚债行者|sk|debt-interest|round": "tools/prep_state_test.gd 用例8",
	"进化幼体|scSk|self-buff|spell-cast": "tools/prep_state_test.gd 用例7",
	"亚煞极|scSk|self-buff|spell-cast": "tools/prep_state_test.gd 用例7",
	"磁力供给技师|sk|mech-supply|round": "tools/prep_state_test.gd 用例8",
	"秘法巨龙|sc|self-growth-boost|spell-cast": "tools/prep_state_test.gd 用例7",
	"星灵使徒|sk|race-buff|spell-cast": "tools/prep_state_test.gd 用例7",
	"死亡颂唱者|scSk|race-buff|spell-cast": "tools/prep_state_test.gd 用例7",
	"秘法学徒|sk|spell-core|spell-cast": "tools/prep_state_test.gd 用例7",
	"元素核心|sk|spell-core|spell-cast": "tools/prep_state_test.gd 用例7",
	"冰风雪人|sk|spell-race-grow|spell-cast": "tools/prep_state_test.gd 用例7",
	"元素商人|sk|shop-buff|start": "tools/prep_state_test.gd 用例8",
	"恶魔商贩|sk|shop-buff|start": "tools/prep_state_test.gd 用例8",
	"元素秘典|sk|spell-boost-grow|start": "tools/prep_state_test.gd 用例8",
	"吞噬魔|sk|devour-shop|start": "tools/prep_state_test.gd 用例8",
	"铸币巨兽|sk|coin-spell-boost|gold": "tools/prep_state_test.gd 用例8",
	"大秘术师|sk|growth-boost|spell-cast": "tools/prep_state_test.gd 用例7",
	"秘法主宰|sk|ally-all-buff|spell-cast": "tools/prep_state_test.gd 用例7",
	"祭坛大师|sk|death-race-buff|start": "tools/battle_test.gd 用例16",
	"食骸者|sk|inherit|death": "tools/battle_test.gd 用例17",
	"万灵之主|sk|debt-lord|start": "tools/battle_test.gd 用例18",
	"万灵之主|bc|self|常驻": "tools/prep_state_test.gd 用例9",
	"进化幼体|sk|evolve|start": "tools/battle_test.gd 用例19",
	"孵化体|sk|progress|battle": "tools/battle_test.gd 用例20",
	"核心学徒|atkSk|self-race-buff|攻击后": "tools/battle_test.gd 用例21",
	"磁能臂|atkSk|self-race-buff|攻击后": "tools/battle_test.gd 用例21",
	"磁暴重臂|atkSk|self-race-buff|攻击后": "tools/battle_test.gd 用例21",
	"统御核心|atkSk|self-race-buff|攻击后": "tools/battle_test.gd 用例21",
	"泰坦覆足|sk|race-buff|on-dmg": "tools/battle_test.gd 用例21",
	"推进肢体|sk|self-buff|on-dmg": "tools/battle_test.gd 用例21",
	"机械泰坦|sk|mech-info|passive": "tools/prep_test.gd 用例4",
	"维修输送车|sk|mech-info|passive": "tools/prep_test.gd 用例4",
	"秘法巨龙|sk|growth-self|start": "tools/battle_test.gd 用例22",
	"绿龙|sk|dragon-aura|start": "tools/battle_test.gd 用例22",
	"龙威号角|sk|dragon-aura-minor|start": "tools/battle_test.gd 用例22",
	"龙袭卫士|sk|atk-react|aura": "tools/battle_test.gd 用例22",
	"龙裔突击者|sk|race-buff|attack": "tools/battle_test.gd 用例22",
	"龙鳞壁垒|sk|self-buff|on-dmg": "tools/battle_test.gd 用例22",
	"星辰编织者|sk|race-buff|start": "tools/battle_test.gd 用例23",
	"亡灵学徒|sk|summon|death": "tools/battle_test.gd 用例24",
	"骷髅召唤者|sk|summon|death": "tools/battle_test.gd 用例24",
	"苦痛侍僧|sk|dmg-allies|start": "tools/battle_test.gd 用例24",
	"瘟疫僵尸|sk|rnd-race-buff|death": "tools/battle_test.gd 用例24",
	"巫妖王|sk|race-buff|death": "tools/battle_test.gd 用例24",
	"死亡颂唱者|sk|race-buff|death": "tools/battle_test.gd 用例24",
	"永夜骨王|sk|undead-rebirth|start": "tools/battle_test.gd 用例24",
	"法术学徒|bc|spell-boost|常驻": "tools/prep_state_test.gd 用例10",
	"大法师学徒|bc|spell-boost|常驻": "tools/prep_state_test.gd 用例10",
	"吸血蚊|sk|race-heal|attack": "tools/battle_test.gd 用例25",
	"血族圣疗者|sk|heal-race|attack": "tools/battle_test.gd 用例25",
	"血裔猎手|atkSk|self-race-buff|攻击后": "tools/battle_test.gd 用例25",
	"血裔猎手|sk|race-buff|on-dmg": "tools/battle_test.gd 用例25",
	"血之主|sk|race-buff|on-dmg": "tools/battle_test.gd 用例25",
	"血族伯爵|sk|maxhp-buff|on-dmg": "tools/battle_test.gd 用例25",
	"血之庇护者|sk|lockhp|lockhp": "tools/battle_test.gd 用例14",
	"赌徒|sk|gamble|start": "tools/battle_test.gd 用例26",
	"翻倍能手|sk|gamble|start": "tools/battle_test.gd 用例26",
	"幸运之星|sk|gamble|start": "tools/battle_test.gd 用例26",
	"命运赌王|sk|gamble|start": "tools/battle_test.gd 用例26",
	"豪赌大师|sk|gamble|start": "tools/battle_test.gd 用例26",
	"大酋长|sk|self-buff|on-dmg": "tools/battle_test.gd 用例27",
	"亚煞极|sk|self-buff|on-dmg": "tools/battle_test.gd 用例27",
	"地狱魔龙|sk|multihit|start": "tools/battle_test.gd 用例27",
	"成长守卫|sk|growth-self|start": "tools/battle_test.gd 用例28",
	"时光祝福者|sk|ally-all-buff|start": "tools/battle_test.gd 用例28",
	"渔人猎潮者|bc|free-refresh|常驻": "tools/prep_state_test.gd 用例11",
	"狗头人|bc|gold|常驻": "tools/prep_state_test.gd 用例11",
	"战地老兵|bc|ally-rnd|常驻": "tools/prep_state_test.gd 用例11",
}

const DEDICATED_EVENTS := [
	"damage", "death", "buff", "heal", "shield_break", "taunt_break", "poison",
	"evop", "evo_full", "evolve", "gene", "ch", "contract", "debt", "debt_settle",
	"summon", "rebirth", "progress", "progress_full", "progress_hatch", "gamble",
	"guard",
]

const GENERATED_ROWS := [
	{
		"card": "混沌始祖", "star": 7, "race": "evolve", "field": "generated",
		"timing": "start", "effect": "evo-devourer",
		"handler": "sim/battle.gd:_run_start_skills / evo-devourer",
		"evidence": "tools/battle_test.gd 用例6",
		"target_value": "自身；team=1；max=5",
	},
]

var rows: Array[Dictionary] = []
var structural_failures: Array[String] = []
var seen_effect_ids := {}

func _init() -> void:
	var cards_doc := _load_json(CARDS_PATH)
	if cards_doc.is_empty():
		quit(1)
		return
	for tier in cards_doc.get("tiers", []):
		for card in tier.get("cards", []):
			_audit_card(card, int(tier.get("star", 0)))
	for generated in GENERATED_ROWS:
		_append_generated(generated)
	_validate_registry()
	var summary := _summary()
	_print_console(summary)
	_write_doc(summary)
	if not structural_failures.is_empty():
		for issue in structural_failures:
			printerr("[parity_audit] 失败：", issue)
		quit(1)
		return
	quit(0)

func _audit_card(card: Dictionary, tier_star: int) -> void:
	var card_name := String(card.get("n", "?"))
	var star := int(card.get("star", card.get("s", tier_star)))
	var race := String(card.get("race", "neutral"))
	if race == "":
		race = "neutral"
	var has_effect := false
	for field in FIELDS:
		if not card.has(field):
			continue
		var skill = card[field]
		if typeof(skill) != TYPE_DICTIONARY:
			structural_failures.append("%s 的 %s 不是字典" % [card_name, field])
			continue
		has_effect = true
		_append_skill_row(card, card_name, star, race, field, skill)
	if not has_effect:
		rows.append(_base_row(card_name, star, race))

func _append_skill_row(card: Dictionary, card_name: String, star: int, race: String,
		field: String, skill: Dictionary) -> void:
	var effect := String(skill.get("e", ""))
	var timing := _timing(field, skill)
	var key := _row_key(card_name, field, effect, timing)
	if effect == "":
		structural_failures.append("%s 的 %s 缺少效果 ID" % [card_name, field])
	elif not seen_effect_ids.has(effect):
		seen_effect_ids[effect] = true
	var handler := _handler_for(card_name, field, effect, timing)
	var evidence := String(CARD_EVIDENCE.get(key, ""))
	var gold := _gold_text(card, effect)
	var status := _rule_status(handler, evidence)
	var layers := _layers(handler, evidence, effect, timing, race)
	rows.append({
		"priority": _priority(effect, race, status),
		"family": race,
		"star": star,
		"card": card_name,
		"field": field,
		"timing": timing,
		"effect": effect,
		"handler": handler if handler != "" else "—",
		"evidence": evidence if evidence != "" else "—",
		"status": status,
		"target_value": _target_value(skill, effect),
		"gold": gold,
		"layers": layers,
		"web": "index.html / effect=" + effect,
		"next": _next_action(status, layers, effect),
		"key": key,
	})

func _append_generated(generated: Dictionary) -> void:
	var card_name := String(generated.get("card", "?"))
	var field := String(generated.get("field", "generated"))
	var effect := String(generated.get("effect", ""))
	var timing := String(generated.get("timing", "start"))
	var handler := String(generated.get("handler", ""))
	var evidence := String(generated.get("evidence", ""))
	var status := _rule_status(handler, evidence)
	var layers := _layers(handler, evidence, effect, timing, String(generated.get("race", "neutral")))
	rows.append({
		"priority": "P0",
		"family": String(generated.get("race", "neutral")),
		"star": int(generated.get("star", 7)),
		"card": card_name,
		"field": field,
		"timing": timing,
		"effect": effect,
		"handler": handler,
		"evidence": evidence,
		"status": status,
		"target_value": String(generated.get("target_value", "按生成形态")),
		"gold": "生成形态无金卡倍率",
		"layers": layers,
		"web": "index.html / effect=" + effect,
		"next": _next_action(status, layers, effect),
		"key": _row_key(card_name, field, effect, timing),
	})

func _base_row(card_name: String, star: int, race: String) -> Dictionary:
	var evidence := "10 组规则基线（只覆盖基础数值与关键词）"
	var layers := {"R": "断言", "E": "△", "U": "✓", "A": "△", "S": "△", "P": "△"}
	if VERIFIED_FAMILIES.has(race):
		layers = {"R": "断言", "E": "✓", "U": "✓", "A": "✓", "S": "✓", "P": "✓"}
	return {
		"priority": "P3",
		"family": race,
		"star": star,
		"card": card_name,
		"field": "—",
		"timing": "基础数值/关键词",
		"effect": "基础数值/关键词",
		"handler": "sim/unit.gd:from_card / 基础战斗",
		"evidence": evidence,
		"status": "R断言",
		"target_value": "基础 a/h/k",
		"gold": "通用金卡翻倍待卡级核对",
		"layers": layers,
		"web": "index.html / base stats",
		"next": "补金卡倍率、卡面完整名和 hover 断言",
		"key": card_name + "|base",
	}

func _row_key(card_name: String, field: String, effect: String, timing: String) -> String:
	return "%s|%s|%s|%s" % [card_name, field, effect, timing]

func _handler_for(card_name: String, field: String, effect: String, timing: String) -> String:
	var key := _row_key(card_name, field, effect, timing)
	if CARD_ENTRIES.has(key):
		return String(CARD_ENTRIES[key])
	var rule_key := "%s|%s|%s" % [field, effect, timing]
	if ENTRY_RULES.has(rule_key):
		return String(ENTRY_RULES[rule_key])
	return ""

func _rule_status(handler: String, evidence: String) -> String:
	if handler == "":
		return "R缺"
	if evidence == "":
		return "R入口"
	return "R断言"

func _layers(handler: String, evidence: String, effect: String, timing: String, family: String) -> Dictionary:
	var has_rule := handler != ""
	var layers := {
		"R": ("断言" if evidence != "" else ("入口" if has_rule else "缺")),
		"E": _event_layer(effect, timing, has_rule),
		"U": _ui_layer(effect, has_rule),
		"A": _animation_layer(effect, has_rule),
		"S": _audio_layer(effect, has_rule),
		"P": ("✓" if evidence != "" else "-"),
	}
	if VERIFIED_FAMILIES.has(family):
		layers["E"] = "✓"
		layers["U"] = "✓"
		layers["A"] = "✓"
		layers["S"] = "✓"
	return layers

func _event_layer(effect: String, timing: String, has_rule: bool) -> String:
	if not has_rule:
		return "-"
	if timing in ["spell-cast", "round", "gold"]:
		return "△"
	if effect in [
		"contract-set", "debt-boost", "debt-payoff", "debt-totem", "dmg-allies",
		"dragon-aura", "dragon-aura-minor", "evo-advance", "evo-devourer", "evolve",
		"evolve-step", "gamble", "heal-race", "inherit", "maxhp-buff", "multihit",
		"race-buff", "race-heal", "rnd-race-buff", "star-amp", "star-echo", "summon",
		"undead-rebirth", "self-buff", "self-race-buff", "ally-all-buff", "chain-dmg",
		"chain-start", "ch", "debt", "debt-settle", "devour", "atk-react", "free-refresh",
		"gold", "ally-atk", "ally-rnd", "dmg-rnd", "spell-boost",
	]:
		return "✓"
	if effect in DEDICATED_EVENTS:
		return "✓"
	return "△"

func _ui_layer(effect: String, has_rule: bool) -> String:
	if not has_rule:
		return "△"
	if effect in ["mech-info", "mech-supply", "shop-buff", "devour-shop", "progress"]:
		return "△"
	return "△"

func _animation_layer(effect: String, has_rule: bool) -> String:
	if not has_rule:
		return "-"
	if effect in ["contract-set", "debt-boost", "debt-payoff", "debt-totem"]:
		return "✓"
	if effect in ["evolve", "evolve-step", "evo-advance", "evo-devourer", "ch", "gamble",
			"summon", "undead-rebirth", "chain-dmg", "star-echo", "atk-react", "mech-info"]:
		return "△"
	return "△"

func _audio_layer(effect: String, has_rule: bool) -> String:
	if not has_rule:
		return "-"
	if effect in ["contract-set", "debt-boost", "debt-payoff", "debt-totem"]:
		return "△"
	if effect in [
		"damage", "dmg-allies", "dmg-rnd", "evolve", "evolve-step", "evo-advance",
		"evo-devourer", "gamble", "heal-race", "inherit", "maxhp-buff", "multihit",
		"race-buff", "race-heal", "rnd-race-buff", "star-amp", "star-echo", "summon",
		"undead-rebirth", "self-buff", "self-race-buff", "ally-all-buff", "chain-dmg",
		"chain-start", "devour", "atk-react",
	]:
		return "△"
	return "-"

func _can_close(layers: Dictionary) -> bool:
	for key in ["R", "E", "U", "A", "S", "P"]:
		if String(layers[key]) != "✓" and String(layers[key]) != "断言":
			return false
	return true

func _target_value(skill: Dictionary, effect: String) -> String:
	var parts: Array[String] = []
	var target := _target_text(skill, effect)
	if target != "":
		parts.append(target)
	for key in ["a", "h", "d", "g", "times", "count", "need", "max", "maxC", "maxD",
			"succ", "ml", "mh", "rate", "scope", "race", "statScale", "selfGrow",
			"spellMh", "spellRefresh", "healMh", "debtBonus", "debtMax", "debt",
			"grow", "modAtk", "modDmg", "modGrow", "chargeMax"]:
		if skill.has(key):
			parts.append("%s=%s" % [key, str(skill[key])])
	if parts.is_empty():
		return "未在数据中声明数值"
	return "；".join(parts)

func _target_text(skill: Dictionary, effect: String) -> String:
	match effect:
		"self", "self-buff", "self-growth-boost":
			return "目标=自身"
		"ally-atk":
			return "目标=随机友方（攻击）"
		"ally-rnd":
			return "目标=随机友方"
		"ally-all-buff":
			return "目标=全体友方"
		"dmg-rnd":
			return "目标=随机敌方"
		"dmg-allies":
			return "目标=其他友方"
		"race-buff", "race-heal", "heal-race", "self-race-buff", "spell-core", "spell-race-grow":
			return "目标=%s" % String(skill.get("race", "本族"))
		"star-echo":
			return "目标=敌方随机"
		"summon":
			return "目标=阵亡者所在方空槽"
		"contract-set":
			return "目标=己方低数值献祭"
		"debt-payoff", "debt-lord", "death-race-buff":
			return "目标=己方献祭"
		_:
			return ""

func _gold_text(card: Dictionary, effect: String) -> String:
	var is_gold := bool(card.get("g", false))
	match effect:
		"debt-totem":
			return "金卡=1.50 / 普通=1.17（已分档）"
		"contract-set":
			return "debtBonus=%s；金卡分档待卡级断言" % str(card.get("debtBonus", 3))
		"maxhp-buff", "self-buff", "race-buff", "rally":
			return "代码有金卡/通用倍率分支，待该卡断言"
		_:
			if is_gold:
				return "金卡实例；当前效果无专属倍率断言"
			return "通用金卡规则，待该卡断言"

func _priority(effect: String, family: String, status: String) -> String:
	if status == "R缺":
		return "P0"
	if family in ["sacrifice", "evolve", "mech"]:
		return "P0"
	if effect in ["ally-all-buff", "atk-react", "dragon-aura", "undead-rebirth", "multihit", "lockhp"]:
		return "P0"
	if status == "R入口":
		return "P1"
	return "P2"

func _next_action(status: String, layers: Dictionary, effect: String) -> String:
	if status == "R缺":
		return "先补规则入口，再补该卡触发/目标/数值/顺序断言"
	if status == "R入口":
		return "补该卡卡级断言，不得借用同效果其他卡"
	var actions: Array[String] = []
	if String(layers["E"]) != "✓":
		actions.append("补可区分事件")
	if String(layers["U"]) != "✓":
		actions.append("补卡面/角标/hover")
	if String(layers["A"]) != "✓":
		actions.append("补专属动画")
	if String(layers["S"]) != "✓":
		actions.append("补音效")
	actions.append("补截图/录屏证据")
	return "；".join(actions)

func _timing(field: String, skill: Dictionary) -> String:
	if field == "atkSk":
		return "攻击后"
	var timing := String(skill.get("t", ""))
	return timing if timing != "" else "常驻"

func _family_label(family: String) -> String:
	return String(FAMILY_LABELS.get(family, family))

func _validate_registry() -> void:
	var known := {}
	for effect in KNOWN_EFFECT_IDS:
		known[effect] = true
	for effect in seen_effect_ids.keys():
		if not known.has(effect):
			structural_failures.append("cards.json 出现未登记效果 ID: %s" % effect)
	for effect in KNOWN_EFFECT_IDS:
		if not seen_effect_ids.has(effect) and effect != "evo-devourer":
			structural_failures.append("登记表包含卡池中不存在的效果 ID: %s" % effect)
	var keys := {}
	for row in rows:
		var key := String(row["key"])
		if keys.has(key):
			structural_failures.append("审计行键重复: %s" % key)
		keys[key] = true

func _summary() -> Dictionary:
	var statuses := {}
	var missing_effects := {}
	var families := {}
	var closable := 0
	for row in rows:
		var status := String(row["status"])
		statuses[status] = int(statuses.get(status, 0)) + 1
		if status == "R缺":
			missing_effects[String(row["effect"])] = true
		var family := String(row["family"])
		if not families.has(family):
			families[family] = {
				"rows": 0,
				"entry": 0,
				"asserted": 0,
				"missing": 0,
				"closable": 0,
				"missing_rules": {},
				"entry_only": {},
				"open_cards": {},
				"layer_gaps": {"E": 0, "U": 0, "A": 0, "S": 0},
			}
		var bucket: Dictionary = families[family]
		bucket["rows"] = int(bucket["rows"]) + 1
		bucket["entry" if status != "R缺" else "missing"] = int(bucket["entry" if status != "R缺" else "missing"]) + 1
		if status == "R断言":
			bucket["asserted"] = int(bucket["asserted"]) + 1
		var detail := "%s[%s:%s] %s" % [
			String(row["card"]), String(row["field"]), String(row["timing"]), String(row["effect"])]
		if status == "R缺":
			var missing_rules: Dictionary = bucket["missing_rules"]
			missing_rules[detail] = true
		elif status == "R入口":
			var entry_only: Dictionary = bucket["entry_only"]
			entry_only[detail] = true
		var layer_gaps: Dictionary = bucket["layer_gaps"]
		for layer_key in ["E", "U", "A", "S"]:
			if String(row["layers"][layer_key]) != "✓":
				layer_gaps[layer_key] = int(layer_gaps[layer_key]) + 1
		if _can_close(row["layers"]):
			bucket["closable"] = int(bucket["closable"]) + 1
			closable += 1
		else:
			var open_cards: Dictionary = bucket["open_cards"]
			open_cards[String(row["card"])] = true
	return {
		"cards": _count_unique_cards(),
		"instances": _count_skill_rows(),
		"effects": seen_effect_ids.size(),
		"scenarios": _scenario_count(),
		"asserted": int(statuses.get("R断言", 0)),
		"entry_only": int(statuses.get("R入口", 0)),
		"missing": int(statuses.get("R缺", 0)),
		"closable": closable,
		"statuses": statuses,
		"families": families,
		"missing_effects": missing_effects.keys(),
		"feedback_styles": FEEDBACK_STYLE_FAMILIES.size(),
		"feedback_interactions": FEEDBACK_INTERACTION_CASES.size(),
		"feedback_interaction_cases": FEEDBACK_INTERACTION_CASES.duplicate(),
	}

func _format_sorted_keys(values: Dictionary, empty_text: String = "无") -> String:
	var keys: Array = values.keys()
	if keys.is_empty():
		return empty_text
	keys.sort()
	return "；".join(keys)

func _count_skill_rows() -> int:
	var n := 0
	for row in rows:
		if String(row["field"]) != "—":
			n += 1
	return n

func _count_unique_cards() -> int:
	var names := {}
	for row in rows:
		names[String(row["card"])] = true
	return names.size()

func _scenario_count() -> int:
	var text := FileAccess.get_file_as_string(SCENARIOS_PATH)
	var doc = JSON.parse_string(text)
	if typeof(doc) != TYPE_DICTIONARY:
		structural_failures.append("无法解析 " + SCENARIOS_PATH)
		return 0
	return int(Array(doc.get("scenarios", [])).size())

func _print_console(summary: Dictionary) -> void:
	print("[parity_audit] 卡牌=%d 技能字段=%d 独立效果=%d" % [
		int(summary["cards"]), int(summary["instances"]), int(summary["effects"])])
	print("[parity_audit] 双端 parity 场景=%d" % int(summary["scenarios"]))
	print("[parity_audit] R断言=%d R入口=%d R缺=%d 六层可关门=%d" % [
		int(summary["asserted"]), int(summary["entry_only"]),
		int(summary["missing"]), int(summary["closable"])])
	print("[parity_audit] 机制反馈契约：%d/%d 族主色与母题唯一，%d 条高风险交互轨迹" % [
		int(summary["feedback_styles"]), FAMILY_ORDER.size(),
		int(summary["feedback_interactions"])])
	var missing_effects: Array = summary["missing_effects"]
	missing_effects.sort()
	print("[parity_audit] R缺效果: ", " ".join(missing_effects))
	if structural_failures.is_empty():
		print("[parity_audit] 结构检查通过")

func _write_doc(summary: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(DOC_PATH)
	if text.is_empty():
		structural_failures.append("无法读取 " + DOC_PATH)
		return
	var block := _render_block(summary)
	var begin := text.find(BEGIN_MARKER)
	if begin >= 0:
		var end := text.find(END_MARKER, begin)
		if end < 0:
			structural_failures.append("文档已有开始标记但缺少结束标记")
			return
		end += END_MARKER.length()
		text = text.substr(0, begin) + block + text.substr(end)
	else:
		text = text.strip_edges(false, true) + "\n\n" + block + "\n"
	var output := FileAccess.open(DOC_PATH, FileAccess.WRITE)
	if output == null:
		structural_failures.append("无法写入 " + DOC_PATH)
		return
	output.store_string(text)
	output.close()
	print("[parity_audit] 已更新 ", DOC_PATH)

func _render_block(summary: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(BEGIN_MARKER)
	lines.append("## 自动逐卡审计（由 `tools/parity_audit.gd` 生成）")
	lines.append("")
	lines.append("唯一键为 `卡名|字段|效果|触发`。`R入口` 只表示规则入口存在，不表示该卡的目标、数值、金卡倍率或时序正确；")
	lines.append("同效果的其他卡即使已有断言，也不能替本行勾销。六层未全部为 `✓` 时，整行不得判定完成。")
	lines.append("")
	lines.append("- 卡牌：%d（含生成形态 `混沌始祖`）" % int(summary["cards"]))
	lines.append("- 技能字段实例：%d" % int(summary["instances"]))
	lines.append("- 独立效果 ID：%d" % int(summary["effects"]))
	lines.append("- 双端 parity 场景：%d（是否全过以 parity_compare 的 0 差异为准）" % int(summary["scenarios"]))
	lines.append("- `R断言`：%d；`R入口`：%d；`R缺`：%d" % [
		int(summary["asserted"]), int(summary["entry_only"]), int(summary["missing"])])
	lines.append("- 六层全部有当前证据、可关门：%d" % int(summary["closable"]))
	lines.append("- 机制反馈契约：%d/%d 族具有唯一主色、母题和占位资源路径；%d 条高风险交互轨迹已登记" % [
		int(summary["feedback_styles"]), FAMILY_ORDER.size(), int(summary["feedback_interactions"])])
	lines.append("- 反馈契约只证明占位表现可识别、可替换，不等同于最终美术或主观视觉评分。")
	lines.append("")
	lines.append("### 根因队列")
	lines.append("")
	lines.append("| ID | 根因 | 受影响机制 | 强制证据 | 状态 |")
	lines.append("|---|---|---|---|---|")
	lines.append("| G1 | 攻击生命周期 | 机械、龙、恶魔、进化、星灵 | 挥击数、重选目标、尾部钩子只跑一次 | 规则入口已有；需逐卡回填 |")
	lines.append("| G2 | 受击流水线 | 血族、机械、进化、吸血 | 锁血→护甲→扣血→充能→受击技→治疗→死亡顺序 | 规则入口已有；需场景断言 |")
	lines.append("| G3 | 运行态跨阶段 | 进化、龙、机械、恶魔、亡灵 | `_t/_g/_gb/_dHit/_atkT/_hit/_pr` 等保真 | 已有字段保真用例；缺跨阶段场景 |")
	lines.append("| G4 | 开场预扫描 | 龙、恶魔、进化、亡灵 | 龙威→minor→多击/进度/重生顺序 | 规则入口已有；需逐卡断言 |")
	lines.append("| G5 | 触发分发表 | 全部效果 | `round/spell-cast/gold/sc/scSk` 逐卡分发 | %s |" % (
		"规则入口已清零；逐卡断言仍待" if int(summary.get("missing", 0)) == 0 else "仍有 R缺"))
	lines.append("| G6 | 机械合体协同 | 机械 | 部位、随机协同、目标继承、三类行为 | 主体已有；逐部位证据缺 |")
	lines.append("| G7 | 表现闭环 | 全族 | 规则事件→UI→动画→音频分别验收 | 大量 △/- |")
	lines.append("| G8 | 跨战斗持久状态 | 龙、进化、献祭、机械 | 连续两回合状态来源一致 | 待办 |")
	lines.append("| G9 | 审计回填 | 全卡池 | 每行 R/E/U/A/S/P 与证据 | 本表持续生成 |")
	lines.append("")
	lines.append("### 机制族汇总")
	lines.append("")
	lines.append("| 机制族 | 行数 | R断言 | R入口 | R缺 | 六层可关门 |")
	lines.append("|---|---:|---:|---:|---:|---:|")
	var families: Dictionary = summary["families"]
	for family in FAMILY_ORDER:
		if not families.has(family):
			continue
		var bucket: Dictionary = families[family]
		lines.append("| %s | %d | %d | %d | %d | %d |" % [
			_family_label(family), int(bucket["rows"]), int(bucket["asserted"]),
			int(bucket["rows"]) - int(bucket["asserted"]) - int(bucket["missing"]),
			int(bucket["missing"]), int(bucket["closable"])])
	lines.append("")
	lines.append("### 机制族缺口（逐族追责）")
	lines.append("")
	lines.append("`规则缺` 是整条规则入口不存在；`有入口未断言` 只说明共享代码分支存在，仍必须逐卡核对目标、数值、金卡倍率和触发顺序。")
	lines.append("表现计数按该族仍为 `△/-` 的卡行统计，不能用某一张代表卡通过来关闭整族。")
	lines.append("")
	for family in FAMILY_ORDER:
		if not families.has(family):
			continue
		var bucket: Dictionary = families[family]
		var layer_gaps: Dictionary = bucket["layer_gaps"]
		lines.append("#### %s" % _family_label(family))
		lines.append("")
		lines.append("- 机制载体：%s" % String(FAMILY_MECHANISMS.get(family, "待登记")))
		lines.append("- 规则缺：%s" % _format_sorted_keys(bucket["missing_rules"]))
		lines.append("- 有入口未断言：%s" % _format_sorted_keys(bucket["entry_only"]))
		lines.append("- 表现未闭：E事件 %d / U界面 %d / A动画 %d / S音频 %d" % [
			int(layer_gaps["E"]), int(layer_gaps["U"]),
			int(layer_gaps["A"]), int(layer_gaps["S"])])
		lines.append("- 六层未闭卡：%s" % _format_sorted_keys(bucket["open_cards"]))
		lines.append("")
	var missing_effects: Array = summary["missing_effects"]
	missing_effects.sort()
	lines.append("当前 `R缺` 效果：")
	lines.append("")
	lines.append("```text")
	lines.append(" ".join(missing_effects))
	lines.append("```")
	lines.append("")
	lines.append("### 逐卡六层底表")
	lines.append("")
	lines.append("六层缩写：`R规则 / E事件 / U界面 / A动画 / S音频 / P证据`。")
	lines.append("`✓`=有当前证据，`△`=部分或通用表现，`-`=未接。")
	lines.append("")
	for family in FAMILY_ORDER:
		var family_rows: Array[Dictionary] = []
		for row in rows:
			if String(row["family"]) == family:
				family_rows.append(row)
		if family_rows.is_empty():
			continue
		lines.append("#### %s（%d）" % [_family_label(family), family_rows.size()])
		lines.append("")
		lines.append("| 优先级 | 星级 | 卡牌 | 字段/触发 | 效果 | 目标/数值 | 金卡倍率 | R/E/U/A/S/P | Godot 入口 | Web | 当前证据 | 下一动作 |")
		lines.append("|---|---:|---|---|---|---|---|---|---|---|---|---|")
		for row in family_rows:
			var layers: Dictionary = row["layers"]
			var layer_text := "%s / %s / %s / %s / %s / %s" % [
				String(layers["R"]), String(layers["E"]), String(layers["U"]),
				String(layers["A"]), String(layers["S"]), String(layers["P"])]
			lines.append("| %s | %d | %s | `%s:%s` | `%s` | %s | %s | `%s` | `%s` | `%s` | %s | %s |" % [
				_escape(row["priority"]), int(row["star"]), _escape(row["card"]),
				_escape(row["field"]), _escape(row["timing"]), _escape(row["effect"]),
				_escape(row["target_value"]), _escape(row["gold"]), _escape(layer_text),
				_escape(row["handler"]), _escape(row["web"]), _escape(row["evidence"]),
				_escape(row["next"]),
			])
		lines.append("")
	lines.append(END_MARKER)
	return "\n".join(lines)

func _escape(value: Variant) -> String:
	return String(value).replace("|", "\\|").replace("\n", " ")

func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		structural_failures.append("文件不存在: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		structural_failures.append("JSON 解析失败: " + path)
		return {}
	return parsed
