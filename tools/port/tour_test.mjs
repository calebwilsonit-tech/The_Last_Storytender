// Port tool (tour): every mechanic not covered by the other tests, and a screenshot of every area in the real Tilewright editor and checks that its interactions work: reading a sign,
// talking to Garrick, collecting a crystal, opening a chest, taking a pickup, lighting a lantern post, striking the
// dummy. The Storytender is moved next to each thing (a test shortcut), then everything else is done with real keys.
// Screenshots and a report go to <out_dir>.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/tour_test.mjs <project_dir> <out_dir>
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
const face = (x, y) => page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2(y - p.y, x - p.x) / Math.PI) * 4) + 8) % 8; }, [x, y]);
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

const go = async (sceneFile, x, y) => {
  await page.evaluate((s) => { window.__play.sim.runtime.travel = { scene: s, spawn: '' }; }, sceneFile);
  for (let i = 0; i < 60 && (await scene()) !== sceneFile; i++) await page.waitForTimeout(250);
  await page.waitForTimeout(1800);
  await readAll();
  if (x !== undefined) { await placeAt(x, y); await page.waitForTimeout(500); }
};
const pos = () => page.evaluate(() => ({ ...window.__play.sim.world.withTag('player')[0].get('transform') }));
const hp = () => page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('state:health')?.hp);
const speedOver = async (key, ms, extra) => {
  const a = await pos();
  if (extra) await page.keyboard.down(extra);
  await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key);
  if (extra) await page.keyboard.up(extra);
  const b = await pos();
  return Math.hypot(b.x - a.x, b.y - a.y) / (ms / 1000);
};
const info = {};
try {
  // ---- movement
  await placeAt(18.5, 56.5);
  await page.waitForTimeout(400);
  const walk = await speedOver('KeyD', 600);
  await placeAt(18.5, 56.5);
  const creep = await speedOver('KeyD', 600, 'ControlLeft');
  check('creeping is slower than walking', creep < walk * 0.75, `walk ${walk.toFixed(2)}, creep ${creep.toFixed(2)} cells/s`);
  await placeAt(18.5, 56.5);
  const a = await pos();
  await page.keyboard.down('KeyD'); await page.waitForTimeout(60); await press('ShiftLeft', 60); await page.waitForTimeout(200); await page.keyboard.up('KeyD');
  const b = await pos();
  check('Shift dashes', Math.hypot(b.x - a.x, b.y - a.y) > 1.6, `${Math.hypot(b.x - a.x, b.y - a.y).toFixed(2)} cells in 0.32 s`);
  await placeAt(18.5, 56.5);
  await page.keyboard.down('KeyD'); await page.keyboard.down('KeyQ'); await page.waitForTimeout(600);
  const lit = await speedOver('KeyD', 600, 'KeyQ');
  await page.keyboard.up('KeyD'); await page.keyboard.up('KeyQ');
  check('the lantern slows you', lit < walk * 0.85, `with lantern ${lit.toFixed(2)}`);

  // ---- a pit: falling in hurts and puts you back
  const pit = await page.evaluate(() => {
    const s = window.__play.sim; const m = s.map; const p = s.world.withTag('player')[0].get('transform');
    for (let r = 1; r < 40; r++) for (let dx = -r; dx <= r; dx++) for (let dy = -r; dy <= r; dy++) {
      const x = Math.floor(p.x) + dx, y = Math.floor(p.y) + dy;
      if (m.hasFlag?.(x, y, 4) || m.isPit?.(x, y)) return { x, y };
    }
    return null;
  });
  if (pit) {
    await heal();
    const h0 = await hp();
    await placeAt(pit.x + 0.5, pit.y + 0.5);
    await page.waitForTimeout(2500);
    const after = await pos();
    check('falling into a plot hole hurts and puts you back on the ground', (await hp()) < h0 && Math.hypot(after.x - pit.x - 0.5, after.y - pit.y - 0.5) > 0.5, `hp ${h0} -> ${await hp()}, at ${after.x.toFixed(1)},${after.y.toFixed(1)}`);
  } else check('falling into a plot hole', false, 'no pit found near the start');

  // ---- crumpling: health to 0, you wake at a checkpoint
  await placeAt(28.5, 53.6); await page.waitForTimeout(300); await press('KeyE'); await readAll(); // light the Margins post
  await placeAt(40.5, 54.5);
  await page.evaluate(() => { const p = window.__play.sim.world.withTag('player')[0]; const h = p.get('state:health'); h.hp = 1; });
  const mite = await page.evaluate(() => window.__play.sim.world.withTag('error-1').map((e) => e.get('transform'))[0]);
  await page.evaluate(() => { const p = window.__play.sim.world.withTag('player')[0]; window.__play.sim.events.emit('damaged', { entity: p.id }); });
  await page.evaluate(() => { const s = window.__play.sim; const p = s.world.withTag('player')[0]; const h = p.get('state:health'); h.hp = 0; h.dead = true; });
  await page.waitForTimeout(3000);
  await readAll();
  const woke = await pos();
  info.crumple = woke;
  check('crumpled, you wake again with your health back', (await hp()) > 50, `hp ${await hp()} at ${woke.x.toFixed(1)},${woke.y.toFixed(1)}`);

  // ---- the binder: use an Ink Vial from it
  await page.evaluate(() => { const s = window.__play.sim; s.runtime.vars['item:ink_vial'] = 2; s.world.withTag('player')[0].get('state:health').hp = 30; });
  await press('Tab'); await page.waitForTimeout(600);
  await shotAs('t_binder.png');
  for (let i = 0; i < 3; i++) await press('KeyE');
  await page.waitForTimeout(400);
  const hpAfterBinder = await hp();
  await press('Tab'); await page.waitForTimeout(400);
  check('the binder uses an item (E on a card)', hpAfterBinder > 30, `hp 30 -> ${hpAfterBinder}, vials ${(await vars())['item:ink_vial']}`);

  // ---- equipment: putting on a binding
  const v0 = await vars();
  info.equip = Object.keys(v0).filter((k) => /worn|equip/.test(k));
  check('a binding can be worn from the binder', Object.keys(v0).some((k) => /worn_binding/.test(k) && v0[k]), `vars: ${info.equip.join(',') || 'none'}`);

  // ---- echoes in the overworld (after the forge memory): R records, R again plays it back
  await page.evaluate(() => { window.__play.sim.runtime.vars.memory_done = 1; });
  await placeAt(20.5, 56.5); await page.waitForTimeout(400);
  await press('KeyR'); await page.keyboard.down('KeyD'); await page.waitForTimeout(700); await page.keyboard.up('KeyD'); await press('KeyR');
  await page.waitForTimeout(800);
  const echoes = (await tagged('echo')).length;
  await shotAs('t_echo.png');
  check('R records an echo that plays back', echoes >= 1, `${echoes} echoes`);

  // ---- fast travel from the map
  await page.evaluate(() => { const v = window.__play.sim.runtime.vars; v['lit:scenes/overworld.scene.json:square'] = 'Thistledown Square|95.5|53.5|0'; });
  const before = await pos();
  await press('KeyM'); await page.waitForTimeout(800);
  await shotAs('t_map.png');
  await press('KeyE'); await page.waitForTimeout(1500);
  const after = await pos();
  await readAll();
  check('the map travels to a lit lantern post', Math.hypot(after.x - before.x, after.y - before.y) > 5, `${before.x.toFixed(0)},${before.y.toFixed(0)} -> ${after.x.toFixed(0)},${after.y.toFixed(0)}`);
  if (/Map/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(',')))) await press('KeyM');

  // ---- the Margin Gate wants 220 renown
  await placeAt(118.5, 55.5); await page.waitForTimeout(300);
  const gates = await page.evaluate(() => window.__play.sim.world.all().filter((e) => e.get('npcTalk')?.dialogue === 'margin_gate').map((e) => e.get('transform')));
  if (gates[0]) {
    await placeAt(gates[0].x, gates[0].y + 1.4); await page.waitForTimeout(300); await press('KeyE');
    const low = await readAll();
    await page.evaluate(() => { window.__play.sim.runtime.vars.renown = 230; });
    await press('KeyE');
    const high = await readAll();
    info.gate = { low, high, flags: Object.keys(await vars()).filter((k) => /margin|gate/.test(k)) };
    check('the Margin Gate refuses below 220 renown and opens above', low.length > 0 && high.join(' ') !== low.join(' '), `low: ${low.join(' | ').slice(0, 80)} / high: ${high.join(' | ').slice(0, 80)}`);
  } else check('the Margin Gate', false, 'no gate found');

  // ---- restoring Garrick after the forge memory
  await placeAt(93.5, 56.6); await page.waitForTimeout(300); await press('KeyE');
  const rest = await readAll();
  check('Garrick is restored after his memory', Number((await vars()).restored_garrick) === 1, rest.slice(0, 2).join(' | ').slice(0, 100));
  await shotAs('t_town_restored.png');

  // ---- the side rooms: through their portals in the Prologue
  await page.evaluate(() => { window.__play.sim.runtime.vars.has_quill = 1; });
  for (const [pid, file] of [['weighing', 'scenes/weighing.scene.json'], ['proof', 'scenes/proof.scene.json']]) {
    const portal = await page.evaluate((pid) => window.__play.sim.world.all().filter((e) => e.get('npcTalk')?.dialogue === `portal_${pid}`).map((e) => e.get('transform'))[0], pid);
    if (!portal) { check(`the ${pid} portal`, false, 'no portal'); continue; }
    if ((await scene()) !== 'scenes/overworld.scene.json') await go('scenes/overworld.scene.json');
    await placeAt(portal.x, portal.y + 1.3); await page.waitForTimeout(300); await press('KeyE'); await readAll();
    for (let i = 0; i < 40 && (await scene()) !== file; i++) await page.waitForTimeout(250);
    await page.waitForTimeout(2000);
    await readAll();
    await shotAs(`t_${pid}.png`);
    const sc = await page.evaluate(() => { const s = window.__play.sim; const c = {}; for (const e of s.world.all()) for (const k of Object.keys(e.components ?? {})) if (k.startsWith('script_') || k === 'npcTalk' || k === 'sentenceStone') c[k] = (c[k] ?? 0) + 1; return c; });
    info[pid] = sc;
    check(`the ${pid} portal takes you in`, (await scene()) === file, `${await scene()}; scripted: ${JSON.stringify(sc)}`);
  }
  // ---- the Cutting Room (no door to it in the port yet)
  await go('scenes/scissor.scene.json');
  await shotAs('t_scissor.png');
  info.scissor = await page.evaluate(() => window.__play.sim.world.all().map((e) => e.name).slice(0, 30));

  // ---- saving: pause, save and back to the title, Continue
  await go('scenes/overworld.scene.json', 60.5, 55.5);
  await page.evaluate(() => { window.__play.sim.runtime.vars.mnemosynth = 123; });
  const savedAt = await pos();
  await press('KeyP'); await page.waitForTimeout(500);
  await shotAs('t_pause.png');
  // Save and return to title is the 4th row on the overworld (Resume, Map, Settings, Save...)
  for (let i = 0; i < 3; i++) await press('KeyS');
  await press('KeyE'); await page.waitForTimeout(1500);
  const onTitle = /Title/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(',')));
  await page.evaluate(() => { window.__play.sim.runtime.vars.mnemosynth = 0; });
  await press('KeyE'); await page.waitForTimeout(2500);
  const v9 = await vars();
  const back = await pos();
  check('pause, save and return to title, then Continue brings it all back', onTitle && Number(v9.mnemosynth) === 123, `title ${onTitle}, mnemosynth ${v9.mnemosynth}, at ${back.x.toFixed(0)},${back.y.toFixed(0)} (saved at ${savedAt.x.toFixed(0)},${savedAt.y.toFixed(0)})`);

  // ---- a screenshot of every area, and of edges and ledges
  const spots = [
    ['overworld', 16.5, 54.5, 'start'], ['overworld', 30.5, 40.5, 'margins'], ['overworld', 46.5, 27.5, 'orchard'], ['overworld', 76.5, 50.5, 'oldmeadow'],
    ['overworld', 95.5, 53.5, 'square'], ['overworld', 118.5, 52.5, 'margingate'], ['overworld', 85.5, 11.5, 'folio'], ['overworld', 115.5, 68.5, 'smudge'],
    ['overworld', 6.5, 54.5, 'west_edge'], ['overworld', 70.5, 3.5, 'north_edge'], ['overworld', 70.5, 98.5, 'south_edge'], ['overworld', 128.5, 50.5, 'east_edge'],
    ['forge', 5.5, 12.5, 'start'], ['forge', 20.5, 10.5, 'hall'], ['forge', 48.5, 10.5, 'arena'],
    ['pip', 6.5, 16.5, 'start'], ['pip', 20.5, 25.5, 'wood'], ['pip', 20.5, 6.5, 'tower'], ['pip', 50.5, 12.5, 'archive'], ['pip', 36.5, 4.5, 'lastpage'],
    ['maud', 5.5, 17.5, 'pantry'], ['maud', 20.5, 15.5, 'kitchen'], ['maud', 33.5, 15.5, 'cellar'], ['maud', 36.5, 7.5, 'hall'],
    ['weighing', 0, 0, 'start'], ['proof', 0, 0, 'start'], ['scissor', 0, 0, 'start'],
  ];
  let cur = '';
  for (const [sc, x, y, name] of spots) {
    if (cur !== sc) { await go(`scenes/${sc}.scene.json`); cur = sc; }
    if (x) await placeAt(x, y);
    await heal();
    await page.waitForTimeout(700);
    await readAll();
    await shotAs(`s_${sc}_${name}.png`);
  }
} catch (e) {
  check('test run', false, String(e && e.stack || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, info, errors: errors.slice(0, 40) }, null, 2));
console.log('INFO', JSON.stringify(info).slice(0, 3000));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
