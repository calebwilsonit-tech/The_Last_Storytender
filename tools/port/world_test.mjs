// Port tool: the rest of the overworld rules (C-05): discovering regions, introductions of new Errors, the new kinds acting, and the dungeon pause items.
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/world_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
import { startGame } from './harness.mjs';

const { page, check, vars, setV, msgs, dialogue, placeAt, where, hp, face, tagged, press, hold, readAll, shotAs, at, useThing, clickText, leaveIndex, stack, finish } = await startGame();
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
await finish();
