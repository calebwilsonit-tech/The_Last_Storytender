// Port tool: what every test of the running game shares: it opens the project in the real Tilewright editor (Electron, under Playwright), presses
// Play, gets past the title, the storybook and the waking-up scene, and hands back the helpers the tests use. A test is:
//
//   import { startGame } from './harness.mjs';
//   const { page, check, vars, setV, placeAt, press, readAll, finish } = await startGame();
//   try { ...checks... } catch (e) { check('test run', false, String((e && e.stack) || e).slice(0, 400)); }
//   await finish();
//
// Run:  TILEWRIGHT=<engine checkout> node tools/port/<name>_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

/**
 * @param {{ intro?: boolean, viewport?: { width: number, height: number } }} [options]
 *   intro: false leaves the title, the storybook and the waking-up scene to the test (default: they are passed)
 */
export async function startGame(options = {}) {
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
  await page.setViewportSize(options.viewport ?? { width: 1600, height: 1000 }).catch(() => undefined);
  await page.getByTestId('btn-open-project').click();
  await page.getByTestId('editor-shell').waitFor({ timeout: 120000 });
  await page.waitForFunction(() => (window.__studio?.state?.assetsVersion ?? 0) > 0, null, { timeout: 300000 });
  await page.waitForTimeout(3000);
  await page.getByTestId('btn-play').click();
  await page.waitForFunction(() => window.__play !== undefined && window.__play.sim, null, { timeout: 60000 });
  await page.waitForTimeout(2500);
  const stack = () => page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','));
  const atStart = await stack();
  if (options.intro !== false) {
    // New Game, then the first choice (Story); the storybook's pages; the waking-up scene is skipped
    for (let i = 0; i < 2 && /Title/.test(await stack()); i++) {
      await page.keyboard.press('KeyE');
      await page.waitForTimeout(700);
    }
    for (let i = 0; i < 12 && /Storybook/.test(await stack()); i++) {
      await page.keyboard.press('KeyE');
      await page.waitForTimeout(350);
    }
    await page.waitForTimeout(600);
    if (await page.evaluate(() => !!window.__play.sim.runtime.cutscene)) {
      await page.keyboard.press('KeyP');
      await page.waitForTimeout(900);
    }
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
  /** Put the Storytender on a spot (a test shortcut). */
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
  /** Turn her toward a cell. Her facing is a direction on the screen (0 right, 2 down); grid +x runs down-right and +y down-left. */
  const face = (x, y) => page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4) + 8) % 8; }, [x, y]);
  const tagged = (tag) => page.evaluate((tag) => window.__play.sim.world.withTag(tag).map((e) => ({ id: e.id, name: e.name, ...e.get('transform'), solid: e.get('collider') ? e.get('collider').enabled : null, visible: e.get('sprite')?.visible !== false, asset: e.get('sprite')?.asset, hp: e.get('state:health')?.hp })), tag);
  const press = async (key, ms = 90) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(160); };
  const hold = async (key, ms) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(200); };
  /** Everything that is being said, and every cutscene that follows it (a conversation can end in a scene, a tick later). */
  const readAll = async () => {
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
  /** Click the first visible thing whose whole text is `text` (a button of a screen). */
  const clickText = async (text, nth = 0) => {
    const hit = await page.evaluate(([t, n]) => { const el = [...document.querySelectorAll('*')].filter((x) => x.children.length === 0 && (x.textContent ?? '').trim() === t).filter((x) => x.getBoundingClientRect().width > 0)[n]; const r = el?.getBoundingClientRect(); return r ? { x: r.x + r.width / 2, y: r.y + r.height / 2 } : null; }, [text, nth]);
    if (hit) await page.mouse.click(hit.x, hit.y);
    return !!hit;
  };
  /** The "Revise Your Draft" screen opens a moment after resting at a post (longer the first time): wait, then leave it. */
  const leaveIndex = async () => {
    await page.waitForTimeout(2600);
    for (let i = 0; i < 3 && /Revise/.test(await stack()); i++) { await clickText('Leave the Index'); await page.waitForTimeout(700); }
  };
  /** Write the report and close the game. */
  const finish = async () => {
    fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
    console.log('errors', errors.length);
    for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
    await app.close();
  };
  return { app, page, errors, results, projectDir, outDir, atStart, stack, check, vars, setV, msgs, dialogue, placeAt, where, hp, face, tagged, press, hold, readAll, shotAs, at, useThing, clickText, leaveIndex, finish };
}
