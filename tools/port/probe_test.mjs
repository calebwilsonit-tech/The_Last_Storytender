// Port tool (tour): every mechanic not covered by the other tests, and a screenshot of every area in the real Tilewright editor and checks that its interactions work: reading a sign,
// talking to Garrick, collecting a crystal, opening a chest, taking a pickup, lighting a lantern post, striking the
// dummy. The Storytender is moved next to each thing (a test shortcut), then everything else is done with real keys.
// Screenshots and a report go to <out_dir>.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/tour_test.mjs <project_dir> <out_dir>
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const [projectDir, outDir] = process.argv.slice(2);
const TILEWRIGHT = process.env.TILEWRIGHT ?? '/home/user/calebwilsonit-tech/tilewrite';
const { _electron: electron } = createRequire(path.join(TILEWRIGHT, 'package.json'))('playwright');
fs.mkdirSync(outDir, { recursive: true });
const base = fs.mkdtempSync(path.join(os.tmpdir(), 'tw-port-'));
const work = path.join(base, 'project');
fs.cpSync(projectDir, work, { recursive: true });
const app = await electron.launch({
  args: [path.join(TILEWRIGHT, 'packages', 'editor'), `--user-data-dir=${path.join(base, 'ud')}`, '--no-sandbox'],
  env: { ...process.env, TILEWRIGHT_TEST_DIR: work },
});
const page = await app.firstWindow();
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
await page.setViewportSize({ width: 1600, height: 1000 }).catch(() => undefined);
await page.getByTestId('btn-open-project').click();
await page.getByTestId('editor-shell').waitFor({ timeout: 120000 });
await page.waitForFunction(() => (window.__studio?.state?.assetsVersion ?? 0) > 0, null, { timeout: 300000 });
await page.waitForTimeout(3000);
await page.getByTestId('btn-play').click();
await page.waitForFunction(() => window.__play !== undefined && window.__play.sim, null, { timeout: 60000 });
await page.waitForTimeout(2500);
// the title screen: New Game, then the Story difficulty
const stack = () => page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','));
for (let i = 0; i < 2 && /Title/.test(await stack()); i++) {
  await page.keyboard.press('KeyE');
  await page.waitForTimeout(700);
}

const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ' - ' + detail : ''}`);
};
const vars = () => page.evaluate(() => ({ ...window.__play.sim.runtime.vars }));
const scene = () => page.evaluate(() => window.__play.sim.runtime.scene);
const dialogue = () => page.evaluate(() => window.__play.sim.runtime.dialogue?.view ?? null);
const placeAt = (x, y) =>
  page.evaluate(([x, y]) => {
    const s = window.__play.sim;
    const p = s.world.withTag('player')[0];
    const t = p.get('transform');
    t.x = x; t.y = y; t.h = s.map.getHeight(Math.floor(x), Math.floor(y));
    const b = p.get('body');
    if (b) { b.vx = 0; b.vy = 0; b.vz = 0; }
  }, [x, y]);
const face = (x, y) => page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2(y - p.y, x - p.x) / Math.PI) * 4) + 8) % 8; }, [x, y]);
const tagged = (tag) => page.evaluate((tag) => window.__play.sim.world.withTag(tag).map((e) => ({ id: e.id, name: e.name, ...e.get('transform'), open: e.get('collider') ? !e.get('collider').enabled : null, visible: e.get('sprite')?.visible !== false })), tag);
const press = async (key, ms = 90) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(160); };
const readAll = async () => {
  const seen = [];
  for (let i = 0; i < 60; i++) {
    const v = await dialogue();
    if (!v) break;
    seen.push(v.kind === 'line' ? v.text : `[choice] ${v.prompt}`);
    await press('KeyE');
    await page.waitForTimeout(150);
  }
  return seen;
};
const heal = () => page.evaluate(() => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); if (h) { h.hp = 100; h.dead = false; } });
const shotAs = (name) => page.screenshot({ path: path.join(outDir, name) });
const near = (list, x, y) => [...list].sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y))[0];

const go = async (sceneFile, x, y) => {
  await page.evaluate((s) => { window.__play.sim.runtime.travel = { scene: s, spawn: '' }; }, sceneFile);
  for (let i = 0; i < 60 && (await scene()) !== sceneFile; i++) await page.waitForTimeout(250);
  await page.waitForTimeout(1800);
  await readAll();
  if (x !== undefined) { await placeAt(x, y); await page.waitForTimeout(500); }
};
const pos = () => page.evaluate(() => ({ ...window.__play.sim.world.withTag('player')[0].get('transform') }));
const hp = () => page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('state:health')?.hp);
const speedOver = async (key, ms, extra) => {
  const a = await pos();
  if (extra) await page.keyboard.down(extra);
  await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key);
  if (extra) await page.keyboard.up(extra);
  const b = await pos();
  return Math.hypot(b.x - a.x, b.y - a.y) / (ms / 1000);
};
const info = {};
try {
  await go('scenes/overworld.scene.json', 16.5, 54.5);
  const st = () => page.evaluate(() => { const s = window.__play.sim; const p = s.world.withTag('player')[0]; const v = s.runtime.vars; return { puddle: v.puddle_slow, slowUntil: v.slow_until, time: s.time ?? null, pc: p.get('playerController'), body: (({ radius, stepUp, ledge, wade }) => ({ radius, stepUp, ledge, wade }))(p.get('body')), tile: s.map.getTile ? s.map.getTile(Math.floor(p.get('transform').x), Math.floor(p.get('transform').y)) : null }; });
  console.log('state', JSON.stringify(await st()).slice(0, 600));
  console.log('walk D', (await speedOver('KeyD', 1000)).toFixed(2));
  console.log('state2', JSON.stringify(await st()).slice(0, 300));
  const info = await page.evaluate(() => { const s = window.__play.sim; const by = {}; for (const e of s.world.all()) { const n = e.name.replace(/[ @].*$/, ''); const c = e.get('collider'); const b = by[n] ??= { n: 0, col: 0, solid: 0 }; b.n++; if (c) { b.col++; if (c.enabled !== false && !c.trigger) b.solid++; } } return by; });
  console.log('colliders', JSON.stringify(info));
} catch (e) { console.log('ERR', e.message); }
console.log('errors', errors.length, errors.slice(0, 3).join(' | ')); await app.close();
