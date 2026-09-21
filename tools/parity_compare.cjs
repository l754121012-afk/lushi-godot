// 对比 Web 版与 Godot 版的战斗结果（tests/out/web.json vs godot.json）
// 对比项：胜负 / 败方掉血 / 每张卡的最终攻击力 / 最大生命
const fs = require('fs');
const path = require('path');
const PROJ = 'C:/Users/李泽文/Documents/Codex/2026-07-26/xian/lushi-godot';

function load(name) {
  const p = path.join(PROJ, 'tests/out', name);
  if (!fs.existsSync(p)) {
    console.error('缺少结果文件:', p);
    process.exit(2);
  }
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

const web = load('web.json');
const godot = load('godot.json');
const wById = Object.fromEntries(web.results.map((r) => [r.id, r]));
const gById = Object.fromEntries(godot.results.map((r) => [r.id, r]));
const ids = web.results.map((r) => r.id);

let diffCount = 0;
console.log('场景'.padEnd(22) + '胜负  掉血   数值（Web → Godot）');
console.log('-'.repeat(92));
for (const id of ids) {
  const w = wById[id], g = gById[id];
  if (!w || !g) { console.log(id + ' 缺少一边结果'); diffCount++; continue; }
  const diffs = [];
  if (w.winner !== g.winner) diffs.push(`winner ${w.winner}→${g.winner}`);
  if ((w.damage_to_e || 0) !== (g.damage_to_e || 0)) diffs.push(`dmgE ${w.damage_to_e}→${g.damage_to_e}`);
  if ((w.damage_to_p || 0) !== (g.damage_to_p || 0)) diffs.push(`dmgP ${w.damage_to_p}→${g.damage_to_p}`);
  if ((w.debt_p || 0) !== (g.debt_p || 0)) diffs.push(`债务P ${w.debt_p}→${g.debt_p}`);
  if ((w.debt_e || 0) !== (g.debt_e || 0)) diffs.push(`债务E ${w.debt_e}→${g.debt_e}`);
  const fmt = (arr) => arr.map((u) => `${u.n} a${u.a}/m${u.mh}`).join(' | ');
  // Web 侧战时/战后棋盘清理时机与 Godot 不同（阵亡、AI 换牌都会导致列表不一致）
  // 因此按"同名单位取交集"比较最终攻击与最大生命，只校验两边都还存在的单位
  const wP = w.p, wE = w.e;
  const gP = g.p.filter((u) => u.alive !== false), gE = g.e.filter((u) => u.alive !== false);
  const byName = (arr) => Object.fromEntries(arr.map((u) => [u.n, u]));
  const wPm = byName(wP), gPm = byName(gP), wEm = byName(wE), gEm = byName(gE);
  for (const n of Object.keys(wPm).filter((k) => gPm[k])) {
    if (wPm[n].a !== gPm[n].a) diffs.push(`我方 ${n} 攻击 ${wPm[n].a}→${gPm[n].a}`);
    if (wPm[n].mh !== gPm[n].mh) diffs.push(`我方 ${n} 最大生命 ${wPm[n].mh}→${gPm[n].mh}`);
  }
  for (const n of Object.keys(wEm).filter((k) => gEm[k])) {
    if (wEm[n].a !== gEm[n].a) diffs.push(`敌方 ${n} 攻击 ${wEm[n].a}→${gEm[n].a}`);
    if (wEm[n].mh !== gEm[n].mh) diffs.push(`敌方 ${n} 最大生命 ${wEm[n].mh}→${gEm[n].mh}`);
  }

  const ok = diffs.length === 0;
  if (!ok) diffCount++;
  console.log(
    (id + (ok ? ' ✅' : ' ⚠️')).padEnd(22) +
    (w.winner + '/' + g.winner).padEnd(7) +
    ((w.damage_to_e || 0) + '/' + (g.damage_to_e || 0)).padEnd(7) +
    ('债' + (w.debt_p || 0) + '/' + (g.debt_p || 0)).padEnd(10) +
    (ok ? '' : diffs.join(' ; '))
  );
  if (!ok) {
    console.log('   web   P: ' + fmt(wP) + '   E: ' + fmt(wE));
    console.log('   godot P: ' + fmt(gP) + '   E: ' + fmt(gE));
  }
}
console.log('-'.repeat(92));
console.log(`共 ${ids.length} 个场景，差异 ${diffCount} 个`);
process.exit(diffCount === 0 ? 0 : 1);
