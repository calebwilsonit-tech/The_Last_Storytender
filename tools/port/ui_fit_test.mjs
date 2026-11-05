// Port test: every screen and the heads-up display stay inside the game's window at any window size (and any interface size).
//   TILEWRIGHT=<engine> node tools/port/ui_fit_test.mjs <project_dir> <out_dir>
import { startGame } from './harness.mjs';

const { page, check, setV, stack, shotAs, finish } = await startGame();

/** What sticks out of the window: every drawn widget of the open screens whose box is not inside the game's root. */
const outside = () =>
  page.evaluate(() => {
    const root = document.querySelector('.tw-screens');
    if (!root) return { error: 'no root' };
    const r = root.getBoundingClientRect();
    const bad = [];
    let n = 0;
    for (const el of root.querySelectorAll('.tw-w')) {
      const b = el.getBoundingClientRect();
      if (b.width < 1 || b.height < 1) continue;
      const cs = getComputedStyle(el);
      if (cs.display === 'none' || cs.visibility === 'hidden' || Number(cs.opacity) === 0) continue;
      // inside a scroll area a widget may run past the edge on purpose
      if (el.closest('.tw-scroll-content, .tw-scroll')) continue;
      n++;
      const tol = 2;
      if (b.left < r.left - tol || b.top < r.top - tol || b.right > r.right + tol || b.bottom > r.bottom + tol) {
        bad.push(`${el.getAttribute('data-testid')} [${Math.round(b.left - r.left)},${Math.round(b.top - r.top)} ${Math.round(b.width)}x${Math.round(b.height)}] in ${Math.round(r.width)}x${Math.round(r.height)}`);
      }
    }
    return { n, bad: bad.slice(0, 6), count: bad.length, w: Math.round(r.width), h: Math.round(r.height) };
  });

const screenNames = () => page.evaluate(() => window.__play.sim.assets.ui.screens.map((s) => s.name));
const names = await screenNames();
console.log('screens', names.join(' | '));
// the screens that are only a piece of another (a tooltip, an overlay with no widgets of its own) are checked too: nothing to skip but the HUD, which stays open
const SIZES = [[900, 640], [1100, 720], [1600, 1000], [2200, 1300]];
try {
  for (const [w, h] of SIZES) {
    await page.setViewportSize({ width: w, height: h });
    await page.waitForTimeout(700);
    // the heads-up display, as it is while playing
    let o = await outside();
    check(`${w}x${h}: the heads-up display fits (${o.n} widgets, window ${o.w}x${o.h})`, !o.error && o.count === 0, o.bad?.join('; '));
    await shotAs(`fit_${w}x${h}_hud.png`);
    for (const ui of [1, 1.5]) {
      await page.evaluate((ui) => window.__play.session.hostObj.changeSettings({ uiScale: ui }), ui);
      await page.waitForTimeout(300);
      const hud = await outside();
      check(`${w}x${h} at interface size ${ui}: the heads-up display fits`, !hud.error && hud.count === 0, hud.bad?.join('; '));
    }
    await page.evaluate(() => window.__play.session.hostObj.changeSettings({ uiScale: 1 }));
    // every screen, one at a time on top of the game
    // (the "(built-in)" ones are the engine's own spares: the game's own screens play those roles)
    for (const name of names.filter((n) => !/\(built-in\)/.test(n))) {
      const before = await stack();
      await page.evaluate((n) => { const st = window.__play.sim.runtime.ui.stack; if (!st.includes(n)) st.push(n); }, name);
      await page.waitForTimeout(450);
      const s = await outside();
      const ok = !s.error && s.count === 0;
      check(`${w}x${h}: "${name}" fits`, ok, s.bad?.join('; '));
      if (!ok || name === 'Settings') await shotAs(`fit_${w}x${h}_${name.replace(/\W+/g, '_')}.png`);
      await page.evaluate(([n, b]) => { window.__play.sim.runtime.ui.stack = b ? b.split(',') : []; void n; }, [name, before]);
      await page.waitForTimeout(150);
    }
  }
  // the Settings screen has the new rows: the interface size is always there, the window size only where the host can set it (not in the editor's Play)
  await page.setViewportSize({ width: 1600, height: 1000 });
  await page.evaluate(() => window.__play.sim.runtime.ui.stack.push('Settings'));
  await page.waitForTimeout(500);
  const labels = await page.evaluate(() => [...document.querySelectorAll('.tw-screens *')].filter((x) => x.children.length === 0 && x.getBoundingClientRect().width > 0).map((x) => (x.textContent ?? '').trim()));
  check('Settings offers "Menu and HUD size"', labels.includes('Menu and HUD size'));
  check('Settings hides "Window size" where the host cannot set it (the editor)', !labels.includes('Window size'));
  // the interface size really makes the heads-up display bigger (and the window size is still respected)
  await page.evaluate(() => { window.__play.sim.runtime.ui.stack = ['HUD']; });
  const widths = () => page.evaluate(() => [...document.querySelectorAll('.tw-screens .tw-w')].reduce((a, e) => a + e.getBoundingClientRect().width, 0));
  await page.evaluate(() => window.__play.session.hostObj.changeSettings({ uiScale: 1 }));
  await page.waitForTimeout(400);
  const w1 = await widths();
  await page.evaluate(() => window.__play.session.hostObj.changeSettings({ uiScale: 1.5 }));
  await page.waitForTimeout(400);
  const w15 = await widths();
  check('the interface size makes the heads-up display bigger', w15 > w1 * 1.3, `${Math.round(w1)} -> ${Math.round(w15)}`);
  const fin = await outside();
  check('and it still fits the window at 1.5', fin.count === 0, fin.bad?.join('; '));
  await page.evaluate(() => window.__play.session.hostObj.changeSettings({ uiScale: 1 }));
  void setV;
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
await finish();
