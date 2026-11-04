// Port tool: what the usable items do (B-03), checked in the real Tilewright editor with real keys (F uses the quick slot).
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
  await page.waitForTimeout(400);
  // ink and lantern
  await setHp(40); await setV({ light: 30 });
  let r = await useIt('herbal_tea', 2);
  check('Herbal Tea: +25 ink and +25 lantern, one used up', Math.abs((await hp()) - 65) < 1.5 && Number((await vars()).light) >= 54 && r.count === 1, `hp ${await hp()} light ${(await vars()).light} left ${r.count} | ${r.said.join(' / ')}`);
  await setHp(100);
  r = await useIt('ink_vial', 3);
  check('Ink Vial at full ink says so and is not used up', r.count === 3 && r.said.some((m) => /already full/i.test(m)), `left ${r.count} | ${r.said.join(' / ')}`);
  await setHp(30);
  r = await useIt('warm_loaf', 1);
  check('Warm Loaf: +60 ink', Math.abs((await hp()) - 90) < 1.5 && r.count === 0, `hp ${await hp()} left ${r.count}`);
  await setHp(20); await setV({ light: 10 });
  r = await useIt('phoenix_draught', 1);
  check('Phoenix Draught: all ink and a full lantern', (await hp()) >= 99 && Number((await vars()).light) >= 99 && r.count === 0, `hp ${await hp()} light ${(await vars()).light}`);
  await setV({ light: 40 });
  r = await useIt('lantern_oil', 1);
  check('Lantern Oil refuels the lantern', Number((await vars()).light) >= 99 && r.count === 0, `light ${(await vars()).light}`);
  // renown and Mnemosynth
  await setV({ renown: 5, mnemosynth: 10 });
  r = await useIt('reader_digest', 1);
  check("Reader's Digest: +12 renown", Number((await vars()).renown) === 17 && r.count === 0, `renown ${(await vars()).renown}`);
  r = await useIt('memory_jar', 1);
  check('Memory Jar: +60 Mnemosynth', Number((await vars()).mnemosynth) === 70 && r.count === 0, `M ${(await vars()).mnemosynth}`);
  await shotAs('items_toast.png');

  // Eraser Crumbs: thrown at the training dummy (5 damage, landing about 150 px away the way she faces)
  const dummy = (await tagged('dummy'))[0];
  if (!dummy) check('the training dummy exists', false, 'no tag dummy');
  else {
    // north on the screen (facing 6) is grid (-1, -1): stand 3 cells south-east of the dummy along the diagonal
    await placeAt(dummy.x + 3, dummy.y + 3);
    await page.waitForTimeout(400);
    await faceDir(6);
    const before = (await tagged('dummy'))[0].hp;
    await setV({ 'item:eraser_crumbs': 2, 'slot:1': 'eraser_crumbs', quick_active: 0 });
    await press('KeyF');
    await page.waitForTimeout(350);
    await shotAs('items_crumbs_flying.png');
    await page.waitForTimeout(1300);
    const after = (await tagged('dummy'))[0].hp;
    check('Eraser Crumbs thrown at the dummy: 5 damage', Math.abs(before - after - 5) < 0.6 && Number((await vars())['item:eraser_crumbs']) === 1, `dummy hp ${before} -> ${after}, crumbs left ${(await vars())['item:eraser_crumbs']}`);
    const bombs = await page.evaluate(() => window.__play.sim.world.withTag('eraser-bomb').length);
    check('the thrown crumbs are gone afterwards', bombs === 0, `${bombs} left`);
  }

  // Sticky Note: Errors nearby stop moving
  const errs = (await tagged('error')).filter((e) => e.visible);
  console.log('errors visible', errs.map((e) => `${e.name}@${e.x.toFixed(0)},${e.y.toFixed(0)}`).join(' '));
  const bare = errs.find((e) => /Bare|Mite/.test(e.name));
  if (!bare) check('an Error is out to test the Sticky Note on', false, 'none visible');
  else {
    await placeAt(bare.x + 3, bare.y + 3);
    await page.waitForTimeout(300);
    const at = (await tagged('error')).find((e) => e.id === bare.id);
    r = await useIt('sticky_note', 1);
    const t0 = (await tagged('error')).find((e) => e.id === bare.id);
    await page.waitForTimeout(2500);
    const t1 = (await tagged('error')).find((e) => e.id === bare.id);
    const moved = Math.hypot(t1.x - t0.x, t1.y - t0.y);
    check('Sticky Note: the Error nearby stays put for a while and the note is used up', moved < 0.35 && r.count === 0 && r.said.some((m) => /Stuck 1/.test(m)), `moved ${moved.toFixed(2)} cells in 2.5 s | ${r.said.join(' / ')}`);
    await setV({ 'item:time_in_a_bottle': 1 });
    r = await useIt('ghost_pepper_ink', 1);
    check('Ghost Pepper Ink with an Error close says so', r.said.some((m) => /forget how to move/i.test(m)), r.said.join(' / '));
  }
  // somewhere with no Error within 12 cells
  const spots = [[60.5, 60.5], [20.5, 90.5], [90.5, 20.5], [30.5, 30.5], [90.5, 90.5]];
  const far = spots.find(([x, y]) => errs.every((e) => Math.hypot(e.x - x, e.y - y) > 12)) ?? spots[0];
  await placeAt(far[0], far[1]);
  await page.waitForTimeout(300);
  r = await useIt('sticky_note', 1);
  check('Sticky Note with no Error nearby says so and is kept', r.count === 1 && r.said.some((m) => /Nothing nearby/i.test(m)), `left ${r.count} | ${r.said.join(' / ')}`);
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
