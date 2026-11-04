// Port tool: resting at a lantern post opens "Revise Your Draft", where Mnemosynth buys stat points (P-01), in the real Tilewright editor.
// The Storytender is put next to a post (a test shortcut); the post is used with E, the buttons are clicked.
//   TILEWRIGHT=<engine checkout> node tools/port/index_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
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
const face = (x, y) => page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4) + 8) % 8; }, [x, y]);
const tagged = (tag) => page.evaluate((tag) => window.__play.sim.world.withTag(tag).map((e) => ({ id: e.id, name: e.name, ...e.get('transform') })), tag);
const press = async (key, ms = 90) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(160); };
const shotAs = (name) => page.screenshot({ path: path.join(outDir, name) });
const maxInk = () => page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('health').max);
const hpNow = () => page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('state:health').hp);
/** The centre of the "+" beside a row's name (the topmost element there is the real button when one can be pressed). */
const plusOf = (name) =>
  page.evaluate((name) => {
    const leaf = (t) => [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === t);
    const nm = leaf(name).find((n) => n.getBoundingClientRect().width > 0);
    if (!nm) return null;
    const r = nm.getBoundingClientRect();
    const plus = leaf('+').map((n) => n.getBoundingClientRect()).filter((b) => b.width > 0 && Math.abs(b.y + b.height / 2 - (r.y + r.height / 2)) < r.height * 1.4).sort((a, b) => b.x - a.x)[0];
    return plus ? { x: plus.x + plus.width / 2, y: plus.y + plus.height / 2 } : null;
  }, name);

try {
  await page.waitForTimeout(1500);
  const post = (await tagged('lantern-post'))[0];
  await placeAt(post.x, post.y + 1.0);
  await page.waitForTimeout(500);
  await face(post.x, post.y);
  await page.waitForTimeout(200);
  await press('KeyE');
  await page.waitForTimeout(3200);
  const v0 = await vars();
  const open0 = /storytender-index|Revise/i.test(await stack());
  await shotAs('idx_open.png');
  check('resting at a post opens Revise Your Draft with 15 free points the first time', open0 && Number(v0.free_points) === 15, `stack ${await stack()}, free ${v0.free_points}, messages ${(await msgs()).slice(-3).join(' | ')}`);
  check('the Index is explained the first time (INDEX_FIRST)', (await msgs()).some((m) => /page of the Index/i.test(m)), '');

  // buy Inkwell with a free point, by clicking its +
  let at = await plusOf('Inkwell');
  if (at) await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(500);
  let v = await vars();
  check('a free point buys Inkwell: level 2, 14 free points left', Number(v.attr_ink) === 1 && Number(v.free_points) === 14 && Number(v.level) === 2, `attr_ink ${v.attr_ink} free ${v.free_points} level ${v.level}; + found ${!!at}`);
  await shotAs('idx_after_one.png');
  // the other 14 free points, then a paid one
  for (let i = 0; i < 14; i++) { at = await plusOf('Inkwell'); if (at) await page.mouse.click(at.x, at.y); await page.waitForTimeout(150); }
  v = await vars();
  check('fifteen free points are all spent on Inkwell', Number(v.attr_ink) === 15 && Number(v.free_points) === 0 && Number(v.attr_points) === 15, `attr_ink ${v.attr_ink} free ${v.free_points} cost ${v.attr_cost}`);
  check('the next point costs floor(20 + 4p + 0.08p^2) = 98 after 15 points', Number(v.attr_cost) === 98, `cost ${v.attr_cost}`);
  await setV({ mnemosynth: 90 });
  at = await plusOf('Thick Paper');
  if (at) await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(400);
  v = await vars();
  check('with 90 Mnemosynth a point at 98 is refused', Number(v.attr_grit) === 0 && Number(v.mnemosynth) === 90, `attr_grit ${v.attr_grit} M ${v.mnemosynth}`);
  await setV({ mnemosynth: 150 });
  await page.waitForTimeout(300);
  at = await plusOf('Thick Paper');
  if (at) await page.mouse.click(at.x, at.y);
  await page.waitForTimeout(400);
  v = await vars();
  check('with 150 Mnemosynth a point costs 98 and the price goes to 104', Number(v.attr_grit) === 1 && Number(v.mnemosynth) === 52 && Number(v.attr_cost) === 104, `attr_grit ${v.attr_grit} M ${v.mnemosynth} cost ${v.attr_cost}`);
  await shotAs('idx_paid.png');

  // leave, and the stats are in effect
  // (in the editor Esc stops the game, so the button is clicked)
  const leave = await page.evaluate(() => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === 'Leave the Index').find((n) => n.getBoundingClientRect().width > 0); const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; });
  if (leave) await page.mouse.click(leave.x, leave.y);
  await page.waitForTimeout(900);
  check('"Leave the Index" closes it', !/Revise|storytender-index/i.test(await stack()), await stack());
  const mi = await maxInk();
  check('Inkwell raises the ink: 15 points = 130 maximum', mi === 130, `max ink ${mi}`);
  // Thick Paper gives back 0.5% of a blow: 1 point on a 10 blow is 0.05; Wit heals; test the speed and the quill instead
  await setV({ attr_foot: 40, attr_pen: 20, attr_wit: 10 });
  await page.waitForTimeout(600);
  const stats = await page.evaluate(() => { const p = window.__play.sim.world.withTag('player')[0]; return { speed: p.get('playerController').speed, dmg: p.get('meleeAttack').damage, range: p.get('meleeAttack').range, cd: p.get('dodge').cooldown }; });
  check('Footwork 40 speeds her up 12% and shortens the dash by 20%', Math.abs(stats.speed - 4.2 * 1.12) < 0.05 && Math.abs(stats.cd - 0.6) < 0.01, JSON.stringify(stats));
  check('Penmanship 20 adds 20% to the quill and 5% to its reach', Math.abs(stats.dmg - 1.1 * 1.2) < 0.02 && Math.abs(stats.range - 2.1 * 1.05) < 0.02, JSON.stringify(stats));
  // resting again opens it again, without the free points
  await setV({ attr_foot: 0, attr_pen: 0, attr_wit: 0 });
  await press('KeyE');
  await page.waitForTimeout(1500);
  const v2 = await vars();
  check('resting a second time opens it again and gives no more free points', /storytender-index|Revise/i.test(await stack()) && Number(v2.free_points) === 0, `stack ${await stack()}, free ${v2.free_points}`);
  await shotAs('idx_second.png');
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
