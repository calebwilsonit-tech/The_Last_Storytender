// Port tool: wearing bindings and amulets (B-04) and falling and crumpling (B-05).
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/rules_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
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
const where = () => page.evaluate(() => { const t = window.__play.sim.world.withTag('player')[0].get('transform'); return { x: t.x, y: t.y }; });
const hp = () => page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('state:health').hp);
const face = (x, y) => page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4) + 8) % 8; }, [x, y]);
const tagged = (tag) => page.evaluate((tag) => window.__play.sim.world.withTag(tag).map((e) => ({ id: e.id, name: e.name, ...e.get('transform'), solid: e.get('collider') ? e.get('collider').enabled : null, visible: e.get('sprite')?.visible !== false, asset: e.get('sprite')?.asset, hp: e.get('state:health')?.hp })), tag);
const press = async (key, ms = 90) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(160); };
const hold = async (key, ms) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(200); };
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
const shotAs = (name) => page.screenshot({ path: path.join(outDir, name) });
const at = (list, x, y) => list.find((e) => Math.abs(e.x - x) < 0.3 && Math.abs(e.y - y) < 0.3);
/** Stand a little way off, face it, press E and read what it says. */
const useThing = async (x, y, fromX, fromY) => { await placeAt(fromX, fromY); await page.waitForTimeout(350); await face(x, y); await page.waitForTimeout(150); await press('KeyE'); await page.waitForTimeout(400); return readAll(); };

