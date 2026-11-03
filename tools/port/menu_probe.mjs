// Port tool: opens the ported game in the editor, plays it, and screenshots the title, pause, binder and map.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/menu_probe.mjs <project_dir> <out_dir>
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const [projectDir, outDir] = process.argv.slice(2);
const TILEWRIGHT = process.env.TILEWRIGHT ?? '/home/user/calebwilsonit-tech/tilewrite';
const { _electron: electron } = createRequire(path.join(TILEWRIGHT, 'package.json'))('playwright');
fs.mkdirSync(outDir, { recursive: true });
const base = fs.mkdtempSync(path.join(os.tmpdir(), 'tw-menu-'));
const work = path.join(base, 'project');
fs.cpSync(projectDir, work, { recursive: true });
const app = await electron.launch({ args: [path.join(TILEWRIGHT, 'packages', 'editor'), `--user-data-dir=${path.join(base, 'ud')}`, '--no-sandbox'], env: { ...process.env, TILEWRIGHT_TEST_DIR: work } });
const page = await app.firstWindow();
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
await page.setViewportSize({ width: 2400, height: 1300 }).catch(() => undefined);
await page.getByTestId('btn-open-project').click();
await page.getByTestId('editor-shell').waitFor({ timeout: 120000 });
await page.waitForFunction(() => (window.__studio?.state?.assetsVersion ?? 0) > 0, null, { timeout: 300000 });
await page.waitForTimeout(3000);
await page.getByTestId('btn-play').click();
await page.waitForFunction(() => window.__play !== undefined && window.__play.sim, null, { timeout: 60000 });
await page.waitForTimeout(2500);
const shot = (n) => page.screenshot({ path: path.join(outDir, n) });
const screens = () => page.evaluate(() => {
  const r = window.__play?.runner; if (r) { const ks = Object.keys(r).filter((k) => /screen|ui/i.test(k)); try { return JSON.stringify(ks.map((k) => [k, typeof r[k] === 'object' ? Object.keys(r[k] ?? {}).slice(0, 12) : r[k]])); } catch (e) { return String(e); } }
  const p = window.__play;
  const s = p?.screens ?? p?.ui ?? p?.sim?.runtime?.screens;
  try { return JSON.stringify((s?.open ?? s?.stack ?? s)?.map?.((x) => x.id ?? x.screen?.id ?? x) ?? Object.keys(p ?? {})); } catch (e) { return String(e); }
});
const press = async (k) => { await page.keyboard.down(k); await page.waitForTimeout(90); await page.keyboard.up(k); await page.waitForTimeout(700); };
const stack = () => page.evaluate(() => JSON.stringify(window.__play.sim.runtime.ui.stack));
await shot('0_title.png'); console.log('title', await stack());
await press('KeyE'); await shot('1_difficulty.png'); console.log('after E', await stack());
await press('KeyE'); await page.waitForTimeout(800); await shot('2_game.png'); console.log('after story', await stack(), await page.evaluate(() => window.__play.sim.runtime.vars.difficulty));
await page.evaluate(() => { const v = window.__play.sim.runtime.vars; v['item:ink_vial'] = 3; v['item:eraser_crumbs'] = 2; v['item:hardcover_binding'] = 1; v['item:lantern_oil'] = 1; v.mnemosynth = 20; v.has_quill = 1; });
await press('KeyP'); await shot('3_pause.png'); console.log('pause', await stack());
await press('KeyP'); await page.waitForTimeout(300);
await press('Tab'); await page.mouse.move(800, 400); await shot('4_binder.png'); console.log('binder', await stack());
await press('KeyP'); await page.waitForTimeout(300); console.log('after P', await stack());
await press('KeyM'); await shot('5_map.png'); console.log('map', await stack());
await press('KeyP'); await page.waitForTimeout(300); console.log('closed', await stack());
console.log('errors', errors.slice(0, 8));
await app.close();
