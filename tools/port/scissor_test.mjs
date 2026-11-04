// Port tool: the end of the Prologue (C-01): the rift, the Cutting Room fight, publishing the town, the Margin Gate and the end card.
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/scissor_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
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
  const waitScene = async (re) => { for (let i = 0; i < 60 && !re.test(await scene()); i++) await page.waitForTimeout(250); await page.waitForTimeout(1500); };
  const clickText = async (t) => {
    const hit = await page.evaluate((t) => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === t).find((n) => n.getBoundingClientRect().width > 0); const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; }, t);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  let v;
  // ---- the rift: only once all three are restored
  await setV({ restored_garrick: 1, restored_pip: 1 });
  await placeAt(86.5, 56.5);
  await page.waitForTimeout(800);
  let rift = (await tagged('rift'))[0];
  check('the rift is not there until Maud is restored too', rift && !rift.visible, JSON.stringify(rift));
  await setV({ restored_maud: 1 });
  await page.waitForTimeout(800);
  rift = (await tagged('rift'))[0];
  check('with all three restored the rift opens in the square, and says so', rift && rift.visible && (await msgs()).some((m) => /something in the sky begins to cut/i.test(m)), JSON.stringify(rift));
  await shotAs('end_rift.png');
  const said = await useThing(88.5, 53.5, 88.2, 52.0);
  await waitScene(/scissor/);
  check('stepping into the rift leads to the Cutting Room', /scissor/.test(await scene()), `${said.slice(0, 2).join(' | ').slice(0, 100)} -> ${await scene()}`);

  // ---- the Cutting Room
  const boss = () => page.evaluate(() => { const e = window.__play.sim.world.withTag('scissor')[0]; return e ? { x: e.get('transform').x, y: e.get('transform').y, hp: e.get('state:health')?.hp } : null; });
  const overlays = () => page.evaluate(() => { const o = {}; for (const e of window.__play.sim.world.withTag('scell')) { const s = e.get('sprite'); if (s.visible) o[`${Math.floor(e.get('transform').x)},${Math.floor(e.get('transform').y)}`] = s.asset; } return o; });
  await placeAt(12.5, 12.8);
  await page.waitForTimeout(800);
  const intro = await readAll();
  v = await vars();
  check('walking up the room starts the fight with his words', v.boss_name === 'The Scissor-Man' && intro.length > 0, `${intro.length} lines; boss_name ${v.boss_name}`);
  // a line is marked, then cut
  let marked = {};
  for (let i = 0; i < 60 && Object.keys(marked).length === 0; i++) { await page.waitForTimeout(250); marked = await overlays(); }
  await shotAs('end_cut_line.png');
  check('he marks a line to cut', Object.keys(marked).length >= 10, `${Object.keys(marked).length} cells marked`);
  // the first line is not patched: it is cut, and she stays out of it
  await placeAt(12.5, 15.2);
  await page.waitForTimeout(5000);
  const cut = await overlays();
  check('an unpatched line is cut away (holes in the paper)', Object.values(cut).some((a) => a === 'fx_hole'), `${Object.keys(cut).length} covers, assets ${[...new Set(Object.values(cut))].join(',')}`);
  let clips = await tagged('clipping');
  check('he leaves clippings behind', clips.length >= 3, `${clips.length} clippings`);
  // a strike while he is not jammed does nothing
  const b0 = await boss();
  await placeAt(b0.x + 0.9, b0.y + 0.2);
  await face(b0.x, b0.y);
  await press('KeyJ', 80); await press('KeyJ', 80);
  await page.waitForTimeout(500);
  const b1 = await boss();
  check('his blades turn the Quill aside while they are free', b1.hp === b0.hp, `hp ${b0.hp} -> ${b1.hp}`);
  // pick up a clipping with a strike
  clips = await tagged('clipping');
  const clip = clips[0];
  await placeAt(clip.x + 0.9, clip.y + 0.1);
  await face(clip.x, clip.y);
  await press('KeyJ', 80);
  await page.waitForTimeout(500);
  v = await vars();
  check('striking a clipping picks it up', Number(v.clip_held) === 1 && v.clip_text, `clip_held ${v.clip_held} (${v.clip_text})`);
  await shotAs('end_clipboard.png');
  // wait for the next marked line, paste on it, and he jams
  let line2 = {};
  for (let i = 0; i < 160; i++) { await page.waitForTimeout(250); const o = await overlays(); const w = Object.entries(o).filter(([, a]) => /warn/.test(a)); if (w.length >= 8) { line2 = Object.fromEntries(w); break; } }
  const cells2 = Object.keys(line2).map((k) => k.split(',').map(Number));
  check('he marks a second line', cells2.length >= 8, `${cells2.length} cells`);
  if (cells2.length) {
    const t = cells2[Math.floor(cells2.length / 2)];
    // facing 6 is up the screen: grid (-1, -1); the paste lands 2.7 cells ahead of her
    await placeAt(t[0] + 0.5 + 1.9, t[1] + 0.5 + 1.9);
    await page.evaluate(() => { window.__play.sim.world.withTag('player')[0].get('transform').facing = 6; });
    await page.waitForTimeout(250);
    await press('KeyV', 80);
    await page.waitForTimeout(400);
    v = await vars();
    check('V pastes the clipping on the line', Number(v.clip_held) === 0, `clip_held ${v.clip_held}`);
    await shotAs('end_patch.png');
    await placeAt(12.5, 15.2);
    let jammed = false;
    for (let i = 0; i < 40 && !jammed; i++) { await page.waitForTimeout(250); jammed = (await msgs()).some((m) => /caught in the patch/i.test(m)); }
    check('a patch on his line jams his shears', jammed, '');
    // hurt him while he is jammed (he is still sliding to the end of his line for the first moment)
    await page.waitForTimeout(1000);
    const b2 = await boss();
    await placeAt(b2.x + 0.9, b2.y + 0.2);
    await face(b2.x, b2.y);
    await press('KeyJ', 80); await press('KeyJ', 80); await press('KeyJ', 80);
    await page.waitForTimeout(500);
    const b3 = await boss();
    check('a jammed Scissor-Man can be hurt', b3.hp < b2.hp, `hp ${b2.hp} -> ${b3.hp}`);
    await shotAs('end_jammed.png');
    // finish him (a test shortcut: his last ink) while the shears are still stuck
    await page.evaluate(() => { const e = window.__play.sim.world.withTag('scissor')[0]; const h = e.get('state:health'); h.hp = 0; });
  }
  const outro = [];
  for (let i = 0; i < 60 && !/overworld/.test(await scene()); i++) { await page.waitForTimeout(500); outro.push(...(await readAll())); }
  await page.waitForTimeout(1500);
  v = await vars();
  check('beaten, he is told what he is; she gets the Thimble, 60 Mnemosynth and 40 renown', Number(v.scissor_done) === 1 && Number(v['item:thimble']) >= 1 && outro.length > 0, `scissor_done ${v.scissor_done}, thimble ${v['item:thimble']}, ${outro.length} lines, M ${v.mnemosynth} R ${v.renown}`);
  check('she is back in the square', /overworld/.test(await scene()), `${await scene()} at ${JSON.stringify(await where())}`);

  // ---- publishing the town
  for (let i = 0; i < 40 && !Number((await vars()).town_published); i++) await page.waitForTimeout(500);
  v = await vars();
  check('the town is published: restored_town and town_published', Number(v.restored_town) === 1 && Number(v.town_published) === 1 && (await msgs()).some((m) => /Prologue is written/i.test(m)), `town_published ${v.town_published}`);
  rift = (await tagged('rift'))[0];
  check('the rift is gone', rift && !rift.visible, JSON.stringify(rift));

  // ---- the Margin Gate
  await setV({ renown: 100 });
  let g = await useThing(125.5, 53.5, 124.5, 53.5);
  check('with too little renown the gate stays shut and says how much', g.some((l) => /220/.test(l)) && !(await stack()).includes('End of the Prologue'), g.join(' | ').slice(0, 140));
  await setV({ renown: 300 });
  g = await useThing(125.5, 53.5, 124.5, 53.5);
  await page.waitForTimeout(2600);
  await shotAs('end_card.png');
  check('with 220 renown the gate opens and the end card of the Prologue shows', /End of the Prologue/.test(await stack()) && g.length > 0, `${await stack()} | ${g.join(' | ').slice(0, 100)}`);
  await clickText('Return to the title');
  await page.waitForTimeout(1800);
  check('"Return to the title" shows the title, with Continue', /Title/.test(await stack()) && (await clickText('Continue')), await stack());
  await page.waitForTimeout(3000);
  v = await vars();
  check('Continue brings back the finished Prologue', Number(v.town_published) === 1 && Number(v.prologue_complete) === 1 && Number(v.scissor_done) === 1, `town ${v.town_published}, complete ${v.prologue_complete}`);
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
