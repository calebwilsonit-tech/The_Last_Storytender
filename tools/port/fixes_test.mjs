// Port tool: three review fixes: crumpling in a memory stays in the memory, a half-fought arena starts clean, the world returns after the ending card.
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/fixes_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
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
  const scene = () => page.evaluate(() => window.__play.sim.runtime.scene);
  const waitScene = async (re) => { for (let i = 0; i < 60 && !re.test(await scene()); i++) await page.waitForTimeout(250); await page.waitForTimeout(2200); await readAll(); };
  const clickText = async (t) => {
    const hit = await page.evaluate((t) => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === t).find((n) => n.getBoundingClientRect().width > 0); const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; }, t);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  const fade = () => page.evaluate(() => window.__play.sim.runtime.view.fade.alpha);
  const pl = () => page.evaluate(() => { const p = window.__play.sim.world.withTag('player')[0]; const t = p.get('transform'); return { x: t.x, y: t.y, hp: p.get('state:health').hp, dead: p.get('state:health').dead }; });
  let v;

  // ---- 3: an arena left half-fought starts clean when the scene loads again
  await setV({ memory_done: 1, has_quill: 1, arena_p_arena_ridge_w0: 1, arena_p_arena_ridge_w1: 1, arena_p_arena_ridge_open: 0 });
  await page.waitForTimeout(500);
  await setV({ go_weighing: 1 });
  await waitScene(/weighing/);
  await setV({ leave_weighing: 1 });
  await waitScene(/overworld/);
  v = await vars();
  const wave0 = await tagged('arena-p_arena_ridge-w0');
  const gate = at(await tagged('gate'), 105.5, 30.5);
  check('a stale arena fight is cleared when the scene loads: waves asleep, gate open', Number(v.arena_p_arena_ridge_w0) === 0 && Number(v.arena_p_arena_ridge_w1) === 0 && wave0.every((e) => !e.visible) && gate && gate.solid === false, `w0 ${v.arena_p_arena_ridge_w0}, visible ${wave0.map((e) => e.visible).join(',')}, gate solid ${gate?.solid}`);

  // ---- 2: crumpling inside a memory puts her back inside it, even after resting at an overworld post
  const post = (await tagged('lantern-post')).find((e) => Math.abs(e.x - 28.5) < 1) ?? (await tagged('lantern-post'))[0];
  await placeAt(post.x, post.y + 1.0);
  await page.waitForTimeout(400);
  await face(post.x, post.y);
  await press('KeyE');
  await page.waitForTimeout(2800);
  for (let i = 0; i < 3 && /Revise/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','))); i++) { await clickText('Leave the Index'); await page.waitForTimeout(700); }
  const cp = await page.evaluate(() => window.__play.sim.runtime.checkpoint?.scene ?? null);
  check('she has rested at an overworld post', /overworld/.test(String(cp)), String(cp));
  await setV({ met_garrick: 1, go_forge: 1 });
  await waitScene(/forge/);
  const start = await pl();
  await placeAt(start.x + 3, start.y);
  await page.waitForTimeout(500);
  await page.evaluate(() => { window.__play.sim.world.withTag('player')[0].get('state:health').hp = 0; });
  await page.waitForTimeout(1500);
  const after = await pl();
  check('crumpling in the forge keeps her in the forge', /forge/.test(await scene()), await scene());
  check('and stands her up again at the memory\'s start with ink', !after.dead && after.hp > 10 && Math.hypot(after.x - start.x, after.y - start.y) < 1.5, `at ${after.x.toFixed(1)},${after.y.toFixed(1)} (start ${start.x.toFixed(1)},${start.y.toFixed(1)}), hp ${after.hp}`);
  await setV({ leave_forge: 1 });
  await waitScene(/overworld/);

  // ---- 1: after the ending card the world comes back out of the white
  await setV({ restored_garrick: 1, restored_pip: 1, restored_maud: 1, scissor_done: 1, town_published: 1, renown: 300 });
  await placeAt(124.5, 53.5);
  await page.waitForTimeout(600);
  await setV({ play_k_ending: 1 });
  for (let i = 0; i < 60 && !/End of the Prologue/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','))); i++) { await readAll(); await page.waitForTimeout(300); }
  const white = await fade();
  check('the ending scene whites the screen out and shows the end card', white > 0.9 && /End of the Prologue/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','))), `fade ${white}`);
  await clickText('Keep exploring');
  await page.waitForTimeout(2800);
  check('"Keep exploring" brings the world back out of the white', (await fade()) < 0.05, `fade ${await fade()}`);
  await shotAs('fix_after_ending.png');

  // ---- 5: a cutscene_on that nothing is playing for does not freeze the Errors for good
  await page.waitForTimeout(1500);
  const errs = (await tagged('error')).filter((e) => e.visible);
  const e0 = errs[0];
  await placeAt(e0.x + 3.2, e0.y);
  await setV({ cutscene_on: 1, letterbox: 1 });
  await page.waitForTimeout(3500);
  v = await vars();
  check('a stuck cutscene_on (nothing playing) is let go within a few seconds', Number(v.cutscene_on) === 0 && Number(v.letterbox) === 0, `cutscene_on ${v.cutscene_on}, letterbox ${v.letterbox}`);
  // ...while a real scene keeps it (the Garrick restoration scene runs a few seconds)
  await setV({ memory_done: 1, restored_garrick: 0, play_k_garrick: 1 });
  await page.waitForTimeout(3500);
  const playing = await page.evaluate(() => window.__play.sim.runtime.cutscene?.name ?? null);
  v = await vars();
  check('but a scene that really is playing keeps the bars and the stillness', playing === 'k_garrick' && Number(v.cutscene_on) === 1 && Number(v.letterbox) === 1, `playing ${playing}, cutscene_on ${v.cutscene_on}`);
  await press('KeyP');
  await page.waitForTimeout(1200);

  // ---- 4: the crystals she leaves where she crumpled are worth exactly what was lost, even with the Mnemosynth bonus
  await setV({ attr_luck: 100, mnemosynth: 100, difficulty: 'normal', rested_once: 0 });
  await page.waitForTimeout(600);
  await placeAt(75.5, 62.5);
  await page.waitForTimeout(500);
  await page.evaluate(() => { window.__play.sim.world.withTag('player')[0].get('state:health').hp = 0; });
  await page.waitForTimeout(1200);
  const dropped = (await tagged('dropped')).filter((c) => Math.hypot(c.x - 75.5, c.y - 62.5) < 3);
  v = await vars();
  const mAfterDeath = Number(v.mnemosynth);
  for (const c of dropped) { await placeAt(c.x, c.y); await page.waitForTimeout(500); }
  v = await vars();
  check('picking the crystals up returns exactly what was lost (85 + 15), not more', dropped.length === 3 && mAfterDeath === 85 && Number(v.mnemosynth) === 100, `${dropped.length} crystals, M ${mAfterDeath} -> ${v.mnemosynth}`);
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
