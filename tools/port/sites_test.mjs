// Port tool: the overworld's puzzle sites (C-02): an echo site, a words site, an arena and a crumbling causeway, each with its chest.
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/sites_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
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
  await setV({ memory_done: 1 });

  // ---- echo site "the neck": plates (42,39) and (48,32), gate (45,37), chest (45,36)
  const chest = { x: 45.5, y: 36.5 };
  let gate = at(await tagged('gate'), 45.5, 37.5);
  check('the WEIGHED gate is shut', gate && gate.solid === true, JSON.stringify(gate));
  let said = await useThing(chest.x, chest.y, chest.x + 1.0, chest.y + 1.2);
  let v = await vars();
  check('the sealed chest says it is sealed', !v['got_chest_45_36'] && said.some((l) => /sealed/i.test(l)), said.join(' | ').slice(0, 120));
  // an echo holds plate A while she stands on plate B
  await placeAt(41.5, 38.5);
  await page.waitForTimeout(400);
  await press('KeyR'); await page.waitForTimeout(300);
  await hold('KeyS', 330);
  await page.waitForTimeout(600);
  await press('KeyR'); await page.waitForTimeout(500);
  const echoes = await tagged('echo');
  await placeAt(48.5, 32.5);
  await page.waitForTimeout(2800);
  v = await vars();
  console.log('echo at', echoes.map((e) => `${e.x.toFixed(1)},${e.y.toFixed(1)}`).join(' '), 'plates', v.plate_p_echo_neck_0, v.plate_p_echo_neck_1);
  check('an echo on one plate and her on the other solve the site (+4 renown)', Number(v.site_p_echo_neck) === 1 && Number(v.renown) >= 4, `site ${v.site_p_echo_neck} renown ${v.renown} | ${(await msgs()).slice(-2).join(' / ')}`);
  gate = at(await tagged('gate'), 45.5, 37.5);
  await page.waitForTimeout(600);
  gate = at(await tagged('gate'), 45.5, 37.5);
  check('the gate opens', gate && gate.solid === false, JSON.stringify(gate));
  said = await useThing(chest.x, chest.y, chest.x + 1.0, chest.y + 1.2);
  v = await vars();
  check('the chest opens now', Number(v['got_chest_45_36']) === 1, said.join(' | ').slice(0, 140));
  await shotAs('site_echo.png');

  // ---- words site "the wells": stones (29,89) (31,89) (33,89) must read BROKEN->MENDED, LIT, PAID
  const stones = (await tagged('stone')).filter((s) => Math.abs(s.y - 89.5) < 0.2 && s.x > 28 && s.x < 34);
  console.log('stones', stones.map((s) => `${s.x},${s.y}`).join(' '));
  const goodPresses = [1, 1, 2];
  // wrong first: one press on the third stone only
  await useThing(33.5, 89.5, 33.5, 90.9);
  v = await vars();
  check('a stone changes its word when it is used', v.stone_p_words_wells_2 === 'WAIVED', `stone 2 reads ${v.stone_p_words_wells_2}`);
  check('one wrong word does not solve the site', !v.site_p_words_wells, '');
  let bridge = await tagged('bridge-p_words_wells');
  check('the bridge is shut while the sentence is wrong', bridge.length === 3 && bridge.every((b) => b.solid === true), `${bridge.length} covers, solid ${bridge.map((b) => b.solid).join(',')}`);
  for (let k = 0; k < 3; k++) {
    const x = 29.5 + k * 2;
    const need = goodPresses[k] - (k === 2 ? 1 : 0);
    for (let n = 0; n < need; n++) await useThing(x, 89.5, x, 90.9);
  }
  await page.waitForTimeout(800);
  v = await vars();
  check('the right sentence solves the site (+4 renown) and says so', Number(v.site_p_words_wells) === 1 && v.stone_p_words_wells_0 === 'MENDED' && v.stone_p_words_wells_1 === 'LIT' && v.stone_p_words_wells_2 === 'PAID', `site ${v.site_p_words_wells}; ${v.stone_p_words_wells_0}/${v.stone_p_words_wells_1}/${v.stone_p_words_wells_2}`);
  await page.waitForTimeout(500);
  bridge = await tagged('bridge-p_words_wells');
  check('the bridge of pages unrolls', bridge.every((b) => b.solid === false), `solid ${bridge.map((b) => b.solid).join(',')}`);
  await useThing(29.5, 89.5, 29.5, 90.9);
  v = await vars();
  check('a solved stone stays as written', v.stone_p_words_wells_0 === 'MENDED', v.stone_p_words_wells_0);
  // walk over the bridge: it is at (30..32, 87), from the south side
  await placeAt(31.5, 88.6);
  await page.waitForTimeout(300);
  await hold(['KeyW', 'KeyD'].length ? 'KeyW' : 'KeyW', 10);
  await shotAs('site_words.png');

  // ---- arena "the ridge": trigger (105,28), gate (105,30), waves of Bares then Mites
  gate = at(await tagged('gate'), 105.5, 30.5);
  check('the PROOF gate is open before the fight', gate && gate.solid === false, JSON.stringify(gate));
  await placeAt(105.5, 28.5);
  await page.waitForTimeout(1500);
  gate = at(await tagged('gate'), 105.5, 30.5);
  let wave0 = (await tagged('arena-p_arena_ridge-w0'));
  check('stepping on the plate shuts the gate and wakes the first wave', gate && gate.solid === true && wave0.length === 2 && wave0.every((e) => e.visible), `gate solid ${gate?.solid}; wave0 ${wave0.length} visible ${wave0.map((e) => e.visible).join(',')}`);
  await shotAs('site_arena.png');
  // beat wave 0 (a test shortcut: their ink to zero)
  const kill = (tag) => page.evaluate((tag) => { for (const e of window.__play.sim.world.withTag(tag)) { const h = e.get('state:health'); if (h) h.hp = 0; } }, tag);
  await placeAt(105.5, 31.5);
  await kill('arena-p_arena_ridge-w0');
  await page.waitForTimeout(2200);
  const wave1 = await tagged('arena-p_arena_ridge-w1');
  check('beating the first wave brings the second', wave1.length === 3 && wave1.some((e) => e.visible), `wave1 visible ${wave1.map((e) => e.visible).join(',')}`);
  await kill('arena-p_arena_ridge-w1');
  await page.waitForTimeout(2500);
  v = await vars();
  gate = at(await tagged('gate'), 105.5, 30.5);
  check('beating the last wave opens the gate and solves the site', Number(v.site_p_arena_ridge) === 1 && gate && gate.solid === false, `site ${v.site_p_arena_ridge}, gate solid ${gate?.solid} | ${(await msgs()).slice(-2).join(' / ')}`);

  // ---- crumbling causeway "smudge": first page (106,91), start (106,92), chest (106,82)
  await placeAt(106.5, 91.5);
  await page.waitForTimeout(1300);
  let cracks = await tagged('crack-p_crumble_smudge');
  const first = at(cracks, 106.5, 91.5);
  check('a page she stands on falls away after a moment', first && first.visible, JSON.stringify(first));
  await page.waitForTimeout(500);
  const hp0 = await hp();
  const p1 = await where();
  check('standing on a fallen page she falls: hurt and put back at the start', Math.abs(p1.y - 92.5) < 0.6 && hp0 < 100, `at ${p1.x.toFixed(1)},${p1.y.toFixed(1)} hp ${hp0}`);
  await placeAt(106.5, 83.5);
  await page.waitForTimeout(800);
  v = await vars();
  check('reaching the chest makes the causeway solid for good (+4 renown)', Number(v.site_p_crumble_smudge) === 1, `site ${v.site_p_crumble_smudge}`);

  // ---- the riddles (vault trials). r0: the stone (39,67), gate (37,65), tier 1 = Proofread
  const clickText = async (t) => {
    const hit = await page.evaluate((t) => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === t).find((n) => n.getBoundingClientRect().width > 0); const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; }, t);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  let gate0 = at(await tagged('gate'), 37.5, 65.5);
  check('the riddle gate is shut', gate0 && gate0.solid === true, JSON.stringify(gate0));
  await useThing(39.5, 67.5, 39.5, 68.9);
  await page.waitForTimeout(900);
  const open1 = /Proofread/.test(await stack());
  v = await vars();
  console.log('proofread words', Array.from({ length: 12 }, (_, i) => v[`pf_w${i}`]).filter(Boolean).join(' '), 'bad', v.pf_bad);
  await shotAs('riddle_proofread.png');
  check('"Attempt the trial" opens the Proofread screen', open1 && Number(v.pf_tries) === 3, `stack ${await stack()}, tries ${v.pf_tries}`);
  // a fine word costs a try
  const fine = Array.from({ length: 12 }, (_, i) => i).find((i) => v[`pf_w${i}`] && i !== Number(v.pf_bad));
  await clickText(v[`pf_w${fine}`]);
  await page.waitForTimeout(500);
  v = await vars();
  check('a fine word costs a try', Number(v.pf_tries) === 2 && Number(v[`pf_x${fine}`]) === 1, `tries ${v.pf_tries}`);
  // leaving loses the trial
  await clickText('Leave it');
  await page.waitForTimeout(900);
  v = await vars();
  check('leaving says the words slip away and keeps the gate shut', !v.riddle_r0 && (await msgs()).some((m) => /words slip away/i.test(m)), '');
  // try again and win
  await useThing(39.5, 67.5, 39.5, 68.9);
  await page.waitForTimeout(900);
  v = await vars();
  await clickText(v[`pf_w${v.pf_bad}`]);
  await page.waitForTimeout(500);
  v = await vars();
  check('the wrong word solves the sentence', Number(v.pf_solved) === 1, `solved ${v.pf_solved}, ${v.pf_msg}`);
  const renown0 = Number(v.renown);
  await clickText('The sentence is fixed');
  await page.waitForTimeout(1200);
  v = await vars();
  check('the riddle is solved: +8 renown and the sentence settles', Number(v.riddle_r0) === 1 && Number(v.renown) - renown0 === 8, `riddle_r0 ${v.riddle_r0}, renown +${Number(v.renown) - renown0}`);
  await page.waitForTimeout(800);
  gate0 = at(await tagged('gate'), 37.5, 65.5);
  check('the riddle gate opens', gate0 && gate0.solid === false, JSON.stringify(gate0));
  // r3 (tier 3): the stone (58,56), gate (60,54): a pattern game
  await useThing(58.5, 56.5, 58.5, 57.9);
  await page.waitForTimeout(900);
  const mg = await page.evaluate(() => { const m = window.__play.sim.runtime.modals.minigame; return m ? { name: m.name, kind: m.kind, phase: m.phase } : null; });
  await shotAs('riddle_pattern.png');
  check('"Attempt the trial" on the harder stone starts the pattern game', mg && /Vault Trial r3/.test(mg.name), JSON.stringify(mg));
  // play it: confirm the intro, wait for the pattern, press it back (W up, D right, S down, A left)
  const KEYS = ['KeyW', 'KeyD', 'KeyS', 'KeyA'];
  const playPattern = async (wrong) => {
    // follow the game: confirm the intro, wait while the pattern is shown, press the next arrow (a wrong one when losing), confirm the result
    for (let i = 0; i < 160; i++) {
      const m = await page.evaluate(() => { const g = window.__play.sim.runtime.modals.minigame; return g ? { phase: g.phase, seq: g.seq, entered: g.entered } : null; });
      if (!m) return;
      if (m.phase === 'intro' || m.phase === 'won' || m.phase === 'lost') await press('KeyE');
      else if (m.phase === 'play') await press(KEYS[wrong ? (m.seq[m.entered] + 1) % 4 : m.seq[m.entered]], 80);
      else await page.waitForTimeout(250);
    }
  };
  await playPattern(true);
  await page.waitForTimeout(1000);
  v = await vars();
  check('losing the pattern says the words slip away; the riddle stays unsolved', !v.riddle_r3 && (await msgs()).filter((m) => /words slip away/i.test(m)).length >= 2, `riddle_r3 ${v.riddle_r3}`);
  await useThing(58.5, 56.5, 58.5, 57.9);
  await page.waitForTimeout(900);
  const r0 = Number((await vars()).renown);
  await playPattern(false);
  await page.waitForTimeout(1200);
  v = await vars();
  const g3 = at(await tagged('gate'), 60.5, 54.5);
  check('winning the pattern solves the riddle: +16 renown and its gate opens', Number(v.riddle_r3) === 1 && Number(v.renown) - r0 === 16 && g3 && g3.solid === false, `riddle_r3 ${v.riddle_r3}, renown +${Number(v.renown) - r0}, gate solid ${g3?.solid}`);
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
