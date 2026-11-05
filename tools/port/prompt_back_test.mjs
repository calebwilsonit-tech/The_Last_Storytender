// Port test: the pop-up prompt over something she can use (and not the engine's "E: talk" text), and "back" in menus on the buttons that are
// not Esc (Backspace here; the gamepad's B is bound to the same action, ui_back).
//   TILEWRIGHT=<engine> node tools/port/prompt_back_test.mjs <project_dir> <out_dir>
import { startGame } from './harness.mjs';

const { page, check, placeAt, face, tagged, stack, press, shotAs, finish } = await startGame();
const shownText = () => page.evaluate(() => [...document.querySelectorAll('.tw-screens .tw-w, .tw-world-item *')].filter((x) => x.children.length === 0 && x.getBoundingClientRect().width > 0).map((x) => (x.textContent ?? '').trim()).filter(Boolean));
try {
  await page.waitForTimeout(800);
  // ---- the prompt
  const pip = (await tagged('pip'))[0];
  const garrick = (await tagged('garrick'))[0];
  await placeAt(garrick.x - 0.2, garrick.y + 1.3);
  await face(garrick.x, garrick.y);
  await page.waitForTimeout(900);
  let t = await shownText();
  check('next to someone a pop-up prompt shows the verb', t.includes('Talk') && t.includes('E'), t.filter((x) => x.length < 12).join('|').slice(0, 120));
  const labelText = await page.evaluate(() => window.__play.sim.world.all?.().map((e) => e.get('label')?.text).filter((x) => x && /E: /.test(x)) ?? []);
  check('the engine\'s "E: talk" text is not drawn on the object any more', labelText.length === 0, JSON.stringify(labelText).slice(0, 100));
  await shotAs('prompt_garrick.png');
  // far from everything the prompt is gone
  await placeAt(garrick.x + 12, garrick.y + 12);
  await page.waitForTimeout(900);
  t = await shownText();
  check('far away there is no prompt', !t.includes('Talk') && !t.includes('Read') && !t.includes('Enter'), t.filter((x) => x.length < 12).join('|').slice(0, 120));
  // only the nearest of two shows (Garrick and Pip stand side by side)
  await placeAt((garrick.x + pip.x) / 2, (garrick.y + pip.y) / 2 + 1);
  await page.waitForTimeout(900);
  const prompts = await page.evaluate(() => [...document.querySelectorAll('.tw-world-item')].filter((x) => x.getBoundingClientRect().width > 0 && /Talk|Read|Enter|Open|Take|Use|Leave|Sit/.test(x.textContent ?? '')).length);
  check('of two things side by side only one prompt shows', prompts <= 1, `${prompts} prompts`);

  // ---- back on Backspace (and so on the gamepad's B)
  await placeAt(garrick.x + 12, garrick.y + 12);
  await page.waitForTimeout(500);
  await page.evaluate(() => window.__play.sim.runtime.ui.stack.push('Pause'));
  await page.waitForTimeout(500);
  await page.evaluate(() => window.__play.sim.runtime.ui.stack.push('Settings'));
  await page.waitForTimeout(500);
  check('Settings is open on top of Pause', /Settings/.test(await stack()) && /Pause/.test(await stack()), await stack());
  await press('Backspace');
  await page.waitForTimeout(500);
  check('Backspace goes back from Settings to Pause', !/Settings/.test(await stack()) && /Pause/.test(await stack()), await stack());
  await press('Backspace');
  await page.waitForTimeout(500);
  check('Backspace goes back from Pause to the game', !/Pause/.test(await stack()), await stack());
  // with nothing open it must not open the Pause screen (B is also the dash)
  await press('Backspace');
  await page.waitForTimeout(500);
  check('Backspace in play does not open the Pause screen', !/Pause/.test(await stack()), await stack());
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
await finish();
