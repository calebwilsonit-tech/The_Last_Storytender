// Port tool: opens the ported project in the real Tilewright editor (Electron, under xvfb), takes screenshots of the
// editor and of Play, and records any errors. Run with NODE_PATH pointing at the engine's node_modules:
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/view.mjs <project_dir> <out_dir> [scene] [keys...]
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const [projectDir, outDir, sceneName = '', ...keys] = process.argv.slice(2);
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
await page.waitForFunction(() => window.__viewport !== undefined && window.__viewport.doc !== null, null, { timeout: 120000 });
// the editor reads the art one file at a time after the editor shows; wait for it
await page.waitForFunction(() => (window.__studio?.state?.assetsVersion ?? 0) > 0, null, { timeout: 300000 });
if (sceneName) {
  await page.evaluate(async (s) => { await window.__store.openScene(s); }, sceneName).catch((e) => errors.push('openScene: ' + e.message));
  await page.waitForTimeout(1500);
}
await page.waitForTimeout(2500);
await page.screenshot({ path: path.join(outDir, 'editor.png') });
await page.getByTestId('btn-play').click();
await page.waitForTimeout(3000);
await page.screenshot({ path: path.join(outDir, 'play_0.png') });
let n = 1;
for (const k of keys) {
  const [key, ms] = k.split(':');
  await page.keyboard.down(key);
  await page.waitForTimeout(Number(ms ?? 600));
  await page.keyboard.up(key);
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(outDir, `play_${n++}.png`) });
}
const problems = await page.evaluate(() => (window.__store?.state?.problems ?? []).slice(0, 30).map((p) => p.text ?? String(p))).catch(() => []);
fs.writeFileSync(path.join(outDir, 'errors.json'), JSON.stringify({ errors, problems }, null, 2));
console.log('errors', errors.length, 'problems', problems.length);
for (const e of errors.slice(0, 15)) console.log(' ', e.slice(0, 300));
await app.close();
