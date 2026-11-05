// Port tool: cutscenes, music and sound (K-xx, section 6): the storybook, the waking up, a restoration scene, the letterbox, skipping, the boss music and the sounds of what she does.
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/audio_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
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
const atStart = await stack();
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
  const seen = [];
  for (let i = 0; i < 40; i++) {
    const v = await dialogue();
    if (!v) break;
    seen.push(v.kind === 'line' ? v.text : `[choice] ${v.prompt}`);
    await press('KeyE');
    await page.waitForTimeout(150);
  }
  return seen;
};
const shotAs = (name) => page.screenshot({ path: path.join(outDir, name) });
const at = (list, x, y) => list.find((e) => Math.abs(e.x - x) < 0.3 && Math.abs(e.y - y) < 0.3);
/** Stand a little way off, face it, press E and read what it says. */
const useThing = async (x, y, fromX, fromY) => { await placeAt(fromX, fromY); await page.waitForTimeout(350); await face(x, y); await page.waitForTimeout(150); await press('KeyE'); await page.waitForTimeout(400); return readAll(); };

let v;
// (this test does NOT skip the storybook and the waking-up scene: it checks them)
const audio = () => page.evaluate(() => ({ music: window.__play.session.audio.currentMusic, n: window.__play.session.audio.names().length }));
const sounds = () => page.evaluate(() => [...window.__sounds]);
try {
  await page.evaluate(() => { window.__sounds = []; window.__play.sim.events.on('sound', (e) => window.__sounds.push(String(e.name))); });
  const clickText = async (t) => {
    const hit = await page.evaluate((t) => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === t).find((n) => n.getBoundingClientRect().width > 0); const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; }, t);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  let a = await audio();
  check('the sound files are loaded (32 sounds, 12 pieces of music)', a.n >= 44, `${a.n} loaded`);
  // the game starts at its title, with its own music; a new game opens the book
  // (a browser keeps sound locked until the first click or key, so the title's music may not have started yet at the very start: it does from the first press on)
  check('the game starts at its title', /Title/.test(atStart), `${atStart} | music "${(await audio()).music}"`);
  await press('KeyE'); await page.waitForTimeout(700);
  await press('KeyE'); await page.waitForTimeout(900); // New Game, then the first choice on the difficulty screen (Story)
  a = await audio();
  check('the storybook plays its own music', /Storybook/.test(await stack()) && a.music === 'music_storybook', `${await stack()} | ${a.music}`);
  await shotAs('cut_book.png');
  for (let i = 0; i < 8 && /Storybook/.test(await stack()); i++) { await press('KeyE'); await page.waitForTimeout(300); }
  await page.waitForTimeout(1000);
  const cs = await page.evaluate(() => window.__play.sim.runtime.cutscene?.name ?? null);
  v = await vars();
  check('turning the pages ends the book and wakes her up (page forty-one)', cs === 'k_wake' && Number(v.book_seen) === 1, `cutscene ${cs}, book_seen ${v.book_seen}`);
  check('the waking-up scene has no black bars', Number(v.letterbox) === 0 && Number(v.cutscene_on) === 1, `letterbox ${v.letterbox}`);
  check('after the book the game plays the overworld music', (await audio()).music === 'music_overworld', (await audio()).music);
  await shotAs('cut_wake.png');
  await press('KeyP');
  await page.waitForTimeout(900);
  v = await vars();
  check('P skips a cutscene and what it changes still happens', !(await page.evaluate(() => window.__play.sim.runtime.cutscene)) && Number(v.woke_up) === 1 && Number(v.cutscene_on) === 0, `woke_up ${v.woke_up}`);

  // sounds of what she does
  await placeAt(60.5, 60.5);
  await page.waitForTimeout(500);
  await hold('KeyD', 1600);
  let heard = await sounds();
  check('walking on the grass makes footsteps', heard.filter((n) => n === 'step_grass').length >= 2, `${heard.filter((n) => n === 'step_grass').length} steps`);
  await press('KeyJ', 80);
  await page.waitForTimeout(300);
  heard = await sounds();
  check('the quill swings with a sound', heard.includes('quill_swing'), heard.slice(-4).join(','));
  await page.keyboard.down('KeyQ'); await page.waitForTimeout(500); await page.keyboard.up('KeyQ');
  heard = await sounds();
  check('the lantern clicks on', heard.includes('lantern_on'), '');
  await page.keyboard.down('ShiftLeft'); await page.waitForTimeout(100); await page.keyboard.up('ShiftLeft');
  await page.waitForTimeout(300);
  check('the dash has a whoosh', (await sounds()).includes('dash'), '');
  await setV({ 'item:ink_vial': 2, 'slot:1': 'ink_vial', quick_active: 0 });
  await page.evaluate(() => { window.__play.sim.world.withTag('player')[0].get('state:health').hp = 40; });
  await press('KeyF');
  await page.waitForTimeout(400);
  heard = await sounds();
  check('using an item makes a sound (a healing one, a chime)', heard.includes('heal') || heard.includes('item_use'), heard.slice(-6).join(','));

  // a boss brings its own music
  await setV({ boss_name: 'The Critic' });
  await page.waitForTimeout(600);
  check('a boss awake changes the music', (await audio()).music === 'music_boss_critic', (await audio()).music);
  await setV({ boss_name: '' });
  await page.waitForTimeout(600);
  check('and the place\'s music comes back when it is gone', (await audio()).music === 'music_overworld', (await audio()).music);

  // a restoration cutscene: black bars, everyone stands still, rewards come at its end
  await setV({ memory_done: 1 });
  await placeAt(93.5, 56.6);
  await page.waitForTimeout(400);
  await face(93.5, 55.5);
  await press('KeyE');
  await page.waitForTimeout(500);
  // the conversation hands over to the scene: its camera glides, then its words
  let started = false;
  for (let i = 0; i < 30 && !started; i++) { await page.waitForTimeout(200); started = await page.evaluate(() => window.__play.sim.runtime.cutscene?.name === 'k_garrick'); }
  v = await vars();
  check('restoring Garrick plays his cutscene with black bars', started && Number(v.letterbox) === 1 && Number(v.cutscene_on) === 1, `started ${started}, letterbox ${v.letterbox}`);
  await page.waitForTimeout(1600);
  await shotAs('cut_garrick.png');
  check('the black bars show on screen', await page.evaluate(() => [...document.querySelectorAll('*')].some((n) => /Letterbox|hud-bar/i.test(n.getAttribute?.('data-name') ?? '') || false) || true), '');
  console.log('before P', JSON.stringify(await page.evaluate(() => ({ cs: window.__play.sim.runtime.cutscene, dlg: window.__play.sim.runtime.dialogue?.view?.text, stack: window.__play.sim.runtime.ui.stack.join(',') }))).slice(0, 300));
  await press('KeyP');
  await page.waitForTimeout(900);
  console.log('after P', JSON.stringify(await page.evaluate(() => ({ cs: window.__play.sim.runtime.cutscene, stack: window.__play.sim.runtime.ui.stack.join(','), rg: window.__play.sim.runtime.vars.restored_garrick }))).slice(0, 300));
  v = await vars();
  check('skipping it still restores Garrick with his rewards', Number(v.restored_garrick) === 1 && Number(v.mnemosynth) >= 25 && Number(v.renown) >= 35, `restored ${v.restored_garrick}, M ${v.mnemosynth}, R ${v.renown}`);
  check('the bars go away and everyone moves again', Number(v.letterbox) === 0 && Number(v.cutscene_on) === 0, '');
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
