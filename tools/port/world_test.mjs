// Port tool: the rest of the overworld rules (C-05): discovering regions, introductions of new Errors, the new kinds acting, and the dungeon pause items.
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/world_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
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
  // ---- discovering a region: +10 Mnemosynth, +6 renown, a toast (not for the start, m / s / o)
  const regions = await page.evaluate(() => { const st = window.__play.sim.world.withTag('player')[0].get('script_Storytender'); return { rows: String(st.regions).split('|'), names: JSON.parse(st.regionNames) }; });
  const spot = (letter) => { for (let y = 0; y < regions.rows.length; y++) { const x = regions.rows[y].indexOf(letter); if (x >= 0) return [x + 0.5, y + 0.5]; } return null; };
  const letters = Object.keys(regions.names).filter((l) => !['m', 's', 'o', 't'].includes(l) && spot(l));
  const L = letters[0];
  const [sx, sy] = spot(L);
  await setV({ mnemosynth: 0, renown: 0 });
  await placeAt(sx, sy);
  await page.waitForTimeout(1200);
  v = await vars();
  check('first visit to a region: +10 Mnemosynth, +6 renown and "Discovered"', Number(v.mnemosynth) === 10 && Number(v.renown) === 6 && (await msgs()).some((m) => /Discovered: /.test(m)), `${regions.names[L]}: M ${v.mnemosynth}, R ${v.renown}, ${(await msgs()).slice(-1)}`);
  await placeAt(sx + 0.2, sy + 0.2);
  await page.waitForTimeout(500);
  await placeAt(sx, sy);
  await page.waitForTimeout(800);
  v = await vars();
  check('a second visit pays nothing', Number(v.mnemosynth) === 10 && Number(v.renown) === 6, `M ${v.mnemosynth}, R ${v.renown}`);

  // ---- the first of each new kind introduces itself
  await setV({ restored_pip: 1, restored_maud: 1 });
  await page.waitForTimeout(500);
  const kinds = [2, 3, 4, 5];
  const found = {};
  for (const k of kinds) {
    const list = (await tagged(`error-${k}`)).filter((e) => e.visible);
    found[k] = list[0];
  }
  console.log('kinds out', JSON.stringify(Object.fromEntries(Object.entries(found).map(([k, e]) => [k, e && [e.x.toFixed(0), e.y.toFixed(0)]]))));
  const intro = { 2: /Run-on drags itself/, 3: /Dangling Modifier/, 4: /Censor stands/, 5: /Three dots blink/ };
  for (const k of kinds) {
    if (!found[k]) { check(`a kind ${k} Error is out`, false, 'none visible'); continue; }
    await placeAt(found[k].x + 6, found[k].y + 6);
    await page.waitForTimeout(900);
    check(`the first kind ${k} Error says what it is`, (await msgs()).some((m) => intro[k].test(m)), (await msgs()).slice(-1)[0] ?? '');
  }

  // ---- the new kinds act: a Run-on chases and is proofread by the lantern, a Censor and an Ellipsis come for her
  const hp = async () => page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('state:health').hp);
  const pos = (id) => page.evaluate((id) => { const e = window.__play.sim.world.get(id); const t = e?.get('transform'); return t ? { x: t.x, y: t.y, hp: e.get('state:health')?.hp, friendly: e.hasTag?.('friendly') ?? e.tags.has('friendly') } : null; }, id);
  for (const k of [2, 4, 5]) {
    const e = found[k];
    if (!e) continue;
    await page.evaluate(() => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); h.hp = 100; h.dead = false; });
    await placeAt(e.x + 3.2, e.y);
    await page.waitForTimeout(300);
    const a = await pos(e.id);
    await page.waitForTimeout(3500);
    const b = await pos(e.id);
    const moved = Math.hypot(b.x - a.x, b.y - a.y);
    const px = await page.evaluate(() => { const t = window.__play.sim.world.withTag('player')[0].get('transform'); return [t.x, t.y]; });
    const near = Math.hypot(b.x - px[0], b.y - px[1]);
    check(`a kind ${k} Error wakes and comes at her`, moved > 0.6 || (await hp()) < 100, `moved ${moved.toFixed(1)}, now ${near.toFixed(1)} from her, ink ${await hp()}`);
  }
  // the lantern proofreads a Run-on
  const ro = found[2];
  if (ro) {
    await page.evaluate(() => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); h.hp = 100; });
    await setV({ has_quill: 1 });
    await placeAt(ro.x + 2.2, ro.y + 0.2);
    await page.waitForTimeout(300);
    let friendly = false;
    await page.keyboard.down('KeyQ');
    for (let i = 0; i < 40 && !friendly; i++) {
      await page.waitForTimeout(150);
      const cur = await pos(ro.id);
      await page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4) + 8) % 8; }, [cur.x, cur.y]);
      friendly = cur.friendly;
      if (Math.hypot(cur.x - (await page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('transform').x)), 0) > 3) await placeAt(cur.x + 2.0, cur.y);
    }
    await page.keyboard.up('KeyQ');
    check('the lantern proofreads a Run-on', friendly, '');
  }

  // ---- the pause menu of a memory offers Travel and Restart
  v = await vars();
  check('on the overworld the pause menu has no dungeon items', Number(v.dungeon_menu) === 0, `dungeon_menu ${v.dungeon_menu}`);
  await setV({ go_forge: 1, met_garrick: 1 });
  for (let i = 0; i < 60 && !/forge/.test(await page.evaluate(() => window.__play.sim.runtime.scene)); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(2500);
  await readAll();
  v = await vars();
  check('inside a memory it offers "Travel to a lantern" and "Restart this dungeon"', Number(v.dungeon_menu) === 1, `dungeon_menu ${v.dungeon_menu}`);
  await press('KeyP');
  await page.waitForTimeout(800);
  const items = await page.evaluate(() => [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && /Restart this dungeon|Travel to a lantern/.test(n.textContent ?? '') && n.getBoundingClientRect().width > 0).map((n) => n.textContent.trim()));
  check('both show on the pause screen', items.includes('Restart this dungeon') && items.includes('Travel to a lantern'), items.join(' | '));
  await shotAs('world_pause_dungeon.png');
  await press('KeyP');
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
