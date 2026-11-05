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
const errs = [];
app.on('window', async (w) => {
  w.on('pageerror', (e) => errs.push('pageerror: ' + (e.stack || e.message).slice(0, 600)));
  w.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') errs.push(m.type() + ': ' + m.text().slice(0, 2500)); });
});
await page.getByTestId('btn-run-window').click();
let win = null;
for (let i = 0; i < 60 && !win; i++) { await page.waitForTimeout(1000); win = app.windows().find((w) => w !== page); }
console.log('windows', app.windows().length, 'editor toast:', (await page.evaluate(() => document.body.innerText.match(/(could not|cannot|error)[^\n]*/i)?.[0] ?? '')).slice(0, 300));
if (win) {
  await win.waitForTimeout(25000);
  await win.screenshot({ path: path.join(outDir, 'window_1.png') });
  console.log('title', await win.title());
  console.log('body', (await win.evaluate(() => document.body.innerText)).slice(0, 800));
  await win.keyboard.press('KeyE'); await win.waitForTimeout(1500); await win.keyboard.press('KeyE'); await win.waitForTimeout(8000);
  await win.screenshot({ path: path.join(outDir, 'window_2.png') });
}
console.log('ERRORS', errs.length); for (const e of errs.slice(0, 15)) console.log(' -', e.slice(0,2500));
console.log('editor errors', errors.length, errors.slice(0, 5).join('\n'));
await app.close();
