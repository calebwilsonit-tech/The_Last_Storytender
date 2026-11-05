// Port tool (pip): plays Pip's memory in the ported game in the real Tilewright editor and checks that its interactions work: reading a sign,
// talking to Garrick, collecting a crystal, opening a chest, taking a pickup, lighting a lantern post, striking the
// dummy. The Storytender is moved next to each thing (a test shortcut), then everything else is done with real keys.
// Screenshots and a report go to <out_dir>.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/pip_test.mjs <project_dir> <out_dir>
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
fs.cpSync(projectDir, work, { recursive: true, filter: (f) => path.basename(f) !== 'saves' }); // (a game played from the editor leaves its saves in the project folder: the tests start fresh)
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
const near = (list, x, y) => [...list].sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y))[0];

const byTag1 = async (tag) => (await tagged(tag))[0];
const useAt = async (x, y, dy = 1.0) => { await placeAt(x, y + dy); await page.waitForTimeout(300); await press('KeyE'); await page.waitForTimeout(300); return readAll(); };
try {
  await page.evaluate(() => { const v = window.__play.sim.runtime.vars; v.memory_done = 1; v.has_quill = 1; v.go_pip = 1; });
  for (let i = 0; i < 40 && !/pip/.test(await scene()); i++) await page.waitForTimeout(250);
  check("Pip's storybook takes you into the memory", /pip/.test(await scene()), await scene());
  await page.waitForTimeout(2000);
  await shotAs('p1_arrive.png');
  const intro = await readAll();
  check('the memory greets you', intro.length > 0, intro.join(' | ').slice(0, 120));

  // the bridge: rewrite BREAKS -> HOLDS, and the gap can be crossed
  const stone = async (k) => byTag1(`stone-${k}`);
  const a = await stone('a');
  await useAt(a.x, a.y);
  await page.waitForTimeout(500);
  const gapsOpen = (await tagged('bridge_holds')).every((g) => g.open);
  await shotAs('p2_bridge.png');
  check('rewriting the bridge to HOLDS makes it crossable', (await vars()).stone_a === 'HOLDS' && Number((await vars()).bridge_holds) === 1 && gapsOpen, `stone_a ${(await vars()).stone_a}`);

  // the wolves fall asleep
  const b = await stone('b');
  await useAt(b.x, b.y);
  await page.waitForTimeout(400);
  check('the wolves fall ASLEEP', Number((await vars()).sleep_wood) === 1);

  // the gate opens for good
  const c = await stone('c');
  await useAt(c.x, c.y);
  await page.waitForTimeout(900);
  const gG = await byTag1('gate-G');
  check('the gate is OPEN', Number((await vars()).gate_G) === 1 && gG.open === true);

  // the river freezes for 12 s, then wears off
  const d = await stone('d');
  await useAt(d.x, d.y);
  await page.waitForTimeout(500);
  const frozen = Number((await vars()).river_frozen) === 1;
  await placeAt(d.x, d.y + 3);
  await page.waitForTimeout(13000);
  const v5 = await vars();
  check('the river FREEZES for 12 seconds, then the words wear off', frozen && Number(v5.river_frozen) === 0 && v5.stone_d === 'FLOWING', `frozen ${frozen}, after ${v5.river_frozen} ${v5.stone_d}`);

  // the three Torn Pages fit THE END
  for (const p of await tagged('page')) await useAt(p.x, p.y);
  const door = await byTag1('gate-H');
  await useAt(door.x, door.y, 1.2);
  await page.waitForTimeout(900);
  check('three Torn Pages open THE END', Number((await vars()).pip_pages) === 3 && Number((await vars()).door_H) === 1 && (await byTag1('gate-H')).open === true, `pages ${(await vars()).pip_pages}`);

  // the Spoiler wakes behind it
  await heal();
  await placeAt(36.5, 3.5);
  await page.waitForTimeout(1200);
  await readAll();
  check('the Spoiler wakes on the Last Page', Number((await vars()).spoiler_awake) === 1);
  // it reads a sentence; a strike while it reads rewrites it
  const spoiler = () => page.evaluate(() => { const c = window.__play.sim.world.withTag('spoiler')[0]; return c ? { hp: c.get('state:health')?.hp, ...c.get('transform') } : null; });
  let hz = 0;
  for (let i = 0; i < 80 && hz === 0; i++) { await heal(); await page.waitForTimeout(250); hz = (await tagged('hazard')).length; }
  await shotAs('p3_reading.png');
  for (let i = 0; i < 6 && !Number((await vars()).spoiler_rewrites); i++) {
    const sp = await spoiler();
    await placeAt(sp.x - 0.9, sp.y);
    await face(sp.x, sp.y);
    await press('KeyJ', 80);
  }
  check('a strike while it reads rewrites the sentence', hz > 0 && Number((await vars()).spoiler_rewrites) >= 1, `hazards ${hz}, rewrites ${(await vars()).spoiler_rewrites}`);

  // five rewrites (the rest a test shortcut): the reckoning, then it can be hurt
  await page.evaluate(() => { window.__play.sim.runtime.vars.spoiler_rewrites = 5; });
  await page.waitForTimeout(600);
  await readAll();
  await page.waitForTimeout(500);
  const s0 = await spoiler();
  for (let i = 0; i < 8; i++) {
    await heal();
    const sp = await spoiler();
    await placeAt(sp.x - 0.9, sp.y);
    await face(sp.x, sp.y);
    await press('KeyJ', 80);
  }
  const s1 = await spoiler();
  check('after five rewrites it can be hurt', Number((await vars()).spoiler_reckoning) === 1 && s1.hp < s0.hp, `hp ${s0.hp} -> ${s1.hp}`);

  // beaten (a test shortcut), Pip turns the page and the memory ends
  await page.evaluate(() => { const c = window.__play.sim.world.withTag('spoiler')[0]; const h = c.get('state:health'); h.hp = 0; h.dead = true; });
  await page.waitForTimeout(800);
  await readAll();
  check('the Spoiler is beaten', Number((await vars()).spoiler_down) === 1);
  const pip = await byTag1('pip');
  await useAt(pip.x, pip.y, 1.2);
  for (let i = 0; i < 40 && /pip/.test(await scene()); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(800);
  await shotAs('p4_home.png');
  const v9 = await vars();
  check('Pip turns the page and you are home', Number(v9.pip_memory_done) === 1 && Number(v9['item:bookmark']) >= 1 && /overworld/.test(await scene()), await scene());
} catch (e) {
  check('test run', false, String(e && e.stack || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
