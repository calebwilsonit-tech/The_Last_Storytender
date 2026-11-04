// Port tool: screenshots of the HUD (ink bottle, lantern, Mnemosynth, renown, region name, quick slots, boss bar) in the real editor.
//   TILEWRIGHT=<engine checkout> node tools/port/items_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
// The Storytender is put next to what she needs (a test shortcut); the item is then used with the key F.
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
await page.evaluate(() => {
  window.__msgs = [];
  window.__play.sim.events.on('message', (e) => window.__msgs.push(String(e.text ?? '')));
});

const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ' - ' + detail : ''}`);
};
const vars = () => page.evaluate(() => ({ ...window.__play.sim.runtime.vars }));
const setV = (o) => page.evaluate((o) => Object.assign(window.__play.sim.runtime.vars, o), o);
const msgs = () => page.evaluate(() => [...window.__msgs]);
const placeAt = (x, y) =>
  page.evaluate(([x, y]) => {
    const s = window.__play.sim;
    const p = s.world.withTag('player')[0];
    const t = p.get('transform');
    t.x = x; t.y = y; t.h = s.map.getHeight(Math.floor(x), Math.floor(y));
    const b = p.get('body');
    if (b) { b.vx = 0; b.vy = 0; b.vz = 0; }
  }, [x, y]);
const faceDir = (f) => page.evaluate((f) => { window.__play.sim.world.withTag('player')[0].get('transform').facing = f; }, f);
const hp = () => page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('state:health').hp);
const setHp = (n) => page.evaluate((n) => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); h.hp = n; h.dead = false; }, n);
const tagged = (tag) => page.evaluate((tag) => window.__play.sim.world.withTag(tag).map((e) => ({ id: e.id, name: e.name, ...e.get('transform'), hp: e.get('state:health')?.hp, visible: e.get('sprite')?.visible !== false })), tag);
const press = async (key, ms = 90) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(160); };
/** Put an item in quick slot 1 (with `n` of it) and press F; returns the messages it caused. */
async function useIt(id, n = 1) {
  await setV({ [`item:${id}`]: n, 'slot:1': id, quick_active: 0 });
  const before = (await msgs()).length;
  await press('KeyF');
  await page.waitForTimeout(500);
  return { count: Number((await vars())[`item:${id}`] ?? 0), said: (await msgs()).slice(before) };
}
const shotAs = (name) => page.screenshot({ path: path.join(outDir, name) });

try {
  await page.waitForTimeout(1500);
  await placeAt(60.5, 60.5);
  await page.waitForTimeout(600);
  await page.screenshot({ path: path.join(outDir, 'hud_start.png'), clip: await page.evaluate(() => { const r = document.querySelector('[data-testid=viewport]')?.getBoundingClientRect(); return r ? { x: r.x, y: r.y, width: r.width, height: r.height } : undefined; }) });
  await setV({ mnemosynth: 125, renown: 63, light: 70, 'item:ink_vial': 3, 'item:warm_loaf': 2, 'slot:1': 'ink_vial', 'slot:2': 'warm_loaf', quick_active: 0, region_name: "The Blacksmith's Reckoning", region_show: 1 });
  await page.waitForTimeout(800);
  const box = await page.evaluate(() => { const r = document.querySelector('[data-testid=viewport]')?.getBoundingClientRect(); return r ? { x: r.x, y: r.y, width: r.width, height: r.height } : null; });
  const clip = box ?? undefined;
  await page.screenshot({ path: path.join(outDir, 'hud_full.png'), clip });
  await setHp(55);
  await setV({ boss_name: 'The Critic', boss_hp: 70, boss_max: 110 });
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(outDir, 'hud_boss.png'), clip });
  await setHp(20); await setV({ light: 10, quick_active: 1 });
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(outDir, 'hud_low.png'), clip });
  check('screenshots taken', true, JSON.stringify(box));
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();

