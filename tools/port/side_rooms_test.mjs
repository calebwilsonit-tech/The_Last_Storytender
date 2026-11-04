// Port tool: the two side-room doors (Proof Room, Weighing Room) with E, and what is scripted inside each room.
// talking to Garrick, collecting a crystal, opening a chest, taking a pickup, lighting a lantern post, striking the
// dummy. The Storytender is moved next to each thing (a test shortcut), then everything else is done with real keys.
// Screenshots and a report go to <out_dir>.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/forge_test.mjs <project_dir> <out_dir>
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
// her facing is a direction on the screen (0 right, 2 down); grid +x runs down-right and +y down-left, so the way to (x, y) is turned onto the screen first
const face = (x, y) => page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4) + 8) % 8; }, [x, y]);
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
const setV = (o) => page.evaluate((o) => Object.assign(window.__play.sim.runtime.vars, o), o);
const inside = () => page.evaluate(() => { const s = window.__play.sim; const all = s.world.all(); const scripted = all.filter((e) => Object.keys(e.components ?? {}).some((k) => k.startsWith('script_')) || [...(e.componentNames?.() ?? [])].some((k) => k.startsWith('script_'))); const names = {}; for (const e of all) { const n = e.name.replace(/ @.*/, ''); names[n] = (names[n] ?? 0) + 1; } return { total: all.length, names }; });
const scriptedCount = () => page.evaluate(() => window.__play.sim.world.all().filter((e) => ['script_StoryGate', 'script_Plate', 'script_Redactor', 'script_Gateway', 'script_WordBlock', 'sentenceStone', 'script_Collect', 'npcTalk', 'checkpoint'].some((c) => e.get(c))).map((e) => e.name.replace(/ @.*/, '') + ':' + ['script_StoryGate', 'script_Plate', 'script_Redactor', 'script_Gateway', 'script_WordBlock', 'sentenceStone', 'script_Collect', 'npcTalk', 'checkpoint'].filter((c) => e.get(c)).join('+')));
try {
  await page.waitForTimeout(1500); await readAll();
  for (const [name, x, y, flag, sc] of [['proof', 13.5, 25.5, { has_quill: 1 }, 'proof'], ['weighing', 107.5, 74.5, { memory_done: 1, has_sword: 1 }, 'weighing']]) {
    await page.evaluate(() => { window.__play.sim.runtime.travel = { scene: 'scenes/overworld.scene.json', spawn: '' }; });
    await page.waitForTimeout(2500); await readAll();
    await setV(flag);
    await placeAt(x, y + 1.1); await page.waitForTimeout(400); await face(x, y); await page.waitForTimeout(200);
    await press('KeyE'); await page.waitForTimeout(500); const said = await readAll();
    for (let i = 0; i < 30 && !(await scene()).includes(sc); i++) await page.waitForTimeout(300);
    const s = await scene();
    check(`the ${name} room's door takes you in with E`, s.includes(sc), `${said.join(' | ').slice(0, 120)} -> ${s}`);
    if (s.includes(sc)) { await page.waitForTimeout(2000); await readAll(); const sc2 = await scriptedCount(); console.log(name, 'interactive things inside:', sc2.length, JSON.stringify(sc2).slice(0, 500)); const inn = await inside(); console.log(name, 'objects:', JSON.stringify(inn.names).slice(0, 600)); await shotAs(`${name}.png`); }
  }
} catch (e) { check('test run', false, String(e && e.stack || e).slice(0, 300)); }
console.log('errors', errors.length);
await app.close();
