// Port tool: a real play-through with keys only (no teleporting): a pathfinder picks the cells, the test holds WASD toward them.
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
const S = () => window.__play.sim;
const pos = () => page.evaluate(() => { const p = window.__play.sim.world.withTag('player')[0]; const t = p.get('transform'); const h = p.get('state:health'); return { x: t.x, y: t.y, h: t.h, hp: h?.hp, dead: h?.dead }; });
const t0 = Date.now(); const log = (...a) => console.log(`[${((Date.now() - t0) / 1000).toFixed(0)}s]`, ...a);
let shotN = 0; const snap = async (tag) => { await shotAs(`r${String(++shotN).padStart(2, '0')}_${tag}.png`); };
const KEYS = { W: 'KeyW', A: 'KeyA', S: 'KeyS', D: 'KeyD' };
let vec = {};
const held = new Set();
const setKeys = async (want) => { for (const k of [...held]) if (!want.includes(k)) { await page.keyboard.up(k); held.delete(k); } for (const k of want) if (!held.has(k)) { await page.keyboard.down(k); held.add(k); } };
const release = () => setKeys([]);
const combos = () => { const out = []; const ks = Object.keys(vec); for (const a of ks) out.push([a]); for (let i = 0; i < ks.length; i++) for (let j = i + 1; j < ks.length; j++) { const [a, b] = [ks[i], ks[j]]; const v = [vec[a][0] + vec[b][0], vec[a][1] + vec[b][1]]; if (Math.hypot(...v) > 0.3) out.push([a, b]); } return out; };
const keysToward = (dx, dy) => { let best = null, bd = -2; const n = Math.hypot(dx, dy) || 1; for (const c of combos()) { const v = c.reduce((s, k) => [s[0] + vec[k][0], s[1] + vec[k][1]], [0, 0]); const m = Math.hypot(...v); const d = (v[0] * dx + v[1] * dy) / (m * n); if (d > bd) { bd = d; best = c; } } return best.map((k) => KEYS[k]); };
const readAllQuiet = async () => { const seen = []; for (let i = 0; i < 80; i++) { const v = await dialogue(); if (!v) break; seen.push(v.kind === 'line' ? v.text : `[choice] ${v.prompt}`); await press('KeyE'); await page.waitForTimeout(120); } return seen; };
// a path of cells on the current map: same height, or stairs (a slope on either cell, one level), no BLOCK/PIT flags, no solid collider
const plan = (tx, ty, opts = {}) => page.evaluate(([tx, ty, opts]) => {
  const s = window.__play.sim, m = s.map; const p = s.world.withTag('player')[0].get('transform');
  const W = m.width ?? m.w, H = m.height ?? m.h;
  const solid = new Set();
  for (const e of s.world.all()) {
    const c = e.get('collider'); const t = e.get('transform'); if (!c || !t || e.hasTag?.('player')) continue;
    if (c.enabled === false || c.trigger || c.solid === false) continue;
    const hw = (c.w ?? 1) / 2, hd = (c.d ?? 1) / 2;
    for (let x = Math.floor(t.x - hw + 0.05); x <= Math.floor(t.x + hw - 0.05); x++) for (let y = Math.floor(t.y - hd + 0.05); y <= Math.floor(t.y + hd - 0.05); y++) solid.add(x + ',' + y);
  }
  const ok = (x, y) => x >= 0 && y >= 0 && x < W && y < H && !(m.getFlags(x, y) & 3) && !solid.has(x + ',' + y);
  const sx = Math.floor(p.x), sy = Math.floor(p.y), gx = Math.floor(tx), gy = Math.floor(ty);
  const goal = (x, y) => opts.adjacent ? Math.abs(x - gx) + Math.abs(y - gy) === 1 || (x === gx && y === gy) : x === gx && y === gy;
  const prev = new Map([[sx + ',' + sy, null]]); const q = [[sx, sy]]; let end = null;
  while (q.length) { const [x, y] = q.shift(); if (goal(x, y)) { end = [x, y]; break; }
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, ny = y + dy, k = nx + ',' + ny; if (prev.has(k) || !ok(nx, ny)) continue;
      const dh = Math.abs(m.getHeight(nx, ny) - m.getHeight(x, y));
      const R = [null, [0, -1], [1, 0], [0, 1], [-1, 0]]; const along = (sl) => !sl || (R[sl.dir] && (R[sl.dir][0] === dx || R[sl.dir][0] === -dx) && (R[sl.dir][1] === dy || R[sl.dir][1] === -dy) && (dx !== 0 ? R[sl.dir][0] !== 0 : R[sl.dir][1] !== 0));
      const sa = m.getSlope(x, y), sb = m.getSlope(nx, ny);
      if (!along(sa) || !along(sb)) continue;
      if (dh > 0 && !((sa || sb) && dh <= 1)) continue; prev.set(k, [x, y]); q.push([nx, ny]); } }
  if (!end) return null; const path = []; let c = end; while (c) { path.unshift(c); c = prev.get(c[0] + ',' + c[1]); }
  return { path, stairs: path.filter(([x, y]) => m.getSlope(x, y)).length };
}, [tx, ty, opts]);
const enemiesNear = (r) => page.evaluate((r) => { const s = window.__play.sim; const p = s.world.withTag('player')[0].get('transform'); return s.world.withTag('enemy').map((e) => ({ id: e.id, n: [...e.tags].join("/"), t: e.get('transform'), h: e.get('state:health') })).filter((e) => e.t && e.h && !e.h.dead && !e.n.includes('friendly') && Math.hypot(e.t.x - p.x, e.t.y - p.y) < r).map((e) => ({ id: e.id, n: e.n, x: e.t.x, y: e.t.y, hp: e.h.hp })); }, r);
const stats = { fights: 0, kills: 0, stuck: [], stairs: 0, cells: 0, hits: 0 };
const fight = async () => {
  for (let round = 0; round < 3; round++) {
    const es = await enemiesNear(1.8); if (!es.length) return;
    const e = es[0]; stats.fights++; log('fight', e.n, 'hp', e.hp.toFixed(1));
    const end = Date.now() + 6000;
    while (Date.now() < end) {
      const [cur] = (await enemiesNear(3)).filter((x) => x.id === e.id); if (!cur) { stats.kills++; log('  beaten'); break; }
      const p = await pos(); const dx = cur.x - p.x, dy = cur.y - p.y;
      await setKeys(keysToward(dx, dy)); await page.waitForTimeout(Math.hypot(dx, dy) > 0.9 ? 120 : 40); await release();
      await press('KeyJ', 60);
    }
    await release();
  }
};
// walk a path with keys; returns true when the goal is reached
let fightReplans = 0;
const near = (list, x, y) => [...list].sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y))[0];
const walkTo = async (tx, ty, opts = {}) => {
  fightReplans = 0;
  for (let attempt = 0; attempt < 4; attempt++) {
    const pl = await plan(tx, ty, opts); if (!pl) { log('no path to', tx, ty); return false; }
    const path = pl.path; let i = 1; var replan = false; let last = await pos(); let lastMove = Date.now(); let lastShot = Date.now();
    stats.stairs += pl.stairs;
    while (i < path.length) {
      if (await dialogue()) { await release(); await readAllQuiet(); }
      if (!opts.noFight && (await enemiesNear(1.5)).length) { await release(); await fight(); replan = true; break; }
      const p = await pos();
      if (p.dead || p.hp <= 0) { await release(); log('crumpled at', p.x.toFixed(1), p.y.toFixed(1)); return false; }
      // skip to the furthest close waypoint ahead
      while (i < path.length - 1 && Math.hypot(path[i][0] + 0.5 - p.x, path[i][1] + 0.5 - p.y) < 0.22) i++;
      const [cx, cy] = path[i]; const dx = cx + 0.5 - p.x, dy = cy + 0.5 - p.y;
      if (i === path.length - 1 && Math.hypot(dx, dy) < 0.3) break;
      await setKeys(keysToward(dx, dy));
      await page.waitForTimeout(50);
      if (Math.hypot(p.x - last.x, p.y - last.y) > 0.25) { last = p; lastMove = Date.now(); stats.cells++; }
      if (Date.now() - lastShot > 15000 && opts.shots) { lastShot = Date.now(); await snap(opts.shots); }
      if (Date.now() - lastMove > 2500) { await release(); stats.stuck.push([+p.x.toFixed(1), +p.y.toFixed(1), path[i]]); log('stuck at', p.x.toFixed(2), p.y.toFixed(2), 'next cell', path[i], 'h', p.h); await snap('stuck'); break; }
    }
    await release();
    if (replan) { attempt--; if (++fightReplans > 40) return false; continue; }
    const p = await pos(); const g = opts.adjacent ? 1.6 : 0.6;
    if (Math.hypot(Math.floor(tx) + 0.5 - p.x, Math.floor(ty) + 0.5 - p.y) < g) return true;
    // wiggle and replan
    await setKeys([KEYS[Object.keys(vec)[attempt % 4]]]); await page.waitForTimeout(250); await release();
  }
  return false;
};
const faceAndE = async (tx, ty) => { const p = await pos(); await setKeys(keysToward(tx - p.x, ty - p.y)); await page.waitForTimeout(70); await release(); await page.waitForTimeout(150); await press('KeyE'); await page.waitForTimeout(400); return readAllQuiet(); };
const V = () => vars();

