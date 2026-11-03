// A redaction bar (redactor.gd): a black bar over the way on. The lantern's beam held on it for 1.4 s lifts it; out of
// the light it creeps back. Lifted, it sets its flag and is gone for good.
const K = 35.8;
export default defineScript({
  name: 'Redactor',
  description: 'A black bar the lantern lifts.',
  settings: {
    flag: { value: '', label: 'Remembered as (flag)' },
    said: { value: '', label: 'Said when it lifts' },
  },
  start(me, game) {
    if (game.vars[me.settings.flag]) me.destroy();
    me.state.progress = 0;
  },
  update(me, game) {
    const p = game.player;
    if (!p) return;
    const dx = me.x - p.x;
    const dy = me.y - p.y;
    const dist = Math.hypot(dx, dy);
    let off = Math.abs(Math.atan2(dy, dx) - (p.facing * Math.PI) / 4);
    if (off > Math.PI) off = 2 * Math.PI - off;
    const lit = !!game.vars.lantern_on && dist <= 175 / K + 1.3 && (dist < 0.8 || off <= 0.63 + Math.atan2(1.3, Math.max(dist, 0.1)));
    const s = me.state;
    s.progress = lit ? Math.min(1, s.progress + game.dt / 1.4) : Math.max(0, s.progress - game.dt * 0.4);
    me.alpha = 1 - s.progress * 0.7;
    if (s.progress >= 1) {
      game.vars[me.settings.flag] = 1;
      if (me.settings.said) game.say(String(me.settings.said));
      me.destroy();
    }
  },
});
