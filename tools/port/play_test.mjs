// Port tool: plays the ported game in the real Tilewright editor and checks that its interactions work: reading a sign,
// talking to Garrick, collecting a crystal, opening a chest, taking a pickup, lighting a lantern post, striking the
// dummy. The Storytender is moved next to each thing (a test shortcut), then everything else is done with real keys.
// Screenshots and a report go to <out_dir>.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/play_test.mjs <project_dir> <out_dir>
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
const dialogue = () => page.evaluate(() => window.__play.sim.runtime.dialogue?.view ?? null);
/** Put the Storytender at a cell (test shortcut), on the ground there. */
const placeAt = (x, y) =>
  page.evaluate(([x, y]) => {
    const s = window.__play.sim;
    const p = s.world.withTag('player')[0];
    const t = p.get('transform');
    t.x = x;
    t.y = y;
    t.h = s.map.getHeight(Math.floor(x), Math.floor(y));
    const b = p.get('body');
    if (b) { b.vx = 0; b.vy = 0; b.vz = 0; }
  }, [x, y]);
/** Entities with a tag, with their positions. */
const tagged = (tag) => page.evaluate((tag) => window.__play.sim.world.withTag(tag).map((e) => ({ id: e.id, name: e.name, ...e.get('transform') })), tag);
const press = async (key, ms = 90) => {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
  await page.waitForTimeout(160);
};
/** Read a conversation to its end with the Interact key; returns every line shown. */
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

