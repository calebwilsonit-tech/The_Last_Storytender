// A redaction bar (redactor.gd): a black bar over the way on. The lantern's beam held on it for 1.4 s lifts it; out of
// the light it creeps back. Lifted, it sets its flag and is gone for good (remember off: the overworld's bars, which are not saved, just go
// until the scene is loaded again).
const K = 35.8;
export default defineScript({
  name: 'Redactor',
  description: 'A black bar the lantern lifts.',
  settings: {
    flag: { value: '', label: 'Remembered as (flag)' },
    remember: { value: true, label: 'Remember it is lifted (off: back whenever the scene loads)' },
    said: { value: '', label: 'Said when it lifts' },
  },
  start(me, game) {
    if (me.settings.remember && game.vars[me.settings.flag]) me.destroy();
    me.state.progress = 0;
  },
  update(me, game) {
    const p = game.player;
    if (!p) return;
    const dx = me.x - p.x;
    const dy = me.y - p.y;
    const dist = Math.hypot(dx, dy);
    // (the Storytender's facing is a direction on the screen, 0 = right, 2 = down; positions are grid cells, where +x runs down-right on the screen and +y down-left,
    // so the way from her to something is turned onto the screen first: (dx - dy, (dx + dy) / 2). The angle between the two is how far off her beam it is.)
    let off = Math.abs(Math.atan2((dx + dy) / 2, dx - dy) - (p.facing * Math.PI) / 4) % (2 * Math.PI);
    if (off > Math.PI) off = 2 * Math.PI - off;
    const lit = !!game.vars.lantern_on && dist <= 175 / K + 1.3 && (dist < 0.8 || off <= 0.63 + Math.atan2(1.3, Math.max(dist, 0.1)));
    const s = me.state;
    // the first black bar she comes near explains itself (main.gd _hint_redactor, 150 px)
    if (dist < 150 / K && !game.vars.redactor_hinted && me.settings.remember !== true) {
      game.vars.redactor_hinted = 1;
      game.say('A black bar hangs across the way. Something is written underneath it. Light makes things matter: hold Q, or the right mouse button.');
    }
    s.progress = lit ? Math.min(1, s.progress + game.dt / 1.4) : Math.max(0, s.progress - game.dt * 0.4);
    me.alpha = 1 - s.progress * 0.7;
    if (s.progress >= 1) {
      if (me.settings.remember) game.vars[me.settings.flag] = 1;
      if (me.settings.said) game.say(String(me.settings.said));
      me.destroy();
    }
  },
});
