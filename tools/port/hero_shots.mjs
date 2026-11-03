// Port tool: screenshots of the Storytender in the ported game, cropped to him: idle, walking each way, the quill strike.
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/hero_shots.mjs <project_dir> <out_dir>
// Writes <out_dir>/<name>.png clips (viewport pixels, 1:1) and report.json (the animator state at each shot).
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
await page.setViewportSize({ width: 1600, height: 1000 }).catch(() => undefined);
await page.getByTestId('btn-open-project').click();
await page.getByTestId('editor-shell').waitFor({ timeout: 120000 });
await page.waitForFunction(() => (window.__studio?.state?.assetsVersion ?? 0) > 0, null, { timeout: 300000 });
await page.waitForTimeout(3000);
await page.getByTestId('btn-play').click();
await page.waitForFunction(() => window.__play !== undefined && window.__play.sim, null, { timeout: 60000 });
await page.waitForTimeout(2500);
const stack = () => page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','));
for (let i = 0; i < 2 && /Title/.test(await stack()); i++) { await page.keyboard.press('KeyE'); await page.waitForTimeout(700); }
await page.waitForTimeout(1500);
await page.evaluate(() => { window.__play.sim.runtime.vars.has_quill = 1; });
const anim = () => page.evaluate(() => { const a = window.__play.sim.world.withTag('player')[0].get('animator'); return a ? `${a.state}/${a.clip}` : 'none'; });
// where he is on the screen: his feet through the renderer and the camera, then a clip around them
const report = [];
const feetOnScreen = () => page.evaluate(() => {
  const s = window.__play.sim, r = window.__viewport.renderer;
  const t = s.world.withTag('player')[0].get('transform');
  const v = r.camera.worldToView(r.worldToScreen(t.x, t.y, t.h));
  const rc = [...document.querySelectorAll('canvas')].map((c) => c.getBoundingClientRect()).sort((a, b) => b.width * b.height - a.width * a.height)[0];
  return { x: rc.left + v.x, y: rc.top + v.y };
});
const SIZE = 150;
const shot = async (name, freeze = false) => {
  if (freeze) await page.evaluate(() => { window.__play.runner.paused = true; });
  const f = await feetOnScreen();
  const clip = { x: Math.round(f.x - SIZE / 2), y: Math.round(f.y - SIZE + 30), width: SIZE, height: SIZE };
  await page.screenshot({ path: path.join(outDir, name + '.png'), clip });
  report.push({ name, anim: await anim(), feet: [Math.round(f.x), Math.round(f.y)] });
  if (freeze) await page.evaluate(() => { window.__play.runner.paused = false; });
};
await page.waitForTimeout(500);
await shot('idle_0');
const dirs = { W: ['KeyW'], A: ['KeyA'], S: ['KeyS'], D: ['KeyD'], WA: ['KeyW', 'KeyA'], WD: ['KeyW', 'KeyD'], SA: ['KeyS', 'KeyA'], SD: ['KeyS', 'KeyD'] };
for (const [name, keys] of Object.entries(dirs)) {
  for (const k of keys) await page.keyboard.down(k);
  await page.waitForTimeout(250);
  for (let i = 0; i < 3; i++) { await shot(`walk_${name}_${i}`); await page.waitForTimeout(40); }
  for (const k of keys) await page.keyboard.up(k);
  await page.waitForTimeout(900);
  await shot(`idle_${name}`);
  // the strike, facing the way he walked: frozen at three moments of it
  for (const [i, ms] of [[0, 20], [1, 70], [2, 130]]) {
    await page.keyboard.down('KeyJ');
    await page.waitForTimeout(ms);
    await shot(`strike_${name}_${i}`, true);
    await page.keyboard.up('KeyJ');
    await page.waitForTimeout(700);
  }
  await page.waitForTimeout(500);
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify(report, null, 1));
await app.close();
console.log('shots', report.length);
