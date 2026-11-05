// Port test: every creature has pictures from all eight directions, and shows the one that fits the way it faces.
//   TILEWRIGHT=<engine> node tools/port/directions_test.mjs <project_dir> <out_dir>
import fs from 'node:fs';
import path from 'node:path';
import { startGame } from './harness.mjs';

const { page, check, placeAt, tagged, projectDir, shotAs, finish } = await startGame();
const FACINGS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE'];
const sprite = (name) => JSON.parse(fs.readFileSync(path.join(projectDir, 'assets', 'sprites', `${name}.sprite.json`), 'utf8'));
const names = [];
for (const k of ['bare', 'censor', 'dangler', 'ellipsis', 'mite', 'runon']) names.push(`err_${k}`, `err_${k}_attack`);
names.push('boss_cold_shoulder', 'boss_cold_slam', 'boss_critic_attack', 'boss_spoiler_attack', 'boss_scissor_cut', 'npc_garrick', 'npc_pip', 'npc_maud', 'npc_garrick_ghost', 'npc_pip_ghost', 'npc_maud_ghost', 'obj_post_lit');
const lacking = [];
for (const n of names) {
  const clip = sprite(n).clips.find((c) => c.name === 'idle');
  const dirs = clip?.dirs ?? {};
  const missing = n === 'obj_post_lit' ? [] : FACINGS.filter((f) => !(dirs[f]?.length > 0));
  if (missing.length) lacking.push(`${n}: ${missing.join(' ')}`);
}
check('every creature\'s picture has a view for each of the eight directions', lacking.length === 0, lacking.join('; ').slice(0, 300));
try {
  await page.waitForTimeout(800);
  // a villager turns to look at her: stand on each side of Garrick
  const g = (await tagged('garrick'))[0];
  const seen = {};
  for (const [dx, dy] of [[0, 3], [3, 0], [0, -3], [-3, 0], [3, 3], [-3, -3]]) {
    await placeAt(g.x + dx, g.y + dy);
    await page.waitForTimeout(700);
    const r = await page.evaluate((id) => { const e = [...window.__play.sim.world.query('transform')].find((q) => q.id === id); const a = e.get('animator'); return { facing: e.get('transform').facing, frame: a?.frame, asset: e.get('sprite').asset }; }, g.id);
    seen[`${dx},${dy}`] = r;
  }
  const facings = new Set(Object.values(seen).map((r) => r.facing));
  check('Garrick turns to look at her as she walks round him', facings.size >= 4, JSON.stringify(Object.entries(seen).map(([k, r]) => `${k}:${r.facing}`)));
  const asset = Object.values(seen)[0].asset;
  const dirs = sprite(asset).clips.find((c) => c.name === 'idle').dirs;
  const okFrames = Object.values(seen).every((r) => Object.entries(dirs).some(([f, list]) => FACINGS.indexOf(f) === r.facing && list.includes(r.frame)));
  check('and the picture shown is the one for that direction', okFrames, JSON.stringify(Object.values(seen).map((r) => `${r.facing}#${r.frame}`)));
  await placeAt(g.x + 3, g.y);
  await page.waitForTimeout(700);
  await shotAs('garrick_dir_a.png');
  await placeAt(g.x, g.y - 3);
  await page.waitForTimeout(700);
  await shotAs('garrick_dir_b.png');
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
await finish();
