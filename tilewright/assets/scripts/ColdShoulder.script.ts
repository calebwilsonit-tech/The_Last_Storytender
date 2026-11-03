// The Cold Shoulder (cold_shoulder.gd): it always turns its frozen shoulder to the Storytender. It can only be hurt from
// behind, or while it rests after a slam (x1.4). The lantern's warmth slows its turning. It shuffles closer, winds up
// (1 s) and slams where she stood (14 damage nearby), then rests 1.7 s. 170 HP, 119 in Story. Beaten, it sets cold_down.
const K = 35.8;
export default defineScript({
  name: 'ColdShoulder',
  description: 'The boss of the Empty Table.',
  settings: {},
  start(me) {
    me.state.ang = 0;
    me.state.mode = 'idle';
    me.state.cd = 3;
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    const p = game.player;
    if (!p) return;
    const mult = v.difficulty === 'story' ? 0.6 : 1;
    if (v.cold_down) { me.alpha = Math.max(0, me.alpha - game.dt / 2.2); if (me.alpha <= 0.02) me.destroy(); return; }
    let health = me.get('health');
    const want = v.difficulty === 'story' ? 119 : 170;
    if (health && health.max !== want) { me.set('health', { ...health, max: want }); health = me.get('health'); }
    let hp = me.get('state:health');
    if (hp && health && hp.hp > health.max) { me.set('state:health', { ...hp, hp: health.max }); hp = me.get('state:health'); }
    if (hp && health) { v.boss_name = 'The Cold Shoulder'; v.boss_hp = hp.hp; v.boss_max = health.max; }
    if (hp && (hp.dead || hp.hp <= 0)) {
      if (!s.endAsked) { s.endAsked = true; v.boss_name = ''; game.startDialogue('maud_end'); }
      return;
    }
    // turning its shoulder towards her: slower in the lantern's warmth, slower still while it rests
    const want_a = Math.atan2(p.y - me.y, p.x - me.x);
    let diff = want_a - s.ang;
    while (diff > Math.PI) diff -= Math.PI * 2;
    while (diff < -Math.PI) diff += Math.PI * 2;
    let rate = 1.25;
    if (v.lantern_on && me.distanceTo(p) < 320 / K) rate *= 0.45;
    if (s.mode === 'rest') rate *= 0.3;
    s.ang += Math.max(-rate * game.dt, Math.min(rate * game.dt, diff));
    me.facing = (Math.round((s.ang / Math.PI) * 4) + 8) % 8;
    // a hit: only from behind (more than 2 rad off its facing) or while it rests
    if (hp && health) {
      if (s.hp === undefined) s.hp = hp.hp;
      if (hp.hp < s.hp) {
        const lost = s.hp - hp.hp;
        let off = Math.abs(want_a - s.ang);
        if (off > Math.PI) off = 2 * Math.PI - off;
        if (s.mode === 'rest') me.set('state:health', { ...hp, hp: Math.max(0, hp.hp - lost * 0.4) });
        else if (off <= 2) me.set('state:health', { ...hp, hp: s.hp }); // the shoulder takes it: a clang
      }
      s.hp = (me.get('state:health') as { hp: number }).hp;
    }
    const fury = hp && health && hp.hp < health.max * 0.5 ? 0.7 : 1;
    switch (s.mode) {
      case 'idle':
        if (me.distanceTo(p) > 110 / K) me.walkTo(p.x, p.y, 38 / K);
        if ((s.cd -= game.dt) <= 0) { s.mode = 'tele'; s.st = 1.0 * fury; s.at = { x: p.x, y: p.y }; }
        break;
      case 'tele':
        if ((s.st -= game.dt) <= 0) {
          if (Math.hypot(p.x - s.at.x, p.y - s.at.y) < 2.1) game.damage(p, 14 * mult);
          s.mode = 'rest';
          s.st = 1.7;
        }
        break;
      case 'rest':
        if ((s.st -= game.dt) <= 0) { s.mode = 'idle'; s.cd = 2.6 * fury; }
        break;
    }
  },
});
