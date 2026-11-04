// Things the Storytender gathers by walking into them (a Mnemosynth crystal: +5, and +12 lantern), remembered by a flag
// so they stay gone (main.gd, got_C_x_y).
export default defineScript({
  name: 'Collect',
  description: 'Picked up by walking into it; adds Mnemosynth and lantern light; never comes back.',
  settings: {
    flag: { value: '', label: 'Remembered as (flag)' },
    mnemo: { value: 5, label: 'Mnemosynth' },
    light: { value: 12, label: 'Lantern light' },
    radius: { value: 0.9, label: 'How close (cells)' },
  },
  start(me, game) {
    if (me.settings.flag && game.vars[me.settings.flag]) me.destroy();
  },
  update(me, game) {
    const p = game.player;
    if (!p || me.distanceTo(p) > Number(me.settings.radius) || Math.abs(p.h - me.h) > 0.7) return;
    const v = game.vars;
    // Fortune: +0.25% Mnemosynth found a point
    v.mnemosynth = Number(v.mnemosynth ?? 0) + Number(me.settings.mnemo) * (1 + 0.0025 * Number(v.attr_luck ?? 0));
    v.light = Math.min(100, Number(v.light ?? 100) + Number(me.settings.light));
    if (me.settings.flag) v[me.settings.flag] = 1;
    me.destroy();
  },
});
