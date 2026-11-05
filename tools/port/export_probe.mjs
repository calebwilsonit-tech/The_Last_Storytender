// Port tool (forge): plays Garrick's memory in the ported game in the real Tilewright editor and checks that its interactions work: reading a sign,
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
const work = path.join(base, 'work', 'project'); const workRoot = path.join(base, 'work');
fs.cpSync(projectDir, work, { recursive: true, filter: (f) => path.basename(f) !== 'saves' }); // (a game played from the editor leaves its saves in the project folder: the tests start fresh)
const app = await electron.launch({
  args: [path.join(TILEWRIGHT, 'packages', 'editor'), `--user-data-dir=${path.join(base, 'ud')}`, '--no-sandbox'],
  env: { ...process.env, TILEWRIGHT_TEST_DIR: workRoot },
});
const page = await app.firstWindow();
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
await page.setViewportSize({ width: 1600, height: 1000 }).catch(() => undefined);
await page.waitForTimeout(3000); await page.evaluate(([d]) => window.tilewright.recent.add(d, 'tls'), [work]); await page.evaluate((d) => window.__store.openRecent(d), work);
const { expect } = createRequire(path.join(TILEWRIGHT, 'package.json'))('@playwright/test');
console.log('step: export button'); await page.getByTestId('btn-export').click();
await page.waitForTimeout(8000); await page.screenshot({ path: path.join(outDir, 'dlg1.png') }); console.log('dialog text:', (await page.evaluate(() => document.querySelector('[role=dialog]')?.innerText ?? document.body.innerText.slice(-1500))).replace(/\s+/g,' ').slice(0, 1500));
await expect(page.getByTestId('export-ready')).toBeVisible({ timeout: 120000 });
for (let i = 0; i < 120 && !(await page.getByTestId('export-go').isEnabled()); i++) await page.waitForTimeout(2000);
console.log('go enabled', await page.getByTestId('export-go').isEnabled(), 'errors:', (await page.getByTestId('export-errors').innerText().catch(() => '')).slice(0, 600));
console.log('step: go'); await page.getByTestId('export-go').click();
for (let i = 0; i < 400; i++) {
  if (await page.getByTestId('export-result').isVisible()) break;
  if (await page.getByTestId('export-failure').isVisible()) { console.log('FAILURE', (await page.getByTestId('export-failure').innerText()).slice(0, 1500)); break; }
  if (i % 15 === 0) console.log('progress', (await page.getByTestId('export-progress').innerText().catch(() => '-')).slice(0, 200));
  await page.waitForTimeout(2000);
}
const exe = (await page.getByTestId('export-exe').textContent()).trim();
console.log('exe', exe);
await app.close();
for (const mode of (process.env.MODES ?? 'normal,test').split(',')) {
  const env = { ...process.env, TILEWRIGHT_GAME_USERDATA: fs.mkdtempSync(path.join(os.tmpdir(), 'tw-game-')) };
  delete env.TILEWRIGHT_TEST_DIR; delete env.TILEWRIGHT_GAME_TEST;
  if (mode === 'test') env.TILEWRIGHT_GAME_TEST = '1';
  const g = await electron.launch({ executablePath: exe, args: ['--no-sandbox'], env });
  const w = await g.firstWindow();
  const errs = []; w.on('pageerror', (e) => errs.push(e.message)); w.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
  await w.waitForTimeout(30000);
  // the frame rate of the exported game at its title (2.5 s of animation frames)
  const fps = await w.evaluate(() => new Promise((res) => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < 2500) requestAnimationFrame(f); else res(Math.round((n / 2.5) * 10) / 10); }; requestAnimationFrame(f); }));
  console.log(mode, 'frames per second at the title:', fps);
  await w.screenshot({ path: path.join(outDir, `game_${mode}.png`) });
  console.log(mode, 'title:', await w.title(), '| text:', (await w.evaluate(() => document.body.innerText)).replace(/\s+/g, ' ').slice(0, 160), '| errors:', errs.slice(0, 3).join(' / ').slice(0, 300));
  await g.close();
}
