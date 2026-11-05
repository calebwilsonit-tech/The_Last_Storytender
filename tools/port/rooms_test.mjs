// Port tool: the two side rooms (C-04): the Weighing Room and the Proof Room.
// The Storytender is put next to things (a test shortcut); the plates, stones and chests are used with real keys.
//   TILEWRIGHT=<engine checkout> node tools/port/rooms_test.mjs <project_dir> <out_dir>      (xvfb-run -a in front on Linux)
import { startGame } from './harness.mjs';

const { page, check, vars, setV, msgs, dialogue, placeAt, where, hp, face, tagged, press, hold, readAll, shotAs, at, useThing, clickText, leaveIndex, stack, finish } = await startGame();
try {
  await page.waitForTimeout(1500);
  const scene = () => page.evaluate(() => window.__play.sim.runtime.scene);
  const waitScene = async (re) => { for (let i = 0; i < 60 && !re.test(await scene()); i++) await page.waitForTimeout(250); await page.waitForTimeout(1800); };
  const gateAt = async (x, y) => at(await tagged('gate'), x, y);
  let v;
  // ================= the Weighing Room =================
  await setV({ memory_done: 1, go_weighing: 1 });
  await waitScene(/weighing/);
  check('the Weighing Room opens with the forge memory done', /weighing/.test(await scene()), await scene());
  await page.waitForTimeout(800);
  await readAll();
  // the Tare Room: plate a (10,20) holds gate A (14,18) open for good
  let gA = await gateAt(14.5, 18.5);
  check('the Tare Room gate is shut', gA && gA.solid === true, JSON.stringify(gA));
  await placeAt(10.5, 20.5);
  await page.waitForTimeout(900);
  gA = await gateAt(14.5, 18.5);
  check('standing on its plate opens the gate', gA && gA.solid === false, JSON.stringify(gA));
  await placeAt(18.5, 21.5);
  await page.waitForTimeout(1500);
  gA = await gateAt(14.5, 18.5);
  check('and it stays open behind her (the first echo is free again)', gA && gA.solid === false, JSON.stringify(gA));
  // a gate that closes again: plate b (10,14), gate x (14,11)
  await placeAt(10.5, 14.5);
  await page.waitForTimeout(900);
  let gx = await gateAt(14.5, 11.5);
  check('the Relay gate opens while its plate is held', gx && gx.solid === false, JSON.stringify(gx));
  await placeAt(20.5, 14.5);
  await page.waitForTimeout(1500);
  gx = await gateAt(14.5, 11.5);
  check('and closes again when she walks away', gx && gx.solid === true, JSON.stringify(gx));
  // the Locket: a third echo
  await useThing(20.5, 8.5, 20.5, 7.3);
  v = await vars();
  check('the Locket of Second Thoughts gives a third echo', Number(v.echo_third) === 1, `echo_third ${v.echo_third}`);
  // the three weights
  const takeW = async (x, y, from, flag) => { for (let k = 0; k < 4 && !Number((await vars())[flag]); k++) await useThing(x, y, x, from); };
  for (let k = 0; k < 4 && !Number((await vars()).got_weight_T); k++) await useThing(19.5, 10.5, 18.4, 10.5); // (from the side: the map is empty south of it)
  await takeW(39.5, 3.5, 4.9, 'got_weight_U');
  v = await vars();
  console.log('weights flags', ['T','U','V'].map((c) => v[`got_weight_${c}`]).join(','), 'at', JSON.stringify(await where()));
  const sc0 = await gateAt(32.5, 28.5);
  check('two weights: the scale door stays shut', Number(v.weights) === 2 && sc0 && sc0.solid === true, `weights ${v.weights}`);
  await takeW(58.5, 12.5, 13.9, 'got_weight_V');
  await page.waitForTimeout(800);
  v = await vars();
  const sc1 = await gateAt(32.5, 28.5);
  check('three weights open the scale door', Number(v.weights) === 3 && sc1 && sc1.solid === false, `weights ${v.weights}, solid ${sc1?.solid}`);
  // the vault
  const said = await useThing(32.5, 32.5, 32.5, 33.9);
  v = await vars();
  check('the vault gives the Hourglass of Drafts and 15 renown', Number(v.side_weighing_done) === 1 && Number(v['item:hourglass_of_drafts']) >= 1 && Number(v.renown) >= 15, `${said.join(' | ').slice(0, 100)} renown ${v.renown}`);
  // the Pan Room: plate f (25,2) makes a bridge over (30..33, 0..4)
  let pan = await tagged('pan');
  check('the Pan Room has no bridge until its plate is held', pan.length === 20 && pan.every((c) => c.solid === true), `${pan.length} cells, solid ${pan.filter((c) => c.solid).length}`);
  await placeAt(25.5, 2.5);
  await page.waitForTimeout(1200);
  pan = await tagged('pan');
  check('holding the pan plate slides a bridge out', pan.every((c) => c.solid === false), `solid ${pan.filter((c) => c.solid).length}`);
  await shotAs('side_pan.png');
  await placeAt(31.5, 2.5);
  await page.waitForTimeout(1500);
  pan = await tagged('pan');
  const under = pan.find((c) => Math.abs(c.x - 31.5) < 0.1 && Math.abs(c.y - 2.5) < 0.1);
  check('the bridge does not let go of her while she is on it', under && under.solid === false, JSON.stringify(under));
  await placeAt(25.5, 6.5);
  await page.waitForTimeout(1500);
  pan = await tagged('pan');
  check('and goes once she is off it', pan.every((c) => c.solid === true), `solid ${pan.filter((c) => c.solid).length}`);
  // the way out
  await useThing(25.5, 19.5, 25.5, 20.9);
  await waitScene(/overworld/);
  check('the doorway takes her back to the overworld', /overworld/.test(await scene()), await scene());

  // ================= the Proof Room =================
  await setV({ has_quill: 1, go_proof: 1 });
  await waitScene(/proof/);
  check('the Proof Room opens with the quill', /proof/.test(await scene()), await scene());
  await page.waitForTimeout(800);
  await readAll();
  // a plaque is unreadable under its bar; the lantern lifts the bar
  let t1 = await useThing(8.5, 4.5, 9.9, 4.6);
  check('a plaque cannot be read under its black bar', t1.some((l) => /black bar covers it/i.test(l)), t1.join(' | ').slice(0, 100));
  await setV({ has_lantern: 1 });
  await placeAt(8.5, 8.5);
  await page.waitForTimeout(400);
  await page.keyboard.down('KeyW'); await page.keyboard.down('KeyD'); await page.waitForTimeout(700); await page.keyboard.up('KeyD'); await page.keyboard.up('KeyW'); await page.waitForTimeout(250);
  await face(8.5, 5.5);
  await page.keyboard.down('KeyQ');
  await page.waitForTimeout(3200);
  await page.keyboard.up('KeyQ');
  await page.waitForTimeout(500);
  v = await vars();
  check('the lantern lifts the bar and the plaque can be read', Number(v.plaque_seen_0) === 1, `plaque_seen_0 ${v.plaque_seen_0}; ${(await msgs()).slice(-2).join(' / ')}`);
  t1 = await useThing(8.5, 4.5, 9.9, 4.6);
  check('the plaque then gives its words', t1.some((l) => /ALIVE/.test(l)), t1.join(' | ').slice(0, 100));
  await shotAs('side_proof.png');
  // the three stones: ALIVE, UNWRITTEN, WELCOME
  const press1 = async (x) => { await useThing(x, 12.5, x, 13.9); };
  await press1(7.5);
  await press1(11.5); await press1(11.5);
  v = await vars();
  const g1 = await gateAt(20.5, 9.5);
  check('two stones right and one not: the gate stays shut', !v.site_proof && g1 && g1.solid === true, `${v.stone_proof_0}/${v.stone_proof_1}/${v.stone_proof_2}`);
  const rBefore = Number((await vars()).renown ?? 0);
  await press1(15.5);
  await page.waitForTimeout(900);
  v = await vars();
  const g2 = await gateAt(20.5, 9.5);
  check('all three right: approved, and the gate lifts (no extra renown)', Number(v.site_proof) === 1 && g2 && g2.solid === false && Number(v.renown ?? 0) === rBefore, `${v.stone_proof_0}/${v.stone_proof_1}/${v.stone_proof_2} renown ${v.renown}`);
  // the lantern post is a checkpoint, and the vault's reward
  const post = (await tagged('lantern-post'))[0];
  check('the Proof Room has its lantern post', !!post, JSON.stringify(post));
  const said2 = await useThing(52.5, 9.5, 52.5, 10.9);
  v = await vars();
  check('the last proof gives the Censor\'s Monocle', Number(v.side_proof_done) === 1 && Number(v['item:censors_monocle']) >= 1, said2.join(' | ').slice(0, 100));
} catch (e) {
  check('test run', false, String((e && e.stack) || e).slice(0, 400));
}
await finish();