try {
  await page.waitForTimeout(1500);
  let v;
  const player = () => page.evaluate(() => { const p = window.__play.sim.world.withTag('player')[0]; const h = p.get('health'); const t = p.get('transform'); return { x: t.x, y: t.y, hp: p.get('state:health').hp, max: h.max, grace: h.invulnerableSeconds, fall: h.fallDamage, speed: p.get('playerController').speed, cd: p.get('dodge').cooldown }; });
  const clickText = async (t, nth = 0) => {
    const hit = await page.evaluate(([t, nth]) => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === t).filter((n) => n.getBoundingClientRect().width > 0)[nth]; const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; }, [t, nth]);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  // ---- B-04: bindings and amulets are worn from the binder
  await setV({ 'item:cloth_binding': 1, 'item:tin_bell': 1, 'item:paper_scrap': 3, 'slot:1': 'paper_scrap', 'slot:2': '' });
  await placeAt(60.5, 60.5);
  await page.waitForTimeout(600);
  v = await vars();
  check('a picked-up scrap does not sit in a quick slot', v['slot:1'] === '', `slot 1 holds "${v['slot:1']}"`);
  const p0 = await player();
  await press('KeyI');
  await page.waitForTimeout(1000);
  const clicked = await clickText('Cloth Binding');
  await page.waitForTimeout(500);
  v = await vars();
  check('clicking a binding in the binder wears it (at once, the world waits)', v.worn_binding === 'cloth_binding', `clicked ${clicked}, worn_binding ${v.worn_binding}`);
  await clickText('Tin Bell');
  await page.waitForTimeout(500);
  v = await vars();
  check('an amulet goes in its own slot', v.worn_amulet === 'tin_bell', `worn_amulet ${v.worn_amulet}`);
  await shotAs('rules_binder.png');
  await press('KeyI');
  await page.waitForTimeout(900);
  const p1 = await player();
  v = await vars();
  check('what is worn changes her: +5% speed and +0.35 s of grace', Math.abs(p1.speed - 4.2 * 1.05) < 0.03 && Math.abs(p1.grace - 1.25) < 0.01, `speed ${p0.speed} -> ${p1.speed}, grace ${p0.grace} -> ${p1.grace}`);
  check('the binder says what it does', /-6%/.test(String(v.st0)) && /\+5%/.test(String(v.st1)) && /1\.3s|1\.2s/.test(String(v.st3)), `${v.st0} | ${v.st1} | ${v.st3}`);
  // take it off by clicking its slot
  await press('KeyI');
  await page.waitForTimeout(900);
  await clickText('click to take off');
  await page.waitForTimeout(400);
  v = await vars();
  check('clicking the slot takes it off', !v.worn_binding || !v.worn_amulet, `binding "${v.worn_binding}" amulet "${v.worn_amulet}"`);
  await press('KeyI');
  await page.waitForTimeout(700);

  // ---- B-05: falling and crumpling
  const diff = async (d) => { await setV({ difficulty: d }); await page.waitForTimeout(500); };
  await diff('story');
  const ps = await player();
  await diff('normal');
  const pn = await player();
  check('a fall costs 8 ink in Story and 15 in Normal', ps.fall === 8 && pn.fall === 15, `story ${ps.fall}, normal ${pn.fall}`);
  const crush = async (x, y) => {
    await placeAt(x, y);
    await page.waitForTimeout(500);
    await page.evaluate(() => { window.__play.sim.world.withTag('player')[0].get('state:health').hp = 0; });
    await page.waitForTimeout(900);
  };
  // normal: she loses a seventh of her Mnemosynth (floor(M x 0.15 / 5) x 5), it lies where she fell, and she wakes with 50 ink
  await setV({ mnemosynth: 100, difficulty: 'normal', rested_once: 0 });
  const crystals0 = (await tagged('dropped')).length;
  await crush(60.5, 60.5);
  v = await vars();
  const pp = await player();
  const crystals1 = (await tagged('dropped')).length;
  check('Normal: 15 of 100 Mnemosynth are left where she fell, as three crystals', Number(v.mnemosynth) === 85 && crystals1 - crystals0 === 3, `M ${v.mnemosynth}, crystals ${crystals0} -> ${crystals1}`);
  check('Normal: she wakes with 50 ink and the page says it can be smoothed', pp.hp === 50 && (await msgs()).some((m) => /crumpled page can be smoothed/i.test(m)), `hp ${pp.hp}`);
  check('with no post rested at she wakes at the start of the page', Math.abs(pp.x - 16.5) < 3 && Math.abs(pp.y - 54.5) < 3, `at ${pp.x.toFixed(1)},${pp.y.toFixed(1)}`);
  // story: nothing lost, 100 ink
  await setV({ mnemosynth: 100, difficulty: 'story' });
  await crush(75.5, 62.5);
  v = await vars();
  const pst = await player();
  check('Story: nothing is lost and she wakes with 100 ink', Number(v.mnemosynth) === 100 && pst.hp === 100, `M ${v.mnemosynth}, hp ${pst.hp}`);
  // in the town she wakes in the town's square
  await crush(92.5, 56.5);
  const pt = await player();
  check('a crumple in the town wakes her in the town square (87,53)', Math.abs(pt.x - 87.5) < 1.5 && Math.abs(pt.y - 53.5) < 1.5, `at ${pt.x.toFixed(1)},${pt.y.toFixed(1)}`);
  // after resting at a post she wakes at that post
  await setV({ rested_once: 0 });
  const post = (await tagged('lantern-post')).find((e) => Math.abs(e.x - 28.5) < 1 && Math.abs(e.y - 52.5) < 1) ?? (await tagged('lantern-post'))[0];
  await placeAt(post.x, post.y + 1.0);
  await page.waitForTimeout(500);
  await face(post.x, post.y);
  await press('KeyE');
  await page.waitForTimeout(2600);
  for (let i = 0; i < 3 && /Revise/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','))); i++) { await clickText('Leave the Index'); await page.waitForTimeout(700); }
  console.log('checkpoint', JSON.stringify(await page.evaluate(() => window.__play.sim.runtime.checkpoint)), 'rested_once', (await vars()).rested_once, 'post', JSON.stringify(post));
  await crush(75.5, 62.5);
  const pr = await player();
  check('after resting at a post she wakes beside it', Math.hypot(pr.x - post.x, pr.y - (post.y + 1)) < 2.5, `at ${pr.x.toFixed(1)},${pr.y.toFixed(1)}; post ${post.x},${post.y}`);
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
