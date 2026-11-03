// A pool of the Critic's red ink (memory_forge.gd _on_pool): a crack warns for 1.3 s, then the ink stays for 4 s and
// burns 6 every 0.6 s to whoever stands in its 3 x 3 cells.
export default defineScript({
  name: 'InkPool',
  description: 'Red ink on the floor: warns, then hurts whoever stands in it.',
  settings: {},
  start(me) {
    me.state.t = 0;
    me.state.tick = 0;
    me.alpha = 0.35;
  },
  update(me, game) {
    const s = me.state;
    s.t += game.dt;
    if (s.t < 1.3) {
      me.alpha = 0.25 + 0.2 * Math.abs(Math.sin(s.t * 8));
      return;
    }
    me.alpha = 0.9;
    s.tick = Math.max(0, s.tick - game.dt);
    const p = game.player;
    if (p && s.tick <= 0 && Math.abs(p.x - me.x) < 1.5 && Math.abs(p.y - me.y) < 1.5 && Math.abs(p.h - me.h) < 0.7) {
      s.tick = 0.6;
      game.damage(p, 6 * (game.vars.difficulty === 'story' ? 0.6 : 1));
    }
    if (s.t > 5.3) me.destroy();
  },
});
