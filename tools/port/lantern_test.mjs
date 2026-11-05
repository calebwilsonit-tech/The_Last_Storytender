// Port test: the raised-lantern pose in all eight directions while Q is held, and the flickering flame of a lit lantern post.
//   TILEWRIGHT=<engine> node tools/port/lantern_test.mjs <project_dir> <out_dir>
import { startGame } from './harness.mjs';

const { page, check, placeAt, setV, shotAs, finish } = await startGame();
const an = () => page.evaluate(() => { const a = window.__play.sim.world.withTag('player')[0].get('animator'); return { state: a.state, clip: a.clip, frame: a.frame, params: { lantern: a.params?.lantern, speed: a.params?.speed } }; });
try {
  await page.waitForTimeout(800);
  const where = await page.evaluate(() => { const t = window.__play.sim.world.withTag('player')[0].get('transform'); return { x: t.x, y: t.y }; });
  await page.keyboard.down('KeyQ');
  const seen = [];
  for (let f = 0; f < 8; f++) {
    await page.evaluate((f) => { window.__play.sim.world.withTag('player')[0].get('transform').facing = f; }, f);
    await setV({ light: 100 }); // (the lantern burns while it is held)
    await page.waitForTimeout(1100);
    const a = await an();
    seen.push(`${f}:${a.state}/${a.clip}#${a.frame}`);
    if (a.state !== 'lantern') check(`facing ${f}: the lantern pose plays while Q is held`, false, JSON.stringify(a));
    await shotAs(`lantern_${f}.png`);
  }
  check('the raised-lantern pose plays in all eight directions while Q is held', seen.every((s) => /lantern\/lantern/.test(s)), seen.join(' '));
  await page.keyboard.up('KeyQ');
  await page.waitForTimeout(900);
  const after = await an();
  check('letting go of Q puts the lantern down', after.state !== 'lantern', JSON.stringify(after));
  // the post's flame
  const lit = () => page.evaluate(() => [...window.__play.sim.world.query('script_Flagged')].filter((e) => e.get('script_Flagged').look === 'obj_post_lit').map((e) => ({ id: e.id, x: e.get('transform').x, y: e.get('transform').y, animated: !!e.get('animator')?.follow })));
  const posts = await lit();
  check('a lit lantern post has an animated flame', posts.length > 0 && posts.every((p) => p.animated), `${posts.length} lit posts`);
  if (posts.length) {
    await placeAt(posts[0].x + 2, posts[0].y + 2);
    await page.evaluate((id) => { const e = [...window.__play.sim.world.query('script_Flagged')].find((q) => q.id === id); window.__play.sim.runtime.vars[e.get('script_Flagged').lookWhen] = 1; }, posts[0].id); // (lit)
    await page.waitForTimeout(900);
    const frames = new Set();
    for (let i = 0; i < 12; i++) { frames.add(await page.evaluate((id) => [...window.__play.sim.world.query('script_Flagged')].find((e) => e.id === id)?.get('animator')?.frame, posts[0].id)); await page.waitForTimeout(150); }
    // the prompt over it: "Light" until it is lit, then "Rest" (and no text drawn on the post)
    const ptext = () => page.evaluate(() => [...document.querySelectorAll('.tw-world-item *')].filter((x) => x.children.length === 0 && x.getBoundingClientRect().width > 0).map((x) => (x.textContent ?? '').trim()).filter(Boolean));
    const lit0 = await page.evaluate((id) => { const e = [...window.__play.sim.world.query('script_Flagged')].find((q) => q.id === id); const k = e.get('script_Flagged').lookWhen; const was = window.__play.sim.runtime.vars[k]; return was; }, posts[0].id);
    check('the lit post offers to rest', (await ptext()).includes('Rest'), (await ptext()).join('|'));
    await page.evaluate((id) => { const e = [...window.__play.sim.world.query('script_Flagged')].find((q) => q.id === id); window.__play.sim.runtime.vars[e.get('script_Flagged').lookWhen] = 0; e.set('sprite', { ...e.get('sprite'), asset: 'obj_post_unlit' }); }, posts[0].id);
    await page.waitForTimeout(700);
    check('an unlit post offers to light it', (await ptext()).includes('Light'), (await ptext()).join('|') + ' ' + lit0);
    const texts = await page.evaluate(() => [...window.__play.sim.world.query('label')].map((e) => e.get('label').text).filter((x) => /E: /.test(x)));
    check('and no "E: ..." text is drawn on the post', texts.length === 0, texts.join('|'));
    check('its flame moves (the animation plays)', frames.size > 2, [...frames].join(','));
  }
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
await finish();
