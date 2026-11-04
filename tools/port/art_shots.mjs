// Port tool: screenshots of the new art in the real game. Opens the ported project in the Tilewright editor (Electron, under xvfb),
// starts the game, and goes through the scenes of a spec file; in each, for each spot of its list, moves the Storytender there (a test
// shortcut, as the other tests do) and saves the picture of the game's viewport as <out_dir>/<scene>_<label>.png. A spot is
// {label, x, y} (a cell; none: where the Storytender is) or {label, tag, dx, dy, nth} (beside the nth entity with that tag; a tag
// "name:Dummy" matches an entity by the start of its name), with optional {vars: {...}} set before the picture (a story flag) and
// {wait: ms}, {press: [keys]}, {look: [script, setting]} (shows the picture a script would switch to). Also writes <out_dir>/<scene>_entities.json (what the scene holds).
//   TILEWRIGHT=<engine checkout> xvfb-run -a node tools/port/art_shots.mjs <project_dir> <out_dir> <spec.json>
// scenes: overworld, then forge | pip | maud (entered and left the way the game does, through their door flags: one run can visit them
// all); a scene that has no door (scissor, proof, weighing) can only be the first of the spec, and is opened in the editor.
import { createRequire } from 'node:module';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const [projectDir, outDir, spotsFile] = process.argv.slice(2);
const spec = JSON.parse(fs.readFileSync(spotsFile, 'utf8'));   // { scene: [spot, ...], ... } in the order to visit them
const TILEWRIGHT = process.env.TILEWRIGHT ?? '/home/user/calebwilsonit-tech/tilewrite';
const { _electron: electron } = createRequire(path.join(TILEWRIGHT, 'package.json'))('playwright');
fs.mkdirSync(outDir, { recursive: true });
const base = fs.mkdtempSync(path.join(os.tmpdir(), 'tw-shots-'));
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
const DOORS = { forge: 'go_forge', pip: 'go_pip', maud: 'go_maud' };
const order = Object.keys(spec);
if (order[0] !== 'overworld' && !DOORS[order[0]]) {
  await page.evaluate(async (s) => { await window.__store.openScene(s); }, `scenes/${order[0]}.scene.json`);
  await page.waitForTimeout(1500);
}
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
const scene = () => page.evaluate(() => window.__play.sim.runtime.scene);
const dialogue = () => page.evaluate(() => window.__play.sim.runtime.dialogue?.view ?? null);
/** Closes any conversation that is open (the memories open with one) so it does not cover the picture. */
const dismiss = async () => {
  for (let i = 0; i < 25 && (await dialogue()); i++) {
    await page.keyboard.down('KeyE');
    await page.waitForTimeout(90);
    await page.keyboard.up('KeyE');
    await page.waitForTimeout(250);
  }
};
const clip = { x: 252, y: 110, width: 1008, height: 676 };   // the game's viewport in the editor window
let here = 'overworld';
for (const sceneName of order) {
  if (here !== sceneName && DOORS[here]) {   // out of a memory
    await page.evaluate((v) => { window.__play.sim.runtime.vars[v] = 1; }, 'leave_' + here);
    for (let i = 0; i < 120 && !/overworld/.test(await scene()); i++) await page.waitForTimeout(250);
    await page.waitForTimeout(1500);
    await dismiss();
    here = 'overworld';
  }
  if (here !== sceneName && DOORS[sceneName]) {
    await page.evaluate((v) => { window.__play.sim.runtime.vars[v] = 1; }, DOORS[sceneName]);
    for (let i = 0; i < 120 && !new RegExp(sceneName).test(await scene()); i++) await page.waitForTimeout(250);
    await page.waitForTimeout(1500);
    await dismiss();
    here = sceneName;
    console.log('in', await scene());
  }
  // what the scene holds
  const all = await page.evaluate(() => window.__play.sim.world.all().map((e) => ({ id: e.id, name: e.name, tags: [...(e.tags ?? [])], ...e.get('transform'), asset: e.get('sprite')?.asset ?? '', visible: e.get('sprite')?.visible !== false })));
  fs.writeFileSync(path.join(outDir, `${sceneName}_entities.json`), JSON.stringify(all, null, 1));
  for (const s of spec[sceneName]) {
    let { x, y } = s;
    let found = null;
    if (s.tag) {
      const hits = all.filter((e) => (s.tag.startsWith('name:') ? e.name.startsWith(s.tag.slice(5)) : e.tags.includes(s.tag)));
      const e = hits[s.nth ?? 0];
      if (!e) { console.log('MISSING', s.label, s.tag); continue; }
      found = e;
      x = e.x + (s.dx ?? -1.2);
      y = e.y + (s.dy ?? 1.2);
      console.log('at', s.label, e.name, e.x.toFixed(1), e.y.toFixed(1));
    }
    if (x !== undefined) await page.evaluate(([x, y]) => {
      const sim = window.__play.sim;
      const p = sim.world.withTag('player')[0];
      const t = p.get('transform');
      t.x = x; t.y = y; t.h = sim.map.getHeight(Math.floor(x), Math.floor(y));
      const b = p.get('body');
      if (b) { b.vx = 0; b.vy = 0; b.vz = 0; }
    }, [x, y]);
    await page.waitForTimeout(s.wait ?? 1200);
    for (const k of s.press ?? []) {   // keys pressed (E talks to what is beside the Storytender), then the conversation is closed
      await page.keyboard.down(k);
      await page.waitForTimeout(90);
      await page.keyboard.up(k);
      await page.waitForTimeout(500);
    }
    if (s.press) await dismiss();
    if (s.vars) {   // {id}, {cx}, {cy} in a flag name stand for the entity's id and cell
      const vars = {};
      for (const [k, v] of Object.entries(s.vars)) vars[found ? k.replace('{id}', found.id).replace('{cx}', Math.round(found.x - 0.5)).replace('{cy}', Math.round(found.y - 0.5)) : k] = v;
      await page.evaluate((v) => { Object.assign(window.__play.sim.runtime.vars, v); }, vars);
      await page.waitForTimeout(s.after ?? 900);
    }
    if (s.look && found) {   // {look: [script, setting]}: shows the picture a script would switch to (its setting holds the sprite name)
      await page.evaluate(([id, script, key]) => {
        const e = window.__play.sim.world.get(id);
        const name = e?.get(script)?.[key];
        const spr = e?.get('sprite');
        if (e && name && spr) e.set('sprite', { ...spr, asset: name });
      }, [found.id, s.look[0], s.look[1]]);
      await page.waitForTimeout(400);
    }
    await page.screenshot({ path: path.join(outDir, `${sceneName}_${s.label}.png`), clip });
  }
}
fs.writeFileSync(path.join(outDir, 'errors.json'), JSON.stringify(errors, null, 1));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log(' ', e.slice(0, 250));
await app.close();