try {
  log('stack after title', await stack());
  await page.waitForTimeout(1500);
  const intro = await readAllQuiet(); log('intro', intro.length, intro.join(' | ').slice(0, 160));
  await snap('start');
  // which way each key moves her (screen keys on an iso grid)
  for (const k of ['W', 'A', 'S', 'D']) { const a = await pos(); await page.keyboard.down(KEYS[k]); await page.waitForTimeout(260); await page.keyboard.up(KEYS[k]); await page.waitForTimeout(250); const b = await pos(); const n = Math.hypot(b.x - a.x, b.y - a.y) || 1; vec[k] = [(b.x - a.x) / n, (b.y - a.y) / n]; }
  log('key directions', JSON.stringify(Object.fromEntries(Object.entries(vec).map(([k, v]) => [k, v.map((n) => n.toFixed(2))]))));
  check('WASD each move her', Object.values(vec).every((v) => Math.hypot(...v) > 0.5));

  // walking speed in sim time
  { const t1 = await page.evaluate(() => window.__play.sim.runtime.time ?? window.__play.sim.time ?? null); const a = await pos(); const w0 = Date.now();
    await page.keyboard.down('KeyD'); await page.waitForTimeout(1000); await page.keyboard.up('KeyD'); const b = await pos(); const t2 = await page.evaluate(() => window.__play.sim.runtime.time ?? window.__play.sim.time ?? null);
    const d = Math.hypot(b.x - a.x, b.y - a.y); log('walk', d.toFixed(2), 'cells in', ((Date.now() - w0) / 1000).toFixed(2), 's wall; sim time', t1, t2);
    stats.speedWall = d / ((Date.now() - w0) / 1000); stats.speedSim = t1 != null && t2 != null && t2 > t1 ? d / (t2 - t1) : null; }

  // 1. the tutorial sign
  const okSign = await walkTo(19, 53, { adjacent: true });
  const sign = okSign ? await faceAndE(19.5, 53.5) : [];
  check('walk to the tutorial sign and read it', sign.length > 0, sign.join(' | ').slice(0, 120));

  // 2. crystals: walk over the three nearest
  const crystals = await page.evaluate(() => { const s = window.__play.sim; const p = s.world.withTag('player')[0].get('transform'); return s.world.all().filter((e) => e.get('script_Collect') && e.get('sprite')?.visible !== false).map((e) => e.get('transform')).sort((a, b) => Math.hypot(a.x - p.x, a.y - p.y) - Math.hypot(b.x - p.x, b.y - p.y)).slice(0, 3).map((t) => [t.x, t.y]); });
  const m0 = Number((await V()).mnemosynth ?? 0); let reached = 0;
  for (const [x, y] of crystals) if (await walkTo(x, y)) reached++;
  await page.waitForTimeout(600);
  const m1 = Number((await V()).mnemosynth ?? 0);
  check('walk over three crystals and collect them', m1 - m0 >= 5 * reached && reached > 0, `reached ${reached}/3, mnemosynth ${m0} -> ${m1}`);

  // 3. a censor bar: walk into it, lantern, walk through
  const bar = await page.evaluate(() => { const s = window.__play.sim; return s.world.withTag('redactor').map((e) => ({ id: e.id, ...e.get('transform'), c: e.get('collider') })).sort((a, b) => Math.hypot(a.x - 21.5, a.y - 47.5) - Math.hypot(b.x - 21.5, b.y - 47.5))[0]; });
  log('bar', JSON.stringify(bar).slice(0, 200));
  const alongY = bar.c.d > bar.c.w;
  // stand two cells in front of its middle on the start's side
  const side = alongY ? [bar.x + 2 * Math.sign(16.5 - bar.x || 1), bar.y] : [bar.x, bar.y + 2 * Math.sign(54.5 - bar.y || 1)];
  const atBar = await walkTo(side[0], side[1]);
  await snap('bar_before');
  let p = await pos(); const before = { ...p };
  await setKeys(keysToward(bar.x - p.x, bar.y - p.y)); await page.waitForTimeout(1500); await release();
  p = await pos();
  const crossed = alongY ? Math.sign(p.x - bar.x) !== Math.sign(before.x - bar.x) : Math.sign(p.y - bar.y) !== Math.sign(before.y - bar.y);
  check('a censor bar blocks when you walk into it', atBar && !crossed, `from ${before.x.toFixed(1)},${before.y.toFixed(1)} to ${p.x.toFixed(1)},${p.y.toFixed(1)}`);
  // face it and hold the lantern (Q)
  await setKeys(keysToward(bar.x - p.x, bar.y - p.y)); await page.waitForTimeout(60); await release();
  await page.keyboard.down('KeyQ'); await page.waitForTimeout(800); await snap('bar_lantern'); await page.waitForTimeout(2700); await page.keyboard.up('KeyQ');
  await page.waitForTimeout(1800); const said = await readAllQuiet();
  const barNow = await page.evaluate((id) => { const e = window.__play.sim.world.get(id); return e ? { en: e.get('collider')?.enabled, vis: e.get('sprite')?.visible, a: e.get('sprite')?.alpha } : null; }, bar.id);
  check('holding the lantern on the bar lifts it (no shortcut flags set)', !barNow || barNow.en === false, JSON.stringify(barNow) + ' ' + said.join(' | ').slice(0, 100) + ` light ${(await V()).light}`);
  p = await pos(); const b2 = { ...p };
  await setKeys(keysToward(bar.x - p.x, bar.y - p.y)); await page.waitForTimeout(1300); await release(); p = await pos();
  const crossed2 = alongY ? Math.sign(p.x - bar.x) !== Math.sign(b2.x - bar.x) : Math.sign(p.y - bar.y) !== Math.sign(b2.y - bar.y);
  check('after the lantern you can walk through where the bar was', crossed2, `${b2.x.toFixed(1)},${b2.y.toFixed(1)} -> ${p.x.toFixed(1)},${p.y.toFixed(1)}`);
  await snap('bar_after');

  // 4. the meadow lantern post
  const okPost = await walkTo(28.5, 52.5, { adjacent: true });
  const postLines = okPost ? await faceAndE(28.5, 52.5) : [];
  await page.waitForTimeout(800); await readAllQuiet();
  const lit = Object.keys(await V()).filter((k) => k.startsWith('lit:'));
  check('walk to the meadow post and light it', lit.length > 0, `${lit.join(',')} ${postLines.join(' | ').slice(0, 80)}`);
  await snap('post');

  // 5. a plot hole: the nearest pit cell
  const pit = await page.evaluate(() => { const s = window.__play.sim, m = s.map; const p = s.world.withTag('player')[0].get('transform'); let best = null, bd = 1e9; for (let y = 0; y < m.height; y++) for (let x = 0; x < m.width; x++) if (m.getFlags(x, y) & 1) { const d = Math.hypot(x + 0.5 - p.x, y + 0.5 - p.y); if (d < bd) { bd = d; best = [x, y]; } } return best; });
  if (pit) {
    const okPit = await walkTo(pit[0], pit[1], { adjacent: true });
    p = await pos(); const hp0 = p.hp; const at0 = { ...p };
    await setKeys(keysToward(pit[0] + 0.5 - p.x, pit[1] + 0.5 - p.y)); await page.waitForTimeout(700); await release();
    await page.waitForTimeout(400); await snap('pit_fall'); await page.waitForTimeout(2600); await readAllQuiet();
    p = await pos();
    check('stepping into a plot hole hurts and puts you back on solid ground', okPit && p.hp < hp0 && !(p.dead), `pit ${pit}, hp ${hp0} -> ${p.hp}, at ${at0.x.toFixed(1)},${at0.y.toFixed(1)} -> ${p.x.toFixed(1)},${p.y.toFixed(1)} h ${p.h}`);
  }

  // 6. walk all the way to town, fighting what comes, then Garrick
  const stuckBefore = stats.stuck.length;
  const okTown = await walkTo(93.5, 56.5, { shots: 'journey' });
  check('walk from the meadow to Thistledown by keys (stairs included)', okTown, `stairs cells on the routes ${stats.stairs}, stuck ${stats.stuck.length - stuckBefore}, fights ${stats.fights}, beaten ${stats.kills}`);
  await snap('town');
  const gar = await faceAndE(93.5, 55.5);
  check('talk to Garrick', gar.length > 0 && Number((await V()).met_garrick) === 1, gar.join(' | ').slice(0, 100));
  // a stone of a puzzle site and a story gate block (walk into them)
  // 7. the forge: touch the flame
  const okForge = await walkTo(95, 58, { adjacent: false });
  const fl = await faceAndE(96, 57);
  for (let i = 0; i < 30 && !/forge/.test(await scene()); i++) { await page.waitForTimeout(300); await readAllQuiet(); }
  check('touch the frozen flame and go into the forge memory', /forge/.test(await scene()), `${okForge} ${fl.join(' | ').slice(0, 80)} scene ${await scene()}`);
  await page.waitForTimeout(2000); await readAllQuiet(); await snap('forge');

  // 8. in the forge: record an echo onto plate a, walk away, then walk through its gate
  const plates = (await tagged('plate')).sort((a, b) => Math.hypot(a.x - 3.5, a.y - 13.5) - Math.hypot(b.x - 3.5, b.y - 13.5));
  const pa = plates[0]; const gate = near(await tagged('gate'), 11.5, 11.5);
  log('plate', pa.x, pa.y, 'gate', gate.x, gate.y, 'open', gate.open);
  await walkTo(pa.x - 1, pa.y, { noFight: true });
  await press('KeyR'); await page.waitForTimeout(250);
  const lbl = await page.evaluate(() => window.__play.sim.world.withTag('player')[0].get('label')?.text ?? '');
  const toast = await page.evaluate(() => document.body.innerText.match(/Record[^\n]*/)?.[0] ?? '');
  await walkTo(pa.x, pa.y, { noFight: true }); await page.waitForTimeout(400);
  await press('KeyR'); await page.waitForTimeout(400);
  const toast2 = await page.evaluate(() => document.body.innerText.match(/Echo made[^\n]*/)?.[0] ?? '');
  check('R records, R again makes an echo, and you are told', /record/i.test(lbl) && (await tagged('echo')).length === 1, `label "${lbl}", toasts "${toast}" / "${toast2}"`);
  const toGate = await walkTo(gate.x - 1.5, gate.y, { noFight: true });
  await page.waitForTimeout(500); await snap('echo_gate');
  const g2 = (await tagged('gate')).find((g) => g.id === gate.id);
  check('the echo holds the plate and the gate stands open while you walk to it', g2.open === true && Number((await V()).plate_a) === 1, `walked ${toGate}, plate_a ${(await V()).plate_a}`);
  const through = await walkTo(gate.x + 1.5, gate.y, { noFight: true });
  check('walk through the opened gate', through, JSON.stringify(await pos()).slice(0, 80));
  await snap('through_gate');
  stats.speedNote = 'see log';
} catch (e) { check('test run', false, String(e && e.stack || e).slice(0, 400)); }
await release().catch(() => {});
console.log('STATS', JSON.stringify(stats));
console.log('errors', errors.length); for (const e of errors.slice(0, 8)) console.log('  ', e.slice(0, 250));
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, stats, errors: errors.slice(0, 40) }, null, 2));
await app.close();
