// 方向 B 第一步：给 Web 加 ?headless=1 开关（dl 立即返回），并验证机械合体能否在无头下跑完 ft()
const fs = require('fs');
const FILE = 'C:/Users/李泽文/Documents/Codex/2026-07-26/xian/lushi-like/index.html';

let s = fs.readFileSync(FILE, 'utf8');
const before = s.length;
const hits = [];
if (!s.includes('window.HEADLESS=')) {
  const a = 'var AI_DIFF=2,S={},E={},PH="i"';
  if (s.includes(a)) {
    s = s.replace(a, 'window.HEADLESS=/[?&]headless=1/.test(location.search);' + a);
    hits.push('flag');
  } else hits.push('flag-miss');
}
for (const p of ['function dl(ms){', 'var dl=function(ms){', 'function dl(t){', 'async function dl(']) {
  if (s.includes(p)) {
    s = s.split(p).join(p + 'if(window.HEADLESS)return Promise.resolve();');
    hits.push('dl:' + p);
    break;
  }
}
if (hits.some((h) => h.startsWith('dl:')) || hits.includes('flag')) fs.writeFileSync(FILE, s);
console.log('patch:', hits.join(' | '), before, '->', s.length);

const PW = 'C:/Users/李泽文/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
const { chromium } = require(PW);
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';

(async () => {
  const browser = await chromium.launch({ executablePath: EDGE, args: ['--mute-audio'] });
  const page = await browser.newPage();
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));
  await page.goto('http://localhost:8080/#headless=1', { waitUntil: 'load' });
  await page.click('#btn-start');
  await page.waitForFunction(() => window.PH === 'p' && typeof window.ft === 'function', null, { timeout: 20000 });
  const out = await page.evaluate(async () => {
    window.evoReward = function () { };
    const mk = (o) => Object.assign({}, JSON.parse(JSON.stringify(o)), { t: 'm', id: ni(), mh: o.h });
    S.b = [mk({ n: '磁力底盘', a: 4, h: 10, s: 3, race: 'mech', part: 'core', k: 't' }),
      mk({ n: '核心学徒', a: 4, h: 5, s: 3, race: 'mech', part: 'head' }),
      mk({ n: '磁能臂', a: 8, h: 4, s: 3, race: 'mech', part: 'arm', k: 'w' }),
      mk({ n: '推进肢体', a: 3, h: 12, s: 3, race: 'mech', part: 'leg', k: 't' }), null, null, null];
    E.b = [mk({ n: '精英靶', a: 6, h: 140, s: 3, race: 'elem' }), null, null, null, null, null, null];
    S.hp = 100; E.hp = 100; S.t = 1; S._phase = 2; E._phase = 2; S.mechLevel = 2; S.mechRepair = 0;
    R();
    const t0 = performance.now();
    let status = 'ok';
    try {
      await Promise.race([ft(), new Promise((r) => setTimeout(() => r('timeout'), 15000))]).then((v) => { if (v === 'timeout') status = 'timeout'; });
    } catch (e) { status = 'error:' + String(e && e.message || e); }
    return {
      status,
      ms: Math.round(performance.now() - t0),
      phase: window.PH,
      board: S.b.filter(Boolean).map((m) => m.n + ':' + m.a + '/' + m.h),
      armor: S._battleArmor || 0,
      hp: { p: S.hp, e: E.hp },
      log: document.getElementById('log').innerText.split('\n').slice(-24),
    };
  });
  console.log('probe:', JSON.stringify(out));
  if (errs.length) console.log('异常:', errs.join('\n'));
  await browser.close();
})().catch((e) => { console.error('FATAL', e); process.exit(1); });
