// Port tool (combat): plays the ported game in the real Tilewright editor and checks that its interactions work: reading a sign,
// talking to Garrick, collecting a crystal, opening a chest, taking a pickup, lighting a lantern post, striking the
// dummy. The Storytender is moved next to each thing (a test shortcut), then everything else is done with real keys.
// Screenshots and a report go to <out_dir>.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/combat_test.mjs <project_dir> <out_dir>
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
const errors0 = [];
page.on('pageerror', (e) => errors0.push('pageerror: ' + e.message));
page.on('console', (m) => { if (m.type() === 'error') errors0.push('console: ' + m.text()); });
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
const placeAt = (x, y) =>
  page.evaluate(([x, y]) => {
    const s = window.__play.sim;
    const p = s.world.withTag('player')[0];
    const t = p.get('transform');
    t.x = x; t.y = y; t.h = s.map.getHeight(Math.floor(x), Math.floor(y));
    const b = p.get('body');
    if (b) { b.vx = 0; b.vy = 0; b.vz = 0; }
  }, [x, y]);
const errors = (tag) => page.evaluate((tag) => window.__play.sim.world.withTag(tag).map((e) => ({ id: e.id, x: e.get('transform').x, y: e.get('transform').y, hp: e.get('state:health')?.hp, visible: e.get('sprite')?.visible !== false, friendly: e.tags.has('friendly') })), tag);
const byId = (id) => page.evaluate((id) => { const e = window.__play.sim.world.all().find((x) => x.id === id); return e && e.get('sprite')?.visible !== false ? { hp: e.get('state:health')?.hp, friendly: e.tags.has('friendly'), x: e.get('transform').x, y: e.get('transform').y } : null; }, id);
const playerHp = () => page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('state:health')?.hp);
const heal = () => page.evaluate(() => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); if (h) h.hp = 100; });
/** Put the Storytender on the open ground beside an Error, on the side with walkable floor, facing it (a short step towards it). */
const besideFacing = async (e, gap) => {
  const dirs = [[-1, 0, 'KeyD'], [1, 0, 'KeyA'], [0, -1, 'KeyS'], [0, 1, 'KeyW']];
  for (const [dx, dy, key] of dirs) {
    // open floor on the Error's own level, all the way between the two
    const ok = await page.evaluate(([x, y, ex, ey]) => {
      const s = window.__play.sim;
      const h0 = s.map.getHeight(Math.floor(ex), Math.floor(ey));
      for (let k = 0; k <= 4; k++) {
        const fx = Math.floor(ex + (x - ex) * (k / 4)), fy = Math.floor(ey + (y - ey) * (k / 4));
        if (s.map.inBounds?.(fx, fy) === false || s.map.isBlocked?.(fx, fy) || s.map.getHeight(fx, fy) !== h0) return false;
      }
      return true;
    }, [e.x + dx * gap, e.y + dy * gap, e.x, e.y]);
    if (!ok) continue;
    await placeAt(e.x + dx * gap, e.y + dy * gap);
    await page.keyboard.down(key); await page.waitForTimeout(60); await page.keyboard.up(key);
    return key;
  }
  await placeAt(e.x - gap, e.y);
  return 'KeyD';
};
const press = async (key, ms = 90) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(160); };
const shotAs = (name) => page.screenshot({ path: path.join(outDir, name) });

