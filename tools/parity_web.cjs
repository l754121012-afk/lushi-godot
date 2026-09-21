// 一致性对照（Web 侧）：用 tests/scenarios.json 在同一套场景下跑 Web 版战斗，输出 tests/out/web.json
// 关键手法：dl 置空（跳过动画）、Math.random 播种（可复现）、相位设 2（关闭昼夜额外加格）、evoReward 置空（隔离宣言奖励）
const fs = require('fs');
const path = require('path');
const PW = 'C:/Users/李泽文/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
const { chromium } = require(PW);
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const PROJ = 'C:/Users/李泽文/Documents/Codex/2026-07-26/xian/lushi-godot';

(async () => {
  const doc = JSON.parse(fs.readFileSync(path.join(PROJ, 'tests/scenarios.json'), 'utf8'));
  const browser = await chromium.launch({ executablePath: EDGE, args: ['--mute-audio'] });
  const page = await browser.newPage();
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  await page.goto('http://localhost:8080/', { waitUntil: 'load' });
  await page.click('#btn-start');
  await page.waitForFunction(() => typeof window.ft === 'function' && window.PH === 'p', null, { timeout: 20000 });
  await page.evaluate(() => {
    window.__ac = setInterval(() => {
      const ov = Array.from(document.querySelectorAll('div')).find((d) => d.style && d.style.zIndex === '98' && d.querySelector('button'));
      if (ov) ov.querySelector('button').click();
    }, 150);
    window.__origDl = window.dl;
    window.__origReward = window.evoReward;
  });

  const results = [];
  for (const sc of doc.scenarios) {
    const r = await page.evaluate(async (sc) => {
      window.dl = async function () { return; };
      window.evoReward = function () { };
      let seed = sc.seed || 1;
      const origRandom = Math.random;
      Math.random = function () { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };

      const build = (list) => {
        const board = new Array(7).fill(null);
        const ids = [];
        list.forEach((c, i) => {
          const m = JSON.parse(JSON.stringify(c));
          m.t = 'm'; m.id = ni(); m.mh = m.h; m._side = undefined;
          board[i] = m;
          ids.push(m.id);
        });
        return { board, ids };
      };
      // 注意：变量名不要用 E / S，否则会遮蔽页面里的全局 AI/玩家状态
      const pSide = build(sc.p), eSide = build(sc.e);
      S.b = pSide.board;
      E.b = eSide.board;
      S.hp = 100; E.hp = 100; S.t = 1;
      // 献祭·债务：场景可以指定契印目标（1 基序号）与初始债务
      S.t = Number(sc.round || 1);
      S._contractId = sc.contractP ? pSide.ids[Number(sc.contractP) - 1] : null;
      E._contractId = sc.contractE ? eSide.ids[Number(sc.contractE) - 1] : null;
      S._debt = Number(sc.debtP || 0);
      E._debt = Number(sc.debtE || 0);
      S._debtTier = debtTier(S._debt);
      E._debtTier = debtTier(E._debt);
      S._debtSettled = false;
      E._debtSettled = false;
      // 星灵连锁：可指定初始连锁层数与星界增幅
      S.chain = Number(sc.chainP || 0);
      E.chain = Number(sc.chainE || 0);
      S.starAmp = Number(sc.ampP || 0);
      E.starAmp = Number(sc.ampE || 0);
      S._battleArmor = Number(sc.armorP || 0);
      E._battleArmor = Number(sc.armorE || 0);
      // 机械：合体等级 / 维修护甲 / 磁力次数（Web 的 ft() 会在开打前自动做合体）
      S.mechLevel = Number(sc.mechLevel || 0);
      S.mechRepair = Number(sc.mechRepair || 0);
      S._magT = Number(sc.magT || 0);
      E.mechLevel = 0; E.mechRepair = 0; E._magT = 0;
      S._phase = 2; E._phase = 2;            // 关闭昼夜加格，先对齐"卡自身机制"
      S._quest = null; E._quest = null;
      R();
      const before = { S: S.hp, E: E.hp };
      const eRef = E, sRef = S;

      try { await ft(); } catch (e) { Math.random = origRandom; return { id: sc.id, error: String(e && e.message || e) }; }
      const hpRightAfterFt = { p: S.hp, e: E.hp };
      const refCheck = { sameE: eRef === E, sameS: sRef === S, eRefHp: eRef.hp, sRefHp: sRef.hp };
      PH = 'p';   // ft() 结尾会进入 AI 回合，这里手动收尾，便于下一场接着跑

      const pick = (ids) => ids.map((id) => {
        const m = S.b.find((x) => x && x.id === id) || E.b.find((x) => x && x.id === id);
        return m ? {
          n: m.n, a: m.a, mh: m.mh, h: m.h,
          evo: m._evo || 0, vd: m._vd || 0, vc: m._vc || 0, gene: m._gene || 0, pr: m._pr || 0,
        } : null;
      }).filter(Boolean);

      const winner = E.hp < before.E ? 'p' : (S.hp < before.S ? 'e' : 'draw');
      const res = {
        id: sc.id,
        name: sc.name,
        winner,
        damage_to_p: before.S - S.hp,
        damage_to_e: before.E - E.hp,
        debt_p: S._debt || 0,
        debt_e: E._debt || 0,
        chain_p: S.chain || 0,
        chain_e: E.chain || 0,
        armor_p: S._battleArmor || 0,
        armor_e: E._battleArmor || 0,
        hp_after: { p: S.hp, e: E.hp },
        hp_right_after_ft: hpRightAfterFt,
        ref_check: refCheck,
        before,
        log: document.getElementById('log').innerText.split('\n').slice(-40),
        p: pick(pSide.ids),
        e: pick(eSide.ids),
      };
      Math.random = origRandom;
      return res;
    }, sc);
    results.push(r);
    console.log('web', r.id, 'winner=' + r.winner,
      'ft后hp=' + JSON.stringify(r.hp_right_after_ft), '读时hp=' + JSON.stringify(r.hp_after), 'dmgE=' + r.damage_to_e,
      'P=' + JSON.stringify(r.p), 'E=' + JSON.stringify(r.e));
    if (r.log) console.log('    log:', JSON.stringify(r.log));
  }
  await browser.close();
  if (errs.length) console.error('页面异常:', errs.join('\n'));

  const outDir = path.join(PROJ, 'tests/out');
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, 'web.json'), JSON.stringify({ source: 'web', version: 1, results }, null, 1), 'utf8');
  console.log('已写出 tests/out/web.json');
})().catch((e) => { console.error('FATAL', e); process.exit(1); });
