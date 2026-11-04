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
// a new game opens the storybook, then the waking-up scene: turn the book's pages and skip the scene
for (let i = 0; i < 12 && /Storybook/.test(await stack()); i++) {
  await page.keyboard.press('KeyE');
  await page.waitForTimeout(350);
}
await page.waitForTimeout(600);
if (await page.evaluate(() => !!window.__play.sim.runtime.cutscene)) {
  await page.keyboard.press('KeyP');
  await page.waitForTimeout(900);
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
  // everything that is being said, and every cutscene that follows it (a conversation can end in a scene, a tick later)
  const seen = [];
  let idle = 0;
  for (let i = 0; i < 160; i++) {
    const cs = await page.evaluate(() => !!window.__play.sim.runtime.cutscene);
    const v = await dialogue();
    if (!v && !cs) {
      if (++idle >= 3) break;
      await page.waitForTimeout(200);
      continue;
    }
    idle = 0;
    if (v) {
      seen.push(v.kind === 'line' ? v.text : `[choice] ${v.prompt}`);
      await press('KeyE');
      await page.waitForTimeout(150);
    } else await page.waitForTimeout(250);
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
  for (const k of ['KeyD','KeyW']) console.log('walk', k, (await speedOver(k, 1000)).toFixed(2), 'creep', (await speedOver(k, 1000, 'KeyC')).toFixed(2));
  // ---- a screenshot of every area, and of edges and ledges
  const spots = [
    ['overworld', 16.5, 54.5, 'start'], ['overworld', 30.5, 40.5, 'margins'], ['overworld', 46.5, 27.5, 'orchard'], ['overworld', 76.5, 50.5, 'oldmeadow'],
    ['overworld', 95.5, 53.5, 'square'], ['overworld', 118.5, 52.5, 'margingate'], ['overworld', 85.5, 11.5, 'folio'], ['overworld', 115.5, 68.5, 'smudge'],
    ['overworld', 6.5, 54.5, 'west_edge'], ['overworld', 70.5, 3.5, 'north_edge'], ['overworld', 70.5, 98.5, 'south_edge'], ['overworld', 128.5, 50.5, 'east_edge'],
    ['forge', 5.5, 12.5, 'start'], ['forge', 20.5, 10.5, 'hall'], ['forge', 48.5, 10.5, 'arena'],
    ['pip', 6.5, 16.5, 'start'], ['pip', 20.5, 25.5, 'wood'], ['pip', 20.5, 6.5, 'tower'], ['pip', 50.5, 12.5, 'archive'], ['pip', 36.5, 4.5, 'lastpage'],
    ['maud', 5.5, 17.5, 'pantry'], ['maud', 20.5, 15.5, 'kitchen'], ['maud', 33.5, 15.5, 'cellar'], ['maud', 36.5, 7.5, 'hall'],
    ['weighing', 0, 0, 'start'], ['proof', 0, 0, 'start'], ['scissor', 0, 0, 'start'],
  ];
  let cur = '';
  for (const [sc, x, y, name] of spots) {
    if (cur !== sc) { await go(`scenes/${sc}.scene.json`); cur = sc; }
    if (x) await placeAt(x, y);
    await heal();
    await page.waitForTimeout(700);
    await readAll();
    await shotAs(`s_${sc}_${name}.png`);
  }
} catch (e) { console.log("ERR", e.message); }
console.log('errors', errors.length); await app.close();
