// Port tool: save and Continue (B-02), checked in the real Tilewright editor with real keys (F uses the quick slot).
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
  await setV({ mnemosynth: 123, renown: 44, 'item:ink_vial': 4, memory_done: 1, has_sword: 1, restored_garrick: 1, restored_pip: 1, restored_maud: 1, has_quill: 1, lesson_done: 1, difficulty: 'story' });
  // beat an Error and open a chest, as a played game would have
  await page.evaluate(() => { const s = window.__play.sim; const e = s.world.withTag('error')[0]; if (e) { const h = e.get('state:health'); h.hp = 0; } });
  await page.waitForTimeout(500);
  const files = () => { try { return fs.readdirSync(path.join(work, 'saves')); } catch { return ['(no saves folder)']; } };
  console.log('saves at start', files());
  console.log('direct saveTo ->', await page.evaluate(async () => { try { return await window.__play.session.saveTo('autosave'); } catch (e) { return 'threw ' + e; } }));
  console.log('after direct', files(), 'projectDir', await page.evaluate(() => window.__play.session.o?.projectDir));
  await press('KeyP'); await page.waitForTimeout(900);
  await shotAs('save_pause.png');
  console.log('stack', await stack());
  const clickText = async (t) => {
    const hit = await page.evaluate((t) => { const n = [...document.querySelectorAll('*')].filter((n) => (n.textContent ?? '').trim() === t && n.children.length === 0).map((n) => { const r = n.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })[0]; return n ?? null; }, t);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  console.log('clicked save', await clickText('Save and return to title'));
  await page.waitForTimeout(2500);
  console.log('stack after', await stack(), 'saves', files());
  await shotAs('save_title.png');
  const titleText = await page.evaluate(() => [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim()).map((n) => n.textContent.trim()).join(' | '));
  const hasContinue = /Continue/.test(titleText);
  check('after Save and return to title the title offers Continue', hasContinue, titleText.slice(0, 300));
  await setV({ mnemosynth: 0, renown: 0 });
  console.log('clicked continue', await clickText('Continue'));
  await page.waitForTimeout(3500);
  console.log('messages', (await msgs()).slice(-6));
  const v = await vars();
  check('Continue brings back Mnemosynth, renown and items', Number(v.mnemosynth) === 123 && Number(v.renown) === 44 && Number(v['item:ink_vial']) === 4, `M ${v.mnemosynth} R ${v.renown} vials ${v['item:ink_vial']} stack ${await stack()}`);
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
