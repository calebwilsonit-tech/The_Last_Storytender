// Port tool: the Prologue story chain on the overworld with real keys (talk E, strike J, dash Shift, lantern Q, binder I, pause P). Memories are marked done (their own tests play them); the Storytender is moved next to each person.
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
const near = (list, x, y) => [...list].sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y))[0];
const setV = (o) => page.evaluate((o) => Object.assign(window.__play.sim.runtime.vars, o), o);
const pl = () => page.evaluate(() => { const p = window.__play.sim.world.withTag('player')[0]; const t = p.get('transform'); const h = p.get('state:health'); return { x: t.x, y: t.y, hp: h?.hp, dead: h?.dead, max: p.get('health')?.max }; });
const talkTo = async (x, y, fx, fy) => { await placeAt(x, y); await page.waitForTimeout(400); await face(fx, fy); await page.waitForTimeout(200); await press('KeyE'); await page.waitForTimeout(500); return readAll(); };
const say = (a) => a.join(' | ').replace(/\[\/?i\]/g, '').slice(0, 150);
const textOnScreen = () => page.evaluate(() => document.querySelector('[data-testid=viewport]')?.innerText ?? document.body.innerText);
try {
  await page.waitForTimeout(1500); await readAll();
  // 1. Garrick as a ghost
  const g1 = await talkTo(93.5, 56.6, 93.5, 55.5);
  check('Garrick, unrestored, talks in placeholder words', g1.length > 0 && Number((await vars()).met_garrick) === 1, say(g1));
  // 2. the forge memory done -> restoration
  await setV({ memory_done: 1, has_sword: 1 });
  const g2 = await talkTo(93.5, 56.6, 93.5, 55.5);
  await page.waitForTimeout(1500); await readAll();
  const v2 = await vars();
  check('with the First Sword Garrick is restored (+25 Mnemosynth, +35 renown)', Number(v2.restored_garrick) === 1, `M ${v2.mnemosynth} R ${v2.renown} | ${say(g2)}`);
  await shotAs('s1_garrick_restored.png');
  // 3. the lesson
  const g3 = await talkTo(93.5, 56.6, 93.5, 55.5);
  check('talking again gives the Quill and starts the lesson', Number((await vars()).has_quill) === 1, say(g3));
  const dummy = (await tagged('dummy'))[0];
  await placeAt(dummy.x, dummy.y + 1.0); await page.waitForTimeout(300); await face(dummy.x, dummy.y);
  const dhp = () => page.evaluate((id) => window.__play.sim.world.get(id)?.get('state:health')?.hp, dummy.id);
  for (let i = 0; i < 4; i++) { const a = await dhp(); await press('KeyJ'); await page.waitForTimeout(450); await readAll(); console.log('strike', i, 'dummy hp', a, '->', await dhp(), 'step', (await vars()).lesson_step); }
  await press('ShiftLeft'); await page.waitForTimeout(600); await readAll();
  await page.keyboard.down('KeyQ'); await page.waitForTimeout(1600); await page.keyboard.up('KeyQ');
  for (let i = 0; i < 8; i++) { await page.waitForTimeout(500); await readAll(); }
  const v3 = await vars();
  check('the lesson (3 strikes, a dash, the lantern) ends with its rewards', Number(v3.lesson_done) === 1 && Number(v3['item:hardcover_binding']) >= 1 && Number(v3['item:eraser_crumbs']) >= 2, `lesson_done ${v3.lesson_done} step ${v3.lesson_step} binding ${v3['item:hardcover_binding']} crumbs ${v3['item:eraser_crumbs']} M ${v3.mnemosynth}`);
  // 4. Pip
  const p1 = await talkTo(91.5, 53.6, 91.5, 52.5);
  check('Pip, before the memory', p1.length > 0, say(p1));
  const errs0 = (await tagged('enemy')).length;
  await setV({ pip_memory_done: 1 });
  const p2 = await talkTo(91.5, 53.6, 91.5, 52.5);
  await page.waitForTimeout(1500); await readAll();
  const v4 = await vars();
  check('after the memory Pip is restored (+30 M, +35 R)', Number(v4.restored_pip) === 1, `M ${v4.mnemosynth} R ${v4.renown} | ${say(p2)}`);
  await shotAs('s2_pip_restored.png');
  // 5. Maud
  const m1 = await talkTo(91.5, 59.6, 91.5, 58.5);
  check('Maud, before the memory', m1.length > 0, say(m1));
  await setV({ maud_memory_done: 1, format_mark: 1 });
  const m2 = await talkTo(91.5, 59.6, 91.5, 58.5);
  await page.waitForTimeout(1500); await readAll();
  const v5 = await vars();
  check('after the memory Maud is restored (+30 M, 3 warm loaves)', Number(v5.restored_maud) === 1 && Number(v5['item:warm_loaf']) >= 3, `loaves ${v5['item:warm_loaf']} M ${v5.mnemosynth} | ${say(m2)}`);
  await shotAs('s3_maud_restored.png');
  // 6. the rift after all three
  await placeAt(88.5, 55.5); await page.waitForTimeout(3000); await readAll();
  const rift = await page.evaluate(() => window.__play.sim.world.all().filter((e) => { const t = e.get('transform'); return t && Math.hypot(t.x - 88.5, t.y - 53.5) < 1.6 && e.get('sprite')?.visible !== false; }).map((e) => e.name));
  const r1 = await talkTo(88.2, 52.0, 88.5, 53.5);
  for (let i = 0; i < 40 && !/scissor/.test(await scene()); i++) await page.waitForTimeout(250);
  check('with all three restored the rift appears and leads to the Cutting Room', /scissor/.test(await scene()), `near (88,53): ${rift.join(', ')} | ${say(r1)}`);
  await shotAs('s4_rift.png');
  // the Cutting Room has its own test (scissor_test); here she is sent home as if the Scissor-Man were beaten
  await page.waitForTimeout(1500);
  await setV({ leave_scissor: 1, scissor_done: 1, town_published: 1 });
  for (let i = 0; i < 40 && !/overworld/.test(await scene()); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(1500);
  // 7. the Margin Gate
  await setV({ renown: 300 });
  const gate = await talkTo(124.5, 53.5, 125.5, 53.5);
  check('the Margin Gate opens for a published town with 220+ renown', /unties itself/i.test(say(gate)), say(gate));
  // the end card of the Prologue comes up a moment later: keep exploring
  await page.waitForTimeout(2600);
  const keep = await page.evaluate(() => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === 'Keep exploring').find((n) => n.getBoundingClientRect().width > 0); const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; });
  if (keep) await page.mouse.click(keep.x, keep.y);
  await page.waitForTimeout(800);
  // 8. the binder: use an Ink Vial
  await page.evaluate(() => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); h.hp = 40; });
  await setV({ 'item:ink_vial': 2 });
  await press('KeyI'); await page.waitForTimeout(1200);
  await shotAs('s5_binder.png');
  const st1 = await stack();
  const cards = await page.evaluate(() => [...document.querySelectorAll('*')].filter((n) => /Ink Vial/.test(n.textContent ?? '') && n.children.length < 4).map((n) => { const r = n.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width }; }).filter((r) => r.w > 20 && r.w < 200));
  let used = 'no card found';
  if (cards.length) { await page.mouse.click(cards[0].x, cards[0].y); await page.waitForTimeout(600); used = 'clicked'; }
  // the world waits while the binder is open, so the Storytender's script applies the item when it closes
  await press('KeyI'); await page.waitForTimeout(900);
  const hpB = (await pl()).hp;
  check('clicking an Ink Vial card in the binder heals (+45)', hpB >= 80, `stack ${st1}, ${used}, hp 40 -> ${hpB}, vials ${(await vars())['item:ink_vial']}`);
  // quick slot F
  await page.evaluate(() => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); h.hp = 30; });
  await setV({ 'item:warm_loaf': 3, 'slot:1': 'warm_loaf', quick_active: 0 });
  await press('KeyF'); await page.waitForTimeout(600);
  check('F uses the quick-slot item (Warm Loaf +60)', (await pl()).hp >= 85, `hp 30 -> ${(await pl()).hp}, loaves ${(await vars())['item:warm_loaf']}`);
  // eraser crumbs: thrown at a Mite does damage?
  await setV({ 'slot:1': 'eraser_crumbs' });
  const mite = near((await tagged('error-1')), 93, 56);
  if (mite) { await placeAt(mite.x + 2.8, mite.y + 2.8); await page.evaluate(() => { window.__play.sim.world.withTag('player')[0].get('transform').facing = 6; }); const hm0 = await page.evaluate((id) => window.__play.sim.world.get(id)?.get('state:health')?.hp, mite.id); await press('KeyF'); await page.waitForTimeout(1600); const hm1 = await page.evaluate((id) => window.__play.sim.world.get(id)?.get('state:health')?.hp ?? 'gone', mite.id); check('throwing Eraser Crumbs hurts an Error', hm1 === 'gone' || hm1 < hm0, `mite hp ${hm0} -> ${hm1}`); }
  // 9. crumpling to real hits
  const bare = near((await tagged('error-0')), 60, 55);
  await page.evaluate(() => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); h.hp = 4; });
  await setV({ mnemosynth: 100 });
  const before = await pl();
  await placeAt(bare.x + 1.3, bare.y); 
  let dead = false, minHp = 99;
  await page.evaluate(() => { window.__died = 0; window.__play.sim.events.on('died', (e) => { if (window.__play.sim.world.get(e.entity)?.tags.has('player')) window.__died++; }); });
  for (let i = 0; i < 60; i++) { await page.waitForTimeout(250); const p = await pl(); minHp = Math.min(minHp, p.hp); if (p.dead || p.hp <= 0 || (await page.evaluate(() => window.__died)) > 0) { dead = true; break; } }
  await shotAs('s6_crumple.png');
  await page.waitForTimeout(4000); await readAll();
  const after = await pl(); const v9 = await vars();
  check('beaten by an Error she crumples and wakes again with ink back', dead && after.hp > 10 && !after.dead, `died ${dead} (min hp ${minHp}), now hp ${after.hp} at ${after.x.toFixed(1)},${after.y.toFixed(1)}, M 100 -> ${v9.mnemosynth} (story mode keeps it)`);
  // 10. save, title, Continue (the buttons are found by their words and clicked)
  await setV({ mnemosynth: 123 });
  await placeAt(94.5, 57.5); await page.waitForTimeout(500);
  const clickText = async (t) => {
    const hit = await page.evaluate((t) => { const n = [...document.querySelectorAll('*')].filter((n) => (n.textContent ?? '').trim() === t && n.children.length === 0).map((n) => { const r = n.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; })[0]; return n ?? null; }, t);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  console.log('direct save ->', String(await page.evaluate(async () => { try { return await window.__play.session.saveTo('autosave'); } catch (e) { return 'threw ' + e; } })).slice(0, 900));
  await press('KeyP'); await page.waitForTimeout(800);
  const saved = await clickText('Save and return to title'); await page.waitForTimeout(2500);
  await shotAs('s7_title_after_save.png');
  await setV({ mnemosynth: 0 });
  const cont = await clickText('Continue'); await page.waitForTimeout(3500);
  const back = await pl(); const v10 = await vars();
  check('pause, "Save and return to title", then Continue brings the game back', saved && cont && Number(v10.mnemosynth) === 123, `clicked save ${saved}, Continue ${cont}; M ${v10.mnemosynth} at ${back.x.toFixed(1)},${back.y.toFixed(1)}; screen ${await stack()}`);
} catch (e) { check('test run', false, String(e && e.stack || e).slice(0, 400)); }
function log2(...a) { console.log(...a); }
console.log('errors', errors.length); for (const e of errors.slice(0, 8)) console.log('  ', e.slice(0, 250));
await app.close();
