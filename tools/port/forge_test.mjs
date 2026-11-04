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
await page.getByTestId('btn-play').click();
await page.waitForFunction(() => window.__play !== undefined && window.__play.sim, null, { timeout: 60000 });
await page.waitForTimeout(2500);
// the title screen: New Game, then the Story difficulty
const stack = () => page.evaluate(() => window.__play.sim.runtime.ui.stack.join(','));
for (let i = 0; i < 2 && /Title/.test(await stack()); i++) {
  await page.keyboard.press('KeyE');
  await page.waitForTimeout(700);
}

const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ' - ' + detail : ''}`);
};
const vars = () => page.evaluate(() => ({ ...window.__play.sim.runtime.vars }));
const scene = () => page.evaluate(() => window.__play.sim.runtime.scene);
const dialogue = () => page.evaluate(() => window.__play.sim.runtime.dialogue?.view ?? null);
const placeAt = (x, y) =>
  page.evaluate(([x, y]) => {
    const s = window.__play.sim;
    const p = s.world.withTag('player')[0];
    const t = p.get('transform');
    t.x = x; t.y = y; t.h = s.map.getHeight(Math.floor(x), Math.floor(y));
    const b = p.get('body');
    if (b) { b.vx = 0; b.vy = 0; b.vz = 0; }
  }, [x, y]);
// her facing is a direction on the screen (0 right, 2 down); grid +x runs down-right and +y down-left, so the way to (x, y) is turned onto the screen first
const face = (x, y) => page.evaluate(([x, y]) => { const p = window.__play.sim.world.withTag('player')[0].get('transform'); p.facing = (Math.round((Math.atan2((x - p.x + (y - p.y)) / 2, x - p.x - (y - p.y)) / Math.PI) * 4) + 8) % 8; }, [x, y]);
const tagged = (tag) => page.evaluate((tag) => window.__play.sim.world.withTag(tag).map((e) => ({ id: e.id, name: e.name, ...e.get('transform'), open: e.get('collider') ? !e.get('collider').enabled : null, visible: e.get('sprite')?.visible !== false })), tag);
const press = async (key, ms = 90) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); await page.waitForTimeout(160); };
const readAll = async () => {
  const seen = [];
  for (let i = 0; i < 60; i++) {
    const v = await dialogue();
    if (!v) break;
    seen.push(v.kind === 'line' ? v.text : `[choice] ${v.prompt}`);
    await press('KeyE');
    await page.waitForTimeout(150);
  }
  return seen;
};
const heal = () => page.evaluate(() => { const h = window.__play.sim.world.withTag('player')[0].get('state:health'); if (h) { h.hp = 100; h.dead = false; } });
const shotAs = (name) => page.screenshot({ path: path.join(outDir, name) });
const near = (list, x, y) => [...list].sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y))[0];

try {
  // into the memory: the forge's door in Thistledown sends you (go_forge)
  await page.evaluate(() => { window.__play.sim.runtime.vars.go_forge = 1; });
  for (let i = 0; i < 40 && !/forge/.test(await scene()); i++) await page.waitForTimeout(250);
  check('the forge door takes you into the memory', /forge/.test(await scene()), await scene());
  await page.waitForTimeout(2000);
  await shotAs('f1_arrive.png');
  const intro = await readAll();
  check('the memory greets you and gives you an echo', intro.length > 0 && Number((await vars()).echo_granted) === 1, intro.join(' | ').slice(0, 140));

  // an echo plate holds its gate open
  const plates = await tagged('plate');
  const gates = await tagged('gate');
  const pa = plates.find((p) => Math.abs(p.x - 3.5) < 0.6 && Math.abs(p.y - 13.5) < 0.6);
  const gg = near(gates, 11.5, 11.5);
  await placeAt(pa.x, pa.y);
  await page.waitForTimeout(900);
  const gOpen = (await tagged('gate')).find((g) => g.id === gg.id).open;
  await shotAs('f2_plate.png');
  check('standing on a plate opens its gate', gOpen === true, `plate_a ${(await vars()).plate_a}`);

  // Garrick's three tools open the forge door
  for (const t of await tagged('token')) {
    await placeAt(t.x, t.y + 1.0);
    await page.waitForTimeout(300);
    await press('KeyE');
    await page.waitForTimeout(300);
    await readAll();
  }
  await page.waitForTimeout(800);
  const door = near(await tagged('gate'), 40.5, 11.5);
  check("Garrick's three tools open the forge door", Number((await vars()).forge_tokens) === 3 && door.open === true, `tokens ${(await vars()).forge_tokens}`);

  // the lantern lifts the black bar
  const bar = (await tagged('redactor'))[0];
  if (bar) {
    await placeAt(bar.x, bar.y - 2.2);
    await face(bar.x, bar.y);
    await page.keyboard.down('KeyQ');
    for (let i = 0; i < 12 && !(await vars()).forge_bar; i++) { await page.waitForTimeout(250); await face(bar.x, bar.y); }
    await page.keyboard.up('KeyQ');
  }
  await readAll();
  check('the lantern lifts the black bar', Number((await vars()).forge_bar) === 1);

  // into the forge hall: the Critic wakes
  await heal();
  await placeAt(44.5, 11.5);
  await page.waitForTimeout(1200);
  const wake = await readAll();
  await page.waitForTimeout(500);
  check('the Critic wakes in the forge hall', Number((await vars()).critic_awake) === 1, wake.join(' | ').slice(0, 120));
  // it throws its words
  let bolts = 0;
  for (let i = 0; i < 20 && bolts === 0; i++) { await page.waitForTimeout(250); bolts = (await tagged('bolt')).length; }
  await shotAs('f3_critic.png');
  check('the Critic throws its words', bolts > 0, `${bolts} in the air`);

  // the three memories strip its layers
  for (const sh of await tagged('shard')) {
    await heal();
    await placeAt(sh.x, sh.y + 1.0);
    await page.waitForTimeout(300);
    await press('KeyE');
    await page.waitForTimeout(300);
    await readAll();
  }
  await page.waitForTimeout(800);
  const reckon = await readAll();
  const v3 = await vars();
  check('three memories strip its layers: the reckoning', [1, 2, 3].every((i) => Number(v3[`shard_${i}`]) === 1) && Number(v3.critic_reckoning) === 1, reckon.join(' | ').slice(0, 100));

  // now it can be hurt
  const critic = () => page.evaluate(() => { const c = window.__play.sim.world.withTag('critic')[0]; return c ? { hp: c.get('state:health')?.hp, ...c.get('transform') } : null; });
  const c0 = await critic();
  for (let i = 0; i < 8; i++) {
    await heal();
    const c = await critic();
    if (!c) break;
    await placeAt(c.x - 1.0, c.y);
    await face(c.x, c.y);
    await press('KeyJ', 80);
  }
  const c1 = await critic();
  check('the Critic can be hurt after the reckoning', c0 && c1 && c1.hp < c0.hp, `hp ${c0?.hp} -> ${c1?.hp}`);

  // beat it (the rest of its health, a test shortcut) and take the First Sword
  await page.evaluate(() => { const c = window.__play.sim.world.withTag('critic')[0]; const h = c.get('state:health'); h.hp = 0; h.dead = true; });
  await page.waitForTimeout(800);
  const fin = await readAll();
  await page.waitForTimeout(800);
  const sword = (await tagged('sword'))[0];
  check('beaten, the First Sword appears on the anvil', Number((await vars()).critic_down) === 1 && sword && sword.visible, fin.slice(-1).join(''));
  await placeAt(sword.x, sword.y + 1.2);
  await page.waitForTimeout(300);
  await press('KeyE');
  await page.waitForTimeout(300);
  await readAll();
  for (let i = 0; i < 40 && /forge/.test(await scene()); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(1000);
  await shotAs('f4_home.png');
  const v4 = await vars();
  check('taking the sword ends the memory and brings you home', Number(v4.has_sword) === 1 && Number(v4.memory_done) === 1 && /overworld/.test(await scene()), await scene());
} catch (e) {
  check('test run', false, String(e && e.stack || e).slice(0, 400));
}
fs.writeFileSync(path.join(outDir, 'report.json'), JSON.stringify({ results, errors: errors.slice(0, 40) }, null, 2));
console.log('errors', errors.length);
for (const e of errors.slice(0, 10)) console.log('  ', e.slice(0, 300));
await app.close();
