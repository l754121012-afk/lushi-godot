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
  const fmt = (arr) => arr.map((u) => `${u.n} a${u.a}/m${u.mh}`).join(' | ');
  // Web 侧战后会把阵亡单位从棋盘移除，Godot 侧保留 alive=false —— 只比较存活单位
  const wP = w.p, wE = w.e;
  const gP = g.p.filter((u) => u.alive !== false), gE = g.e.filter((u) => u.alive !== false);
  const pa = wP.map((u) => u.a).join(','), pb = gP.map((u) => u.a).join(',');
  const ea = wE.map((u) => u.a).join(','), eb = gE.map((u) => u.a).join(',');
  if (pa !== pb) diffs.push(`我方攻击 ${pa}→${pb}`);
  // 敌方：Web 战后清场时机与 Godot 不同（一方可能已把阵亡单位移出棋盘），只在两边都还有存活单位时比对数值
  if (wE.length > 0 && gE.length > 0 && ea !== eb) diffs.push(`敌方攻击 ${ea}→${eb}`);
  const pm = wP.map((u) => u.mh).join(','), pmb = gP.map((u) => u.mh).join(',');
  if (pm !== pmb) diffs.push(`我方最大生命 ${pm}→${pmb}`);
  const em = wE.map((u) => u.mh).join(','), emb = gE.map((u) => u.mh).join(',');
  if (wE.length > 0 && gE.length > 0 && em !== emb) diffs.push(`敌方最大生命 ${em}→${emb}`);

  const ok = diffs.length === 0;
  if (!ok) diffCount++;
  console.log(
    (id + (ok ? ' ✅' : ' ⚠️')).padEnd(22) +
    (w.winner + '/' + g.winner).padEnd(7) +
    ((w.damage_to_e || 0) + '/' + (g.damage_to_e || 0)).padEnd(7) +
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
