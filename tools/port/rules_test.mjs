// Port tool: wearing bindings and amulets (B-04) and falling and crumpling (B-05).
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/rules_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
import { startGame } from './harness.mjs';

const { page, check, vars, setV, msgs, dialogue, placeAt, where, hp, face, tagged, press, hold, readAll, shotAs, at, useThing, clickText, leaveIndex, stack, finish } = await startGame();
try {
  await page.waitForTimeout(1500);
  let v;
  const player = () => page.evaluate(() => { const p = window.__play.sim.world.withTag('player')[0]; const h = p.get('health'); const t = p.get('transform'); return { x: t.x, y: t.y, hp: p.get('state:health').hp, max: h.max, grace: h.invulnerableSeconds, fall: h.fallDamage, speed: p.get('playerController').speed, cd: p.get('dodge').cooldown }; });
  const clickText = async (t, nth = 0) => {
    const hit = await page.evaluate(([t, nth]) => { const n = [...document.querySelectorAll('*')].filter((n) => n.children.length === 0 && (n.textContent ?? '').trim() === t).filter((n) => n.getBoundingClientRect().width > 0)[nth]; const r = n?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; }, [t, nth]);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  // ---- B-04: bindings and amulets are worn from the binder
  await setV({ 'item:cloth_binding': 1, 'item:tin_bell': 1, 'item:paper_scrap': 3, 'slot:1': 'paper_scrap', 'slot:2': '' });
  await placeAt(60.5, 60.5);
  await page.waitForTimeout(600);
  v = await vars();
  check('a picked-up scrap does not sit in a quick slot', v['slot:1'] === '', `slot 1 holds "${v['slot:1']}"`);
  const p0 = await player();
  await press('KeyI');
  await page.waitForTimeout(1000);
  const clicked = await clickText('Cloth Binding');
  await page.waitForTimeout(500);
  v = await vars();
  check('clicking a binding in the binder wears it (at once, the world waits)', v.worn_binding === 'cloth_binding', `clicked ${clicked}, worn_binding ${v.worn_binding}`);
  await clickText('Tin Bell');
  await page.waitForTimeout(500);
  v = await vars();
  check('an amulet goes in its own slot', v.worn_amulet === 'tin_bell', `worn_amulet ${v.worn_amulet}`);
  await shotAs('rules_binder.png');
  await press('KeyI');
  await page.waitForTimeout(900);
  const p1 = await player();
  v = await vars();
  check('what is worn changes her: +5% speed and +0.35 s of grace', Math.abs(p1.speed - 4.2 * 1.05) < 0.03 && Math.abs(p1.grace - 1.25) < 0.01, `speed ${p0.speed} -> ${p1.speed}, grace ${p0.grace} -> ${p1.grace}`);
  check('the binder says what it does', /-6%/.test(String(v.st0)) && /\+5%/.test(String(v.st1)) && /1\.3s|1\.2s/.test(String(v.st3)), `${v.st0} | ${v.st1} | ${v.st3}`);
  // take it off by clicking its slot
  await press('KeyI');
  await page.waitForTimeout(900);
  await clickText('click to take off');
  await page.waitForTimeout(400);
  v = await vars();
  check('clicking the slot takes it off', !v.worn_binding || !v.worn_amulet, `binding "${v.worn_binding}" amulet "${v.worn_amulet}"`);
  await press('KeyI');
  await page.waitForTimeout(700);

  // ---- B-05: falling and crumpling
  const diff = async (d) => { await setV({ difficulty: d }); await page.waitForTimeout(500); };
  await diff('story');
  const ps = await player();
  await diff('normal');
  const pn = await player();
  check('a fall costs 8 ink in Story and 15 in Normal', ps.fall === 8 && pn.fall === 15, `story ${ps.fall}, normal ${pn.fall}`);
  const crush = async (x, y) => {
    await placeAt(x, y);
    await page.waitForTimeout(500);
    await page.evaluate(() => { window.__play.sim.world.withTag('player')[0].get('state:health').hp = 0; });
    await page.waitForTimeout(900);
  };
  // normal: she loses a seventh of her Mnemosynth (floor(M x 0.15 / 5) x 5), it lies where she fell, and she wakes with 50 ink
  await setV({ mnemosynth: 100, difficulty: 'normal', rested_once: 0 });
  const crystals0 = (await tagged('dropped')).length;
  await crush(60.5, 60.5);
  v = await vars();
  const pp = await player();
  const crystals1 = (await tagged('dropped')).length;
  check('Normal: 15 of 100 Mnemosynth are left where she fell, as three crystals', Number(v.mnemosynth) === 85 && crystals1 - crystals0 === 3, `M ${v.mnemosynth}, crystals ${crystals0} -> ${crystals1}`);
  check('Normal: she wakes with 50 ink and the page says it can be smoothed', pp.hp === 50 && (await msgs()).some((m) => /crumpled page can be smoothed/i.test(m)), `hp ${pp.hp}`);
  check('with no post rested at she wakes at the start of the page', Math.abs(pp.x - 16.5) < 3 && Math.abs(pp.y - 54.5) < 3, `at ${pp.x.toFixed(1)},${pp.y.toFixed(1)}`);
  // story: nothing lost, 100 ink
  await setV({ mnemosynth: 100, difficulty: 'story' });
  await crush(75.5, 62.5);
  v = await vars();
  const pst = await player();
  check('Story: nothing is lost and she wakes with 100 ink', Number(v.mnemosynth) === 100 && pst.hp === 100, `M ${v.mnemosynth}, hp ${pst.hp}`);
  // in the town she wakes in the town's square
  await crush(92.5, 56.5);
  const pt = await player();
  check('a crumple in the town wakes her in the town square (87,53)', Math.abs(pt.x - 87.5) < 1.5 && Math.abs(pt.y - 53.5) < 1.5, `at ${pt.x.toFixed(1)},${pt.y.toFixed(1)}`);
  // after resting at a post she wakes at that post
  await setV({ rested_once: 0 });
  const post = (await tagged('lantern-post')).find((e) => Math.abs(e.x - 28.5) < 1 && Math.abs(e.y - 52.5) < 1) ?? (await tagged('lantern-post'))[0];
  await placeAt(post.x, post.y + 1.0);
  await page.waitForTimeout(500);
  await face(post.x, post.y);
  await press('KeyE');
  await page.waitForTimeout(2600);
  for (let i = 0; i < 3 && /Revise/.test(await page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','))); i++) { await clickText('Leave the Index'); await page.waitForTimeout(700); }
  console.log('checkpoint', JSON.stringify(await page.evaluate(() => window.__play.sim.runtime.checkpoint)), 'rested_once', (await vars()).rested_once, 'post', JSON.stringify(post));
  await crush(75.5, 62.5);
  const pr = await player();
  check('after resting at a post she wakes beside it', Math.hypot(pr.x - post.x, pr.y - (post.y + 1)) < 2.5, `at ${pr.x.toFixed(1)},${pr.y.toFixed(1)}; post ${post.x},${post.y}`);
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
await finish();