try {
  await page.evaluate(() => { window.__play.sim.runtime.vars.has_quill = 1; });
  const bares = await errors('error-0');
  const mites = await errors('error-1');
  const danglers = await errors('error-3');
  // 12 Bares and 14 Mites roam; the arenas hold 6 more Bares and 5 more Mites (and Run-ons), hidden until their fight
  check('the Prologue has its Errors', bares.length === 18 && mites.length === 19 && danglers.length === 7, `bare ${bares.length}, mite ${mites.length}, dangler ${danglers.length}`);
  check('Danglers stay away until Pip is restored', danglers.every((d) => !d.visible), danglers.map((d) => d.visible).join(','));

  // 0. J swings the quill: the strike plays
  const anim = () => page.evaluate(() => { const a = window.__play.sim.world.withTag('player')[0].get('animator'); return a ? `${a.state}/${a.clip}` : 'none'; });
  await page.keyboard.down('KeyJ');
  const seen = [];
  for (let i = 0; i < 8; i++) { seen.push(await anim()); await page.waitForTimeout(25); }
  await page.keyboard.up('KeyJ');
  await page.waitForTimeout(400);
  seen.push(await anim());
  await page.keyboard.down('KeyD'); await page.waitForTimeout(350); const walking = await anim(); await page.keyboard.up('KeyD'); await page.waitForTimeout(300);
  check('walking plays the walk', walking.includes('walk'), walking);
  check('J plays the quill strike, then back to standing', seen.some((x) => x.includes('strike')) && !seen[seen.length - 1].includes('strike'), [...new Set(seen)].join(' '));

  // 1. a Bare notices you and lunges
  let hit = false;
  for (const b0 of bares.slice(2, 6)) {
    await heal();
    await besideFacing(b0, 2.4);
    for (let i = 0; i < 20 && !hit; i++) { await page.waitForTimeout(400); hit = (await playerHp()) < 100; }
    if (hit) break;
  }
  await shotAs('1_bare.png');
  check('a Bare notices and lunges', hit, `hp ${await playerHp()}`);

  // 2. the quill beats a Mite: renown and Mnemosynth
  const m0 = mites[0];
  const before = await vars();
  await heal();
  await besideFacing(m0, 0.9);
  let gone = false;
  for (let i = 0; i < 10 && !gone; i++) {
    const m = await byId(m0.id);
    if (!m) { gone = true; break; }
    await placeAt(m.x - 0.9, m.y);
    await press('KeyD', 40);
    await press('KeyJ', 80);
  }
  // it left a crystal: walk into it
  // it left a crystal (worth 5); standing where the Mite was, the Storytender may already have picked it up
  const crystals = await page.evaluate(() => window.__play.sim.world.withTag('dropped').map((e) => ({ x: e.get('transform').x, y: e.get('transform').y })));
  for (const c of crystals) { await placeAt(c.x, c.y); await page.waitForTimeout(300); }
  const gained = Number((await vars()).mnemosynth ?? 0) - Number(before.mnemosynth ?? 0);
  check('a beaten Mite drops a crystal worth 5', gained >= 5 && gained % 5 === 0, `gained ${gained} (a crystal lying nearby may be picked up too)`);
  // rest at the Margins lantern post (light it, then E again): the Mite comes back once you are away from its spot
  await placeAt(28.5, 53.6);
  await page.waitForTimeout(400);
  await press('KeyE');
  await page.waitForTimeout(500);
  for (let i = 0; i < 6 && (await page.evaluate(() => window.__play.sim.runtime.dialogue !== null && window.__play.sim.runtime.dialogue !== undefined)); i++) await press('KeyE');
  await press('KeyE');
  await page.waitForTimeout(300);
  let back = null;
  for (let i = 0; i < 10 && !back; i++) { await page.waitForTimeout(200); back = await byId(m0.id); }
  check('resting brings the Mite back', !!back, back ? `hp ${back.hp}` : 'still gone');
  // resting at a post opens the Index a moment later (the first time with its explanation): leave it
  await page.waitForTimeout(2200);
  const leave = await page.evaluate(() => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === 'Leave the Index').find((n) => n.getBoundingClientRect().width > 0); const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; });
  if (leave) await page.mouse.click(leave.x, leave.y);
  await page.waitForTimeout(500);
  const after = await vars();
  check('the quill beats a Mite', gone && Number(after.renown) > Number(before.renown ?? 0), `renown ${before.renown} -> ${after.renown}, mnemosynth ${before.mnemosynth} -> ${after.mnemosynth}`);

  // 3. the lantern proofreads a Bare
  const b1 = bares[1];
  await heal();
  const key = await besideFacing(b1, 2.0);
  await page.keyboard.down('KeyQ');
  let friend = false;
  for (let i = 0; i < 40 && !friend; i++) {
    await page.waitForTimeout(120);
    const b = await byId(b1.id);
    if (b) {
      await page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = Math.round(((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4 + 8)) % 8; }, [b.x, b.y]);
      friend = b.friendly;
    }
  }
  await shotAs('3_proofread.png');
  await page.keyboard.up('KeyQ');
  const lookNow = await page.evaluate((id) => window.__play.sim.world.all().find((x) => x.id === id)?.get('sprite')?.asset, b1.id);
  check('the lantern proofreads a Bare', friend, `key ${key}`);
  check('a proofread Bare looks friendly', lookNow === 'err_bare_friendly', lookNow);

  // 4. the lantern burns a Mite away
  const m1 = mites[1];
  await page.waitForTimeout(1500);
  await heal();
  await besideFacing(m1, 1.6);
  await page.keyboard.down('KeyQ');
  let burned = false;
  for (let i = 0; i < 10 && !burned; i++) {
    await page.waitForTimeout(300);
    const m = await byId(m1.id);
    if (!m) burned = true;
    else await page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = Math.round(((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4 + 8)) % 8; }, [m.x, m.y]);
  }
  await page.keyboard.up('KeyQ');
  check('the lantern burns a Mite away', burned);

  // 5. Pip restored: the Danglers come out
  await page.evaluate(() => { window.__play.sim.runtime.vars.restored_pip = 1; });
  await page.waitForTimeout(500);
  const d2 = await errors('error-3');
  check('Pip restored lets the Danglers out', d2.every((d) => d.visible), d2.map((d) => d.visible).join(','));
} catch (e) {
  check('test run', false, String(e && e.stack || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors0.slice(0, 40) }, null, 2));
console.log('errors', errors0.length);
for (const e of errors0.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
