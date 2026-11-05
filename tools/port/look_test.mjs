// Port tool: how things look (V-01, V-02, V-06): Maud's word blocks, a sentence stone in Pip's memory, the Cutting Room.
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/look_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
import { startGame } from './harness.mjs';

const { page, check, vars, setV, msgs, dialogue, placeAt, where, hp, face, tagged, press, hold, readAll, shotAs, at, useThing, clickText, leaveIndex, stack, finish } = await startGame();
try {
  await page.waitForTimeout(1500);
  const scene = () => page.evaluate(() => window.__play.sim.runtime.scene);
  const go = async (flag, re) => { await setV({ [flag]: 1 }); for (let i = 0; i < 60 && !re.test(await scene()); i++) await page.waitForTimeout(250); await page.waitForTimeout(2500); await readAll(); };
  await setV({ has_quill: 1, memory_done: 1, format_mark: 1 });
  await go('go_maud', /maud/);
  const words = await tagged('word');
  console.log('words', words.map((w) => `${w.x.toFixed(0)},${w.y.toFixed(0)}`).join(' '));
  const w0 = words[0];
  await placeAt(w0.x + 2.5, w0.y + 2.5);
  await page.waitForTimeout(900);
  await shotAs('look_maud_words.png');
  check('Maud\'s word blocks have no second copy of the word', words.length > 0, `${words.length} blocks`);
  const lab = await page.evaluate((id) => window.__play.sim.world.get(id)?.get('label')?.text ?? '(none)', w0.id);
  check('the engine\'s copy of the word is empty', lab === '' || lab === '(none)' || /underline|bold|italic/.test(lab), `label "${lab}"`);
  await setV({ leave_maud: 1 });
  for (let i = 0; i < 60 && !/overworld/.test(await scene()); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(2500);
  await setV({ leave_pip: 0 });
  await go('go_pip', /pip/);
  const stones = await tagged('stone');
  console.log('stones', stones.map((w) => `${w.x.toFixed(0)},${w.y.toFixed(0)}`).join(' '));
  const s0 = stones[0];
  await placeAt(s0.x + 2.0, s0.y + 2.2);
  await page.waitForTimeout(900);
  await shotAs('look_pip_stones.png');
  const sl = await page.evaluate((id) => window.__play.sim.world.get(id)?.get('label'), s0.id);
  check('a sentence stone writes its sentence large and dark', sl && sl.size >= 18 && sl.color === 0x2b1d12, JSON.stringify(sl));
  await setV({ leave_pip: 1 });
  for (let i = 0; i < 60 && !/overworld/.test(await scene()); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(2500);
  await setV({ go_scissor: 1 });
  for (let i = 0; i < 60 && !/scissor/.test(await scene()); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(2500);
  await shotAs('look_scissor.png');
  check('the Cutting Room opens', /scissor/.test(await scene()), await scene());
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
await finish();
