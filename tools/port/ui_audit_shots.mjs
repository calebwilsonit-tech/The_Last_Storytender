// Port tool: screenshots of the heads-up display, a prompt next to something you can use, and every menu, for looking at the UI.
//   TILEWRIGHT=<engine> node tools/port/ui_audit_shots.mjs <project_dir> <out_dir>
import { startGame } from './harness.mjs';

const { page, shotAs, placeAt, face, tagged, stack, finish, setV } = await startGame({ viewport: { width: 1500, height: 960 } });
try {
  await page.waitForTimeout(800);
  await shotAs('a_hud.png');
  // next to the person who is nearest: Garrick's sign or a talker
  const talkers = await page.evaluate(() => window.__play.sim.world.all?.().filter?.((e) => e.get('script_Talk') || e.get('talk')).slice(0, 3).map((e) => [e.name, e.get('transform').x, e.get('transform').y]) ?? []);
  console.log('talkers', JSON.stringify(talkers));
  const sign = (await tagged('sign'))[0] ?? (await tagged('npc'))[0];
  console.log('sign', JSON.stringify(sign));
  if (sign) {
    await placeAt(sign.x, sign.y + 1.1);
    await face(sign.x, sign.y);
    await page.waitForTimeout(900);
    await shotAs('b_near_thing.png');
  }
  for (const name of ['Pause', 'Settings', 'Binder', 'Map', 'Controls', 'Save game']) {
    await page.evaluate((n) => { window.__play.sim.runtime.ui.stack = [n]; }, name);
    await page.waitForTimeout(700);
    await shotAs(`c_${name.replace(/\W+/g, '_')}.png`);
  }
  await page.evaluate(() => { window.__play.sim.runtime.ui.stack = ['HUD']; });
  void stack; void setV;
} catch (e) {
  console.log('ERR', String((e && e.stack) || e).slice(0, 400));
}
await finish();
