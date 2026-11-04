// Port tool: checks the overworld's solid things and the echo's feedback in the real Tilewright editor (M-01, M-02, M-03).
// The Storytender is put next to each thing (a test shortcut), then walks into it with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/mech_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
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
const msgs = () => page.evaluate(() => [...window.__msgs]);
const placeAt = (x, y) =>
  page.evaluate(([x, y]) => {
    const s = window.__play.sim;
    const p = s.world.withTag('player')[0];
    const t = p.get('transform');
    t.x = x;
    t.y = y;
    t.h = s.map.getHeight(Math.floor(x), Math.floor(y));
    const b = p.get('body');
    if (b) { b.vx = 0; b.vy = 0; b.vz = 0; }
  }, [x, y]);
const where = () => page.evaluate(() => { const t = window.__play.sim.world.withTag('player')[0].get('transform'); return { x: t.x, y: t.y }; });
const count = (cls, x, y) => page.evaluate(([cls, x, y]) => window.__play.sim.world.all().filter((e) => e.name.startsWith(cls) && Math.abs(e.get('transform').x - x) < 0.2 && Math.abs(e.get('transform').y - y) < 0.2).length, [cls, x, y]);
// the view is isometric: W walks toward -x -y (up the screen), D toward +x -y, so W and D together are straight along -y (north on the grid)
const NORTH = ['KeyW', 'KeyD'];
const hold = async (key, ms) => {
  const keys = Array.isArray(key) ? key : [key];
  for (const k of keys) await page.keyboard.down(k);
  await page.waitForTimeout(ms);
  for (const k of keys.reverse()) await page.keyboard.up(k);
  await page.waitForTimeout(250);
};
const shotAs = (name) => page.screenshot({ path: path.join(outDir, name) });

/** Walk north (W and D together) into something that stands at (x, y) with `gap` cells to spare; it blocks when she stays south of it. */
async function blockedFrom(cls, x, y, startY, limitY, label) {
  await placeAt(x, startY);
  await page.waitForTimeout(500);
  await hold(NORTH, 1400);
  const p = await where();
  check(`${label} blocks the way`, p.y > limitY, `${cls} at ${x},${y}; she stopped at y ${p.y.toFixed(2)} (limit ${limitY})`);
}

try {
  const info = await page.evaluate(() => {
    const sim = window.__play.sim;
    const tree = sim.world.withTag('prop-0').find((e) => e.get('collider') && Math.abs(e.get('transform').x - 40) < 25 && Math.abs(e.get('transform').y - 60) < 25);
    return { tree: tree && { t: tree.get('transform') } };
  });
  // control: a tree (it had a collider before) must block
  if (info.tree) await blockedFrom('Prop tree', info.tree.t.x, info.tree.t.y, info.tree.t.y + 1.7, info.tree.t.y + 0.5, 'a tree (control)');
  // M-03: things that must block (each one is walked into from the south)
  await blockedFrom('StoryGate', 45.5, 37.5, 39.4, 37.9, 'a story gate');
  await blockedFrom('SentenceStone', 58.5, 56.5, 58.2, 56.9, 'a sentence stone');
  await blockedFrom('Prop sign', 42.5, 37.5, 39.4, 37.9, 'a sign beside a puzzle site');

  // M-02: a censor bar blocks, the lantern lifts it, and then she can pass (bar at 31.5,40.5, 3 wide)
  await blockedFrom('Redactor', 31.5, 40.5, 42.2, 40.85, 'a censor bar');
  await shotAs('bar_blocked.png');
  await page.evaluate(() => { window.__play.sim.runtime.vars.has_lantern = 1; });
  await placeAt(31.5, 43.4);
  await page.waitForTimeout(300);
  await hold(NORTH, 350); // walk up to the bar, which turns her to face it
  await page.keyboard.down('KeyQ');
  await page.waitForTimeout(2600);
  await page.keyboard.up('KeyQ');
  await page.waitForTimeout(600);
  const left = await count('Redactor', 31.5, 40.5);
  check('the lantern lifts a censor bar', left === 0, `${left} bars left at that spot`);
  const said = (await msgs()).filter((m) => /written there all along/.test(m)).length;
  check('lifting a bar says so', said === 1, `${said} messages`);
  await placeAt(31.5, 41.9);
  await hold(NORTH, 1400);
  const through = await where();
  check('she walks through the lifted bar', through.y < 40.2, `y ${through.y.toFixed(2)}`);

  // M-01: echo feedback: before the forge memory is done, R says she cannot make echoes yet
  await placeAt(18.5, 54.5);
  await page.waitForTimeout(400);
  await hold('KeyR', 150);
  const m1 = await msgs();
  await shotAs('echo_not_yet.png');
  check('R before the forge says she cannot make echoes yet', m1.some((m) => /cannot make echoes yet/i.test(m)), m1.slice(-3).join(' | '));
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