try {
  // 1. the tutorial sign beside the start (19,53)
  await placeAt(18.5, 54.5);
  await page.waitForTimeout(600);
  await press('KeyE');
  await page.waitForTimeout(500);
  await shotAs('1_sign.png');
  const sign = await readAll();
  check('read the tutorial sign', sign.some((l) => /walk/.test(l)), sign.join(' | ').slice(0, 160));

  // 2. a Mnemosynth crystal: walk into it
  const crystals = await tagged('prop-3');
  const before = await vars();
  const c0 = crystals.sort((a, b) => Math.hypot(a.x - 16.5, a.y - 54.5) - Math.hypot(b.x - 16.5, b.y - 54.5))[0];
  await placeAt(c0.x - 1.2, c0.y);
  await page.waitForTimeout(300);
  await page.keyboard.down('KeyD');
  await page.keyboard.down('KeyS');
  await page.waitForTimeout(450);
  await page.keyboard.up('KeyD');
  await page.keyboard.up('KeyS');
  await page.waitForTimeout(400);
  const afterC = await vars();
  check('collect a crystal', Number(afterC.mnemosynth ?? 0) > Number(before.mnemosynth ?? 0), `mnemosynth ${before.mnemosynth} -> ${afterC.mnemosynth}`);

  // 3. talk to Garrick (93,55): the placeholder speaks Lorem ipsum and remembers meeting you
  await placeAt(93.5, 56.6);
  await page.waitForTimeout(600);
  await press('KeyE');
  await page.waitForTimeout(500);
  await shotAs('3_garrick.png');
  const g = await readAll();
  const v3 = await vars();
  check('talk to Garrick', g.length > 0 && Number(v3.met_garrick) === 1, g.join(' | ').slice(0, 160));

  // 4. a chest that is not guarded: (21,44) holds two ink vials
  await placeAt(21.5, 45.6);
  await page.waitForTimeout(600);
  await press('KeyE');
  await page.waitForTimeout(500);
  await shotAs('4_chest.png');
  const ch = await readAll();
  const v4 = await vars();
  check('open a chest', Number(v4['item:ink_vial'] ?? 0) === 2 && Number(v4.got_chest_21_44) === 1, ch.join(' | ').slice(0, 160));

  // 5. a one-time pickup (the nearest "Take" thing)
  const picks = await tagged('prop-10');
  if (picks.length) {
    // the pickup with no other talking thing near it, so Interact can only mean it
    const talkers = await page.evaluate(() => window.__play.sim.world.all().filter((e) => e.get('npcTalk')).map((e) => ({ id: e.id, ...e.get('transform') })));
    const lonely = (p) => Math.min(...talkers.filter((t) => t.id !== p.id).map((t) => Math.hypot(t.x - p.x, t.y - p.y)));
    const p0 = [...picks].sort((a, b) => lonely(b) - lonely(a))[0];
    await placeAt(p0.x, p0.y + 1.1);
    await page.waitForTimeout(600);
    await press('KeyE');
    await page.waitForTimeout(500);
    const pk = await readAll();
    await page.waitForTimeout(400);
    const left = await tagged('prop-10');
    check('take a pickup', left.length === picks.length - 1, pk.join(' | ').slice(0, 160));
  } else check('take a pickup', false, 'no pickup in the scene');

  // 6. light the Margins lantern post (28,52)
  await placeAt(28.5, 53.6);
  await page.waitForTimeout(600);
  await press('KeyE');
  await page.waitForTimeout(800);
  await shotAs('6_post.png');
  const v6 = await vars();
  check('light a lantern post', Object.keys(v6).some((k) => k.startsWith('lit:')), Object.keys(v6).filter((k) => k.startsWith('lit:')).join(','));
  await readAll();
  // resting at a post opens the Index (Revise Your Draft) a moment later: leave it
  await page.waitForTimeout(2500);
  const idxOpen = /Revise/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(',')));
  const leave = await page.evaluate(() => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === 'Leave the Index').find((n) => n.getBoundingClientRect().width > 0); const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; });
  if (leave) await page.mouse.click(leave.x, leave.y);
  await page.waitForTimeout(600);
  check('lighting the post opens the Index, which can be left', idxOpen && !/Revise/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','))), `open ${idxOpen}`);

  // 7. strike the training dummy (93,58) with the quill (J)
  await placeAt(93.5, 59.3);
  await page.waitForTimeout(400);
  // W and D together walk straight along -y (the view is isometric), which is where the dummy stands
  await page.keyboard.down('KeyW'); await page.keyboard.down('KeyD'); await page.waitForTimeout(120); await page.keyboard.up('KeyD'); await page.keyboard.up('KeyW'); await page.waitForTimeout(160);
  const hits0 = await page.evaluate(() => window.__play.sim.world.withTag('dummy')[0]?.get('state:health')?.hp ?? null);
  for (let i = 0; i < 3; i++) await press('KeyJ', 80);
  await page.waitForTimeout(500);
  const hits1 = await page.evaluate(() => window.__play.sim.world.withTag('dummy')[0]?.get('state:health')?.hp ?? null);
  await shotAs('7_dummy.png');
  check('strike the dummy', hits0 !== null && hits1 !== null && hits1 < hits0, `dummy hp ${hits0} -> ${hits1}`);

  // 8. the lantern: holding Q burns fuel
  const l0 = Number((await vars()).light ?? 100);
  await page.keyboard.down('KeyQ');
  await page.waitForTimeout(1200);
  await shotAs('8_lantern.png');
  await page.keyboard.up('KeyQ');
  const l1 = Number((await vars()).light ?? 100);
  check('hold the lantern', l1 < l0, `light ${l0.toFixed(1)} -> ${l1.toFixed(1)}`);
  // 8b. the chest opened in 4 looks open, the post lit in 6 looks lit
  const assetNear = (x, y) => page.evaluate(([x, y]) => { let best = null, d = 1e9; for (const e of window.__play.sim.world.all()) { const t = e.get('transform'); const a = e.get('sprite')?.asset ?? ''; if (!t || !String(a).startsWith('obj_')) continue; const k = Math.hypot(t.x - x, t.y - y); if (k < d) { d = k; best = a; } } return best; }, [x, y]);
  check('the opened chest looks open', (await assetNear(21.5, 44.5)) === 'obj_chest_open', await assetNear(21.5, 44.5));
  check('the lit lantern post looks lit', (await assetNear(28.5, 52.5)) === 'obj_post_lit', await assetNear(28.5, 52.5));

  // 9. Garrick is a graphite placeholder until he is restored, then in colour
  const look = () => page.evaluate(() => window.__play.sim.world.withTag('garrick')[0]?.get('sprite')?.asset);
  const lookBefore = await look();
  await placeAt(93.5, 57.2);
  await page.evaluate(() => { window.__play.sim.runtime.vars.restored_garrick = 1; });
  await page.waitForTimeout(500);
  await shotAs('9_garrick_restored.png');
  const lookAfter = await look();
  check("Garrick turns from placeholder to colour when restored", /ghost/.test(lookBefore) && lookAfter === "npc_garrick", `${lookBefore} -> ${lookAfter}`);
  check('title screen started the game', !/Title/.test(await stack()), await stack());
} catch (e) {
  check('test run', false, String(e && e.stack || e).slice(0, 400));
}
const problems = await page.evaluate(() => [...document.querySelectorAll('[data-testid=problem-text], .problem-text')].map((n) => n.textContent).slice(0, 20)).catch(() => []);
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40), problems }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
