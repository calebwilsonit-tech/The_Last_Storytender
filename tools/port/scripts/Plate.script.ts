// An echo plate (echo_plate.gd): a floor plate that wants someone standing on it, the Storytender or one of her echoes.
// While someone does, its flag is 1.
export default defineScript({
  name: 'Plate',
  description: 'On (its flag is 1) while the Storytender or an echo stands on it.',
  settings: {
    flag: { value: '', label: 'Flag it holds' },
    radius: { value: 0.85, label: 'How close counts (cells)' },
    lookOn: { value: '', label: 'Picture while pressed (sprite name)' },
    lookOff: { value: '', label: 'Picture otherwise' },
  },
  update(me, game) {
    const r = Number(me.settings.radius);
    const on = (o: ScriptEntity): boolean => me.distanceTo(o) < r && Math.abs(o.h - me.h) < 0.6;
    let pressed = !!game.player && on(game.player);
    if (!pressed) for (const e of game.findAll('tag:echo')) if (on(e)) { pressed = true; break; }
    const v = pressed ? 1 : 0;
    if (game.vars[me.settings.flag] !== v) game.vars[me.settings.flag] = v;
    const look = pressed ? me.settings.lookOn : me.settings.lookOff;
    const spr = me.get('sprite');
    if (look && spr && spr.asset !== look) me.set('sprite', { ...spr, asset: look });
  },
});
