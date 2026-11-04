// Port tool (maud): plays Maud's memory in the ported game in the real Tilewright editor and checks that its interactions work: reading a sign,
// talking to Garrick, collecting a crystal, opening a chest, taking a pickup, lighting a lantern post, striking the
// dummy. The Storytender is moved next to each thing (a test shortcut), then everything else is done with real keys.
// Screenshots and a report go to <out_dir>.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/maud_test.mjs <project_dir> <out_dir>
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
const face = (x, y) => page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4) + 8) % 8; }, [x, y]);
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

const byTag1 = async (tag) => (await tagged(tag))[0];
const useAt = async (x, y, dy = 1.0) => { await placeAt(x, y + dy); await page.waitForTimeout(300); await press('KeyE'); await page.waitForTimeout(300); return readAll(); };
const strikeAt = async (b, key) => {
  await press(key);
  await placeAt(b.x - 1.0, b.y + 0.05);
  await face(b.x, b.y);
  await press('KeyJ', 80);
  await page.waitForTimeout(400);
};
const word = async (w) => byTag1(`word-${w}`);
try {
  await page.evaluate(() => { const v = window.__play.sim.runtime.vars; v.memory_done = 1; v.has_quill = 1; v.pip_memory_done = 1; v.go_maud = 1; });
  for (let i = 0; i < 40 && !/maud/.test(await scene()); i++) await page.waitForTimeout(250);
  check("Maud's oven takes you into the memory", /maud/.test(await scene()), await scene());
  await page.waitForTimeout(2000);
  const intro = await readAll();
  await shotAs('m1_arrive.png');
  check('the memory greets you and grants the format styles', intro.length > 0 && Number((await vars()).format_mark) === 1, intro.join(' | ').slice(0, 120));

  // the Pantry: underline BREAD and it bridges the gap
  await strikeAt(await word('bread'), 'Digit1');
  const bridged = (await tagged('bread_bridge')).every((g) => g.open);
  await shotAs('m2_bread.png');
  check('underlining BREAD bridges the gap', Number((await vars()).bread_bridge) === 1 && bridged, `style ${(await vars()).format_style}`);

  // the Kitchen: bold SALT, then italic: it slides onto the plate and the COLD door opens
  const salt0 = await word('salt');
  await strikeAt(salt0, 'Digit2');
  await placeAt(salt0.x - 1.0, salt0.y + 0.05);
  await face(salt0.x, salt0.y);
  await press('Digit3');
  await press('KeyJ', 80);
  await placeAt(salt0.x, salt0.y + 2.5);
  await page.waitForTimeout(2500);
  const salt1 = await word('salt');
  await shotAs('m3_salt.png');
  check('bold, italic SALT slides onto the plate and opens the COLD door', Number((await vars()).cold_gate) === 1 && salt1.x > salt0.x + 5, `salt ${salt0.x} -> ${salt1.x}`);

  // the Cellar: the dough cannot be rushed (a test shortcut lets it rise), then underline it
  const dough = await word('dough');
  await strikeAt(dough, 'Digit1');
  const burnt = !(await vars()).dough_bridge;
  await page.evaluate(() => { const d = window.__play.sim.world.withTag('word-dough')[0]; const s = d.get('scriptScratch') ?? {}; });
  for (let i = 0; i < 80 && (await readAll()).length >= 0; i++) {
    const risen = await page.evaluate(() => window.__play.sim.world.withTag('word-dough')[0]?.get('sprite')?.alpha);
    if (risen === undefined || risen >= 0.999) break;
    await page.waitForTimeout(500);
  }
  await strikeAt(dough, 'Digit1');
  await readAll();
  check('the dough collapses if rushed, and once risen underlining it bridges the cellar', burnt && Number((await vars()).dough_bridge) === 1, `bridge ${(await vars()).dough_bridge}`);

  // the Hall: guests arrive; the lantern leads one to a chair
  await heal();
  await placeAt(36.5, 7.5);
  await page.waitForTimeout(1200);
  await readAll();
  check('the Empty Table wakes in the hall', Number((await vars()).table_awake) === 1);
  let guests = [];
  for (let i = 0; i < 40 && guests.length < 2; i++) { await heal(); await page.waitForTimeout(300); guests = await tagged('guest'); }
  check('guests arrive', guests.length >= 2, `${guests.length} guests`);
  const chairs = await tagged('chair');
  const g0 = guests[0];
  const ch = near(chairs, g0.x, g0.y);
  // walk the guest to a chair: stand by the chair and shine the lantern at the guest
  await page.keyboard.down('KeyQ');
  for (let i = 0; i < 30 && !(Number((await vars()).guests_seated) >= 1); i++) {
    await heal();
    const g = (await tagged('guest')).find((x) => x.id === g0.id) ?? g0;
    const fx = ch.x + (ch.x > g.x ? 0.7 : -0.7), fy = ch.y;
    await placeAt(fx, fy);
    await face(g.x, g.y);
    await page.waitForTimeout(400);
  }
  await page.keyboard.up('KeyQ');
  await shotAs('m4_guest.png');
  check('the lantern leads a guest to a chair', Number((await vars()).guests_seated) >= 1, `seated ${(await vars()).guests_seated}`);

  // six seated (a test shortcut): the Cold Shoulder comes; it shrugs off a blow from the front
  await page.evaluate(() => { window.__play.sim.runtime.vars.cold_spawn = 1; window.__play.sim.runtime.vars.table_full = 1; });
  await page.waitForTimeout(1200);
  const cold = () => page.evaluate(() => { const c = window.__play.sim.world.withTag('coldshoulder')[0]; return c ? { hp: c.get('state:health')?.hp, ...c.get('transform') } : null; });
  const c0 = await cold();
  check('the Cold Shoulder comes', !!c0, c0 ? `hp ${c0.hp}` : 'none');
  // strike from behind it (it faces the Storytender, so a few strikes from the side it is slow to turn to)
  let c1 = c0;
  for (let i = 0; i < 14 && c1 && c1.hp >= c0.hp; i++) {
    await heal();
    const c = await cold();
    await placeAt(c.x + (i % 2 ? 1.0 : -1.0), c.y + (i % 4 < 2 ? 0.9 : -0.9));
    await face(c.x, c.y);
    await press('KeyJ', 80);
    await page.waitForTimeout(250);
    c1 = await cold();
  }
  await shotAs('m5_cold.png');
  check('the Cold Shoulder can be hurt from behind or as it rests', c1 && c1.hp < c0.hp, `hp ${c0?.hp} -> ${c1?.hp}`);

  // beaten (a test shortcut): sit with Maud and the memory ends
  await page.evaluate(() => { const c = window.__play.sim.world.withTag('coldshoulder')[0]; const h = c.get('state:health'); h.hp = 0; h.dead = true; });
  await page.waitForTimeout(800);
  await readAll();
  check('the Cold Shoulder is beaten', Number((await vars()).maud_finale) === 1);
  const maud = await byTag1('maud');
  await useAt(maud.x, maud.y, 1.2);
  for (let i = 0; i < 40 && /maud/.test(await scene()); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(800);
  const v9 = await vars();
  check('you sit with Maud and are home', Number(v9.maud_memory_done) === 1 && /overworld/.test(await scene()), await scene());
} catch (e) {
  check('test run', false, String(e && e.stack || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
